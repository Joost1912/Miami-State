# MIAMI STATE – Entwicklungsbericht Prompt 09 (Kriminalität)

Stand: 17.11.2026 · Place `122392352890697` (Team Create) · Sicherungen: **v48** „Backup vor Prompt 09“, **v53** Zwischenstand, **v54** Endstand · **nicht veröffentlicht**

Alle Mechaniken sind fiktive, abstrakte Gameplay-Interaktionen: Prompt halten, im Bereich bleiben. Es gibt keine realen Anleitungen.

## 1. Überfälle

### Banküberfall: Miami State Bank (Downtown, −155 / −283)
- **Bank umgebaut** (vorher ein massiver Block):
  - Schalterhalle mit Glastrennwand und 3 Schaltern, Durchgang mit Schwingtür
  - Wartebereich, Geldautomat, Kameras
  - **Tresorraum** mit runder Tresortür, Schließfachwand und Geldwagen
- **Start:** Am Bedienfeld neben dem Tresor 3 s den Prompt halten. Der Server prüft:
  - Tatort
  - Rolle: keine Polizei, niemand im Dienst
  - Zustand: nicht gefesselt, nicht in Haft, nicht bewusstlos
  - mindestens 1 h Spielzeit
  - persönliche Abklingzeit
  - Abklingzeit des Ortes
  - **mindestens 3 Polizisten im Dienst**
- **Ablauf:**
  - Der Alarm wird ausgelöst: Alarmlampen blinken rot, ein Alarmton läuft.
  - Es entsteht ein P1-Einsatz in der Leitstelle.
  - Die Täter bekommen Fahndungsstufe 3.
  - Der Fortschritt (150 s) läuft nur, solange mindestens ein Täter im Tresorbereich ist, sonst pausiert er. 25 s ohne Täter im Bereich, z. B. nach Festnahme oder Flucht, beenden den Überfall als gescheitert.
- **Crew:** Bis zu 4 Spieler. Wer den Tresorbereich während des Überfalls betritt, macht mit und wird ebenfalls gesucht.
- **Belohnung:** Der Server würfelt $4.500–6.500 und verteilt sie auf die Täter, die beim Abschluss im Tresor stehen. Jeder Täter wird genau **einmal** belohnt. Die Auszahlung erfolgt als **markierte Geldbündel** ($100 je Bündel) ins Inventar.
- **Abbrechen:** Der Starter bricht den ganzen Überfall ab, andere Beteiligte steigen nur selbst aus. Ein Abbruch gibt die halbe Abklingzeit.
- **Abklingzeit:** 30 min für den Ort, 45 min persönlich.
- **Schwierigkeitsstufen:** Leicht, Standard, Schwer sind in `Config.Crime` angelegt. Aktiv ist nur „Standard“, die anderen sind vorbereitet.

### Juwelierüberfall: Miami Gold Jewelers (Downtown)
- **Atmosphäre:** Holzvertäfelung, heller Marmor, Vitrinen mit Goldkante und Spots, Wandvitrinen, neue **Schaufensterauslage** mit Podesten, Büsten, Kette und Spots, Pflanzen, Kameras, Tresor, Alarmanlage, 2 Alarmlampen.
- **Start:** Die erste Vitrine (3,5 s halten) startet den Überfall. Danach folgen Alarm, ein Einsatz in der Leitstelle und Fahndungsstufe 2 (mindestens 2 Polizisten im Dienst nötig).
- **Ablauf:**
  - Jede der 3 Vitrinen ist **einmal** ausräumbar und bringt $500–800 in Form von gestohlenem Schmuck.
  - Ein leeres Glas und verschwundener Schmuck sind für alle sichtbar.
  - Das Zeitfenster beträgt 120 s.
  - Der Überfall endet, wenn alle Vitrinen leer sind, die Zeit abläuft oder die Täter flüchten.
- **Abklingzeit:** 20 min für den Ort (danach werden die Vitrinen wieder aufgefüllt), 30 min persönlich.

