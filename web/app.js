import { cycleYears, validateData, compare, ratio, csv } from "./core.js";
import {
  purchasingPower,
  inflationScenario,
  emptyPlan,
  validatePlan,
  planSummary,
  planningReport,
} from "./planning.js";
const $ = (s) => document.querySelector(s),
  escape = (s) =>
    String(s).replace(
      /[&<>"']/g,
      (c) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        })[c],
    );
const fmt = (n) =>
  new Intl.NumberFormat("de-DE", { maximumFractionDigits: 2 }).format(n);
const colors = [
  "#0f1c3d",
  "#99613a",
  "#267468",
  "#933d61",
  "#65569d",
  "#9d561d",
  "#276f9c",
  "#746414",
  "#ad3152",
  "#354f39",
];
let content,
  data,
  demo,
  provenance = null,
  config = { partner: "", theme: "navy" },
  selection = ["gold", "dax"],
  from = 1926,
  to = 2026,
  real = false;
let settingsMessage = "",
  dataRequestPending = false;
let planning,
  plan,
  planError = "",
  planMessage = "";
let historyAmount = "10000",
  historyFrom = null,
  historyTo = null,
  scenarioAmount = "10000",
  scenarioRate = "3",
  scenarioYears = "10";
const storage = {
  get(k) {
    try {
      return localStorage.getItem(k);
    } catch {
      return null;
    }
  },
  set(k, v) {
    try {
      localStorage.setItem(k, v);
    } catch {
      throw Error("Lokaler Speicher nicht verfügbar oder voll.");
    }
  },
  remove(k) {
    try {
      localStorage.removeItem(k);
    } catch {
      throw Error("Lokaler Speicher konnte nicht gelöscht werden.");
    }
  },
};
function setMessage(message) {
  settingsMessage = message;
  const result = $("#settings-result");
  if (result) result.textContent = message;
}
function installData(next, info = null) {
  validateData(next);
  storage.set("crisis-data", JSON.stringify({ data: next, provenance: info }));
  data = next;
  provenance = info;
  historyFrom=null;historyTo=null;
  selection = data.series.slice(0, 2).map((s) => s.id);
  const years = data.series.flatMap((s) => s.points.map((p) => p.year));
  from = Math.min(...years);
  to = Math.max(...years);
}
function provenanceNote() {
  if (!provenance) return "";
  const parts = [
    provenance.provider ? `Quelle: ${provenance.provider}` : "",
    provenance.fetchedAt ? `Abgerufen: ${provenance.fetchedAt}` : "",
    provenance.cached ? "Gespeicherter Abruf" : "",
    provenance.stale ? "Daten sind veraltet; kein aktueller Kurs" : "",
    ...(Array.isArray(provenance.notes) ? provenance.notes : []),
  ].filter(Boolean);
  return `<p class="small muted">${escape(parts.join(" · "))}</p>`;
}
function quotesPanel() {
  if (!Array.isArray(provenance?.quotes) || !provenance.quotes.length)
    return "";
  return `<section class="card"><h2>Aktuelle Einzelkurse</h2><p class="small muted">Zeitpunktkurse werden separat angezeigt und nicht mit Jahresmittelwerten verrechnet.</p><div class="grid">${provenance.quotes
    .map((q) => {
      const value = q.price ?? q.value,
        valid =
          typeof value === "number" && Number.isFinite(value) && value > 0;
      return `<article><h3>${escape(q.name ?? q.symbol ?? "Kurs")}</h3><p>${valid ? fmt(value) + " " + escape(q.unit ?? q.currency ?? "") : "Nicht verfügbar"}</p><p class="small muted">${escape(q.asOf ?? q.timestamp ?? "Kein Zeitstempel")} ${q.error ? " · " + escape(q.error) : ""}</p></article>`;
    })
    .join("")}</div></section>`;
}
function marketPanel() {
  return `<section class="card"><h2>Echte Marktdaten</h2><p>Den gebündelten historischen Datenbestand laden oder einen neuen Abruf starten. Jahresmittel und einzelne aktuelle Kurse bleiben getrennt. Fehler ersetzen Ihren bisherigen Datenbestand nicht.</p><div class="actions"><button id="load-history" data-market-load ${dataRequestPending ? "disabled" : ""}>Historische Daten laden</button><button id="refresh-market" data-market-load class="secondary" ${dataRequestPending ? "disabled" : ""}>Marktdaten aktualisieren</button><button id="export-data" class="secondary">Aktuellen Datensatz speichern</button></div>${provenanceNote()}</section>${quotesPanel()}`;
}
async function loadMarketData(live) {
  if (dataRequestPending) return;
  dataRequestPending = true;
  setMessage(
    live
      ? "Marktdaten werden abgerufen …"
      : "Historischer Datenbestand wird geladen …",
  );
  document
    .querySelectorAll("[data-market-load]")
    .forEach((b) => (b.disabled = true));
  const controller = new AbortController(),
    timeout = setTimeout(() => controller.abort(), 30000);
  try {
    const response = await fetch(
      live ? "api/data" : "assets/market-data.json",
      { signal: controller.signal, cache: "no-store" },
    );
    if (!response.ok)
      throw Error(
        live && response.status === 404
          ? "Der aktuelle Webserver unterstützt keinen Marktdatenabruf. Mit START-WEB.cmd und installiertem Node.js starten oder den historischen Datenbestand laden."
          : `Datenquelle meldet HTTP ${response.status}.`,
      );
    const text = await response.text();
    if (new TextEncoder().encode(text).length > 2 * 1024 * 1024)
      throw Error("Antwort überschreitet 2 MB.");
    const payload = JSON.parse(text),
      next = payload.data ?? payload;
    if (next.kind === "demo")
      throw Error(
        "Die Datenquelle lieferte Beispieldaten; der aktuelle Bestand wurde beibehalten.",
      );
    const info = payload.provenance ?? {
      provider: next.source,
      fetchedAt: next.metadata?.fetchedAt,
      notes: [
        "Gebündelter historischer Datenbestand; kein Live-Kurs.",
        next.metadata?.coverage ?? "",
      ],
    };
    installData(next, info);
    settingsMessage = live
      ? "Marktdaten geprüft und übernommen."
      : "Historische Daten geprüft und übernommen.";
    render();
  } catch (e) {
    setMessage(
      (e.name === "AbortError"
        ? "Zeitüberschreitung beim Datenabruf."
        : e.message) + " Der bisherige Datenbestand bleibt erhalten.",
    );
  } finally {
    clearTimeout(timeout);
    dataRequestPending = false;
    document
      .querySelectorAll("[data-market-load]")
      .forEach((b) => (b.disabled = false));
  }
}
function saveDownload(body, type, name) {
  const u = URL.createObjectURL(new Blob([body], { type })),
    a = document.createElement("a");
  a.href = u;
  a.download = name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(u), 1000);
}
function applyConfig() {
  document.documentElement.style.setProperty(
    "--accent",
    config.theme === "teal"
      ? "#286c60"
      : config.theme === "rose"
        ? "#873e59"
        : "#0f1c3d",
  );
  $("#partner").textContent = config.partner
    ? `In Kooperation mit ${config.partner}`
    : "";
}
const note = () =>
  `<div class="notice"><strong>${data.kind === "demo" ? "Beispielmodus · Synthetische Werte" : "Datenbestand · " + escape(data.source)}</strong> · Stand ${escape(data.asOf)}. ${data.kind === "demo" ? "Keine historischen Kurse, keine aktuellen Marktdaten." : "Beobachtungsjahre und Einheiten der Reihen beachten; Datenstand bedeutet keinen Echtzeitkurs."}${provenanceNote()}</div>`;
