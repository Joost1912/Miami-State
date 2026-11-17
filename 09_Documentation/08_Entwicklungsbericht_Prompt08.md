# MIAMI STATE – Entwicklungsbericht Prompt 08

Stand: 17.11.2026 · Place `122392352890697` (Team Create) · Sicherungen: **v34** „Backup vor Prompt 08“, **v42** Zwischenstand, **v45** Endstand · **nicht veröffentlicht**

## 1. Stadtbereiche: verändert und verkleinert

**Vorgehen statt globaler Verkleinerung:** Die Map wurde **nicht** pauschal skaliert. Das hätte Straßen, Spawnpunkte, Garagen, Brandstellen-Marker und die generierten Kartendaten (`MapGeo`) beschädigt. Stattdessen habe ich die überdimensionierten Freiflächen gezielt **verdichtet**: Die Gesamtfläche bleibt gleich, aber es gibt keine riesigen leeren Asphaltflächen mehr.

| Bereich | Vorher | Nachher |
|---|---|---|
| Sawgrass Park, 17 Blöcke (Tankstellen-, Lager-, Büro-, Wohn- und Gewerbeblöcke, Autohaus) | 441–541 × 700 Studs Asphalt, nur 2–15 % bebaut | Häuserzeilen an allen Straßenfronten mit Gassen, Vorgärten und Pocket-Parks; 16 Nachbarschaftsparks (200 × 170) mit Wegen, Bäumen, Bänken und Spielplatz |
| Große Parkplätze (Wohnblöcke, Gewerbe) | durchgehende Parkflächen | durch Parks, Baumreihen und Gebäude gegliedert; markierte Stellplätze bleiben erhalten |
| Downtown, City-Hall-Platz | leere Pflasterfläche | City Hall Gardens (Prompt 07) und 4 begehbare Läden an der Downtown-Ladenstraße |

- **Neu:** 190 Gebäude (Wohnhäuser mit 2–4 Etagen, Bürogebäude mit 3–6 Etagen, Ladenzeilen), 118 Grünflächen, rund 4.800 Parts
- **Geschützt:** Bauplätze mit Fahrzeug-Spawns, Stellplätzen, Zapfsäulen, geparkten Autos, Interaktionen oder Zufahrtsrampen davor werden übersprungen. Jeder dritte Platz bleibt als Durchfahrt bzw. Grünfläche offen.
- **Kontrolle:** Ein Gebäude stand auf zwei Stellplätzen des Autohauses, es wurde entfernt. Danach gab es 0 Konflikte mit Spawn- und Spielmarkern. Ausparken und Fahren im verdichteten Block ist getestet.
- **Karte und Minimap:** Alle neuen Gebäude und Grünflächen stehen in `Config.MapExtra` und werden beim Start eingemischt. Stadtkarte und Minimap stimmen also überein.

## 2. Grafik und Licht

- **Tag/Nacht:** fließende Lichtstimmung über Keyframes (Morgen, Tag, goldene Stunde ~17:45, blaue Stunde ~19:00, kühle Nacht) für Umgebungslicht, Atmosphäre, Farbton, Bloom und Belichtung. Die Werte werden alle 2 s berechnet, das ist eine kleine Rechnung ohne Dauerlast.
- **Neon:** 341 farbige Fassaden-Akzente an Hochhäusern und Clubs (Kanten, Kronen, Fins) sind entsättigt (−55 % Sättigung), leuchten nur nachts und sind tagsüber matt. Ampeln und Displays sind unverändert.
- **Lighting:** Sättigung 0,14 → 0,06, Kontrast 0,12 → 0,10, Bloom 0,55 → 0,45, weichere Schatten 0,15 → 0,22.
- **Läden:** echte Schaufenster aus Glas mit Sprossen, Glas-Schiebetüren, Innenbeleuchtung (SurfaceLights/Spots ohne Schatten, schont die Performance).

## 3. Bestehende Oberflächen: alle erhalten

Analysiert: Alle UIs entstehen per Code (`StarterGui` ist leer). Wichtig: `UI.screen(name)` löscht eine gleichnamige ScreenGui. Neue Menüs haben deshalb eigene Namen: **`MiamiStore`** (Shop-Menü) und **`MiamiWeaponHUD`** (Waffenanzeige).

