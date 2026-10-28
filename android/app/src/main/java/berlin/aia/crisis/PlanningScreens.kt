package berlin.aia.crisis

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp

@Composable fun MoreMenu(open: (String)->Unit) {
 Heading("Mehr","Werkzeuge für Ihre nächsten Fragen.")
 Panel("Kaufkraft"){Text("Verstehen, wie ein Preisindex oder eine eigene Inflationsannahme einen unveränderten Geldbetrag verändert.");Button(onClick={open("power")}){Text("Kaufkraft öffnen")}}
 Panel("Strukturcheck"){Text("Fünf Fragen zu Verfügbarkeit, Abhängigkeiten und Entscheidungen. Antworten und nächsten Prüfschritt lokal festhalten.");Button(onClick={open("structure")}){Text("Strukturcheck öffnen")}}
 Panel("Einstellungen"){Text("Datenquellen, Import, Partnerbranding und rechtliche Hinweise.");Button(onClick={open("settings")}){Text("Einstellungen öffnen")}}
}

@Composable fun PurchasingPowerScreen(data: MarketData) {
 var scenario by rememberSaveable {mutableStateOf(false)}
 var amount by rememberSaveable {mutableStateOf("10000")}
 var from by rememberSaveable(data) {mutableStateOf((data.cpi.find {it.year==2000}?.year ?: data.cpi.first().year).toString())}
 var to by rememberSaveable(data) {mutableStateOf(data.cpi.last().year.toString())}
 var rate by rememberSaveable {mutableStateOf("3")}
 var years by rememberSaveable {mutableStateOf("10")}
 Heading("Kaufkraft","Was bleibt vom gleichen Betrag?")
 Text("Alle Ergebnisse sind Geldeinheiten. Der Rechner verwendet keine Wechselkurse und bewertet keine Anlageentscheidung.")
 Row(horizontalArrangement=Arrangement.spacedBy(12.dp)){
  FilterChip(selected=!scenario,onClick={scenario=false},label={Text("Historisch")},modifier=Modifier.testTag("power-history"))
  FilterChip(selected=scenario,onClick={scenario=true},label={Text("Eigene Annahme")},modifier=Modifier.testTag("power-scenario"))
 }
 Panel(if(scenario)"Ihre Inflationsannahme" else "Historische Kaufkraft"){
  OutlinedTextField(amount,{amount=it},label={Text("Betrag in Geldeinheiten")},supportingText={Text("Ohne Tausendertrennzeichen, maximal 1 Billion.")},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Decimal),modifier=Modifier.fillMaxWidth().testTag("power-amount"))
  if(scenario){
   Note("Reine Rechenannahme, keine Prognose. Die gewählte konstante Rate kann von tatsächlichen Entwicklungen abweichen.")
   OutlinedTextField(rate,{rate=it},label={Text("Inflation pro Jahr in % (−50 bis 100)")},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Decimal),modifier=Modifier.fillMaxWidth().testTag("power-rate"))
   OutlinedTextField(years,{years=it},label={Text("Dauer in Jahren (1–100)")},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Number),modifier=Modifier.fillMaxWidth().testTag("power-years"))
  } else {
   DataNotice(data)
   Text("CPI-Region: ${data.cpiRegion}. Verfügbare Jahre: ${data.cpi.first().year}–${data.cpi.last().year}. Es werden nur tatsächlich vorhandene Jahreswerte verwendet.",style=MaterialTheme.typography.bodySmall)
   Row(horizontalArrangement=Arrangement.spacedBy(12.dp)){
    OutlinedTextField(from,{from=it},label={Text("Startjahr")},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Number),modifier=Modifier.weight(1f).testTag("power-from"))
    OutlinedTextField(to,{to=it},label={Text("Endjahr")},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Number),modifier=Modifier.weight(1f).testTag("power-to"))
   }
   Text("Die CPI-Region ist keine Währungsumrechnung. Ein US-Preisindex beschreibt nicht automatisch die persönliche Inflation in Deutschland.",style=MaterialTheme.typography.bodySmall)
  }
 }
 val result=runCatching {
  val a=amount.replace(',','.').toDoubleOrNull() ?: error("Bitte einen gültigen Betrag eingeben.")
  if(scenario)PlanningEngine.inflationScenario(a,rate.replace(',','.').toDoubleOrNull() ?: error("Bitte eine gültige Rate eingeben."),years.toIntOrNull() ?: error("Bitte eine ganze Anzahl Jahre eingeben."))
  else PlanningEngine.purchasingPower(data,a,from.toIntOrNull() ?: error("Bitte ein Startjahr eingeben."),to.toIntOrNull() ?: error("Bitte ein Endjahr eingeben."))
 }
 result.onSuccess {r->Panel("Ergebnis${if(scenario)" Ihrer Annahme" else " der CPI-Rechnung"}"){
  Text("Verbleibende Kaufkraft: ${number(r.remainingPower)} Geldeinheiten",modifier=Modifier.testTag("power-remaining"),style=MaterialTheme.typography.titleMedium)
  Text("Betrag für gleiche Kaufkraft am Ende: ${number(r.requiredAmount)} Geldeinheiten",modifier=Modifier.testTag("power-required"))
  Text("${if(r.lossPercent<0)"Kaufkraftgewinn" else "Kaufkraftverlust"}: ${number(kotlin.math.abs(r.lossPercent))} %")
  Text("Preisniveauänderung: ${number(r.priceChangePercent)} %")
  Text("Bei unverändertem nominalem Betrag. Faktor: ${number(r.factor)}. Keine Zinsen, Gebühren oder Steuern berücksichtigt.",style=MaterialTheme.typography.bodySmall)
 }}.onFailure {Note(it.message ?: "Bitte die Eingaben prüfen.")}
}

