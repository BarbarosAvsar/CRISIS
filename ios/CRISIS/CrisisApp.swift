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
 @Published var partner: String { didSet { UserDefaults.standard.set(String(partner.prefix(60)), forKey: "partner") } }
 @Published var theme: String { didSet { UserDefaults.standard.set(theme, forKey: "theme") } }
 @Published var revision = 0
 @Published var message = ""
 private let file: URL
 init() throws {
  guard let c = Bundle.main.url(forResource: "content", withExtension: "json"), let d = Bundle.main.url(forResource: "demo-data", withExtension: "json") else { throw CrisisError(message: "Gebündelte Daten fehlen.") }
  content = try JSONDecoder().decode(Content.self, from: Data(contentsOf: c)); demoBytes = try Data(contentsOf: d)
  let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  file = folder.appendingPathComponent("market.json")
  if let bytes = try? Data(contentsOf: file), let saved = try? CrisisEngine.parse(bytes) { data = saved } else { data = try CrisisEngine.parse(demoBytes) }
  partner = UserDefaults.standard.string(forKey: "partner") ?? ""; theme = UserDefaults.standard.string(forKey: "theme") ?? "navy"
 }
 var accent: Color { theme == "teal" ? Color(red: 40/255, green: 108/255, blue: 96/255) : theme == "rose" ? Color(red: 135/255, green: 62/255, blue: 89/255) : navy }
 func load(_ url: URL) {
  let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
  do {
   let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
   let bytes = try handle.read(upToCount: 2 * 1024 * 1024 + 1) ?? Data()
   let next = try CrisisEngine.parse(bytes); try bytes.write(to: file, options: .atomic); data = next; revision += 1; message = "Datensatz geprüft und importiert."
  } catch { message = "Import abgelehnt: \(error.localizedDescription)" }
 }
 func reset() { do { if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }; data = try CrisisEngine.parse(demoBytes); revision += 1; message = "Beispieldaten wiederhergestellt." } catch { message = error.localizedDescription } }
}

