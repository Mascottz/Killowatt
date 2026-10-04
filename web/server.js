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

function makeSim() {
  return {
    t: 0,
    acme: { ledger: [], tripped: false, warned: false, prevented: 0, spent: 0 },
    staging: { ledger: [], tripped: false, warned: false, prevented: 0, spent: 0 },
    infra: { ledger: [], tripped: false, warned: false, prevented: 0, spent: 0 },
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

    if (burst > BURST_LIMIT) {
      acme.tripped = true;
      note(
        "trip",
        `${fmtSimTime(t)}  TRIP  durable-objects blew the burst window; ${money(burst)} of ${money(
          BURST_LIMIT
        )} allowed`
      );
      note(
        "trip",
        `${fmtSimTime(t)}  stop  suspended durable-objects on acme-prod → action hard_stop`
      );
    } else if (hour > HOURLY_LIMIT) {
      acme.tripped = true;
      note("trip", `${fmtSimTime(t)}  TRIP  hourly limit; ${money(hour)} of ${money(HOURLY_LIMIT)} allowed`);
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
    totals: {
      spent: acme.spent + sim.staging.spent + sim.infra.spent,
      prevented: acme.prevented,
    },
    accounts: [
      {
        name: "acme-prod",
        spent: acme.spent,
        tripped: acme.tripped,
        prevented: acme.prevented,
        burst_pct: Math.min(
          140,
          Math.round((spentSince(acme, t, WINDOW_TICKS, "rds-prod-backups") / BURST_LIMIT) * 100)
        ),
        tick_cents: acme.lastTick,
      },
      { name: "staging", spent: sim.staging.spent, tripped: false, tick_cents: sim.staging.lastTick },
      { name: "infra-core", spent: sim.infra.spent, tripped: false, tick_cents: sim.infra.lastTick },
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
  if (req.method === "GET" && (req.url === "/" || req.url === "/index.html")) {
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(fs.readFileSync(path.join(__dirname, "public", "index.html")));
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

  if (req.method === "POST" && req.url === "/api/reset") {
    sim = makeSim();
    broadcast({ type: "reset" });
    res.writeHead(202, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ ok: true }));
    return;
  }

  res.writeHead(404, { "Content-Type": "text/plain" });
  res.end("not found");
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`killowatt dashboard on http://0.0.0.0:${PORT}`);
});
