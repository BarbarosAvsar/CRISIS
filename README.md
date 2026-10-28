# CRISIS ©

Deutschsprachige Website sowie eigenständige native Android- und iOS-Anwendungen für Marktvergleiche, Zyklusmodelle und die bereitgestellten CRISIS-Unterlagen. Keine WebViews, kein Cross-Plattform-Framework. JavaScript, Kotlin und Swift implementieren die Rechenlogik unabhängig; versionierte JSON-Inhalte und Referenzfälle sichern die Konsistenz.

**Datenstatus:** Die PDFs liefern Quellenverweise, aber keine historischen Marktwerte, API-Verträge oder Zugangsdaten. Der mitgelieferte Datensatz ist vollständig synthetisch und überall als Beispiel gekennzeichnet. Es gibt keinen Live-Feed und keine validierte Kurs- oder Krisenprognose. Echte lizenzierte Daten lassen sich lokal als JSON importieren.

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

Das Hilfsskript nutzt den Gradle Wrapper und übernimmt den bereitgestellten HTTP(S)-Proxy für Java. Für andere Maschinen `ANDROID_HOME` setzen oder `android/local.properties` mit `sdk.dir` anlegen. Das Debug-APK liegt unter `android/app/build/outputs/apk/debug/app-debug.apk`. Installation: `adb install -r <APK>`. Die App benötigt keine Netzwerkberechtigung; Quellenlinks öffnet der Browser.

### iOS

macOS mit Xcode 16+, iOS 16+. `ios/CRISIS.xcodeproj` öffnen, gemeinsames Schema **CRISIS** wählen und im iPhone-/iPad-Simulator starten. Keine Paketabhängigkeiten. Für ein physisches Gerät das eigene Signing-Team setzen. App und XCTest-Target sind im Projekt enthalten.

```sh
cd /workspace/CRISIS/ios
xcodebuild -project CRISIS.xcodeproj -scheme CRISIS \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project CRISIS.xcodeproj -scheme CRISIS \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Den Simulatornamen gegebenenfalls mit `xcrun simctl list devices available` ermitteln. Ein iOS-Build und Simulatorlauf sind in der Linux-Cloud **nicht verifiziert**.

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

Lizenzierte historische und aktuelle Daten sowie deren Qualitätsnachweise fehlen weiterhin. Die Modellfortschreibung ist kein empirisch validiertes Frühwarnsystem. Betreiber- und Datenschutzangaben, Nutzungsrechte an internen Dossiers und White-Label-Freigaben müssen für den tatsächlichen Betrieb bestätigt werden. App-Store-Signing, Release-Härtung und Tests auf realen Geräten sind separate Release-Schritte. Die Anwendungen wurden nicht öffentlich bereitgestellt.
