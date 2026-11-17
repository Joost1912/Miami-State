# Entwicklungsbericht Prompt 11 – Jobsystem, Unternehmen, Wirtschaft, Karriere

Stand: 2026-11-17 · Place 122392352890697, gesichert als Version 66 (nicht veroeffentlicht) · Code im Repo `02_Scripts`, installiert ueber `serve.ps1`; Abgleich Studio = Repo: 79/79 Skripte byte-identisch.

## Analyse (Ausgangslage)

- Berufe = Fraktionen (Polizei, Feuerwehr, EMS) + frei waehlbare zivile Rollen. **Fehler:** Zivilisten bekamen ohne jede Aktivitaet $50–100 alle 10 Minuten; „Unternehmer“ war ohne Unternehmen waehlbar (AFK-/Exploit-Einkommen).
- Wiederverwendet statt neu gebaut: EconomyService (Bank, Transaktions-IDs), InteractionService (Taste E), UniformService (Arbeitskleidung), VehicleService (Dienstfahrzeuge, Kennzeichen), ShopService, Smartphone, CityMap-Navigation, MiamiDebug.

## 1. Zentrales Jobsystem (`WorkService`, `Config/Work.luau`, `Client/Controllers/Work.luau`)

Job-Dashboard (Fenster „Arbeit & Wirtschaft“) mit Reitern JOBS · KARRIERE · UNTERNEHMEN · MITARBEITER · FINANZEN. Jeder Beruf zeigt Beschreibung, Voraussetzungen, Verdienst, Arbeitsort, Arbeitskleidung, Aufgaben, Fortschritt (Auftraege, Verdienst) und Status. Beruf waehlen per Handy/Dashboard oder direkt am Depot; Schicht beginnt am Depot-Terminal.

Ablauf: Der Server erzeugt jeden Auftragsschritt und prueft die Position selbst (2x/s). Der Client zeigt eine Auftragskarte unter dem Geld-Block, eine nur fuer den Spieler sichtbare Zielmarkierung, Halte-Prompts und die Navigation.

## 2. Berufe

| Beruf | Firma / Depot | Ab Stufe | Fahrzeug | Ablauf | Richtwert/h |
|---|---|---|---|---|---|
| Bauarbeiter | Sunstate Construction, Baustelle Sawgrass West | 1 | – | Material holen/abladen, Werkzeug (Presslufthammer, Betonmischer, Schweissen, Kran) | $1.100–1.500 |
| Paketzusteller | Gulf Coast Parcel, Office Parking | 1 | Lieferwagen | Pakete laden, 3 Adressen (Ladenmarker) | $1.500–2.000 |
| Taxifahrer | Miami Cab Co., Public Parking Ost | 1 | Taxi | Fahrgast abholen, absetzen, Fahrpreis + Trinkgeld (schnelle Fahrt) | $1.600–2.200 + Tipps |
| Busfahrer | Miami State Transit, Public Parking Nord | 2 | Stadtbus | Linie 1: 8 Haltestellen, halten, Fahrgaeste, Linienbonus | $1.800–2.400 |
| Mechaniker | Miami Auto Repair | 2 | Werkstattwagen | Pannenhilfe (Pannenfahrzeug mit Rauch), Fahrzeug warten/betanken, Kunden per Rechnung abrechnen (80 % Mechaniker, 20 % Werkstatt) | $1.800–2.600 + Rechnungen |
| LKW-Fahrer | Meridian Freight, Hafen | 3 | Kasten-LKW | Fracht laden, 11 Ziele (Lager, Tankstellen, Maerkte), Fernverkehr ab Stufe 5 (+25 %) | $2.200–3.000 |

Neue Fahrzeugvorlagen: Taxi, DeliveryVan, BoxTruck, CityBus, ServiceTruck (Varianten bestehender Modelle mit Beschriftung).

## 3. Unternehmen (`BusinessService`)

19 Unternehmen in 8 Typen an bestehenden Standorten: Restaurants (Maison Azure, Bayfront Kitchen, SKYLINE 52, The Burger Joint – Kette, Little Havana Diner), Cafes (Cafe Moka – Kette, Bean & Leaf), Nachtclubs (NEONROOM, ECLIPSE, PULSE), Autohaeuser (Sawgrass Motors, Bayfront Prestige), Werkstatt (Miami Auto Repair), Geschaefte (Freshway – Kette, Volt Electronics, Palm Boutique), Immobilien (Bayfront Realty), Lieferunternehmen (Gulf Coast Parcel, Miami Cab Co.).

- Finden: Unternehmensliste mit „Auf Karte zeigen“; „BUSINESS“-Kiosk am Standort (19/19 platziert).
- Kaufen vor Ort (Bank, ab Karrierestufe 3, max. 2), atomar ueber eigenen DataStore → serveruebergreifend eindeutig; verkaufen an die Stadt (70 % + Kontostand).
- Dashboard: Name, Konto, Einnahmen, Ausgaben, Mitarbeiter, Oeffnungszeiten, Wert, Status (Geoeffnet/Geschlossen/Verschuldet/Zu verkaufen), Buchungsjournal; Einzahlen, Auszahlen, Oeffnen/Schliessen, Zeiten, Preisfaktor (0,8–1,5, nur Gastronomie/Laden/Club), Club-Eintritt.
- Einnahmen aus echten Ablaeufen: Kassenumsaetze (Marge 25–35 %), Club-Eintritt (VIP-Armband frei), Autohaus-Provision, Tuning, Mechaniker-Rechnungen, Immobilien-Provision, Auftragsgebuehren der Lieferfirmen, Laufkundschaft nur pro eingestempelter, aktiver Person vor Ort.
- Ausgaben: Betriebskosten stuendlich atomar abgebucht ($500–2.600/Tag, auch offline, max. 72 h nachberechnet), Gehaelter.

