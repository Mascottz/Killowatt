(function () {
  "use strict";

  var CIRC = 452.4;
  var history = { acme: [], staging: [], infra: [] };

  function $(id) { return document.getElementById(id); }

  function money(cents) {
    return "$" + Math.floor(cents / 100) + "." + String(cents % 100).padStart(2, "0");
  }

  function setRing(pct, tripped) {
    var capped = Math.min(pct, 100);
    $("ringFill").style.strokeDashoffset = String(CIRC * (1 - capped / 100));
    $("ringPct").textContent = Math.round(pct) + "%";
    $("ring").classList.toggle("hot", pct >= 75 && !tripped);
  }

  function drawSpark(id, points, tripped) {
    var svg = $(id);
    if (!points.length) { svg.innerHTML = ""; return; }
    var max = Math.max.apply(null, points.concat([20]));
    var step = 240 / Math.max(points.length - 1, 1);
    var coords = points.map(function (p, i) {
      var x = i * step;
      var y = 36 - (p / max) * 32;
      return x.toFixed(1) + "," + y.toFixed(1);
    });
    var color = tripped ? "#E2794F" : "#C98E5F";
    svg.innerHTML =
      '<polyline points="' + coords.join(" ") + '" fill="none" stroke="' + color +
      '" stroke-width="1.6" stroke-linejoin="round" opacity="0.85"/>';
  }

  function pushHistory(key, val) {
    history[key].push(val);
    if (history[key].length > 48) history[key].shift();
  }

  var logEl = $("log");
  function appendLogs(logs) {
    logs.forEach(function (l) {
      var div = document.createElement("div");
      div.className = "line " + l.cls;
      div.textContent = l.text;
      logEl.appendChild(div);
    });
    while (logEl.children.length > 80) logEl.removeChild(logEl.firstChild);
    logEl.scrollTop = logEl.scrollHeight;
  }

  function applyFrame(frame) {
    var s = frame.state;
    currentMode = s.mode || currentMode;
    var watchMode = currentMode === "alert_only";
    setModeButtons(currentMode);

    document.body.classList.toggle("tripped", s.accounts[0].tripped);
    document.body.classList.toggle("watchhit", watchMode && s.accounts[0].watching);

    $("simTime").textContent = s.sim_time;
    $("statSpent").textContent = money(s.totals.spent);
    $("statBurst").textContent = s.accounts[0].burst_pct + "%";

    if (watchMode) {
      $("statSavedLabel").textContent = "would have saved, watch mode";
      $("statPrevented").textContent = money(s.totals.saved);
      $("statSavedHint").textContent = "nothing refused; everything noted";
      $("watchSaved").textContent = money(s.totals.saved);
    } else {
      $("statSavedLabel").textContent = "prevented by the breaker";
      $("statPrevented").textContent = money(s.totals.prevented);
      $("statSavedHint").textContent = "everything refused after the trip";
      $("bannerPrevented").textContent = money(s.totals.prevented);
    }

    var acme = s.accounts[0];
    $("acmeSpend").innerHTML = money(acme.spent) + "<small>today</small>";
    $("stagingSpend").innerHTML = money(s.accounts[1].spent) + "<small>today</small>";
    $("infraSpend").innerHTML = money(s.accounts[2].spent) + "<small>today</small>";

    setRing(acme.burst_pct, acme.tripped);
    $("legendSpend").textContent = money(Math.round(acme.burst_pct / 100 * 4000));

    var tag = $("acmeTag");
    if (acme.tripped) {
      tag.textContent = "open → stopped"; tag.className = "tag trip";
    } else if (watchMode && acme.watching) {
      tag.textContent = "watching → would stop"; tag.className = "tag warn";
    } else if (acme.burst_pct >= 75) {
      tag.textContent = "approaching"; tag.className = "tag warn";
    } else {
      tag.textContent = "calm"; tag.className = "tag";
    }

    // the seal shows the posture; ember belongs to a real trip only
    $("sealState").textContent = watchMode ? "watching" : (acme.tripped ? "open" : "closed");

    pushHistory("acme", acme.tick_cents);
    pushHistory("staging", s.accounts[1].tick_cents);
    pushHistory("infra", s.accounts[2].tick_cents);
    drawSpark("acmeSpark", history.acme, acme.tripped);
    drawSpark("stagingSpark", history.staging, false);
    drawSpark("infraSpark", history.infra, false);

    if (frame.logs && frame.logs.length) appendLogs(frame.logs);
  }

  function reset() {
    history = { acme: [], staging: [], infra: [] };
    logEl.innerHTML = '<div class="line sys">killowatt; replaying the incident from the top</div>';
    document.body.classList.remove("tripped");
    document.body.classList.remove("watchhit");
  }

  var currentMode = "hard_stop";

  function setModeButtons(mode) {
    $("modeArmed").classList.toggle("active", mode !== "alert_only");
    $("modeWatch").classList.toggle("active", mode === "alert_only");
  }

  var es = new EventSource("/api/stream");
  es.onmessage = function (ev) {
    var frame = JSON.parse(ev.data);
    if (frame.type === "frame") applyFrame(frame);
    if (frame.type === "reset") {
      currentMode = frame.mode || "hard_stop";
      setModeButtons(currentMode);
      reset();
    }
  };

  $("resetBtn").addEventListener("click", function () {
    var q = currentMode === "alert_only" ? "?mode=watch" : "";
    fetch("/api/reset" + q, { method: "POST" });
  });

  $("modeArmed").addEventListener("click", function () {
    if (currentMode !== "hard_stop") fetch("/api/reset", { method: "POST" });
  });

  $("modeWatch").addEventListener("click", function () {
    if (currentMode !== "alert_only") fetch("/api/reset?mode=watch", { method: "POST" });
  });
})();
