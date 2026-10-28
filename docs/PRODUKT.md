# CRISIS: Zweck und Produktanforderungen

Diese Produktdefinition ersetzt die frühere Ableitung einer vorwiegend informierenden Startseite. Sie trennt belegte Ziele, daraus entwickelte Werkzeuge und weiterhin fehlende Datenvoraussetzungen. Die Originalunterlagen bleiben als Quellen unverändert erhalten.

## Wofür CRISIS gedacht ist

CRISIS ist ein Orientierungs- und Beratungsarbeitsplatz für Kaufkrafterhalt und handlungsfähige Vermögensstrukturen. Anleger und Berater sollen erkennen, was die verfügbaren Daten aussagen, wie Inflation einen unveränderten Geldbetrag verändert und welche strukturellen Fragen sie vor einer Entscheidung klären müssen. Das Werkzeug trifft keine individuelle Anlageentscheidung.

Der Zweck ist aus den sechs Unterlagen hinreichend bestimmbar. Eine Suche in E-Mails ist dafür nicht erforderlich; es wurden keine E-Mail-Inhalte gelesen oder Nachrichten verschickt.

| Beleg | Produktziel | Umgesetzte Ableitung |
| --- | --- | --- |
| Brandguide S. 2–3 | Kaufkraftverlust verstehen, reale Asset-Vergleiche, weniger emotionale Entscheidungen | Kaufkraftrechner, Vergleich und direkter Werkzeugeinstieg |
| Wirkungsjahr 2026 S. 2–3 | Liquidität, Zugang, Flexibilität; Orientierung statt Ereignisvorhersage | Arbeitsübersicht mit tatsächlicher Datenabdeckung und klaren nächsten Schritten |
| Wirkungsjahr S. 14, VI 6.2–6.3 | Abhängigkeiten, Redundanz, Zuständigkeit und Reversibilität | Qualitativer Strukturcheck mit eigenen Notizen und nächstem Prüfschritt |
| Wirkungsjahr S. 16, VII | Zugangsautonomie und laufende Rekalibrierung | Verantwortlichkeit und Termin zur Wiederprüfung |
| Goldverbote S. 7, 10–11 | Wert, Eigentum und tatsächliche Verfügbarkeit unterscheiden | Eigene Prüfung der praktischen Zugriffswege, ohne Schutzgarantie |
| Brandguide S. 2, White-Label | Beratung und Verständlichkeit | Lokal exportierbare Gesprächsnotiz mit Partnername und Quellenbezügen |

Der persönliche Strukturcheck und sein Export sind neue Produktentscheidungen, die aus diesen Zielen abgeleitet wurden; sie sind kein im PDF vorgegebenes Formular.

## Kernablauf

1. **Orientieren:** tatsächliche Datenjahre, verfügbare Reihen und fehlende Assetklassen erkennen.
2. **Verstehen:** unveränderten Geldbetrag mit der Kaufkraft seiner CPI-Bezugsregion vergleichen.
3. **Einordnen:** nominale und reale Asset-Indizes sowie deren Zeit- und Einheitengrenzen vergleichen.
4. **Prüfen:** Liquidität, Zugriff, Abhängigkeiten, Alternativen und Entscheidungswege dokumentieren.
5. **Nachhalten:** nächsten eigenen Schritt, Zuständigkeit und Wiederprüfung festhalten; Gesprächsnotiz lokal exportieren.

## Abnahmekriterien

### Arbeitsübersicht

- Konkreter Nutzen statt unbelegter Trefferquote; gleiche Kernbegriffe auf Web, Android und iOS.
- Direkte Wege zu Kaufkraft, Vergleich und Strukturcheck.
- Datenstand und Abdeckung beziehen sich auf den geladenen Datensatz. Fehlende Aktien- und Immobilienreihen werden sichtbar benannt und nicht durch Beispielkurse ersetzt.
- Originaldokumente und Zyklusmodell bleiben zugänglich, ordnen sich aber dem Arbeitsablauf unter.

### Kaufkraft