@Composable fun StructureCheckScreen(m: CrisisModel,export:()->Unit) {
 var confirmDelete by rememberSaveable {mutableStateOf(false)}
 val plan=m.plan;val guide=m.planningGuide
 Heading("Strukturcheck","Handlungsfähigkeit beginnt mit Klarheit.")
 Text(guide.purpose)
 Note("Die Antworten bleiben auf diesem Gerät, bis Sie selbst einen Textbericht exportieren. Keine Kontonummern, Zugangsdaten oder andere Geheimnisse eintragen.")
 if(m.planWarning.isNotBlank())Note(m.planWarning)
 val summary=runCatching {PlanningEngine.summary(plan)}.getOrNull()
 if(summary!=null)Panel("Ihr Arbeitsstand"){
  Text("${summary.reviewed} von 5 beantwortet · ${summary.open} offene Prüfpunkte",modifier=Modifier.testTag("plan-summary"))
  Text("Dokumentiert: ${summary.documented} · Klärung nötig: ${summary.needsAction} · Nicht zutreffend: ${summary.notApplicable}")
  Text("Offen umfasst ungeprüfte Fragen und selbst angegebenen Klärungsbedarf. Das ist kein Risikoscore.",style=MaterialTheme.typography.bodySmall)
 }
 guide.questions.forEach {q->
  val answer=plan.answers.getValue(q.id)
  Panel(q.title){
   Text(q.text)
   Text(q.why,style=MaterialTheme.typography.bodySmall)
   PlanningEngine.statuses.forEach {(status,label)->Row {
    RadioButton(answer.status==status,{m.answer(q.id,status=status)},enabled=!m.planBusy,modifier=Modifier.testTag("plan-${q.id}-$status").semantics {contentDescription="${q.title}: $label"})
    Text(label,Modifier.padding(top=12.dp))
   }}
   OutlinedTextField(answer.note,{m.answer(q.id,note=it)},label={Text("Notiz zu ${q.title}")},supportingText={Text("${answer.note.length}/500 Zeichen")},enabled=!m.planBusy,modifier=Modifier.fillMaxWidth().testTag("plan-${q.id}-note"))
   Text("Quelle: ${q.source}",style=MaterialTheme.typography.bodySmall)
  }
 }
 Panel("Nächster Prüfschritt"){
  OutlinedTextField(plan.action,{m.planDetails(action=it)},label={Text("Nächster konkreter Schritt")},supportingText={Text("${plan.action.length}/1000 Zeichen")},enabled=!m.planBusy,modifier=Modifier.fillMaxWidth().testTag("plan-action"))
  OutlinedTextField(plan.owner,{m.planDetails(owner=it)},label={Text("Zuständig (optional)")},supportingText={Text("Maximal 80 Zeichen")},enabled=!m.planBusy,modifier=Modifier.fillMaxWidth().testTag("plan-owner"))
  OutlinedTextField(plan.reviewDate,{m.planDetails(reviewDate=it)},label={Text("Prüftermin (JJJJ-MM-TT, optional)")},enabled=!m.planBusy,modifier=Modifier.fillMaxWidth().testTag("plan-review-date"))
 }
 val valid=runCatching {PlanningEngine.validate(plan)}.isSuccess
 if(!valid)Note("Bitte den Prüftermin und die Textlängen kontrollieren.")
 Button(onClick={m.savePlan()},enabled=valid && !m.planBusy,modifier=Modifier.testTag("plan-save")){Text("Strukturcheck speichern")}
 OutlinedButton(onClick=export,enabled=valid && !m.planBusy){Text("Textbericht exportieren")}
 Text("Nur Speichern sichert die Antworten dauerhaft. Export erstellt eine von Ihnen gewählte Datei; es erfolgt keine automatische Übertragung.",style=MaterialTheme.typography.bodySmall)
 OutlinedButton(onClick={confirmDelete=true},enabled=!m.planBusy){Text("Strukturcheck löschen")}
 if(confirmDelete)AlertDialog(onDismissRequest={confirmDelete=false},title={Text("Strukturcheck löschen?")},text={Text("Gespeicherte Antworten, Notizen und Prüfschritt werden von diesem Gerät gelöscht.")},confirmButton={TextButton(onClick={confirmDelete=false;m.deletePlan()}){Text("Jetzt löschen")}},dismissButton={TextButton(onClick={confirmDelete=false}){Text("Abbrechen")}})
}
