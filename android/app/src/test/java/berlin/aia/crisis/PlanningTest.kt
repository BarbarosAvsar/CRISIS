package berlin.aia.crisis

import org.junit.Assert.*
import org.junit.Test
import java.io.File

class PlanningTest {
 private fun fixture(name:String)=File(System.getProperty("crisis.shared"),name).readText()
 @Test fun historicalUsesOnlyExactCPIObservations(){
  val d=CrisisEngine.parse(fixture("golden-data.json"))
  val r=PlanningEngine.purchasingPower(d,10000.0,2020,2022)
  assertEquals(1.21,r.factor,1e-12);assertEquals(12100.0,r.requiredAmount,1e-9)
  assertEquals(8264.462809917355,r.remainingPower,1e-9);assertEquals(17.355371900826448,r.lossPercent,1e-9)
  assertThrows(IllegalStateException::class.java){PlanningEngine.purchasingPower(d,10000.0,2019,2022)}
  assertThrows(IllegalArgumentException::class.java){PlanningEngine.purchasingPower(d,10000.0,2022,2020)}
 }
 @Test fun scenarioMatchesSharedVectorsAndHandlesDeflation(){
  val vectors=org.json.JSONObject(fixture("planning-vectors.json"))
  for(key in listOf("scenario","deflation")){
   val v=vectors.getJSONObject(key);val r=PlanningEngine.inflationScenario(v.getDouble("amount"),v.getDouble("ratePercent"),v.getInt("years"))
   assertEquals(v.getDouble("remainingPower"),r.remainingPower,1e-9);assertEquals(v.getDouble("requiredAmount"),r.requiredAmount,1e-9)
  }
  val flat=PlanningEngine.inflationScenario(10000.0,0.0,10);assertEquals(10000.0,flat.remainingPower,0.0);assertEquals(0.0,flat.lossPercent,0.0)
 }
 @Test fun extremeOrMalformedCalculatorInputsAreRejected(){
  for(amount in listOf(0.0,-1.0,Double.NaN,Double.POSITIVE_INFINITY,1e12+1))assertThrows(IllegalArgumentException::class.java){PlanningEngine.inflationScenario(amount,3.0,10)}
  assertThrows(IllegalArgumentException::class.java){PlanningEngine.inflationScenario(10000.0,101.0,10)}
  assertThrows(IllegalArgumentException::class.java){PlanningEngine.inflationScenario(10000.0,3.0,0)}
  assertThrows(IllegalArgumentException::class.java){PlanningEngine.inflationScenario(1e12,100.0,100)}
 }
 @Test fun planRoundTripAndCountsHaveNoRiskScore(){
  val plan=PlanningEngine.emptyPlan().copy(answers=PlanningEngine.emptyPlan().answers+mapOf("liquidity" to PlanningAnswer("documented","Vorhandene Reserve geprüft"),"access" to PlanningAnswer("needs_action","Vertretung prüfen"),"decisions" to PlanningAnswer("not_applicable","")),action="Zugänge besprechen",owner="Ich",reviewDate="2028-02-29")
  assertEquals(plan,PlanningEngine.parse(PlanningEngine.json(plan)))
  assertEquals(PlanningSummary(3,3,1,1,1),PlanningEngine.summary(plan))
 }
 @Test fun invalidPlansAreRejectedInsteadOfPartiallySaved(){
  val p=PlanningEngine.emptyPlan()
  for(invalid in listOf(p.copy(answers=p.answers-"access"),p.copy(action="a".repeat(1001)),p.copy(owner="a".repeat(81)),p.copy(reviewDate="2026-02-30"),p.copy(answers=p.answers+("access" to PlanningAnswer("safe",""))),p.copy(answers=p.answers+("access" to PlanningAnswer("unreviewed","a".repeat(501))))))assertThrows(IllegalArgumentException::class.java){PlanningEngine.validate(invalid)}
  assertThrows(IllegalArgumentException::class.java){PlanningEngine.parse(" ".repeat(32*1024+1))}
 }
 @Test fun reportContainsSourcesNotesAndConcreteNextStep(){
  val guide=PlanningEngine.guide(fixture("planning.json"));val p=PlanningEngine.emptyPlan().copy(action="Vertretungsregelung prüfen",owner="Beratung",reviewDate="2026-12-01")
  val report=PlanningEngine.report(guide,p,"Partner","2026-10-28")
  guide.questions.forEach {assertTrue(report.contains(it.source));assertTrue(report.contains(it.text))}
  assertTrue(report.contains("Vertretungsregelung prüfen"));assertTrue(report.contains("Partner: Partner"));assertTrue(report.contains("Kein Risikoscore."))
 }
}
