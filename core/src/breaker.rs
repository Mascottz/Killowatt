use crate::ledger::{Event, Ledger};
use crate::policy::Policy;

// what the core decided about an event.
#[derive(Debug, Clone, PartialEq)]
pub enum Verdict {
    Allow,
    Throttle(String),
    HardStop(String),
    // already tripped; this spend is what got prevented
    Blocked,
}

pub struct Breaker {
    pub policy: Policy,
    ledger: Ledger,
    tripped_at: Option<u64>,
    pub prevented_cents: u64,
    pub spent_at_trip_cents: u64,
}

impl Breaker {
    pub fn new(policy: Policy) -> Breaker {
        Breaker {
            policy,
            ledger: Ledger::new(),
            tripped_at: None,
            prevented_cents: 0,
            spent_at_trip_cents: 0,
        }
    }

    pub fn is_tripped(&self) -> bool {
        self.tripped_at.is_some()
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
        self.ledger.record(e);
        self.ledger.prune(self.ledger_last_ts(), 3600);

        if self.policy.is_exempt(&service) {
            return Verdict::Allow;
        }

        let now_ms = self.ledger_last_ts();

        let burst_spend = self.ledger.spent_in_last(
            now_ms,
            self.policy.burst.window_seconds,
            |s| self.policy.is_exempt(s),
        );
        if burst_spend > self.policy.burst.limit_cents {
            return self.trip(
                now_ms,
                burst_spend,
                self.policy.burst.limit_cents,
                &format!("{} blew the burst window", service),
            );
        }

        let hour_spend = self
            .ledger
            .spent_in_last(now_ms, 3600, |s| self.policy.is_exempt(s));
        if hour_spend > self.policy.hourly_limit_cents {
            return self.trip(
                now_ms,
                hour_spend,
                self.policy.hourly_limit_cents,
                &format!("{} blew the hourly limit", service),
            );
        }

        let day_spend = self
            .ledger
            .spent_in_last(now_ms, 86_400, |s| self.policy.is_exempt(s));
        if day_spend > self.policy.daily_limit_cents {
            return self.trip(
                now_ms,
                day_spend,
                self.policy.daily_limit_cents,
                &format!("{} blew the daily limit", service),
            );
        }

        Verdict::Allow
    }

    fn trip(&mut self, ts_ms: u64, spend: u64, limit: u64, why: &str) -> Verdict {
        self.tripped_at = Some(ts_ms);
        self.spent_at_trip_cents = spend;
        let reason = format!(
            "{}; {} of {} allowed",
            why,
            crate::money(spend),
            crate::money(limit)
        );
        // the policy decides what a trip does; alert_only is not wired yet
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
