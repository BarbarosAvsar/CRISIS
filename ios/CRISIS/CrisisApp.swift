import SwiftUI
import UIKit
import Charts
import UniformTypeIdentifiers

let navy = Color(red: 15/255, green: 28/255, blue: 61/255)
let rose = Color(red: 232/255, green: 185/255, blue: 200/255)
let teal = Color(red: 199/255, green: 232/255, blue: 227/255)
let plotColors: [Color] = [navy, Color(red: 153/255, green: 97/255, blue: 58/255), Color(red: 38/255, green: 116/255, blue: 104/255), Color(red: 147/255, green: 61/255, blue: 97/255), Color(red: 101/255, green: 86/255, blue: 157/255), Color(red: 157/255, green: 86/255, blue: 29/255), Color(red: 39/255, green: 111/255, blue: 156/255), Color(red: 116/255, green: 100/255, blue: 20/255), Color(red: 173/255, green: 49/255, blue: 82/255), Color(red: 53/255, green: 79/255, blue: 57/255)]
func number(_ n: Double) -> String { n.formatted(.number.locale(Locale(identifier: "de_DE")).precision(.fractionLength(2))) }

@MainActor final class CrisisStore: ObservableObject {
 @Published var data: MarketData
 let content: Content
 let demoBytes: Data
 let planning: PlanningDocument
 @Published var plan: PersonalPlan
 @Published var partner: String { didSet { preferences.set(String(partner.prefix(60)), forKey: "partner") } }
 @Published var theme: String { didSet { preferences.set(theme, forKey: "theme") } }
 @Published var revision = 0
 @Published var message = ""
 @Published var refreshing = false
 @Published var provenance: MarketProvenance?
 private let file: URL
 private let planFile: URL
 private let preferences: UserDefaults
 init(preferences: UserDefaults = .standard, directory: URL? = nil) throws {
  self.preferences = preferences
  guard let c = Bundle.main.url(forResource: "content", withExtension: "json"), let d = Bundle.main.url(forResource: "demo-data", withExtension: "json"), let history = Bundle.main.url(forResource: "market-data", withExtension: "json"), let planningFile = Bundle.main.url(forResource: "planning", withExtension: "json") else { throw CrisisError(message: "Gebündelte Daten fehlen.") }
  content = try JSONDecoder().decode(Content.self, from: Data(contentsOf: c)); demoBytes = try Data(contentsOf: d)
  planning = try JSONDecoder().decode(PlanningDocument.self, from: Self.readBounded(planningFile))
  let folder = try directory ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  file = folder.appendingPathComponent("market.json")
  planFile = folder.appendingPathComponent("planning.json")
  var loadWarning = ""
  if FileManager.default.fileExists(atPath: file.path) {
   do { let restored = try Self.decodeStored(Self.readBounded(file, limit: 3 * 1024 * 1024)); data = restored.data; provenance = restored.provenance }
   catch { data = try CrisisEngine.parse(Self.readBounded(history)); loadWarning = "Gespeicherte Daten konnten nicht gelesen werden. Historische Daten werden angezeigt; die gespeicherte Datei bleibt erhalten." }
  } else { data = try CrisisEngine.parse(Self.readBounded(history)) }
  if FileManager.default.fileExists(atPath: planFile.path) {
   do { plan = try PlanningEngine.parse(Self.readBounded(planFile, limit: 32 * 1024), document: planning) }
   catch { plan = PlanningEngine.empty(planning); loadWarning += " Gespeicherter Strukturcheck ist ungültig; die Originaldatei bleibt erhalten. Ein leerer Entwurf wird angezeigt." }
  } else { plan = PlanningEngine.empty(planning) }
  partner = String((preferences.string(forKey: "partner") ?? "").prefix(60))
  let savedTheme = preferences.string(forKey: "theme") ?? "navy"
  theme = ["navy", "rose", "teal"].contains(savedTheme) ? savedTheme : "navy"
  message = loadWarning
 }
 static func readBounded(_ url: URL, limit: Int = 2 * 1024 * 1024) throws -> Data {
  let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
  var bytes = Data()
  while let chunk = try handle.read(upToCount: 65_536), !chunk.isEmpty {
   guard bytes.count + chunk.count <= limit else { throw CrisisError(message: "Datei überschreitet die erlaubte Größe.") }
   bytes.append(chunk)
  }
  return bytes
 }
 static func decodeStored(_ bytes: Data) throws -> StoredMarket {
  let raw = try JSONSerialization.jsonObject(with: bytes)
  if let wrapper = raw as? [String: Any], let inner = wrapper["data"] {
   return StoredMarket(data: try CrisisEngine.parse(JSONSerialization.data(withJSONObject: inner)), provenance: try MarketProvenance.parse(wrapper["provenance"] is NSNull ? nil : wrapper["provenance"]))
  }
  return StoredMarket(data: try CrisisEngine.parse(bytes), provenance: nil)
 }
 private func save(_ next: MarketData, info: MarketProvenance? = nil) throws {
  let bytes = try JSONEncoder().encode(StoredMarket(data: next, provenance: info))
  guard bytes.count <= 3 * 1024 * 1024 else { throw CrisisError(message: "Datensatz ist zu groß.") }
  try bytes.write(to: file, options: .atomic)
  data = next; provenance = info; revision += 1
 }
 var accent: Color { theme == "teal" ? Color(red: 40/255, green: 108/255, blue: 96/255) : theme == "rose" ? Color(red: 135/255, green: 62/255, blue: 89/255) : navy }
 func load(_ url: URL) {
  let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
  do {
   let bytes = try Self.readBounded(url)
   let next = try CrisisEngine.parse(bytes); try save(next); message = "Datensatz geprüft und importiert."
  } catch { message = "Import abgelehnt: \(error.localizedDescription)" }
 }
 func historical() {
  do {
   guard let url = Bundle.main.url(forResource: "market-data", withExtension: "json") else { throw CrisisError(message: "Historischer Datensatz ist nicht gebündelt.") }
   let bytes = try Self.readBounded(url)
   let next = try CrisisEngine.parse(bytes)
   try save(next)
   message = "Echte historische Daten geladen. Stand und Quelle sind im Datenhinweis angegeben; keine laufenden Börsenkurse."
  } catch { message = "Historische Daten konnten nicht geladen werden: \(error.localizedDescription)" }
 }
 func refresh(_ address: String) async {
  guard !refreshing else { return }
  refreshing = true; defer { refreshing = false }
  do {
   let response = try await LiveDataClient.fetch(address)
   let object = try JSONSerialization.jsonObject(with: response)
   let payload: Data
   var info: MarketProvenance? = nil
   if let wrapper = object as? [String: Any], let inner = wrapper["data"] { payload = try JSONSerialization.data(withJSONObject: inner); info = try MarketProvenance.parse(wrapper["provenance"]) }
   else { payload = response }
   let next = try CrisisEngine.parse(payload)
   guard next.kind == "import" else { throw CrisisError(message: "Der Datenserver hat Beispieldaten zurückgegeben.") }
   try save(next, info: info)
   message = "Daten vom HTTPS-Adapter aktualisiert. Datenstand: \(next.asOf)."
  } catch { message = "Aktualisierung fehlgeschlagen; bisherige Daten bleiben erhalten: \(error.localizedDescription)" }
 }
 func reset() { do { try save(CrisisEngine.parse(demoBytes)); message = "Beispieldaten wiederhergestellt." } catch { message = error.localizedDescription } }
 func savePlan() {
  do {
   try PlanningEngine.validate(plan, document: planning)
   let bytes = try JSONEncoder().encode(plan)
   guard bytes.count <= 32 * 1024 else { throw CrisisError(message: "Strukturcheck ist zu groß.") }
   try bytes.write(to: planFile, options: .atomic)
   var storageURL = planFile
   var flags = URLResourceValues(); flags.isExcludedFromBackup = true
   try storageURL.setResourceValues(flags)
   message = "Strukturcheck lokal gespeichert. Die Angaben werden nicht an den Datenadapter übertragen."
  } catch { message = "Strukturcheck konnte nicht gespeichert werden: \(error.localizedDescription)" }
 }
 func deletePlan() {
  do {
   if FileManager.default.fileExists(atPath: planFile.path) { try FileManager.default.removeItem(at: planFile) }
   plan = PlanningEngine.empty(planning)
   message = "Gespeicherter Strukturcheck und der aktuelle Entwurf wurden gelöscht."
  } catch { message = "Strukturcheck konnte nicht gelöscht werden: \(error.localizedDescription)" }
 }
}

