# Phase 7: Stadtueberarbeitung, Smartphone, Stadtkarte/Minimap, Feuerwehr & Rettungsdienst

Stand: 16.11.2026 · Place-Version 30 (gespeichert, **nicht veroeffentlicht**)

Hinweis: Die im Auftrag erwaehnten Referenz-Screenshots (Handy, Karte) lagen nicht vor. Smartphone und Karte
folgen deshalb dem bestehenden MIAMI-STATE-Design und koennen nach Erhalt der Screenshots angepasst werden.

## 1. Stadtueberarbeitung (Schritte 23 und 24)

Alles wird nur auf **freien** Flaechen gebaut (Kollisionsabfrage), nichts Bestehendes geloescht. Ergebnis liegt in
`workspace.Map.Refinement` und ist reproduzierbar (Schritt 24 baut nur diesen Ordner neu).

| Bereich | Ergebnis |
|---|---|
| Downtown/Midtown verdichtet | 216 neue Gebaeude: Ladenzeilen entlang der Strassen (Cafes, Restaurants, Boutiquen, Bank, Juwelier) mit Markisen, Aussensitzplaetzen, Muellcontainern im Hof, dazu kleine Buero-/Wohnhaeuser auf Innenflaechen |
| Plaetze | 49 Pocket-Plaetze (Hochbeet mit Baum, Baenke, Blumenbeete, Laternen) |
| Gruenflaechen | 124 Parks (Wege, Baenke, Baumgruppen, Blumen, Laternen) und 80 locker begruente Flaechen, Strassenbegleitgruen am Autobahn-Korridor; kleinste Flaechen bleiben bewusst einfache Rasen |
| Parkplaetze | 100 Pflanzinseln und bepflanzte Mittelstreifen gliedern die grossen Parkflaechen (z.B. Sawgrass Center) |
| Strassen | 21 Bushaltestellen, 36 Strassennamen-Schilder (US-Stil) an Kreuzungen, Sitzbaenke und Muelleimer an Gehwegen |
| Vegetation | 4 Baumarten (Laubbaum, Eiche, Zypresse, bluehender Baum) + Palmen, Straeucher mit Blueten, Hecken, 3 Blumenbeet-Varianten |
| Sonstiges | Werkstatt "Miami Auto Repair" (Sawgrass), Bank und Juwelier in Downtown, 104 Stellplatz-Marker fuer eigene Fahrzeuge |

Deko-Objekte sind **wiederverwendbare Union-Vorlagen** (15 Stueck, `ServerStorage.MapAssets.Decor`), die die Engine
instanziert rendert. Pruefung auf Test-/Temp-Objekte: keine gefunden.

## 2. Smartphone (Taste U / HUD "Handy")
Dunkles Design links am Bildschirmrand, Statusleiste (Spielzeit, Bargeld), grosse Uhr, Hintergrundbild (4 zur Wahl),
Ein-/Ausblend-Animation, automatische Skalierung fuer kleine Bildschirme/Mobilgeraete. Apps:
- **Hilfe**: Steuerung, Spielanleitung, Einsatzfraktionen, Regeln, Verletzungen.
- **Notruf**: Polizei / Feuerwehr / Rettungsdienst, Kategorie, Beschreibung, aktueller Standort -> gemeinsame Leitstelle.
- **Bank**: Kontostand, Bargeld, Ueberweisung (mobil), Umsaetze; Ein-/Auszahlen am Geldautomaten mit Route zum naechsten Automaten.
- **Fahrzeug**: eigene Fahrzeuge (jeder Charakter erhaelt ein Startfahrzeug), Details, Kennzeichen, Standort, Ausparken am naechsten freien Parkplatz, Einparken, Orten per Navigation.
- **Server**: Spieler online mit Fraktion/Rang/Dienst, eigene Charakterdaten.
- **Kontakte**: speichern (Server-App oder Interaktionsmenue), Online-Status, entfernen; Nachrichten als vorbereitete Erweiterung.
- **Einstellungen**: Soundeffekte, Musik, Minimap an/aus, Partikel, Steuerungshinweise, Oberflaechengroesse, Hintergrund (im Profil gespeichert, serverseitig validiert).
- **Karte** sowie vorbereitete Apps: Polizei, Fire/EMS (oeffnen das Dashboard fuer Mitglieder), Jobs, Immobilien, Autohandel, Nachrichten, Firmen.
Neue Apps: Eintrag in `Phone.Apps` ergaenzen.

