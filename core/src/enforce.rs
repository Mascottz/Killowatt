use serde::Serialize;
use std::path::PathBuf;

// what a trip turns into. reversible first, lethal later.
#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Action {
    Suspend,
    ScaleToZero,
    Kill,
    Throttle,
}

impl Action {
    pub fn label(&self) -> &'static str {
        match self {
            Action::Suspend => "suspend",
            Action::ScaleToZero => "scale to zero",
            Action::Kill => "kill",
            Action::Throttle => "throttle",
        }
    }
}

// one enforcement order, serialized verbatim into the audit trail.
#[derive(Debug, Clone, Serialize)]
pub struct Order {
    pub account: String,
    pub service: String,
    pub action: Action,
    pub policy_action: String,
    pub reason: String,
    pub at_ms: u64,
}

// the enforcer acts and reports what it did; the replay timestamps it
// and prints it. watch mode never reaches an enforcer at all.
pub trait Enforcer {
    fn enforce(&mut self, order: &Order) -> Result<String, String>;
}

// the default; it reports what would happen and touches nothing.
#[derive(Debug, Default)]
pub struct DryRun {
    pub orders: Vec<Order>,
}

impl DryRun {
    pub fn new() -> DryRun {
        DryRun { orders: Vec::new() }
    }
}

impl Enforcer for DryRun {
    fn enforce(&mut self, order: &Order) -> Result<String, String> {
        self.orders.push(order.clone());
        Ok(format!(
            "dry-run; would {} {} on {} → reversible, no api called",
            order.action.label(),
            order.service,
            order.account
        ))
    }
}

// every order appended as one json line; the record you show when
// someone asks what the breaker did at three in the morning.
pub struct AuditLog {
    path: PathBuf,
}

impl AuditLog {
    pub fn new(path: impl Into<PathBuf>) -> AuditLog {
        AuditLog { path: path.into() }
    }

    pub fn path(&self) -> &std::path::Path {
        &self.path
    }
}

impl Enforcer for AuditLog {
    fn enforce(&mut self, order: &Order) -> Result<String, String> {
        use std::io::Write;

        let mut line = serde_json::to_string(order).map_err(|e| e.to_string())?;
        line.push('\n');

        let mut file = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.path)
            .map_err(|e| format!("cannot open audit log; {}", e))?;

        file.write_all(line.as_bytes())
            .map_err(|e| format!("cannot write audit log; {}", e))?;

        Ok(format!("audit; order appended to {}", self.path.display()))
    }
}

// what a trip turns into under a given policy action; watch mode
// produces no order at all, because it never touches anything.
pub fn order_for(
    policy_action: &str,
    account: &str,
    service: &str,
    reason: &str,
    at_ms: u64,
) -> Option<Order> {
    let action = match policy_action {
        "hard_stop" => Action::Suspend,
        "throttle" => Action::Throttle,
        _ => return None,
    };

    Some(Order {
        account: account.to_string(),
        service: service.to_string(),
        action,
        policy_action: policy_action.to_string(),
        reason: reason.to_string(),
        at_ms,
    })
}
