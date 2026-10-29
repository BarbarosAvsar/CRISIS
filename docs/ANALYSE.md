# Dokumentenanalyse und Umsetzungsplan

Die aktuelle Produktdefinition und Abnahmekriterien stehen in [PRODUKT.md](PRODUKT.md). Die folgende Dokumentenanalyse hält die Herkunft der Ziele fest und wird nicht als zusätzliches, widersprechendes Leistungsversprechen verstanden.

Nachtrag: Die ursprünglichen PDF-Unterlagen enthalten selbst keine Kursreihen. Zusätzlich wurden inzwischen externe echte Weltbank-Reihen und ein öffentlicher HTTPS-Kursadapter integriert; Abdeckung, Zeitstände und Nutzungsbedingungen stehen in [MARKTDATEN.md](MARKTDATEN.md). Native Build- und Simulatorprüfungen werden nun über GitHub Actions durchgeführt. Der aktuelle Nachweis steht in [TESTS.md](TESTS.md).

Stand: 28. Oktober 2026. Alle sechs PDFs wurden vollständig mit `pdftotext -layout` extrahiert; Formel- und Farbdokument wurden zusätzlich visuell geprüft. Das ZIP enthält 13 EPS-Logos (vier Hintergrundvarianten, neun Plain-Varianten); macOS-Metadateien wurden ausgeschlossen. Das originale Midnight-Blue-Logo wird unverändert als Rasterableitung in allen Anwendungen verwendet. Alle EPS-Dateien bleiben unter `shared/logos/` erhalten.

Die Dokumente sind fachliches Ausgangsmaterial. Interne Formulierungen wie „Keine Weitergabe“ wurden als Inhalte erhalten; sie ersetzen nicht den Entwicklungsauftrag. Keine externen Nachrichten wurden versandt und keine Anwendung öffentlich bereitgestellt.

## Quellenbefund

| Dokument | Befund | Umsetzung / Grenze |
| --- | --- | --- |
| `crisis©_formel_definition.pdf` (1 Seite) | Ereignisse ab 1911: 16/18/20; Hochpreise ab 1918: 8/9/10; Tiefpreise ab 1924: 7/11/9 | Alle gezeigten Jahre durch wiederholte Addition reproduziert und getestet. „×“ im Layout ist mathematisch widersprüchlich; die Jahresfolgen sind maßgeblich. Keine Umdeutung zu belastbaren Handelssignalen. |
| `crisis_wirkungsjahr2026-geopolitische_und_marktstrategische_feldanalyse.pdf` (19 Seiten) | Leitessay; Cover als Systembild; vier Wirkungsräume; Spannungsachsen; Zyklen; Feldbeschreibung; Kapital/Struktur/Entscheidung; Grenzen; Nachwort | Vier redaktionell zusammengefasste Orientierungskarten und vollständige Lesefassung. Keine erfundenen Risikoscores. Der Text bezeichnet sich ausdrücklich als Orientierungsrahmen ohne konkrete Prognosen oder Handlungsanweisungen. |
| `crisis_brandguide.pdf` (4 Seiten) | Makro-Intelligenz, Vermögensschutz, 100 Jahre Daten und 100 Jahre Prognose, Asset-Vergleich, reale Werte, Frühindikatoren, White-Label | Kaufkraft, reale Vergleiche und Partnerbranding. Echte Gold-/Silber- und US-CPI-Reihen 1960–2024 sind der Standardbestand; synthetische Beispieldaten bleiben separat wählbar. Der mechanische Modellkalender bis 2126 ist keine empirisch validierte Prognose. |
| `crisis_goldverbote_whitepaper.pdf` (12 Seiten) | Monetäre Übergänge, staatlicher Zugriff, funktionale Verfügbarkeit, USA und Deutschland, Struktur und Zeit | Vollständige Offline-Lesefassung und Suchfunktion. Aussagen erscheinen als Position der Herausgeber. Keine Garantie, Gold oder bestimmte Vermögensstrukturen seien vor staatlichem Zugriff oder Wertverlust geschützt. |
| `crisis_daten_api.pdf` (2 Seiten) | Drei Edelmetallquellen; 14 Statista-Verweise (5 Inflation, 4 Rüstung, 5 BIP); drei Wertpapier- und fünf Immobilienverweise | 25 Quellen im Katalog. Kein API-Protokoll, keine Zugangsdaten, keine Frequenzen, keine Nutzungsrechte oder Rohdaten. Daher validierter Import statt fragiler Scraper. LSEG.L ist eine Einzelaktie und kein Londoner Marktindex. |
| `Farbcode RGB.pdf` (1 Seite) | Rose e8b9c8, Navy 0f1c3d, Teal c7e8e3; Logo, Home/Vergleich, Impressum/Datenschutz | Gemeinsame Farbwerte, Originalmarke, Navigation und Rechtliches. Dunklere Varianten von Rose/Teal ausschließlich für lesbare UI-Akzente. Keine Schriftfamilie spezifiziert: Systemschriften. |
| `crisis logos.zip` | 13 Vektorvarianten, keine Schriftdateien oder Nutzungsvereinbarung | Originalarchivinhalt ohne Metadaten erhalten; GS-Konvertierung des Midnight-Blue-EPS. Keine neu erfundene Bildmarke. |

