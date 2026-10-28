package berlin.aia.crisis

import android.app.Application
import android.os.Bundle
import androidx.core.content.edit
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewmodel.compose.viewModel
import java.util.Locale

val Navy=Color(0xFF0F1C3D);val Rose=Color(0xFFE8B9C8);val Teal=Color(0xFFC7E8E3)
val PlotColors=listOf(Navy,Color(0xFF99613A),Color(0xFF267468),Color(0xFF933D61),Color(0xFF65569D),Color(0xFF9D561D),Color(0xFF276F9C),Color(0xFF746414),Color(0xFFAD3152),Color(0xFF354F39))
fun number(n: Double)=String.format(Locale.GERMANY,"%,.2f",n)
class CrisisModel(app: Application): AndroidViewModel(app) {
 private val prefs=app.getSharedPreferences("crisis",0)
 private val file=java.io.File(app.filesDir,"market.json")
 val content=CrisisEngine.content(app.assets.open("content.json").bufferedReader().use { it.readText() })
 val demoText=app.assets.open("demo-data.json").bufferedReader().use { it.readText() }
 var data by mutableStateOf(runCatching { CrisisEngine.parse(file.readText()) }.getOrElse { CrisisEngine.parse(demoText) }); private set
 var partner by mutableStateOf(prefs.getString("partner","") ?: "")
 var theme by mutableStateOf(prefs.getString("theme","navy") ?: "navy")
 var message by mutableStateOf("")
 fun brand() { prefs.edit { putString("partner",partner.take(60));putString("theme",theme) };message="Branding gespeichert." }
 fun load(text: String) { runCatching { val next=CrisisEngine.parse(text);val temp=java.io.File(file.parentFile,"market.tmp");temp.writeText(text);check(temp.renameTo(file));data=next }.onSuccess { message="Datensatz geprüft und importiert." }.onFailure { message="Import abgelehnt: ${it.message}" } }
 fun reset() { if(file.exists() && !file.delete()){message="Datei konnte nicht gelöscht werden.";return};data=CrisisEngine.parse(demoText);message="Beispieldaten wiederhergestellt." }
}
class MainActivity: ComponentActivity(){ override fun onCreate(savedInstanceState: Bundle?){super.onCreate(savedInstanceState);setContent { CrisisApp() }} }
@Composable fun CrisisApp(m: CrisisModel=viewModel()) {
 var tab by remember { mutableIntStateOf(0) };val context=LocalContext.current
 var exportText by remember { mutableStateOf("") }
 val export=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { uri -> if(uri!=null)runCatching { context.contentResolver.openOutputStream(uri)?.use { it.write(exportText.toByteArray()) } ?: error("Datei nicht verfügbar") }.onFailure { m.message="Export fehlgeschlagen: ${it.message}" } }
 val template=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri -> if(uri!=null)runCatching { context.contentResolver.openOutputStream(uri)?.use { it.write(m.demoText.toByteArray()) } ?: error("Datei nicht verfügbar") }.onFailure { m.message="Export fehlgeschlagen." } }
 val importer=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri -> if(uri!=null)runCatching { context.contentResolver.openInputStream(uri)?.use { val out=java.io.ByteArrayOutputStream();val buffer=ByteArray(8192);var n=it.read(buffer);while(n!=-1){require(out.size()+n<=2*1024*1024){"Maximal 2 MB erlaubt."};out.write(buffer,0,n);n=it.read(buffer)};out.toString("UTF-8") } ?: error("Datei nicht lesbar") }.onSuccess { m.load(it) }.onFailure { m.message="Import abgelehnt: ${it.message}" } }
 val accent=when(m.theme){"teal"->Color(0xFF286C60);"rose"->Color(0xFF873E59);else->Navy}
 MaterialTheme(colorScheme=lightColorScheme(primary=accent,secondary=Navy,background=Color(0xFFF7F8FA),surface=Color.White,onPrimary=Color.White,onSurface=Navy,onBackground=Navy)) {
  Scaffold(bottomBar={ NavigationBar { listOf("Übersicht","Vergleich","Zyklen","Wissen","Mehr").forEachIndexed { i,t -> NavigationBarItem(selected=tab==i,onClick={tab=i},icon={Text(listOf("⌂","↗","◷","≡","···")[i])},label={Text(t,fontSize=10.sp)}) } } }) { padding ->
   Column(Modifier.padding(padding).fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(16.dp)) {
    val logo=remember { android.graphics.BitmapFactory.decodeStream(context.assets.open("logo.png")).asImageBitmap() }
    Image(logo,"CRISIS – Wissen, das Werte schützt.",Modifier.width(155.dp).height(52.dp))
    if(m.partner.isNotBlank())Text("In Kooperation mit ${m.partner}",style=MaterialTheme.typography.labelSmall)
    if(m.message.isNotEmpty()){Note(m.message);TextButton(onClick={m.message=""}){Text("Schließen")}}
    when(tab){0->Home(m){tab=it};1->Comparison(m.data){exportText=it;export.launch("crisis-vergleich.csv")};2->Cycles(m.content);3->Library(m.content);4->Settings(m,{importer.launch(arrayOf("application/json","text/plain"))},{template.launch("crisis-beispieldaten.json")})}
    Text("©2026 CRISIS © · ALL I AM Akademie",style=MaterialTheme.typography.labelSmall)
    Text("Orientierung, keine Anlageberatung. Modelljahre sind keine belastbaren Prognosen.",style=MaterialTheme.typography.bodySmall)
   }
  }
 }
}
@Composable fun Heading(eyebrow:String,title:String){Text(eyebrow.uppercase(),style=MaterialTheme.typography.labelSmall);Text(title,style=MaterialTheme.typography.headlineLarge)}
@Composable fun Note(text:String){Surface(color=Teal,shape=MaterialTheme.shapes.small){Text(text,Modifier.padding(14.dp),style=MaterialTheme.typography.bodySmall)}}
@Composable fun Panel(title:String,body:@Composable ColumnScope.()->Unit){Card(colors=CardDefaults.cardColors(containerColor=Color.White),modifier=Modifier.fillMaxWidth()){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){Text(title,style=MaterialTheme.typography.titleLarge);body()}}}
@Composable fun DataNotice(d: MarketData){Note("${if(d.kind=="demo")"Beispielmodus · Synthetische Werte, keine historischen oder aktuellen Kurse" else "Importierte Daten · ${d.source}"}. Stand ${d.asOf}.")}
@Composable fun Home(m:CrisisModel,nav:(Int)->Unit){
 Heading("Makro-Intelligenz für Vermögensschutz","Erkennen, was 90% übersehen.")
 Text("Märkte verstehen. Muster hinterfragen. Werte schützen.")
 Button(onClick={nav(1)}){Text("Assets vergleichen ↗")};DataNotice(m.data)
 Panel("1926 — 2126"){Text("100 Jahre Rückblick und 100 Jahre reine Modellfortschreibung. Keine Kursprognose.");TextButton(onClick={nav(2)}){Text("Zyklen entdecken")}}
 Panel("Gold-Silber-Ratio"){val r=CrisisEngine.ratio(m.data);Text(r?.let { "${number(it.value)} : 1 · ${it.year}" } ?: "Nicht verfügbar",style=MaterialTheme.typography.headlineMedium);Text(if(m.data.kind=="demo")"Rechenbeispiel, kein Marktwert." else "Nur gleiche Währung und Einheit.")}
 Text("Die Welt als Wirkungsfeld.",style=MaterialTheme.typography.headlineSmall)
 m.content.fields.forEach { Panel(it.title){Text(it.text)} }
 Panel("Makrolage"){Text("Inflation % p.a.; Rüstung und BIP in Mrd. USD. Stand ${m.data.asOf}",style=MaterialTheme.typography.bodySmall);m.data.macro.forEach { Text("${it.country}\nInflation: ${it.inflation?.let(::number) ?: "Nicht verfügbar"}\nRüstung: ${it.military?.let(::number) ?: "Nicht verfügbar"} · BIP: ${it.gdp?.let(::number) ?: "Nicht verfügbar"}") }}
}
@Composable fun Comparison(data:MarketData,export:(String)->Unit){
 var selected by remember(data){mutableStateOf(data.series.take(2).map { it.id }.toSet())};var from by remember{mutableStateOf("1926")};var to by remember{mutableStateOf("2026")};var real by remember{mutableStateOf(false)}
 Heading("Vergleich","Werte im Verhältnis.");DataNotice(data)
 Panel("Asset-Auswahl"){data.series.forEach { s-> Row { Checkbox(s.id in selected,{checked->selected=if(checked) selected+s.id else selected-s.id});Text(s.name,Modifier.padding(top=12.dp)) } };Row(horizontalArrangement=Arrangement.spacedBy(12.dp)){OutlinedTextField(from,{from=it},label={Text("Von")},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Number),modifier=Modifier.weight(1f));OutlinedTextField(to,{to=it},label={Text("Bis")},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Number),modifier=Modifier.weight(1f))};Row {Checkbox(real,{real=it});Text("Inflationsbereinigt",Modifier.padding(top=12.dp))};Text("CPI: ${data.cpiRegion}. Gemeinsamer Start = 100. Ohne Wechselkurse, Dividenden, Mieten, Kosten und Steuern.",style=MaterialTheme.typography.bodySmall)}
 val result=runCatching { CrisisEngine.compare(data,selected,from.toInt(),to.toInt(),real) }
 result.onSuccess { ss -> Panel("Langfristig denken."){Text("${ss.first().points.first().year}–${ss.first().points.last().year} · ${if(real)"Real" else "Nominal"} · Basis 100");Plot(ss);ss.forEachIndexed { i,s->Text("${s.name}: 100 → ${number(s.points.last().value)} (${number(s.points.last().value-100)} %) · ${s.unit}",color=PlotColors[i%PlotColors.size]) };Button(onClick={export(CrisisEngine.csv(ss))}){Text("CSV exportieren")}} }.onFailure { Note(it.message ?: "Ungültiger Vergleich.") }
}
@Composable fun Plot(ss:List<Series>){Canvas(Modifier.fillMaxWidth().height(230.dp).semantics{contentDescription="Indexverlauf. Start- und Endwerte stehen unter dem Diagramm."}){
 val values=ss.flatMap{it.points.map{p->p.value}};val lo=values.min()*.9;val hi=values.max()*1.1;val first=ss.first().points.first().year;val last=ss.first().points.last().year
 for(i in 0..4){val y=size.height*i/4;drawLine(Color(0xFFDCE1E8),androidx.compose.ui.geometry.Offset(0f,y),androidx.compose.ui.geometry.Offset(size.width,y))}
 ss.forEachIndexed { i,s->val p=Path();s.points.forEachIndexed { j,v->val x=((v.year-first).toFloat()/(last-first))*size.width;val y=(size.height-(v.value-lo)/(hi-lo)*size.height).toFloat();if(j==0)p.moveTo(x,y)else p.lineTo(x,y) };drawPath(p,PlotColors[i%PlotColors.size],style=androidx.compose.ui.graphics.drawscope.Stroke(3f)) }
}}
@Composable fun Cycles(c:Content){var focus by remember{mutableStateOf("2026")};Heading("Zyklen","Zeit macht Muster sichtbar.");Note("Das PDF zeigt ×; die Jahresfolgen entstehen durch Addition der Intervalle. Keine nachgewiesene Prognosegüte. Ab 2027 reine Modellfortschreibung.");OutlinedTextField(focus,{focus=it},label={Text("Jahr 1926–2126")},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Number));val year=focus.toIntOrNull();if(year==null||year !in 1926..2126)Note("Bitte Jahr 1926–2126 eingeben.")else {val matches=c.cycles.filter{year in CrisisEngine.years(it)};Note(if(matches.isEmpty())"$year: kein Modelltreffer. Keine Aussage über tatsächliches Risiko." else "$year: ${matches.joinToString{it.name}} (Modell)")};c.cycles.forEach { cy->Panel(cy.name){Text("Start ${cy.start} · +${cy.steps.joinToString(" / +")} Jahre");Text(CrisisEngine.years(cy).joinToString(" · "){if(it>2026)"$it*" else "$it"});Text("* Szenario",style=MaterialTheme.typography.labelSmall)}}}
@Composable fun Library(c:Content){var search by remember{mutableStateOf("")};var opened by remember{mutableStateOf<String?>(null)};val uri=LocalUriHandler.current;Heading("Wissen","Struktur vor Schlagzeile.");OutlinedTextField(search,{search=it},label={Text("Unterlagen durchsuchen")},modifier=Modifier.fillMaxWidth());Note("Die Dossiers vertreten die Sicht der Herausgeber. Ihre Aussagen sind nicht unabhängig verifiziert. Originaltexte einschließlich interner Nutzungshinweise.");val ds=c.documents.filter{(it.title+it.pages.joinToString()).contains(search,true)};if(ds.isEmpty())Text("Keine passenden Dokumente gefunden.");ds.forEach { d->Panel(d.title){Text("${d.pages.size} Seiten · Vollständige Lesefassung");TextButton(onClick={opened=if(opened==d.title)null else d.title}){Text(if(opened==d.title)"Schließen" else "Lesen")};if(opened==d.title)d.pages.forEachIndexed { i,p->Text("Seite ${i+1}",style=MaterialTheme.typography.titleMedium);Text(p,style=MaterialTheme.typography.bodyMedium)}}};Panel("Datenquellen"){Text("Webseiten sind keine API-Verträge. Live-Daten erfordern lizenzierte Anbieter und sichere Serveradapter. LSEG.L ist eine Einzelaktie.");c.sources.forEach {s->TextButton(onClick={uri.openUri(s.url)}){Text("${s.provider} · ${s.label} ↗")}}}}
@Composable fun Settings(m:CrisisModel,onImport:()->Unit,onTemplate:()->Unit){var legal by remember{mutableStateOf(false)};Heading("Einstellungen","Ihre Perspektive. Ihre Daten.");Panel("White-Label Branding"){OutlinedTextField(m.partner,{m.partner=it.take(60)},label={Text("Berater / Partnername")});listOf("navy" to "Midnight Blue","teal" to "Teal Mist","rose" to "Rusty Rose").forEach{(id,name)->Row{RadioButton(m.theme==id,{m.theme=id});Text(name,Modifier.padding(top=12.dp))}};Button(onClick={m.brand()}){Text("Branding speichern")};Text("Originalpalette: #0f1c3d · #e8b9c8 · #c7e8e3. Dunkle Akzentvarianten für lesbare Bedienelemente.",style=MaterialTheme.typography.bodySmall)};Panel("Daten importieren"){Text("JSON-Schema v1 · maximal 2 MB. Daten bleiben lokal auf diesem Gerät. Keine Zugangsdaten importieren.");Button(onClick=onImport){Text("JSON-Datei auswählen")};OutlinedButton(onClick=onTemplate){Text("Beispieldatei speichern")};OutlinedButton(onClick={m.reset()}){Text("Beispieldaten wiederherstellen")}};Panel("Rechtliches"){TextButton(onClick={legal=!legal}){Text("Impressum & Datenschutz")};if(legal){Text("ALL I AM Akademie, ein Bereich des Herzenskraft e.V.\nKreuzkirchstrasse 17, 77652 Offenburg\nAlexander Avsar, Präsident\ninfo@aia.berlin · www.aia.berlin/crisis\nAngaben aus dem Brandguide. Register- und weitere Pflichtangaben sind vor Veröffentlichung zu bestätigen.");Text("Keine Cookies, kein Tracking, kein Konto. Importierte Daten und Branding werden nur lokal gespeichert, nicht an CRISIS übertragen. Exporte und externe Links werden bewusst geöffnet. Importierte Daten lassen sich über die Wiederherstellung löschen; sämtliche lokalen Daten über die Android-App-Einstellungen. Externe Anbieter haben eigene Datenschutzbestimmungen. Diese Hinweise sind vor Veröffentlichung an den tatsächlichen Betrieb anzupassen.")}}}
