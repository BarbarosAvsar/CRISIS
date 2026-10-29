# Verifikation

Prüfstand: 29. Oktober 2026. Alle drei Jobs des [GitHub-Nachtests](https://github.com/BarbarosAvsar/CRISIS/actions/runs/40834899046) für App-Commit `c8cd7a8d61138992e80abbdf1b37eadac5fbb629` sind erfolgreich. Es gibt nur den kanonischen Branch `main`. Cloud- und Store-Veröffentlichung wurden nicht ausgeführt.

| Prüfung | Ergebnis | Umfang / Nachweis |
| --- | --- | --- |
| Web-/Datenadaptertests | 26 bestanden | Historienbundles, Quellenmetadaten, Einzelkurse, Ausfälle, Kaufkraft, Deflation, Grenzwerte, Checklistenvalidierung und Bericht |
| Browser, Desktop/Mobil | Bestanden, auch im aktuellen GitHub-Webjob | 1440×1000 und 390×844; Navigation, Vergleich, Import/CSV, Kaufkraft, Szenario, lokales Speichern/Wiederherstellen, TXT-Export, beschädigte Checkliste und bestätigtes Löschen |
| Android Build, JVM, Lint | Lokal und in CI erfolgreich; 15 JVM-Tests bestanden | Native App und Test-APK kompiliert; Lint ohne Fehler. `verification/android-tests.xml` und `android-lint.xml` |
| Android native UI | Sieben Tests bestanden, keine übersprungen | Android-15-Emulator; Kaufkraft/Deflation/Neuanlage der Activity, Checklistenpersistenz, beschädigte Speicherung und bisherige Abläufe. `verification/android-ui-tests.xml` |
| iOS Build, XCTest, UI | Nativ kompiliert; 16 Unit- und sechs UI-Tests bestanden | Xcode 26.6; iPhone 17 Pro, iOS-Simulator 26.4.1. Kaufkraft und Checkliste lassen sich ohne Absturz öffnen; Speichern, Neustart und Löschen wurden ausgeführt. `verification/ios-ci-summary.txt` |
| Historische Daten | Echte Beobachtungen gebündelt | Gold/Silber und US-CPI 1960–2024; Makroindikatoren für fünf Länder. Quellen und Grenzen: [MARKTDATEN.md](MARKTDATEN.md) |
| Aktueller Feed | Echter Goldkurs am 28. Oktober geprüft; Silber zeitweise HTTP 403 | Zeitgestempelte Einzelkurse werden getrennt angezeigt; Ausfälle erzeugen keine erfundenen Ersatzkurse. Kein laufendes Verfügbarkeitsversprechen. |

Screenshots der aktuellen Website: [Übersicht](screenshots/web-desktop.png), [Mobil](screenshots/web-mobile.png), [Kaufkraft](screenshots/web-kaufkraft.png) und [Strukturcheck](screenshots/web-strukturcheck.png). Maschinenlesbarer Nachweis: [verification/results.json](verification/results.json). Die archivierten nativen XML-Berichte und die iOS-Zusammenfassung stammen aus diesem erfolgreichen Lauf. Frühere Prüfstände bleiben in der Git-Historie nachvollziehbar. Das aktuelle lokal gebaute Debug-APK liegt unter `artifacts/crisis-debug.apk`; seine Prüfsumme steht daneben in `SHA256SUMS`.

## Reproduktion

```sh
npm ci --ignore-scripts
npm test
npx playwright install chromium
# In einem zweiten Terminal den Server starten: npm start
npm run test:browser
./tools/android.sh :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
# Mit verbundenem Android-Gerät oder Emulator:
./tools/android.sh :app:connectedDebugAndroidTest
# Auf macOS mit Xcode und installiertem Simulator:
./tools/test-ios.sh
```

Der iOS-Runner bootet einen verfügbaren iPhone-Simulator, kompiliert die native App und führt beide XCTest-Targets aus. Das vollständige `.xcresult` bleibt als Workflow-Artefakt erhalten. Unter Linux meldet das Skript die fehlende Xcode-Unterstützung ausdrücklich mit Fehlerstatus; es zählt keinen übersprungenen Test als bestanden. Der optionale Linux-Parser `tools/check-swift-syntax.py` ersetzt weder Swift-Typprüfung noch Simulatorlauf.

Die reproduzierbaren Werkzeugversionen stehen in `package-lock.json`, Gradle Wrapper und Android-Builddateien. Gradle 8.13 meldet Hinweise zur späteren Gradle-9-Migration; Android-Lint weist auf neuere Abhängigkeiten hin. Diese Hinweise sind keine deaktivierten Prüfungen.

## Verbleibende Abnahme auf physischen Geräten

Physische iPhones und Android-Geräte sind nicht angeschlossen. Emulator-/Simulatorergebnisse belegen keine Prüfung auf echter Hardware. Vor öffentlicher Bereitstellung bleiben diese Abläufe manuell abzunehmen:

1. Navigation über Übersicht und Mehr, große Systemschrift, VoiceOver/TalkBack, schmale/weite Displays, Ausrichtung und Wiederaufnahme aus dem Hintergrund.
2. Historischer Gold-/Silbervergleich, CPI-Schalter, Jahresgrenzen und verständliche Fehler bei leerer Auswahl. Synthetische Aktien-/Immobilienbeispiele ausdrücklich nur im Demomodus prüfen.
3. Kaufkraft mit `shared/planning-vectors.json` vergleichen; eigene Inflation und Deflation testen. CPI-Region und Unterschied zwischen Preissteigerung und Kaufkraftverlust müssen erkennbar bleiben.
4. Strukturcheck bearbeiten, ausdrücklich speichern, App vollständig schließen und neu öffnen. Nächsten Schritt, Zuständigkeit und Datum prüfen. Löschdialog abbrechen und anschließend bestätigen.
5. CSV und persönliche TXT-Gesprächsnotiz über native Datei-/Teilen-Dialoge exportieren und in Zielanwendungen öffnen. Inhalte und deutsche Zeichen prüfen.
6. `shared/golden-data.json` importieren: 2020–2022 nominal 200, real 165,289256 und Ratio 5. Fehlerhafte oder mehr als 2 MiB große Dateien müssen den Bestand erhalten. Eine Marktdatenwiederherstellung darf die persönliche Checkliste nicht löschen.
7. Dokumentensuche, vollständige Offline-Lesefassungen, externe Quellen, Partnerbranding, Impressum und Datenschutz prüfen.

Aktien-/Immobilienfeeds, 100 Jahre echte Marktbeobachtungen und empirisch validierte Krisenprognosen sind weiterhin nicht durch die integrierten Quellen abgedeckt. Release-Signing, Store-Freigaben sowie Betreiber-, Datenschutz- und Nutzungsrechtsprüfung sind separate Voraussetzungen.
