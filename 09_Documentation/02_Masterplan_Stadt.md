# MIAMI STATE – Masterplan Stadt (Phase 1)

Stand: 16.11.2026 · Status: **Planung** (Bau startet, sobald die Verbindung zu Roblox Studio steht)

Dieser Plan ist die verbindliche Vorlage für den Bau. Koordinaten in Studs, Ursprung (0, 0, 0) = Zentrum Downtown.
Achsen: **+X = Osten (Meer)**, **−X = Westen (Landesinnere)**, **−Z = Norden**, **+Z = Süden**. Bodenhöhe Land = Y 0, Wasserspiegel = Y −8.

> Beim Bau angepasst (16.11.2026): H1 liegt bei **X −520** (Platz für Frontage St), der Bay Causeway bei **Z −200** (in Flucht mit dem Downtown-Raster), Anschlussstellen an **Coconut Blvd (Z −1000)** und **Harbor Blvd (Z 600)**, Wasserspiegel **Y −8**. Aktueller Baustand: [03_Map_Phase1_Stand.md](03_Map_Phase1_Stand.md).

## 1. Stadtidee

Eine fiktive Küstenstadt nach dem Vorbild Südfloridas: Festland mit Downtown am Wasser, davor eine Bucht und eine vorgelagerte **Strandinsel**, die über **zwei Dämme mit Brücken** angebunden ist. Das gibt uns von Anfang an Brücken, Uferpromenaden, Skyline-Blicke über das Wasser und klare Polizei-Engstellen für Verfolgungsjagden.

Eigene Namen (keine realen oder GTA-Namen):

| Bereich | Arbeitsname |
|---|---|
| Downtown | **Bayfront Downtown** |
| Strandinsel | **Coral Key** |
| Bucht | **Palmetto Bay** |
| Wohngebiet | **Coconut Heights** |
| Industrie/Hafen | **Port Meridian** |
| Vorort | **Sawgrass Park** |
| Sumpf (später) | **Glades** |

## 2. Karte (Phase 1, ca. 7.000 × 6.000 Studs)

```
            X: -4000      -2000        0         1000   1800   2700    +X (Osten)
 Z:-3000  +------------+------------+-----------+-------+------+------
          |            | COCONUT    |  (Park/   |       |CORAL | OCEAN
          | SAWGRASS   | HEIGHTS    |  Reserve) |       | KEY  |
 Z:-1200  | PARK       | Wohngebiet |           |       | Nord |
          | Vorort     +-----H1-----+-----------+ BAY   |------|
          | Tankstelle,|            | BAYFRONT  |=C1====|Hotels|
 Z:    0  | Mall  =====H2===========| DOWNTOWN  | Brücke|Strand|
          |            |   (I-Hwy)  |  Skyline  |       |Prome-|
 Z: 1000  |            |     H1     +-----------+       |nade  |
          |            |            | PORT      |=C2====|Süd   |
          |            |            | MERIDIAN  |       |      |
 Z: 2600  +------------+------------+-----------+-------+------+------
   X<-4000: GLADES (Sumpf, später)
```

`H1` = Nord-Süd-Highway (hochgelegt) · `H2` = Ost-West-Highway · `C1/C2` = Dämme mit Brücken zur Insel

| Stadtteil | X-Bereich | Z-Bereich | Phase |
|---|---|---|---|
| Bayfront Downtown | 0 … 1000 | −1000 … 1000 | **1** |
| Coral Key (Strandinsel) | 1800 … 2500 Land, 2500 … 2750 Strand | −2600 … 2600 | **1** |
| Coconut Heights (Wohnen) | −2000 … −200 | −2800 … −1200 | **1** (erste Straßenzüge) |
| Port Meridian (Industrie) | −500 … 1000 | 1200 … 2600 | 2 |
| Sawgrass Park (Vorort) | −4000 … −2200 | −2600 … 2600 | 2 |
| Glades (Sumpf/Land) | < −4000 | – | 3 |
| Palmetto Bay (Wasser) | 1000 … 1800 | gesamt | **1** |
| Ozean | > 2750 | gesamt | **1** |

## 3. Straßenstandards

Maßstab: Avatar ≈ 5 Studs hoch. Fahrspuren werden bewusst **breiter als real** angelegt, weil Roblox-Fahrzeuge größer skaliert sind und Feuerwehr-Leiterwagen, Rettungswagen und Polizei nebeneinander passen müssen.

| Typ | Aufbau | Gesamtbreite |
|---|---|---|
| **Highway** | 3 Spuren je Richtung à 14 + Seitenstreifen 2 × 10 + Mittelleitplanke 6 | **110** |
| **Boulevard** (Hauptstraße) | 2 + 2 Spuren à 14 + Abbiegespur/Mittelinsel 14 + Gehweg 2 × 14 | **98** |
| **Stadtstraße** | 1 + 1 Spuren à 14 + Parkstreifen 2 × 10 + Gehweg 2 × 12 | **72** |
| **Wohnstraße** | 1 + 1 Spuren à 13 + Gehweg 2 × 10 | **46** |

- Bordsteinhöhe 0,6 Studs, Gehwege leicht erhöht.
- Kurvenradien Highway ≥ 250 Studs, Auffahrten ≥ 120.
- Kreuzungen sind eigene Module (`Intersection_4Way_Boulevard` usw.) mit Haltelinien, Zebrastreifen und Ampel-Ankerpunkten.

