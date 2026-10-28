// Independent of the UI: identical contracts are implemented natively in Kotlin/Swift.
const statuses = ['unreviewed', 'documented', 'needs_action', 'not_applicable'];
function result(amount, factor) {
  if (typeof amount !== 'number' || !Number.isFinite(amount) || amount <= 0 || amount > 1e12)
    throw Error('Betrag größer null und höchstens 1 Billion eingeben.');
  const requiredAmount = amount * factor, remainingPower = amount / factor;
  if ([factor, requiredAmount, remainingPower].some(v => !Number.isFinite(v) || v <= 0 || v > 1e15))
    throw Error('Die Annahmen führen zu nicht darstellbaren Beträgen.');
  return {amount, factor, requiredAmount, remainingPower, lossPercent: (1 - 1 / factor) * 100, priceChangePercent: (factor - 1) * 100};
}
export function purchasingPower(data, amount, from, to) {
  if (!Number.isInteger(from) || !Number.isInteger(to) || from >= to)
    throw Error('Das Endjahr muss nach dem Startjahr liegen.');
  const a = data.cpi.find(p => p.year === from), b = data.cpi.find(p => p.year === to);
  if (!a || !b) throw Error('Für beide ausgewählten Jahre werden CPI-Werte benötigt. Es wird nicht interpoliert.');
  return {...result(amount, b.value / a.value), from, to};
}
export function inflationScenario(amount, ratePercent, years) {
  if (typeof ratePercent !== 'number' || !Number.isFinite(ratePercent) || ratePercent < -50 || ratePercent > 100)
    throw Error('Angenommene Inflationsrate zwischen −50 und 100 Prozent eingeben.');
  if (!Number.isInteger(years) || years < 1 || years > 100) throw Error('Zeitraum von 1 bis 100 ganzen Jahren eingeben.');
  return {...result(amount, (1 + ratePercent / 100) ** years), ratePercent, years};
}
export function emptyPlan(questions) {
  return {schemaVersion: 1, answers: Object.fromEntries(questions.map(q => [q.id, {status: 'unreviewed', note: ''}])), action: '', owner: '', reviewDate: ''};
}
export function validatePlan(plan, questions) {
  if (!plan || plan.schemaVersion !== 1 || !plan.answers || typeof plan.answers !== 'object' || Array.isArray(plan.answers))
    throw Error('Ungültiger Strukturcheck.');
  if (Object.keys(plan.answers).length !== questions.length || Object.keys(plan.answers).some(id => !questions.some(q => q.id === id)))
    throw Error('Der Strukturcheck muss genau die vorgesehenen Prüffragen enthalten.');
  const text = (v, max) => typeof v === 'string' && v.length <= max;
  if (!text(plan.action, 1000) || !text(plan.owner, 80) || !text(plan.reviewDate, 10)) throw Error('Textlänge im Strukturcheck überschritten.');
  if (plan.reviewDate && (!/^\d{4}-\d{2}-\d{2}$/.test(plan.reviewDate) || !Number.isFinite(Date.parse(plan.reviewDate)) || new Date(plan.reviewDate).toISOString().slice(0, 10) !== plan.reviewDate))
    throw Error('Gültiges Datum der Wiederprüfung angeben.');
  for (const q of questions) {
    const a = plan.answers[q.id];
    if (!a || !statuses.includes(a.status) || !text(a.note, 500)) throw Error('Ungültige Antwort im Strukturcheck.');
  }
  return {schemaVersion: 1, answers: Object.fromEntries(questions.map(q => [q.id, {status: plan.answers[q.id].status, note: plan.answers[q.id].note}])), action: plan.action, owner: plan.owner, reviewDate: plan.reviewDate};
}
export function planSummary(plan, questions) {
  const clean = validatePlan(plan, questions);
  const counts = Object.fromEntries(statuses.map(s => [s, 0]));
  for (const a of Object.values(clean.answers)) counts[a.status]++;
  return {...counts, total: questions.length, reviewed: questions.length - counts.unreviewed, open: counts.unreviewed + counts.needs_action,
    needsAction: counts.needs_action, notApplicable: counts.not_applicable};
}
export function planningReport(plan, questions, {partner = '', generatedAt = ''} = {}) {
  const clean = validatePlan(plan, questions), summary = planSummary(clean, questions);
  const names = {unreviewed: 'Noch ungeprüft', documented: 'Dokumentiert', needs_action: 'Klärung nötig', not_applicable: 'Nicht zutreffend'};
  return ['CRISIS © · Persönlicher Strukturcheck', generatedAt ? `Erstellt: ${generatedAt}` : '', partner ? `Beratung: ${partner}` : '',
    `${summary.reviewed}/${summary.total} bearbeitet · ${summary.open} offene Prüfpunkte`,
    'Eigene Bestandsaufnahme, kein gemessener Risikoscore und keine Anlageempfehlung.', '',
    ...questions.flatMap(q => [q.title, q.text, `Status: ${names[clean.answers[q.id].status]}`, `Notiz: ${clean.answers[q.id].note || '—'}`, `Bezug: ${q.source}`, '']),
    `Nächster Prüfschritt: ${clean.action || '—'}`, `Zuständig: ${clean.owner || '—'}`, `Wiederprüfung: ${clean.reviewDate || '—'}`].filter(v => v !== null).join('\n') + '\n';
}
