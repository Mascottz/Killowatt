// the semantics, pinned down; money stays integer, windows roll, exempt
// never counts, watch mode counts what it would have saved, and the trip
// lands on the first window that breaks.

use killowatt_core::breaker::{Breaker, Verdict};
use killowatt_core::ledger::{Event, Ledger};
use killowatt_core::policy::{BurstLimit, Policy};
use killowatt_core::{metering, money};

fn test_policy(action: &str) -> Policy {
    Policy {
        account: "test-prod".into(),
        daily_limit_cents: 250_00,
        hourly_limit_cents: 60_00,
        burst: BurstLimit {
            window_seconds: 600,
            limit_cents: 40_00,
        },
        exempt: vec!["backups".into()],
        action: action.into(),
    }
}

fn ev(ts_secs: u64, service: &str, cents: u64) -> Event {
    Event {
        ts_ms: ts_secs * 1000,
        service: service.to_string(),
        cents,
    }
}

#[test]
fn money_prints_from_integer_cents() {
    assert_eq!(money(0), "$0.00");
    assert_eq!(money(5), "$0.05");
    assert_eq!(money(40_20), "$40.20");
    assert_eq!(money(1_234_56), "$1234.56");
}

#[test]
fn ledger_window_rolls_and_prunes() {
    let mut ledger = Ledger::new();
    ledger.record(ev(0, "api", 100));
    ledger.record(ev(300, "api", 200));
    ledger.record(ev(700, "api", 400));
    ledger.prune(700_000, 600);

    // the t=0 event aged out of a 600s window by t=700
    let spend = ledger.spent_in_last(700_000, 600, |_| false);
    assert_eq!(spend, 600);
}

#[test]
fn calm_traffic_is_allowed() {
    let mut br = Breaker::new(test_policy("hard_stop"));
    for t in 0..60 {
        let verdict = br.evaluate(ev(t * 60, "api", 30));
        assert_eq!(verdict, Verdict::Allow);
    }
    assert!(!br.is_tripped());
    assert!(!br.is_watching());
}

#[test]
fn burst_trip_lands_on_the_first_window_that_breaks() {
    let mut br = Breaker::new(test_policy("hard_stop"));

    // 100 cents every 10s; a 600s window holds 61 events, so the 41st
    // event is the first one that can push the window past $40.00
    let mut tripped_at = None;
    for i in 0..50u64 {
        let verdict = br.evaluate(ev(i * 10, "api", 100));
        match verdict {
            Verdict::HardStop(_) => {
                tripped_at = Some(i);
                break;
            }
            Verdict::Allow => {}
            other => panic!("unexpected verdict; {:?}", other),
        }
    }

    assert_eq!(tripped_at, Some(40));
    assert!(br.is_tripped());
    assert!(br.spent_at_trip_cents > 40_00);
}

#[test]
fn hourly_limit_catches_the_slow_leak() {
    let mut br = Breaker::new(test_policy("hard_stop"));

    // 100 cents a minute; the burst window never sees more than $11.00,
    // but the hour crosses $60.00 at minute sixty
    let mut trip_reason = None;
    for m in 0..70u64 {
        if let Verdict::HardStop(reason) = br.evaluate(ev(m * 60, "api", 100)) {
            trip_reason = Some(reason);
            break;
        }
    }

    let reason = trip_reason.expect("the slow leak must trip");
    assert!(reason.contains("hourly"), "reason was; {}", reason);
}

#[test]
fn after_a_trip_everything_non_exempt_is_prevented() {
    let mut br = Breaker::new(test_policy("hard_stop"));
    for i in 0..41u64 {
        br.evaluate(ev(i * 10, "api", 100));
    }
    assert!(br.is_tripped());

    assert_eq!(br.evaluate(ev(500, "api", 250)), Verdict::Blocked);
    assert_eq!(br.prevented_cents, 250);

    // exempt services keep running through a hard stop and never count
    assert_eq!(br.evaluate(ev(510, "backups", 999)), Verdict::Blocked);
    assert_eq!(br.prevented_cents, 250);
}

#[test]
fn watch_mode_sees_the_breach_without_tripping() {
    let mut br = Breaker::new(test_policy("alert_only"));

    let mut first_watch = None;
    for i in 0..50u64 {
        match br.evaluate(ev(i * 10, "api", 100)) {
            Verdict::Watch(_) if first_watch.is_none() => first_watch = Some(i),
            Verdict::Watch(_) | Verdict::Allow => {}
            other => panic!("watch mode must not enforce; {:?}", other),
        }
    }

    assert_eq!(first_watch, Some(40));
    assert!(!br.is_tripped());
    assert!(br.is_watching());
    // every non-exempt charge from the first breach onward is counted
    assert_eq!(br.would_have_saved_cents, 100 * 10);
}

