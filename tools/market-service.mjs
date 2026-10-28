import https from 'node:https';
import {readFile} from 'node:fs/promises';
import {validateData} from '../web/core.js';

const PROVIDER = 'https://api.gold-api.com/price/';
export async function providerJson(url, {timeout = 12000, maxBytes = 65536} = {}) {
  const proxy = process.env.HTTPS_PROXY || process.env.https_proxy;
  const agent = proxy ? new (await import('https-proxy-agent')).HttpsProxyAgent(proxy) : undefined;
  return new Promise((resolve, reject) => {
    const req = https.get(url, {agent, headers: {'Accept':'application/json','User-Agent':'CRISIS/1.1'}}, res => {
      if (res.statusCode !== 200) {res.resume(); reject(new Error(`Anbieter antwortet mit HTTP ${res.statusCode}`)); return;}
      let size = 0; const chunks = [];
      res.on('data', chunk => {size += chunk.length; if (size > maxBytes) res.destroy(new Error('Antwort überschreitet das Größenlimit')); else chunks.push(chunk);});
      res.on('error', reject);
      res.on('end', () => {try {resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));} catch {reject(new Error('Ungültige JSON-Antwort des Anbieters'));}});
    });
    const timer = setTimeout(() => req.destroy(new Error('Zeitüberschreitung beim Datenanbieter')), timeout);
    req.on('close', () => clearTimeout(timer)); req.on('error', reject);
  });
}

export function validateQuote(raw, symbol, now = Date.now()) {
  if (!raw || raw.symbol !== symbol || raw.currency !== 'USD' || typeof raw.price !== 'number' ||
      !Number.isFinite(raw.price) || raw.price <= 0 || raw.price > 1e15 || typeof raw.updatedAt !== 'string' ||
      !Number.isFinite(Date.parse(raw.updatedAt)) || Date.parse(raw.updatedAt) > now + 5 * 60000)
    throw new Error('Ungültiger Kurs oder Zeitstempel des Anbieters');
  return {symbol, name:symbol === 'XAU' ? 'Gold' : 'Silber', price:raw.price,
    currency:'USD', unit:'USD/Feinunze', asOf:raw.updatedAt, error:null,
    stale:now - Date.parse(raw.updatedAt) > 3 * 3600000, provider:PROVIDER + symbol};
}

export function marketService({loadHistory = async () => JSON.parse(await readFile(new URL('../shared/market-data.json', import.meta.url))),
  fetchJson = providerJson, now = Date.now, ttl = 60000} = {}) {
  let cached, expires = 0, pending;
  async function refresh() {
    const data = validateData(await loadHistory());
    if (data.kind !== 'import') throw new Error('Echter historischer Datensatz fehlt');
    const results = await Promise.allSettled(['XAU','XAG'].map(async symbol => validateQuote(await fetchJson(PROVIDER + symbol), symbol, now())));
    const quotes = results.map((r, i) => r.status === 'fulfilled' ? r.value :
      {symbol:i === 0 ? 'XAU' : 'XAG', name:i === 0 ? 'Gold' : 'Silber', price:null,
        currency:'USD', unit:'USD/Feinunze', asOf:null, stale:true,
        error:r.reason.message || 'Anbieter nicht erreichbar', provider:PROVIDER + (i === 0 ? 'XAU' : 'XAG')});
    const provenance = {fetchedAt:new Date(now()).toISOString(), provider:'Weltbank (Jahresreihen) · Gold API (indikative aktuelle Kurse)',
      cached:false, stale:quotes.some(q => q.stale), quotes,
      notes:`Historische Jahresmittel bis ${data.asOf}; aktuelle Einzelkurse werden nicht in die Jahresreihen gemischt. Nicht alle Börsen- und Immobilienmärkte abgedeckt.`};
    if (quotes.every(q => q.error)) throw new Error('Aktuelle Kurse derzeit nicht erreichbar. Historische Daten bleiben separat verfügbar.');
    cached = {data, provenance}; expires = now() + ttl; return structuredClone(cached);
  }
  return async function () {
    if (cached && now() < expires) return {...structuredClone(cached), provenance:{...structuredClone(cached.provenance), cached:true}};
    if (!pending) pending = refresh().catch(error => {
      if (!cached) throw error;
      return {...structuredClone(cached), provenance:{...structuredClone(cached.provenance), cached:true, stale:true,
        notes:`Letzter erfolgreicher Abruf: ${cached.provenance.fetchedAt}. ${error.message}`}};
    }).finally(() => {pending = null;});
    return pending;
  };
}
