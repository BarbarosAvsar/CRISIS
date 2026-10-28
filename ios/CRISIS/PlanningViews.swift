import SwiftUI
import UniformTypeIdentifiers

private func inputNumber(_ text: String) -> Double? {
 Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
}
struct PurchasingPowerView: View {
 @EnvironmentObject var store: CrisisStore
 @State private var amount = "10000"
 @State private var from = ""
 @State private var to = ""
 @State private var scenarioAmount = "10000"
 @State private var rate = "3"
 @State private var years = "10"
 private var historical: Result<PurchasingPowerResult, Error> {
  Result {
   guard let a = inputNumber(amount), let f = Int(from), let t = Int(to) else { throw CrisisError(message: "Betrag und vollständige Jahre eingeben.") }
   return try CrisisEngine.purchasingPower(store.data, amount: a, from: f, to: t)
  }
 }
 private var scenario: Result<InflationScenarioResult, Error> {
  Result {
   guard let a = inputNumber(scenarioAmount), let r = inputNumber(rate), let y = Int(years) else { throw CrisisError(message: "Betrag, angenommene Jahresrate und ganze Anzahl Jahre eingeben.") }
   return try CrisisEngine.inflationScenario(amount: a, ratePercent: r, years: y)
  }
 }
 var body: some View {
  Screen(title: "Kaufkraft") {
   Text("Was bleibt von Ihrem Betrag?").font(.largeTitle)
   Text("Historische Preisentwicklung nachvollziehen und eine eigene Zukunftsannahme getrennt durchrechnen.")
   Panel(title: "Historischer Kaufkraftvergleich") {
    Text("CPI: \(store.data.cpiRegion). Quelle: \(store.data.source). Datenstand: \(store.data.asOf).").font(.caption)
    Text("Einheit: CPI-Bezugswährung / Geldeinheiten. Der geladene US-CPI beschreibt US-Kaufkraft und ist keine EUR-Umrechnung.").font(.footnote)
    TextField("Betrag ohne Tausendertrennzeichen", text: $amount).keyboardType(.decimalPad).textFieldStyle(.roundedBorder).accessibilityIdentifier("power-amount")
    HStack {
     TextField("Startjahr", text: $from).keyboardType(.numberPad).accessibilityLabel("Startjahr Kaufkraft").accessibilityIdentifier("power-from")
     TextField("Endjahr", text: $to).keyboardType(.numberPad).accessibilityLabel("Endjahr Kaufkraft").accessibilityIdentifier("power-to")
    }.textFieldStyle(.roundedBorder)
    Text("Verfügbare CPI-Jahre: \(store.data.cpi.first?.year ?? 0)–\(store.data.cpi.last?.year ?? 0). Nur exakt vorhandene Beobachtungen, keine Interpolation.").font(.caption)
    switch historical {
    case .success(let r):
     VStack(alignment: .leading, spacing: 8) {
      Text("\(number(r.amount)) → \(number(r.remainingPower)) Geldeinheiten Kaufkraft").font(.title3)
      Text("Benötigter Betrag im Endjahr für gleiche Kaufkraft: \(number(r.requiredAmount))")
      Text("Preisänderung: \(number(r.priceChangePercent)) % · Kaufkraftverlust: \(number(r.lossPercent)) %")
      Text("Ein negativer Kaufkraftverlust bedeutet einen Kaufkraftzuwachs. Die Rechnung unterstellt einen unveränderten nominalen Betrag ohne Zinsen oder Kosten.").font(.caption)
     }.accessibilityElement(children: .combine).accessibilityIdentifier("power-historical-result")
    case .failure(let e): Note(text: e.localizedDescription).accessibilityIdentifier("power-historical-error")
    }
   }
   Panel(title: "Eigene Inflationsannahme") {
    Note(text: "Ihre Annahme, keine Prognose. Diese Rechnung ist unabhängig von den historischen CPI-Daten und vom Zyklusmodell.")
    TextField("Betrag ohne Tausendertrennzeichen", text: $scenarioAmount).keyboardType(.decimalPad).textFieldStyle(.roundedBorder).accessibilityIdentifier("scenario-amount")
    TextField("Angenommene Inflation % pro Jahr", text: $rate).keyboardType(.numbersAndPunctuation).textFieldStyle(.roundedBorder).accessibilityIdentifier("scenario-rate")
    TextField("Jahre (1–100)", text: $years).keyboardType(.numberPad).textFieldStyle(.roundedBorder).accessibilityIdentifier("scenario-years")
    switch scenario {
    case .success(let r):
     VStack(alignment: .leading, spacing: 8) {
      Text("Verbleibende Kaufkraft: \(number(r.remainingPower)) Geldeinheiten").font(.title3)
      Text("Für gleiche Kaufkraft benötigt: \(number(r.requiredAmount)) Geldeinheiten")
      Text("Bei \(number(r.ratePercent)) % pro Jahr über \(r.years) Jahre: Preisänderung \(number(r.priceChangePercent)) % · Kaufkraftverlust \(number(r.lossPercent)) %")
     }.accessibilityElement(children: .combine).accessibilityIdentifier("power-scenario-result")
    case .failure(let e): Note(text: e.localizedDescription).accessibilityIdentifier("power-scenario-error")
    }
   }
  }.onAppear { selectDefaultYears() }.onChange(of: store.revision) { _ in selectDefaultYears() }
 }
 private func selectDefaultYears() {
  let points = store.data.cpi
  guard let first = points.first, let last = points.last else { return }
  from = String(points.first(where: { $0.year >= last.year - 10 && $0.year < last.year })?.year ?? first.year)
  to = String(last.year)
 }
}