## 2. Hehler und Wirtschaft
- **Hehler** im Containerhof vor dem Hafentor (−275 / 1110), absichtlich nicht auf der Karte. Er kauft Beute gegen **20 % Abschlag** bar an.
- **Stundenlimit $12.000 pro Spieler.** Darüber kauft er nur noch einen Teil an oder lehnt ab (getestet: genau $12.000).
- **Alle Geldflüsse laufen über `EconomyService`** (Kontoverlauf „Hehler (illegal)“). Im Profil stehen `Crime.Ledger` (Beute und Verkäufe, max. 30 Einträge), `Crime.IllegalEarned`, Überfälle und gescheiterte Überfälle.
- **Beute ist illegal:** Bei einer Durchsuchung wird sie als illegal markiert, sie ist beschlagnahmbar und **wird bei einer Inhaftierung automatisch beschlagnahmt**.
- **Balancing:** Eine Bank bringt netto etwa $3.600–5.200 pro Überfall, verteilt auf die Crew. Ein Juwelier bringt netto etwa $1.200–1.900. Abklingzeiten und das Stundenlimit verhindern endloses Geldverdienen.
- **Organisationen vorbereitet:** Profilfeld `Crime.Organization`, `Config.Crime.Organizations`.

## 3. Fahndungssystem
- **Stufen:** 0 Unauffällig · 1 Gesucht · 2 Hoch gesucht · 3 Prioritätsfahndung (`Record.WantedLevel`, gespeichert). `Record.Wanted` bleibt für alte Systeme synchron.
- **Auslöser:**
  - Bank → 3, Juwelier → 2
  - MDT „Fahndung ausschreiben“ → mindestens 1
  - Haftbefehl → mindestens 2
  - „Fahndung aufheben“ und Inhaftierung → 0
- **Abklingen:** Ohne neue Tat sinkt die Stufe nach 10 / 15 / 20 min um eins. Ein aktiver Haftbefehl hält mindestens Stufe 1. Während eines Überfalls oder in Haft gibt es kein Abklingen.
- **Vertraulichkeit:** Die eigene Stufe sieht nur der Spieler selbst (privater Push). Die Polizei sieht alle Gesuchten im MDT. Es gibt **keine öffentlichen Attribute** zur Fahndung oder Crew.
- **Migration:** Ein vorhandenes `Wanted = true` wird beim Laden zu Stufe 1 (Schema 5).

## 4. Polizei-Integration (keine zweite Leitstelle)
1. Der Alarm löst `DispatchService.CreateSystemCall` aus. Es entsteht ein P1-Einsatz („10-90 Bankueberfall“ bzw. „10-90 Juwelierueberfall“, neue Systemkategorien in `Config.Police`).
2. Es folgt eine Funkmeldung auf DISP und PD1 („ALLE EINHEITEN …“) sowie ein Hinweis an alle Polizisten im Dienst.
3. Der Einsatz erscheint im MDT unter „Einsätze“ und auf der MDT-Karte. Beim Übernehmen gibt es einen Wegpunkt auf Stadtkarte und Minimap.
4. **Neuer MDT-Reiter „Fahndung“:** aktive Überfälle (Täterzahl, Fortschritt, Knopf „Übernehmen“) und gesuchte Personen (Stufe, Grund, Haftbefehl, letzter Stadtteil, Akte).
5. **Crime-HUD für Polizisten im Dienst:** Alarm-Meldung mit Einsatznummer, Täterzahl, Einheiten und „Einsatz übernehmen“.
6. **Abschluss:** Ein vereitelter oder abgebrochener Überfall schließt den Einsatz automatisch. Ein erfolgreicher Überfall meldet „Täter mit Beute flüchtig“, der Einsatz bleibt offen und wird nach 10 min automatisch geschlossen.
7. **Festnahme:** `Justice.Jail` setzt die Fahndung auf 0, beschlagnahmt die Beute und nimmt den Täter aus der Crew.

