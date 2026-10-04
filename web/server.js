// killowatt web; zero dependencies on purpose.
// serves the dashboard and runs the same runaway loop demo the rust core runs,
// one frame at a time over server-sent events.

const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = process.env.PORT || 8080;
const TICK_MS = 600; // one frame
const SECS_PER_TICK = 30; // each frame stands in for 30 simulated seconds
const WINDOW_TICKS = 20; // burst window; 10 simulated minutes
const HOUR_TICKS = 120;
const BURST_LIMIT = 4000; // cents, matches policies/acme.cue
const HOURLY_LIMIT = 6000;
const RUNAWAY_AT = 10; // the retry loop starts here
const RUNAWAY_CENTS = 210; // per tick, the loop billing the same request over and over

const clients = new Set();

// zero deps means a zero-dep static table too.
const STATIC = {
  "/": ["index.html", "text/html; charset=utf-8"],
  "/index.html": ["index.html", "text/html; charset=utf-8"],
  "/style.css": ["style.css", "text/css; charset=utf-8"],
  "/app.js": ["app.js", "text/javascript; charset=utf-8"],
};

function makeSim(mode) {
  return {
    t: 0,
    mode: mode || "hard_stop", // hard_stop is armed; alert_only is watch mode
    acme: { ledger: [], tripped: false, warned: false, watching: false, prevented: 0, would_have_saved: 0, spent: 0 },
    staging: { ledger: [], tripped: false, warned: false, watching: false, prevented: 0, would_have_saved: 0, spent: 0 },
    infra: { ledger: [], tripped: false, warned: false, watching: false, prevented: 0, would_have_saved: 0, spent: 0 },
    logs: [],
  };
}

let sim = makeSim();

function spentSince(account, t, windowTicks, skipService) {
  const horizon = t - windowTicks;
  let sum = 0;
  for (const e of account.ledger) {
    if (e.t >= horizon && e.service !== skipService) sum += e.cents;
  }
  return sum;
}

function fmtSimTime(t) {
  const secs = t * SECS_PER_TICK;
  const mm = String(Math.floor(secs / 60)).padStart(2, "0");
  const ss = String(secs % 60).padStart(2, "0");
  return `t+${mm}:${ss}`;
}

function money(cents) {
  return `$${Math.floor(cents / 100)}.${String(cents % 100).padStart(2, "0")}`;
}

function pushLog(cls, text) {
  sim.logs.push({ cls, text });
  if (sim.logs.length > 60) sim.logs.shift();
}

