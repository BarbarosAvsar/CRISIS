import { chromium } from "@playwright/test";
import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { readFile, mkdir } from "node:fs/promises";
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const browser = await chromium.launch({
  ...(process.env.CRISIS_USE_PLAYWRIGHT_BROWSER
    ? {}
    : { executablePath: process.env.CHROMIUM_PATH || "/usr/bin/chromium" }),
  headless: true,
  args: ["--no-sandbox"],
});
try {
  const page = await browser.newPage({
    viewport: { width: 1440, height: 1000 },
  });
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (m) => {
    if (m.type() === "error") errors.push(m.text());
  });
  await page.goto(process.env.CRISIS_BASE_URL || "http://127.0.0.1:4173");
  await page
    .getByRole("heading", {
      name: "Vermögen verstehen. Handlungsfähig bleiben.",
    })
    .waitFor();
  await mkdir(path.join(root, "docs/screenshots"), { recursive: true });
  await page.screenshot({
    path: path.join(root, "docs/screenshots/web-desktop.png"),
    fullPage: true,
  });
  await page.getByRole("link", { name: "Planung", exact: true }).click();
  await page
    .getByRole("heading", { name: "Kaufkraft sichtbar machen." })
    .waitFor();
  assert.match(await page.locator("#scenario-result").innerText(), /7\.440,94/);
  assert.match(
    await page.locator("#scenario-result").innerText(),
    /keine Prognose/,
  );
  await page.locator("#scenario-rate").fill("101");
  await page.locator("#scenario-result [role=alert]").waitFor();
  await page.locator("#scenario-rate").fill("3");
  await page.locator("#history-from").selectOption("2024");
  await page.locator("#history-result [role=alert]").waitFor();
  await page.locator("#history-from").selectOption("1960");
  assert.equal(await page.locator("#history-result [role=alert]").count(), 0);
  await page.screenshot({
    path: path.join(root, "docs/screenshots/web-kaufkraft.png"),
    fullPage: true,
  });
  await page
    .getByRole("link", { name: "Meinen Strukturcheck öffnen", exact: true })
    .click();
  await page
    .getByRole("heading", { name: "Struktur vor Entscheidung." })
    .waitFor();
  await page.locator("[name=plan-liquidity][value=needs_action]").check();
  await page
    .locator("#note-liquidity")
    .fill("Reserve und Fälligkeiten prüfen.");
  await page
    .locator("#plan-action")
    .fill("Verfügbarkeit der Reserve mit der Beratung klären.");
  await page.locator("#plan-owner").fill("Eigene Prüfung");
  await page.locator("#plan-review").fill("2027-01-15");
  assert.match(
    await page.locator("#plan-summary").innerText(),
    /1 mit Klärungsbedarf/,
  );
  assert.equal(
    await page.evaluate(() => localStorage.getItem("crisis-plan")),
    null,
  );
  await page
    .getByRole("button", { name: "Lokal speichern", exact: true })
    .click();
  await page
    .getByRole("status")
    .filter({ hasText: "Strukturcheck lokal gespeichert" })
    .waitFor();
  await page.reload();
  await page.locator("#plan-action").waitFor();
  assert.equal(
    await page.locator("#note-liquidity").inputValue(),
    "Reserve und Fälligkeiten prüfen.",
  );
  assert.equal(
    await page.locator("[name=plan-liquidity][value=needs_action]").isChecked(),
    true,
  );
  const reportDownload = page.waitForEvent("download");
  await page
    .getByRole("button", { name: "Gesprächsnotiz exportieren", exact: true })
    .click();
  const report = await reportDownload;
  assert.equal(report.suggestedFilename(), "crisis-strukturcheck.txt");
  const reportText = await readFile(await report.path(), "utf8");
  assert.match(reportText, /Reserve und Fälligkeiten prüfen/);
  assert.match(reportText, /2027-01-15/);
  await page.evaluate(() =>
    localStorage.setItem("crisis-plan", '{"schemaVersion":99}'),
  );
  await page.reload();
  await page.getByRole("alert").waitFor();
  assert.equal(await page.locator("#save-plan").isDisabled(), true);
  assert.equal(
    await page.evaluate(() => localStorage.getItem("crisis-plan")),
    '{"schemaVersion":99}',
  );
  await page
    .getByRole("button", { name: "Lokale Angaben löschen", exact: true })
    .click();
  assert.equal(
    await page.evaluate(() => localStorage.getItem("crisis-plan")),
    null,
  );
  assert.match(
    await page.locator("#plan-summary").innerText(),
    /0 von 5 bearbeitet/,
  );
  await page.screenshot({
    path: path.join(root, "docs/screenshots/web-strukturcheck.png"),
    fullPage: true,
  });
  await page.getByRole("link", { name: "Vergleich", exact: true }).click();
  await page.locator("svg").waitFor();
  await page.locator("#real").check();
  assert.match(await page.locator("#chart-result").innerText(), /Real/);
  for (const id of await page
    .locator("[name=asset]:checked")
    .evaluateAll((es) => es.map((e) => e.value)))
    await page.locator(`[name=asset][value=${id}]`).uncheck();
  await page.getByRole("alert").waitFor();
  await page.locator("[name=asset][value=gold]").check();
  await page.locator("[name=asset][value=silver]").check();
  const download = page.waitForEvent("download");
  await page.getByRole("button", { name: "CSV exportieren" }).click();
  assert.equal((await download).suggestedFilename(), "crisis-vergleich.csv");
  await page.getByRole("link", { name: "Zyklen", exact: true }).click();
  await page.locator("#focus-year").fill("2032");
  assert.match(
    await page.locator("#year-result").innerText(),
    /Niedrige Preise/,
  );
  assert.equal(await page.locator(".year.selected").count(), 1);
  await page.locator("#focus-year").fill("0");
  assert.equal(await page.locator(".year.selected").count(), 0);
  await page.getByRole("link", { name: "Wissen", exact: true }).click();
  await page.locator("#search").fill("unfindablexyz");
  assert.match(await page.locator("#documents").innerText(), /Keine passenden/);
  await page.locator("#search").fill("Goldverbote");
  assert.ok((await page.locator("#documents article").count()) > 0);
  await page.getByRole("link", { name: "Einstellungen", exact: true }).click();
  await page.locator("#partner-name").fill("<img src=x onerror=alert(1)>");
  await page.getByRole("button", { name: "Branding speichern" }).click();
  await page.reload();
  assert.equal(await page.locator("#partner img").count(), 0);
  assert.match(await page.locator("#partner").innerText(), /<img/);
  await page.locator("#data-file").setInputFiles({
    name: "invalid.json",
    mimeType: "application/json",
    buffer: Buffer.from('{"bad":true}'),
  });
  await page
    .getByRole("status")
    .filter({ hasText: "Import abgelehnt" })
    .waitFor();
  // Data and branding have independent recovery paths: corrupt branding must not erase an import.
  await page
    .getByRole("button", { name: "Historische Daten laden", exact: true })
    .click();
  await page
    .getByRole("status")
    .filter({ hasText: "Historische Daten geprüft" })
    .waitFor();
  await page.evaluate(() => localStorage.setItem("crisis-brand", "{broken"));
  await page.reload();
  await page.locator("#data-file").waitFor();
  assert.ok(await page.evaluate(() => localStorage.getItem("crisis-data")));
  const feed = JSON.parse(
    await readFile(path.join(root, "shared/market-data.json"), "utf8"),
  );
  await page.route("**/api/data", (route) =>
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        data: feed,
        provenance: {
          provider: "Browser test fixture",
          fetchedAt: "2026-10-28T12:00:00Z",
          cached: true,
          stale: false,
          notes: ["History remains annual."],
          quotes: [
            {
              symbol: "XAU",
              name: "Gold",
              price: 1.23,
              currency: "USD",
              unit: "USD/Feinunze",
              asOf: "2026-10-28T12:00:00Z",
              provider: "Browser test fixture",
            },
          ],
        },
      }),
    }),
  );
  await page
    .getByRole("button", { name: "Marktdaten aktualisieren", exact: true })
    .click();
  await page
    .getByRole("status")
    .filter({ hasText: "Marktdaten geprüft" })
    .waitFor();
  await page.getByRole("heading", { name: "Aktuelle Einzelkurse" }).waitFor();
  assert.match(await page.locator("main").innerText(), /1,23 USD\/Feinunze/);
  await page.getByRole("link", { name: "Vergleich", exact: true }).click();
  assert.match(await page.locator("#chart-result").innerText(), /1960–2024/);
  await page.getByRole("link", { name: "Einstellungen", exact: true }).click();
  const before = await page.evaluate(() => localStorage.getItem("crisis-data"));
  await page.unroute("**/api/data");
  await page.route("**/api/data", (route) =>
    route.fulfill({
      status: 503,
      contentType: "application/json",
      body: '{"error":"test unavailable"}',
    }),
  );
  await page
    .getByRole("button", { name: "Marktdaten aktualisieren", exact: true })
    .click();
  await page.getByRole("status").filter({ hasText: "HTTP 503" }).waitFor();
  assert.equal(
    await page.evaluate(() => localStorage.getItem("crisis-data")),
    before,
  );
  await page
    .getByRole("button", {
      name: "Beispieldaten wiederherstellen",
      exact: true,
    })
    .click();
  await page.reload();
  await page.locator("#data-file").waitFor();
  assert.equal(
    await page.evaluate(
      () => JSON.parse(localStorage.getItem("crisis-data")).data.kind,
    ),
    "demo",
  );
  await page
    .getByRole("button", { name: "Historische Daten laden", exact: true })
    .click();
  await page
    .getByRole("status")
    .filter({ hasText: "Historische Daten geprüft" })
    .waitFor();
  await page
    .locator("#data-file")
    .setInputFiles(path.join(root, "shared/demo-data.json"));
  await page
    .getByRole("status")
    .filter({ hasText: "Datensatz geprüft" })
    .waitFor();
  await page.locator("#partner-name").fill("");
  await page.getByRole("button", { name: "Branding speichern" }).click();
  await page.getByRole("link", { name: "Übersicht", exact: true }).click();
  await page.setViewportSize({ width: 390, height: 844 });
  await page.screenshot({
    path: path.join(root, "docs/screenshots/web-mobile.png"),
    fullPage: true,
  });
  assert.ok(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  );
  await page.getByRole("link", { name: "Planung", exact: true }).click();
  await page
    .getByRole("heading", { name: "Kaufkraft sichtbar machen." })
    .waitFor();
  assert.ok(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  );
  await page
    .getByRole("link", { name: "Meinen Strukturcheck öffnen", exact: true })
    .click();
  assert.ok(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  );
  await page.getByRole("link", { name: "Vergleich", exact: true }).click();
  assert.ok(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  );
  for (const link of ["Impressum", "Datenschutz"]) {
    await page.getByRole("link", { name: link, exact: true }).click();
    await page.getByRole("heading", { name: link, exact: true }).waitFor();
  }
  await page.evaluate(()=>{location.hash='__proto__'});
  await page.getByRole('heading',{name:'Seite nicht gefunden.'}).waitFor();
  await page.getByRole('link',{name:'Übersicht',exact:true}).click();
  await page.getByRole('heading',{name:'Vermögen verstehen. Handlungsfähig bleiben.'}).waitFor();
  assert.deepEqual(
    errors.filter((e) => !e.includes("503 (Service Unavailable)")),
    [],
  );
  console.log(
    "Browser: purpose, purchasing power, planning save/export/delete and corrupt-data recovery, desktop/mobile navigation, charts, CPI, live-feed errors, import, persistence and legal views passed.",
  );
} finally {
  await browser.close();
}
