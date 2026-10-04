use crate::breaker::{Breaker, Verdict};
use crate::ledger::Event;
use crate::policy::Policy;
use crate::{fmt_t, money};

const TICK_MS: u64 = 2_000;
const RUNAWAY_AT_TICK: u64 = 180; // t+06:00, the misconfigured retry loop starts here
const END_TICK: u64 = 600; // t+20:00

// the acme production workload, in cents per tick.
const SERVICES: [(&str, u64); 3] = [
    ("api-gateway", 2),
    ("rds-prod-backups", 14),
    ("durable-objects", 1),
];

const LOOP_EXTRA_CENTS: u64 = 55; // the loop; same request over and over, billed every time

struct Outcome {
    spent_at_cross: u64,
    prevented_cents: u64,
    saved_cents: u64,
}

pub fn run() {
    let policy = Policy::load();
    println!(
        "killowatt core; one incident, replayed twice, against the {} policy",
        policy.account
    );
    println!(
        "policy {} → daily {}, hourly {}, burst {} per {}s",
        policy.account,
        money(policy.daily_limit_cents),
        money(policy.hourly_limit_cents),
        money(policy.burst.limit_cents),
        policy.burst.window_seconds
    );
    if !policy.exempt.is_empty() {
        println!("exempt {}", policy.exempt.join(", "));
    }

    println!();
    println!("replay one; the breaker armed, action hard_stop");
    println!("--------------------------------------------------");
    let mut armed = policy.clone();
    armed.action = "hard_stop".into();
    let armed_out = replay(armed);

    println!();
    println!("replay two; watch mode, same incident, action alert_only");
    println!("--------------------------------------------------");
    let mut watch = policy.clone();
    watch.action = "alert_only".into();
    let watch_out = replay(watch);

    println!();
    println!("the pitch, side by side");
    println!(
        "  armed   spent {}, then stopped it; prevented {}",
        money(armed_out.spent_at_cross),
        money(armed_out.prevented_cents)
    );
    println!(
        "  watch   touched nothing, saw everything; would have saved {}",
        money(watch_out.saved_cents)
    );
    println!("  watch mode is how you earn the right to arm the breaker");
}

fn replay(policy: Policy) -> Outcome {
    let mut br = Breaker::new(policy.clone());
    let mut abuse_at_ms = 0;
    let mut crossed_at_ms: Option<u64> = None;
    let mut crossed_announced = false;
    let mut refused_counter: u64 = 0;
    let mut total_spend_cents: u64 = 0;

    for t in 0..=END_TICK {
        let ts = t * TICK_MS;

        for (name, base) in SERVICES {
            let mut cents = base;
            if name == "durable-objects" && t >= RUNAWAY_AT_TICK {
                cents += LOOP_EXTRA_CENTS;
                if abuse_at_ms == 0 {
                    abuse_at_ms = ts;
                }
            }
            total_spend_cents += cents;

            let verdict = br.evaluate(Event {
                ts_ms: ts,
                service: name.to_string(),
                cents,
            });

            match verdict {
                Verdict::HardStop(reason) | Verdict::Throttle(reason) => {
                    let label = if matches!(br.policy.action.as_str(), "throttle") {
                        "THROTTLE"
                    } else {
                        "TRIP"
                    };
                    println!("{}  {}    {}", fmt_t(ts), label, reason);
                    println!(
                        "{}  stop    suspended {} on {}; action {}",
                        fmt_t(ts), name, policy.account, policy.action
                    );
                    crossed_at_ms = Some(ts);
                }
                Verdict::Watch(reason) => {
                    crossed_at_ms.get_or_insert(ts);
                    if !crossed_announced {
                        crossed_announced = true;
                        println!("{}  WATCH   {}", fmt_t(ts), reason);
                        println!(
                            "{}  note    nothing touched; killowatt would have stopped this",
                            fmt_t(ts)
                        );
                    }
                }
                Verdict::Blocked => {
                    refused_counter += 1;
                }
                _ => {}
            }
        }

        if t % 30 != 0 {
            continue;
        }

        match (br.is_tripped(), br.is_watching()) {
            (true, _) => {
                if refused_counter > 0 {
                    println!(
                        "{}  blocked {} charges refused; prevented {} so far",
                        fmt_t(ts),
                        refused_counter,
                        money(br.prevented_cents)
                    );
                    refused_counter = 0;
                }
            }
            (false, true) => {
                println!(
                    "{}  watch   still burning; would have saved {} by now",
                    fmt_t(ts),
                    money(br.would_have_saved_cents)
                );
            }
            (false, false) => {
                println!(
                    "{}  state   burst {} of {}; hour {} of {}",
                    fmt_t(ts),
                    money(br.burst_spend(ts)),
                    money(policy.burst.limit_cents),
                    money(br.hour_spend(ts)),
                    money(policy.hourly_limit_cents)
                );
            }
        }
    }

    let crossed = crossed_at_ms.expect("the demo always crosses a limit");
    println!();
    println!("summary");
    println!("  first abusive event    {}", fmt_t(abuse_at_ms));
    println!(
        "  limit crossed          {}, {} after the loop started",
        fmt_t(crossed),
        fmt_t(crossed - abuse_at_ms)
    );
    if br.is_tripped() {
        println!("  spent before trip      {}", money(br.spent_at_trip_cents));
        println!(
            "  prevented after trip   {} in {} of simulated time",
            money(br.prevented_cents),
            fmt_t(END_TICK * TICK_MS - crossed)
        );
    } else {
        println!("  spent, untouched       {}", money(total_spend_cents));
        println!(
            "  would have saved       {} in {} of simulated time",
            money(br.would_have_saved_cents),
            fmt_t(END_TICK * TICK_MS - crossed)
        );
    }

    Outcome {
        spent_at_cross: br.spent_at_trip_cents,
        prevented_cents: br.prevented_cents,
        saved_cents: br.would_have_saved_cents,
    }
}
