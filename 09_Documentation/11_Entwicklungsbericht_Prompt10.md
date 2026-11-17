# Entwicklungsbericht Prompt 10 – Fahrzeugbesitz, Apartments, Downtown, Premium-HUD

Stand: 2026-11-17 · Place 122392352890697 · Arbeitsweise: Code im Repo `02_Scripts`, Installation in Studio über `serve.ps1` (localhost), Abgleich Studio = Repo (75/75 Skripte byte-identisch).

## 1. Premium-HUD (`Client/Controllers/Hud.luau`, `Minimap.luau`)

| Element | Position | Umsetzung |
|---|---|---|
| Spieluhr `HH:MM` + Wochentag + Tag/Nacht | oben links | synchron mit `Lighting.ClockTime`; Wochentag ueber neues Attribut `Lighting.GameDay` (DayNightController zaehlt Mitternacht) |
| MIAMI STATE Schriftzug | oben rechts | Montserrat, "STATE" mit Tuerkis-Pink-Verlauf, feine Linie |
| CASH / BANK | direkt unter dem Logo | live ueber Spieler-Attribute `Cash`/`Bank`; Zaehl-Animation und +/- Betrag bei jeder Buchung |
| Beruf / Dienststatus | unter BANK | Fraktionsfarbe |
| Minimap | unten links | bestehende Minimap ins Layout verschoben (keine zweite Karte), 252x164, runde Ecken, Stadtteil/Distanz, "INNENRAUM" in Wohnungen/Venues |
| Lebensanzeige + Status | direkt unter der Minimap | Farbe nach Zustand; Statusbalken in Fraktionsfarbe im Dienst |
| Fahrzeuganzeige | unten rechts, nur im Fahrzeug | Tempo km/h, Modell, Kennzeichen, Tank, Gurt (C), Licht, Warnblinker, Sondersignal; ein-/ausfahrende Animation |
| Schnellzugriff | rechter Rand | schmale Icon-Leiste (Maus/Touch) statt der alten Knopfreihe; Tastenkuerzel unveraendert |

Kompatibilitaet: Handy und Stadtkarte bleiben unveraendert; beim Oeffnen blendet sich die Minimap aus. Das Fahndungs-HUD (Prompt 09) sitzt jetzt unter der Uhr. Die alte Tacho-ScreenGui `VehicleHUD` bleibt deaktiviert erhalten (Handy-Einstellungen greifen darauf zu).

## 2. Fahrzeugsystem (`DealershipService`, Erweiterung `VehicleService`, `Config/Vehicles.luau`, `Client/Controllers/Vehicles.luau`)

- **Autohaeuser:** *Sawgrass Motors* (Standard, bestehendes Gebaeude in Sawgrass Park, Ausstellungsflaeche mit 4 Fahrzeugen) und *Bayfront Prestige* (Luxus, Eingang Midtown, Showroom mit 5 Fahrzeugen auf Drehtellern).
- **Modelle (9):** Volta C1, Meridian Sedan, Everglade SUV, Gulf Hauler | Aurelia S, Regent X, Vento GT, Riviera Spyder (Cabrio), Apex R (Supersportwagen). Fuenf neue Vorlagen als Varianten der bestehenden (`ServerStorage.Vehicles`).
- **Kauf/Verkauf:** Katalog mit Werten, Lackwahl, Kauf vom Bankkonto (Serverpreis, Transaktions-ID, Ortspruefung, max. 8 Fahrzeuge), Verkauf zu 60 %.
- **Probefahrt:** 90 s ab Stellplatz am Autohaus, endet bei Zeitablauf oder Aussteigen, Rueckkehr ins Autohaus.
- **Besitz gespeichert:** Modell, Kennzeichen, Halter (Profil), Kaufpreis, Lack, Tuning, Tankstand; Garagenstatus = ausgeparkt/eingeparkt.
- **Garage:** Garagen-Kioske an allen Apartmenthaeusern, Autohaus und Parkhaeusern, Handy-App "Garage": ausparken, einparken, orten (Navigationsziel), abschleppen ($250), verkaufen, Tuning. Doppeltes Ausparken wird verhindert.
- **Kennzeichen:** eindeutig, am Fahrzeug sichtbar, MDT-Abfrage jetzt auch fuer eingeparkte Fahrzeuge (Status "In der Garage").
- **Tuning (optisch):** Lack (14 Farben), Felgen, Scheibentoenung, Unterbodenbeleuchtung, Scheinwerferfarbe – in Werkstatt (Miami Auto Repair), Autohaus-Service oder Prestige-Atelier.
- **Tank:** Verbrauch je Modell, leerer Tank = kein Antrieb, Tanken an allen bestehenden Zapfsaeulen (E halten, $2 pro %).

