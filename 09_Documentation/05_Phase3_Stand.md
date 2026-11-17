# MIAMI STATE – Phase 3: Sawgrass Park, Fahrzeuge, Optimierung

Stand: 16.11.2026 · Neue Place-Version gespeichert (nicht veröffentlicht). Bestehende Stadtteile wurden erweitert, nicht ersetzt.

## 1. Palmen-Optimierung (Priorität 1)

| | vorher | nachher |
|---|---|---|
| Palmen | 562 | 562 (alle erhalten) |
| Parts pro Palme | ~19 | 2 (1 Union + 1 unsichtbarer Stamm-Kollider) |
| Parts aller Palmen | 10.678 | 1.124 |
| Map gesamt (ohne neue Inhalte) | 28.531 | 18.977 (**−33 %**) |

Vorgehen: 4 Varianten aus den bisherigen Einzelteilen per `GeometryService:UnionAsync` zu je einer Union verschmolzen
(Farben bleiben erhalten), als Vorlagen in `ServerStorage.MapAssets.Palms`. Identische Geometrie wird instanziert gerendert.
Ersetzung abschnittsweise mit Sichtkontrolle: zuerst Coral Key (105), dann übrige Stadtteile (189), dann Mittelinseln (268).
`Kit.palm` nutzt ab jetzt automatisch die Vorlagen – alle Bauschritte erzeugen nur noch optimierte Palmen.

**Blender-Weg geprüft:** `04_Models/Palms/make_palms.py` erzeugt headless 4 Palmen-Meshes (je ~376 Dreiecke, gebogene Wedel)
als FBX. Funktioniert lokal. Für die Nutzung im Spiel müssen sie als Asset hochgeladen werden → benötigt MCP-Berechtigung
„Publish & manage assets → asset:write“ und einen freigegebenen Upload-Ordner. Optionales Upgrade für noch schönere Wedel.

## 2. Sawgrass Park (neuer Stadtteil, X −4200 … −700, Z −2400 … 2200)

- Terrain nach Westen erweitert (bis X −4600).
- Straßen: Glades Rd, Cypress Ave, **Sawgrass Ave** (Boulevard), Mangrove Ave; Coconut Blvd, Causeway Blvd und Harbor Blvd
  nach Westen verlängert; Wohnstraßen Palmetto Ln, Breeze Ln, Sunset Ln; Commerce St, Industry Rd. Festland jetzt 110 Kreuzungen.
- **300 Einfamilienhäuser** und Villen (Vorgärten, Garagen, Einfahrten, Palmen und Laubbäume)
- **12 Apartmenthäuser** in 4 Wohnanlagen (Palm Villas, Coral Gardens, Sawgrass Commons, Mangrove Pointe) mit Poolhof, Spielplatz, Parkplatz
- **Sawgrass Central Park** mit Teich, Wegen, Bänken, Spielplatz
- 32 Läden, Cafés und Restaurants (Ladenzeile am Coconut Blvd, Restaurantzeile an der Sawgrass Ave)
- Bürohäuser, Werkstätten (Auto Repair, Tire Pro …), Self-Storage, Autohaus **Sawgrass Motors**

## 3. Tankstellen

| Tankstelle | Ort | Ausstattung |
|---|---|---|
| **Sunshine Fuel** (groß) | Coconut Blvd / Mangrove Ave | Dach mit Leuchtband, 4 Zapfinseln (8 Zapfsäulen), Sunshine Mart, Preis-Pylon, **Waschstraße**, Parkplätze, Mülleimer, Einkaufswagen, Luftstation, 2 Zufahrten |
| **Bay Fuel** | Causeway Blvd / Mangrove Ave | 2 Zapfinseln, Bay Mart, Preis-Pylon, Parkplatz, 2 Zufahrten |
| Sunshine Fuel (bestehend) | Coconut Heights | unverändert |

Vorbereitet für Interaktion: Zapfsäulen mit Tag `FuelPump` und Attributen `StationId`/`PumpNumber`, je ein **deaktivierter**
ProximityPrompt „Tanken“; Shop-Eingang `ShopEntrance`, Waschstraße `CarWash`. Kein Wirtschaftssystem programmiert.

## 4. Shopping Center „Sawgrass Center“

FRESHWAY MARKET (Supermarkt), VOLT ELECTRONICS, URBAN THREADS (Mode), CAREPLUS PHARMACY (Drogerie), PRO SPORTS, CASA FURNITURE;
dazu STAR BURGER (Fast Food mit Drive-Thru) und BEAN & LEAF (Café). Schaufenster, Türen, Leuchtschilder, überdachter Gang
mit Lichtband, großer Parkplatz mit Lichtmasten und Einkaufswagen, eigenes Parkhaus (4 Ebenen), Pylon-Schild.
Treffpunkt-Marker `MeetingPoint`, jeder Laden mit `StoreEntrance`-Marker für spätere Innenräume.

## 5. Parken

- **Downtown Parking**: befahrbares Parkhaus, 5 Ebenen mit Scheren-Rampen (ersetzt den bisherigen Platzhalter an gleicher Stelle)
- **Center Parking**: Parkhaus am Shopping Center (4 Ebenen)
- Öffentliche Parkplätze (2 × „PUBLIC PARKING“), Parkplätze an Tankstellen, Wohnanlagen, Büros, Diner, Autohaus
- Straßenparken: Parkstreifen der Stadtstraßen, in der Second St mit geparkten Autos

## 6. Fahrzeuge

