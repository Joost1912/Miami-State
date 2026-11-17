# Phase 6: Police Department (Miami State Police)

Stand: 16.11.2026 · Place-Version 24 (gespeichert, **nicht veroeffentlicht**)

## Umgesetzte Funktionen

### Polizeiwache (`MapBuild/Steps/19_PoliceStation.luau`)
Eigenstaendiges Gebaeude an der Stelle des frueheren PoliceHQ-Hochhauses in Downtown (X -266..-6, Z -146..-26).
Empfang mit Desk-Officer-NPC, Lobby, Umkleide mit Dienst-Terminal, Bueros mit MDT-Terminals, Besprechungsraum,
Leitstelle (Dispatch-Konsole), zwei Verhoerraeume, drei Zellen mit Gittern, Booking-Bereich, Garage mit drei
Stellplaetzen, Garagen-Terminal und Einparkzone. 13 Tueren, davon die internen nur fuer die Polizei.

### Dienst und Raenge
- Dienstbeginn nur am Dienst-Terminal der Wache, Dienstende ueberall (Dashboard oder Status 10-7).
- Im Dienst: Uniform (Muetze, Abzeichen, Guertel, Funkgeraet, Dienstfarben), Handschellen im Inventar,
  Rufzeichen (z.B. `1-ADAM-90`), Dienstnummer, Einheitenstatus, Funkkanal PD1.
- Bei Dienstende: urspruengliches Aussehen zurueck, Handschellen entfernt, Dienstfahrzeug eingezogen,
  laufende Massnahmen aufgeloest, Dienstzeit gespeichert.
- Neun Raenge von Cadet bis Chief of Police. Rechte werden serverseitig geprueft:

| Ab Rang | Rechte |
|---|---|
| 1 Cadet | Funk, MDT, Dienst, Police Sedan |
| 2 Officer | Fesseln, Durchsuchen, Abfuehren, Strafzettel, Festnahme, Fahndung, Verkehrskontrolle, Kanal PD2, Police SUV |
| 3 Senior Officer | Beschlagnahme, Interceptor |
| 4 Corporal | Highway Patrol |
| 5 Sergeant | Haftbefehl, Vorgesetzter (Entlassen, Protokoll), Einsatzzuweisung, Kanal PDCMD, Unmarked Unit |
| 6 Lieutenant | Raenge verwalten, Einstellen |
| 7 Captain+ | Entlassen aus dem Dienst |

### Fahrzeuge
Police Sedan, Police SUV, Police Interceptor, Highway Patrol und Unmarked Unit (verdeckte Blaulichter).
Ausparken am Garagen-Terminal mit Rang-Pruefung, Einparken in der Garage, Kennzeichen `MSP-<Dienstnummer>`.
Bedienung als Fahrer: Q Blaulicht, R Sirene, T Sirenenton (Wail/Yelp/Priority), Y Horn, H Warnblinker, L Licht.
Der Fahrer erhaelt den Netzwerkbesitz am Fahrzeug, Effekte laufen lokal auf jedem Client.

### Funk (Taste B)
Kanaele DISP, PD1, PD2, PDCMD, INTEROP (sowie FD1, EMS1 fuer andere Fraktionen), Zugriff nach Rang.
Funkspruch mit Filter, Laengen- und Spam-Grenze, 10-Codes als Schnellknoepfe, aktive Einheiten, Panik 10-99
(erzeugt automatisch einen P1-Einsatz).

### Notruf und Leitstelle
- 911 (Taste N fuer alle): Kategorie, Beschreibung, Standort automatisch, Prioritaet aus der Kategorie, 45 s Sperre.
- Beamte uebernehmen Einsaetze (Wegpunkt), melden "vor Ort" und schliessen ab. Ab Sergeant: Einsatz zuweisen.
- Neue Einsaetze werden per Funk und Hinweis gemeldet, offene Einsaetze verfallen nach 45 Minuten.

### MDT (Taste M, nur im Polizeifahrzeug oder an Wachen-Terminals)
Reiter Einsaetze, Karte (Bezirke, Strassen, Orte, Einsaetze und Einheiten live), Personen (Akte, Fahndung,
Haftbefehle, Straftaten, Strafzettel, Verwarnungen, Fuehrerscheinpunkte), Fahrzeuge (Kennzeichen, Typ, Halter,
Zulassung, Status des Halters) und Verkehrskontrolle.

### Festnahme und Strafen (Taste X an einer Person)
Fesseln (Handschellen-Item noetig), Loesen, Durchsuchen mit Beschlagnahme von Waffen und Munition, Abfuehren,
ins Fahrzeug setzen und herausholen, Festnahme im Booking-Bereich mit Tatbestaenden aus dem Strafkatalog.
Die Geldstrafe wird erst vom Konto, dann vom Bargeld abgebucht; Haft in einer freien Zelle mit Countdown,
Fluchtschutz und Entlassung am Ausgang. Haftzeit bleibt beim Verlassen des Spiels erhalten.
Strafzettel (Verkehrskatalog mit Punkten, Fuehrerscheinentzug ab 12 Punkten), muendliche Verwarnung.

### Verkehrskontrolle
Aus dem Polizeifahrzeug: Fahrzeug direkt voraus anhalten. Der Fahrer erhaelt einen Hinweis-Banner, Kennzeichen,
Halter und Fuehrerschein werden automatisch abgefragt und per Funk gemeldet.

### Sicherheit
Alle Aktionen laufen ueber den einen gepruefen Endpunkt mit Rate-Limit; jede Polizeiaktion prueft Dienst,
Rang-Recht, Entfernung und Zustand der Zielperson. Zusaetzlich Aktionssperre pro Beamten, Textfilter fuer
Freitexte, Audit-Protokoll aller Massnahmen (Server-Log und Protokoll-Reiter ab Sergeant). Gefesselte oder
inhaftierte Spieler duerfen nur eingeschraenkte Aktionen ausfuehren und nicht fahren.

