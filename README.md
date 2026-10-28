# CRISIS ©

Deutschsprachige Website sowie eigenständige native Android- und iOS-Anwendungen für Marktvergleiche, Zyklusmodelle und die bereitgestellten CRISIS-Unterlagen. Keine WebViews, kein Cross-Plattform-Framework. JavaScript, Kotlin und Swift implementieren die Rechenlogik unabhängig; versionierte JSON-Inhalte und Referenzfälle sichern die Konsistenz.

**Datenstatus:** Neue Installationen starten mit echten Weltbank-Jahresdaten für Gold und Silber von 1960 bis 2024, US-CPI und Makroindikatoren für die fünf dokumentierten Länder. Quelle, Berichtsjahr und Lizenz stehen im Datensatz. Aktuelle Gold-/Silber-Einzelkurse können über den Node-Server ausdrücklich abgerufen werden; Verfügbarkeit und Anbieterzeitstempel sind sichtbar. Börsen- und Immobilienkurse sind damit weiterhin nicht abgedeckt. Synthetische Beispieldaten bleiben als gesonderter Demonstrationsmodus verfügbar. Eine validierte Kurs- oder Krisenprognose wird nicht behauptet.

Unter Windows das gesamte GitHub-ZIP entpacken und **START-WEB.cmd** doppelklicken. Vorhandenes Python 3.8+ oder Node.js 22+ genügt; Administratorrechte und `npm ci` sind für die historische Website nicht nötig. Der Starter verwendet seinen eigenen Ordner. Für aktuelle Kurse benötigt der Node-Adapter seine Abhängigkeiten (`npm ci --ignore-scripts`) und Internetzugang. Alternativ mit vorhandenem Python aus dem Projektordner `python tools/start-web.py` ausführen. Der lokale Server ist unter `http://127.0.0.1:4173` erreichbar.

## Starten

### Website

Node.js 22 oder neuer:

```sh
cd /workspace/CRISIS
npm ci --ignore-scripts
npm start
```

Der Server lauscht auf Port 4173; `PORT` überschreibt ihn. HTML/CSS/JavaScript und Assets unter `web/` können auch mit einem statischen HTTP-Host ausgeliefert werden. Ein direktes Öffnen über `file:` unterstützt das Laden der JSON-Dateien nicht. Keine Serverdatenbank und keine API-Schlüssel erforderlich.

```sh
npm test
npm run test:browser  # laufender Server; Chromium erforderlich
```

### Android

Android Studio, JDK 17–21, Android SDK 35; Mindestversion Android 8/API 26. `android/` als Projekt öffnen oder:

```sh
cd /workspace/CRISIS
./tools/android.sh :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
```

Das Hilfsskript nutzt den Gradle Wrapper und übernimmt den bereitgestellten HTTP(S)-Proxy für Java. Für andere Maschinen `ANDROID_HOME` setzen oder `android/local.properties` mit `sdk.dir` anlegen. Das Debug-APK liegt unter `android/app/build/outputs/apk/debug/app-debug.apk`. Installation: `adb install -r <APK>`. Für den optionalen Abruf vom eigenen HTTPS-Datenadapter besitzt die App Internetzugriff; ohne eingetragene Datenquelle bleibt der Betrieb lokal.

### iOS

macOS mit Xcode 16+, iOS 16+. `ios/CRISIS.xcodeproj` öffnen, gemeinsames Schema **CRISIS** wählen und im iPhone-/iPad-Simulator starten. Keine Paketabhängigkeiten. Für ein physisches Gerät das eigene Signing-Team setzen. App und XCTest-Target sind im Projekt enthalten.

```sh
cd /workspace/CRISIS/ios
xcodebuild -project CRISIS.xcodeproj -scheme CRISIS \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project CRISIS.xcodeproj -scheme CRISIS \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Den Simulatornamen gegebenenfalls mit `xcrun simctl list devices available` ermitteln. Alternativ führt `./tools/test-ios.sh` aus dem Projektordner Build, Unit- und UI-Tests im Simulator aus und erhält das `.xcresult`. Native macOS-/Simulatornachweise stehen in `docs/TESTS.md`; die lokale Linux-Maschine selbst kann Xcode nicht ausführen.

## Funktionen auf allen Plattformen

- Übersicht mit vier Wirkungsräumen aus dem Dossier, Gold-Silber-Ratio und Makrolage für Deutschland, Spanien, USA, Frankreich und Großbritannien.
- Mehrfachvergleich von Gold, Silber, DAX, Dow Jones, LSEG.L und Immobilienpreisen für Berlin, Mallorca/Palma, Paris, London und New York; beliebige weitere importierte Reihen.
- Jahresfilter, gemeinsame Basis 100, nominale oder CPI-bereinigte Entwicklung, Diagramm, textliche Ergebnisse und CSV-Export.
- Drei exakt rekonstruierte Jahresfolgen, Jahresprüfung und Szenariofortschreibung bis 2126.
- Suche und vollständige Lesefassungen aller sechs PDFs sowie 25 dokumentierte Quellenlinks. Die Website bietet zusätzlich Original-PDFs; die Apps lesen die vollständigen extrahierten Texte offline.
- Lokaler, geprüfter JSON-Import bis 2 MB, Beispieldatei-Export und Wiederherstellung; persistentes Beraterbranding mit Partnername und drei Akzentvarianten.
- Betreiberangaben aus dem Brandguide, lokale Datenschutzhinweise, keine Telemetrie und keine Konten.

## Struktur und Dokumentation

| Pfad | Inhalt |
| --- | --- |
| `web/` | Website ohne Framework, statischer Betrieb |
| `android/` | Kotlin, Compose Material 3, Canvas, Android-Dateiauswahl |
| `ios/` | SwiftUI, Swift Charts, native Datei- und Exportdialoge |
| `shared/` | Kanonische Inhalte, Beispiel- und Referenzdaten, JSON-Schema, 13 Original-EPS-Logos |
| `docs/ANALYSE.md` | Dokumentenanalyse, Entscheidungen und Anforderungszuordnung |
| `docs/DATEN.md` | Importvertrag, Berechnungen und Anbieterintegration |
| `docs/TESTS.md` | Tatsächliche Ergebnisse, Grenzen und native Abnahme |
| `tools/` | Lokaler Server und reproduzierbare Hilfsskripte |

`python3 tools/generate-content.py` synchronisiert die kanonischen Inhalte und Plattformbundles aus den archivierten PDF-Texten. `python3 tools/generate-xcode.py` erzeugt das eingecheckte Xcode-Projekt deterministisch. Änderungen an Plattformbundles direkt würden beim nächsten Synchronisieren überschrieben.

## Vor einer Veröffentlichung

Der historische Weltbank-Datensatz deckt Gold, Silber, US-CPI und Makroindikatoren ab; seine Quellen und CC-BY-4.0-Bedingungen einschließlich Weltbank-Zusätzen stehen in `shared/market-data.json`. Daten für Aktien und Immobilien sowie die kommerzielle Eignung eines aktuellen Kursanbieters benötigen zusätzliche Prüfung. Die Modellfortschreibung ist kein empirisch validiertes Frühwarnsystem. Betreiber- und Datenschutzangaben, Nutzungsrechte an internen Dossiers und White-Label-Freigaben müssen für den tatsächlichen Betrieb bestätigt werden. App-Store-Signing, Release-Härtung und Tests auf realen Geräten sind separate Release-Schritte. Die Anwendungen wurden nicht öffentlich bereitgestellt.
