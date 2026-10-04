use crate::ledger::Event;
use crate::policy::Policy;
use crate::report;
use crate::money;

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

// pure event generation; the same stream the demo replays twice.
pub fn build_events() -> Vec<Event> {
    let mut events = Vec::new();
    for t in 0..=END_TICK {
        let ts = t * TICK_MS;
        for (name, base) in SERVICES {
            let mut cents = base;
            if name == "durable-objects" && t >= RUNAWAY_AT_TICK {
                cents += LOOP_EXTRA_CENTS;
            }
            events.push(Event {
                ts_ms: ts,
                service: name.to_string(),
                cents,
            });
        }
    }
    events
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

    let events = build_events();

    println!();
    println!("replay one; the breaker armed, action hard_stop");
    println!("--------------------------------------------------");
    let mut armed = policy.clone();
    armed.action = "hard_stop".into();
    let armed_out = report::replay(&armed, &events);

    println!();
    println!("replay two; watch mode, same incident, action alert_only");
    println!("--------------------------------------------------");
    let mut watch = policy.clone();
    watch.action = "alert_only".into();
    let watch_out = report::replay(&watch, &events);

    report::pitch(&armed_out, &watch_out);
}
