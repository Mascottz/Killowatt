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
// events come back grouped by account and sorted by time within each group,
// because a breaker decides per account.
pub fn load_events_by_account(
    path: &Path,
) -> Result<std::collections::BTreeMap<String, Vec<Event>>, String> {
    let raw = fs::read_to_string(path)
        .map_err(|e| format!("cannot read {}: {}", path.display(), e))?;

    let mut groups: std::collections::BTreeMap<String, Vec<Event>> =
        std::collections::BTreeMap::new();
    let mut count = 0usize;

    for (n, line) in raw.lines().enumerate() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let parsed: BillLine = serde_json::from_str(line)
            .map_err(|e| format!("line {} is not a bill event; {}", n + 1, e))?;
        groups.entry(parsed.account).or_default().push(Event {
            ts_ms: parsed.ts_ms,
            service: parsed.service,
            cents: parsed.cents,
        });
        count += 1;
    }

    if count == 0 {
        return Err("the export is empty; nothing to replay".into());
    }

    for events in groups.values_mut() {
        events.sort_by_key(|e| e.ts_ms);
    }

    Ok(groups)
}

// load a billing export for one account; the single-account path, a thin
// wrapper over the grouped loader.
pub fn load_events(path: &Path, account: &str) -> Result<Vec<Event>, String> {
    let groups = load_events_by_account(path)?;

    if let Some(events) = groups.get(account) {
        return Ok(events.clone());
    }

    // no events named for this account; replay everything, like before, so a
    // mis-labelled export still shows up in the output.
    let mut all: Vec<Event> = groups.into_values().flatten().collect();
    all.sort_by_key(|e| e.ts_ms);
    eprintln!(
        "note; no events named {} in this export; replaying the whole thing",
        account
    );
    Ok(all)
}
