import {chromium} from '@playwright/test';import assert from 'node:assert/strict';import path from 'node:path';import {fileURLToPath} from 'node:url';import {writeFile,mkdir} from 'node:fs/promises';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const browser=await chromium.launch({...(process.env.CRISIS_USE_PLAYWRIGHT_BROWSER?{}:{executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium'}),headless:true,args:['--no-sandbox']});
try{const page=await browser.newPage({viewport:{width:1440,height:1000}});const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
await page.goto('http://127.0.0.1:4173');await page.getByRole('heading',{name:'Erkennen, was 90% übersehen.'}).waitFor();
await mkdir(path.join(root,'docs/screenshots'),{recursive:true});await page.screenshot({path:path.join(root,'docs/screenshots/web-desktop.png'),fullPage:true});
await page.getByRole('link',{name:'Vergleich',exact:true}).click();await page.locator('svg').waitFor();await page.locator('#real').check();assert.match(await page.locator('#chart-result').innerText(),/Real/);
for(const id of await page.locator('[name=asset]:checked').evaluateAll(es=>es.map(e=>e.value)))await page.locator(`[name=asset][value=${id}]`).uncheck();await page.getByRole('alert').waitFor();await page.locator('[name=asset][value=gold]').check();await page.locator('[name=asset][value=silver]').check();
const download=page.waitForEvent('download');await page.getByRole('button',{name:'CSV exportieren'}).click();assert.equal((await download).suggestedFilename(),'crisis-vergleich.csv');
await page.getByRole('link',{name:'Zyklen',exact:true}).click();await page.locator('#focus-year').fill('2032');assert.match(await page.locator('#year-result').innerText(),/Niedrige Preise/);
await page.getByRole('link',{name:'Wissen',exact:true}).click();await page.locator('#search').fill('unfindablexyz');assert.match(await page.locator('#documents').innerText(),/Keine passenden/);await page.locator('#search').fill('Goldverbote');assert.ok(await page.locator('#documents article').count()>0);
await page.getByRole('link',{name:'Einstellungen',exact:true}).click();await page.locator('#partner-name').fill('<img src=x onerror=alert(1)>');await page.getByRole('button',{name:'Branding speichern'}).click();await page.reload();assert.equal(await page.locator('#partner img').count(),0);assert.match(await page.locator('#partner').innerText(),/<img/);
await page.locator('#data-file').setInputFiles({name:'invalid.json',mimeType:'application/json',buffer:Buffer.from('{"bad":true}')});await page.getByRole('status').filter({hasText:'Import abgelehnt'}).waitFor();
await page.locator('#data-file').setInputFiles(path.join(root,'shared/demo-data.json'));await page.getByRole('status').filter({hasText:'Datensatz geprüft'}).waitFor();
await page.locator('#partner-name').fill('');await page.getByRole('button',{name:'Branding speichern'}).click();await page.getByRole('link',{name:'Übersicht',exact:true}).click();
await page.setViewportSize({width:390,height:844});await page.screenshot({path:path.join(root,'docs/screenshots/web-mobile.png'),fullPage:true});assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth));
await page.getByRole('link',{name:'Vergleich',exact:true}).click();assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth));
for(const link of ['Impressum','Datenschutz']){await page.getByRole('link',{name:link,exact:true}).click();await page.getByRole('heading',{name:link,exact:true}).waitFor()}
assert.deepEqual(errors,[]);console.log('Browser: desktop/mobile navigation, charts, CPI, validation, export, search, import, persistence, XSS escaping and legal views passed.');
}finally{await browser.close()}