Nach den Änderungen getestet und funktionsfähig: Smartphone (U), Stadtkarte (V, mit neuer Legende „Waffenhaendler“), Minimap, Geld-HUD, Inventar (I), Notruf (N), Bank-Funktionen, Fahrzeug ausparken/fahren/einparken, Fahrzeug-HUD, Fraktionsmenü (K).

## 4. Namensanzeigen über Köpfen: entfernt

- Das `RPNameTag` (Name, Fraktion, Rang) wird nicht mehr erzeugt.
- Am Humanoid sind `DisplayDistanceType = None`, `NameDisplayDistance = 0`, die Lebensleiste und der `DisplayName` abgeschaltet. `StarterPlayer.NameDisplayDistance` und `HealthDisplayDistance` stehen auf 0.
- **Schutz:** Jede BillboardGui, die nachträglich an einem Spielercharakter auftaucht, wird sofort entfernt. Getestet: Ein untergeschobenes Schild hat nicht überlebt.
- Name und Beruf bleiben in Smartphone, Profil und Fraktionsmenüs sichtbar. Der Charakter selbst ist unverändert.

## 5. Geschäfte

Alle Läden laufen über **ein** Shopsystem (`Config.Shops` + `ShopService` + Shop-Menü). Ein neuer Laden braucht nur einen Katalog-Eintrag und einen Namen in `Shops.ByName`.

| Laden | Ort | Innenraum | Funktion |
|---|---|---|---|
| **Suncoast Arms** (Waffenladen) | Downtown-Ladenstraße (393, −545), vorher Barbershop | Lamellenwand mit Kurzwaffen, Glasvitrine, Zubehörregal, Kasse, Verkäufer | Waffenschein, 3 Kurzwaffen, Munition in Packungen, Holster, Waffenlicht, Waffenkoffer, Abzugsschloss, Reinigungsset, Tasche |
| **Everglades Outfitters** (Langwaffen) | Sawgrass Park (−2513, −1092), vorher Surf Shop, also anderer Stadtteil | Holzinterieur, Langwaffen-Wandrack, Ausrüstungsregale, Tische, Geweih | Flinte, Jagdgewehr, Karabiner, Munition, Zubehör. Nur mit Waffenschein, sauberem Register und ≥ 2 h Spielzeit (Karabiner ≥ 5 h) |
| **Palm Boutique** (Kleidung) | Ocean Drive (542, −427) | Kleiderständer, Wandregal, Schaufensterpuppen, 2 Umkleiden, Spiegel | 34 Kleidungsstücke (Oberteile, Hosen, Schuhe, Kopfbedeckungen, Brillen); Reiter Kaufen / Umkleide / Outfits (6 Plätze) |
| **Freshway Market** (Supermarkt) | Downtown (230, −670) | Regalreihen mit Einzelprodukten, Kühlregal, Aktionsstand | 12 Artikel: Getränke, Lebensmittel, Alltag |
| **Gulf Coast Supply** (Werkzeug) | Downtown (225, −538) | Lochwand mit Werkzeug, Regale, Leiter, Werkzeugkasten-Tisch | 9 Werkzeuge bzw. Baubedarf |
| **Miami Gold Jewelers** (Juwelier) | Downtown (−266, −545) | Holzvertäfelung, heller Marmor, 3 Vitrinen + Wandvitrinen mit Spots, Tresor, Alarm, Kameras | Reiter Ausstellung / Info, 4 Schmuckstücke |

- **Raub-Vorbereitung Juwelier:** Die Vitrinen tragen den Tag `JewelCase` (CaseId, Value, Robbable, Looted), der Tresor den Tag `JewelerVault` (Locked), die Alarmanlage den Tag `JewelerAlarm` (Armed). Das Modell hat die Attribute `RobberyReady` und `JewelCases`.
- Die übrigen Filialen derselben Ketten (z. B. weitere Palm Boutiquen, Sneaker Station, Urban Threads) verkaufen über ihren Eingang ebenfalls aus den Katalogen, bleiben aber außen geschlossene Blöcke.

## 6. Waffen

