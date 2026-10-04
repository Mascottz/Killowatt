use crate::ledger::{Event, Ledger};
use crate::policy::Policy;

// what the core decided about an event.
#[derive(Debug, Clone, PartialEq)]
pub enum Verdict {
    Allow,
    Throttle(String),
    HardStop(String),
    // watch mode; the limit broke but nothing was touched, and this is
    // what would have been stopped
    Watch(String),
    // already tripped; this spend is what got prevented
    Blocked,
}

// which window broke, and by how much.
struct Breach {
    spend: u64,
    limit: u64,
    window: &'static str,
}

pub struct Breaker {
    pub policy: Policy,
    ledger: Ledger,
    tripped_at: Option<u64>,
    watch_started_at: Option<u64>,
    pub prevented_cents: u64,
    pub would_have_saved_cents: u64,
    pub spent_at_trip_cents: u64,
}

impl Breaker {
    pub fn new(policy: Policy) -> Breaker {
        Breaker {
            policy,
            ledger: Ledger::new(),
            tripped_at: None,
            watch_started_at: None,
            prevented_cents: 0,
            would_have_saved_cents: 0,
            spent_at_trip_cents: 0,
        }
    }

    pub fn is_tripped(&self) -> bool {
        self.tripped_at.is_some()
    }

    pub fn is_watching(&self) -> bool {
        self.watch_started_at.is_some()
    }

    // one event in, one verdict out. three checks, in order;
    // burst first, then the hour, then the day.
    pub fn evaluate(&mut self, e: Event) -> Verdict {
        if self.is_tripped() {
            // exempt services keep running through a hard stop; only
            // non-exempt spend is spend we actually prevented.
            if !self.policy.is_exempt(&e.service) {
                self.prevented_cents += e.cents;
            }
            return Verdict::Blocked;
        }

        let service = e.service.clone();
        let cents = e.cents;
        self.ledger.record(e);
        self.ledger.prune(self.ledger_last_ts(), 3600);

        if self.policy.is_exempt(&service) {
            return Verdict::Allow;
        }

        let now_ms = self.ledger_last_ts();

        let breach = self.first_breach(now_ms);
        let Some(breach) = breach else {
            return Verdict::Allow;
        };

        let why = format!("{} blew the {}", service, breach.window);

        // watch mode; the limit broke, nothing gets touched, and from the
        // first breach onward every charge is counted as would-have-saved.
        if self.policy.action == "alert_only" {
            if self.watch_started_at.is_none() {
                self.watch_started_at = Some(now_ms);
            }
            self.would_have_saved_cents += cents;
            return Verdict::Watch(format!(
                "{}; {} of {} allowed",
                why,
                crate::money(breach.spend),
                crate::money(breach.limit)
            ));
        }

        self.trip(now_ms, breach, &why)
    }

    fn first_breach(&self, now_ms: u64) -> Option<Breach> {
        let burst = self.burst_spend(now_ms);
        if burst > self.policy.burst.limit_cents {
            return Some(Breach {
                spend: burst,
                limit: self.policy.burst.limit_cents,
                window: "burst window",
            });
        }

        let hour = self.hour_spend(now_ms);
        if hour > self.policy.hourly_limit_cents {
            return Some(Breach {
                spend: hour,
                limit: self.policy.hourly_limit_cents,
                window: "hourly limit",
            });
        }

        let day = self
            .ledger
            .spent_in_last(now_ms, 86_400, |s| self.policy.is_exempt(s));
        if day > self.policy.daily_limit_cents {
            return Some(Breach {
                spend: day,
                limit: self.policy.daily_limit_cents,
                window: "daily limit",
            });
        }

        None
    }

    fn trip(&mut self, ts_ms: u64, breach: Breach, why: &str) -> Verdict {
        self.tripped_at = Some(ts_ms);
        self.spent_at_trip_cents = breach.spend;
        let reason = format!(
            "{}; {} of {} allowed",
            why,
            crate::money(breach.spend),
            crate::money(breach.limit)
        );
        match self.policy.action.as_str() {
            "throttle" => Verdict::Throttle(reason),
            _ => Verdict::HardStop(reason),
        }
    }

    fn ledger_last_ts(&self) -> u64 {
        self.ledger.last_ts()
    }

    // current window spend, for gauges and state lines.
    pub fn burst_spend(&self, now_ms: u64) -> u64 {
        self.ledger.spent_in_last(
            now_ms,
            self.policy.burst.window_seconds,
            |s| self.policy.is_exempt(s),
        )
    }

    pub fn hour_spend(&self, now_ms: u64) -> u64 {
        self.ledger
            .spent_in_last(now_ms, 3600, |s| self.policy.is_exempt(s))
    }
}
