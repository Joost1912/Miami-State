# Entwicklungsbericht Prompt 14 – Stadtbild: Fassaden, Downtown, NPCs, Hafen

Stand: 2026-11-17 · Place 122392352890697, gesichert als Version 79 (nicht veroeffentlicht) · Studio = Repo: 77/77 Spiel-Skripte identisch.
Sicherung vor den Aenderungen: Place-Version 73.

## 1. Fassaden mit Fenstern und Bueros – **fertig + getestet** (Schritt `30_Facades.luau`)

Vorher: Glastuerme waren durchgehende Glasbloecke mit Querbaendern, Buerobauten hatten durchlaufende Glasstreifen; Fenster leuchteten nur nachts.

- **Glastuerme (98 Schaefte):** senkrechte Pfosten alle 8 Studs -> Fensterraster; Glas leicht durchsichtig, dahinter sichtbare Etagen (Geschossdecken, Betonkern, Deckenleuchten auf ca. 80 % der Etagen), Arbeitsplaetze mit Bildschirm im ersten Obergeschoss.
- **Lobbys (57):** durchsichtig, mit Marmorboden, Empfangstheke, Logowand mit Lichtband, Sofas, Pflanzen, Deckenpaneelen, Arbeitsplaetzen.
- **Buerobauten mit Fensterbaendern:** Pfostenraster ueber die ganze Hoehe; hinter ca. 60 % der Fensterbaender beleuchtete Bueros (warmes Licht + Leuchtband).
- **Wohnbauten:** Fensterteilung und Fenstersimse.
- Runde Tuerme bleiben ohne Raster (Zylinder).
- Rein optisch (keine Kollision, keine Raycasts, keine Schatten), je Gebaeude im Ordner `Facade`; geaenderte Originalteile merken ihre alte Transparenz im Attribut `OrigTransp`.
- Getestet: Luft- und Strassenansichten (Fensterraster, beleuchtete Etagen, Lobby-Einrichtung sichtbar).

## 2. Downtown kompakter – **fertig + getestet** (Schritt `31_DowntownDense.luau`)

- Analyse: Die Wohn- und Geschaeftsbloecke in Downtown sind bereits voll bebaut. Die grossen Leerflaechen lagen auf den Dienstgrundstuecken (Polizei, Klinik, Feuerwehr, Rathaus).
- Neu: 6 Buerogebaeude (4 Tuerme 140–200 Studs, 2 Buerobauten) auf diesen Freiflaechen; Parkplaetze, Spawnpunkte, Zufahrten, Vorfelder und Spielmarker bleiben frei (Sperrzonen).
- Minimap/Stadtkarte: `MapExtra.Buildings3`, wird in `MainClient` eingemischt.
- Grenze: Strassen und Bloecke selbst wurden nicht verschoben (das waere ein Neubau des gesamten Strassennetzes inkl. Navigation). Der nordoestliche Polizei-Hof bleibt leer, weil dort Fahrzeug-Spawnpunkte liegen.

## 3. NPCs entfernt – **fertig + getestet** (Schritt `32_NoNPC.luau`, `Traffic.luau`)

- 16 NPC-Figuren (Verkaeufer, Empfang Polizei/Feuerwehr/Klinik, Hehler, Jobcenter, 5x Autohaus-Personal) **nach `ServerStorage.Backup_NPCs` verschoben** (nicht geloescht, Attribut `OrigPath`).
- Ersatz an derselben Stelle: Theke mit Kasse (Laeden, Empfaenge), Info-Terminal (Jobcenter, Interaktion „Berufe ansehen“ bleibt), Kistenstapel (Hehler, „Ware anbieten“ bleibt).
- Nebenbei behoben: Das Autohaus-Personal trug versehentlich die Jobcenter-Interaktion.
- Passanten (Client-Verkehr) abgeschaltet; NPC-Autos bleiben (abschaltbar im Handy unter Einstellungen).
- Getestet: 0 Humanoide in der Welt, Prompts an Terminal und Kisten vorhanden.

## 4. Hafen – **fertig + getestet** (Schritt `33_Harbor.luau`, `Server/Services/GateService.luau`)

- Fahrwege im Containerterminal: Ringstrasse am Tor, 5 Nord-Sued-Achsen (Lagerstrasse, 3 Terminalgassen, Kaistrasse), 6 Ost-West-Querspangen – dunkler Asphalt, gelbe Mittellinie, weisse Randlinien, Haltelinien.
- **Funktionierende Schranken** (Einfahrt/Ausfahrt): Pfosten mit Antrieb, rot-weisser Baum mit Gegengewicht und Spitzenlicht, Ampel rot/gruen, Mittelinsel mit Pollern, „STOP“ auf der Fahrbahn. Oeffnet automatisch, sobald ein Spieler (zu Fuss oder im Fahrzeug) heranfaehrt, schliesst 2,5 s nachdem der Bereich leer ist.
- Schilder (Tempo 15, Terminal A/B/C, Kai, Lagerhallen, Ausfahrt), Betonschutzwand an der Lagerstrasse, Lichtmasten an den Hauptkreuzungen.
- Die alten starren Schrankenbaeume liegen in `ServerStorage.Backup_Harbor`.
- Getestet: Schranke 0° -> 81° beim Annaehern (Ampel gruen), zurueck auf 0° nach dem Verlassen (Ampel rot).

## 5. Leistung

- Teile in der Welt: 62.800 -> 94.000 (Fassaden ~30.800, rein optisch, ohne Kollision/Schatten).
- Spieltest: 60 FPS, ca. 18.000 gestreamte Teile beim Client (StreamingEnabled, Radius 1024).

## 6. Offen / Hinweise

- Einfache Wohnhaeuser (Vororte) und Lagerhallen haben bereits eigene Fenster bzw. keine; sie wurden nicht veraendert.
- Ruecknahme: NPCs aus `Backup_NPCs` zurueckverschieben und `NPCReplacement`-Objekte entfernen; Fassaden: Ordner `Facade` loeschen und `OrigTransp` zurueckschreiben; Downtown/Hafen: Ordner `DowntownDense` bzw. `Harbor14`.
