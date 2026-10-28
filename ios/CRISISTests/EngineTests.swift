import XCTest
@testable import CRISIS
final class EngineTests: XCTestCase {
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
}