## Ablauf und Architektur

1. Unterlagen inventarisieren, Texte und Vektoren sichern, Anforderungen und Widersprüche dokumentieren.
2. Gemeinsame versionierte Datenstruktur, Formeln, Grenzfälle und Referenzdatensatz definieren.
3. Responsive Vanilla-Website umsetzen, Kernrechnung und Browserinteraktionen prüfen.
4. Native Android- und iOS-Modelle und Oberflächen implementieren; Inhalte bytegleich bündeln.
5. Android kompilieren, JVM-Tests und Lint ausführen; Xcode-Projekt und XCTest-Suite bereitstellen; Plattformgrenzen offenlegen.
6. Betrieb, Import, Tests und verbleibende Release-Voraussetzungen dokumentieren.

Es gibt bewusst keine Backend-Abhängigkeit für den lokalen Funktionsumfang. Browser: ES-Module und localStorage. Android: ViewModel, Compose, lokale private JSON-Datei und SharedPreferences. iOS: ObservableObject, SwiftUI/Charts, Application Support und UserDefaults. Jede Plattform besitzt ihre eigene Rechenimplementierung. Keine WebViews, Flutter-, React-Native- oder Kotlin-Multiplatform-Laufzeit.

## Anforderungszuordnung

| Anforderung | Website | Android | iOS | Nachweis |
| --- | --- | --- | --- | --- |
| Marke, Palette, Partnerbranding | `style.css`, `app.js` | `MainActivity.kt` | `CrisisApp.swift` | Browser- und native Simulatorprüfungen; physische Abnahme offen |
| Nominal-/Realvergleich und Diagramm | `core.js`, `draw()` | `CrisisEngine.compare`, `Plot` | `CrisisEngine.compare`, Swift Charts | JS-, Kotlin- und Swift-Referenztests; siehe TESTS.md |
| Drei Zyklen und 100-Jahre-Szenario | `cycleYears` | `years` | `years` | Exakte PDF-Sequenzen und Randwerte als Tests |
| Historische Kursdaten / aktuelle Kurse | Weltbank-Bestand und HTTPS-Adapter | Bestand, Import, eigener HTTPS-Adapter | Bestand, Import, eigener HTTPS-Adapter | Echte Gold-/Silber- und CPI-Reihen, getrennte Einzelkurse; weitere Assetklassen offen |
| Gold-Silber-Ratio | `ratio` | `ratio` | `ratio` | Nur gemeinsame Jahre und gleiche Einheit/Währung |
| Makrolage fünf Länder | Übersicht | Übersicht | Übersicht | Fehlende Werte bleiben „Nicht verfügbar“ |
| Alle Dokumente und Suche | Wissen/PDFs/Text | Wissen/Text offline | Wissen/Text offline | Sechs Dokumente, vollständige Textseiten |
| CSV-Export | Browserdownload | CreateDocument | FileExporter | Browser geprüft; native Logiktests, Gerätefluss offen |
| Import/Fehler/Wiederherstellung | lokal | lokal | lokal | Validierung vor Austausch; 2-MB-Limit |
| Rechtliches | Footerseiten | Mehr | Mehr | Angaben aus Dokument; Publikationsprüfung offen |

## Nicht dokumentierte Produktentscheidungen

- Deutsch ist die einzige spezifizierte Sprache. Keine Benutzerverwaltung, Abos, Zahlungsabwicklung, Push-Nachrichten oder Cloud-Synchronisation wurden erfunden.
- White-Label bedeutet hier persistenter Partnername und Akzentwahl. Beliebiger Logoupload, Mandantenverwaltung und eigene Store-Bundles sind nicht spezifiziert.
- Die Jahresfenster 1926–2126 beziehen sich auf das dokumentierte Wirkungsjahr 2026, nicht auf ein stillschweigend jährlich veränderliches Modell.
- Reale Indizes nutzen einen ausdrücklich benannten CPI. Keine versteckte Währungsumrechnung und kein Total-Return-Versprechen.
- Ein öffentlicher HTTPS-Kursadapter ist implementiert. Weitere Assetklassen, verlässliche Datenversorgung und passende Nutzungsrechte bleiben externe Voraussetzungen; ein vollständiges datenbasiertes Produktions-Frühwarnsystem lässt sich aus diesen Unterlagen allein nicht herleiten.

Die nachfolgende Produktentwicklung ergänzt die Quellenziele um einen historischen Kaufkraftrechner, getrennte Inflationsannahmen und einen lokal gespeicherten Strukturcheck. Diese Werkzeuge unterstützen die im Dossier betonte Vorbereitung und Wiederprüfung eigener Entscheidungen. Eine individuelle Krisenwahrscheinlichkeit wird daraus nicht berechnet.
