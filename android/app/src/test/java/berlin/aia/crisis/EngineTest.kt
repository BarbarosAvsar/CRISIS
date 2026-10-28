package berlin.aia.crisis
import org.junit.Test
import org.junit.Assert.*
import java.io.File
class EngineTest {
 private fun fixture(name:String)=File(System.getProperty("crisis.shared"),name).readText()
 @Test fun documentedCycles(){val c=CrisisEngine.content(fixture("content.json"));assertEquals(listOf(1911,1927,1945,1965,1981,1999,2019),CrisisEngine.years(c.cycles[0],1911,2019));assertEquals(listOf(1918,1926,1935,1945,1953,1962,1972,1980,1989,1999,2007,2016,2026),CrisisEngine.years(c.cycles[1],1918,2026));assertEquals(listOf(1924,1931,1942,1951,1958,1969,1978,1985,1996,2005,2012,2023,2032),CrisisEngine.years(c.cycles[2],1924,2032));assertEquals(6,c.documents.size)}
 @Test fun bundledDataAndNormalization(){val d=CrisisEngine.parse(fixture("demo-data.json"));assertEquals(10,d.series.size);val ss=CrisisEngine.compare(d,setOf("gold","dax"),1926,2026,false);assertEquals(100.0,ss.first().points.first().value,1e-9);val real=CrisisEngine.compare(d,setOf("gold"),1926,2026,true);assertTrue(real.first().points.last().value<ss.first().points.last().value);assertNotNull(CrisisEngine.ratio(d));assertTrue(CrisisEngine.csv(ss).contains("Asset;Jahr;Index"))}
 @Test fun goldenCpi(){val d=CrisisEngine.parse(fixture("golden-data.json"));val ss=CrisisEngine.compare(d,setOf("gold","silver"),2020,2022,true);assertEquals(165.28925619834712,ss.first().points.last().value,1e-9);assertEquals(2,ss.first().points.size);assertEquals(5.0,CrisisEngine.ratio(d)!!.value,1e-9)}
 @Test fun rejectsInvalid(){val text=fixture("demo-data.json");assertThrows(IllegalArgumentException::class.java){CrisisEngine.parse(text.replaceFirst("\"value\": 20.0","\"value\": 0.0"))};val d=CrisisEngine.parse(text);assertThrows(IllegalArgumentException::class.java){CrisisEngine.compare(d,emptySet(),1926,2026,false)};assertThrows(IllegalArgumentException::class.java){CrisisEngine.compare(d,setOf("gold"),2026,1926,true)}}
 @Test fun csvEscaping(){assertEquals("\"'=HYPERLINK(\"\"unsafe\"\")\"",CrisisEngine.csvLabel("=HYPERLINK(\"unsafe\")"))}
 @Test fun strictNumericAndCalendarValidation(){val text=fixture("demo-data.json");assertThrows(IllegalArgumentException::class.java){CrisisEngine.parse(text.replaceFirst("\"value\": 20.0","\"value\": \"20\""))};assertThrows(java.time.format.DateTimeParseException::class.java){CrisisEngine.parse(text.replace("2026-01-01","2026-02-30"))}}
 @Test fun rejectsUnrepresentableCalculatedValues(){
  val d=CrisisEngine.parse(fixture("golden-data.json"))
  val extreme=d.copy(series=d.series.map {s->s.copy(points=s.points.mapIndexed {i,p->p.copy(value=if(i==0)Double.MIN_VALUE else 1e15)})})
  assertThrows(IllegalArgumentException::class.java){CrisisEngine.compare(extreme,setOf("gold"),2020,2022,false)}
  val ratio=d.copy(series=d.series.map {s->if(s.id=="silver")s.copy(points=s.points.map {it.copy(value=Double.MIN_VALUE)})else s})
  assertNull(CrisisEngine.ratio(ratio))
 }
}
