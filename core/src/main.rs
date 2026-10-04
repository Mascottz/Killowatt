use std::path::Path;
use std::process::ExitCode;

use killowatt_core::enforce::{AuditLog, DryRun, Enforcer};
use killowatt_core::{fmt_t, metering, money, policy, report, sim};

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
    eprintln!("  killowatt ingest <file> --verbose");
    eprintln!("                                  same, with the full transcript per account");
    eprintln!();
    eprintln!("export shape; one json object per line, money in integer cents");
    eprintln!(r#"  {{"account":"acme-prod","service":"api","cents":120,"ts_ms":1696000000000}}"#);
}

// real billing data, same treatment as the demo; every account in the
// export gets its own policy and its own breaker, armed and watching.
// enforcement defaults to dry-run; --audit <path> appends every order to a
// log, --verbose prints the full transcript per account.
fn ingest(path_str: &str) -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    let verbose = args.iter().any(|a| a == "--verbose");
    let mut enforcer: Box<dyn Enforcer> =
        match args.iter().position(|a| a == "--audit").and_then(|i| args.get(i + 1)) {
            Some(audit_path) => Box::new(AuditLog::new(audit_path)),
            None => Box::new(DryRun::new()),
        };

    let registry = policy::load_registry();
    let path = Path::new(path_str);

    let groups = match metering::load_events_by_account(path) {
        Ok(groups) => groups,
        Err(msg) => {
            eprintln!("ingest failed; {}", msg);
            return ExitCode::FAILURE;
        }
    };

    println!("killowatt core; ingesting {}", path.display());
    println!(
        "registry; {} policies → {}",
        registry.len(),
        registry
            .iter()
            .map(|(account, p)| format!("{} ({})", account, p.action))
            .collect::<Vec<_>>()
            .join(", ")
    );

    for (account, events) in &groups {
        let Some(policy) = registry.get(account) else {
            println!();
            println!("{}", account);
            println!("  no policy; {} events set aside", events.len());
            continue;
        };

        println!();
        println!("{}; action {}", account, policy.action);

        let armed_out = if verbose {
            println!("  the breaker armed");
            report::replay(policy, events, enforcer.as_mut(), true)
        } else {
            report::replay(policy, events, enforcer.as_mut(), false)
        };

        let mut watch = policy.clone();
        watch.action = "alert_only".into();
        let watch_out = if verbose {
            println!("  watch mode, same events");
            report::replay(&watch, events, enforcer.as_mut(), true)
        } else {
            report::replay(&watch, events, enforcer.as_mut(), false)
        };

        match (armed_out.crossed_at, armed_out.cross_window) {
            (Some(ts), window) => {
                let window = window.unwrap_or_else(|| "a limit".into());
                let verb = if policy.action == "throttle" {
                    "throttled"
                } else {
                    "stopped"
                };
                println!(
                    "  armed  {} at {} on the {}; spent {}, prevented {}",
                    verb,
                    fmt_t(ts - armed_out.first_ts),
                    window,
                    money(armed_out.spent_at_cross_cents),
                    money(armed_out.prevented_cents)
                );
            }
            _ => println!("  armed  quiet; nothing crossed a limit"),
        }

        if watch_out.crossed_at.is_some() {
            println!(
                "  watch  touched nothing; would have saved {}",
                money(watch_out.saved_cents)
            );
        } else {
            println!("  watch  quiet too; {} spent, nothing to stop", money(watch_out.total_spend_cents));
        }
    }

    println!();
    println!("watch mode is how you earn the right to arm the breaker");
    ExitCode::SUCCESS
}
