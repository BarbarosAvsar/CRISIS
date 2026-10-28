import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {purchasingPower,inflationScenario,emptyPlan,validatePlan,planSummary,planningReport} from '../web/planning.js';

const config=JSON.parse(await readFile(new URL('../shared/planning.json',import.meta.url)));
const vectors=JSON.parse(await readFile(new URL('../shared/planning-vectors.json',import.meta.url)));
const fixture=JSON.parse(await readFile(new URL('../shared/golden-data.json',import.meta.url)));
const near=(actual,expected)=>assert.ok(Math.abs(actual-expected)<=Math.max(1,Math.abs(expected))*1e-12,`${actual} != ${expected}`);
test('historical purchasing power distinguishes required money from power of unchanged money',()=>{
 const v=vectors.historical,r=purchasingPower(fixture,v.amount,v.from,v.to);
 for(const key of ['factor','requiredAmount','remainingPower','lossPercent'])near(r[key],v[key]);
 near(r.priceChangePercent,21);
});
test('future assumptions use compound inflation; deflation is a signed purchasing-power gain',()=>{
 for(const v of [vectors.scenario,vectors.deflation]){
  const r=inflationScenario(v.amount,v.ratePercent,v.years);
  for(const key of ['factor','requiredAmount','remainingPower'])near(r[key],v[key]);
 }
 assert.ok(inflationScenario(10000,-2,5).lossPercent<0);
 const unchanged=inflationScenario(10000,0,10);near(unchanged.remainingPower,10000);near(unchanged.lossPercent,0);
});
test('missing CPI years, reversed dates, invalid scenarios and overflowing amounts fail honestly',()=>{
 for(const args of [[fixture,10000,2019,2022],[fixture,10000,2022,2020],[fixture,0,2020,2022]])assert.throws(()=>purchasingPower(...args));
 for(const args of [[10000,3,0],[10000,3,1.5],[10000,-100,10],[10000,101,10],[-1,3,10],[Infinity,3,10],[1e12,100,100],[1e12,-50,100]])assert.throws(()=>inflationScenario(...args));
});
test('checklist counts work remaining instead of inventing a risk score',()=>{
 const plan=emptyPlan(config.questions);
 assert.deepEqual(planSummary(plan,config.questions),{unreviewed:5,documented:0,needs_action:0,not_applicable:0,total:5,reviewed:0,open:5,needsAction:0,notApplicable:0});
 plan.answers.liquidity.status='documented';plan.answers.access.status='needs_action';plan.answers.dependencies.status='not_applicable';
 const summary=planSummary(plan,config.questions);assert.equal(summary.reviewed,3);assert.equal(summary.open,3);assert.equal(summary.needsAction,1);
 assert.ok(!('riskScore' in summary));
});
test('plans validate dates, size, required answers, statuses and preserve raw user notes',()=>{
 const plan=emptyPlan(config.questions);plan.answers.access.note='<img src=x> & eigene Notiz';plan.reviewDate='2026-10-28';plan.action='Vertretung praktisch prüfen';
 assert.equal(validatePlan(plan,config.questions).answers.access.note,plan.answers.access.note);
 for(const change of [p=>p.reviewDate='2026-02-30',p=>p.owner='x'.repeat(81),p=>delete p.answers.access,p=>p.answers.extra={status:'unreviewed',note:''},p=>p.answers.access.status='safe',p=>p.answers.access.note='x'.repeat(501),p=>p.schemaVersion=2]){
  const bad=structuredClone(plan);change(bad);assert.throws(()=>validatePlan(bad,config.questions));
 }
});
test('consultation report preserves sources and chosen action without recommendations',()=>{
 const plan=emptyPlan(config.questions);plan.action='Zugriff testen';plan.owner='Beratung';plan.reviewDate='2026-11-15';plan.answers.access.status='needs_action';plan.answers.access.note='Vertretung ungeprüft';
 const report=planningReport(plan,config.questions,{partner:'Partner',generatedAt:'2026-10-28'});
 for(const s of ['Zugriff testen','2026-11-15','Beratung','Vertretung ungeprüft','Goldverbote','kein gemessener Risikoscore'])assert.ok(report.includes(s));
});
test('planning questions bundled identically for all native and web clients',async()=>{
 const canonical=await readFile(new URL('../shared/planning.json',import.meta.url),'utf8');
 assert.equal(config.questions.length,5);assert.equal(new Set(config.questions.map(q=>q.id)).size,5);
 for(const dir of ['web/assets','android/app/src/main/assets','ios/CRISIS/Resources'])assert.equal(await readFile(new URL(`../${dir}/planning.json`,import.meta.url),'utf8'),canonical);
});