- Historisch: exakte vorhandene CPI-Start- und Endjahre, keine Interpolation. Endjahr muss nach Startjahr liegen.
- Faktor `CPI(Ende)/CPI(Start)`. Für Betrag A: benötigter nominaler Endbetrag `A × Faktor`; Kaufkraft des unveränderten Betrags in Einheiten des Startjahrs `A / Faktor`.
- Preisänderung und Kaufkraftverlust werden nicht verwechselt. CPI 100→121 bedeutet 21 % Preissteigerung und rund 17,36 % Kaufkraftverlust.
- Die CPI-Region ist sichtbar. Die eingebauten Daten beschreiben die USA; keine Aussage über deutsche/EUR-Kaufkraft und keine Devisenumrechnung.
- Separates Was-wäre-wenn-Werkzeug: selbst angenommene jährliche Inflation und Zeitraum. Zinseszinseffekt, keine Rendite und keine Prognose.
- Betrag größer null bis 10¹², Annahme −50 bis 100 % p.a., 1–100 ganze Jahre. Nicht darstellbare Ergebnisse werden abgewiesen. Deflation bleibt als Kaufkraftgewinn erkennbar.

### Strukturcheck

- Fünf gemeinsame Fragen aus `shared/planning.json`: Liquidität, tatsächlicher Zugriff, Abhängigkeiten, Alternativen/Vertretung, Entscheidung/Wiederprüfung.
- Status je Frage: ungeprüft, dokumentiert, Klärung nötig, nicht zutreffend. Notizen bis 500 Zeichen; nächster Prüfschritt bis 1000, Zuständigkeit bis 80 Zeichen, optionales gültiges Datum.
- Bearbeitete/offene Prüfpunkte sind Arbeitsfortschritt, keine Risikopunktzahl. Auch vollständig ausgefüllte Antworten beweisen keine Sicherheit.
- Explizites Speichern, Wiederherstellen nach Neustart, lokaler Textbericht und gezieltes Löschen der eigenen Checkliste. Beschädigte gespeicherte Daten werden nicht still überschrieben.
- Eigene Angaben bleiben lokal; sie werden weder an den Kursadapter übermittelt noch für Telemetrie verwendet. Keine Kontonummern, Zugangsdaten oder detaillierten Portfolios erforderlich.

## Geänderte oder gestrichene Anforderungen

- **„90 % übersehen“ / „erstes Frühwarnsystem“:** als unbelegte Leistungsversprechen aus dem Arbeitsprodukt entfernt. Als Originalaussagen im Brandguide weiterhin nachlesbar.
- **100 Jahre Marktprognose:** kein Produktversprechen. Die Feldanalyse S. 3, 10 und 16–18 sowie das Whitepaper S. 11 beanspruchen ausdrücklich keine konkreten Vorhersagen. Der mechanische Kalender bleibt als Modell gekennzeichnet.
- **Automatische Krisenwarnungen und Kauf-/Verkaufssignale:** keine Implementierung ohne definierte Indikatoren, Schwellen und Validierung. Ein ausgefüllter Strukturcheck wird nicht zu einer Warnampel umgedeutet.
- **Kontenanbindung, vollständige Portfolioverwaltung, Abos und Cloud-Konten:** für den belegten Kernzweck nicht erforderlich und daher nicht hinzugefügt.
- **Technische Datenkonfiguration als Haupteinstieg:** nachgeordnet; Import und eigener HTTPS-Adapter bleiben für fortgeschrittene Nutzung erreichbar.

## Verbleibende Voraussetzungen

Der echte historische Basisbestand enthält Gold und Silber 1960–2024, US-CPI und Makro-Jahreswerte. Vollständige Aktien-/Immobilienhistorien und 100 Jahre reale Preisreihen bleiben Datenbeschaffungsaufgaben. Die neuen Werkzeuge erweitern die Auswertung vorhandener Informationen; sie ersetzen diese fehlenden Quellen nicht. Physische Geräte-, Datenschutz- und Betreiberabnahme bleiben vor öffentlicher Bereitstellung erforderlich.
