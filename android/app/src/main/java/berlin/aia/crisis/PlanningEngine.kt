package berlin.aia.crisis

import org.json.JSONObject
import java.time.LocalDate
import kotlin.math.pow

data class PurchasingPower(val factor: Double,val requiredAmount: Double,val remainingPower: Double,val lossPercent: Double,val priceChangePercent: Double)
data class PlanningQuestion(val id: String,val title: String,val text: String,val source: String,val why: String)
data class PlanningGuide(val title: String,val purpose: String,val questions: List<PlanningQuestion>)
data class PlanningAnswer(val status: String="unreviewed",val note: String="")
data class StructurePlan(val answers: Map<String,PlanningAnswer>,val action: String="",val owner: String="",val reviewDate: String="")
data class PlanningSummary(val reviewed: Int,val open: Int,val documented: Int,val needsAction: Int,val notApplicable: Int)

object PlanningEngine {
 val ids=listOf("liquidity","access","dependencies","alternatives","decisions")
 val statuses=linkedMapOf("unreviewed" to "Noch ungeprüft","documented" to "Dokumentiert","needs_action" to "Klärung nötig","not_applicable" to "Nicht zutreffend")
 fun guide(text: String): PlanningGuide {
  val j=JSONObject(text);require(j.getInt("schemaVersion")==1)
  val questions=j.getJSONArray("questions")
  val result=(0 until questions.length()).map {i->val q=questions.getJSONObject(i);PlanningQuestion(q.getString("id"),q.getString("title"),q.getString("text"),q.getString("source"),q.getString("why"))}
  require(result.map {it.id}==ids)
  return PlanningGuide(j.getString("title"),j.getString("purpose"),result)
 }
 fun emptyPlan()=StructurePlan(ids.associateWith {PlanningAnswer()})
 private fun checkAmount(amount: Double) {require(amount.isFinite() && amount>0 && amount<=1e12){"Betrag muss größer 0 und höchstens 1 Billion sein."}}
 private fun result(amount: Double,factor: Double): PurchasingPower {
  val required=amount*factor;val remaining=amount/factor
  require(factor.isFinite() && factor>0 && factor<=1e15 && required.isFinite() && required>0 && required<=1e15 && remaining.isFinite() && remaining>0 && remaining<=1e15){"Das Ergebnis ist nicht darstellbar. Kleinere Eingaben wählen."}
  val loss=(1-1/factor)*100;val change=(factor-1)*100
  require(loss.isFinite() && change.isFinite()){"Das Ergebnis ist nicht darstellbar."}
  return PurchasingPower(factor,required,remaining,loss,change)
 }
 fun purchasingPower(data: MarketData,amount: Double,from: Int,to: Int): PurchasingPower {
  checkAmount(amount);require(from<to){"Das Startjahr muss vor dem Endjahr liegen."}
  val start=data.cpi.find {it.year==from}?.value ?: error("Für das Startjahr fehlt ein CPI-Wert.")
  val end=data.cpi.find {it.year==to}?.value ?: error("Für das Endjahr fehlt ein CPI-Wert.")
  return result(amount,end/start)
 }
 fun inflationScenario(amount: Double,ratePercent: Double,years: Int): PurchasingPower {
  checkAmount(amount);require(ratePercent.isFinite() && ratePercent in -50.0..100.0){"Annahme zwischen −50 und 100 Prozent eingeben."}
  require(years in 1..100){"Dauer zwischen 1 und 100 Jahren eingeben."}
  return result(amount,(1+ratePercent/100).pow(years))
 }
 fun validDate(date: String): Boolean= date.isEmpty() || runCatching {require(Regex("\\d{4}-\\d{2}-\\d{2}").matches(date));LocalDate.parse(date);true}.getOrDefault(false)
 fun validate(plan: StructurePlan): StructurePlan {
  require(plan.answers.keys==ids.toSet()){"Alle fünf Fragen sind erforderlich."}
  plan.answers.values.forEach {require(it.status in statuses && it.note.length<=500){"Ungültiger Status oder Notiz über 500 Zeichen."}}
  require(plan.action.length<=1000 && plan.owner.length<=80){"Nächster Schritt oder Zuständigkeit zu lang."}
  require(validDate(plan.reviewDate)){"Prüftermin im Format JJJJ-MM-TT eingeben."}
  return plan
 }
 fun parse(text: String): StructurePlan {
  require(text.toByteArray(Charsets.UTF_8).size<=32*1024){"Strukturcheck ist größer als 32 KiB."}
  val j=JSONObject(text);require(j.get("schemaVersion") is Number && j.getDouble("schemaVersion")==1.0){"Unbekannte Planversion."}
  val answers=j.getJSONObject("answers");require(answers.keys().asSequence().toSet()==ids.toSet())
  fun field(o: JSONObject,k: String): String {require(o.get(k) is String);return o.getString(k)}
  return validate(StructurePlan(ids.associateWith {val a=answers.getJSONObject(it);PlanningAnswer(field(a,"status"),field(a,"note"))},field(j,"action"),field(j,"owner"),field(j,"reviewDate")))
 }
 fun json(plan: StructurePlan): String {
  validate(plan);val answers=JSONObject()
  ids.forEach {id->val a=plan.answers.getValue(id);answers.put(id,JSONObject().put("status",a.status).put("note",a.note))}
  return JSONObject().put("schemaVersion",1).put("answers",answers).put("action",plan.action).put("owner",plan.owner).put("reviewDate",plan.reviewDate).toString()
 }
 fun summary(plan: StructurePlan): PlanningSummary {
  validate(plan);fun count(status: String)=plan.answers.values.count {it.status==status}
  val unreviewed=count("unreviewed");val needs=count("needs_action")
  return PlanningSummary(ids.size-unreviewed,unreviewed+needs,count("documented"),needs,count("not_applicable"))
 }
 fun report(guide: PlanningGuide,plan: StructurePlan,partner: String,date: String=LocalDate.now().toString()): String {
  validate(plan);val summary=summary(plan)
  return buildString {
   appendLine("CRISIS © · ${guide.title}");appendLine("Erstellt: $date")
   if(partner.isNotBlank())appendLine("Partner: $partner")
   appendLine(guide.purpose);appendLine("${summary.reviewed}/5 beantwortet · ${summary.open} offene Prüfpunkte. Kein Risikoscore.")
   guide.questions.forEach {q->val a=plan.answers.getValue(q.id);appendLine();appendLine(q.title);appendLine(q.text);appendLine("Status: ${statuses.getValue(a.status)}");appendLine("Notiz: ${a.note.ifBlank {"—"}}");appendLine("Quelle: ${q.source}");appendLine("Einordnung: ${q.why}")}
   appendLine();appendLine("Nächster Schritt: ${plan.action.ifBlank {"—"}}");appendLine("Zuständig: ${plan.owner.ifBlank {"—"}}");appendLine("Prüftermin: ${plan.reviewDate.ifBlank {"—"}}")
   appendLine("Selbstauskunft zur Vorbereitung eines Gesprächs. Keine Prognose, Anlageempfehlung oder rechtliche Bewertung.")
  }
 }
}