## Neue und geaenderte Skripte

Neu: `Shared/Config/Police.luau`, `Shared/Config/MapData.luau`, `Server/Services/VehicleService.luau`,
`PoliceService.luau`, `RadioService.luau`, `DispatchService.luau`, `JusticeService.luau`,
`Client/Controllers/Police.luau`, `Radio.luau`, `MDT.luau`, `Emergency.luau`, `Overlays.luau`,
`MapBuild/Steps/19_PoliceStation.luau`.

Geaendert: `Main.server.luau`, `DataService.luau` (Schema v2 mit Akte und Migration der alten Polizeiraenge),
`JobService.luau`, `Factions.luau`, `Items.luau` (Handschellen), `VehicleKit.luau`, `17_Vehicles.luau`,
`18_Gameplay.luau`, `05_Downtown.luau`, `MainClient.client.luau`, `Hud.luau`, `Interact.luau`,
`VehicleClient.client.luau`, `VehicleEffects.client.luau`.

Entfernt: `Server/VehicleService.server.luau` (ersetzt durch das Modul `Services/VehicleService`).

## Neue Oberflaechen
Polizei-Dashboard (K) mit Dienst, Raengen, Personal und Protokoll · Garage · Funkgeraet (B) · MDT (M) ·
Notruf (N) · erweitertes Interaktionsmenue (X) · Durchsuchungsergebnis · Banner fuer Fesseln, Haft und
Verkehrskontrolle · Einsatz-Wegpunkt · Einsatzleiste im HUD (nur im Dienst).

## Durchgefuehrte Tests (Studio, ein Spieler plus Test-Verdaechtiger)
Getestet ueber echte Client-Anfragen, Tasteneingaben und Bildschirmaufnahmen.

- Dienstbeginn abseits des Terminals abgelehnt, am Terminal erfolgreich; Uniform, Rufzeichen, Dienstnummer gesetzt.
- Dienstende: Uniform entfernt, Fahrzeug eingezogen, Funk und Garage gesperrt, Dienstzeit gespeichert.
- Persistenz nach Neustart: Rang, Dienstzeit, Festnahmen und Strafzettel erhalten, Dienststatus zurueckgesetzt.
- Cadet: nur Police Sedan, Fesseln, Strafzettel, Fahndung, Haftbefehl und Protokoll abgelehnt.
- Sergeant: Interceptor, Highway Patrol und Unmarked ausgeparkt; alle Massnahmen erlaubt.
- Garage: Ausparken nur am Terminal, Spawn-Sperre gegen Doppelklick, Einparken.
- Sirene mit drei Toenen, Blaulicht, Horn, Warnblinker und Licht; fremdes Fahrzeug nicht steuerbar.
- Funk: Kanalrechte nach Rang, Spam- und Laengengrenze, Status-Codes, Panik erzeugt P1-Einsatz.
- 911 mit Sperre und Kategorie-Pruefung; Einsatz uebernehmen, vor Ort, abschliessen; Zuweisen ohne Recht abgelehnt.
- MDT: Zugriff im Fahrzeug, Personensuche, Akte, Fahndung, Haftbefehl, Kennzeichenabfrage, Karte.
- Festnahme komplett: fesseln, durchsuchen, Pistole beschlagnahmt (Telefon abgelehnt), abfuehren, ins Fahrzeug,
  herausholen, Booking ($4.500 Strafe, 11 Minuten), Zelle, Fluchtversuch zurueckgeholt, Entlassung.
- Strafzettel und Verwarnung, ungueltige Codes abgelehnt; Verkehrskontrolle mit Halterabfrage.
- Sicherheit: 20 Anfragen in Folge (7 abgewiesen), ungueltige Datentypen, unbekannte Aktionen, falsche IDs
  abgewiesen; keine Server-Fehler in der Konsole.

## Waehrend der Tests behobene Fehler
- Hupe kaum hoerbar (Ton nur 0,04 s lang): wird jetzt 0,7 s als Schleife gespielt.
- "Aus Fahrzeug holen" setzte die Person auf den Fahrersitz: Sitzverbindung wird serverseitig geloest und die
  Person hinter den Beamten gestellt.
- Gefesselte Personen konnten auf dem Fahrersitz bleiben: Sitzverbindung wird jetzt serverseitig getrennt.
- Kennzeichenabfrage nutzt dieselbe Personensuche wie alle anderen Massnahmen.
- Verwarnungstext: Hinweis auf die tatsaechliche Grenze von 80 Zeichen korrigiert; Aktionsbereich im
  Interaktionsmenue passt sich der Anzahl der Knoepfe an.

## Noch offen
- **Mehrspieler-Test** mit echten Spielern (Studio: Test → Clients and Servers, 2–3 Clients). Mit MCP ist nur
  ein Spieler moeglich; alle Personenmassnahmen wurden mit einem simulierten Verdaechtigen getestet.
  Insbesondere Rangaenderung/Einstellen/Entlassen durch Vorgesetzte, Abfuehren und Haft mit echten
  Spieler-Charakteren sowie Sirenen auf fremden Clients brauchen diesen Test.
- Fahrphysik der neuen Polizeifahrzeuge wurde nicht erneut gefahren (Bauweise wie die getesteten Fahrzeuge).

## Bekannte Punkte
- Die Roblox-Spielerliste (durch die Teams) ueberdeckt oben rechts teilweise das Funkgeraet.
- Das Studio-Testprofil steht nach den Tests auf Polizei, Sergeant.
- Test-Hilfen (MiamiDebug, Test-Verdaechtiger) existieren nur in Studio.