## 5. Crime-HUD (`MiamiCrimeHUD`, oben links, neue eigene ScreenGui)
- **Fahndungsanzeige:** Stufe als Rauten, Name, Grund und Zeit bis zur nächsten Stufe.
- **Überfall-Panel:** Ort, Countdown, Fortschrittsbalken, Stufe, Hinweis „Im Tresorbereich“ oder „Zurück in den Tresor!“, eigene Beute, Polizeistatus mit Einsatznummer, Knopf „Abbrechen“ bzw. „Aussteigen“.
- **Hehler-Fenster** (`MiamiFence`) mit Angebot und Restlimit.
- Smartphone, Karte, Minimap, Geld-HUD und alle anderen Anzeigen sind unverändert (getestet).

## 6. Weitere Aktivitäten (technisch vorbereitet)
`Config.Crime.Activities` mit Fahndungsstufe, Tatbeständen und Notizen; Freischaltung über `CrimeService.Register(id, handler)` + `Enabled = true`:
- Ladendiebstahl (Kassen in begehbaren Läden)
- Fahrzeugdiebstahl (geparkte NPC-Autos, Abgabe beim Hehler)
- Illegale Rennen
- Kriminelle NPC-Ereignisse

Die Fahndungsstufen, das Beute- und Hehler-System und die Leitstellen-Anbindung lassen sich dafür direkt wiederverwenden.

## 7. Sicherheit
- Start, Fortschritt, Zeit, Belohnung, Fahndung, Einsätze und Abklingzeiten laufen **nur auf dem Server**. Der Client sendet nur Wünsche über den bestehenden `Request`-Endpunkt (mit Rate-Limit). Es gibt keine neuen RemoteEvents.
- **Doppelte Belohnung:** Die Belohnung ist pro Täter markiert, der Statuswechsel erfolgt atomar, eine Vitrine lässt sich nur einmal ausräumen (zweiter Versuch: „leer“).
- **Manipulierte Zeiten:** Der Fortschritt wird serverseitig hochgezählt. Für die Vitrinen gilt ein Mindestabstand von 3,2 s zwischen zwei Beutezügen, auch wenn jemand die Haltezeit des Prompts überspringt (getestet: „Zu schnell“).
- **Unberechtigt:** Polizei, Spieler im Dienst, Gefesselte, Inhaftierte, Bewusstlose und Spieler in der Abklingzeit werden abgelehnt. Es gilt die Mindestanzahl an Polizei im Dienst.
- Hehler: Beute wird in einem atomaren Schritt entnommen, ausgezahlt wird danach. Schlägt die Auszahlung fehl, wird zurückgebucht.

## 8. Neue und geänderte Scripts

**Neu**
- `Services.CrimeService`: Überfälle, Hehler, Polizeiansicht, Aktivitäten-Registry
- `Services.WantedService`: Fahndungsstufen, Abklingen, privater Status, MDT-Liste
- `Config.Crime`: Überfälle und Stufen, Fahndung, Hehler, Beutewerte, Aktivitäten
- `Controllers.Crime`: Crime-HUD, Polizei-Alarm, Alarmlampen, Hehler-Fenster

**Geändert**
- `DataService`: Schema 5, also `Record.WantedLevel`/`WantedUntil` und `Crime` (Statistik, Buch, Abklingzeiten, Organisation)
- `JusticeService`: Fahndung, Haftbefehl und Inhaftierung über Stufen; automatische Beschlagnahme der Beute; Beute ist bei Durchsuchung illegal und beschlagnahmbar
- `InteractionService`: Haltezeit über das Attribut `HoldDuration`
- `Config.Items`: Kategorie „Beute“, `MarkedCash`, `StolenJewelry`
- `Config.Police`: Systemkategorien `BankRobbery` und `JewelryRobbery`
- `Main`: Services, Aktionen `Crime.Cancel`, `Crime.Fence`, `Crime.State`, `Crime.PoliceView`, Studio-Testbefehle
- `MainClient`: `Config.Crime`, Push-Ereignisse `Wanted`, `Heist` und `OpenFence`, Start des Crime-HUD
- `Controllers.MDT`: Reiter „Fahndung“
- `MapBuildTools.ShopKit`: Typ „Bank“, Alarmlampen, Überfallzonen, Juwelier-Vitrinen als Interaktion, Schaufenster