## 4. Mitarbeitersystem

Bewerbung → Einstellung (Praktikant/Mitarbeiter) → Befoerderung bis Manager; Entlassung, Kuendigung, Gehaelter je Position (Obergrenzen), Ein-/Ausstempeln vor Ort, Mitarbeiteruebersicht mit Online-/Dienststatus. Rechte serverseitig: Inhaber alles; Manager befoerdern/entlassen/Gehaelter/Preise (nur unterhalb der eigenen Position); Supervisor Bewerbungen annehmen, Finanzen sehen; Supervisor ab Stufe 8, Manager ab Stufe 12. Gehalt alle 10 Minuten aktiver Dienstzeit aus dem Unternehmenskonto. Mitarbeiter der Lieferfirmen erhalten +10 % Auftragslohn.

## 5. Wirtschaft & Schutz

- Alles konfigurierbar in `Config/Work.luau` (Loehne, XP, Stufenkurve, Limits, Unternehmenstypen, Preise, Margen, Betriebskosten).
- **Anti-AFK:** Gehalt/Grundsicherung (Payroll) nur bei Bewegung im Auszahlungszeitraum; Laufkundschaft und Unternehmensgehalt nur aktiv und vor Ort.
- Zivile Rollen einheitlich $50 Grundsicherung (Verdienst kommt aus Berufen).
- Stundenlimit $4.500 Arbeitslohn; Teleport-Schutz (Mindestfahrzeit); Haltezeit serverseitig; Transaktions-IDs gegen Doppelbuchung; jeder Lohn im Kontoverlauf und Server-Log.
- Finanzen-Uebersicht: Bargeld, Bank, Arbeitsverdienst, laufende Kosten (Mieten, Fahrzeuge, Unternehmen), Preisuebersicht, letzte Kontobewegungen.

## 6. Karriere

XP fuer Auftraege, Lieferungen, Rechnungen, Arbeit im Unternehmen, Unternehmensfuehrung und Kauf; Stufen 1–30, Lohnbonus +2 %/Stufe (max. +30 %), Freischaltungen (Bus/Mechaniker 2, LKW/Unternehmen 3, Fernverkehr 5, Supervisor 8, Manager 12), Jobfortschritt je Beruf.

## 7. Smartphone

Bestehendes Handy erweitert (nicht neu gebaut): JOBS (bisherige App umgeleitet), KARRIERE, FIRMEN (bisheriges „kommt bald“ ersetzt), MITARBEITER, FINANZEN; Startbildschirm scrollbar. Das HUD ist unveraendert.

## 8. Neue / geaenderte Skripte

Neu: `Shared/Config/Work.luau`, `Server/Services/WorkService.luau`, `BusinessService.luau`, `Client/Controllers/Work.luau`, `MapBuild/Steps/26_Prompt11.luau`.
Geaendert: `Main` (Services, Studio-Debug WorkState/SetXP/BusinessFlush), `PayrollService` (Anti-AFK), `Factions` (Grundsicherung), `DataService` (Profil `Work`), `ShopService` + `InteractionService` (Preisfaktor, Umsatzanteil), `DealershipService` (Provision, Tuning), `PropertyService` (Provision), `ActivityService` (Club-Eintritt), `MainClient`, `Phone`, `MapExtra` (Depots auf der Karte), Bauschritt `18_Gameplay` (Modullisten).

## 9. Tests (Studio, Solo, echter Request-Weg)

Erfolgreich: Jobliste/Stufensperre (LKW ab 3 abgelehnt), Beruf waehlen, Schicht nur am Depot, Arbeitskleidung, alle 6 Berufe starten mit Fahrzeug/Auftrag, Bauarbeiter-Auftrag komplett (Lohn $22 + XP, zu fruehes Ausloesen abgelehnt), Taxi komplett (Abholung, Absetzen, $62 + $14 Trinkgeld), **Teleport-Schutz** (1.091 Studs in 13,9 s abgelehnt), Unternehmen kaufen (Ortspruefung, Doppelkauf blockiert), Preisfaktor, Umsatzanteil, Laufkundschaft (nur aktiv), Ein-/Auszahlen (Ueberziehung abgelehnt), Verkauf an die Stadt, Anti-AFK im Payroll, Dashboard, Bus-Livery. Keine Fehler in der Konsole. Testdaten bereinigt (Unternehmen wieder zu verkaufen, Profil auf $490 / $2.415, Stufe 1, kein Beruf; Notaufnahme-Kosten durch einen Testunfall ausgeglichen; 2 Smoothies im Inventar verbleiben).

## 10. Bekannte Punkte

- **Mehrspieler nicht live getestet:** Bewerbung/Einstellung/Gehalt an andere Spieler, Rechnungen zwischen Spielern brauchen 2+ Spieler (Studio: Test → Server + 2 Clients).
- Paket-, Bus-, LKW- und Mechaniker-Auftraege wurden bis zum ersten Schritt getestet, nicht ganz durchgefahren.
- Fahrgaeste/Passagiere sind nicht als Figuren sichtbar (Meldungen statt NPC).
- Ein Frachtziel (Coral Key Hotels) fand keinen freien Platz und entfaellt.
- Unternehmen liegen im echten DataStore `MiamiState_Business_v1` – Studio-Tests betreffen echte Daten.
- Teleport-Versetzen von Fahrzeugen in Tests kann zu Unfallverletzungen fuehren (so ausgeloest: Spieler bewusstlos, behoben).
