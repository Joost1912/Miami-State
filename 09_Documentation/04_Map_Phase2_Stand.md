# MIAMI STATE – Map Phase 2: Stadterweiterung

Stand: 16.11.2026 · Place-Version 6 (in Roblox gespeichert, nicht veröffentlicht)

Grundsatz: Die bestehende Map wurde **erweitert, nicht neu begonnen**. Alle Bauschritte sind deterministisch –
ein erneuter Lauf erzeugt exakt dasselbe Ergebnis. Bestehende Gebäude bleiben stehen; neue Bebauung nutzt nur freie Flächen.

## Neue Bauschritte

| Schritt | Inhalt |
|---|---|
| `03_Roads` (erweitert) | Raster nach Norden verlängert: Midtown St (Z −1400), **Starlight Blvd** (Z −1800), North Gate St (Z −2200). Bayshore Dr endet an der Port St, Palm Ave führt zum Hafentor, Frontage St bis Z 2500. 55 Kreuzungen auf dem Festland. |
| `05_Downtown` (angepasst) | Uferpromenade endet am Hafen, Geländer offen zur Marina. |
| `09_Entertainment` | Starlight Entertainment District |
| `10_Port` | Port Meridian (Containerhafen) |
| `11_Marina` | Bayfront Marina + Marina Village |
| `12_Infill` | Verdichtung der Downtown, neue Midtown- und Condo-Blöcke |
| `13_Night` | Beleuchtete Fenster an allen älteren Gebäuden, Tag-Nacht-Zyklus |
| `Server/DayNightController` | 24 Echtzeit-Minuten pro Tag, Start 17:00; ab 18:24 Laternen, Flutlicht, Fenster an, Umgebungslicht dunkler |

## Neue Gebäudetypen im MapKit

Gestaffelter Turm (versetzte Rücksprünge), runder Glasturm, Wohnturm mit umlaufenden Balkonen, Bürohaus mit Dachterrasse,
Dachterrassen (Pool / Garten / Bar), nachts beleuchtete Fensterfelder, Lagerhalle, Containerblock, Containerbrücke,
Portalkran, Frachtschiff, Luxusyacht, Motorboot, Nachtclub, Casino-Resort, Arena, Absperrkordel, Außenbestuhlung.

## Was entstanden ist

**Downtown / Midtown (Verdichtung):** 40 neue Gebäude – 7 runde Glastürme, 14 gestaffelte Türme, 11 Wohntürme,
8 Bürohäuser – plus 3 kleine Plätze. Höhen je Lage: Uferreihe 180–360, Mitte 130–260, West 90–180, Midtown 120–300.

**Starlight Entertainment District** (Z −2164 … −1436):
- Nachtclubs **NEON ROOM**, **ECLIPSE** (mit Rooftop-Club und DJ-Pult), **PULSE**: Neonfassaden, Leuchtschilder, Vordach, Warteschlange mit Absperrkordeln, VIP-Eingang mit rotem Teppich, Außenbereich
- Bars/Lounges **VELVET LOUNGE**, **TIKI BAR**, **MIDNIGHT JAZZ** mit Außenbestuhlung
- Restaurants **PRIME STEAKHOUSE**, **OCEAN GRILL**, **CAFE SOLEIL**
- **GOLDEN PALM CASINO** mit Hotelturm und Rooftop-Bar (rein fiktives Spielweltgebäude, **kein Echtgeld-Glücksspiel**)
- **MERIDIAN ARENA** (Veranstaltungshalle mit LED-Ring)
- Luxushotel **THE MERIDIAN GRAND** (runder Turm mit Spitze), **SKYLINE HOTEL** mit Rooftop-Bar
- Neon-Torbogen „STARLIGHT DISTRICT“ über dem Boulevard

**Port Meridian** (Z 1036 … 2600):
- Vorzone: Hafenbehörde, Zoll, LKW-Parkplatz mit Sattelzügen
- Sicherheitstor mit Schranken und Wachhäuschen (Marker `PortGate_Checkpoint`), Zaun um das Terminal
- 6 Containerbrücken, 2 Frachtschiffe (ATLANTIC STAR, CORAL TRADER), 60 Containerblöcke, Portalkrane
- 4 Lagerhallen mit Laderampen, Kaimauer mit Pollern und Fendern, 8 Flutlichtmasten

**Bayfront Marina** (Bucht nördlich der Brücke):
- Hauptsteg, 4 Fingerstege, 3 Rampen von der Promenade
- 12 Luxusyachten, 23 Motorboote
- Marina Village auf Plattform über dem Wasser: HARBOR CAFE, MARINA GRILL, BAYFRONT YACHT CLUB mit Außenbereich

## Test (Play-Modus)

- Keine Fehler in der Konsole.
- Tag-Nacht-Zyklus geprüft: Zeit läuft; um 18:37 Fenster an, Laternen Neon + Licht an, Umgebungslicht dunkel; um 06:32 wieder aus.
- Laufweg Rathaus → Meridian Ave → Starlight Blvd bis vor die Clubs: begehbar.
- Client am Spawn: 7.642 gestreamte Parts, Render-CPU 5,3 ms, Physik 60 FPS.
- Map gesamt: 28.531 Parts, 2.189 Models, 522 Lichter, 326 Gebäude.

## Bekannte Punkte

| Punkt | Hinweis |
|---|---|
| Wegsuche über sehr lange Strecken scheitert | Kein Kartenfehler; in Etappen funktioniert der Weg |
| Glanz/Neon wirkt erst mit `Lighting.Technology = Future` richtig | bitte manuell prüfen (per MCP nicht setzbar) |
| HTTP-Freigabe `localhost:34872` nötig für Bauskripte | einmalig in MCP-Berechtigungen gesetzt |
| Palmen weiterhin aus Parts | Mesh aus Blender bleibt größte Performance-Reserve |

## Noch offen

Sawgrass Park (Vorort), Glades (Sumpf), Highway-Verlängerung und H2, Innenräume, Fahrzeuge und Verkehr,
Mesh-Assets aus Blender, Wetter.
