# Verifikation

## Aktueller Nachtest

Prüfstand: 28. Oktober 2026. Die lokalen Prüfungen wurden durch echte GitHub-Runner ergänzt. Der App-Code ist auf `main`; es gibt keine zusätzlichen Entwicklungsbranches. Cloud- oder Store-Veröffentlichung wurde nicht ausgeführt.

| Prüfung | Ergebnis | Nachweis |
| --- | --- | --- |
| Web-/Datenadaptertests | 19 bestanden | `npm test`; echte Historienbundles, Quellenmetadaten, getrennte Einzelkurse, Cache, Ausfälle und Zahlenüberlauf |
| Browser, Desktop/Mobil | Bestanden, zusätzlich GitHub-Webjob erfolgreich | Historische Standarddaten, Import, Suche, CSV, Branding, Zustandswiederherstellung und sichtbarer HTTP-503-Fehler ohne Datenverlust |
| Android Build, JVM, Lint | Build erfolgreich; 9 JVM-Tests bestanden; Lint ohne Fehler | `docs/verification/android-tests.xml` und `android-lint.xml`; Hinweise auf neuere Abhängigkeiten bleiben sichtbar |
| Android native UI | 4 Tests auf Android-15-Emulator bestanden, keine übersprungen | `docs/verification/android-ui-tests.xml`; [GitHub-Lauf](https://github.com/BarbarosAvsar/CRISIS/actions/runs/40691889323) |
| iOS Build, XCTest, UI | Nativ kompiliert; 11 Unit- und 4 UI-Tests auf iPhone-17-Pro-Simulator bestanden | [Erfolgreicher GitHub-Lauf](https://github.com/BarbarosAvsar/CRISIS/actions/runs/40692250242), App-Commit `1699ff9`; Xcode 26.6, Simulator iOS 26.4.1 |
| Historische Daten | Echte Beobachtungen gebündelt | Gold/Silber 1960–2024, 65 US-CPI-Werte, Makroindikatoren für fünf Länder; siehe `MARKTDATEN.md` |
| Aktueller Feed | Echter Goldkurs samt Zeitstempel abgerufen; Silber antwortete zeitweise HTTP 403 | Getrennte Darstellung, kein Einmischen in Jahresreihen; anbieterseitige oder Cloud-Netzwerkausfälle werden angezeigt |

Physische iPhone-/Android-Geräte sind nicht angeschlossen. Emulator-/Simulatorergebnisse sind keine Prüfung auf echter Hardware. Native Datei- und Teilen-Dialoge, VoiceOver/TalkBack und eine vollständige Geräteabnahme bleiben manuell zu prüfen. Aktien-/Immobilienfeeds, 100 Jahre echte Marktdaten und empirisch validierte Krisenprognosen sind weiterhin nicht durch die integrierten Quellen abgedeckt.

Reproduktion: `npm test`, mit laufendem Server `npm run test:browser`, `./tools/android.sh :app:testDebugUnitTest :app:connectedDebugAndroidTest` mit verbundenem Android-Gerät/Emulator; auf macOS `./tools/test-ios.sh`. Der iOS-Runner bootet den Simulator, führt beide XCTest-Targets aus und erhält das `.xcresult`. Er meldet Linux ausdrücklich als nicht unterstützt, ohne einen übersprungenen Test als bestanden zu zählen.

## Archiv: Erstprüfung vor dem Nachtest

Die folgenden Angaben dokumentieren den ursprünglichen Stand vor Einbindung der echten Daten und vor Ausführung der nativen GitHub-Tests. Sie werden durch den aktuellen Nachtest oben ergänzt und sind keine aktuellen Bereitschaftsaussagen.

## Ausgeführt

| Prüfung | Ergebnis | Umfang |
| --- | --- | --- |
| `npm test` | 12 bestanden, 0 fehlgeschlagen, 0 übersprungen | Alle dokumentierten Zyklusjahre, CPI-Referenz, gemeinsame Jahre, fehlende Daten, Ratio, Importgrenzen, CSV-Quoting/Formelneutralisierung, Kalenderdatum, sechs Original-PDFs, 25 HTTPS-Quellen, identische Plattformbundles, geparstes Xcode-Projekt mit App-/Test-/Ressourcen-Targets |
| `npm run test:browser` | Bestanden | Chromium, 1440×1000 und 390×844; Navigation, CPI-Schalter, Diagramm, leere Auswahl, CSV-Download, Jahresprüfung 2032, Dokumentensuche, gültiger/ungültiger Import, lokale Brandingpersistenz, HTML-Escaping, Rechtliches, kein horizontaler Überlauf; keine JS-/Konsolenfehler |
| Android `:app:assembleDebug` | Erfolgreich | Native Kotlin-/Compose-Kompilierung, Ressourcen, DEX, Debug-Signing und APK-Paket |
| Android `:app:testDebugUnitTest` | 6 bestanden, 0 fehlgeschlagen, 0 übersprungen | PDF-Sequenzen, Daten-/Dokumentbundle, nominale/reale Normalisierung, gemeinsamer CPI-Referenzfall, Ratio/CSV, ungültige Auswahl, Numeric-String-Ablehnung, ungültiges Kalenderdatum, CSV-Formelneutralisierung |
| Android `:app:lintDebug` | Erfolgreich | Android-Lint; finale Details siehe archivierter XML-Bericht |
| Swift-Quelldateien | Syntax geparst | `Models.swift`, `CrisisApp.swift`, `EngineTests.swift` mit Tree-sitter Swift; **keine** Swift-Typprüfung |
| iOS-Projektdateien | Strukturell geparst | OpenStep-Projekt, gemeinsames Xcode-Schema, Datenschutzmanifest, App- und XCTest-Target; **kein** Xcode-Build |
| `tools/setup-cloud.sh` | Wiederholung erfolgreich | Vorhandenes JDK/SDK wiederverwendet, SDK-Voraussetzungen geprüft, `npm ci` wiederholt |
| `tools/android.sh` | Ausgeführt | Gradle Wrapper 8.13 mit offizieller SHA-256, lokales JDK, SDK, Java-Proxy und System-CA |

Screenshots: `docs/screenshots/web-desktop.png` und `docs/screenshots/web-mobile.png`. Native Buildberichte und das Debug-APK entstehen unter `android/app/build/`; ausgewählte Nachweise werden unter `docs/verification/` archiviert.

## Werkzeugkette

- Node.js 24.19.0; Projekt verlangt Node 22+; Playwright 1.56.1 mit vorhandenem Chromium.
- Temurin JDK 21.0.9+10, lokaler Download mit offizieller SHA-256 geprüft. Die vorinstallierte JRE enthielt keinen Compiler; ein Systempaket war ohne sudo nicht installierbar.
- Android CLI 11076708, anhand des offiziellen Repository-Checksums geprüft; SDK 35, Build Tools 35.0.0.
- Gradle 8.13 mit offizieller SHA-256, AGP 8.9.2, Kotlin/Compose-Plugin 2.1.20, Compose BOM 2025.04.01.
- Paket-, TLS- und Artefaktprüfung blieben aktiviert. Java verwendet die vorhandene Proxyroute und den System-Truststore einschließlich Session-CA.

Gradle meldet veraltete DSL-Funktionen im Hinblick auf Gradle 9. Der Wrapper ist auf die tatsächlich geprüfte Version 8.13 festgelegt. Ein optionaler Hinweis auf nicht entfernte Debugsymbole einer AndroidX-Bibliothek betrifft das Debugpaket. Keine Prüfungen oder Assertions wurden deaktiviert.

## Nicht ausgeführt

- **iOS-Kompilierung, sechs XCTest-Fälle, Simulator und Gerät:** Xcode, SwiftUI-SDK und Apple-Simulator sind unter Linux nicht verfügbar. Syntax- und Projektprüfung ersetzen diese Tests nicht. Die bereitgestellten XCTest-Fälle gelten als **ungetestet**, nicht bestanden.
- **Android-Geräteoberfläche:** Kein Gerät angeschlossen und kein `/dev/kvm` für einen hardwarebeschleunigten Emulator. Kompilierung und JVM-Domänentests belegen keine vollständig geprüften UI-Dateidialoge, TalkBack- oder Rotationsabläufe.
- **Live-Feed oder echte historische Ergebnisse:** Keine lizenzierten Datensätze/API-Verträge in den Unterlagen. Der Importmechanismus ist geprüft; Datenbeschaffung und empirische Modellgüte bleiben offen.
- **Store-Veröffentlichung, Release-Signing, Sicherheits-/Rechtsabnahme, öffentliche Bereitstellung:** Nicht beauftragt oder durchgeführt.
- **GitHub Actions:** Workflow für Web, Android und macOS/iOS angelegt, aber nicht hochgeladen oder ausgeführt. Er ist kein zusätzlicher Prüfnachweis.

## Native Abnahme auf Geräten

1. App starten; Originalmarke, Beispielhinweis und alle vier Wirkungsräume prüfen.
2. Vergleich Gold/Silber bzw. Gold/DAX wählen, Jahresgrenzen ändern, CPI umschalten. Startindex 100, Endwerte mit Referenzdatei vergleichen.
3. Alle Assets abwählen; verständlichen Fehler prüfen. Ungültigen Jahresbereich testen.
4. CSV über den nativen Dateidialog speichern und in Tabellenkalkulation öffnen.
5. `shared/golden-data.json` importieren. Für 2020–2022: nominal 200, real 165,289256 und Ratio 5. App schließen/starten; Import muss erhalten bleiben.
6. Fehlerhafte JSON-Datei und Datei größer 2 MiB wählen; Bestand muss erhalten bleiben. Beispieldaten wiederherstellen.
7. Jahr 2026 und 2032 im Zyklusmodell prüfen. Keine garantierten Kauf-/Verkaufssignale behaupten.
8. Alle sechs Dokumente öffnen, nach „Goldverbote“ suchen, lange Dokumente bis zum Ende lesen; externe Quellen bewusst öffnen.
9. Partnername/Farbe ändern, App neu starten und Persistenz prüfen; Impressum/Datenschutz lesen.
10. Große Systemschrift, VoiceOver/TalkBack, schmale/weite Displays, Geräteausrichtung sowie App-Hintergrund/Wiederaufnahme testen. Diese UX-Abnahme bleibt vor Veröffentlichung erforderlich.

Xcode-Befehle stehen in der README. Optionaler Linux-Syntaxcheck:

```sh
python3 -m pip install --target /tmp/crisis-swift-parser tree-sitter==0.25.2 tree-sitter-swift==0.0.1
PYTHONPATH=/tmp/crisis-swift-parser python3 tools/check-swift-syntax.py
```
