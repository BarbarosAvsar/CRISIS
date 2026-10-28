import Foundation

struct Point: Codable, Identifiable { var id: Int { year }; let year: Int; let value: Double }
struct Series: Codable, Identifiable { let id: String; let name: String; let group: String; let unit: String; let currency: String; var points: [Point] }
struct Macro: Codable, Identifiable { var id: String { country }; let country: String; let inflation: Double?; let military: Double?; let gdp: Double? }
struct MarketData: Codable { let schemaVersion: Int; let kind: String; let asOf: String; let source: String; let cpiRegion: String; let cpi: [Point]; let series: [Series]; let macro: [Macro] }
struct Cycle: Codable, Identifiable { let id: String; let name: String; let start: Int; let steps: [Int] }
struct CrisisDocument: Codable, Identifiable { var id: String { title }; let title: String; let file: String; let pages: [String] }
struct Source: Codable, Identifiable { var id: String { url }; let provider: String; let label: String; let url: String }
struct Field: Codable, Identifiable { var id: String { title }; let title: String; let text: String }
struct Content: Codable { let cycles: [Cycle]; let documents: [CrisisDocument]; let sources: [Source]; let fields: [Field] }
struct CrisisError: LocalizedError { let message: String; var errorDescription: String? { message } }

enum CrisisEngine {
 static func years(_ c: Cycle, from: Int = 1926, to: Int = 2126) -> [Int] {
  guard from >= 1800, to <= 2200, from <= to, !c.steps.isEmpty, c.steps.allSatisfy({ $0 > 0 }) else { return [] }
  var y = c.start, i = 0, out: [Int] = []
  while y <= to { if y >= from { out.append(y) }; y += c.steps[i % c.steps.count]; i += 1 }; return out
 }
 static func parse(_ bytes: Data) throws -> MarketData {
  func check(_ condition: Bool, _ text: String) throws { if !condition { throw CrisisError(message: text) } }
  try check(bytes.count <= 2 * 1024 * 1024, "Maximal 2 MB erlaubt.")
  let d = try JSONDecoder().decode(MarketData.self, from: bytes)
  try check(d.schemaVersion == 1 && ["demo", "import"].contains(d.kind), "Schema v1 und kind demo/import erforderlich.")
  let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); f.isLenient = false
  try check(d.asOf.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil && f.date(from: d.asOf) != nil, "Ungültiger Datenstand.")
  try check(!d.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && d.source.count <= 500 && !d.cpiRegion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && d.cpiRegion.count <= 500, "Quelle und CPI-Region erforderlich.")
  func points(_ p: [Point]) throws {
   try check((1...401).contains(p.count), "1–401 Werte erforderlich."); var prev = 0
   for v in p { try check((1800...2200).contains(v.year) && v.year > prev && v.value.isFinite && v.value > 0 && v.value <= 1e15, "Sortierte Jahre und positive Werte erforderlich."); prev = v.year }
  }
  try points(d.cpi); try check((1...30).contains(d.series.count), "1–30 Datenreihen erforderlich.")
  try check(Set(d.series.map(\.id)).count == d.series.count, "Doppelte Reihen-ID.")
  for s in d.series {
   try check(s.id.range(of: #"^[a-z][a-z0-9-]{0,39}$"#, options: .regularExpression) != nil, "Ungültige Reihen-ID.")
   for v in [s.name, s.group, s.unit, s.currency] { try check(!v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && v.count <= 100, "Ungültiges Reihenfeld.") }; try points(s.points)
  }
  try check(d.macro.count <= 20, "Zu viele Länder.")
  // Require explicitly present nullable macro fields, matching the JSON contract.
  let raw = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
  let rawMacro = raw?["macro"] as? [[String: Any]] ?? []
  for m in rawMacro { try check(["inflation", "military", "gdp"].allSatisfy { m.keys.contains($0) }, "Makrofelder fehlen.") }
  for m in d.macro {
   try check(!m.country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && m.country.count <= 100, "Land fehlt.")
   for n in [m.inflation, m.military, m.gdp].compactMap({ $0 }) { try check(n.isFinite && abs(n) <= 1e15, "Ungültiger Makrowert.") }
   try check((m.military ?? 0) >= 0 && (m.gdp ?? 0) >= 0, "Negative Makrowerte.")
  }
  return d
 }
 static func compare(_ d: MarketData, ids: Set<String>, from: Int, to: Int, real: Bool) throws -> [Series] {
  guard from >= 1800, to <= 2200, from <= to else { throw CrisisError(message: "Jahresbereich 1800–2200 erforderlich.") }
  let ss = d.series.filter { ids.contains($0.id) }; guard let first = ss.first else { throw CrisisError(message: "Mindestens ein Asset auswählen.") }
  let cpi = Dictionary(uniqueKeysWithValues: d.cpi.map { ($0.year, $0.value) })
  let years = first.points.map(\.year).filter { y in y >= from && y <= to && ss.allSatisfy { $0.points.contains { $0.year == y } } && (!real || cpi[y] != nil) }
  guard years.count >= 2, let base = years.first else { throw CrisisError(message: "Mindestens zwei gemeinsame Jahreswerte (ggf. mit CPI) erforderlich.") }
  return ss.map { s in
   let map = Dictionary(uniqueKeysWithValues: s.points.map { ($0.year, $0.value) }); var next = s
   next.points = years.map { y in Point(year: y, value: map[y]! / map[base]! * 100 * (real ? cpi[base]! / cpi[y]! : 1)) }; return next
  }
 }
 static func ratio(_ d: MarketData) -> Point? {
  guard let a = d.series.first(where: { $0.id == "gold" }), let b = d.series.first(where: { $0.id == "silver" }), a.currency == b.currency, a.unit == b.unit else { return nil }
  for p in a.points.reversed() { if let q = b.points.first(where: { $0.year == p.year }) { return Point(year: p.year, value: p.value / q.value) } }; return nil
 }
 static func csvLabel(_ name: String) -> String {
  let safe = name.range(of: #"^[\s]*[=+\-@]|^[\t\r\n]"#, options: .regularExpression) != nil ? "'" + name : name
  return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
 }
 static func csv(_ ss: [Series]) -> String {
  "Asset;Jahr;Index\n" + ss.flatMap { s in s.points.map { p in "\(csvLabel(s.name));\(p.year);\(String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), p.value))" } }.joined(separator: "\n") + "\n"
 }
}