## 3. Apartments (`PropertyService`, `Config/Properties.luau`, `Client/Controllers/Property.luau`)

| Haus | Stadtteil | Klassen |
|---|---|---|
| Sawgrass Gardens | Sawgrass Park | Standard |
| Brickell Heights | Midtown (Brickell) | Standard, Stadtwohnung |
| Ocean Drive Residences | Waterfront Coral Key | Stadtwohnung, Luxury |
| Bayfront One | Downtown (hoechster Turm) | Luxury, Penthouse |

- Eingaenge (Vordach, Glastuer, Leuchtschild, Garage) vor Bestandsgebaeuden – die Gebaeude selbst wurden nicht veraendert.
- Kauf ($65k–$950k) oder Miete (7 Tage Vorauszahlung, automatische Verlaengerung vom Konto), Verkauf (70 %), Kuendigung, max. 2 Immobilien.
- Eigene Wohnungsnummer (z.B. `B1-5402`) an der Tuer; Innenraeume je Klasse: Wohnbereich, Kueche, Schlafzimmer, Bad, Balkon; Luxury/Penthouse moebliert, Penthouse mit Dachterrasse und Pool. Skyline-Panorama vor den Fenstern, nachts beleuchtet.
- Zutritt: Eigentuemer, Schluesselinhaber (max. 6, dauerhaft gespeichert), eingeladene Gaeste (5 Minuten); "abgeschlossen" = nur diese, "offen" = Besucher, solange der Bewohner zu Hause ist. Klingeln am Eingang.
- Einrichtung (Grundlage): 10 Moebelstuecke kaufen, vor sich platzieren, verschieben, drehen, einlagern; gespeichert.
- Technik: instanzierte Innenraeume bei x 5200, Y 600 – ausserhalb des Streaming-Radius der Stadt (1024), dadurch dort unsichtbar.

## 4. Downtown & Aktivitaeten (`ActivityService`, `Config/Shops.luau`, `Config/Items.luau`)

- **Einheitliche Grundlage:** alle Orte nutzen den bestehenden InteractionService (Taste E): `VenueDoor` (Tueren mit optionaler Bedingung), `Activity` (bezahlte Aktivitaet mit Fortschrittsbalken), `Shop` (Kataloge).
- **Restaurants:** ueber 100 bestehende Restaurant-/Cafe-Marker sind jetzt bestellbar (Diner, Fast Food, Pizzeria, Sushi, Taqueria, Cuban, Grill, BBQ, Thai, Gelateria, Baeckerei). Neu mit Innenraum: *Maison Azure* (Fine Dining) und *Bayfront Kitchen* (modern); *SKYLINE 52* als Rooftop-Restaurant auf dem echten Dach von Infill_bay_012 (Aufzug). Essen heilt etwas (+2 bis +10), Sitzplaetze an allen Tischen.
- **Nachtleben:** NEONROOM, ECLIPSE und PULSE haben Innenraeume: animierte Tanzflaeche (Tanzen per Emote), Bar (alkoholfreie Drinks), Lounges, DJ-Buehne, VIP-Lounge nur mit VIP-Armband ($750).
- **Shopping:** weitere Marker aktiv (Pro Sports, Buchlaeden, Blumen, Spielwaren, Surf & Sun, Optiker, Corner Market, Thrift Shop).
- **Freizeit:** *Bayfront Social* (Kino mit Ticketkontrolle, 4 Bowlingbahnen mit Kugel/Kegel-Animation und Bestwert, 6 Arcade-Automaten), *Iron Bay Fitness* (Laufbaender, Bankdruecken, Fitnesswert 0–100, Mitgliedschaft), Fitness-24-/Yoga-Marker als Trainingspunkte, Basketballplatz an der Bayfront-Promenade, Autotreffen-Treffpunkt.
- Kartenmarker fuer alle neuen Orte (neue Kategorien "Apartments", "Freizeit").

