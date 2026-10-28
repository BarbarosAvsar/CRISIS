# Datenvertrag und Berechnungen

Der neue echte Basisbestand und der HTTPS-Kursadapter sind in [MARKTDATEN.md](MARKTDATEN.md) dokumentiert. `shared/market-data.json` enthält Weltbank-Beobachtungen, während die unten aufgeführten Beispiel- und Referenzdateien weiterhin synthetische Rechenfälle sind. Aktuelle Einzelkurse kommen als optionale `provenance.quotes` neben `data`; sie werden nicht in jährliche Vergleichspunkte umgewandelt.

## Import v1

`shared/data.schema.json` beschreibt die Struktur. `shared/demo-data.json` ist eine vollständig synthetische Beispieldatei, `shared/golden-data.json` ein kleiner Rechenreferenzfall. Auf allen Plattformen über **Einstellungen → Daten importieren** laden. Höchstens 2 MiB UTF-8, 30 Reihen, 401 Jahreswerte pro Reihe/CPI. Eine erfolgreiche Prüfung ersetzt den gesamten vorherigen Datensatz; Fehler erhalten den Bestand. Eigene Daten verwenden `kind: "import"`, Beispiele `kind: "demo"`.

```json
{
  "schemaVersion": 1,
  "kind": "import",
  "asOf": "2026-01-01",
  "source": "Lizenzierter Anbieter / Datensatzversion",
  "cpiRegion": "DE",
  "cpi": [{"year": 2020, "value": 100}, {"year": 2021, "value": 110}],
  "series": [{
    "id": "gold", "name": "Gold", "group": "Edelmetalle",
    "unit": "EUR/Feinunze", "currency": "EUR",
    "points": [{"year": 2020, "value": 10}, {"year": 2021, "value": 15}]
  }],
  "macro": [{"country": "Deutschland", "inflation": null, "military": null, "gdp": null}]
}
```

Auch dieses Beispiel enthält ausschließlich Rechenwerte, keine Marktdaten. `asOf` ist der gemeinsame Datenstand, kein automatisch überprüfter Zeitpunkt. Zahlen sind JSON-Zahlen, keine Strings. Jahre: eindeutige, streng aufsteigende Ganzzahlen 1800–2200. Werte: endlich, größer null und höchstens 10^15. IDs sind eindeutig und entsprechen `[a-z][a-z0-9-]{0,39}`. Metadaten dürfen nicht leer sein; Titel/Einheiten sind auf 100, Quelle/CPI-Region auf 500 Zeichen begrenzt. Zusätzliche Felder werden ignoriert. Das Schema allein kann Sortierung, eindeutige IDs und Nicht-Leerraum nicht vollständig ausdrücken; die Laufzeitprüfungen ergänzen diese Bedingungen.

Makrofelder sind explizit nullable. `null` bedeutet „Nicht verfügbar“, nicht null Prozent. Inflation: Jahresrate in Prozent. Rüstung und BIP: Milliarden USD für den durch `asOf` bezeichneten Berichtsstand; vor dem Import extern auf dieselbe Periode/Definition harmonisieren. Negative Inflation ist zulässig, negative Ausgaben und negatives BIP nicht. Fehlende Länder werden nicht erfunden. Für unterschiedliche Berichtsperioden sind separate Datensätze erforderlich.

Preise sind jährliche nominale Beobachtungen nach einer konsistenten, extern definierten Aggregation (etwa Jahresende oder Jahresmittel). Diese Aggregation muss der Anbieter in der Quellenbeschreibung erklären. Keine automatische Interpolation, Rückrechnung vor Währungseinführung, Devisenumrechnung, Steuer-, Miet-, Dividenden- oder Gebührenkorrektur. Insbesondere US-/UK-Reihen und lange historische EUR-Reihen benötigen fachgerechte externe Vorverarbeitung.

## Vergleichsrechnung

1. Gewünschte Reihen und Jahresgrenzen wählen.
2. Nur Jahre verwenden, die in **allen** Reihen vorkommen; bei realem Vergleich zusätzlich im CPI.
3. Mindestens zwei gemeinsame Jahre verlangen. Das früheste gemeinsame Jahr ist die Basis `b`.
4. Nominaler Index: `I(t) = 100 × Preis(t) / Preis(b)`.
5. Realer Index: `R(t) = I(t) × CPI(b) / CPI(t)`.
6. Veränderung seit Basis: `Index(letztes Jahr) − 100` Prozent.

CPI muss positiv sein; seine absolute Basis ist unerheblich. Ein DE-CPI kann einen Vergleich aus deutscher Kaufkraftperspektive veranschaulichen, ersetzt bei USD/GBP-Assets aber keine Währungsumrechnung. Werte verschieden denominierter Assets werden nur als relative Indizes verglichen. Keine absolute Addition unterschiedlich denominierter Preise.

Referenz: Preis 10→20, CPI 100→121, nominal 100→200, real 100→165,28925619834712. Der Referenzfall enthält absichtlich eine Lücke in der zweiten Reihe, sodass nur 2020 und 2022 gemeinsam sind.

Gold-Silber-Ratio: der jüngste **gemeinsame** Jahrestermin der IDs `gold` und `silver`; Goldwert / Silberwert nur bei identischer Währung **und identischer Einheit**. Andernfalls nicht verfügbar. Kein Rückgriff auf unterschiedlich datierte letzte Werte.

## Jahresmodell

- Ereignisse: Start 1911, wiederholt +16, +18, +20.
- Hohe Preise: Start 1918, wiederholt +8, +9, +10.
- Niedrige Preise: Start 1924, wiederholt +7, +11, +9.

Die im PDF gedruckten Multiplikationszeichen können die Jahresreihen nicht erzeugen. Die implementierte Addition reproduziert sämtliche Beispiele einschließlich Hochpreisjahr 2026 und Tiefpreisjahr 2032. Die Anzeige 1926–2126 ist ein Kalender mechanischer Modelljahre. Sie modelliert keine Preisverläufe, Wahrscheinlichkeiten, Ereigniskausalität oder nachgewiesene Frühindikatoren. Ab 2027 explizit Szenario. Das Material enthält keinen Backtest und keine Definition eines messbaren Warnscores.

## Künftiger Live-Anbieter

Die Quellenliste ist eine redaktionelle Referenz. Für produktive Anbindung benötigt der Betreiber einen Anbieter mit Nutzungs-/Weiterverteilungsrechten, dokumentiertem API-Vertrag, Historientiefe, Einheiten, Aggregation, Aktualisierung, CPI- und Wechselkursmethodik. Die Anwendung kann den daraus erzeugten v1-Datensatz bereits konsumieren. Zugangsdaten gehören in einen gesicherten Serveradapter, niemals in Browser-/App-Bundles, Importdateien oder das Repository. Es wurden keine Anbieterzugänge angefordert, weil kein bestimmter API-Vertrag vorliegt.

## Speicherung

Web: `crisis-data` und `crisis-brand` in localStorage. Android: private Datei `market.json`, Branding in SharedPreferences, Android-Backup deaktiviert. iOS: Application Support `market.json`, Branding in UserDefaults. Datensätze sind für öffentliche Marktdaten gedacht, nicht für persönliche Portfolios oder Geheimnisse; keine zusätzliche App-Verschlüsselung. Löschen: Beispieldaten wiederherstellen; Branding leeren bzw. App-/Browserdaten löschen. Exporte sind ausdrücklich vom Nutzer gewählte Dateien.
