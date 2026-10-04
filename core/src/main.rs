mod breaker;
mod ledger;
mod policy;
mod sim;

// money prints from integer cents; no floats anywhere near money.
pub fn money(cents: u64) -> String {
    format!("${}.{:02}", cents / 100, cents % 100)
}

// t+mm:ss for log lines.
pub fn fmt_t(ms: u64) -> String {
    let secs = ms / 1000;
    format!("t+{:02}:{:02}", secs / 60, secs % 60)
}

fn main() {
    sim::run();
}