## 5. Neue / geaenderte Skripte

Neu: `Shared/Config/Vehicles.luau`, `Shared/Config/Properties.luau`, `Server/Services/DealershipService.luau`, `PropertyService.luau`, `ActivityService.luau`, `Client/Controllers/Vehicles.luau`, `Property.luau`, `Activity.luau`, `MapBuild/Steps/25_Prompt10.luau`.

Geaendert: `Main.server.luau` (Services laden; Services bringen eigene Aktionen mit), `VehicleService`, `JusticeService` (MDT-Kennzeichen), `DataService` (Freizeitwerte), `DayNightController` (Wochentag, Fensterlicht), `Hud`, `Minimap`, `Crime` (Position), `Phone` (Apps Immobilien/Garage), `MainClient`, `VehicleClient`, Configs `Items`, `Shops`, `MapData`, `MapExtra`, Bauschritt `18_Gameplay` (Modullisten Prompt 08–10 ergaenzt, damit ein erneuter Lauf nichts mehr entfernt).

## 6. Tests (Studio, Solo-Spieltest, echter Request-Weg des Clients)

Erfolgreich: HUD (Uhr, Logo, Cash/Bank live, Minimap, Fahrzeuganzeige, Gurt), Autohaus-Katalog, Kauf, Ortssperre (Luxusmodell im falschen Autohaus abgelehnt), Ausparken, Doppel-Ausparken verhindert, Tuning, Orten, Probefahrt (Start, Fahren per Tastatur, Ende beim Aussteigen), Tanken, Apartment-Info/Kauf/Miete, Limit 2, Betreten, Moebel kaufen/platzieren/drehen, Lagerpruefung, Schluessel an Offline-Spieler abgelehnt, Verlassen, Verkauf, Kuendigung, Venue-Tuer, Kino-Ticket, Bowling, Restaurant-Bestellung + Essen, Club-Tuer, VIP-Sperre. **Speicherung nach Neustart bestaetigt** (Wohnungen, Moebel, Fahrzeuge, Tuning, Bestwerte). Testdaten danach entfernt, Geld auf Ausgangsstand gesetzt (verbleibend: 1 Kinoticket im Inventar, Bowling-Bestwert 218).

## 7. Bekannte Punkte / offen

- **Mehrspieler nicht live getestet:** Schluessel, Einladungen, Klingeln, Besucher brauchen zwei Spieler (Studio "Test > Server + 2 Clients" manuell starten).
- Fahrzeugvarianten sind Abwandlungen der vorhandenen Modelle (Chrom, Spoiler, offenes Verdeck, kleinerer Kleinwagen); eigene Karosserien waeren ein spaeterer Schritt. Der Volta C1 ist skaliert – Fahrverhalten im Spiel pruefen.
- Neue Lackfarbe eines ausgeparkten Autos wird erst nach dem naechsten Ausparken sichtbar.
- Schluessel gelten nur, solange der Eigentuemer auf demselben Server ist (Innenraum wird aus seinem Profil erzeugt).
- Kino zeigt animierte Titeltafeln statt Filmen; Marina-Bootsaktivitaeten und Veranstaltungen sind noch nicht umgesetzt.
- In Studio wird der echte DataStore benutzt – Tests aendern das eigene Profil.
- Place-Version **60** gesichert (Speichern, nicht veroeffentlicht).
