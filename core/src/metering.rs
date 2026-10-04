use crate::ledger::Event;
use serde::Deserialize;
use std::fs;
use std::path::Path;

// one line of a billing export, in the wire shape from proto/killowatt.proto.
#[derive(Debug, Clone, Deserialize)]
struct BillLine {
    account: String,
    service: String,
    cents: u64,
    ts_ms: u64,
}

// load a billing export; one json object per line, any order, any account mix.
// events come back sorted by time, filtered to the account we care about,
// because a breaker decides per account.
pub fn load_events(path: &Path, account: &str) -> Result<Vec<Event>, String> {
    let raw = fs::read_to_string(path)
        .map_err(|e| format!("cannot read {}: {}", path.display(), e))?;

    let mut all: Vec<BillLine> = Vec::new();
    for (n, line) in raw.lines().enumerate() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let parsed: BillLine = serde_json::from_str(line)
            .map_err(|e| format!("line {} is not a bill event; {}", n + 1, e))?;
        all.push(parsed);
    }

    if all.is_empty() {
        return Err("the export is empty; nothing to replay".into());
    }

    let for_account: Vec<BillLine> = all
        .iter()
        .filter(|l| l.account == account)
        .cloned()
        .collect();

    let (picked, dropped) = if for_account.is_empty() {
        (all, 0usize)
    } else {
        let dropped = all.len() - for_account.len();
        (for_account, dropped)
    };

    let mut events: Vec<Event> = picked
        .into_iter()
        .map(|l| Event {
            ts_ms: l.ts_ms,
            service: l.service,
            cents: l.cents,
        })
        .collect();
    events.sort_by_key(|e| e.ts_ms);

    if dropped > 0 {
        eprintln!(
            "note; {} events belonged to other accounts and were set aside",
            dropped
        );
    }

    Ok(events)
}