- Alle Waffen sind fiktive Spielgegenstände ohne Gewaltdarstellung: einfache Teile-Modelle, keine fremden Assets.
- **Waffenschein** (neu): wird im Waffenladen ausgestellt (ab 21, keine Fahndung bzw. kein Haftbefehl) und ist Voraussetzung für Waffen und Munition.
- **Polizei:** Bei einer Durchsuchung gelten Waffen und Munition nur **ohne** Waffenschein als illegal. Der Waffenschein selbst kann beschlagnahmt werden.
- **Inventar:** Waffen anzeigen, Ausrüsten/Verstauen, Laden/Entladen mit Anzeige „Magazin x/y | Reserve“. Munition wandert zwischen Inventar und Magazin, im Profil gespeichert.
- **Waffenanzeige** (unten rechts, nur mit Waffe in der Hand): Name, Magazin, Reserve; Knöpfe bzw. Tasten **Z** Nachladen, **C** Verstauen.
- **Automatisch verstaut** bei: Fesseln, Haft, Bewusstlosigkeit, Fahrersitz, Respawn, Ablegen oder Beschlagnahme.
- **Kein Schusssystem** in dieser Phase: Das Tool trägt die Attribute `MiamiWeapon`, `Mag` und `Loaded` als Grundlage dafür.

## 7. Sicherheit (alles serverseitig)

- Preis, Packungsgröße und Bedingungen kommen nur aus `Config.Shops`. Ein vom Client mitgeschickter Preis wird ignoriert (getestet).
- Ein Kauf ist nur an Kasse oder Eingang **dieses** Ladens möglich (Abstandsprüfung).
- Bedingungen (Waffenschein, Register, Alter, Spielzeit, schon im Besitz) werden bei Anzeige **und** Kauf geprüft.
- **Doppelkäufe:** einmalige Transaktions-ID plus 0,4 s Sperre. Waffen und Kleidung lassen sich nur einmal besitzen.
- **Kein negativer Kontostand:** Abbuchung erst nach Inventarprüfung, atomar (`DataService.Mutate`). Bei einem Fehler wird sofort erstattet.
- Anzahl 1–10, nur bekannte Läden und Artikel. Kleidung lässt sich nur anziehen, wenn sie gekauft wurde, und nur im Kleidungsgeschäft.
- Waffenaktionen haben eine Takt-Sperre und prüfen Besitz und Zustand. Jeder Waffenkauf und jedes Ausrüsten landet im Audit-Log.
- Alle Aktionen laufen über den bestehenden `Request`-Endpunkt mit Rate-Limit. Es gibt keine neuen offenen RemoteEvents.

## 8. Neue und geänderte Scripts

**Neu**
- `ServerScriptService.MiamiServer.Services.WeaponService`: Ausrüsten, Verstauen, Laden, Entladen, Auto-Verstauen
- `ServerScriptService.MiamiServer.Services.ClothingService`: Kleidung anlegen, Outfits, Uniform-Vorrang
- `ReplicatedStorage.MiamiShared.Config.Clothing`: 34 Kleidungsstücke, 5 Bereiche
- `ReplicatedStorage.MiamiShared.Config.MapExtra`: neue Marker, umbenannte Läden, 190 Gebäude, 120 Grünflächen
- `StarterPlayerScripts.MainClient.Controllers.WeaponHud`: Waffenanzeige
- `ServerStorage.MapBuildTools.ShopKit`: begehbare Läden aus Ladenblöcken, mit Sicherung und `revert()`
- `ServerStorage.MapBuildTools.InfillKit`: kontrollierte Verdichtung mit Platz- und Markerprüfung

**Geändert**
- `ShopService`: neu geschrieben (Bedingungen, Pakete, Transaktions-ID, Kleidung, Audit)
- `Config.Shops`: Katalogfelder, 4 neue Kataloge, Supermarkt und Werkzeug erweitert
- `Config.Items`: 6 Waffen, 6 Munitionsarten, Waffenschein, Zubehör, Lebensmittel, Werkzeug, Schmuck
- `DataService`: Schema 4 (`Weapons.Loaded`, `Wardrobe`), Attribut `SessionStart`
- `EconomyService`: `ClaimTx`
- `CharacterService`: Kopfanzeigen entfernt plus Schutz, `ApplyBase`, `AfterAppearance`-Haken
- `InteractionService`: Shop-Katalog mit Sperrgründen
- `JusticeService`: Waffenschein-Logik bei Durchsuchung und Beschlagnahme
- `Main`: neue Services, Aktionen `Shop.Info`, `Weapon.*`, `Clothing.*`, Studio-Testbefehle
- `MainClient`: `Config.Clothing`, MapExtra-Einmischung, `WeaponHud` (plus der Fix für Taste K aus Prompt 07)
- `Controllers.Shop`: komplett neues Shop-Menü (`MiamiStore`)
- `Controllers.Inventory`: Waffenaktionen
- `Config.MapData`: Kategorie „Waffenhaendler“
- `DayNightController`: Licht-Keyframes, Nacht-Akzente