@main @MainActor struct CrisisApp: App {
 private let result: Result<CrisisStore, Error>
 init() {
  result = Result {
   if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
    let suite = "berlin.aia.crisis.ui-tests"
    guard let defaults = UserDefaults(suiteName: suite) else { throw CrisisError(message: "Testspeicher nicht verfügbar.") }
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("crisis-ui-tests", isDirectory: true)
    if ProcessInfo.processInfo.environment["CRISIS_RESET_STATE"] == "1" {
     defaults.removePersistentDomain(forName: suite)
     let dataFile = folder.appendingPathComponent("market.json")
     if FileManager.default.fileExists(atPath: dataFile.path) { try FileManager.default.removeItem(at: dataFile) }
     let planFile = folder.appendingPathComponent("planning.json")
     if FileManager.default.fileExists(atPath: planFile.path) { try FileManager.default.removeItem(at: planFile) }
    }
    return try CrisisStore(preferences: defaults, directory: folder)
   }
   return try CrisisStore()
  }
 }
 var body: some Scene { WindowGroup { switch result { case .success(let store): RootView(store: store); case .failure(let error): VStack { Text("CRISIS konnte nicht starten.").font(.title); Text(error.localizedDescription) }.padding() } } }
}
struct RootView: View {
 @ObservedObject var store: CrisisStore
 var body: some View {
  TabView {
   NavigationStack { HomeView() }.tabItem { Label("Übersicht", systemImage: "house") }
   NavigationStack { ComparisonView() }.tabItem { Label("Vergleich", systemImage: "chart.xyaxis.line") }
   NavigationStack { CycleView() }.tabItem { Label("Zyklen", systemImage: "clock") }
   NavigationStack { LibraryView() }.tabItem { Label("Wissen", systemImage: "books.vertical") }
   NavigationStack { SettingsView() }.tabItem { Label("Mehr", systemImage: "slider.horizontal.3") }
  }.environmentObject(store).tint(store.accent).preferredColorScheme(.light)
   .alert("CRISIS", isPresented: Binding(get: { !store.message.isEmpty }, set: { if !$0 { store.message = "" } })) { Button("OK") { store.message = "" } } message: { Text(store.message) }
 }
}
struct BrandHeader: View {
 @EnvironmentObject var store: CrisisStore
 var body: some View { VStack(alignment: .leading, spacing: 8) { if let url = Bundle.main.url(forResource: "logo", withExtension: "png"), let image = UIImage(contentsOfFile: url.path) { Image(uiImage: image).resizable().scaledToFit().frame(width: 155, height: 52).accessibilityLabel("CRISIS – Wissen, das Werte schützt.") } else { Text("CRISIS ©").font(.title.bold()) }; if !store.partner.isEmpty { Text("In Kooperation mit \(store.partner)").font(.caption).accessibilityIdentifier("partner-label") } } }
}
struct Screen<Body: View>: View {
 let title: String; @ViewBuilder let content: () -> Body
 var body: some View { ScrollView { VStack(alignment: .leading, spacing: 20) { BrandHeader(); content(); Text("©2026 CRISIS © · ALL I AM Akademie").font(.caption); Text("Orientierung, keine Anlageberatung. Modelljahre sind keine belastbaren Prognosen.").font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity).padding() }.scrollDismissesKeyboard(.interactively).background(Color(red: 247/255, green: 248/255, blue: 250/255)).foregroundStyle(navy).navigationTitle(title).navigationBarTitleDisplayMode(.inline) }
}
struct Panel<Body: View>: View {
 let title: String; @ViewBuilder let content: () -> Body
 var body: some View { VStack(alignment: .leading, spacing: 14) { Text(title).font(.title2); content() }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(.white, in: RoundedRectangle(cornerRadius: 14)) }
}
struct Note: View { let text: String; var body: some View { Text(text).font(.footnote).frame(maxWidth: .infinity, alignment: .leading).padding(14).background(teal, in: RoundedRectangle(cornerRadius: 8)) } }
struct DataNotice: View {
 let d: MarketData
 @EnvironmentObject var store: CrisisStore
 var body: some View { VStack(alignment: .leading, spacing: 10) {
  Note(text: "\(d.kind == "demo" ? "Beispielmodus · Synthetische Werte, keine historischen oder aktuellen Kurse" : "Datenbestand · " + d.source). Stand \(d.asOf). Beobachtungsjahre der Reihen beachten; Datenstand bedeutet keinen Echtzeitkurs.")
  if let info = store.provenance {
   if let provider = info.provider { Text("Quelle: \(provider)").font(.caption) }
   if let time = info.fetchedAt { Text("Abgerufen: \(time)").font(.caption) }
   if info.cached == true { Text("Gespeicherter Abruf").font(.caption) }
   if info.stale == true { Text("Daten sind veraltet; kein aktueller Kurs.").font(.caption.bold()) }
   ForEach(Array((info.notes ?? []).enumerated()), id: \.offset) { _, note in Text(note).font(.caption) }
  }
 } }
}
struct QuotesView: View {
 @EnvironmentObject var store: CrisisStore
 var body: some View {
  if let quotes = store.provenance?.quotes, !quotes.isEmpty {
   Panel(title: "Aktuelle Einzelkurse") {
    Text("Zeitpunktkurse werden separat angezeigt und nicht mit Jahresmittelwerten verrechnet.").font(.caption)
    ForEach(Array(quotes.enumerated()), id: \.offset) { _, q in
     VStack(alignment: .leading, spacing: 5) {
      Text(q.name ?? q.symbol ?? "Kurs").bold()
      Text(q.amount.map { number($0) + " " + (q.unit ?? q.currency ?? "") } ?? "Nicht verfügbar")
      Text(q.asOf ?? q.timestamp ?? "Kein Zeitstempel").font(.caption)
      if let error = q.error { Text(error).font(.caption) }
     }
    }
   }
  }
 }
}
struct HomeView: View {
 @EnvironmentObject var store: CrisisStore
 var body: some View { Screen(title: "Übersicht") {
  Text("MAKRO-INTELLIGENZ FÜR VERMÖGENSSCHUTZ").font(.caption)
  Text("Vermögen verstehen. Handlungsfähig bleiben.").font(.largeTitle)
  Text("Kaufkraft sichtbar machen, Werte vergleichen und den nächsten eigenen Schritt dokumentieren.")
  Panel(title: "Ihr nächster Schritt") {
   NavigationLink("Kaufkraft prüfen") { PurchasingPowerView() }.accessibilityIdentifier("home-purchasing-power")
   NavigationLink("Werte vergleichen") { ComparisonView() }.accessibilityIdentifier("home-compare")
   NavigationLink("Strukturcheck beginnen") { StructureCheckView() }.accessibilityIdentifier("home-structure")
  }
  DataNotice(d: store.data)
  Text("Geladene Reihen: \(store.data.series.map(\.name).joined(separator: ", ")).").font(.footnote)
  let groups = Set(store.data.series.map { $0.group.lowercased() })
  let missing = [("Aktien", "aktien"),("Immobilien", "immobilien")].filter { !groups.contains($0.1) }.map { $0.0 }
  if !missing.isEmpty { Text("\(missing.joined(separator: " und ")) sind im geladenen Datensatz nicht enthalten. Zusätzliche lizenzierte Reihen können als JSON importiert werden.").font(.caption).foregroundStyle(.secondary) }
  QuotesView()
  Panel(title: "Daten und zeitliche Orientierung") {
   Text("CPI-Beobachtungen: \(store.data.cpi.first?.year ?? 0)–\(store.data.cpi.last?.year ?? 0) · \(store.data.cpiRegion). Jahresmodelle sind eine zusätzliche Perspektive, keine Kursprognose.")
   NavigationLink("Zyklen entdecken") { CycleView() }
  }
  Panel(title: "Gold-Silber-Ratio") { if let r = CrisisEngine.ratio(store.data) { Text("\(number(r.value)) : 1 · \(r.year)").font(.title) } else { Text("Nicht verfügbar") }; Text(store.data.kind == "demo" ? "Rechenbeispiel, kein Marktwert." : "Nur bei gleicher Währung und Einheit.").font(.footnote) }
  Text("Die Welt als Wirkungsfeld.").font(.title2)
  ForEach(store.content.fields) { f in Panel(title: f.title) { Text(f.text) } }
  Panel(title: "Makrolage") { Text("Inflation % p.a.; Rüstung und BIP in Mrd. USD. Stand \(store.data.asOf)").font(.caption); ForEach(store.data.macro) { m in VStack(alignment: .leading) { Text(m.country).bold(); Text("Inflation: \(m.inflation.map(number) ?? "Nicht verfügbar")\nRüstung: \(m.military.map(number) ?? "Nicht verfügbar") · BIP: \(m.gdp.map(number) ?? "Nicht verfügbar")").font(.footnote) } } }
 } }
}
struct CSVDocument: FileDocument {
 static var readableContentTypes: [UTType] { [.commaSeparatedText, .json] }
 var text: String
 init(text: String) { self.text = text }
 init(configuration: ReadConfiguration) throws { text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? "" }
 func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}