**Neue Modelle**
- begehbare Bank mit Tresor
- Juwelier neu aufgebaut
- Hehler-Platz mit Container, Kisten, Lampe und NPC

## 9. Tests (Studio-Playtest, echter DataStore)

| Test | Ergebnis |
|---|---|
| Start ohne Fehler, Profil auf Schema 5 migriert | ✅ |
| Bank: ohne Polizei abgelehnt (0/3); als Polizist abgelehnt; Start über den **echten Prompt** (E 3,5 s gehalten) | ✅ |
| Alarm, Einsatz #1001 als P1 in der Leitstelle, Funk, Fahndungsstufe 3, Crime-HUD mit Countdown | ✅ |
| Fortschritt pausiert außerhalb des Tresors (17 → 17), läuft drinnen weiter | ✅ |
| Abschluss nach 150 s: $4.800 als 48 Bündel, Buch, Statistik, Alarm aus, Abklingzeit 30 min, neuer Start abgelehnt | ✅ |
| Hehler: $3.840 (20 % Abschlag), Limit exakt $12.000, danach Teilverkauf bzw. Ablehnung | ✅ |
| Juwelier: Vitrine startet den Überfall, „Zu schnell“, „leer“ beim zweiten Versuch, nach 3 Vitrinen Ende und leere Optik | ✅ |
| Polizei: Einsätze sichtbar, Übernahme mit Wegpunkt, MDT-Reiter „Fahndung“ (Darstellung geprüft) | ✅ |
| Fahndung ausschreiben → 1, Haftbefehl → 2, Durchsuchung zeigt Beute als illegal, Inhaftierung → Fahndung 0, Beute beschlagnahmt | ✅ |
| Abbruch durch den Starter: Alarm aus, Einsatz geschlossen, halbe Abklingzeit | ✅ |
| Handy, Stadtkarte, Minimap, HUDs weiterhin funktionsfähig, Konsole ohne Fehler | ✅ |
| Datenspeicherung: Abklingzeiten, Beute, Buch und Fahndung bleiben im Profil (gespeichert und geprüft) | ✅ |

**Gefundene und behobene Fehler:**
- Die Startfunktion für Überfälle hieß wie die Service-Startfunktion und wurde überschrieben. Sie heißt jetzt `StartHeist`.
- Ein geplantes öffentliches Crew-Attribut hätte die Täter verraten. Die Crew wird jetzt nur serverseitig geführt.
- Der Bankschalter hat den Weg zum Tresor versperrt. Jetzt gibt es einen Durchgang.

## 10. Bekannte Probleme und offene Punkte
- **Kein echter Mehrspieler-Test:** Studio-MCP steuert nur einen Client. Crew, mehrere Polizisten und die Synchronisation des HUDs bei anderen Spielern sind nur über die Server-Logik abgesichert. Bitte in Studio unter *Test → Clients and Servers* mit 3–4 Spielern prüfen. Für die Bank sind 3 Polizisten im Dienst nötig; im Studio senkt der Testbefehl `CrimeTest` diese Zahl.
- **Abklingen der Fahndung** (10–20 min) ist im Code umgesetzt, aber nicht in Echtzeit abgewartet.
- **Alarmton:** Er nutzt einen eingebauten Roblox-Ton (`rbxasset://sounds/electronicpingshort.wav`), der als Signalton klingt und nicht wie eine echte Sirene.
- **Optik:** Kassierer, Bankpersonal und Hehler basieren auf derselben NPC-Vorlage (der Hehler ist dunkel umgefärbt).
- **Rufname:** Wer vorher Polizist war, behält in derselben Sitzung seinen Polizei-Rufnamen im Audit-Log (nur kosmetisch).
- **Nicht spielbar, nur vorbereitet:** Ladendiebstahl, Fahrzeugdiebstahl, illegale Rennen, NPC-Ereignisse und kriminelle Organisationen.
- **Kein Schusssystem** (siehe Prompt 08). Überfälle laufen ohne Kampf.
- **Testprofil „Maya Santos“** ist vollständig zurückgesetzt (Geld, Inventar, Rolle, Fahndung, Kriminalitätsdaten). Der Kontoverlauf enthält Testbuchungen.
