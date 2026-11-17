# MIAMI STATE – Map Phase 1: Stand

Stand: 16.11.2026 · Gebaut direkt in Roblox Studio über den offiziellen Studio-MCP-Server.

## 1. So wird die Map gebaut

Die Map entsteht **generatorbasiert und reproduzierbar**:

| Datei | Aufgabe |
|---|---|
| `02_Scripts/MapBuild/MapKit.luau` | Bausteine: Straßen, Kreuzungen, Ampeln, Laternen, Palmen, Hochhäuser, Art-Deco-Hotels, Mittelbauten, Häuser, Parkplätze, Schilder |
| `02_Scripts/MapBuild/Runner.luau` | Lädt Kit + Bauschritt aus dem Repo und führt ihn in Studio aus |
| `02_Scripts/MapBuild/serve.ps1` | Lokaler Nur-Lese-Server (localhost:34872), über den Studio die Skripte aus dem Repo holt |
| `02_Scripts/MapBuild/Steps/01…08` | Bauschritte (Setup, Terrain, Straßen, Highway, Downtown, Coral Key, Coconut Heights, Feinschliff) |
| `02_Scripts/Server/TrafficSignalController.server.luau` | Ampelsteuerung (läuft im Spiel) |

Jeder Schritt räumt seinen Bereich vorher auf und baut ihn neu, kann also gefahrlos wiederholt werden.
Ablauf: `serve.ps1` starten → in Studio per MCP `require(ServerStorage.MapBuildTools.Runner:Clone()).run("05_Downtown")`.

## 2. Erstellte Stadtteile

| Stadtteil | Inhalt |
|---|---|
| **Bayfront Downtown** | 15 Blöcke, 16 Glashochhäuser (120–450 Studs, höchste am Wasser, Neon-Kronen, ein Turm mit Spitze), Rathaus mit Platz und Brunnen, Parkhaus, Einkaufszentrum „Bayside Market“, Uferpromenade mit Kaimauer und Palmen |
| **Coral Key** (Strandinsel) | 40 Gebäude an der Ocean Avenue (pastellfarbene Art-Deco-Hotels mit Neon-Finnen und Pools, dazwischen Glastürme, ein Strandparkplatz), 46 Geschäfte/Restaurants, 46 Apartmenthäuser, Holz-Promenade mit Palmen und Laternen, Sandstrand mit 11 Rettungstürmen, Sonnenschirmen und Liegen, 2 Beach Clubs |
| **Coconut Heights** (Wohngebiet) | 105 Einfamilienhäuser und Villen (Ziegel-Satteldächer, Garagen, Einfahrten, Hecken; Villen mit Pool), Park mit Spielplatz, Tankstelle „Sunshine Fuel“, Einkaufszeile „Heights Plaza“ |
| **Palmetto Bay / Ozean** | Terrain-Wasser, flache Bucht, Strand fällt flach ins Meer ab |

## 3. Straßen (fertig, zusammenhängend)

- **Meridian Expressway (H1)**: hochgelegt (Y 40), 3 + 3 Spuren, Mittelleitwand, Pfeiler, Laternen, Z −2900 … 2500
- **2 Rauten-Anschlussstellen** mit je 4 Rampen: Coconut Blvd (Z −1000) und Harbor Blvd (Z 600)
- **Bay Causeway**: Brücke Downtown → Coral Key (Z −200), Steigung auf Y 26 für Bootsdurchfahrt, Geländer, Pfeiler im Wasser
- **Boulevards** mit bepflanzter Mittelinsel und Palmen: Meridian Ave, Bayshore Dr, Coconut Blvd, Causeway Blvd, Harbor Blvd, Ocean Ave
- **Stadtstraßen** mit Parkstreifen: Frontage St, Palm Ave, Sixth St, Second St, Port St, Heights Ave, Bay Rd und Querstraßen auf Coral Key
- **Wohnstraßen** in Coconut Heights (4 Ost-West, 2 Nord-Süd)
- 53 Kreuzungen, automatisch mit Gehwegecken, Zebrastreifen, Haltelinien; **Ampeln** an allen Boulevard-Kreuzungen (Steuerung läuft), sonst Stoppschilder
- Straßenlaternen alle ~120 Studs (Tag `StreetLamp` für spätere Tag-Nacht-Steuerung)

## 4. Einsatzstandorte (für spätere Spielsysteme)

Unsichtbare Markierungen in `Workspace.Map.ServiceSites` (Attribut `Service`):

| Marker | Ort |
|---|---|
| `PoliceHQ_VehicleSpawn` | Parkplatz „Miami State Police“-Hauptquartier (Downtown West) |
| `FireStation1_VehicleSpawn` | Vorplatz Feuerwache 1 mit 4 Hallentoren |
| `Hospital_AmbulanceSpawn` | Notaufnahme „Bayfront Medical Center“ (mit Hubschrauberlandeplatz) |
| `CityHall_Entrance` | Rathaus |

## 5. Playtest-Ergebnis

- Keine Skriptfehler in der Konsole.
- Spawn auf dem Rathausplatz funktioniert, Maßstab aus Spielersicht stimmig (Spur 14 Studs ≈ 2,8 Avatarhöhen, bewusst breit für Fahrzeuge).
- Fußweg vom Rathaus zur Kreuzung Causeway Blvd / Palm Ave ohne Hindernisse.
- Ampeln schalten im Spiel um.
- Kennzahlen: 21.176 Parts, 1.839 Models, 470 Lichter; Client streamt am Spawn ca. 6.600 Parts; Physik 60 FPS; Render-CPU ca. 5,7 ms (Studio, RTX 4060).

## 6. Bekannte Probleme / Einschränkungen

| Problem | Status / Lösung |
|---|---|
| `Lighting.Technology` darf per MCP nicht gesetzt werden | **Manuell**: Lighting → Technology = **Future** einstellen (wichtig für Glas, Neon, Schatten) |
| Place noch nie gespeichert → automatisches Speichern nicht möglich | **Manuell einmal**: Datei → Speichern unter → `01_Project\MiamiState.rbxl` |
| Terrain-Oberfläche liegt 2 Studs über Füllhöhe | Behoben (Füllung bis −2) |
| 3D-Gras wuchs durch Straßen | Behoben (`Terrain.Decoration = false`) |
| Gehweg-Ecken an Kreuzungen fehlten | Behoben im Kit |
| Palmen aus ~19 Parts | Größter Part-Treiber → durch Blender-Mesh ersetzen (Phase 2) |
| Highway endet an beiden Enden mit Absperrung | Fortsetzung in Phase 2 (Port, Sawgrass Park) |
| Rampen-Bodenstücke haben Markierung teils auf falscher Seite | kosmetisch, Phase 2 |
| Hochhäuser ohne Innenräume, Fenster nachts nicht beleuchtet | Phase 2 (Tag-Nacht-System) |

## 7. Was noch fehlt

- **Port Meridian** (Industrie/Hafen) und **Sawgrass Park** (Vorort) – Fläche und Straßenanschlüsse sind reserviert
- **Glades** (Sumpf), Highway H2 nach Westen, zweite Brücke (South Causeway)
- Tag-Nacht-Zyklus und Wetter, beleuchtete Fenster nachts
- Eigene Meshes aus Blender (Palmen, Fahrzeuge, Fassadendetails, Straßenmöbel)
- Innenräume (Polizei, Feuerwache, Krankenhaus, Geschäfte)
- Unsichtbare Kartengrenzen, Fahrzeug-Spawns, Verkehrs-KI
