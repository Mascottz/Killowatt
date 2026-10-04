use std::path::Path;
use std::process::ExitCode;

use killowatt_core::enforce::{AuditLog, DryRun, Enforcer};
use killowatt_core::{metering, money, policy, report, sim};

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();

    match args.first().map(String::as_str) {
        None | Some("sim") | Some("demo") => {
            sim::run();
            ExitCode::SUCCESS
        }
        Some("ingest") => match args.get(1) {
            Some(path) => ingest(path),
            None => {
                usage();
                ExitCode::FAILURE
            }
        },
        Some("--help") | Some("help") => {
            usage();
            ExitCode::SUCCESS
        }
        Some(cmd) => {
            eprintln!("unknown command; {}", cmd);
            usage();
            ExitCode::FAILURE
        }
    }
}

fn usage() {
    eprintln!("killowatt core");
    eprintln!("  killowatt                       the built-in incident, replayed armed and watching");
    eprintln!("  killowatt ingest <file>         replay a billing export through the breaker");
    eprintln!("  killowatt ingest <file> --audit <path>");
    eprintln!("                                  same, and append every enforcement order to a jsonl log");
    eprintln!();
    eprintln!("export shape; one json object per line, money in integer cents");
    eprintln!(r#"  {{"account":"acme-prod","service":"api","cents":120,"ts_ms":1696000000000}}"#);
}

// real billing data, same treatment as the demo; armed and watch, side by side.
// enforcement defaults to dry-run; --audit <path> appends every order to a log.
fn ingest(path_str: &str) -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    let enforcer: Box<dyn Enforcer> =
        match args.iter().position(|a| a == "--audit").and_then(|i| args.get(i + 1)) {
            Some(audit_path) => Box::new(AuditLog::new(audit_path)),
            None => Box::new(DryRun::new()),
        };

    let policy = policy::Policy::load();
    let path = Path::new(path_str);

    let events = match metering::load_events(path, &policy.account) {
        Ok(events) => events,
        Err(msg) => {
            eprintln!("ingest failed; {}", msg);
            return ExitCode::FAILURE;
        }
    };

    println!(
        "killowatt core; ingesting {} against the {} policy",
        path.display(),
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

    println!();
    println!("replay one; the breaker armed, action hard_stop");
    println!("--------------------------------------------------");
    let mut armed = policy.clone();
    armed.action = "hard_stop".into();
    let mut enforcer = enforcer;
    let armed_out = report::replay(&armed, &events, enforcer.as_mut());

    println!();
    println!("replay two; watch mode, same export, action alert_only");
    println!("--------------------------------------------------");
    let mut watch = policy.clone();
    watch.action = "alert_only".into();
    let watch_out = report::replay(&watch, &events, enforcer.as_mut());

    report::pitch(&armed_out, &watch_out);
    ExitCode::SUCCESS
}
