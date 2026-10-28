export function cycleYears(cycle, from=1926, to=2126) {
  if(!Number.isInteger(from)||!Number.isInteger(to)||from<1800||to>2200||from>to) throw Error('Jahresbereich 1800–2200 erforderlich.');
  const out=[];let y=cycle.start,i=0;
  while(y<=to){if(y>=from)out.push(y);y+=cycle.steps[i++%cycle.steps.length]}return out;
}
export function validateData(d){
  const fail=m=>{throw Error(m)};
  if(d?.schemaVersion!==1||!['demo','import'].includes(d.kind))fail('schemaVersion 1 und kind demo/import erforderlich.');
  if(!/^\d{4}-\d{2}-\d{2}$/.test(d.asOf)||Number.isNaN(Date.parse(d.asOf))||new Date(d.asOf).toISOString().slice(0,10)!==d.asOf)fail('Datenstand als ISO-Datum erforderlich.');
  for(const k of ['source','cpiRegion'])if(typeof d[k]!=='string'||!d[k].trim()||d[k].length>500)fail(k+' fehlt oder ist zu lang.');
  function points(p,label){if(!Array.isArray(p)||!p.length||p.length>401)fail(label+': 1–401 Werte erforderlich.');let prev=0;for(const v of p){if(!Number.isInteger(v.year)||v.year<1800||v.year>2200||v.year<=prev||typeof v.value!=='number'||!Number.isFinite(v.value)||v.value<=0||v.value>1e15)fail(label+': sortierte eindeutige Jahre und positive endliche Werte erforderlich.');prev=v.year}}
  points(d.cpi,'CPI');if(!Array.isArray(d.series)||!d.series.length||d.series.length>30)fail('1–30 Datenreihen erforderlich.');
  const ids=new Set();for(const s of d.series){if(!/^[a-z][a-z0-9-]{0,39}$/.test(s.id)||ids.has(s.id))fail('Ungültige oder doppelte Reihen-ID.');ids.add(s.id);for(const k of ['name','group','unit','currency'])if(typeof s[k]!=='string'||!s[k].trim()||s[k].length>100)fail('Ungültiges Feld: '+k);points(s.points,s.id)}
  if(!Array.isArray(d.macro)||d.macro.length>20)fail('macro muss eine Liste sein.');
  for(const m of d.macro){if(typeof m.country!=='string'||!m.country.trim()||m.country.length>100)fail('Land fehlt.');for(const k of ['inflation','military','gdp'])if(m[k]!==null&&(typeof m[k]!=='number'||!Number.isFinite(m[k])||Math.abs(m[k])>1e15||k!=='inflation'&&m[k]<0))fail('Ungültiger Makrowert.');}
  return d;
}
export function compare(data,ids,from,to,real=false){
  const series=ids.map(id=>data.series.find(s=>s.id===id)).filter(Boolean);
  if(!series.length)throw Error('Mindestens eine Datenreihe auswählen.');
  const cpi=new Map(data.cpi.map(p=>[p.year,p.value]));
  const common=series[0].points.map(p=>p.year).filter(y=>y>=from&&y<=to&&series.every(s=>s.points.some(p=>p.year===y))&&(!real||cpi.has(y)));
  if(common.length<2)throw Error('Mindestens zwei gemeinsame Jahreswerte erforderlich (bei realer Darstellung mit CPI).');
  const base=common[0];return series.map(s=>{const map=new Map(s.points.map(p=>[p.year,p.value]));return {...s,points:common.map(year=>({year,value:map.get(year)/map.get(base)*100*(real?cpi.get(base)/cpi.get(year):1)}))}});
}
export function ratio(data){const a=data.series.find(s=>s.id==='gold'),b=data.series.find(s=>s.id==='silver');if(!a||!b||a.currency!==b.currency||a.unit!==b.unit)return null;for(const p of [...a.points].reverse()){const q=b.points.find(q=>q.year===p.year);if(q)return {year:p.year,value:p.value/q.value}}return null}
export function csvLabel(name){const safe=/^[\s]*[=+\-@]|^[\t\r\n]/.test(name)?"'"+name:name;return '"'+safe.replaceAll('"','""')+'"'}
export function csv(series){return 'Asset;Jahr;Index\n'+series.flatMap(s=>s.points.map(p=>`${csvLabel(s.name)};${p.year};${p.value.toFixed(4)}`)).join('\n')+'\n'}
