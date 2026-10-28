import http from 'node:http';
import {readFile, realpath} from 'node:fs/promises';
import path from 'node:path';
import {marketService} from './market-service.mjs';
const root=path.resolve(import.meta.dirname,'../web');
const mime={'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript','.json':'application/json','.png':'image/png','.pdf':'application/pdf'};
const live=marketService();
const headers={'X-Content-Type-Options':'nosniff','Content-Security-Policy':"default-src 'self'; style-src 'self'; img-src 'self' data:; object-src 'none'; base-uri 'self'; frame-ancestors 'none'"};
const server=http.createServer(async(req,res)=>{
  if(!['GET','HEAD'].includes(req.method)){res.writeHead(405,{...headers,Allow:'GET, HEAD'});res.end();return;}
  try{
    const p=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
    if(p==='/api/data'){
      try{const body=JSON.stringify(await live());res.writeHead(200,{...headers,'Content-Type':'application/json','Cache-Control':'no-store'});res.end(req.method==='HEAD'?undefined:body);}
      catch(error){res.writeHead(503,{...headers,'Content-Type':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify({error:error.message}));}return;
    }
    const f=await realpath(path.resolve(root,'.'+(p==='/'?'/index.html':p)));
    if(!f.startsWith(root+path.sep))throw Error();
    const body=await readFile(f);res.writeHead(200,{...headers,'Content-Type':mime[path.extname(f)]||'application/octet-stream'});res.end(req.method==='HEAD'?undefined:body);
  }catch{res.writeHead(404,headers);res.end('Nicht gefunden');}
});
server.on('error',error=>{console.error(error.code==='EADDRINUSE'?'Port belegt. Bestehenden Server verwenden oder PORT ändern.':error.message);process.exitCode=1;});
server.listen(Number(process.env.PORT||4173),process.env.HOST||'127.0.0.1',()=>console.log('CRISIS server ready · http://127.0.0.1:'+server.address().port));
