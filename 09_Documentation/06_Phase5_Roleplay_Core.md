# MIAMI STATE – Phase 5: Core-Roleplay-System – Abschlussbericht

Stand: 16.11.2026 · Place gespeichert, **nicht veröffentlicht**. Keine kostenpflichtigen Aktionen.

## 1. Ausgangsanalyse

Vorhanden waren 3 Server-Skripte (Ampeln, Tag-Nacht, Fahrzeuge), 2 Client-Skripte (Fahrzeugsteuerung, Blaulicht),
keine Spielerdaten, keine Remotes, keine Teams. Wiederverwendet statt neu gebaut:
Fahrzeug-Spawnpunkte (`RequiredJob`-Attribut), Laden-Marker (`ShopEntrance` ×3, `StoreEntrance` ×41), Fahrzeugsystem.

## 2. Architektur

```
ReplicatedStorage.MiamiShared            gemeinsame Konfiguration + UI (nur lesen)
  Config/Economy, Factions, Items, Shops
  Format, UI (Design-System)
ReplicatedStorage.MiamiRemotes           Request (RemoteFunction), Push (RemoteEvent) – vom Server erzeugt
ServerScriptService.MiamiServer
  Main                                   Start + EIN Anfrage-Endpunkt mit Validierung
  Services/DataService                   Laden/Speichern, Session-Lock, Autosave
  Services/EconomyService                Bargeld, Bank, Überweisung, Doppel-Schutz, Kontoverlauf
  Services/InventoryService              Inventar, Nutzungs-Handler (erweiterbar)
  Services/JobService                    Fraktionen, Ränge, Dienst, Berechtigungen, Teams
  Services/PayrollService                Gehaltszahlungen
  Services/CharacterService              Charaktererstellung, Textfilter, Aussehen, Namensschild
  Services/InteractionService            einheitliche Interaktion (Tag "Interactable")
  Services/ShopService                   Einkauf mit Serverpreisen
ServerScriptService.VehicleService       (bestehend) jetzt mit Berufsprüfung
StarterPlayerScripts.MainClient          Client-Einstieg + Controllers: Hud, CharacterCreator, Profile,
                                         Bank, Inventory, Jobs, Shop, Interact
```

Quellcode: `02_Scripts/Shared`, `02_Scripts/Server`, `02_Scripts/Client`; Installation in Studio: Bauschritt `18_Gameplay`.

**Sicherheitsprinzipien**
- Clients senden nur Wünsche an `Request(action, payload)`; der Server prüft Rate-Limit (Token-Bucket), Profil, Aktion, Typen, Wertebereiche, Ort/Abstand.
- Geld, Inventar, Beruf werden **nur** im Server über `DataService.Mutate` geändert (ohne Yield → atomar).
- Anzeigewerte gehen als Spieler-Attribute an die Clients; lokale Änderungen daran haben keine Wirkung (getestet).
- Jede Geldbuchung mit Client-Bezug trägt eine Transaktions-ID; bereits gesehene IDs werden verworfen.
- Preise, Gehälter, Ränge kommen ausschließlich aus der Server-Konfiguration.
- Namen und Verwendungszwecke laufen durch den Roblox-Textfilter.

## 3. Datenspeicherung

- DataStore `MiamiState_Players_v1`, Schlüssel `Player_<UserId>`, nur `UpdateAsync`.
- **Session-Lock:** Beim Laden wird `Meta.Session = {JobId, Time}` gesetzt. Hält ein anderer Server das Profil, wird gewartet (max. 5 Versuche), sonst Kick mit Hinweis – verhindert Duplikate beim Serverwechsel. Verwaiste Locks verfallen nach 10 Min.
- Speichern: Autosave alle 120 s (nur geänderte Profile), beim Verlassen (Lock wird freigegeben), beim Herunterfahren (`BindToClose`, parallel, max. 25 s). Speichern verwirft, wenn der Lock verloren ging.
- Fehler: 4 Wiederholungen mit Backoff, Request-Budget wird beachtet; schlägt das Laden fehl, wird der Spieler mit Hinweis gekickt (statt mit leerem Profil zu spielen und Daten zu überschreiben).
- Datenschema (Version 1): `Character`, `Money{Cash,Bank,History}`, `Job{Faction,Rank,OnDuty}`, `Inventory{Items}`, `Vehicles{Owned}`, `Properties{Owned}`, `Stats`, `Meta`. Fehlende Felder werden beim Laden ergänzt; Migrationen über `migrate()`.
- Studio ohne API-Zugriff: Ersatzspeicher im Arbeitsspeicher, deutlich in der Konsole gekennzeichnet.

## 4. Systeme und Benutzeroberflächen