function title(k, h, p) {
  return `<p class="eyebrow">CRISIS INTELLIGENCE / ${k}</p><h1>${h}</h1><p class="muted">${p}</p>`;
}
function home() {
  const r = ratio(data);
  const years = data.series.flatMap((s) => s.points.map((p) => p.year));
  const groups=new Set(data.series.map(s=>s.group.trim().toLocaleLowerCase('de')));
  const missingGroups=['Aktien','Immobilien'].filter(group=>!groups.has(group.toLocaleLowerCase('de')));
  const missingNotice=missingGroups.length?`<p id="missing-market-groups" class="small muted">${missingGroups.join(' und ')} sind im geladenen Datensatz nicht enthalten. Zusätzliche lizenzierte Reihen können als JSON importiert werden.</p>`:'';
  return `<section class="hero"><div>
    <p class="eyebrow">Wissen, das Werte schützt.</p>
    <span class="badge ${data.kind === "demo" ? "demo" : ""}">${data.kind === "demo" ? "Beispielmodus" : "Historische Berichtsdaten"}</span>
    <h1>Vermögen verstehen.<br>Handlungsfähig bleiben.</h1>
    <p class="lead">CRISIS macht Kaufkraftverlust sichtbar, vergleicht die Entwicklung von Vermögenswerten und hilft Ihnen, Abhängigkeiten Ihrer Vermögensstruktur zu prüfen.</p>
    <div class="actions"><a class="button" href="#purchasingpower">Meine Kaufkraft berechnen</a><a class="button secondary" href="#compare">Marktverläufe vergleichen</a></div>
  </div><aside class="purpose-card"><p class="eyebrow">So nutzen Sie CRISIS</p>
    <ol><li><strong>Verstehen</strong><span>Was bleibt von einem Geldbetrag bei anhaltender Inflation?</span></li>
    <li><strong>Einordnen</strong><span>Wie haben sich Preise nominal und nach Inflation entwickelt?</span></li>
    <li><strong>Vorbereiten</strong><span>Welche Fragen zu Liquidität, Zugang und Abhängigkeiten sind noch offen?</span></li></ol>
    <p class="small">Berechnungen und strukturierte Fragen unterstützen Ihre Vorbereitung. Sie erzeugen keine persönlichen Anlageempfehlungen.</p>
  </aside></section>
  <div class="grid"><article class="card"><span class="number">01 / KAUFKRAFT</span><h2>Was bleibt real?</h2><p>Berechnen Sie ein eigenes Inflationsszenario und sehen Sie den Unterschied zwischen Geldbetrag und Kaufkraft.</p><a href="#purchasingpower">Szenario berechnen →</a></article>
  <article class="card"><span class="number">02 / MARKTVERGLEICH</span><h2>Was zeigt die Historie?</h2><p>Vergleichen Sie verfügbare Reihen auf gemeinsamer Basis 100. CPI, Quellen und Beobachtungsjahre bleiben sichtbar.</p><a href="#compare">Daten vergleichen →</a></article>
  <article class="card"><span class="number">03 / STRUKTURCHECK</span><h2>Was ist noch ungeklärt?</h2><p>Halten Sie fest, welche Fragen zu Ihrer Vermögensstruktur beantwortet sind und wo Sie Klärungsbedarf sehen.</p><a href="#structure">Struktur prüfen →</a></article></div>
  <section class="card"><div class="section-heading"><h2>Ihr aktueller Datenbestand</h2><a href="#settings">Daten und Quellen verwalten →</a></div><p>${data.series.length} Reihen: ${data.series.map((s) => escape(s.name)).join(", ")}. Beobachtungsjahre ${Math.min(...years)}–${Math.max(...years)}; gemeinsame Jahre können davon abweichen.</p>${missingNotice}${note()}<p>Gold-Silber-Ratio${r ? " " + r.year + ": <strong>" + fmt(r.value) + " : 1</strong>" : " ist für diesen Datenbestand nicht verfügbar."} ${data.kind === "demo" ? "Synthetisches Rechenbeispiel." : "Jahreswerte gleicher Währung und Einheit; kein aktueller Handelskurs."}</p></section>
  <div class="section-heading"><h2>Risiken im Zusammenhang verstehen.</h2><a href="#library">Dossier 2026 lesen ↗</a></div><div class="grid four">${content.fields.map((f, i) => `<article class="card"><span class="number">0${i + 1} / WIRKUNGSRAUM</span><h3>${escape(f.title)}</h3><p>${escape(f.text)}</p></article>`).join("")}</div>
  <div class="section-heading"><h2>Makrolage</h2><span class="small muted">Berichtsdaten laut Quelle; keine Echtzeitwerte</span></div><div class="card table-wrap">${macroTable()}</div>
  <section class="card method-link"><h2>Historische Muster einordnen</h2><p>Die drei dokumentierten Jahresfolgen sind ein mechanisches Modell. Ihre Fortschreibung ist keine nachgewiesene Vorhersage von Krisen oder Marktwendepunkten.</p><a href="#cycles">Modell und Grenzen ansehen →</a></section>`;
}
function macroTable() {
  return `<table><caption>Einheitliche Eingaben: Inflation % p.a., Rüstung und BIP in Mrd. USD; Stand ${escape(data.asOf)}</caption><thead><tr><th>Land</th><th>Inflation</th><th>Rüstungsetat</th><th>BIP</th></tr></thead><tbody>${data.macro.map((m) => `<tr><th scope="row">${escape(m.country)}</th>${["inflation", "military", "gdp"].map((k) => `<td>${m[k] === null ? "Nicht verfügbar" : fmt(m[k])}</td>`).join("")}</tr>`).join("")}</tbody></table>`;
}
function planningNavigation(current) {
  return `<nav class="planning-nav" aria-label="Planungswerkzeuge"><a href="#purchasingpower" ${current === "power" ? 'aria-current="page"' : ""}>Kaufkraft berechnen</a><a href="#structure" ${current === "structure" ? 'aria-current="page"' : ""}>Struktur prüfen</a></nav>`;
}
function powerResults(result, context) {
  return `<p class="small muted">${escape(context)} · Beträge in derselben Recheneinheit wie Ihre Eingabe.</p><dl class="result-grid">
    <div class="result-item"><dt>Verbleibende Kaufkraft des unveränderten Geldbetrags</dt><dd>${fmt(result.remainingPower)}</dd></div>
    <div class="result-item"><dt>Geldbetrag für dieselbe Kaufkraft</dt><dd>${fmt(result.requiredAmount)}</dd></div>
    <div class="result-item"><dt>Änderung des Preisniveaus</dt><dd>${fmt(result.priceChangePercent)} %</dd></div>
    <div class="result-item"><dt>${result.lossPercent >= 0 ? "Kaufkraftverlust" : "Kaufkraftgewinn"}</dt><dd>${fmt(Math.abs(result.lossPercent))} %</dd></div></dl>
    <p class="small muted">Der nominale Geldbetrag bleibt ${fmt(result.amount)}. Zinsen, Renditen, Wechselkurse, Steuern und persönliche Ausgaben sind nicht einbezogen.</p>`;
}
function purchasingPowerView() {
  const years = data.cpi.map((p) => p.year);
  if (!years.includes(historyFrom)) historyFrom = years.find(year=>year>=years.at(-1)-10&&year<years.at(-1))??years[0];
  if (!years.includes(historyTo)) historyTo = years.at(-1);
  return (
    title(
      "PLANUNG",
      "Kaufkraft sichtbar machen.",
      "Ein unveränderter Geldbetrag kann über die Zeit weniger oder mehr kaufen. Berechnen Sie den Effekt für Ihren Betrag.",
    ) +
    planningNavigation("power") +
    `<div class="planning-grid"><section class="card planning-form"><p class="eyebrow">01 / HISTORISCHE BERECHNUNG</p><h2>Was zeigt der Verbraucherpreisindex?</h2>
    <p class="small muted">CPI: ${escape(data.cpiRegion)} · ${escape(data.source)} · Stand ${escape(data.asOf)}. Der verwendete CPI bestimmt die Kaufkraftperspektive; es findet keine Währungsumrechnung statt.</p>
    <label for="history-amount">Betrag in CPI-Bezugswährung</label><input id="history-amount" type="number" min="0.01" max="1000000000000" step="any" value="${escape(historyAmount)}" inputmode="decimal">
    <div class="row"><div><label for="history-from">Von Jahr</label><select id="history-from">${years.map((y) => `<option value="${y}" ${y === historyFrom ? "selected" : ""}>${y}</option>`).join("")}</select></div>
    <div><label for="history-to">Bis Jahr</label><select id="history-to">${years.map((y) => `<option value="${y}" ${y === historyTo ? "selected" : ""}>${y}</option>`).join("")}</select></div></div>
    <p class="help">Nur vorhandene CPI-Jahre, ohne Interpolation. Das Endjahr muss nach dem Startjahr liegen.</p><div id="history-result" aria-live="polite"></div></section>
    <section class="card planning-form"><p class="eyebrow">02 / EIGENES SZENARIO</p><h2>Was wäre bei anhaltender Inflation?</h2><p class="small muted">Ihre Annahme wird für jedes Jahr konstant fortgeschrieben. Das ist eine Modellrechnung und keine Prognose.</p>
    <label for="scenario-amount">Geldbetrag (eigene Recheneinheit)</label><input id="scenario-amount" type="number" min="0.01" max="1000000000000" step="any" value="${escape(scenarioAmount)}" inputmode="decimal">
    <div class="row"><div><label for="scenario-rate">Inflation pro Jahr (%)</label><input id="scenario-rate" type="number" min="-50" max="100" step="any" value="${escape(scenarioRate)}" inputmode="decimal"></div>
    <div><label for="scenario-years">Zeitraum (Jahre)</label><input id="scenario-years" type="number" min="1" max="100" step="1" value="${escape(scenarioYears)}" inputmode="numeric"></div></div>
    <div id="scenario-result" aria-live="polite"></div></section></div>
    <section class="card"><h2>Vom Rechenergebnis zur nächsten Frage</h2><p>Welche Ausgaben, Rücklagen oder Verpflichtungen sind von dieser Kaufkraftentwicklung betroffen? Der Strukturcheck hilft Ihnen, offene Fragen für ein Gespräch oder eine eigene Prüfung festzuhalten.</p><a class="button secondary" href="#structure">Meinen Strukturcheck öffnen</a></section>`
  );
}
function updatePower() {
  const readValue = (id) => {
    const input = $(id);
    if (!input.value.trim()) throw Error("Bitte alle Felder ausfüllen.");
    return Number(input.value);
  };
  historyAmount = $("#history-amount").value;
  historyFrom = Number($("#history-from").value);
  historyTo = Number($("#history-to").value);
  scenarioAmount = $("#scenario-amount").value;
  scenarioRate = $("#scenario-rate").value;
  scenarioYears = $("#scenario-years").value;
  try {
    const result = purchasingPower(
      data,
      readValue("#history-amount"),
      historyFrom,
      historyTo,
    );
    $("#history-result").innerHTML = powerResults(
      result,
      `CPI ${data.cpiRegion}: ${historyFrom}–${historyTo}`,
    );
  } catch (error) {
    $("#history-result").innerHTML =
      `<p class="error" role="alert">${escape(error.message)}</p>`;
  }
  try {
    const result = inflationScenario(
      readValue("#scenario-amount"),
      readValue("#scenario-rate"),
      readValue("#scenario-years"),
    );
    $("#scenario-result").innerHTML = powerResults(
      result,
      `Szenario: ${scenarioYears} Jahre bei ${scenarioRate} % pro Jahr – keine Prognose`,
    );
  } catch (error) {
    $("#scenario-result").innerHTML =
      `<p class="error" role="alert">${escape(error.message)}</p>`;
  }
}
const planStatuses = [
  ["unreviewed", "Noch nicht geprüft"],
  ["documented", "Dokumentiert"],
  ["needs_action", "Klärungsbedarf"],
  ["not_applicable", "Nicht zutreffend"],
];
function structureView() {
  return (
    title(
      "PLANUNG",
      "Struktur vor Entscheidung.",
      "Prüfen Sie Ihre Handlungsfähigkeit anhand der CRISIS-Dossiers. Sie dokumentieren den eigenen Stand – das ist keine Bewertung Ihres Vermögens.",
    ) +
    planningNavigation("structure") +
    `<p class="notice">Angaben bleiben lokal in diesem Browser. Geben Sie keine Kontonummern, Zugangsdaten oder vertraulichen Bestände ein. Antworten werden erst mit „Lokal speichern“ dauerhaft gespeichert.</p>
  ${planError ? `<p class="error" role="alert">${escape(planError)} Der gespeicherte Inhalt bleibt bis zu Ihrer ausdrücklichen Löschung erhalten.</p>` : ""}
  <section class="card"><h2>Meine Strukturfragen</h2><div id="plan-summary" class="structure-summary" aria-live="polite"></div>
  ${planning.questions
    .map(
      (
        q,
      ) => `<article class="checklist-item"><fieldset><legend>${escape(q.title)}: ${escape(q.text)}</legend><div class="checklist-options">${planStatuses.map(([status, label]) => `<label><input type="radio" name="plan-${q.id}" value="${status}" ${plan.answers[q.id].status === status ? "checked" : ""}>${label}</label>`).join("")}</div></fieldset>
    <p class="small muted">${escape(q.why)} · Bezug: ${escape(q.source)}</p><label class="note-label" for="note-${q.id}">Notiz zu ${escape(q.title)} (maximal 500 Zeichen)</label><textarea id="note-${q.id}" data-plan-note="${q.id}" maxlength="500">${escape(plan.answers[q.id].note)}</textarea></article>`,
    )
    .join("")}
  <div class="planning-form"><label for="plan-action">Mein nächster Klärungsschritt</label><textarea id="plan-action" maxlength="1000">${escape(plan.action)}</textarea>
  <div class="row"><div><label for="plan-owner">Zuständig / Gesprächspartner (optional)</label><input id="plan-owner" maxlength="80" value="${escape(plan.owner)}"></div>
  <div><label for="plan-review">Erneut prüfen am (optional)</label><input id="plan-review" type="date" min="1800-01-01" max="2200-12-31" value="${escape(plan.reviewDate)}"></div></div></div>
  <div class="actions"><button id="save-plan">Lokal speichern</button><button id="export-plan" class="secondary">Gesprächsnotiz exportieren</button><button id="delete-plan" class="secondary">Lokale Angaben löschen</button></div><p id="plan-result" role="status">${escape(planMessage)}</p></section>`
  );
}
function readPlan() {
  const next = {
    schemaVersion: 1,
    answers: {},
    action: $("#plan-action").value,
    owner: $("#plan-owner").value,
    reviewDate: $("#plan-review").value,
  };
  for (const q of planning.questions)
    next.answers[q.id] = {
      status: $(`[name="plan-${q.id}"]:checked`)?.value ?? "unreviewed",
      note: $(`#note-${q.id}`).value,
    };
  return validatePlan(next, planning.questions);
}
function showPlanMessage(message) {
  planMessage = message;
  const element = $("#plan-result");
  if (element) element.textContent = message;
}
function updatePlanSummary() {
  try {
    plan = readPlan();
    const summary = planSummary(plan, planning.questions);
    $("#plan-summary").textContent =
      `${summary.reviewed} von ${summary.total} bearbeitet · ${summary.documented} dokumentiert · ${summary.needs_action} mit Klärungsbedarf · ${summary.unreviewed} noch nicht geprüft · ${summary.not_applicable} nicht zutreffend. Eigene Bestandsaufnahme, kein Risikoscore.`;
  } catch (error) {
    showPlanMessage(error.message);
  }
}
function comparison() {
  return (
    title(
      "VERGLEICH",
      "Werte im Verhältnis.",
      "Gemeinsame Jahreswerte, ein Startpunkt. Nominal oder inflationsbereinigt.",
    ) +
    note() +
    `<div class="split"><aside class="card controls"><fieldset><legend>Asset-Auswahl</legend>${data.series.map((s) => `<label class="check"><input type="checkbox" name="asset" value="${s.id}" ${selection.includes(s.id) ? "checked" : ""}>${escape(s.name)}</label>`).join("")}</fieldset><div class="row"><div><label for="from">Von</label><input id="from" type="number" min="1800" max="2200" value="${from}"></div><div><label for="to">Bis</label><input id="to" type="number" min="1800" max="2200" value="${to}"></div></div><label class="check"><input id="real" type="checkbox" ${real ? "checked" : ""}>Inflationsbereinigt</label><p class="small muted">CPI: ${escape(data.cpiRegion)}. Gemeinsamer Start = 100. Wechselkurse, Dividenden, Mieten, Kosten und Steuern sind nicht enthalten.</p><button id="export" class="secondary">CSV exportieren</button></aside><section class="card chart-card"><div class="section-heading"><h2>Langfristig denken.</h2><span class="badge">Basis 100</span></div><div id="chart-result" aria-live="polite"></div></section></div>`
  );
}
function draw() {
  try {
    selection = [...document.querySelectorAll("[name=asset]:checked")].map(
      (e) => e.value,
    );
    from = Number($("#from").value);
    to = Number($("#to").value);
    real = $("#real").checked;
    if (
      !Number.isInteger(from) ||
      !Number.isInteger(to) ||
      from > to ||
      from < 1800 ||
      to > 2200
    )
      throw Error("Gültigen Jahresbereich 1800–2200 angeben.");
    const ss = compare(data, selection, from, to, real);
    const vals = ss.flatMap((s) => s.points.map((p) => p.value)),
      lo = Math.min(...vals) * 0.9,
      hi =
        Math.max(...vals) <= Number.MAX_VALUE / 1.1
          ? Math.max(...vals) * 1.1
          : Math.max(...vals);
    const start = ss[0].points[0].year,
      end = ss[0].points.at(-1).year,
      x = (y) => 60 + ((y - start) / (end - start)) * 700,
      y = (v) => 260 - ((v - lo) / (hi - lo)) * 230;
    $("#chart-result").innerHTML =
      `<p class="small muted">${start}–${end} · ${real ? "Real (CPI " + escape(data.cpiRegion) + ")" : "Nominal"} · Indexentwicklung, keine absolute Werthaltigkeit</p><svg class="chart" viewBox="0 0 800 310" role="img" aria-label="Indexverlauf der ausgewählten Assets; Werte stehen auch in der Tabelle.">${[
        0, 1, 2, 3, 4,
      ]
        .map((i) => {
          const v = lo + ((hi - lo) * i) / 4;
          return `<line x1="60" y1="${y(v)}" x2="760" y2="${y(v)}" stroke="#dce1e8"/><text x="3" y="${y(v) + 4}">${fmt(v)}</text>`;
        })
        .join(
          "",
        )}${ss.map((s, i) => `<polyline fill="none" stroke="${colors[i % colors.length]}" stroke-width="2.5" points="${s.points.map((p) => x(p.year) + "," + y(p.value)).join(" ")}"/>`).join("")}<text x="60" y="292">${start}</text><text x="725" y="292">${end}</text></svg><div class="legend">${ss.map((s, i) => `<span><i class="dot color-${i % colors.length}"></i>${escape(s.name)}</span>`).join("")}</div><div class="table-wrap"><table><caption>Ergebnisse ${data.kind === "demo" ? "(synthetisch)" : ""}</caption><thead><tr><th>Asset</th><th>Originaleinheit</th><th>Startindex</th><th>Endindex</th><th>Änderung</th></tr></thead><tbody>${ss.map((s) => `<tr><th scope="row">${escape(s.name)}</th><td>${escape(s.unit)}</td><td>100</td><td>${fmt(s.points.at(-1).value)}</td><td>${fmt(s.points.at(-1).value - 100)} %</td></tr>`).join("")}</tbody></table></div>`;
    $("#export").disabled = false;
    $("#export").onclick = () =>
      saveDownload(csv(ss), "text/csv;charset=utf-8", "crisis-vergleich.csv");
  } catch (e) {
    $("#chart-result").innerHTML =
      `<p class="error" role="alert">${escape(e.message)}</p>`;
    $("#export").disabled = true;
  }
}
function cycles() {
  return (
    title(
      "ZYKLEN",
      "Zeit macht Muster sichtbar.",
      "Die drei Jahresfolgen der Formeldefinition. Fortschreibung durch wiederholte Addition der Intervalle.",
    ) +
    `<div class="notice">Das PDF zeigt „×“, die dokumentierten Jahresfolgen entstehen jedoch durch Addition. 2026 ist ein Modelljahr für „hohe Preise“, kein nachgewiesener Marktwendepunkt. Ab 2027: gestrichelte Szenarien. Kein Kauf- oder Verkaufssignal.</div><div class="card controls"><label for="focus-year">Jahr untersuchen (1926–2126)</label><input id="focus-year" type="number" min="1926" max="2126" value="2026"><p id="year-result" role="status"></p></div>${content.cycles
      .map(
        (c) =>
          `<section class="card doc"><div class="section-heading"><h2>${escape(c.name)}</h2><span class="small">Start ${c.start} · +${c.steps.join(" / +")} Jahre</span></div><div class="timeline">${cycleYears(
            c,
          )
            .map(
              (y) =>
                `<span class="year ${y > 2026 ? "future" : ""}" data-year="${y}">${y}</span>`,
            )
            .join("")}</div></section>`,
      )
      .join("")}`
  );
}
function inspectYear() {
  const y = Number($("#focus-year").value);
  document
    .querySelectorAll("[data-year]")
    .forEach((el) => el.classList.remove("selected"));
  if (!Number.isInteger(y) || y < 1926 || y > 2126) {
    $("#year-result").textContent =
      "Bitte ein Jahr zwischen 1926 und 2126 eingeben.";
    return;
  }
  document
    .querySelectorAll("[data-year]")
    .forEach((el) =>
      el.classList.toggle("selected", Number(el.dataset.year) === y),
    );
  const matches = content.cycles.filter((c) => cycleYears(c).includes(y));
  $("#year-result").textContent = matches.length
    ? `${y}: ${matches.map((c) => c.name).join(" · ")} (Modell)`
    : `${y}: kein Modelltreffer. Keine Aussage über tatsächliches Risiko.`;
}
function library() {
  return (
    title(
      "WISSEN",
      "Struktur vor Schlagzeile.",
      "Alle sechs Originaldokumente, durchsuchbare Lesefassungen und dokumentierte Quellen.",
    ) +
    `<div class="card controls"><label for="search">Unterlagen durchsuchen</label><input type="search" id="search" placeholder="Zum Beispiel: Gold, Liquidität, Zyklen"><p class="small muted">Die Dossiers enthalten Interpretationen der Herausgeber; ihre Aussagen sind nicht unabhängig verifiziert. Interne Nutzungshinweise bleiben im Original erhalten.</p></div><div id="documents"></div><section class="card"><h2>Datenquellen</h2><p>Verweise aus dem Daten-PDF. Webseiten sind keine API-Verträge. Live-Daten erfordern lizenzierte Anbieter, dokumentierte Endpunkte und ggf. einen sicheren Serveradapter. LSEG.L ist eine Einzelaktie.</p><ul class="source-list">${content.sources.map((s) => `<li><a href="${escape(s.url)}" target="_blank" rel="noopener noreferrer">${escape(s.provider)} · ${escape(s.label)} ↗</a></li>`).join("")}</ul></section>`
  );
}
function docs() {
  const q = $("#search").value.toLocaleLowerCase("de");
  const ds = content.documents.filter((d) =>
    (d.title + " " + d.pages.join(" ")).toLocaleLowerCase("de").includes(q),
  );
  $("#documents").innerHTML = ds.length
    ? ds
        .map(
          (d) =>
            `<article class="doc"><h2>${escape(d.title)}</h2><p class="small muted">${d.pages.length} Seiten · Originalunterlage</p><a class="button secondary" href="assets/${encodeURIComponent(d.file)}" target="_blank" rel="noopener">Original-PDF öffnen ↗</a><details><summary>Lesefassung anzeigen</summary>${d.pages.map((p, i) => `<details><summary>Seite ${i + 1}</summary><pre class="document">${escape(p)}</pre></details>`).join("")}</details></article>`,
        )
        .join("")
    : '<p class="empty">Keine passenden Dokumente gefunden.</p>';
}
function settings() {
  return (
    title(
      "EINSTELLUNGEN",
      "Ihre Perspektive. Ihre Daten.",
      "Lokale Konfiguration ohne Konto, Tracking oder Cloudspeicherung.",
    ) +
    marketPanel() +
    `<div class="grid"><section class="card controls"><h2>White-Label Branding</h2><label for="partner-name">Berater / Partnername</label><input id="partner-name" maxlength="60" value="${escape(config.partner)}" placeholder="Name Ihrer Beratung"><label for="theme">Akzentfarbe</label><select id="theme"><option value="navy">Midnight Blue</option><option value="teal">Teal Mist (dunkler UI-Akzent)</option><option value="rose">Rusty Rose (dunkler UI-Akzent)</option></select><div class="actions"><button id="save-brand">Branding speichern</button></div><p class="small muted">Das CRISIS-Original bleibt unverändert. Partnername und Akzent werden lokal gespeichert.</p></section><section class="card controls"><h2>Daten importieren</h2><p class="small">JSON-Schema v1 · maximal 2 MB. Keine Zugangsdaten importieren. Bestandsdaten werden erst nach erfolgreicher Prüfung ersetzt.</p><label for="data-file">Datendatei auswählen</label><input id="data-file" type="file" accept=".json,application/json"><div class="actions"><button id="template" class="secondary">Beispieldatei laden</button><button id="reset" class="secondary">Beispieldaten wiederherstellen</button></div><p class="small muted">Eigene Daten werden im Browser gespeichert. Auf gemeinsam genutzten Geräten können andere Personen darauf zugreifen.</p></section><section class="card"><h2>Markenpalette</h2><div class="swatches"><span class="rose">Rose</span><span class="teal">Teal</span></div><p class="small muted">Midnight Blue #0f1c3d<br>Rusty Rose #e8b9c8<br>Teal Mist #c7e8e3</p><a href="#library">Brandguide und Farben ansehen →</a></section></div><p id="settings-result" role="status">${escape(settingsMessage)}</p>`
  );
}
function legal() {
  return `<article class="legal">${title("RECHTLICH", "Impressum", "Angaben aus dem bereitgestellten Brandguide; vor Veröffentlichung zu bestätigen.")}<h2>ALL I AM Akademie</h2><p>Akademie für ganzheitliche Persönlichkeits- & Projektentwicklung<br>Ein Bereich des Herzenskraft e.V.<br>Kreuzkirchstrasse 17<br>77652 Offenburg</p><p>Vertreten durch Alexander Avsar, Präsident<br><a href="mailto:info@aia.berlin">info@aia.berlin</a><br><a href="https://www.aia.berlin/crisis">www.aia.berlin/crisis</a></p><h2>Redaktioneller Hinweis</h2><p>Die Inhalte dienen der Information. Die Dossiers vertreten die Sicht der Herausgeber. Zyklusmodelle haben keine nachgewiesene Prognosegüte und begründen keine Anlageempfehlung. Historische Wertentwicklung erlaubt keine verlässliche Aussage über künftige Ergebnisse.</p><p>Registerangaben, Verantwortlichkeit und gegebenenfalls weitere Pflichtangaben sind vor einer öffentlichen Bereitstellung durch den Betreiber zu ergänzen.</p></article>`;
}
function privacy() {
  return `<article class="legal">${title("RECHTLICH", "Datenschutz", "Hinweise für den vorliegenden lokalen Funktionsumfang.")}
  <p>Die Anwendung verwendet keine Analyse-, Werbe- oder Trackingdienste und setzt keine Cookies. Branding, importierte Datensätze und ausdrücklich gespeicherte Strukturchecks liegen im lokalen Speicher dieses Browsers. Persönliche Eingaben werden nicht an einen CRISIS-Server übertragen.</p>
  <p>Die Kaufkraftrechner verarbeiten Eingaben nur während der Nutzung. Der Strukturcheck wird erst über „Lokal speichern“ dauerhaft gesichert. Seine Angaben können im Strukturcheck über „Lokale Angaben löschen“ entfernt werden. Auf gemeinsam genutzten Geräten können andere Personen die lokalen Daten einsehen.</p>
  <p>Mit „Beispieldaten wiederherstellen“ werden importierte Marktdaten ersetzt. Browserdaten können vollständig über die Browsereinstellungen gelöscht werden. Exporte erstellen nur die von Ihnen gewählte lokale Datei; beim Strukturcheck enthält sie Ihre Antworten, Notizen und Angaben zum nächsten Schritt.</p>
  <p>Ein ausdrücklich ausgelöster Marktdatenabruf kontaktiert den Datenadapter; der Adapter fragt externe Anbieter ab. Ihre Planungsangaben und importierten Bestände werden dabei nicht übermittelt. Externe Quellen und PDF-Dateien öffnen Sie bewusst. Bei externen Quellen gelten die Datenschutzbedingungen des jeweiligen Anbieters. Ein Webhoster kann technische Zugriffsdaten verarbeiten. Aufbewahrung, Rechtsgrundlage, Betroffenenrechte und Kontaktdaten des Verantwortlichen sind vor Veröffentlichung an den tatsächlichen Betrieb anzupassen.</p><a href="#legal">Betreiberangaben</a></article>`;
}
function render() {
  const route = location.hash.slice(1) || "home",
    views = {
      home,
      compare: comparison,
      purchasingpower: purchasingPowerView,
      structure: structureView,
      cycles,
      library,
      settings,
      legal,
      privacy,
    };
  $("#main").innerHTML = (
    (Object.hasOwn(views,route)?views[route]:null) ||
    (() =>
      title(
        "404",
        "Seite nicht gefunden.",
        "Bitte die Hauptnavigation verwenden.",
      ))
  )();
  if (route === "home") {
    $("#main").insertAdjacentHTML("beforeend", quotesPanel());
    const macroStatus = $("#main .section-heading .small.muted");
    if (macroStatus && data.kind !== "demo")
      macroStatus.textContent =
        "Berichtsdaten laut Quelle; keine Echtzeitwerte";
    if (data.kind !== "demo") $("#main .badge.demo")?.classList.remove("demo");
  }
  document.querySelectorAll("nav a").forEach((a) => {
    a.removeAttribute("aria-current");
    if (
      a.hash === "#" + route ||
      (a.closest('header')&&a.hash === "#purchasingpower" && route === "structure")
    )
      a.setAttribute("aria-current", "page");
  });
  document.title = `CRISIS © · ${{ home: "Übersicht", compare: "Vergleich", purchasingpower: "Kaufkraft", structure: "Strukturcheck", cycles: "Zyklen", library: "Wissen", settings: "Einstellungen", legal: "Impressum", privacy: "Datenschutz" }[route] || "404"}`;
  if (route === "purchasingpower") {
    document
      .querySelectorAll(".planning-form input,.planning-form select")
      .forEach((input) => input.addEventListener("input", updatePower));
    updatePower();
  }
  if (route === "structure") {
    document
      .querySelectorAll(
        ".checklist-item input,.checklist-item textarea,.planning-form input,.planning-form textarea",
      )
      .forEach((input) =>
        input.addEventListener("input", () => {
          updatePlanSummary();
          showPlanMessage("Änderungen noch nicht gespeichert.");
        }),
      );
    $("#save-plan").disabled = !!planError;
    $("#save-plan").onclick = () => {
      try {
        const next = readPlan();
        storage.set("crisis-plan", JSON.stringify(next));
        plan = next;
        planError = "";
        showPlanMessage("Strukturcheck lokal gespeichert.");
      } catch (error) {
        showPlanMessage(error.message);
      }
    };
    $("#export-plan").onclick = () => {
      try {
        const next = readPlan();
        saveDownload(
          planningReport(next, planning.questions, {
            partner: config.partner,
            generatedAt: new Date().toISOString(),
          }),
          "text/plain;charset=utf-8",
          "crisis-strukturcheck.txt",
        );
        showPlanMessage("Gesprächsnotiz exportiert.");
      } catch (error) {
        showPlanMessage(error.message);
      }
    };
    $("#delete-plan").onclick = () => {
      if(!window.confirm('Alle lokalen Angaben im Strukturcheck einschließlich Notizen und nächstem Prüfschritt löschen? Dies betrifft keine Marktdaten.')){
        showPlanMessage('Löschen abgebrochen. Ihre Angaben bleiben erhalten.');
        return;
      }
      try {
        storage.remove("crisis-plan");
        plan = emptyPlan(planning.questions);
        planError = "";
        planMessage = "Lokale Angaben gelöscht.";
        render();
      } catch (error) {
        showPlanMessage(error.message);
      }
    };
    updatePlanSummary();
  }
  if (route === "compare") {
    document
      .querySelectorAll(".controls input")
      .forEach((el) => el.addEventListener("input", draw));
    draw();
  }
  if (route === "cycles") {
    $("#focus-year").oninput = inspectYear;
    inspectYear();
  }
  if (route === "library") {
    $("#search").oninput = docs;
    docs();
  }
  if (route === "settings") {
    $("#load-history").onclick = () => loadMarketData(false);
    $("#refresh-market").onclick = () => loadMarketData(true);
    $("#export-data").onclick = () =>
      saveDownload(
        JSON.stringify(data, null, 2),
        "application/json",
        "crisis-daten.json",
      );
    $("#theme").value = config.theme;
    $("#save-brand").onclick = () => {
      try {
        const next = {
          partner: $("#partner-name").value.trim(),
          theme: $("#theme").value,
        };
        storage.set("crisis-brand", JSON.stringify(next));
        config = next;
        applyConfig();
        setMessage("Branding gespeichert.");
      } catch (e) {
        setMessage(e.message);
      }
    };
    $("#template").onclick = () =>
      saveDownload(
        JSON.stringify(demo, null, 2),
        "application/json",
        "crisis-beispieldaten.json",
      );
    $("#reset").onclick = () => {
      try {
        installData(structuredClone(demo));
        settingsMessage = "Beispieldaten wiederhergestellt.";
        render();
      } catch (e) {
        setMessage(e.message);
      }
    };
    $("#data-file").onchange = async (e) => {
      try {
        const f = e.target.files[0];
        if (!f) return;
        if (f.size > 2 * 1024 * 1024) throw Error("Maximal 2 MB erlaubt.");
        const next = validateData(JSON.parse(await f.text()));
        installData(next);
        setMessage("Datensatz geprüft und importiert.");
      } catch (e) {
        setMessage("Import abgelehnt: " + e.message);
      } finally {
        e.target.value = "";
      }
    };
  }
}
try {
  let history;
  [content, demo, history, planning] = await Promise.all(
    ["content", "demo-data", "market-data", "planning"].map(async (n) => {
      const r = await fetch(`assets/${n}.json`);
      if (!r.ok) throw Error("Unterlagen nicht erreichbar.");
      return r.json();
    }),
  );
  validateData(demo);
  plan = emptyPlan(planning.questions);
  try {
    const savedPlan = storage.get("crisis-plan");
    if (savedPlan)
      plan = validatePlan(JSON.parse(savedPlan), planning.questions);
  } catch (error) {
    planError =
      "Der gespeicherte Strukturcheck konnte nicht gelesen werden: " +
      error.message;
  }
  data = validateData(history);
  provenance = {
    provider: history.source,
    fetchedAt: history.metadata?.fetchedAt,
    notes: [
      "Gebündelter historischer Datenbestand; kein Live-Kurs.",
      history.metadata?.coverage ?? "",
    ],
  };
  try {
    const stored = storage.get("crisis-data");
    if (stored) {
      const parsed = JSON.parse(stored);
      data = validateData(parsed.data ?? parsed);
      provenance = parsed.provenance ?? null;
    }
  } catch {
    setMessage(
      "Der gespeicherte Datensatz ist ungültig. Der historische Datenbestand wurde geladen.",
    );
    try {
      storage.remove("crisis-data");
    } catch {}
  }
  try {
    const b = JSON.parse(storage.get("crisis-brand"));
    if (
      b &&
      typeof b.partner === "string" &&
      ["navy", "rose", "teal"].includes(b.theme)
    )
      config = { partner: b.partner.slice(0, 60), theme: b.theme };
  } catch {
    config = { partner: "", theme: "navy" };
  }
  selection = data.series.slice(0, 2).map((s) => s.id);
  const years = data.series.flatMap((s) => s.points.map((p) => p.year));
  from = Math.min(...years);
  to = Math.max(...years);
  applyConfig();
  window.addEventListener("hashchange", () => {
    render();
    $("#main").focus({ preventScroll: true });
    window.scrollTo(0, 0);
  });
  render();
} catch (e) {
  $("#main").innerHTML =
    `<p class="error" role="alert">${escape(e.message)} Bitte über den dokumentierten Webserver starten und neu laden.</p>`;
}
