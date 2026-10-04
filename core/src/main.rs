use std::path::Path;
use std::process::ExitCode;

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
    eprintln!("  killowatt                 the built-in incident, replayed armed and watching");
    eprintln!("  killowatt ingest <file>   replay a billing export through the breaker");
    eprintln!();
    eprintln!("export shape; one json object per line, money in integer cents");
    eprintln!(r#"  {{"account":"acme-prod","service":"api","cents":120,"ts_ms":1696000000000}}"#);
}

// real billing data, same treatment as the demo; armed and watch, side by side.
fn ingest(path_str: &str) -> ExitCode {
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
    let armed_out = report::replay(&armed, &events);

    println!();
    println!("replay two; watch mode, same export, action alert_only");
    println!("--------------------------------------------------");
    let mut watch = policy.clone();
    watch.action = "alert_only".into();
    let watch_out = report::replay(&watch, &events);

    report::pitch(&armed_out, &watch_out);
    ExitCode::SUCCESS
}