struct ComparisonView: View {
 @EnvironmentObject var store: CrisisStore
 @State private var selected: Set<String> = []
 @State private var from = "1926"
 @State private var to = "2026"
 @State private var real = false
 @State private var exporting = false
 @State private var exportText = ""
 var result: Result<[Series], Error> { Result { guard let f = Int(from), let t = Int(to) else { throw CrisisError(message: "Gültige Jahre eingeben.") }; return try CrisisEngine.compare(store.data, ids: selected, from: f, to: t, real: real) } }
 var body: some View { Screen(title: "Vergleich") {
  Text("Werte im Verhältnis.").font(.largeTitle); DataNotice(d: store.data); QuotesView()
  Panel(title: "Asset-Auswahl") {
   ForEach(store.data.series) { s in Toggle(s.name, isOn: Binding(get: { selected.contains(s.id) }, set: { if $0 { selected.insert(s.id) } else { selected.remove(s.id) } })).accessibilityIdentifier("asset-" + s.id) }
   HStack { TextField("Von", text: $from).keyboardType(.numberPad).accessibilityLabel("Von Jahr").accessibilityIdentifier("comparison-from"); TextField("Bis", text: $to).keyboardType(.numberPad).accessibilityLabel("Bis Jahr").accessibilityIdentifier("comparison-to") }.textFieldStyle(.roundedBorder)
   Toggle("Inflationsbereinigt", isOn: $real).accessibilityIdentifier("comparison-real")
   Text("CPI: \(store.data.cpiRegion). Gemeinsamer Start = 100. Ohne Wechselkurse, Dividenden, Mieten, Kosten und Steuern.").font(.caption)
  }
  switch result {
   case .success(let ss): Panel(title: "Langfristig denken.") {
    Text("\(ss[0].points.first!.year)–\(ss[0].points.last!.year) · \(real ? "Real" : "Nominal") · Basis 100").font(.caption)
    Chart(ss) { s in ForEach(s.points) { p in LineMark(x: .value("Jahr", p.year), y: .value("Index", p.value)).foregroundStyle(by: .value("Asset", s.name)) } }.chartForegroundStyleScale(range: plotColors).chartXAxis { AxisMarks { value in AxisGridLine(); AxisValueLabel { if let year = value.as(Int.self) { Text(String(year)) } } } }.frame(height: 250).accessibilityLabel("Indexverlauf. Start- und Endwerte folgen als Text.")
    ForEach(ss) { s in Text("\(s.name): 100 → \(number(s.points.last!.value)) (\(number(s.points.last!.value - 100)) %) · \(s.unit)").font(.footnote) }
    Button("CSV exportieren") { exportText = CrisisEngine.csv(ss); exporting = true }.buttonStyle(.borderedProminent).accessibilityIdentifier("comparison-export")
   }
   case .failure(let e): Note(text: e.localizedDescription).accessibilityIdentifier("comparison-error")
  }
 }.onAppear { if selected.isEmpty { selected = Set(store.data.series.prefix(2).map(\.id)) } }
 .onChange(of: store.revision) { _ in selected = Set(store.data.series.prefix(2).map(\.id)) }
 .fileExporter(isPresented: $exporting, document: CSVDocument(text: exportText), contentType: .commaSeparatedText, defaultFilename: "crisis-vergleich") { if case .failure(let e) = $0 { store.message = e.localizedDescription } }
 }
}
struct CycleView: View {
 @EnvironmentObject var store: CrisisStore
 @State private var year = "2026"
 var body: some View { Screen(title: "Zyklen") {
  Text("Zeit macht Muster sichtbar.").font(.largeTitle)
  Note(text: "Das PDF zeigt ×; die Jahresfolgen entstehen durch Addition der Intervalle. Keine nachgewiesene Prognosegüte. Ab 2027 reine Modellfortschreibung.")
  TextField("Jahr 1926–2126", text: $year).keyboardType(.numberPad).textFieldStyle(.roundedBorder).accessibilityIdentifier("cycle-year")
  if let y = Int(year), (1926...2126).contains(y) {
   let matches = store.content.cycles.filter { CrisisEngine.years($0).contains(y) }
   Note(text: matches.isEmpty ? "\(y): kein Modelltreffer. Keine Aussage über tatsächliches Risiko." : "\(y): \(matches.map(\.name).joined(separator: " · ")) (Modell)").accessibilityIdentifier("cycle-result")
  } else { Note(text: "Bitte Jahr 1926–2126 eingeben.") }
  ForEach(store.content.cycles) { c in Panel(title: c.name) { Text("Start \(c.start) · +\(c.steps.map(String.init).joined(separator: " / +")) Jahre").font(.caption); LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))]) { ForEach(CrisisEngine.years(c), id: \.self) { y in Text("\(y)\(y > 2026 ? "*" : "")").font(.caption).padding(8).frame(maxWidth: .infinity).background(Int(year) == y ? rose : teal.opacity(0.35), in: RoundedRectangle(cornerRadius: 6)) } }; Text("* Szenario").font(.caption) } }
 } }
}
struct LibraryView: View {
 @EnvironmentObject var store: CrisisStore
 @State private var search = ""
 var docs: [CrisisDocument] { store.content.documents.filter { search.isEmpty || ($0.title + $0.pages.joined()).localizedCaseInsensitiveContains(search) } }
 var body: some View { Screen(title: "Wissen") {
  Text("Struktur vor Schlagzeile.").font(.largeTitle)
  TextField("Unterlagen durchsuchen", text: $search).textFieldStyle(.roundedBorder).accessibilityIdentifier("library-search")
  Note(text: "Die Dossiers vertreten die Sicht der Herausgeber. Aussagen sind nicht unabhängig verifiziert. Vollständige Lesefassungen einschließlich interner Nutzungshinweise.")
  if docs.isEmpty { Text("Keine passenden Dokumente gefunden.").accessibilityIdentifier("library-empty") }
  ForEach(docs) { d in Panel(title: d.title) { Text("\(d.pages.count) Seiten").font(.caption); NavigationLink("Vollständige Lesefassung") { DocumentView(document: d) } } }
  Panel(title: "Datenquellen") { Text("Webseiten sind keine API-Verträge. Live-Daten erfordern lizenzierte Anbieter und sichere Serveradapter. LSEG.L ist eine Einzelaktie.").font(.footnote); ForEach(store.content.sources) { s in if let url = URL(string: s.url) { Link("\(s.provider) · \(s.label) ↗", destination: url).font(.footnote) } } }
 } }
}
struct DocumentView: View {
 let document: CrisisDocument
 var body: some View { ScrollView { LazyVStack(alignment: .leading, spacing: 24) { ForEach(Array(document.pages.enumerated()), id: \.offset) { i, p in VStack(alignment: .leading, spacing: 12) { Text("Seite \(i + 1)").font(.headline); Text(p).textSelection(.enabled) } } }.padding() }.navigationTitle(document.title) }
}
struct SettingsView: View {
 @EnvironmentObject var store: CrisisStore
 @State private var importing = false
 @State private var exporting = false
 @AppStorage("market-adapter-url") private var adapter = ""
 var body: some View { Screen(title: "Einstellungen") {
  Text("Ihre Perspektive. Ihre Daten.").font(.largeTitle)
  Panel(title: "Planung") {
   NavigationLink("Kaufkraft prüfen") { PurchasingPowerView() }.accessibilityIdentifier("more-purchasing-power")
   NavigationLink("Strukturcheck") { StructureCheckView() }.accessibilityIdentifier("more-structure")
  }
  Panel(title: "White-Label Branding") {
   TextField("Berater / Partnername", text: $store.partner).textFieldStyle(.roundedBorder).accessibilityIdentifier("partner-name").onChange(of: store.partner) { s in if s.count > 60 { store.partner = String(s.prefix(60)) } }
   Picker("Akzentfarbe", selection: $store.theme) { Text("Midnight Blue").tag("navy"); Text("Teal Mist").tag("teal"); Text("Rusty Rose").tag("rose") }
   Text("Automatisch lokal gespeichert. Originalpalette: #0f1c3d · #e8b9c8 · #c7e8e3. Dunkle Akzentvarianten für lesbare Bedienelemente.").font(.caption)
  }
  Panel(title: "Daten importieren") {
   Text("JSON-Schema v1 · maximal 2 MB. Daten bleiben lokal auf diesem Gerät. Keine Zugangsdaten importieren.").font(.footnote)
   Button("JSON-Datei auswählen") { importing = true }.buttonStyle(.borderedProminent)
   Button("Echte historische Daten laden") { store.historical() }.buttonStyle(.bordered).accessibilityIdentifier("historical-load")
   Button("Beispieldatei speichern") { exporting = true }.buttonStyle(.bordered)
   Button("Beispieldaten wiederherstellen", role: .destructive) { store.reset() }
  }
  Panel(title: "Daten aktualisieren") {
   Text("Optional: HTTPS-Adresse des eigenen Datenadapters. Es werden erst nach Antippen Daten angefragt. Stand und Quelle bestimmen, ob Kurse aktuell oder verzögert sind.").font(.footnote)
   TextField("https://ihr-server.example/api/data", text: $adapter).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).textFieldStyle(.roundedBorder).accessibilityIdentifier("adapter-url")
   Button(store.refreshing ? "Aktualisierung läuft …" : "Jetzt aktualisieren") { Task { await store.refresh(adapter) } }.disabled(store.refreshing).buttonStyle(.borderedProminent).accessibilityIdentifier("market-refresh")
   Text("Keine API-Schlüssel oder Passwörter in die Adresse eintragen. Anbieterzugänge werden auf dem Server verwaltet.").font(.caption)
  }
  Panel(title: "Rechtliches") { NavigationLink("Impressum & Datenschutz") { LegalView() } }
 }.fileImporter(isPresented: $importing, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in switch result { case .success(let urls): if let url = urls.first { store.load(url) }; case .failure(let e): store.message = e.localizedDescription } }
 .fileExporter(isPresented: $exporting, document: CSVDocument(text: String(data: store.demoBytes, encoding: .utf8) ?? ""), contentType: .json, defaultFilename: "crisis-beispieldaten") { if case .failure(let e) = $0 { store.message = e.localizedDescription } }
 }
}
struct LegalView: View {
 var body: some View { ScrollView { VStack(alignment: .leading, spacing: 20) {
  Text("Impressum").font(.title)
  Text("ALL I AM Akademie\nEin Bereich des Herzenskraft e.V.\nKreuzkirchstrasse 17, 77652 Offenburg\nVertreten durch Alexander Avsar, Präsident\ninfo@aia.berlin · www.aia.berlin/crisis")
  Text("Angaben aus dem Brandguide. Register- und weitere Pflichtangaben sind vor Veröffentlichung zu bestätigen.")
  Text("Datenschutz").font(.title)
  Text("Keine Cookies, kein Tracking, kein Konto. Importierte Daten und Branding bleiben lokal auf diesem Gerät. Bei ausdrücklich gewählter Aktualisierung ruft die App Markt-JSON vom konfigurierten HTTPS-Adapter ab; dabei erhält der Server technische Verbindungsdaten wie die IP-Adresse. Importierte Dateien und Branding werden dabei nicht hochgeladen. Exporte und externe Links öffnen Sie bewusst. Für externe Anbieter gelten deren eigene Datenschutzbedingungen. Importierte Daten können über die Wiederherstellung gelöscht werden; alle lokalen Daten durch Löschen der App. Diese Hinweise sind vor Veröffentlichung an den tatsächlichen Betrieb anzupassen.")
  Text("Der Strukturcheck kann persönliche Notizen, einen nächsten Schritt, eine verantwortliche Person und einen Prüftermin enthalten. Diese Angaben bleiben im lokalen Entwurf und werden erst mit „Lokal speichern“ in einer privaten, vom Betriebssystem-Backup ausgeschlossenen Datei gespeichert. Der Datenadapter erhält diese Angaben nie. Mit „Strukturcheck löschen“ entfernen Sie den lokalen Check und den aktuellen Entwurf. Exportierte TXT-Berichte können persönliche Angaben enthalten; deren Ablage und Weitergabe bestimmen Sie selbst.")
  Text("Die Dossiers vertreten die Sicht der Herausgeber. Zyklusmodelle haben keine nachgewiesene Prognosegüte und begründen keine Anlageempfehlung. Historische Wertentwicklung erlaubt keine verlässliche Aussage über künftige Ergebnisse.")
 }.padding() }.navigationTitle("Rechtliches") }
}
