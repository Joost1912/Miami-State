# Entwicklungsbericht Prompt 13 – LOTT E-Scooter-Vermietung

Stand: 2026-11-17 · Place 122392352890697, gesichert als Version 73 (nicht veroeffentlicht) · Studio = Repo: 76/76 Spiel-Skripte identisch.
Ehrliche Kennzeichnung: **fertig + getestet**, **fertig, nur teilweise getestet**, **offen**.

## 1. Neue und geaenderte Dateien

| Datei | Inhalt |
|---|---|
| `Shared/Config/Lott.luau` (neu) | Preis 50 $/angefangene Minute, Mietabstand 12 Studs, Verlaufslaenge, Aktualisierungsintervall der App, Regeln |
| `MapBuild/Steps/29_Lott.luau` (neu) | Roller-Vorlage (ServerStorage.LottScooterTemplate) + Verteilung in `workspace.LottScooters` |
| `Server/Services/LottService.luau` (neu) | Miete, Sperren, Minutenabrechnung, Rueckgabe, Verlauf, Verbindungsabbruch |
| `Client/Controllers/Lott.luau` (neu) | LOTT-App, Miet-/Verwaltungsdialog am Roller, Mietbalken ueber der Minimap |
| `Server/Services/DataService.luau` | Profilfeld `Lott = { History, Total, Rides }` |
| `Server/Main.server.luau` | LottService geladen; Studio-Testbefehl `MiamiDebug "Lott"` |
| `Client/MainClient.client.luau` | Config, Push-Ereignisse `LottOffer`/`LottManage`/`LottState`, Start |
| `MapBuild/Steps/18_Gameplay.luau` | neue Module in den Installationslisten |

## 2. Roller in der Stadt – **fertig + getestet**

- Eigenes Modell: schwarzes Trittbrett mit Mint-Zierleiste, Mint-Lenkstange mit **LOTT-Logo**, Lenker mit Griffen, **Display** („LOTT FREI“ / „LOTT AKTIV“), Front-Scheinwerfer mit Licht, Ruecklicht, Schutzblech, Staender. Vier kleine Raeder (zwei vorn lenkbar) fuer stabiles Fahren, Aufrichthilfe gegen Umkippen.
- **22 Roller** mit eindeutiger ID `LOTT-1001` … `LOTT-1022`: Downtown 6, Einkaufsstrassen 3, Parks 3, Strandpromenade 3, Wohngebiete 2, Buerogebiete 2, Restaurants/Clubs 2, Bushaltestellen 1 – auf freien, ebenen Flaechen neben Gehwegen (nicht auf Fahrbahnen), mindestens 220 Studs Abstand. (Geplant waren 24; zwei Plaetze fielen wegen des Mindestabstands weg.)
- Ruhende Roller sind verankert (keine Physiklast); nur gemietete Roller sind beweglich.
- Fahren ueber das bestehende Fahrzeugsystem (Steuerung, Netzwerkeigentum, Tacho-HUD „LOTT E-Scooter“, max. 34). Getestet: 41 Studs gefahren mit Lenken, bleibt aufrecht; Fahrt im Spieltest mit 34 km/h.

## 3. Mieten – **fertig + getestet**

- Am Roller [E] „Mieten (50 $/Min)“ → Dialog mit ID, Standort, Preis, Preisbeispielen (1 Min = 50 $, 2:10 = 150 $, 10 Min = 500 $), Regeln, Zahlart Bank/Bar → „Jetzt mieten“ oder „Abbrechen“.
- Nach Bestaetigung: erste Minute gebucht, Roller gesperrt (`Available = false`, `RenterId`), Sitz freigegeben, Spieler steigt direkt auf. [F] „Aufsteigen“ erscheint nur waehrend einer Miete.
- Getestet: zu weit weg → „Du musst direkt am Roller stehen“; Miete ok (Bank −50 $); zweiter Roller → „Du hast bereits einen Roller gemietet“; **zweite Person auf denselben Roller → „Dieser Roller ist bereits vermietet“**; Spieler sitzt auf LOTT-1001.

## 4. Waehrend der Miete / Abrechnung – **fertig + getestet**

