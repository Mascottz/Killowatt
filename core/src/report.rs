use crate::breaker::{Breaker, Verdict};
use crate::enforce::{self, Enforcer};
use crate::ledger::Event;
use crate::policy::Policy;
use crate::{fmt_t, money};

// what one replay of an event stream produces.
pub struct Outcome {
    pub crossed_at: Option<u64>,
    pub first_ts: u64,
    pub cross_window: Option<String>,
    pub spent_at_cross_cents: u64,
    pub prevented_cents: u64,
    pub saved_cents: u64,
    pub total_spend_cents: u64,
}

// feed an ordered event stream through a breaker and tell the story.
// used by the built-in demo and by ingest, so simulated bills and real
// bills get exactly the same treatment.
pub fn replay(
    policy: &Policy,
    events: &[Event],
    enforcer: &mut dyn Enforcer,
    verbose: bool,
) -> Outcome {
    let mut br = Breaker::new(policy.clone());
    let total = events.len();
    let step = (total / 12).max(1);

    let mut crossed_at: Option<u64> = None;
    let mut watch_announced = false;
    let mut refused_counter: u64 = 0;
    let mut cumulative_cents: u64 = 0;
    let mut spent_at_cross_cents: u64 = 0;
    let mut first_ts: u64 = 0;
    let mut last_ts: u64 = 0;

    for (i, e) in events.iter().enumerate() {
        if i == 0 {
            first_ts = e.ts_ms;
        }
        last_ts = e.ts_ms;
        cumulative_cents += e.cents;
        let ts = e.ts_ms;

        let verdict = br.evaluate(e.clone());

        match verdict {
            Verdict::HardStop(reason) | Verdict::Throttle(reason) => {
                if verbose {
                    let label = if policy.action == "throttle" {
                        "THROTTLE"
                    } else {
                        "TRIP"
                    };
                    println!("{}  {}    {}", fmt_t(ts - first_ts), label, reason);
                    println!(
                        "{}  stop    suspended {} on {}; action {}",
                        fmt_t(ts - first_ts),
                        e.service,
                        policy.account,
                        policy.action
                    );
                }
                crossed_at = Some(ts);
                spent_at_cross_cents = br.spent_at_trip_cents;

                if let Some(order) =
                    enforce::order_for(&policy.action, &policy.account, &e.service, &reason, ts)
                {
                    match enforcer.enforce(&order) {
                        Ok(report) => {
                            if verbose {
                                println!("{}  enforce {}", fmt_t(ts - first_ts), report)
                            }
                        }
                        Err(msg) => println!("{}  enforce failed; {}", fmt_t(ts - first_ts), msg),
                    }
                }
            }
            Verdict::Watch(reason) => {
                if crossed_at.is_none() {
                    crossed_at = Some(ts);
                    spent_at_cross_cents = cumulative_cents;
                }
                if !watch_announced {
                    watch_announced = true;
                    if verbose {
                        println!("{}  WATCH   {}", fmt_t(ts - first_ts), reason);
                        println!(
                            "{}  note    nothing touched; killowatt would have stopped this",
                            fmt_t(ts - first_ts)
                        );
                    }
                }
            }
            Verdict::Blocked => {
                refused_counter += 1;
            }
            Verdict::Allow => {}
        }

        if i % step != 0 || !verbose {
            continue;
        }

        match (br.is_tripped(), br.is_watching()) {
            (true, _) => {
                if refused_counter > 0 {
                    println!(
                        "{}  blocked {} charges refused; prevented {} so far",
                        fmt_t(ts - first_ts),
                        refused_counter,
                        money(br.prevented_cents)
                    );
                    refused_counter = 0;
                }
            }
            (false, true) => {
                println!(
                    "{}  watch   still burning; would have saved {} by now",
                    fmt_t(ts - first_ts),
                    money(br.would_have_saved_cents)
                );
            }
            (false, false) => {
                println!(
                    "{}  state   burst {} of {}; hour {} of {}",
                    fmt_t(ts - first_ts),
                    money(br.burst_spend(ts)),
                    money(policy.burst.limit_cents),
                    money(br.hour_spend(ts)),
                    money(policy.hourly_limit_cents)
                );
            }
        }
    }

    if verbose {
        println!();
        println!("summary");
    println!(
        "  stream                 {} events over {}",
        total,
        fmt_t(last_ts.saturating_sub(first_ts))
    );

    if let Some(crossed) = crossed_at {
        println!(
            "  limit crossed          {} after the stream started",
            fmt_t(crossed - first_ts)
        );
    }

    if br.is_tripped() {
        println!("  spent before trip      {}", money(spent_at_cross_cents));
        println!(
            "  prevented after trip   {}",
            money(br.prevented_cents)
        );
    } else if br.is_watching() {
        println!("  spent, untouched       {}", money(cumulative_cents));
        println!(
            "  would have saved       {}",
            money(br.would_have_saved_cents)
        );
    } else {
        println!("  quiet stream           {}", money(cumulative_cents));
        println!("  nothing crossed a limit; nothing to stop");
    }
    }

    Outcome {
        first_ts,
        cross_window: br.breach_window.map(String::from),
        crossed_at,
        spent_at_cross_cents,
        prevented_cents: br.prevented_cents,
        saved_cents: br.would_have_saved_cents,
        total_spend_cents: cumulative_cents,
    }
}

// the pitch, printed after running the same stream armed and watching.
pub fn pitch(armed: &Outcome, watch: &Outcome) {
    println!();
    println!("the pitch, side by side");
    if armed.crossed_at.is_some() {
        println!(
            "  armed   spent {}, then stopped it; prevented {}",
            money(armed.spent_at_cross_cents),
            money(armed.prevented_cents)
        );
        println!(
            "  watch   touched nothing, saw everything; would have saved {}",
            money(watch.saved_cents)
        );
    } else {
        println!(
            "  nothing crossed a limit in this stream; {} spent, nothing to stop",
            money(armed.total_spend_cents)
        );
    }
    println!("  watch mode is how you earn the right to arm the breaker");
}
