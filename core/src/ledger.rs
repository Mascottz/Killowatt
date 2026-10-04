use std::collections::VecDeque;

// one unit of spend, straight from metering.
#[derive(Debug, Clone)]
pub struct Event {
    pub ts_ms: u64,
    pub service: String,
    pub cents: u64,
}

// rolling spend history for one account. oldest entries age out;
// the only windows that ever matter are the hour and the burst window.
pub struct Ledger {
    entries: VecDeque<Event>,
}

impl Ledger {
    pub fn new() -> Self {
        Ledger {
            entries: VecDeque::new(),
        }
    }

    pub fn record(&mut self, e: Event) {
        self.entries.push_back(e);
    }

    pub fn last_ts(&self) -> u64 {
        self.entries.back().map(|e| e.ts_ms).unwrap_or(0)
    }

    // drop anything older than the window we still care about.
    pub fn prune(&mut self, now_ms: u64, keep_seconds: u64) {
        let horizon = now_ms.saturating_sub(keep_seconds * 1000);
        while let Some(front) = self.entries.front() {
            if front.ts_ms < horizon {
                self.entries.pop_front();
            } else {
                break;
            }
        }
    }

    // sum over the trailing window, skipping exempt services.
    pub fn spent_in_last<F>(&self, now_ms: u64, seconds: u64, exempt: F) -> u64
    where
        F: Fn(&str) -> bool,
    {
        let horizon = now_ms.saturating_sub(seconds * 1000);
        self.entries
            .iter()
            .filter(|e| e.ts_ms >= horizon && !exempt(&e.service))
            .map(|e| e.cents)
            .sum()
    }
}