// one frame of the simulation. mirrors the rust core; burst first, then the hour.
function tick() {
  sim.t += 1;
  const t = sim.t;
  const logs = [];
  const note = (cls, text) => {
    logs.push({ cls, text });
    pushLog(cls, text);
  };

  const tickEvents = {
    acme: [
      { service: "api-gateway", cents: 10, exempt: false },
      { service: "rds-prod-backups", cents: 70, exempt: true },
      {
        service: "durable-objects",
        cents: 5 + (t >= RUNAWAY_AT ? RUNAWAY_CENTS : 0),
        exempt: false,
      },
    ],
    staging: [{ service: "web-app", cents: 8, exempt: false }],
    infra: [{ service: "queue-workers", cents: 12, exempt: false }],
  };

  // acme; the account with the policy and the problem.
  const acme = sim.acme;
  let acmeTickSpend = 0;
  for (const ev of tickEvents.acme) {
    if (acme.tripped) {
      if (!ev.exempt) {
        acme.prevented += ev.cents;
      } else {
        acme.ledger.push({ t, service: ev.service, cents: ev.cents });
        acme.spent += ev.cents;
        acmeTickSpend += ev.cents;
      }
      continue;
    }
    acme.ledger.push({ t, service: ev.service, cents: ev.cents });
    if (!ev.exempt) acmeTickSpend += ev.cents;
    acme.spent += ev.cents;
  }
  // prune
  const horizon = t - HOUR_TICKS;
  acme.ledger = acme.ledger.filter((e) => e.t >= horizon);

  if (!acme.tripped) {
    const burst = spentSince(acme, t, WINDOW_TICKS, "rds-prod-backups");
    const hour = spentSince(acme, t, HOUR_TICKS, "rds-prod-backups");

    const breached =
      burst > BURST_LIMIT
        ? { spend: burst, limit: BURST_LIMIT, window: "burst window" }
        : hour > HOURLY_LIMIT
          ? { spend: hour, limit: HOURLY_LIMIT, window: "hourly limit" }
          : null;

    if (breached && sim.mode === "alert_only") {
      // watch mode; the limit broke, nothing gets touched, and from the
      // first breach onward every non-exempt charge is would-have-saved.
      if (!acme.watching) {
        acme.watching = true;
        note(
          "warn",
          `${fmtSimTime(t)}  WATCH durable-objects blew the ${breached.window}; ${money(
            breached.spend
          )} of ${money(breached.limit)} allowed`
        );
        note("warn", `${fmtSimTime(t)}  note  nothing touched; killowatt would have stopped this`);
      }
      acme.would_have_saved += acmeTickSpend;
      if (t % 6 === 0) {
        note(
          "allow",
          `${fmtSimTime(t)}  watch still burning; would have saved ${money(acme.would_have_saved)} by now`
        );
      }
    } else if (breached) {
      acme.tripped = true;
      note(
        "trip",
        `${fmtSimTime(t)}  TRIP  durable-objects blew the ${breached.window}; ${money(
          breached.spend
        )} of ${money(breached.limit)} allowed`
      );
      note(
        "trip",
        `${fmtSimTime(t)}  stop  suspended durable-objects on acme-prod → action hard_stop`
      );
    } else if (!acme.warned && burst >= BURST_LIMIT * 0.8) {
      acme.warned = true;
      note(
        "warn",
        `${fmtSimTime(t)}  near  burst window at ${Math.round((burst / BURST_LIMIT) * 100)}%; durable-objects is the loud one`
      );
    } else if (t % 4 === 0) {
      note(
        "allow",
        `${fmtSimTime(t)}  allow acme-prod burst ${money(burst)} of ${money(BURST_LIMIT)}`
      );
    }
  } else if (t % 6 === 0) {
    note("blocked", `${fmtSimTime(t)}  blocked prevented ${money(acme.prevented)} so far`);
  }

  // the quiet accounts; recorded for the sparklines.
  for (const name of ["staging", "infra"]) {
    const acc = sim[name];
    let accSpend = 0;
    for (const ev of tickEvents[name]) {
      acc.ledger.push({ t, service: ev.service, cents: ev.cents });
      acc.spent += ev.cents;
      accSpend += ev.cents;
    }
    acc.ledger = acc.ledger.filter((e) => e.t >= horizon);
    acc.lastTick = accSpend;
  }
  acme.lastTick = acmeTickSpend;

  const state = {
    sim_time: fmtSimTime(t),
    tick: t,
    mode: sim.mode,
    totals: {
      spent: acme.spent + sim.staging.spent + sim.infra.spent,
      prevented: acme.prevented,
      saved: acme.would_have_saved,
    },
    accounts: [
      {
        name: "acme-prod",
        spent: acme.spent,
        tripped: acme.tripped,
        watching: acme.watching,
        prevented: acme.prevented,
        would_have_saved: acme.would_have_saved,
        burst_pct: Math.min(
          140,
          Math.round((spentSince(acme, t, WINDOW_TICKS, "rds-prod-backups") / BURST_LIMIT) * 100)
        ),
        tick_cents: acme.lastTick,
      },
      { name: "staging", spent: sim.staging.spent, tripped: false, watching: false, tick_cents: sim.staging.lastTick },
      { name: "infra-core", spent: sim.infra.spent, tripped: false, watching: false, tick_cents: sim.infra.lastTick },
    ],
  };

  broadcast({ type: "frame", state, logs });
}

function broadcast(obj) {
  const data = `data: ${JSON.stringify(obj)}\n\n`;
  for (const res of clients) res.write(data);
}

setInterval(tick, TICK_MS);
setInterval(() => {
  for (const res of clients) res.write(": ping\n\n");
}, 15000);

const server = http.createServer((req, res) => {
  if (req.method === "GET" && STATIC[req.url]) {
    const [file, type] = STATIC[req.url];
    res.writeHead(200, { "Content-Type": type });
    res.end(fs.readFileSync(path.join(__dirname, "public", file)));
    return;
  }

  if (req.method === "GET" && req.url === "/api/stream") {
    res.writeHead(200, {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    });
    res.write(": killowatt stream\n\n");
    clients.add(res);
    req.on("close", () => clients.delete(res));
    return;
  }

  if (req.method === "POST" && req.url.startsWith("/api/reset")) {
    const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
    const mode = url.searchParams.get("mode") === "watch" ? "alert_only" : "hard_stop";
    sim = makeSim(mode);
    broadcast({ type: "reset", mode: sim.mode });
    res.writeHead(202, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ ok: true, mode: sim.mode }));
    return;
  }

  res.writeHead(404, { "Content-Type": "text/plain" });
  res.end("not found");
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`killowatt dashboard on http://0.0.0.0:${PORT}`);
});