struct PlanningTextDocument: FileDocument {
 static var readableContentTypes: [UTType] { [.plainText] }
 var text: String
 init(text: String) { self.text = text }
 init(configuration: ReadConfiguration) throws { text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? "" }
 func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}
struct StructureCheckView: View {
 @EnvironmentObject var store: CrisisStore
 @State private var exporting = false
 @State private var exportText = ""
 @State private var deleting = false
 private var counts: PlanCounts { PlanningEngine.counts(store.plan) }
 private func answerStatus(_ id: String) -> Binding<String> {
  Binding(get: { store.plan.answers[id]?.status ?? "unreviewed" }, set: { value in
   var answer = store.plan.answers[id] ?? PlanningAnswer(status: "unreviewed", note: "")
   answer.status = value; store.plan.answers[id] = answer
  })
 }
 private func answerNote(_ id: String) -> Binding<String> {
  Binding(get: { store.plan.answers[id]?.note ?? "" }, set: { value in
   var answer = store.plan.answers[id] ?? PlanningAnswer(status: "unreviewed", note: "")
   answer.note = PlanningEngine.limited(value, units: 500); store.plan.answers[id] = answer
  })
 }
 var body: some View {
  Screen(title: store.planning.title) {
   Text("Struktur klären. Nächsten Schritt festhalten.").font(.largeTitle)
   Text(store.planning.purpose)
   Note(text: "Persönliche Angaben werden nur nach „Lokal speichern“ gesichert und nicht an den Datenadapter übertragen. Keine Kontonummern, Passwörter oder sonstigen Zugangsdaten eintragen.")
   Panel(title: "Ihr Bearbeitungsstand") {
    Text("\(counts.reviewed) von \(counts.total) bearbeitet · \(counts.open) offen").accessibilityIdentifier("plan-progress")
    Text("Dokumentiert: \(counts.documented) · Handlungsbedarf: \(counts.needsAction) · Nicht zutreffend: \(counts.notApplicable)")
    Text("Offen umfasst noch ungeprüfte Fragen und festgehaltenen Handlungsbedarf. Das ist kein Risiko- oder Sicherheitsrating.").font(.caption)
   }
   ForEach(store.planning.questions) { question in
    Panel(title: question.title) {
     Text(question.text)
     Text(question.why).font(.footnote)
     Picker("Status", selection: answerStatus(question.id)) {
      ForEach(PlanningEngine.statuses, id: \.self) { value in Text(PlanningEngine.statusLabel(value)).tag(value) }
     }.accessibilityIdentifier("plan-status-" + question.id)
     TextField("Eigene Notiz (max. 500 Zeichen)", text: answerNote(question.id), axis: .vertical).lineLimit(3...6).textFieldStyle(.roundedBorder).accessibilityIdentifier("plan-note-" + question.id)
     Text(question.source).font(.caption).foregroundStyle(.secondary)
    }
   }
   Panel(title: "Ein konkreter nächster Schritt") {
    TextField("Nächster Schritt (max. 1000 Zeichen)", text: Binding(get: { store.plan.action }, set: { store.plan.action = PlanningEngine.limited($0, units: 1000) }), axis: .vertical).lineLimit(3...6).textFieldStyle(.roundedBorder).accessibilityIdentifier("plan-action")
    TextField("Verantwortlich (max. 80 Zeichen)", text: Binding(get: { store.plan.owner }, set: { store.plan.owner = PlanningEngine.limited($0, units: 80) })).textFieldStyle(.roundedBorder).accessibilityIdentifier("plan-owner")
    TextField("Prüftermin JJJJ-MM-TT (optional)", text: $store.plan.reviewDate).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder).accessibilityIdentifier("plan-review-date")
   }
   Button("Lokal speichern") { store.savePlan() }.buttonStyle(.borderedProminent).accessibilityIdentifier("plan-save")
   Button("Bericht als TXT exportieren") {
    do {
     let date = ISO8601DateFormatter().string(from: Date())
     exportText = try PlanningEngine.report(store.plan, document: store.planning, partner: store.partner, date: date)
     exporting = true
    } catch { store.message = error.localizedDescription }
   }.buttonStyle(.bordered).accessibilityIdentifier("plan-export")
   Button("Strukturcheck löschen", role: .destructive) { deleting = true }.accessibilityIdentifier("plan-delete")
  }.fileExporter(isPresented: $exporting, document: PlanningTextDocument(text: exportText), contentType: .plainText, defaultFilename: "crisis-strukturcheck") { if case .failure(let e) = $0 { store.message = e.localizedDescription } }
   .confirmationDialog("Gespeicherten Strukturcheck und aktuellen Entwurf löschen?", isPresented: $deleting, titleVisibility: .visible) {
    Button("Strukturcheck endgültig löschen", role: .destructive) { store.deletePlan() }
    Button("Abbrechen", role: .cancel) {}
   }
 }
}