### Hauptachsen Phase 1
| Name | Typ | Verlauf |
|---|---|---|
| **H1 – Meridian Expressway** | Highway (hochgelegt, Y 40) | Nord-Süd bei X −400, Z −3000 … 2600 |
| **H2 – Sawgrass Expressway** | Highway | Ost-West bei Z 0, X −4000 … −400, Anschluss an H1 |
| **C1 – Bay Causeway** | Boulevard + Brücke | Z −400, X 1000 … 1800 |
| **C2 – South Causeway** | Stadtstraße + Brücke | Z 1600, X 1000 … 1800 (Phase 2) |
| **Ocean Avenue** | Boulevard | Coral Key, X 2350, Nord-Süd (Hotelseite → Strand) |
| **Bayshore Drive** | Boulevard | Downtown-Ufer, X 900, Nord-Süd |
| **Downtown-Raster** | Boulevards Nord-Süd, Stadtstraßen Ost-West | Blockabstand 400 (Block 300 + Straße) |

Auf- und Abfahrten Phase 1: H1 ↔ H2 (Kleeblatt-Light), H1 → Downtown (Z −400 und Z 400), H1 → Coconut Heights (Z −1800).

## 4. Downtown-Aufbau

- 3 × 5 Blöcke à 300 × 300 Studs.
- Hochhäuser zum Wasser hin am höchsten (Skyline-Wirkung von Coral Key aus): Uferreihe 250–450 Studs hoch, landeinwärts 120–250.
- Reservierte Grundstücke für Spielsysteme:
  - **Police HQ** (Block B2), **Fire Station 1** (Block C1), **Bayfront Medical Center** (Nordrand Downtown, nahe H1 für schnelle Anfahrt).
  - Parkhaus, Bank, Rathaus, Plaza mit Brunnen.

## 5. Explorer-Struktur

```
Workspace
└─ Map
   ├─ Districts
   │  ├─ BayfrontDowntown   (Buildings, Props, Lots)
   │  ├─ CoralKey
   │  ├─ CoconutHeights
   │  ├─ PortMeridian
   │  └─ SawgrassPark
   ├─ Roads
   │  ├─ Highways  ├─ Boulevards  ├─ Streets  ├─ Intersections  └─ Ramps
   ├─ Infrastructure (Bridges, TrafficLights, StreetLights, Barriers)
   ├─ Vegetation      (Palmen, Büsche – CanCollide nur am Stamm)
   ├─ ServiceSites    (Platzhalter: PoliceHQ, FireStation1, Hospital – für spätere Systeme)
   └─ SpawnPoints
ReplicatedStorage
└─ MapKit            (wiederverwendbare Bausteine: Fassaden, Fenster, Palmen, Laternen, Ampeln)
ServerStorage
└─ MapBuildTools     (Generator-Module; nicht im Spiel aktiv)
Lighting             (Atmosphere, Sky, Bloom, ColorCorrection, SunRays, DepthOfField aus)
```

Benennung: `District_Element_Variante_Nr`, z. B. `Downtown_Tower_Glass_03`, `Road_Boulevard_BayshoreDrive_02`.

## 6. Bauweise und Performance

- **Generatorbasiert:** Straßen, Blöcke und Gebäude entstehen über Luau-Module (`ServerStorage/MapBuildTools`), die per MCP in Studio ausgeführt werden. Der Quellcode wird in `02_Scripts` mit Git versioniert. Vorteil: Die Stadt lässt sich jederzeit reproduzierbar neu bauen und anpassen.
- **Terrain** für Wasser, Sand, Gras und Uferböschungen; **Parts/MeshParts** für Straßen und Gebäude.
- **Gebäude** als Models mit `ModelStreamingMode = Atomic`, Kollision vereinfacht (`CollisionFidelity = Box`, Fassadendetails `CanCollide = false`, `CanQuery = false`, `CanTouch = false`).
- Fenster als wenige große Glasflächen statt Einzelfenster; Nachtbeleuchtung über `SurfaceLight` nur auf ausgewählten Fassaden.
- Kleine Requisiten `CastShadow = false`.
- `Workspace.StreamingEnabled = true`, `StreamingTargetRadius` ca. 1024, `StreamingMinRadius` ca. 256.
- Ziel: Downtown < 15.000 Instanzen in Phase 1.

## 7. Look und Stimmung

- Lighting-Technologie **Future**, warme Sonne, leichter Dunst (`Atmosphere` Density ~0,3, leicht pinker Horizont).
- Farbpalette: Weiß/Creme, Türkis, Korallenrosa, Glas in Blaugrün; nachts Neon in Pink/Cyan an Hotels in Coral Key.
- Tag-Nacht-Zyklus und Wetter werden als eigenes System in Phase 2 umgesetzt (Server steuert Zeit, Clients interpolieren).

## 8. Reihenfolge der Umsetzung (Phase 1)

1. Masterplan ✅ (dieses Dokument)
2. Terrain: Land, Bucht, Ozean, Strand von Coral Key
3. Straßennetz: H1, H2, Bay Causeway mit Brücke, Downtown-Raster, Ocean Avenue
4. Downtown-Skyline (wiederverwendbare Turm-Bausteine)
5. Strandpromenade Coral Key, erste Straßen in Coconut Heights
6. Vegetation, Straßenlaternen, Ampeln, Lighting
7. Playtest: Maßstab zu Fuß, Straßenanschlüsse, Performance
