import Foundation

struct PurchasingPowerResult {
 let amount: Double
 let from: Int
 let to: Int
 let factor: Double
 let requiredAmount: Double
 let remainingPower: Double
 let lossPercent: Double
 let priceChangePercent: Double
}
struct InflationScenarioResult {
 let amount: Double
 let ratePercent: Double
 let years: Int
 let factor: Double
 let requiredAmount: Double
 let remainingPower: Double
 let lossPercent: Double
 let priceChangePercent: Double
}
extension CrisisEngine {
 static func purchasingPower(_ data: MarketData, amount: Double, from: Int, to: Int) throws -> PurchasingPowerResult {
  guard from < to, let start = data.cpi.first(where: { $0.year == from }), let end = data.cpi.first(where: { $0.year == to }) else { throw CrisisError(message: "Start- und Endjahr müssen als CPI-Werte vorliegen; Start vor Ende wählen. Es wird nicht interpoliert.") }
  let values = try PlanningEngine.calculate(amount: amount, factor: end.value / start.value)
  return PurchasingPowerResult(amount: amount, from: from, to: to, factor: values.factor, requiredAmount: values.required, remainingPower: values.remaining, lossPercent: values.loss, priceChangePercent: values.change)
 }
 static func inflationScenario(amount: Double, ratePercent: Double, years: Int) throws -> InflationScenarioResult {
  guard ratePercent.isFinite, (-50...100).contains(ratePercent), (1...100).contains(years) else { throw CrisisError(message: "Jahre: 1–100. Angenommene jährliche Inflation: −50 bis 100 Prozent.") }
  let values = try PlanningEngine.calculate(amount: amount, factor: pow(1 + ratePercent / 100, Double(years)))
  return InflationScenarioResult(amount: amount, ratePercent: ratePercent, years: years, factor: values.factor, requiredAmount: values.required, remainingPower: values.remaining, lossPercent: values.loss, priceChangePercent: values.change)
 }
}

struct PlanningQuestion: Codable, Identifiable {
 let id: String
 let title: String
 let text: String
 let source: String
 let why: String
}
struct PlanningDocument: Codable {
 let schemaVersion: Int
 let title: String
 let purpose: String
 let questions: [PlanningQuestion]
}
struct PlanningAnswer: Codable {
 var status: String
 var note: String
}
struct PersonalPlan: Codable {
 var schemaVersion: Int
 var answers: [String: PlanningAnswer]
 var action: String
 var owner: String
 var reviewDate: String
}
struct PlanCounts { let total: Int; let reviewed: Int; let open: Int; let documented: Int; let needsAction: Int; let notApplicable: Int }