| System | Status |
|---|---|
| Charaktererstellung (Vor-/Nachname, Geschlecht, Jahrgang, Hautton, Größe, Statur) | ✅ |
| Spielerprofil (Taste P) | ✅ |
| Geldanzeige (HUD: Bargeld, Bank, Beruf) | ✅ |
| Bank am Geldautomaten: Übersicht + Kontoverlauf, Einzahlen, Abheben, Überweisen | ✅ |
| 11 Geldautomaten (Rathaus, Bayside Market, Sawgrass Center, 3 Tankstellen, 2× Coral Key, Hafen, Starlight District, Bank of Sawgrass) | ✅ |
| Inventar (Taste I): 14 Gegenstände in 8 Kategorien, benutzen, entfernen, Stapel- und Platzlimit | ✅ |
| Läden: Tankstellen-Shops, Supermarkt, Apotheke, Elektronik, Werkzeug, Cafés (über vorhandene Laden-Marker) | ✅ |
| Berufe (Taste J): 4 Fraktionen, 18 Ränge, Dienst an/aus, Fraktion verlassen, Verwaltung für Admin/Leitung | ✅ |
| Jobcenter am Rathaus (NPC) | ✅ |
| Gehalt nach Fraktion + Rang (Einsatzkräfte nur im Dienst), alle 10 Min. aufs Konto | ✅ |
| Einsatzfahrzeuge nur für passende Fraktion im Dienst | ✅ |
| Spielerinteraktion (Taste X): Spieler ansehen, Bargeld geben; Ausweis zeigen | ✅ (Einzelspieler geprüft, s. u.) |
| Türen (Interaktionstyp „Door“), NPC-Dialoge | ✅ Logik vorhanden, noch keine Türen in der Welt (Innenräume folgen) |

Neue Interaktionen: Objekt taggen (`Interactable`) + Attribut `InteractType` setzen, Handler mit `InteractionService.Register` – fertig.

## 5. Tests (Play-Modus in Studio)

| Test | Ergebnis |
|---|---|
| Charaktererstellung: 7 ungültige Eingaben abgelehnt, gültige angelegt, doppelte Erstellung blockiert | ✅ |
| Aktionen vor Charaktererstellung gesperrt | ✅ |
| Einzahlen/Abheben korrekt; ohne Automat abgelehnt | ✅ |
| Doppelte Transaktions-ID verworfen | ✅ |
| Negativ, Kommazahl, NaN, 1e12, Text als Betrag, zu wenig Geld | ✅ abgelehnt |
| Bargeld lokal auf 999.999 manipuliert → Server ignoriert | ✅ |
| Inventar: benutzen, heilen (60 → 80 HP), verbrauchen, entfernen, unbekannte/fehlende Gegenstände | ✅ |
| Shop: bar und per Karte; zu weit weg, falscher Laden, nicht im Sortiment, Anzahl 50, Zahlungsart „Free“, Stapellimit | ✅ |
| Nicht-Admin macht sich selbst zum Chief / erfindet Fraktion / fälscht Fraktions-Attribut | ✅ abgelehnt |
| Admin-Zuweisung, Team, Dienst, Namensschild, Gehaltslauf (+$300) | ✅ |
| Polizeiauto außer Dienst gesperrt, im Dienst erlaubt | ✅ |
| Überweisung und Bargeldübergabe zwischen zwei Profilen, Duplikat, Deckung | ✅ (zweites Profil serverseitig simuliert) |
| Unbekannte Aktionen, falsche Typen, Selbstüberweisung, unbekannte Spieler | ✅ abgelehnt |
| Rate-Limit: 15 von 30 Sofort-Anfragen gebremst | ✅ |
| Speichern mit Session-Lock | ✅ (Ersatzspeicher) |
| UIs: Charaktererstellung, Inventar, Berufe, Bank per ATM-Prompt, HUD, Namensschild | ✅ Screenshots geprüft |
| Konsole | keine Fehler |

**Behobene Fehler während der Tests:** Menü-Umschalten per Taste setzte den Zustand nicht zurück; Charaktererstellung
blieb offen, wenn der Charakter anders angelegt wurde; Laden-Marker hätten doppelte Prompt-Handler bekommen;
Kontoverlauf-Bezeichnungen vereinheitlicht.

## 6. Offene Punkte

| Punkt | Grund / nächster Schritt |
|---|---|
| **Echtes Speichern + Laden nach Neubeitritt** | Studio hat keinen API-Zugriff. **Bitte aktivieren:** Studio → *Datei → Spieleinstellungen → Sicherheit → „Studio-Zugriff auf API-Dienste aktivieren“*. Danach Test: Charakter anlegen → Test stoppen → neu starten → Daten müssen geladen werden. |
| **Test mit mehreren echten Spielern** | Über MCP nur Einzelspieler möglich. In Studio: *Test → Clients und Server → 2 Spieler → Starten*, dann Geld geben (X), Überweisen am ATM. |
| Überweisungen nur an Spieler auf demselben Server | Serverübergreifend später über MessagingService/DataStore |
| Admin in Studio automatisch | Live: nur Projektinhaber + `JobService.Admins` |
| Kleidung/Uniformen | Charakter übernimmt Avatar-Kleidung; Uniformen pro Fraktion in eigener Phase |
| Namen nur mit Buchstaben A–Z | Umlaute können später ergänzt werden |

## 7. Empfohlene nächste Systeme

1. Persistenz-Test mit API-Zugriff + Mehrspieler-Test (s. o.)
2. Fahrzeugbesitz: Autohaus „Sawgrass Motors“ (Kauf, Schlüssel im Inventar, Garage/Abschleppen) – Grundlage `Vehicles.Owned` vorhanden
3. Tankstellen-System (Zapfsäulen sind bereits getaggt) + Kraftstoffverbrauch
4. Polizeisystem: Handschellen, Durchsuchen, Festnahme, Funk, Fahndung (Berechtigungen existieren)
5. EMS: Verletzungen/Bewusstlosigkeit, Behandlung, Krankenhaus; Feuerwehr: Brandeinsätze
6. Uniformen und Dienstausrüstung je Fraktion, Innenräume (Wachen, Bank) mit Türen
