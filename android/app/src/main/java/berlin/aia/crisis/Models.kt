package berlin.aia.crisis

import org.json.JSONObject
import java.time.LocalDate

data class Point(val year: Int, val value: Double)
data class Series(val id: String, val name: String, val group: String, val unit: String, val currency: String, val points: List<Point>)
data class Macro(val country: String, val inflation: Double?, val military: Double?, val gdp: Double?)
data class MarketData(val kind: String, val asOf: String, val source: String, val cpiRegion: String, val cpi: List<Point>, val series: List<Series>, val macro: List<Macro>)
data class Cycle(val id: String, val name: String, val start: Int, val steps: List<Int>)
data class Document(val title: String, val file: String, val pages: List<String>)
data class Source(val provider: String, val label: String, val url: String)
data class Field(val title: String, val text: String)
data class Content(val cycles: List<Cycle>, val documents: List<Document>, val sources: List<Source>, val fields: List<Field>)

object CrisisEngine {
 fun years(c: Cycle, from: Int = 1926, to: Int = 2126): List<Int> {
  require(from in 1800..2200 && to in from..2200)
  val result = mutableListOf<Int>(); var year = c.start; var i = 0
  while (year <= to) { if (year >= from) result.add(year); year += c.steps[i++ % c.steps.size] }
  return result
 }
 fun parse(text: String): MarketData {
  require(text.toByteArray().size <= 2 * 1024 * 1024) { "Maximal 2 MB erlaubt." }
  val j = JSONObject(text)
  require(j.get("schemaVersion") is Number && j.getDouble("schemaVersion") == 1.0 && j.getString("kind") in listOf("demo", "import")) { "Schema v1 und kind demo/import erforderlich." }
  val date = j.getString("asOf"); require(Regex("\\d{4}-\\d{2}-\\d{2}").matches(date)); LocalDate.parse(date)
  fun str(o: JSONObject, key: String, max: Int = 100): String { require(o.get(key) is String); val v = o.getString(key); require(v.isNotBlank() && v.length <= max) { "Ungültiges Feld $key" }; return v }
  fun points(o: JSONObject, key: String): List<Point> {
   val a = o.getJSONArray(key); require(a.length() in 1..401); var prev = 0
   return (0 until a.length()).map { val p = a.getJSONObject(it); require(p.get("year") is Number && p.get("value") is Number); val yr = p.getDouble("year"); val v = p.getDouble("value"); require(yr % 1 == 0.0 && yr in 1800.0..2200.0 && yr > prev && v.isFinite() && v > 0 && v <= 1e15) { "Sortierte Jahre und positive Werte erforderlich." }; prev = yr.toInt(); Point(prev, v) }
  }
  val a = j.getJSONArray("series"); require(a.length() in 1..30)
  val series = (0 until a.length()).map { val s = a.getJSONObject(it); val id = str(s, "id"); require(Regex("[a-z][a-z0-9-]{0,39}").matches(id)); Series(id, str(s,"name"), str(s,"group"),str(s,"unit"),str(s,"currency"),points(s,"points")) }
  require(series.map { it.id }.distinct().size == series.size)
  val m = j.getJSONArray("macro"); require(m.length() <= 20)
  val macro = (0 until m.length()).map { val v = m.getJSONObject(it); fun num(k: String): Double? { require(v.has(k)); if(v.isNull(k)) return null; require(v.get(k) is Number); val n = v.getDouble(k); require(n.isFinite() && kotlin.math.abs(n) <= 1e15 && (k == "inflation" || n >= 0)); return n }; Macro(str(v,"country"),num("inflation"),num("military"),num("gdp")) }
  return MarketData(j.getString("kind"),date,str(j,"source",500),str(j,"cpiRegion",500),points(j,"cpi"),series,macro)
 }
 fun content(text: String): Content {
  val j=JSONObject(text)
  val cs=j.getJSONArray("cycles"); val ds=j.getJSONArray("documents");val ss=j.getJSONArray("sources");val fs=j.getJSONArray("fields")
  return Content((0 until cs.length()).map { val c=cs.getJSONObject(it); val steps=c.getJSONArray("steps");Cycle(c.getString("id"),c.getString("name"),c.getInt("start"),(0 until steps.length()).map { steps.getInt(it) }) },(0 until ds.length()).map { val d=ds.getJSONObject(it);val p=d.getJSONArray("pages");Document(d.getString("title"),d.getString("file"),(0 until p.length()).map { p.getString(it) }) },(0 until ss.length()).map { val s=ss.getJSONObject(it);Source(s.getString("provider"),s.getString("label"),s.getString("url")) },(0 until fs.length()).map { val f=fs.getJSONObject(it);Field(f.getString("title"),f.getString("text")) })
 }
 fun compare(data: MarketData, ids: Set<String>, from: Int, to: Int, real: Boolean): List<Series> {
  require(from in 1800..2200 && to in from..2200) { "Gültigen Jahresbereich 1800–2200 angeben." }
  val ss=data.series.filter { it.id in ids }; require(ss.isNotEmpty()) { "Mindestens ein Asset auswählen." }
  val cpi=data.cpi.associate { it.year to it.value }
  val years=ss.first().points.map { it.year }.filter { y -> y in from..to && ss.all { s -> s.points.any { it.year==y } } && (!real || cpi.containsKey(y)) }
  require(years.size>=2) { "Mindestens zwei gemeinsame Jahreswerte (ggf. mit CPI) erforderlich." }
  val base=years.first()
  return ss.map { s -> val map=s.points.associate { it.year to it.value };s.copy(points=years.map { y ->
   val value=map.getValue(y)/map.getValue(base)*100*(if(real)cpi.getValue(base)/cpi.getValue(y) else 1.0)
   require(value.isFinite() && value>0 && value<=1e15) { "Die Werte erzeugen einen nicht darstellbaren Index. Bitte den Datensatz prüfen." }
   Point(y,value)
  }) }
 }
 fun ratio(d: MarketData): Point? {
  val a=d.series.find { it.id=="gold" } ?: return null;val b=d.series.find { it.id=="silver" } ?: return null
  if(a.currency!=b.currency || a.unit!=b.unit)return null
  for(p in a.points.reversed()) {
   val q=b.points.find { it.year==p.year } ?: continue
   val value=p.value/q.value
   return if(value.isFinite() && value>0)Point(p.year,value) else null
  }
  return null
 }
 fun csvLabel(name: String): String { val safe=if(Regex("^[\\s]*[=+\\-@]|^[\\t\\r\\n]").containsMatchIn(name)) "'"+name else name;return "\""+safe.replace("\"","\"\"")+"\"" }
 fun csv(ss: List<Series>)="Asset;Jahr;Index\n"+ss.flatMap { s -> s.points.map { p -> "${csvLabel(s.name)};${p.year};${String.format(java.util.Locale.US,"%.4f",p.value)}" } }.joinToString("\n")+"\n"
}