- Serverseitig, Vorauszahlung: zu Beginn jeder angefangenen Minute 50 $ (Minutenzaehler je Miete → keine Doppelbuchung). Reicht das Geld nicht → Miete endet automatisch, **keine Schulden**.
- Absteigen beendet die Miete nicht; fremde Spieler werden vom Sitz entfernt („Erst mieten …“).
- Getestet: 2:11 Fahrzeit = **3 angefangene Minuten = 150 $** (Bank 2.415 → 2.265 $), Konsole zeigt genau drei Buchungen. Testgeld danach auf 490 $ / 2.415 $ zurueckgesetzt.
- Mietbalken ueber der Minimap: ID, Laufzeit, bisherige Kosten, blinkender Punkt „laeuft“.

## 5. Beenden – **fertig + getestet**

- Ueber die App („Miete beenden“) oder am Roller ([E] → „Deine Miete“ → „Miete beenden“).
- Roller wird an der aktuellen Stelle aufrecht abgestellt und verankert, sobald er steht; wieder verfuegbar fuer alle.
- Getestet: Beenden ueber den Dialog → „Miete beendet: 3 angefangene Minute(n), gesamt $150“, Eintrag im Verlauf (LOTT-1001, 142 s, 3 Min, 150 $), Gesamt 150 $, 1 Fahrt.

## 6. LOTT-App im Handy – **fertig, nur teilweise getestet**

- App „LOTT“ (🛴, Mint) direkt nach „Karte“; Zaehler zeigt eine laufende Miete.
- Live-Karte (Stadtkarte, Zoom +/−, Zentrieren): Marker frei (mint), vermietet (grau), eigener (gold), eigene Position (blau). Aktualisierung alle 4 s **nur solange die App offen ist**, eigener Punkt jede halbe Sekunde, kein Neuaufbau der Karte.
- Marker antippen → Details: ID, Status, Entfernung (m), Stadtteil, Preis, „Navigieren“ (bestehende Navigation mit Route).
- Aktive Miete: „● ABRECHNUNG LAEUFT“, Dauer, angefangene Minuten, aktuelle Kosten, Countdown zur naechsten Abbuchung, „Zum Roller“, „Miete beenden“.
- Liste „In deiner Naehe“ (5 naechste freie Roller), Verlauf (letzte Fahrten, Gesamtkosten, Fahrten), Regeln.
- Kleine Bildschirme: Handy skaliert ueber das bestehende Handy-Scaling, Dialoge ueber das automatische Fenster-Scaling (Prompt 12).
- Getestet: Datenabfrage (`Lott.List`: 22 Roller, Positionen, Entfernung, aktive Miete, Verlauf). Die App-Oberflaeche selbst wurde **nicht per Klick** durchgespielt (Klick-Automatisierung unzuverlaessig) – bitte einmal manuell oeffnen.

## 7. Sicherheit

- Alle Preise, Sperren und Buchungen nur auf dem Server; der Client sendet nur Roller-ID und Zahlart.
- Eindeutige IDs; ein Roller pro Spieler, ein Spieler pro Roller; Sperre wird vor der Buchung gesetzt (gleichzeitige Anfragen scheitern).
- Abstandspruefung serverseitig (12 Studs); gefesselte/inhaftierte/bewusstlose Spieler koennen nicht mieten.
- Bestehendes Rate-Limit fuer Anfragen; Prompt-Spam-Schutz (0,5 s).
- **Verbindungsabbruch / Spiel verlassen:** Miete endet sofort, bezahlte Minute verfaellt, nichts wird nachberechnet, Roller wird wieder frei.
- Roller verloren (zerstoert/aus der Welt gefallen) → Miete endet.

## 8. Offen / Hinweise

- **Mehrspieler-Test** (zwei echte Clients) ueber „Test → Server + 2 Clients“ manuell durchfuehren: Roller sichtbar vermietet/frei beim anderen Spieler. Die Sperre selbst ist serverseitig getestet.
- Roller werden nach Serverneustart wieder an ihre Ausgangsplaetze gesetzt (Platzierung ist Teil der Karte).
