package berlin.aia.crisis

import org.json.JSONObject
import java.net.URI
import javax.net.ssl.HttpsURLConnection

data class LiveDataReply(val data: MarketData, val json: String, val provenance: JSONObject?)

/** Explicit user-selected HTTPS adapter. No credentials, redirects or relaxed TLS. */
object LiveDataClient {
 fun parseStored(text: String): LiveDataReply {
  val objectValue=JSONObject(text)
  if(!objectValue.has("data"))return LiveDataReply(CrisisEngine.parse(text),text,null)
  return parseReply(text)
 }
 fun endpoint(text: String): URI {
  val uri=URI(text.trim())
  require(uri.scheme=="https" && !uri.host.isNullOrBlank() && uri.rawUserInfo==null && uri.rawQuery==null && uri.rawFragment==null) {
   "HTTPS-Adresse ohne Zugangsdaten, Parameter oder Fragment erforderlich."
  }
  return uri
 }
 fun parseReply(text: String): LiveDataReply {
  require(text.toByteArray(Charsets.UTF_8).size<=2*1024*1024) {"Maximal 2 MB erlaubt."}
  val reply=JSONObject(text);val raw=reply.getJSONObject("data").toString();val parsed=CrisisEngine.parse(raw)
  require(parsed.kind=="import") {"Der Datenserver muss echte Daten als kind import kennzeichnen."}
  val provenance=reply.optJSONObject("provenance")
  val safe=provenance?.let { p ->
   val result=JSONObject()
   for(key in listOf("fetchedAt","provider","notes"))if(p.opt(key) is String)result.put(key,p.getString(key).take(1000))
   result.put("stale",p.optBoolean("stale",true));result.put("cached",p.optBoolean("cached",false))
   val quotes=p.optJSONArray("quotes");val safeQuotes=org.json.JSONArray()
   if(quotes!=null)for(i in 0 until minOf(quotes.length(),30)){
    val q=quotes.optJSONObject(i) ?: continue
    val next=JSONObject()
    for(key in listOf("symbol","name","currency","unit","asOf","error","provider"))if(q.opt(key) is String)next.put(key,q.getString(key).take(500))
    if(q.opt("price") is Number){val price=q.getDouble("price");require(price.isFinite() && price>0 && price<=1e15){"Ungültiger aktueller Kurs."};next.put("price",price)}
    next.put("stale",q.optBoolean("stale",true));safeQuotes.put(next)
   }
   result.put("quotes",safeQuotes);result
  }
  val stored=JSONObject().put("data",JSONObject(raw));if(safe!=null)stored.put("provenance",safe)
  return LiveDataReply(parsed,stored.toString(),safe)
 }
 fun fetch(url: String): LiveDataReply {
  val connection=endpoint(url).toURL().openConnection() as HttpsURLConnection
  connection.instanceFollowRedirects=false;connection.connectTimeout=15_000;connection.readTimeout=15_000
  connection.setRequestProperty("Accept","application/json")
  try {
   require(connection.responseCode==200) {"Datenserver antwortet mit HTTP ${connection.responseCode}."}
   require(connection.contentType?.substringBefore(';')?.trim()=="application/json") {"Der Datenserver liefert kein JSON."}
   require(connection.contentLengthLong<=2*1024*1024) {"Maximal 2 MB erlaubt."}
   val text=connection.inputStream.use {stream->
    val out=java.io.ByteArrayOutputStream();val buffer=ByteArray(8192);var n=stream.read(buffer)
    while(n!=-1){require(out.size()+n<=2*1024*1024){"Maximal 2 MB erlaubt."};out.write(buffer,0,n);n=stream.read(buffer)}
    out.toString("UTF-8")
   }
   return parseReply(text)
  } finally {connection.disconnect()}
 }
}
