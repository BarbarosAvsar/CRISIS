package berlin.aia.crisis

import android.app.Application
import android.os.Bundle
import android.net.Uri
import android.util.AtomicFile
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
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Locale

val Navy=Color(0xFF0F1C3D);val Rose=Color(0xFFE8B9C8);val Teal=Color(0xFFC7E8E3)
val PlotColors=listOf(Navy,Color(0xFF99613A),Color(0xFF267468),Color(0xFF933D61),Color(0xFF65569D),Color(0xFF9D561D),Color(0xFF276F9C),Color(0xFF746414),Color(0xFFAD3152),Color(0xFF354F39))
fun number(n: Double)=String.format(Locale.GERMANY,"%,.2f",n)
class CrisisModel(app: Application): AndroidViewModel(app) {
 private val prefs=app.getSharedPreferences("crisis",0)
 private val file=java.io.File(app.filesDir,"market.json")
 val content=CrisisEngine.content(app.assets.open("content.json").bufferedReader().use { it.readText() })
 val demoText=app.assets.open("demo-data.json").bufferedReader().use { it.readText() }
 private val defaultText=if(prefs.getString("dataset",null)=="demo")demoText else runCatching {app.assets.open("market-data.json").bufferedReader().use {it.readText()}}.getOrDefault(demoText)
 private val savedText=runCatching {readBounded(AtomicFile(file).openRead())}.getOrNull()
 private val restored=savedText?.let {runCatching {LiveDataClient.parseStored(it)}.getOrNull()}
 var data by mutableStateOf(restored?.data ?: CrisisEngine.parse(defaultText)); private set
 var partner by mutableStateOf(prefs.getString("partner","") ?: "")
 var theme by mutableStateOf(prefs.getString("theme","navy") ?: "navy")
 var message by mutableStateOf(if(savedText!=null && restored==null)"Gespeicherte Daten sind beschädigt. Historischer Basisbestand wurde geladen." else "")
 var busy by mutableStateOf(false); private set
 var pendingExport = ""
 var endpoint by mutableStateOf(prefs.getString("endpoint","") ?: "")
 var liveProvenance by mutableStateOf(restored?.provenance); private set
 val planningGuide=PlanningEngine.guide(app.assets.open("planning.json").bufferedReader().use {it.readText()})
 private val planFile=AtomicFile(java.io.File(app.filesDir,"structure-plan.json"))
 private val restoredPlan=runCatching {planFile.openRead().use {stream->val bytes=stream.readBytesLimited(32*1024);PlanningEngine.parse(bytes.toString(Charsets.UTF_8))}}
 var plan by mutableStateOf(restoredPlan.getOrNull() ?: PlanningEngine.emptyPlan()); private set
 var planWarning by mutableStateOf(if(restoredPlan.isFailure && java.io.File(app.filesDir,"structure-plan.json").exists())"Der gespeicherte Strukturcheck ist beschädigt. Er bleibt bis zum ausdrücklichen Speichern oder Löschen erhalten." else ""); private set
 var planBusy by mutableStateOf(false); private set
 private fun java.io.InputStream.readBytesLimited(limit: Int): ByteArray {
  val out=java.io.ByteArrayOutputStream();val buffer=ByteArray(4096);var n=read(buffer)
  while(n!=-1){require(out.size()+n<=limit){"Datei zu groß."};out.write(buffer,0,n);n=read(buffer)}
  return out.toByteArray()
 }
 fun answer(id: String,status: String?=null,note: String?=null){val before=plan.answers.getValue(id);plan=plan.copy(answers=plan.answers+(id to before.copy(status=status ?: before.status,note=note?.take(500) ?: before.note)))}
 fun planDetails(action: String=plan.action,owner: String=plan.owner,reviewDate: String=plan.reviewDate){plan=plan.copy(action=action.take(1000),owner=owner.take(80),reviewDate=reviewDate.take(10))}
 fun savePlan(){
  if(planBusy)return
  val text=runCatching {PlanningEngine.json(plan)}.getOrElse {message=it.message ?: "Strukturcheck ungültig.";return}
  planBusy=true
  viewModelScope.launch {try {withContext(Dispatchers.IO){val output=planFile.startWrite();try {output.write(text.toByteArray(Charsets.UTF_8));planFile.finishWrite(output)}catch(error:Exception){planFile.failWrite(output);throw error}};planWarning="";message="Strukturcheck lokal gespeichert."}catch(error:Exception){message="Speichern fehlgeschlagen: ${error.message}"}finally{planBusy=false}}
 }
 fun deletePlan(){
  if(planBusy)return
  planBusy=true
  viewModelScope.launch {try {withContext(Dispatchers.IO){planFile.delete();require(!java.io.File(getApplication<Application>().filesDir,"structure-plan.json").exists())};plan=PlanningEngine.emptyPlan();planWarning="";message="Strukturcheck gelöscht."}catch(error:Exception){message="Löschen fehlgeschlagen: ${error.message}"}finally{planBusy=false}}
 }
 fun brand() { prefs.edit { putString("partner",partner.take(60));putString("theme",theme) };message="Branding gespeichert." }
 private fun readBounded(stream: java.io.InputStream): String = stream.use {
  val output=java.io.ByteArrayOutputStream();val buffer=ByteArray(8192);var count=it.read(buffer)
  while(count!=-1){require(output.size()+count<=2*1024*1024){"Maximal 2 MB erlaubt."};output.write(buffer,0,count);count=it.read(buffer)}
  output.toString("UTF-8")
 }
 fun load(text: String) = importData { text }
 fun historicalSnapshot() = importData { getApplication<Application>().assets.open("market-data.json").bufferedReader().use {it.readText()} }
 fun importFile(uri: Uri) = importData {
  readBounded(getApplication<Application>().contentResolver.openInputStream(uri) ?: error("Datei nicht lesbar."))
 }
 private fun persist(text: String): MarketData {
  val parsed=LiveDataClient.parseStored(text).data;val atomic=AtomicFile(file);val output=atomic.startWrite()
  try {output.write(text.toByteArray(Charsets.UTF_8));atomic.finishWrite(output)} catch(error:Exception){atomic.failWrite(output);throw error}
  return parsed
 }
 private fun importData(read: () -> String) {
  if(busy)return
  busy=true
  viewModelScope.launch {
   try {
    val next=withContext(Dispatchers.IO) {
     persist(read())
    }
    data=next;liveProvenance=null;prefs.edit {putString("dataset","import")};message="Datensatz geprüft und importiert."
   } catch(error:Exception){message="Import abgelehnt: ${error.message}"} finally {busy=false}
  }
 }
 fun refreshLive() {
  if(busy)return
  busy=true
  viewModelScope.launch {
   try {
    val selectedEndpoint=endpoint.trim()
    val reply=withContext(Dispatchers.IO) {val response=LiveDataClient.fetch(selectedEndpoint);persist(response.json);response}
    data=reply.data;liveProvenance=reply.provenance
    prefs.edit {putString("endpoint",selectedEndpoint);putString("dataset","import")}
    message="Datenserver erfolgreich abgerufen. Den Datenstand und die Quellen beachten."
   } catch(error:Exception){message="Aktualisierung fehlgeschlagen: ${error.message}"} finally {busy=false}
  }
 }
 fun exportFile(uri: Uri,text: String) {
  viewModelScope.launch {
   try {withContext(Dispatchers.IO) {getApplication<Application>().contentResolver.openOutputStream(uri)?.use {it.write(text.toByteArray(Charsets.UTF_8))} ?: error("Datei nicht verfügbar.")};message="Datei gespeichert."}
   catch(error:Exception){message="Export fehlgeschlagen: ${error.message}"}
  }
 }
 fun reset() {
  if(busy)return
  busy=true
  viewModelScope.launch {
   try {val next=withContext(Dispatchers.IO) {persist(demoText)};data=next;liveProvenance=null;prefs.edit {putString("dataset","demo")};message="Beispieldaten wiederhergestellt."}
   catch(error:Exception){message=error.message ?: "Wiederherstellung fehlgeschlagen."} finally {busy=false}
  }
 }
}
class MainActivity: ComponentActivity(){ override fun onCreate(savedInstanceState: Bundle?){super.onCreate(savedInstanceState);setContent { CrisisApp() }} }
@Composable fun CrisisApp(m: CrisisModel=viewModel()) {
 var tab by rememberSaveable { mutableIntStateOf(0) };val context=LocalContext.current
 var morePage by rememberSaveable {mutableStateOf("menu")}
 val pages=rememberSaveableStateHolder()
 val export=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { uri -> if(uri!=null)m.exportFile(uri,m.pendingExport) }
 val template=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri -> if(uri!=null)m.exportFile(uri,m.demoText) }
 val importer=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri -> if(uri!=null)m.importFile(uri) }
 val report=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/plain")) {uri->if(uri!=null)m.exportFile(uri,m.pendingExport)}
 val accent=when(m.theme){"teal"->Color(0xFF286C60);"rose"->Color(0xFF873E59);else->Navy}
 MaterialTheme(colorScheme=lightColorScheme(primary=accent,secondary=Navy,background=Color(0xFFF7F8FA),surface=Color.White,onPrimary=Color.White,onSurface=Navy,onBackground=Navy)) {
  Scaffold(bottomBar={ NavigationBar { listOf("Übersicht","Vergleich","Zyklen","Wissen","Mehr").forEachIndexed { i,t -> NavigationBarItem(selected=tab==i,onClick={tab=i;if(i==4)morePage="menu"},icon={Text(listOf("⌂","↗","◷","≡","···")[i],Modifier.clearAndSetSemantics {})},label={Text(t,fontSize=10.sp)}) } } }) { padding ->
   pages.SaveableStateProvider(if(tab==4)"more-$morePage" else "tab-$tab") {
   Column(Modifier.padding(padding).fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(16.dp)) {
    val logo=remember { context.assets.open("logo.png").use {android.graphics.BitmapFactory.decodeStream(it).asImageBitmap()} }
    Image(logo,"CRISIS – Wissen, das Werte schützt.",Modifier.width(155.dp).height(52.dp))
    if(m.partner.isNotBlank())Text("In Kooperation mit ${m.partner}",style=MaterialTheme.typography.labelSmall)
    if(m.message.isNotEmpty()){Note(m.message);TextButton(onClick={m.message=""}){Text("Schließen")}}
    if(m.busy)LinearProgressIndicator(Modifier.fillMaxWidth().semantics {contentDescription="Daten werden verarbeitet"})
    when(tab){
     0->Home(m,{tab=it},{tab=4;morePage="power"},{tab=4;morePage="structure"})
     1->Comparison(m.data){m.pendingExport=it;export.launch("crisis-vergleich.csv")}
     2->Cycles(m.content)
     3->Library(m.content)
     4->{
      if(morePage!="menu")TextButton(onClick={morePage="menu"}){Text("Zurück zu Mehr")}
      when(morePage){
       "power"->PurchasingPowerScreen(m.data)
       "structure"->StructureCheckScreen(m){runCatching {PlanningEngine.report(m.planningGuide,m.plan,m.partner)}.onSuccess {m.pendingExport=it;report.launch("crisis-strukturcheck.txt")}.onFailure {m.message=it.message ?: "Strukturcheck ungültig."}}
       "settings"->Settings(m,{importer.launch(arrayOf("application/json","text/plain"))},{template.launch("crisis-beispieldaten.json")})
       else->MoreMenu {morePage=it}
      }
     }
    }
    Text("©2026 CRISIS © · ALL I AM Akademie",style=MaterialTheme.typography.labelSmall)
    Text("Orientierung, keine Anlageberatung. Modelljahre sind keine belastbaren Prognosen.",style=MaterialTheme.typography.bodySmall)
   }
   }
  }
 }
}
@Composable fun Heading(eyebrow:String,title:String){Text(eyebrow.uppercase(),style=MaterialTheme.typography.labelSmall);Text(title,modifier=Modifier.semantics {heading()},style=MaterialTheme.typography.headlineLarge)}
@Composable fun Note(text:String){Surface(color=Teal,shape=MaterialTheme.shapes.small){Text(text,Modifier.padding(14.dp),style=MaterialTheme.typography.bodySmall)}}
@Composable fun Panel(title:String,body:@Composable ColumnScope.()->Unit){Card(colors=CardDefaults.cardColors(containerColor=Color.White),modifier=Modifier.fillMaxWidth()){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){Text(title,modifier=Modifier.semantics {heading()},style=MaterialTheme.typography.titleLarge);body()}}}
@Composable fun DataNotice(d: MarketData){Note("${if(d.kind=="demo")"Beispielmodus · Synthetische Werte, keine historischen oder aktuellen Kurse" else "Importierte Daten · ${d.source}"}. Stand ${d.asOf}.")}
@Composable fun LiveNotice(p:org.json.JSONObject?) {
 if(p==null)return
 Panel("Aktuelle Einzelkurse") {
  Text("Abruf: ${p.optString("fetchedAt","Unbekannt")} · ${if(p.optBoolean("stale",true))"Veraltet oder teilweise nicht verfügbar" else "Zeitstempel beachten"} · ${if(p.optBoolean("cached"))"Zwischenspeicher" else "Anbieterabruf"}",style=MaterialTheme.typography.bodySmall)
  val quotes=p.optJSONArray("quotes")
  if(quotes!=null)for(i in 0 until quotes.length()){
   val q=quotes.getJSONObject(i)
   Text("${q.optString("name")}: ${if(q.opt("price") is Number)number(q.getDouble("price"))+" "+q.optString("unit") else "Nicht verfügbar"}\nStand: ${q.optString("asOf","Unbekannt")} ${q.optString("error","")}",style=MaterialTheme.typography.bodySmall)
  }
  Text(p.optString("notes","Einzelkurse sind nicht Teil der Jahresreihen."),style=MaterialTheme.typography.bodySmall)
 }
}
@Composable fun Home(m:CrisisModel,nav:(Int)->Unit,onPower:()->Unit,onStructure:()->Unit){
 Heading("Makro-Intelligenz für Vermögensschutz","Vermögen verstehen. Handlungsfähig bleiben.")
 Text("Kaufkraft nachvollziehen, Märkte vergleichen und strukturelle Fragen vorbereiten.")
 Button(onClick=onPower){Text("Kaufkraft berechnen")}
 OutlinedButton(onClick={nav(1)}){Text("Assets vergleichen")}
 OutlinedButton(onClick=onStructure){Text("Strukturcheck starten")}
 DataNotice(m.data);LiveNotice(m.liveProvenance)
 Panel("Datengrundlage"){Text("${m.data.series.joinToString {it.name}} · ${m.data.series.flatMap {it.points}.minOf {it.year}}–${m.data.series.flatMap {it.points}.maxOf {it.year}}. Für andere Anlageklassen stehen Quellenverweise und der Datenimport bereit.");TextButton(onClick={nav(2)}){Text("Zyklusmodell ansehen")}}
 val missing=listOf("Aktien","Immobilien").filter {group->m.data.series.none {it.group.equals(group,true)}}
 if(missing.isNotEmpty())Text("Nicht im geladenen Bestand: ${missing.joinToString()}. Keine erfundenen Vergleichswerte.",style=MaterialTheme.typography.bodySmall)
 Panel("Gold-Silber-Ratio"){val r=CrisisEngine.ratio(m.data);Text(r?.let { "${number(it.value)} : 1 · ${it.year}" } ?: "Nicht verfügbar",style=MaterialTheme.typography.headlineMedium);Text(if(m.data.kind=="demo")"Rechenbeispiel, kein Marktwert." else "Nur gleiche Währung und Einheit.")}
 Text("Die Welt als Wirkungsfeld.",style=MaterialTheme.typography.headlineSmall)
 m.content.fields.forEach { Panel(it.title){Text(it.text)} }
 Panel("Makrolage"){Text("Inflation % p.a.; Rüstung und BIP in Mrd. USD. Stand ${m.data.asOf}",style=MaterialTheme.typography.bodySmall);m.data.macro.forEach { Text("${it.country}\nInflation: ${it.inflation?.let(::number) ?: "Nicht verfügbar"}\nRüstung: ${it.military?.let(::number) ?: "Nicht verfügbar"} · BIP: ${it.gdp?.let(::number) ?: "Nicht verfügbar"}") }}
}
@Composable fun Comparison(data:MarketData,export:(String)->Unit){
 var selected by rememberSaveable(data){mutableStateOf(data.series.take(2).map { it.id })};var from by rememberSaveable{mutableStateOf("1926")};var to by rememberSaveable{mutableStateOf("2026")};var real by rememberSaveable{mutableStateOf(false)}
 Heading("Vergleich","Werte im Verhältnis.");DataNotice(data)
 Panel("Asset-Auswahl"){data.series.forEach { s-> Row { Checkbox(s.id in selected,{checked->selected=if(checked) selected+s.id else selected-s.id},modifier=Modifier.testTag("asset-${s.id}").semantics {contentDescription=s.name});Text(s.name,Modifier.padding(top=12.dp)) } };Row(horizontalArrangement=Arrangement.spacedBy(12.dp)){OutlinedTextField(from,{from=it},label={Text("Von")},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Number),modifier=Modifier.weight(1f).testTag("compare-from"));OutlinedTextField(to,{to=it},label={Text("Bis")},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Number),modifier=Modifier.weight(1f).testTag("compare-to"))};Row {Checkbox(real,{real=it},modifier=Modifier.testTag("compare-real").semantics {contentDescription="Inflationsbereinigt"});Text("Inflationsbereinigt",Modifier.padding(top=12.dp))};Text("CPI: ${data.cpiRegion}. Gemeinsamer Start = 100. Ohne Wechselkurse, Dividenden, Mieten, Kosten und Steuern.",style=MaterialTheme.typography.bodySmall)}
 val result=runCatching { CrisisEngine.compare(data,selected.toSet(),from.toIntOrNull() ?: error("Bitte ein gültiges Startjahr eingeben."),to.toIntOrNull() ?: error("Bitte ein gültiges Endjahr eingeben."),real) }
 result.onSuccess { ss -> Panel("Langfristig denken."){Text("${ss.first().points.first().year}–${ss.first().points.last().year} · ${if(real)"Real" else "Nominal"} · Basis 100");Plot(ss);ss.forEachIndexed { i,s->Text("${s.name}: 100 → ${number(s.points.last().value)} (${number(s.points.last().value-100)} %) · ${s.unit}",color=PlotColors[i%PlotColors.size]) };Button(onClick={export(CrisisEngine.csv(ss))}){Text("CSV exportieren")}} }.onFailure { Note(it.message ?: "Ungültiger Vergleich.") }
}
@Composable fun Plot(ss:List<Series>){Canvas(Modifier.fillMaxWidth().height(230.dp).semantics{contentDescription="Indexverlauf. Start- und Endwerte stehen unter dem Diagramm."}){
 val values=ss.flatMap{it.points.map{p->p.value}};val maximum=values.max();val lo=values.min()/maximum*.9;val hi=1.1;val first=ss.first().points.first().year;val last=ss.first().points.last().year
 for(i in 0..4){val y=size.height*i/4;drawLine(Color(0xFFDCE1E8),androidx.compose.ui.geometry.Offset(0f,y),androidx.compose.ui.geometry.Offset(size.width,y))}
 ss.forEachIndexed { i,s->val p=Path();s.points.forEachIndexed { j,v->val x=((v.year-first).toFloat()/(last-first))*size.width;val y=(size.height-(v.value/maximum-lo)/(hi-lo)*size.height).toFloat();if(j==0)p.moveTo(x,y)else p.lineTo(x,y) };drawPath(p,PlotColors[i%PlotColors.size],style=androidx.compose.ui.graphics.drawscope.Stroke(3f)) }
}}
@Composable fun Cycles(c:Content){
 var focus by rememberSaveable {mutableStateOf("2026")}
 Heading("Zyklen","Zeit macht Muster sichtbar.")
 Note("Das PDF zeigt ×; die Jahresfolgen entstehen durch Addition der Intervalle. Keine nachgewiesene Prognosegüte. Ab 2027 reine Modellfortschreibung.")
 OutlinedTextField(focus,{focus=it},label={Text("Jahr 1926–2126")},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Number),modifier=Modifier.testTag("cycle-year"))
 val year=focus.toIntOrNull()
 if(year==null||year !in 1926..2126)Note("Bitte Jahr 1926–2126 eingeben.")
 else {val matches=c.cycles.filter{year in CrisisEngine.years(it)};Note(if(matches.isEmpty())"$year: kein Modelltreffer. Keine Aussage über tatsächliches Risiko." else "$year: ${matches.joinToString{it.name}} (Modell)")}
 c.cycles.forEach {cy->Panel(cy.name){Text("Start ${cy.start} · +${cy.steps.joinToString(" / +")} Jahre");Text(CrisisEngine.years(cy).joinToString(" · "){if(it>2026)"$it*" else "$it"});Text("* Szenario",style=MaterialTheme.typography.labelSmall)}}
}
@Composable fun Library(c:Content){
 var search by rememberSaveable {mutableStateOf("")};var opened by rememberSaveable {mutableStateOf<String?>(null)}
 val uri=LocalUriHandler.current;val context=LocalContext.current
 Heading("Wissen","Struktur vor Schlagzeile.")
 OutlinedTextField(search,{search=it},label={Text("Unterlagen durchsuchen")},modifier=Modifier.fillMaxWidth().testTag("document-search"))
 Note("Die Dossiers vertreten die Sicht der Herausgeber. Ihre Aussagen sind nicht unabhängig verifiziert. Originaltexte einschließlich interner Nutzungshinweise.")
 val ds=c.documents.filter{(it.title+it.pages.joinToString()).contains(search,true)}
 if(ds.isEmpty())Text("Keine passenden Dokumente gefunden.")
 ds.forEach {d->Panel(d.title){
  Text("${d.pages.size} Seiten · Vollständige Lesefassung")
  TextButton(onClick={opened=if(opened==d.title)null else d.title}){Text(if(opened==d.title)"Schließen" else "Lesen")}
  if(opened==d.title)d.pages.forEachIndexed {i,p->Text("Seite ${i+1}",style=MaterialTheme.typography.titleMedium);Text(p,style=MaterialTheme.typography.bodyMedium)}
 }}
 Panel("Datenquellen"){
  Text("Webseiten sind keine API-Verträge. Live-Daten erfordern lizenzierte Anbieter und sichere Serveradapter. LSEG.L ist eine Einzelaktie.")
  c.sources.forEach {s->TextButton(onClick={runCatching {uri.openUri(s.url)}.onFailure {android.widget.Toast.makeText(context,"Kein Browser zum Öffnen des Links verfügbar.",android.widget.Toast.LENGTH_LONG).show()}}){Text("${s.provider} · ${s.label} ↗")}}
 }
}
@Composable fun Settings(m:CrisisModel,onImport:()->Unit,onTemplate:()->Unit){
 var legal by rememberSaveable {mutableStateOf(false)}
 Heading("Einstellungen","Ihre Perspektive. Ihre Daten.")
 Panel("White-Label Branding"){
  OutlinedTextField(m.partner,{m.partner=it.take(60)},label={Text("Berater / Partnername")},modifier=Modifier.testTag("partner-name"))
  listOf("navy" to "Midnight Blue","teal" to "Teal Mist","rose" to "Rusty Rose").forEach{(id,name)->Row{RadioButton(m.theme==id,{m.theme=id},modifier=Modifier.semantics {contentDescription=name});Text(name,Modifier.padding(top=12.dp))}}
  Button(onClick={m.brand()}){Text("Branding speichern")}
  Text("Originalpalette: #0f1c3d · #e8b9c8 · #c7e8e3. Dunkle Akzentvarianten für lesbare Bedienelemente.",style=MaterialTheme.typography.bodySmall)
 }
 Panel("Daten importieren"){
  Text("JSON-Schema v1 · maximal 2 MB. Daten bleiben lokal auf diesem Gerät. Keine Zugangsdaten importieren.")
  Button(onClick=onImport,enabled=!m.busy){Text("JSON-Datei auswählen")}
  OutlinedButton(onClick={m.historicalSnapshot()},enabled=!m.busy){Text("Echte historische Daten laden")}
  OutlinedButton(onClick=onTemplate,enabled=!m.busy){Text("Beispieldatei speichern")}
  OutlinedButton(onClick={m.reset()},enabled=!m.busy){Text("Beispieldaten wiederherstellen")}
 }
 Panel("Aktueller Datenserver"){
  Text("Optional: HTTPS-Adresse Ihres CRISIS-Datenservers, etwa dessen /api/data-Endpunkt. Die Verbindung erfolgt nur beim Antippen. Keine Zugangsdaten eintragen.",style=MaterialTheme.typography.bodySmall)
  OutlinedTextField(m.endpoint,{m.endpoint=it},label={Text("HTTPS-Datenquelle")},singleLine=true,modifier=Modifier.fillMaxWidth().testTag("data-endpoint"))
  Button(onClick={m.refreshLive()},enabled=!m.busy && m.endpoint.isNotBlank()){Text("Daten vom Server aktualisieren")}
  Text("Bei einem Fehler bleibt der zuletzt gespeicherte Datensatz erhalten. Der Server muss Herkunft und Aktualität ausweisen; Jahresreihen sind keine Echtzeitkurse.",style=MaterialTheme.typography.bodySmall)
 }
 Panel("Rechtliches"){
  TextButton(onClick={legal=!legal}){Text("Impressum & Datenschutz")}
  if(legal){
   Text("ALL I AM Akademie, ein Bereich des Herzenskraft e.V.\nKreuzkirchstrasse 17, 77652 Offenburg\nAlexander Avsar, Präsident\ninfo@aia.berlin · www.aia.berlin/crisis\nAngaben aus dem Brandguide. Register- und weitere Pflichtangaben sind vor Veröffentlichung zu bestätigen.")
   Text("Keine Cookies, kein Tracking, kein Konto. Importierte Daten und Branding bleiben lokal. Der persönliche Strukturcheck speichert Ihre Antworten, Notizen, Zuständigkeit und Wiederprüfung nur nach ausdrücklichem Speichern auf diesem Gerät. Diese Angaben werden nicht an den Kursadapter oder CRISIS übertragen. Mit ‚Strukturcheck löschen‘ entfernen Sie die gespeicherte Checkliste; importierte Marktdaten lassen sich über die Wiederherstellung löschen. Exporte erstellen bewusst gewählte Dateien, deren weitere Verwendung Sie selbst bestimmen. Sämtliche lokalen Daten können Sie über die Android-App-Einstellungen löschen. Beim bewusst gestarteten HTTPS-Abruf erhält Ihr Datenserver technische Verbindungsdaten. Für externe Links gelten die Datenschutzbestimmungen der Anbieter. Diese Hinweise sind vor Veröffentlichung an den tatsächlichen Betrieb anzupassen.")
  }
 }
}