Eigene Modelle (keine fremden Assets), je 62–82 Parts: **Limousine, SUV, Pickup, Sportwagen, Polizeiauto** (Lichtbalken,
Rammschutz, Beschriftung), **Rettungswagen** (Kofferaufbau), **Feuerwehr** (Drehleiter, Geräteräume). Karosserie, Kabine mit
getönten Scheiben, Scheinwerfer mit Licht, Rückleuchten, Spiegel, Kennzeichen, Felgen mit Speichen, Armaturenbrett, Lenkrad, Sitze.

**Fahrphysik** (`VehicleKit.luau`): je Rad Federbein (Prismatic + Feder), Servo-Lenkung vorn, Motor-Gelenk, Allradantrieb;
Federvorspannung automatisch aus der Masse; Karosserie masselos, Schwerpunkt tief.

**Skripte:**
- `Server/VehicleService` – Netzwerkeigentum an den Fahrer, Einsteigen (F Fahrer / G Mitfahrer), Spawnpunkte (max. 1 Fahrzeug pro Spieler, Cooldown), Sondersignal-Remote mit Prüfung, Aufräumen
- `Client/VehicleClient` – Steuerung (W/S/A/D), geschwindigkeitsabhängige Lenkung, Bremsen/Rückwärts, Tacho-HUD, Q = Sondersignal
- `Client/VehicleEffects` – Blinklicht lokal auf jedem Client

**Spawnpunkte:** Rathausplatz (Limousine, SUV, Pickup, Sportwagen), Sawgrass Center (alle 4 zivil),
Polizei-HQ (2× Polizei), Feuerwache 1 (Feuerwehr), Krankenhaus (2× Rettungswagen). Einsatz-Spawns tragen `RequiredJob` für das spätere Jobsystem.

## 7. Qualitätskontrolle (Play-Modus)

| Test | Ergebnis |
|---|---|
| Fahrzeug spawnen | ✅ |
| Einsteigen / Aussteigen | ✅ (Leertaste; Eigentum geht zurück an Server, Auto bremst) |
| Beschleunigen | ✅ Limousine 0 → 43 km/h in 2,5 s, auf Gerade 90 km/h nach 3 s |
| Bremsen / Rückwärts | ✅ |
| Lenkung | ✅ W+D fährt nach rechts, Auto bleibt waagerecht |
| Sondersignal (Q) | ✅ rot/blau blinkt |
| Stabilität aller 7 Typen | ✅ nach Fix (siehe unten) |
| Konsole | keine Fehler |

**Behobene Probleme:** Fahrzeug-„Explosion“ durch zu leichte Fahrwerks-Hilfsteile und zu starken Lenkservo → Masse ~3,
Servo-Drehmoment an Fahrzeug gekoppelt; Fahrer-Prompt wurde vom Mitfahrer-Prompt verdeckt → eigene Tasten;
Spawn-Prompt saß mitten auf der Fläche (Auto landete auf dem Spieler) → Prompt an den Schildpfosten verlegt.

**Nachtest (Parkhäuser und Einsatzfahrzeuge):**

| Test | Ergebnis |
|---|---|
| Downtown-Parkhaus: Erdgeschoss → Rampe 1 → Wenden → Rampe 2 → Ebene 2 | ✅ (skriptgesteuerter Fahrer, Limousine) |
| Center-Parkhaus (steilere Rampen): gleiche Strecke | ✅ |
| Rettungswagen per Tastatur | ✅ 56 km/h nach 3,5 s, Blaulicht, Rechtskurve, Bremsen, stabil |
| Feuerwehr per Tastatur | ✅ 73 km/h (Höchstgeschwindigkeit) nach 4 s, Blaulicht, Linkskurve, Bremsen, stabil |

Dabei behobene Parkhaus-Fehler: Erdgeschoss lag 1,2 Studs über dem Grundstück (Stufe an der Einfahrt) → bündig;
Rampen ohne Seitenschutz (Auto kippte von der Rampe) → gelbe Schrammborde; Wendefläche zu klein und Spurenden
ohne Wand (Front hing über der Kante) → Wendefläche 44 Studs + Abschlusswände; Schrammborde blockierten das
schräge Einbiegen → beginnen erst nach 24 Studs.

**Hinweis für Spieler:** Im Parkhaus nach jeder Rampe auf der Wendefläche über das Parkdeck ausholen und in die
Nachbarspur einbiegen (Scheren-Rampen). Mit Tastatur ist das Wenden enger als mit dem Testfahrer – ggf. kurz zurücksetzen.

**Weiterhin nicht getestet:** mehrere Spieler gleichzeitig (benötigt Mehrspieler-Test in Studio oder Live-Server).

## 8. Performance

| Wert | Phase 2 | Phase 3 |
|---|---|---|
| Map-Parts gesamt | 28.531 | ~38.500 (inkl. kompletter neuer Stadtteil, Fahrzeuge, Parkhäuser) |
| ohne Sawgrass Park | 28.531 | ~26.000 |
| Am Spawn gestreamt | 7.642 | **6.920** |
| Physik | 60 FPS | 60 FPS |
| Render-CPU am Spawn | 5,3 ms (Einzelwert) | 8,0 ms Median (6,1–18,2) |

## 9. Grafik / Beleuchtung

`Lighting.Technology` ist für MCP-Skripte weder lesbar noch setzbar. **Bitte selbst prüfen:**
Explorer → **Lighting** anklicken → Fenster **Eigenschaften** → **Technology** → **Future** wählen.
Geprüft und aktiv: GlobalShadows an, EnvironmentSpecular/Diffuse = 1 (Reflexionen), Atmosphere, Bloom (Neon-Glühen),
ColorCorrection, SunRays, Laternen/Fenster/Flutlicht per Tag-Nacht-Zyklus, Glasfassaden mit Reflectance.