## 3. Stadtkarte, Minimap, Navigation
- **Gemeinsame Datenquelle** `MapGeo` (Schritt 22 erzeugt sie aus der gebauten Welt): 388 Fahrbahnstuecke, 947 Gebaeude, 67 Parkplaetze, 117 Gruenflaechen, 235 Kartenmarker, Strassengraph (536 Knoten).
- **Stadtkarte** (Taste V / Handy-App): Strassen, Autobahn, Stadtteile, Gebaeude, Spielerposition mit Blickrichtung, Zoom (Mausrad/Knoepfe), Verschieben (Ziehen), Legende mit Filtern, Marker anklicken -> Name, Stadtteil, Entfernung, Navigation starten; Klick auf die Karte setzt einen eigenen Wegpunkt.
- **14 Marker-Kategorien** mit Farben/Symbolen: Polizei, Krankenhaus, Feuerwehr, Bank, Tankstelle, Autohaus, Werkstatt, Hafen, Juwelier, Clubs, Restaurants, Geschaefte, Parkhaus, Arbeit/Behoerden.
- **Navigation**: Routenberechnung (A*) im Strassengraph, Route auf Karte und Minimap, Zielmarker in der Welt mit Entfernung, automatische Neuberechnung bei Abweichung, Ankunftserkennung, "Navigation beenden". Einsatz-Wegpunkte der Leitstelle nutzen dieselbe Navigation; funktioniert auch waehrend der Fahrt.
- **Minimap** oben rechts: abgerundet, Norden oben, Spielerpfeil mit Blickrichtung, wichtige Symbole, Ziel (am Rand angeheftet), Route, Stadtteil und Zielentfernung, Zoom (+/- bzw. Knoepfe, 4 Stufen), ausblendbar (Einstellungen).

## 4. Feuerwehr
- **Fire Station 1** neu mit Innenraeumen (Schritt 20): Empfang mit Mitarbeiter-NPC, Umkleide/Dienst-Terminal, Aufenthaltsraum mit Kueche, Besprechungsraum mit Leitstellen-Terminal, Captain's Office, Geraeteraum (Feuerloescher auffuellen), Fahrzeughalle mit 3 Toren/Stellplaetzen und Garagen-Terminal.
- **Dienstgrade**: Firefighter, Senior Firefighter, Engineer, Lieutenant, Captain, Battalion Chief, Fire Chief (Rechte serverseitig; alte 5 Raenge werden automatisch migriert).
- **Dienst**: Antritt nur an der Wache, Schutzkleidung (Helm, Reflexstreifen, Atemschutzflasche), Rufzeichen/Dienstnummer, Dienstzeit, Werkzeuge Feuerloescher + Strahlrohr, Funkkanal FD1, Dashboard (Dienst, Einsaetze, Raenge, Personal).
- **Fahrzeuge**: Fire Engine (Pumpe, Schlauchhaspel), Ladder Truck (Drehleiter, Stuetzen), Rescue Squad (Lichtmast, Dachgepaeck), Command Vehicle - fahrbar, Blaulicht rot/weiss, Sirene, Warnblinker, Mannschaftsraum.
- **Brandsystem**: automatische Einsaetze (nur wenn Feuerwehr im Dienst) an 492 Fundorten: Gebaeude-, Fahrzeug-, Muellcontainer-, Flaechenbrand, technische Hilfeleistung (Unfallwagen, "Person befreien"). Feuer und Rauch, Ausbreitung, Schaden fuer Personen im Brandherd, Loeschen mit Werkzeugen (Strahlrohr nur mit Loeschfahrzeug in der Naehe, Feuerloescher mit Fuellstand), Abschluss mit Praemie und Statistik. Harte Grenzen: 3 Einsaetze, 14 Brandherde, Ablauf nach 30 Minuten.

