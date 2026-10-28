# Historische und aktuelle Daten

Der echte Basisbestand liegt in `shared/market-data.json`, identisch gebündelt für Web, Android und iOS. Neue Installationen laden ihn standardmäßig; eine bewusste Rückkehr zu Beispieldaten bleibt gespeichert.

- Gold und Silber: World Bank Commodity Price Data, Annual Prices (Nominal), Jahresmittel 1960–2024, USD je Feinunze. Workbook-Stand: 3. Januar 2025. Ein Abruf im Jahr 2026 macht die Beobachtungen nicht aktueller.
- US-CPI: World Development Indicators, FP.CPI.TOTL, Jahresmittel 2010=100, auf denselben Jahresbereich begrenzt.
- Inflation, Rüstungsausgaben und BIP: FP.CPI.TOTL.ZG, MS.MIL.XPND.CD und NY.GDP.MKTP.CD für Deutschland, Spanien, USA, Frankreich und Großbritannien. Gemeinsames Berichtsjahr 2024; Dollarbeträge in Milliarden USD. Fehlende Werte bleiben null.
- Nutzungsbedingungen und Attribution: [Weltbank-Datennutzungsbedingungen](https://data.worldbank.org/summary-terms-of-use), CC BY 4.0 mit den dort genannten Zusatzbedingungen. Weiterverarbeitung durch CRISIS: Auswahl der Reihen, Normierung der Einheiten, Begrenzung auf gemeinsame Jahre. Keine Unterstützung oder Befürwortung durch die Weltbank behauptet.

Jede Quelle hat Downloadadresse, Änderungsstand und SHA-256 des geladenen Rohinhalts in `metadata.sources`. Das Abrufdatum steht separat in `metadata.fetchedAt`. Aktualisierung: `python -m pip install -r tools/requirements-data.txt`, anschließend `python tools/refresh-history.py`. Der Befehl aktualisiert nur bei erfolgreich ausgelesenen echten Daten die vier identischen Bundles. Keine synthetischen Lückenfüller.

## Aktuelle Einzelkurse

Der Node-Server stellt `GET /api/data` bereit: `{data, provenance}`. `data` bleibt der historische Jahresbestand. `provenance.quotes` enthält indikative aktuelle Gold-/Silberkurse von [Gold API](https://gold-api.com), getrennt nach Preis, USD/Feinunze, Anbieterzeitstempel, Anbieteradresse und Fehlerstatus. Der Anbieter beschreibt seine Echtzeit-Endpunkte als öffentlich und auf Websites nutzbar; seine langfristige Verfügbarkeit und eine individuelle kommerzielle Zusage werden nicht garantiert.

Anbieter-URLs: `https://api.gold-api.com/price/XAU` und `/price/XAG`. Keine Schlüssel im Client. TLS bleibt aktiviert, Weiterleitungen werden nicht automatisch verfolgt. Der Adapter begrenzt Antwortgröße und Wartezeit, bündelt gleichzeitige Abrufe und puffert erfolgreiche Antworten höchstens 60 Sekunden. Beim Ausfall wird ein vorhandener alter Stand ausdrücklich als veraltet gekennzeichnet, sonst HTTP 503 geliefert. Ein Kurs älter als drei Stunden wird als veraltet markiert. Reale Börsenzeiten werden dadurch nicht modelliert; auch Wochenendstände können veraltet sein.

Web: „Marktdaten aktualisieren“ ruft den lokalen Node-Adapter auf. Python liefert nur den historischen Bestand. Android/iOS: eigene HTTPS-Adresse dieses Adapters in den Einstellungen eintragen, danach bewusst aktualisieren. Es ist kein öffentliches Backend bereitgestellt. Eine Cloud-Umgebung oder ein Benutzer-PC wird nicht automatisch zur mobilen Datenquelle. Es werden keine Konten, Cookies oder Schlüssel für diesen Funktionsumfang benötigt.

Die aktuellen Einzelkurse werden niemals als Jahresmittel in die Historie geschrieben. Ihr Zeitstempel ersetzt nicht den Jahresstand 2024. Der Gold-Silber-Vergleich und die Inflationsbereinigung nutzen die historischen Reihen. Aktien- und Immobilienkurse sowie eine vollständige Historie von 100 Jahren sind weiterhin nicht durch diese Quelle abgedeckt.