@main @MainActor struct CrisisApp: App {
 private let result: Result<CrisisStore, Error>
 init() { result = Result { try CrisisStore() } }
 var body: some Scene { WindowGroup { switch result { case .success(let store): RootView(store: store); case .failure(let error): VStack { Text("CRISIS konnte nicht starten.").font(.title); Text(error.localizedDescription) }.padding() } } }
}
struct RootView: View {
 @ObservedObject var store: CrisisStore
 var body: some View {
  TabView {
   NavigationStack { HomeView().environmentObject(store) }.tabItem { Label("Übersicht", systemImage: "house") }
   NavigationStack { ComparisonView().environmentObject(store) }.tabItem { Label("Vergleich", systemImage: "chart.xyaxis.line") }
   NavigationStack { CycleView().environmentObject(store) }.tabItem { Label("Zyklen", systemImage: "clock") }
   NavigationStack { LibraryView().environmentObject(store) }.tabItem { Label("Wissen", systemImage: "books.vertical") }
   NavigationStack { SettingsView().environmentObject(store) }.tabItem { Label("Mehr", systemImage: "slider.horizontal.3") }
  }.tint(store.accent).preferredColorScheme(.light)
   .alert("CRISIS", isPresented: Binding(get: { !store.message.isEmpty }, set: { if !$0 { store.message = "" } })) { Button("OK") { store.message = "" } } message: { Text(store.message) }
 }
}
struct BrandHeader: View {
 @EnvironmentObject var store: CrisisStore
 var body: some View { VStack(alignment: .leading, spacing: 8) { if let url = Bundle.main.url(forResource: "logo", withExtension: "png"), let image = UIImage(contentsOfFile: url.path) { Image(uiImage: image).resizable().scaledToFit().frame(width: 155, height: 52).accessibilityLabel("CRISIS – Wissen, das Werte schützt.") } else { Text("CRISIS ©").font(.title.bold()) }; if !store.partner.isEmpty { Text("In Kooperation mit \(store.partner)").font(.caption) } } }
}
struct Screen<Body: View>: View {
 let title: String; @ViewBuilder let content: () -> Body
 var body: some View { ScrollView { VStack(alignment: .leading, spacing: 20) { BrandHeader(); content(); Text("©2026 CRISIS © · ALL I AM Akademie").font(.caption); Text("Orientierung, keine Anlageberatung. Modelljahre sind keine belastbaren Prognosen.").font(.caption).foregroundStyle(.secondary) }.padding() }.background(Color(red: 247/255, green: 248/255, blue: 250/255)).foregroundStyle(navy).navigationTitle(title).navigationBarTitleDisplayMode(.inline) }
}
struct Panel<Body: View>: View {
 let title: String; @ViewBuilder let content: () -> Body
 var body: some View { VStack(alignment: .leading, spacing: 14) { Text(title).font(.title2); content() }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(.white, in: RoundedRectangle(cornerRadius: 14)) }
}
struct Note: View { let text: String; var body: some View { Text(text).font(.footnote).frame(maxWidth: .infinity, alignment: .leading).padding(14).background(teal, in: RoundedRectangle(cornerRadius: 8)) } }
struct DataNotice: View { let d: MarketData; var body: some View { Note(text: "\(d.kind == "demo" ? "Beispielmodus · Synthetische Werte, keine historischen oder aktuellen Kurse" : "Importierte Daten · " + d.source). Stand \(d.asOf).") } }
struct HomeView: View {
 @EnvironmentObject var store: CrisisStore
 var body: some View { Screen(title: "Übersicht") {
  Text("MAKRO-INTELLIGENZ FÜR VERMÖGENSSCHUTZ").font(.caption)
  Text("Erkennen, was 90% übersehen.").font(.largeTitle)
  Text("Märkte verstehen. Muster hinterfragen. Werte schützen.")
  DataNotice(d: store.data)
  Panel(title: "1926 — 2126") { Text("100 Jahre Rückblick und 100 Jahre reine Modellfortschreibung. Keine Kursprognose."); NavigationLink("Zyklen entdecken") { CycleView() } }
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
 @State private var from = "1926", to = "2026", real = false, exporting = false
 @State private var exportText = ""
 var result: Result<[Series], Error> { Result { guard let f = Int(from), let t = Int(to) else { throw CrisisError(message: "Gültige Jahre eingeben.") }; return try CrisisEngine.compare(store.data, ids: selected, from: f, to: t, real: real) } }
 var body: some View { Screen(title: "Vergleich") {
  Text("Werte im Verhältnis.").font(.largeTitle); DataNotice(d: store.data)
  Panel(title: "Asset-Auswahl") {
   ForEach(store.data.series) { s in Toggle(s.name, isOn: Binding(get: { selected.contains(s.id) }, set: { if $0 { selected.insert(s.id) } else { selected.remove(s.id) } })) }
   HStack { TextField("Von", text: $from).keyboardType(.numberPad).accessibilityLabel("Von Jahr"); TextField("Bis", text: $to).keyboardType(.numberPad).accessibilityLabel("Bis Jahr") }.textFieldStyle(.roundedBorder)
   Toggle("Inflationsbereinigt", isOn: $real)
   Text("CPI: \(store.data.cpiRegion). Gemeinsamer Start = 100. Ohne Wechselkurse, Dividenden, Mieten, Kosten und Steuern.").font(.caption)
  }
  switch result {
   case .success(let ss): Panel(title: "Langfristig denken.") {
    Text("\(ss[0].points.first!.year)–\(ss[0].points.last!.year) · \(real ? "Real" : "Nominal") · Basis 100").font(.caption)
    Chart(ss) { s in ForEach(s.points) { p in LineMark(x: .value("Jahr", p.year), y: .value("Index", p.value)).foregroundStyle(by: .value("Asset", s.name)) } }.chartForegroundStyleScale(range: plotColors).chartXAxis { AxisMarks { value in AxisGridLine(); AxisValueLabel { if let year = value.as(Int.self) { Text(String(year)) } } } }.frame(height: 250).accessibilityLabel("Indexverlauf. Start- und Endwerte folgen als Text.")
    ForEach(ss) { s in Text("\(s.name): 100 → \(number(s.points.last!.value)) (\(number(s.points.last!.value - 100)) %) · \(s.unit)").font(.footnote) }
    Button("CSV exportieren") { exportText = CrisisEngine.csv(ss); exporting = true }.buttonStyle(.borderedProminent)
   }
   case .failure(let e): Note(text: e.localizedDescription)
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
  TextField("Jahr 1926–2126", text: $year).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
  if let y = Int(year), (1926...2126).contains(y) {
   let matches = store.content.cycles.filter { CrisisEngine.years($0).contains(y) }
   Note(text: matches.isEmpty ? "\(y): kein Modelltreffer. Keine Aussage über tatsächliches Risiko." : "\(y): \(matches.map(\.name).joined(separator: " · ")) (Modell)")
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
  TextField("Unterlagen durchsuchen", text: $search).textFieldStyle(.roundedBorder)
  Note(text: "Die Dossiers vertreten die Sicht der Herausgeber. Aussagen sind nicht unabhängig verifiziert. Vollständige Lesefassungen einschließlich interner Nutzungshinweise.")
  if docs.isEmpty { Text("Keine passenden Dokumente gefunden.") }
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
 @State private var importing = false, exporting = false
 var body: some View { Screen(title: "Einstellungen") {
  Text("Ihre Perspektive. Ihre Daten.").font(.largeTitle)
  Panel(title: "White-Label Branding") {
   TextField("Berater / Partnername", text: $store.partner).textFieldStyle(.roundedBorder).onChange(of: store.partner) { s in if s.count > 60 { store.partner = String(s.prefix(60)) } }
   Picker("Akzentfarbe", selection: $store.theme) { Text("Midnight Blue").tag("navy"); Text("Teal Mist").tag("teal"); Text("Rusty Rose").tag("rose") }
   Text("Automatisch lokal gespeichert. Originalpalette: #0f1c3d · #e8b9c8 · #c7e8e3. Dunkle Akzentvarianten für lesbare Bedienelemente.").font(.caption)
  }
  Panel(title: "Daten importieren") {
   Text("JSON-Schema v1 · maximal 2 MB. Daten bleiben lokal auf diesem Gerät. Keine Zugangsdaten importieren.").font(.footnote)
   Button("JSON-Datei auswählen") { importing = true }.buttonStyle(.borderedProminent)
   Button("Beispieldatei speichern") { exporting = true }.buttonStyle(.bordered)
   Button("Beispieldaten wiederherstellen", role: .destructive) { store.reset() }
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
  Text("Keine Cookies, kein Tracking, kein Konto. Importierte Daten und Branding bleiben lokal auf diesem Gerät. Es werden keine Daten an CRISIS übertragen. Exporte und externe Links öffnen Sie bewusst. Für externe Anbieter gelten deren eigene Datenschutzbedingungen. Importierte Daten können über die Wiederherstellung gelöscht werden; alle lokalen Daten durch Löschen der App. Diese Hinweise sind vor Veröffentlichung an den tatsächlichen Betrieb anzupassen.")
  Text("Die Dossiers vertreten die Sicht der Herausgeber. Zyklusmodelle haben keine nachgewiesene Prognosegüte und begründen keine Anlageempfehlung. Historische Wertentwicklung erlaubt keine verlässliche Aussage über künftige Ergebnisse.")
 }.padding() }.navigationTitle("Rechtliches") }
}