## 9. Tests

| Test | Ergebnis |
|---|---|
| Start ohne Fehler (Server und Client) | ✅ |
| Kopfanzeigen: 0 BillboardGuis, `DisplayDistanceType` None, untergeschobenes Schild entfernt | ✅ |
| Smartphone, Karte, Minimap, Inventar, Notruf, Geld-HUD, Waffen-HUD öffnen/anzeigen | ✅ |
| Waffenladen: ohne Schein gesperrt → Schein (Karte) → P45 → Munition (2 Pakete = 16 Schuss); Doppelkauf, gleiche Transaktions-ID, zu wenig Bargeld, Anzahl 100, fremder Artikel, falscher Laden, manipulierter Preis abgelehnt | ✅ |
| Kontostand nach Käufen exakt ($2.115 − 500 − 1.200 − 64 = $351), nie negativ | ✅ |
| Langwaffen: 1 h → gesperrt; 3 h + Fahndung → gesperrt; 3 h sauber → Flinte ✅, Karabiner gesperrt (5 h) | ✅ |
| Ausrüsten, Laden (+8, 8/8), Entladen, Verstauen; Lauf zeigt nach vorn (Kurz- und Langwaffe) | ✅ |
| Kleidung: 5 Teile kaufen, anziehen, fremdes Teil abgelehnt, Outfit speichern/löschen, eigene Kleidung | ✅ |
| Supermarkt (Kauf + Verbrauch), Werkzeugladen, Juwelier (Kauf + 3 Vitrinen/Tresor/Alarm-Marker) | ✅ |
| Kauf per Mausklick im Shop-Menü (9-mm-Munition) | ✅ |
| Speicherung: Käufe sind nach einem Neustart des Tests im echten DataStore vorhanden; Speichern + Prüfen erfolgreich | ✅ |
| Eigenes Fahrzeug im verdichteten Block ausparken, fahren, einparken | ✅ |
| Fraktionsmenü per Taste K (Fix aus Prompt 07) | ✅ |

**Performance (Studio-Playtest, 1 Spieler):** Physik 60 FPS, Server-Heartbeat 0,3 ms, Speicher etwa 4,8 GB (vorher etwa 4,5 GB). Streaming ist aktiv (Radius 1.024). Neue Parts: etwa 4.800 für die Verdichtung und etwa 1.150 für die 6 Läden. Deko-Teile ohne Kollision bzw. Abfrage, Lichter ohne Schatten.

## 10. Offene Punkte und bekannte Probleme

- **Keine pauschale Verkleinerung der Map** (bewusst, siehe Abschnitt 1). Straßenbreiten, Abstände zwischen Stadtteilen und Randbereiche sind unverändert.
- **Straßen (1.4):** Markierungen, Verkehrsschilder und Parkbuchten wurden nicht überarbeitet.
- **Kein Schusssystem**, Waffen lassen sich nur ausrüsten und laden. Raubüberfälle am Juwelier sind nur technisch vorbereitet.
- **Multiplayer nicht getestet:** Studio-MCP steuert nur einen Client. Empfehlung: In Studio unter *Test → Clients and Servers* mit 2–3 Spielern prüfen.
- **Reiter im Shop-Menü:** Synthetische Mausklicks kamen dort nicht an (Werkzeug-Einschränkung). Die Ansichten Umkleide und Outfits sind über den direkten Aufruf geprüft, ein Kauf-Knopf per Klick ist bestätigt.
- **Optik:** Kopfbedeckungen verschwinden bei Avataren mit großem Haar teilweise. Alle Verkäufer-NPCs sind Kopien derselben Figur (Empfang Krankenhaus).
- **Testprofil (Maya Santos):** Geld und Inventar sind exakt zurückgesetzt. Die **Spielzeit steht auf 3 h**, weil ich sie für den Langwaffentest gesetzt habe und der Originalwert unbekannt ist. Der Kontoverlauf enthält Testbuchungen.
- **Polizei-UI:** Ob der Knopf „Beschlagnahmen“ auch für den Waffenschein erscheint, hängt davon ab, wie das Durchsuchungsmenü „illegal“ anzeigt. Das ist nicht getestet.
- Umgebaute Läden lassen sich mit `ShopKit.revert(model)` zurückbauen. Die Sicherungen liegen in `ServerStorage.ShopKitBackup`.