#[test]
fn exempt_services_cannot_trip_the_breaker() {
    let mut br = Breaker::new(test_policy("hard_stop"));
    for i in 0..100u64 {
        let verdict = br.evaluate(ev(i * 10, "backups", 500));
        assert_eq!(verdict, Verdict::Allow);
    }
    assert!(!br.is_tripped());
    assert!(!br.is_watching());
}

#[test]
fn metering_filters_sorts_and_rejects() {
    let dir = std::env::temp_dir();
    let path = dir.join(format!("killowatt-test-{}.jsonl", std::process::id()));

    // out of order, two accounts, one blank line
    let body = [
        r#"{"account":"other","service":"web","cents":9,"ts_ms":2000}"#,
        r#"{"account":"test-prod","service":"api","cents":30,"ts_ms":5000}"#,
        "",
        r#"{"account":"test-prod","service":"api","cents":20,"ts_ms":1000}"#,
    ]
    .join("\n");
    std::fs::write(&path, body).unwrap();

    let events = metering::load_events(&path, "test-prod").unwrap();
    assert_eq!(events.len(), 2);
    assert_eq!(events[0].ts_ms, 1000, "events come back sorted");
    assert_eq!(events[1].cents, 30);

    // garbage in, clean error out
    std::fs::write(&path, "not json\n").unwrap();
    assert!(metering::load_events(&path, "test-prod").is_err());

    // empty export, clean error out
    std::fs::write(&path, "\n").unwrap();
    assert!(metering::load_events(&path, "test-prod").is_err());

    std::fs::remove_file(&path).ok();
}

#[test]
fn watch_mode_produces_no_order() {
    assert!(killowatt_core::enforce::order_for(
        "alert_only",
        "acct",
        "api",
        "whatever",
        1000
    )
    .is_none());
}

#[test]
fn hard_stop_maps_to_suspend_and_throttle_maps_to_throttle() {
    use killowatt_core::enforce::{order_for, Action};

    let stop = order_for("hard_stop", "acct", "api", "burst broke", 1000).unwrap();
    assert_eq!(stop.action, Action::Suspend);

    let throttle = order_for("throttle", "acct", "api", "burst broke", 1000).unwrap();
    assert_eq!(throttle.action, Action::Throttle);
}

#[test]
fn dry_run_collects_orders_and_touches_nothing() {
    use killowatt_core::enforce::{order_for, DryRun, Enforcer};

    let mut dry = DryRun::new();
    let order = order_for("hard_stop", "acct", "api", "burst broke", 1000).unwrap();
    let report = dry.enforce(&order).unwrap();

    assert!(report.contains("dry-run"));
    assert_eq!(dry.orders.len(), 1);
}

#[test]
fn audit_log_appends_one_json_line_per_order() {
    use killowatt_core::enforce::{order_for, AuditLog, Enforcer};

    let path = std::env::temp_dir().join(format!("killowatt-audit-{}.jsonl", std::process::id()));
    let _ = std::fs::remove_file(&path);

    let mut log = AuditLog::new(&path);
    let order = order_for("hard_stop", "acct", "api", "burst broke", 1000).unwrap();
    log.enforce(&order).unwrap();
    log.enforce(&order).unwrap();

    let body = std::fs::read_to_string(&path).unwrap();
    let lines: Vec<&str> = body.lines().collect();
    assert_eq!(lines.len(), 2);

    let parsed: serde_json::Value = serde_json::from_str(lines[0]).unwrap();
    assert_eq!(parsed["service"], "api");
    assert_eq!(parsed["action"], "suspend");

    std::fs::remove_file(&path).ok();
}

#[test]
fn bill_groups_events_by_account() {
    use killowatt_core::metering;

    let path = std::env::temp_dir().join(format!("killowatt-bill-{}.jsonl", std::process::id()));
    std::fs::write(
        &path,
        r#"{"account":"a","service":"x","cents":10,"ts_ms":300}
{"account":"b","service":"y","cents":20,"ts_ms":100}
{"account":"a","service":"x","cents":11,"ts_ms":100}
"#,
    )
    .unwrap();

    let groups = metering::load_events_by_account(&path).unwrap();
    assert_eq!(groups.len(), 2);
    assert_eq!(groups["a"].len(), 2);
    assert_eq!(groups["b"].len(), 1);
    // sorted by time inside each group
    assert_eq!(groups["a"][0].ts_ms, 100);
    assert_eq!(groups["a"][1].ts_ms, 300);

    // the single-account path still works on top of the groups
    let solo = metering::load_events(&path, "b").unwrap();
    assert_eq!(solo.len(), 1);

    std::fs::remove_file(&path).ok();
}

#[test]
fn registry_loads_every_repo_policy() {
    use killowatt_core::policy;

    let registry = policy::load_registry();
    assert!(registry.contains_key("acme-prod"));
    assert!(registry.contains_key("infra-core"));
    assert_eq!(registry["infra-core"].action, "throttle");
    assert_eq!(registry["acme-prod"].action, "hard_stop");
}