## 5. Rettungsdienst
- **Bayfront Medical Center**: begehbares Erdgeschoss (Schritt 21) mit Empfang/Warten (NPC), Notaufnahme (3 Behandlungsplaetze), 4 Behandlungsraeumen, 4 Patientenzimmern, Stationsbuero, Rettungswache (Dienst, Ausruestung, Leitstelle), Ambulanzgarage mit 2 Stellplaetzen, Rettungswagen-Zufahrt mit Vordach; Bettenturm mit Hubschrauberlandeplatz bleibt erhalten.
- **Dienstgrade**: EMT, Paramedic, Senior Paramedic, EMS Supervisor, Medical Director.
- **Fahrzeuge**: Ambulance, Heavy Rescue Ambulance, Medical Responder (Notarztfahrzeug) mit Trage/Patientenraum.
- **Verletzungssystem**: leicht / schwer (langsamer) / bewusstlos (liegt, Bildschirm mit Restzeit, "Hilfe rufen" -> automatischer Einsatz, Notaufnahme nach Ablauf gegen Gebuehr). Ursachen: Stuerze, von Fahrzeugen erfasst, Verkehrsunfaelle (Insassen), Feuer. Keine automatische Regeneration mehr; Verbandszeug heilt nur begrenzt. Zustand bleibt beim Verlassen des Spiels erhalten.
- **Massnahmen** (Interaktionsmenue X): Untersuchen (Befund mit Vitalwerten, Ursache, kritischer Zeit), Stabilisieren, Versorgen, Wiederbeleben (Defibrillator), Tragen, in den Rettungswagen / heraus, Klinikbehandlung am Bett (Kosten fuer Patient, Praemie fuer EMS). Feuerwehr darf untersuchen, stabilisieren, versorgen und tragen.

## 6. Gemeinsame Leitstelle
Polizei, Feuerwehr und Rettungsdienst nutzen dasselbe Einsatzsystem: Notrufe aller Kategorien, Standort/Stadtteil,
Prioritaet, verfuegbare Einheiten, Uebernehmen/Vor Ort/Abschliessen, **Nachalarmieren** weiterer Dienste
(z.B. Unfall: Polizei+EMS -> Feuerwehr), automatische Einsaetze (Brand, Bewusstlosigkeit), Panikknopf fuer alle drei Fraktionen.

## Erstellte und geaenderte Skripte
Neu: `Shared/Config/Rescue.luau`, `Server/Services/UniformService.luau`, `RescueService.luau`, `FireService.luau`,
`MedicalService.luau`, `PhoneService.luau`, `Client/Controllers/Rescue.luau`, `Phone.luau`, `CityMap.luau`,
`Minimap.luau`, `Medical.luau`, `FireTools.luau`, `MapBuild/Steps/20_FireStation.luau`, `21_Hospital.luau`,
`22_MapExport.luau`, `23_DecorTemplates.luau`, `24_CityRefine.luau`; generiert: `MiamiShared.Config.MapGeo`.

Geaendert: `Factions.luau`, `Items.luau` (Defibrillator), `MapData.luau` (Marker-Kategorien), `DataService.luau`
(Schema 3: Fahrzeuge, Feuerwehr/EMS-Daten, Verletzung, Handy; Migration), `DispatchService.luau`, `RadioService.luau`,
`VehicleService.luau` (eigene Fahrzeuge, Kennzeichen MSFD/EMS), `PoliceService.luau` (gemeinsamer UniformService),
`JusticeService.luau`, `Main.server.luau`, `MainClient.client.luau`, `Hud.luau`, `Interact.luau`,
`VehicleEffects.client.luau`, `MapKit.luau` (Innenraum-Baukasten), `VehicleKit.luau`, `17_Vehicles.luau`, `18_Gameplay.luau`.

## Neue Modelle
Fire Station 1 (215 Parts), Bayfront Medical Erdgeschoss (305 Parts, 11 Betten), 6 Einsatzfahrzeuge
(FireEngine, LadderTruck, FireRescue, FireCommand, AmbulanceHeavy, EMSResponder; Ambulance ueberarbeitet),
15 Deko-Vorlagen, Werkstatt, rund 220 Infill-Gebaeude.

