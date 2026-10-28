import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { cycleYears, validateData, compare, ratio, csv } from "../web/core.js";
const d = JSON.parse(
    await readFile(new URL("../shared/demo-data.json", import.meta.url)),
  ),
  c = JSON.parse(
    await readFile(new URL("../shared/content.json", import.meta.url)),
  );
test("all three documented sequences, including 2026 and future boundaries", () => {
  assert.deepEqual(
    cycleYears(c.cycles[0], 1911, 2019),
    [1911, 1927, 1945, 1965, 1981, 1999, 2019],
  );
  assert.deepEqual(
    cycleYears(c.cycles[1], 1918, 2026),
    [
      1918, 1926, 1935, 1945, 1953, 1962, 1972, 1980, 1989, 1999, 2007, 2016,
      2026,
    ],
  );
  assert.deepEqual(
    cycleYears(c.cycles[2], 1924, 2032),
    [
      1924, 1931, 1942, 1951, 1958, 1969, 1978, 1985, 1996, 2005, 2012, 2023,
      2032,
    ],
  );
  assert.throws(() => cycleYears(c.cycles[0], 2200, 1800));
});
test("bundled schema has ten synthetic series and six complete documents", () => {
  assert.equal(validateData(d), d);
  assert.equal(d.series.length, 10);
  assert.equal(c.documents.length, 6);
  assert.ok(c.documents.every((d) => d.pages.length > 0));
  assert.equal(d.series[0].points.length, 101);
  assert.equal(c.sources.length, 25);
});
const simple = {
  schemaVersion: 1,
  kind: "import",
  asOf: "2026-01-01",
  source: "Test fixture",
  cpiRegion: "DE",
  cpi: [
    { year: 2020, value: 100 },
    { year: 2021, value: 110 },
    { year: 2022, value: 121 },
  ],
  series: [
    {
      id: "gold",
      name: "Gold",
      group: "Edelmetalle",
      unit: "EUR/Feinunze",
      currency: "EUR",
      points: [
        { year: 2020, value: 10 },
        { year: 2021, value: 15 },
        { year: 2022, value: 20 },
      ],
    },
    {
      id: "silver",
      name: "Silber",
      group: "Edelmetalle",
      unit: "EUR/Feinunze",
      currency: "EUR",
      points: [
        { year: 2020, value: 2 },
        { year: 2022, value: 4 },
      ],
    },
  ],
  macro: [],
};
test("common-year normalization and CPI adjustment", () => {
  const n = compare(simple, ["gold", "silver"], 2020, 2022, false);
  assert.deepEqual(n[0].points, [
    { year: 2020, value: 100 },
    { year: 2022, value: 200 },
  ]);
  assert.equal(n[1].points[1].value, 200);
  const r = compare(simple, ["gold", "silver"], 2020, 2022, true);
  assert.ok(Math.abs(r[0].points[1].value - 165.28925619834712) < 1e-9);
});
test("missing overlap or CPI is an explicit failure", () => {
  assert.throws(() => compare(simple, [], 2020, 2022));
  assert.throws(() => compare(simple, ["gold", "silver"], 2021, 2022));
  assert.throws(() =>
    compare(
      { ...simple, cpi: [{ year: 2021, value: 110 }] },
      ["gold", "silver"],
      2020,
      2022,
      true,
    ),
  );
});
test("ratio matches common date, currency and unit", () => {
  assert.deepEqual(ratio(simple), { year: 2022, value: 5 });
  const s = structuredClone(simple);
  s.series[1].currency = "USD";
  assert.equal(ratio(s), null);
});
test("reject malformed input without coercing values", () => {
  for (const mutate of [
    (x) => x.series.push(x.series[0]),
    (x) => (x.cpi[0].value = 0),
    (x) => x.cpi.reverse(),
    (x) => (x.series[0].points[0].year = 2020.1),
    (x) => (x.cpi[0].value = "100"),
    (x) => (x.kind = "live"),
    (x) =>
      (x.macro = [{ country: "DE", inflation: null, military: -1, gdp: null }]),
    (x) => (x.series[0].name = ""),
    (x) => (x.cpi[0].value = Infinity),
  ]) {
    const x = structuredClone(simple);
    mutate(x);
    assert.throws(() => validateData(x));
  }
});
test("CSV contains all selected years, quotes labels and exact values", () => {
  const s = compare(simple, ["gold"], 2020, 2022);
  const out = csv(s);
  assert.match(out, /"Gold";2022;200.0000/);
  assert.equal(out.trim().split("\n").length, 4);
});
test("platform bundles are byte-identical to canonical content", async () => {
  for (const name of ["content.json", "demo-data.json"])
    for (const dir of [
      "web/assets",
      "android/app/src/main/assets",
      "ios/CRISIS/Resources",
    ])
      assert.equal(
        await readFile(new URL(`../${dir}/${name}`, import.meta.url), "utf8"),
        await readFile(new URL(`../shared/${name}`, import.meta.url), "utf8"),
      );
});
test("CSV quotes embedded quotes and neutralizes spreadsheet formulas", () => {
  const s = compare(simple, ["gold"], 2020, 2022);
  s[0].name = '=HYPERLINK("unsafe")';
  assert.ok(csv(s).includes('"\'=HYPERLINK(""unsafe"")";2020;100.0000'));
});
test("reject impossible calendar dates", () => {
  assert.throws(() => validateData({ ...simple, asOf: "2026-02-30" }));
});
test("guards invalid cycle definitions and numeric overflow",()=>{
  for(const cycle of [{start:1911,steps:[]},{start:1911,steps:[0]},{start:1911,steps:[-1]},null])assert.throws(()=>cycleYears(cycle));
  for(const invalid of [null,[],false,{...simple,series:[null]},{...simple,cpi:[null]},{...simple,macro:[null]}])assert.throws(()=>validateData(invalid));
  const overflow=structuredClone(simple);overflow.series[0].points[0].value=1e-300;overflow.series[0].points[2].value=1e15;
  validateData(overflow);assert.throws(()=>compare(overflow,['gold'],2020,2022,false),/Zahlenbereich/);
  overflow.series[1].points[1].value=1e-300;assert.equal(ratio(overflow),null);
  assert.throws(()=>compare(simple,['gold'],2022,2020),/Jahresbereich/);
});
test('genuine historical snapshot is valid and available identically on every platform',async()=>{
  const bytes=await readFile(new URL('../shared/market-data.json',import.meta.url),'utf8'),history=validateData(JSON.parse(bytes));
  assert.equal(history.kind,'import');assert.equal(history.series.length,2);assert.equal(history.asOf,'2024-12-31');assert.match(history.source,/Weltbank/);
  assert.deepEqual(history.series.map(s=>s.id),['gold','silver']);assert.equal(history.series[0].points[0].year,1960);
  for(const dir of ['web/assets','android/app/src/main/assets','ios/CRISIS/Resources'])assert.equal(await readFile(new URL(`../${dir}/market-data.json`,import.meta.url),'utf8'),bytes);
});
test("all original PDFs are available and source URLs are well formed", async () => {
  for (const doc of c.documents) {
    const b = await readFile(
      new URL("../web/assets/" + encodeURIComponent(doc.file), import.meta.url),
    );
    assert.equal(b.subarray(0, 4).toString(), "%PDF");
  }
  for (const s of c.sources) {
    const u = new URL(s.url);
    assert.equal(u.protocol, "https:");
    assert.ok(!s.url.includes(" "));
  }
});
test("Xcode project parses and contains native app and test targets", async () => {
  const { default: xcode } = await import("xcode");
  const p = xcode.project(
    new URL("../ios/CRISIS.xcodeproj/project.pbxproj", import.meta.url)
      .pathname,
  );
  p.parseSync();
  const targets = Object.values(p.pbxNativeTargetSection()).filter(
    (v) => typeof v === "object",
  );
  assert.equal(targets.length, 3);
  assert.ok(targets.some((t) => t.name === "CRISIS"));
  assert.ok(targets.some((t) => t.name === "CRISISTests"));
  assert.ok(targets.some((t) => t.name === "CRISISUITests"));
  const resources = Object.values(
    p.hash.project.objects.PBXResourcesBuildPhase,
  ).filter((v) => typeof v === "object");
  assert.equal(resources.length, 2);
});
