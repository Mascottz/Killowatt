use serde::Deserialize;
use std::collections::BTreeMap;
use std::fs;
use std::path::Path;

// a spend policy, mirrored from policies/schema.cue.
// money is integer cents; floats do not touch money.
#[derive(Debug, Clone, Deserialize)]
pub struct Policy {
    pub account: String,
    pub daily_limit_cents: u64,
    pub hourly_limit_cents: u64,
    pub burst: BurstLimit,
    #[serde(default)]
    pub exempt: Vec<String>,
    #[serde(default = "default_action")]
    pub action: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct BurstLimit {
    pub window_seconds: u64,
    pub limit_cents: u64,
}

fn default_action() -> String {
    "hard_stop".into()
}

impl Policy {
    // loads an exported policy json; tries the repo root layout first,
    // then the layout you get when running from core/.
    pub fn load() -> Policy {
        let candidates = ["policies/acme.json", "../policies/acme.json"];
        for p in candidates {
            if Path::new(p).exists() {
                let raw = fs::read_to_string(p).expect("policy file readable");
                let policy: Policy =
                    serde_json::from_str(&raw).expect("policy matches schema");
                return policy;
            }
        }
        // fallback so the demo always runs, matches policies/acme.cue
        Policy {
            account: "acme-prod".into(),
            daily_limit_cents: 250_00,
            hourly_limit_cents: 60_00,
            burst: BurstLimit {
                window_seconds: 600,
                limit_cents: 40_00,
            },
            exempt: vec!["rds-prod-backups".into()],
            action: "hard_stop".into(),
        }
    }

    pub fn is_exempt(&self, service: &str) -> bool {
        self.exempt.iter().any(|s| s == service)
    }
}

// every exported policy in the repo, keyed by account name. this is what
// cue export ./policies produces; one breaker per account, one registry.
pub fn load_registry() -> BTreeMap<String, Policy> {
    let candidates = ["policies/accounts.json", "../policies/accounts.json"];
    for p in candidates {
        if Path::new(p).exists() {
            let raw = fs::read_to_string(p).expect("registry readable");
            let by_key: BTreeMap<String, Policy> =
                serde_json::from_str(&raw).expect("registry matches schema");
            // re-key by the account the policy actually names, so the file
            // can use short keys while the breaker matches on real names.
            return by_key
                .into_values()
                .map(|pol| (pol.account.clone(), pol))
                .collect();
        }
    }
    let solo = Policy::load();
    let mut map = BTreeMap::new();
    map.insert(solo.account.clone(), solo);
    map
}
