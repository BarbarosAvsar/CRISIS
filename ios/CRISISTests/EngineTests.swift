import XCTest
@testable import CRISIS
final class EngineTests: XCTestCase {
 func testServerProvenanceAcceptsNotesStringAndFailedQuote() throws {
  let raw: [String: Any] = ["notes": "Annual history remains separate.", "stale": true,
   "quotes": [["symbol": "XAG", "price": NSNull(), "error": "HTTP 403"]]]
  let info = try XCTUnwrap(MarketProvenance.parse(raw))
  XCTAssertEqual(info.notes, ["Annual history remains separate."])
  XCTAssertNil(info.quotes?.first?.amount)
  XCTAssertEqual(info.quotes?.first?.error, "HTTP 403")
 }
 func fixture(_ name: String) throws -> Data {
  try Data(contentsOf: XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json")))
 }
 func testDocumentedSequences() throws {
  let c = try JSONDecoder().decode(Content.self, from: fixture("content"))
  XCTAssertEqual(CrisisEngine.years(c.cycles[0], from: 1911, to: 2019), [1911,1927,1945,1965,1981,1999,2019])
  XCTAssertEqual(CrisisEngine.years(c.cycles[1], from: 1918, to: 2026), [1918,1926,1935,1945,1953,1962,1972,1980,1989,1999,2007,2016,2026])
  XCTAssertEqual(CrisisEngine.years(c.cycles[2], from: 1924, to: 2032), [1924,1931,1942,1951,1958,1969,1978,1985,1996,2005,2012,2023,2032])
  XCTAssertEqual(c.documents.count, 6)
 }
 func testNormalizationAndCPI() throws {
  let d = try CrisisEngine.parse(fixture("demo-data"))
  XCTAssertEqual(d.series.count, 10)
  let n = try CrisisEngine.compare(d, ids: ["gold", "dax"], from: 1926, to: 2026, real: false)
  XCTAssertEqual(n[0].points[0].value, 100, accuracy: 1e-9)
  let r = try CrisisEngine.compare(d, ids: ["gold"], from: 1926, to: 2026, real: true)
  XCTAssertLessThan(r[0].points.last!.value, n[0].points.last!.value)
  XCTAssertNotNil(CrisisEngine.ratio(d))
  XCTAssertTrue(CrisisEngine.csv(n).contains("Asset;Jahr;Index"))
 }
 func testGoldenCPI() throws {
  let d = try CrisisEngine.parse(fixture("golden-data"))
  let ss = try CrisisEngine.compare(d, ids: ["gold", "silver"], from: 2020, to: 2022, real: true)
  XCTAssertEqual(ss[0].points.count, 2)
  XCTAssertEqual(ss[0].points.last!.value, 165.28925619834712, accuracy: 1e-9)
  XCTAssertEqual(CrisisEngine.ratio(d)!.value, 5, accuracy: 1e-9)
 }
 func testInvalidDataAndSelection() throws {
  let bytes = try fixture("demo-data")
  let bad = String(data: bytes, encoding: .utf8)!.replacingOccurrences(of: "\"value\": 20.0", with: "\"value\": 0.0")
  XCTAssertThrowsError(try CrisisEngine.parse(Data(bad.utf8)))
  let d = try CrisisEngine.parse(bytes)
  XCTAssertThrowsError(try CrisisEngine.compare(d, ids: [], from: 1926, to: 2026, real: false))
  XCTAssertThrowsError(try CrisisEngine.compare(d, ids: ["gold"], from: 2026, to: 1926, real: true))
 }
 func testCSVQuotingAndFormulaNeutralization() {
  XCTAssertEqual(CrisisEngine.csvLabel("=HYPERLINK(\"unsafe\")"), "\"'=HYPERLINK(\"\"unsafe\"\")\"")
 }
 func testInvalidCalendar() throws {
  let bytes = try fixture("demo-data")
  let bad = String(data: bytes, encoding: .utf8)!.replacingOccurrences(of: "2026-01-01", with: "2026-02-30")
  XCTAssertThrowsError(try CrisisEngine.parse(Data(bad.utf8)))
 }
 func testExtremeRatiosCannotProduceInfiniteChartValues() throws {
  let raw = try fixture("golden-data")
  var object = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
  var series = try XCTUnwrap(object["series"] as? [[String: Any]])
  var points = try XCTUnwrap(series[0]["points"] as? [[String: Any]])
  points[0]["value"] = 1e-300
  series[0]["points"] = points; object["series"] = series
  let data = try CrisisEngine.parse(JSONSerialization.data(withJSONObject: object))
  XCTAssertThrowsError(try CrisisEngine.compare(data, ids: ["gold"], from: 2020, to: 2022, real: false))
 }
 @MainActor func testStorePreservesDataAfterRejectedImport() throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let suite = "berlin.aia.crisis.test.\(UUID().uuidString)"
  let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
  defer { preferences.removePersistentDomain(forName: suite) }
  let store = try CrisisStore(preferences: preferences, directory: directory)
  let valid = directory.appendingPathComponent("valid.json")
  try fixture("golden-data").write(to: valid)
  store.load(valid)
  XCTAssertEqual(store.data.source, "Test fixture")
  let invalid = directory.appendingPathComponent("invalid.json")
  try Data("{}".utf8).write(to: invalid)
  store.load(invalid)
  XCTAssertEqual(store.data.source, "Test fixture")
  XCTAssertTrue(store.message.contains("Import abgelehnt"))
  let restored = try CrisisStore(preferences: preferences, directory: directory)
  XCTAssertEqual(restored.data.source, "Test fixture")
 }
 @MainActor func testBrandingAndCorruptStorageRecovery() throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let suite = "berlin.aia.crisis.test.\(UUID().uuidString)"
  let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
  defer { preferences.removePersistentDomain(forName: suite) }
  let store = try CrisisStore(preferences: preferences, directory: directory)
  store.partner = "Persistente Beratung"; store.theme = "teal"
  let broken = directory.appendingPathComponent("market.json")
  try Data("broken-json".utf8).write(to: broken)
  let restored = try CrisisStore(preferences: preferences, directory: directory)
  XCTAssertEqual(restored.partner, "Persistente Beratung")
  XCTAssertEqual(restored.theme, "teal")
  XCTAssertEqual(restored.data.kind, "import")
  XCTAssertTrue(restored.message.contains("bleibt erhalten"))
  XCTAssertEqual(try String(contentsOf: broken, encoding: .utf8), "broken-json")
 }
 @MainActor func testBoundedFileReadRejectsOversizedInput() throws {
  let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: file) }
  try Data(repeating: 32, count: 2 * 1024 * 1024 + 1).write(to: file)
  XCTAssertThrowsError(try CrisisStore.readBounded(file))
 }
 func testPurchasingPowerMatchesSharedReference() throws {
  let data = try CrisisEngine.parse(fixture("golden-data"))
  let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture("planning-vectors")) as? [String: Any])
  let expected = try XCTUnwrap(raw["historical"] as? [String: Double])
  let result = try CrisisEngine.purchasingPower(data, amount: expected["amount"]!, from: Int(expected["from"]!), to: Int(expected["to"]!))
  XCTAssertEqual(result.factor, expected["factor"]!, accuracy: 1e-10)
  XCTAssertEqual(result.requiredAmount, expected["requiredAmount"]!, accuracy: 1e-10)
  XCTAssertEqual(result.remainingPower, expected["remainingPower"]!, accuracy: 1e-10)
  XCTAssertEqual(result.lossPercent, expected["lossPercent"]!, accuracy: 1e-10)
 }
 func testInflationScenarioAndDeflationReferences() throws {
  let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture("planning-vectors")) as? [String: Any])
  for key in ["scenario", "deflation"] {
   let expected = try XCTUnwrap(raw[key] as? [String: Double])
   let result = try CrisisEngine.inflationScenario(amount: expected["amount"]!, ratePercent: expected["ratePercent"]!, years: Int(expected["years"]!))
   XCTAssertEqual(result.factor, expected["factor"]!, accuracy: 1e-10)
   XCTAssertEqual(result.requiredAmount, expected["requiredAmount"]!, accuracy: 1e-10)
   XCTAssertEqual(result.remainingPower, expected["remainingPower"]!, accuracy: 1e-10)
  }
 }
 func testPurchasingPowerRejectsMissingYearsAndExtremeInputs() throws {
  let data = try CrisisEngine.parse(fixture("golden-data"))
  XCTAssertThrowsError(try CrisisEngine.purchasingPower(data, amount: 10000, from: 2020, to: 2023))
  XCTAssertThrowsError(try CrisisEngine.purchasingPower(data, amount: 10000, from: 2022, to: 2020))
  for amount in [0, -1, .infinity, .nan, 1e13] { XCTAssertThrowsError(try CrisisEngine.inflationScenario(amount: amount, ratePercent: 3, years: 10)) }
  XCTAssertThrowsError(try CrisisEngine.inflationScenario(amount: 10000, ratePercent: 101, years: 10))
  XCTAssertThrowsError(try CrisisEngine.inflationScenario(amount: 10000, ratePercent: 3, years: 0))
  XCTAssertThrowsError(try CrisisEngine.inflationScenario(amount: 1e12, ratePercent: 100, years: 100))
 }
 func testPlanValidationCountsAndReport() throws {
  let document = try JSONDecoder().decode(PlanningDocument.self, from: fixture("planning"))
  var plan = PlanningEngine.empty(document)
  XCTAssertEqual(PlanningEngine.counts(plan).open, 5)
  plan.answers["liquidity"] = PlanningAnswer(status: "documented", note: "Reserve dokumentiert")
  plan.answers["access"] = PlanningAnswer(status: "needs_action", note: "Vertretung prüfen")
  plan.action = "Vertretung gemeinsam testen"; plan.owner = "Eigene Zuständigkeit"; plan.reviewDate = "2026-11-30"
  try PlanningEngine.validate(plan, document: document)
  let counts = PlanningEngine.counts(plan)
  XCTAssertEqual(counts.reviewed, 2); XCTAssertEqual(counts.open, 4); XCTAssertEqual(counts.needsAction, 1)
  let report = try PlanningEngine.report(plan, document: document, partner: "Beratung", date: "2026-10-28")
  XCTAssertTrue(report.contains(plan.action)); XCTAssertTrue(report.contains(document.questions[0].source))
  plan.reviewDate = "2026-02-30"
  XCTAssertThrowsError(try PlanningEngine.validate(plan, document: document))
  plan.reviewDate = ""; plan.answers["liquidity"]?.note = String(repeating: "a", count: 501)
  XCTAssertThrowsError(try PlanningEngine.validate(plan, document: document))
  plan.answers.removeValue(forKey: "liquidity")
  XCTAssertThrowsError(try PlanningEngine.validate(plan, document: document))
 }
 @MainActor func testPlanSavedLocallyRestoredDeletedAndCorruptFilePreserved() throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let suite = "berlin.aia.crisis.test.\(UUID().uuidString)"
  let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
  defer { preferences.removePersistentDomain(forName: suite) }
  let store = try CrisisStore(preferences: preferences, directory: directory)
  store.plan.answers["liquidity"]?.note = "Eigene persönliche Notiz"
  store.plan.action = "Nächsten Schritt prüfen"
  store.savePlan()
  let restored = try CrisisStore(preferences: preferences, directory: directory)
  XCTAssertEqual(restored.plan.action, "Nächsten Schritt prüfen")
  XCTAssertEqual(restored.plan.answers["liquidity"]?.note, "Eigene persönliche Notiz")
  let planFile = directory.appendingPathComponent("planning.json")
  XCTAssertTrue(FileManager.default.fileExists(atPath: planFile.path))
  restored.deletePlan()
  XCTAssertFalse(FileManager.default.fileExists(atPath: planFile.path))
  XCTAssertEqual(restored.plan.action, "")
  try Data("invalid-plan".utf8).write(to: planFile)
  let recovery = try CrisisStore(preferences: preferences, directory: directory)
  XCTAssertEqual(recovery.plan.action, "")
  XCTAssertTrue(recovery.message.contains("Originaldatei bleibt erhalten"))
  XCTAssertEqual(try String(contentsOf: planFile, encoding: .utf8), "invalid-plan")
 }
}