enum PlanningEngine {
 static let statuses = ["unreviewed", "documented", "needs_action", "not_applicable"]
 static func limited(_ text: String, units: Int) -> String {
  var result = "", used = 0
  for character in text {
   let size = String(character).utf16.count
   if used + size > units { break }
   result.append(character); used += size
  }
  return result
 }
 static func statusLabel(_ value: String) -> String {
  switch value { case "documented": return "Dokumentiert"; case "needs_action": return "Handlungsbedarf"; case "not_applicable": return "Nicht zutreffend"; default: return "Noch offen" }
 }
 static func calculate(amount: Double, factor: Double) throws -> (factor: Double, required: Double, remaining: Double, loss: Double, change: Double) {
  guard amount.isFinite, amount > 0, amount <= 1e12 else { throw CrisisError(message: "Ein positiver Betrag bis 1.000.000.000.000 Geldeinheiten ist erforderlich.") }
  let required = amount * factor, remaining = amount / factor
  guard factor.isFinite, factor > 0, factor <= 1e15, required.isFinite, required > 0, required <= 1e15, remaining.isFinite, remaining > 0, remaining <= 1e15 else { throw CrisisError(message: "Die Angaben ergeben keinen darstellbaren Kaufkraftwert.") }
  let loss = (1 - 1 / factor) * 100, change = (factor - 1) * 100
  guard loss.isFinite, change.isFinite else { throw CrisisError(message: "Die Angaben ergeben keinen darstellbaren Kaufkraftwert.") }
  return (factor,required,remaining,loss,change)
 }
 static func empty(_ document: PlanningDocument) -> PersonalPlan {
  PersonalPlan(schemaVersion: 1, answers: Dictionary(uniqueKeysWithValues: document.questions.map { ($0.id, PlanningAnswer(status: "unreviewed", note: "")) }), action: "", owner: "", reviewDate: "")
 }
 static func validate(_ plan: PersonalPlan, document: PlanningDocument) throws {
  guard plan.schemaVersion == 1, Set(plan.answers.keys) == Set(document.questions.map(\.id)), plan.action.utf16.count <= 1000, plan.owner.utf16.count <= 80 else { throw CrisisError(message: "Ungültiger Strukturcheck oder zu lange Angaben.") }
  for answer in plan.answers.values { guard statuses.contains(answer.status), answer.note.utf16.count <= 500 else { throw CrisisError(message: "Ungültiger Status oder Notiz mit mehr als 500 Zeichen.") } }
  if !plan.reviewDate.isEmpty {
   let format = DateFormatter(); format.locale = Locale(identifier: "en_US_POSIX"); format.dateFormat = "yyyy-MM-dd"; format.isLenient = false
   guard plan.reviewDate.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil, let date = format.date(from: plan.reviewDate), format.string(from: date) == plan.reviewDate else { throw CrisisError(message: "Prüftermin als gültiges Datum JJJJ-MM-TT eingeben oder leer lassen.") }
  }
 }
 static func parse(_ bytes: Data, document: PlanningDocument) throws -> PersonalPlan {
  guard bytes.count <= 32 * 1024 else { throw CrisisError(message: "Gespeicherter Strukturcheck ist zu groß.") }
  let plan = try JSONDecoder().decode(PersonalPlan.self, from: bytes)
  try validate(plan, document: document)
  return plan
 }
 static func counts(_ plan: PersonalPlan) -> PlanCounts {
  let values = plan.answers.values.map(\.status)
  return PlanCounts(total: values.count, reviewed: values.filter { $0 != "unreviewed" }.count, open: values.filter { $0 == "unreviewed" || $0 == "needs_action" }.count, documented: values.filter { $0 == "documented" }.count, needsAction: values.filter { $0 == "needs_action" }.count, notApplicable: values.filter { $0 == "not_applicable" }.count)
 }
 static func report(_ plan: PersonalPlan, document: PlanningDocument, partner: String, date: String) throws -> String {
  try validate(plan, document: document)
  let counts = counts(plan)
  var lines = ["CRISIS © · Strukturcheck", "Stand: \(date)", "Partner: \(partner.isEmpty ? "Nicht angegeben" : partner)", document.purpose, "", "Bearbeitet: \(counts.reviewed) / \(document.questions.count) · Offen: \(counts.open) · Handlungsbedarf: \(counts.needsAction)", "Kein Risiko- oder Sicherheitsrating.", ""]
  for q in document.questions {
   let a = plan.answers[q.id]!
   lines += [q.title, q.text, "Status: \(statusLabel(a.status))", "Notiz: \(a.note.isEmpty ? "Keine Notiz" : a.note)", "Quelle: \(q.source)", ""]
  }
  lines += ["Nächster Schritt: \(plan.action.isEmpty ? "Noch nicht festgelegt" : plan.action)", "Verantwortlich: \(plan.owner.isEmpty ? "Noch nicht festgelegt" : plan.owner)", "Prüftermin: \(plan.reviewDate.isEmpty ? "Noch nicht festgelegt" : plan.reviewDate)", "", "Lokale Selbstdokumentation. Keine Anlage-, Rechts- oder Steuerberatung."]
  return lines.joined(separator: "\n") + "\n"
 }
}
