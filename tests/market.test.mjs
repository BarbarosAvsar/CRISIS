import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {marketService, validateQuote} from '../tools/market-service.mjs';

const history=JSON.parse(await readFile(new URL('../shared/market-data.json',import.meta.url)));
const time=Date.parse('2026-10-28T12:00:00Z');
const quote=symbol=>({symbol,currency:'USD',price:symbol==='XAU'?4000:50,updatedAt:new Date(time).toISOString()});
test('real source series have provenance, actual observations and matching units',()=>{
 assert.equal(history.kind,'import'); assert.equal(history.asOf,'2024-12-31');
 assert.deepEqual(history.series.map(s=>s.id),['gold','silver']);
 assert.equal(history.series[0].points[0].year,1960);
 assert.equal(history.series[0].points.length,65); assert.equal(history.cpi.length,65);
 assert.equal(history.macro.length,5);
 assert.ok(history.metadata.sources.every(s=>/^https:/.test(s.url)&&/^[a-f0-9]{64}$/.test(s.sha256)));
 assert.equal(history.metadata.licenseUrl,'https://data.worldbank.org/summary-terms-of-use');
});
test('live adapter preserves annual history and separates provider timestamps',async()=>{
 let calls=0;
 const service=marketService({loadHistory:async()=>history,fetchJson:async url=>{calls++;return quote(url.split('/').at(-1));},now:()=>time});
 const first=await service();assert.equal(calls,2);assert.deepEqual(first.data,history);
 assert.equal(first.provenance.quotes[0].asOf,'2026-10-28T12:00:00.000Z');
 assert.equal(first.provenance.cached,false);assert.equal((await service()).provenance.cached,true);assert.equal(calls,2);
});
test('partial failure is visible; all-source failure without cache rejects',async()=>{
 const partial=marketService({loadHistory:async()=>history,now:()=>time,fetchJson:async url=>{if(url.endsWith('XAG'))throw Error('HTTP 403');return quote('XAU');}});
 const result=await partial();assert.equal(result.provenance.stale,true);assert.match(result.provenance.quotes[1].error,/403/);assert.equal(result.provenance.quotes[1].price,null);
 await assert.rejects(marketService({loadHistory:async()=>history,fetchJson:async()=>{throw Error('offline');}})(),/nicht erreichbar/);
});
test('failed refresh returns last known response explicitly stale',async()=>{
 let now=time,offline=false;
 const service=marketService({loadHistory:async()=>history,now:()=>now,ttl:1000,fetchJson:async url=>{if(offline)throw Error('offline');return quote(url.split('/').at(-1));}});
 await service();offline=true;now+=2000;
 const old=await service();assert.equal(old.provenance.stale,true);assert.equal(old.provenance.cached,true);
 assert.equal(old.provenance.fetchedAt,new Date(time).toISOString());
});
test('quote validation rejects wrong symbols/currencies, zero and future observations',()=>{
 for(const bad of [{...quote('XAU'),price:0},{...quote('XAU'),currency:'EUR'},{...quote('XAG')},{...quote('XAU'),updatedAt:'broken'},{...quote('XAU'),updatedAt:'2027-01-01T00:00:00Z'}])assert.throws(()=>validateQuote(bad,'XAU',time));
 assert.equal(validateQuote({...quote('XAU'),updatedAt:'2026-10-27T00:00:00Z'},'XAU',time).stale,true);
});
