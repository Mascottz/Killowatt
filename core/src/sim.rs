use crate::breaker::{Breaker, Verdict};
use crate::ledger::Event;
use crate::{fmt_t, money};
use crate::policy::Policy;

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

pub fn run() {
    let policy = Policy::load();
    println!("killowatt core; replaying a runaway loop against the {} policy", policy.account);
    println!(
        "policy {} → daily {}, hourly {}, burst {} per {}s, action {}",
        policy.account,
        money(policy.daily_limit_cents),
        money(policy.hourly_limit_cents),
        money(policy.burst.limit_cents),
        policy.burst.window_seconds,
        policy.action
    );
    if !policy.exempt.is_empty() {
        println!("exempt {}", policy.exempt.join(", "));
    }
    println!();

    let mut br = Breaker::new(policy.clone());
    let mut trip_ms: Option<u64> = None;
    let mut first_abuse_ms: Option<u64> = None;
    let mut refused_counter: u64 = 0;

    for t in 0..=END_TICK {
        let ts = t * TICK_MS;

        for (name, base) in SERVICES {
            let mut cents = base;
            if name == "durable-objects" && t >= RUNAWAY_AT_TICK {
                cents += LOOP_EXTRA_CENTS;
                if first_abuse_ms.is_none() {
                    first_abuse_ms = Some(ts);
                }
            }

            let verdict = br.evaluate(Event {
                ts_ms: ts,
                service: name.to_string(),
                cents,
            });

            let was_throttle = matches!(verdict, Verdict::Throttle(_));
            match verdict {
                Verdict::HardStop(reason) | Verdict::Throttle(reason) => {
                    let label = if was_throttle { "THROTTLE" } else { "TRIP" };
                    println!("{}  {}    {}", fmt_t(ts), label, reason);
                    println!(
                        "{}  stop    suspended {} on {}; action {}",
                        fmt_t(ts),
                        name,
                        policy.account,
                        policy.action
                    );
                    trip_ms = Some(ts);
                }
                Verdict::Blocked => {
                    refused_counter += 1;
                }
                _ => {}
            }
        }

        match trip_ms {
            None => {
                if t % 30 == 0 {
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
            Some(_) => {
                if t % 30 == 0 && refused_counter > 0 {
                    println!(
                        "{}  blocked {} charges refused; prevented {} so far",
                        fmt_t(ts),
                        refused_counter,
                        money(br.prevented_cents)
                    );
                    refused_counter = 0;
                }
            }
        }
    }

    let trip_at = trip_ms.expect("the demo always trips");
    let abuse_at = first_abuse_ms.expect("the loop always starts");
    println!();
    println!("summary");
    println!("  first abusive event    {}", fmt_t(abuse_at));
    println!(
        "  trip                   {}, {} after the loop started",
        fmt_t(trip_at),
        fmt_t(trip_at - abuse_at)
    );
    println!("  spent before trip      {}", money(br.spent_at_trip_cents));
    println!(
        "  prevented after trip   {} in {} of simulated time",
        money(br.prevented_cents),
        fmt_t(END_TICK * TICK_MS - trip_at)
    );
    println!("  real incidents run for days; that tail is what killowatt protects");
}