## Durchgefuehrte Tests (Studio, ein Spieler + Test-Person)
- Smartphone: Oeffnen/Schliessen, Startbildschirm, Hilfe-, Notruf-, Bank-App (Darstellung), Fahrzeug-App (Startfahrzeug, kein Parkplatz in der Naehe -> Ablehnung, Ausparken, doppelt ausparken abgelehnt, Einparken), Einstellungen (ungueltige Werte/Schluessel abgelehnt), Server-App, Kontakt (sich selbst abgelehnt).
- Karte: Darstellung, Legende, Spielerposition, Einsatz-Wegpunkt -> Route/Zielmarker, "Navigation beenden".
- Minimap: Darstellung, Zoom, Stadtteil, Bildrate mit/ohne Minimap je 60 FPS.
- Feuerwehr: Dienstantritt nur an der Wache, Uniform/Werkzeuge/Rufzeichen/Funk, Garage mit Rangpruefung, Einsatz Muellcontainer: Loeschen ohne Werkzeug wirkungslos, Spam-Treffer begrenzt, Einsatz abgeschlossen ($310 Praemie, Funkmeldung).
- EMS: Dienst, Uniform, Garage, kompletter Patientenablauf (Tragen, Einladen, Ausladen, Wiederbeleben, Versorgen, Klinikbehandlung am Bett), Rechte Feuerwehr vs. EMS getrennt.
- Verletzungen: Stufen leicht/schwer/bewusstlos, Sturzschaden (-39), Fahrzeugtreffer (-17), Bewusstlosigkeit (Bildschirm, gesperrte Aktionen, Hilfe rufen -> EMS-Einsatz, Notaufnahme nach Zeitablauf mit $500).
- Leitstelle: 911, Uebernehmen, Nachalarmieren (doppelt/ungueltig abgelehnt), Abschluss nur fuer Berechtigte.
- Persistenz: Rang, Dienstzeit, EMS-Statistik, Fahrzeug, Einstellungen nach Neustart erhalten.

## Waehrend der Tests behobene Fehler
Minimap aktualisierte nach Zoom nicht; Marker/Route lagen unter der Gebaeudeebene; Landflaeche zwischen Stadtteilen als Wasser;
Handy-Hintergrund faerbte alle Inhalte ein; App-Raster nur 3 Spalten; Handy-Karten mit ueberlappenden Texten;
Ausladen aus dem RTW mit zu kleiner Reichweite; Verletzungszustand konnte beim Beitritt ueberschrieben werden;
Polizei-Dienstlogik setzte bei Feuerwehr/EMS-Dienstantritt Status und Uniformfarbe zurueck; Stadtueberarbeitung
(Grundstueck zaehlte als belegt, zu grosse Einzelparks, Ladenreihen belegten ganze Flaechen).

## Performance
- Parts gesamt: ca. 39.000 -> ca. 49.400 (davon Stadtueberarbeitung ca. 10.000, Feuerwache/Krankenhaus ca. 520).
- Instanzen im Client: ca. 77.000; StreamingEnabled ist aktiv.
- Bildrate im Test: 60 FPS (Heartbeat) mit und ohne Minimap; Physik 60 FPS.
- Minimap: Kartenebene einmalig aufgebaut, Aktualisierung mit 30 Hz und nur bei Bewegung; grosse Karte wird beim ersten Oeffnen gebaut und danach wiederverwendet.
- Server-Schleifen: Brandschaden 1 Hz (nur bei aktiven Braenden), Ausbreitung 45 s, Verletzungs-Abtastung 10/5 Hz.

## Noch offen / bekannte Punkte
- **Mehrspieler-Test** steht aus (Studio: Test -> Clients and Servers). Besonders zu pruefen: Tragen/Transport echter Spieler, Liegeposition bei anderen Clients, Sirenen/Feuer bei Zuschauern, Rangverwaltung.
- Loeschstrahl-Optik (Partikel am Werkzeug) wurde nicht im Bild geprueft; Loeschen selbst ist serverseitig getestet.
- Musik: Es gibt noch keine Musik im Spiel; der Regler steuert bereits die Lautstaerkegruppe fuer spaeteres Radio/Musik.
- Grafikoptionen: Roblox erlaubt Skripten keine Grafikqualitaet; in der App gibt es Partikel und Oberflaechengroesse, sonst Verweis auf das Roblox-Menue.
- Ein-/Auszahlen ist bewusst nur am Geldautomaten moeglich (Bargeld); die App zeigt die Route zum naechsten Automaten.
- Einige kleine Stadtteil-Strassenstuecke (u.a. Autobahnrampen) sind nicht mit dem Hauptnetz verbunden; die Navigation weicht dann auf die Luftlinie zum Ziel aus.
- Viele Restaurants/Geschaefte sind Kulisse; kaufbar sind die Ketten mit vorhandenem Sortiment (z.B. Cafes, Apotheke, Markt).
- Die Roblox-Spielerliste ueberdeckt weiterhin teilweise das Funkgeraet.
