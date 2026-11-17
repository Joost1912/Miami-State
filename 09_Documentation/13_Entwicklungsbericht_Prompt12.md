# Entwicklungsbericht Prompt 12 – Autohaus, Interaktionen, Nachrichten, Telefon, Stadt, Stabilitaet

Stand: 2026-11-17 · Place 122392352890697, gesichert als Version 69 (nicht veroeffentlicht) · Studio = Repo: 83/83 Skripte byte-identisch.
Ehrliche Kennzeichnung: **fertig + getestet**, **fertig, nur teilweise getestet**, **offen**.

## 0. Pruefung des Bestands (vor den Aenderungen)

- Spieltest: alle 19 Menues (Inventar, Profil, Berufe, Handy, Karte, Notruf, Dienst, Funk, Interaktion, Bank, Autohaus, Garage, Tuning, Immobilien, 5 Arbeitsreiter, Shop, Rettung, MDT, Polizei) geoeffnet – keine Fehler/Warnungen in der Konsole.
- Welt: ca. 58.000 Teile, 1.498 Lichter (keins mit Schatten), 12 NPC-Humanoide, StreamingEnabled (Radius 1024).
- Fehlte: Nachrichten (nur „kommt bald“), Telefon, NPC-Verkehr, Passanten; Interaktionsmenue nur Ausweis/Geld/Kontakt/Polizei.

## 1. Behobene Fehler

| Fehler | Auswirkung | Behebung |
|---|---|---|
| Fahrzeugkauf: Geld abgebucht, bevor das Fahrzeug eingetragen ist | bei Fehler Geldverlust | Eintragung geprueft, sonst automatische Erstattung |
| Fahrzeugkauf: Transaktions-ID vor der Kontopruefung verbraucht | erneuter Versuch nach Aufladen blockiert | Pruefung vor dem Verbrauch |
| Fahrzeuglimit nur vor der Zahlung geprueft | Wettlauf bei Doppelanfrage | zusaetzlich in der Eintragung |
| Telefonnummer fehlte bei frueh geladenen Profilen | leere Nummer | Nachholen beim Dienststart |
| Neues Autohaus ueberlappte einen Nachbarschaftspark (gefunden per Kollisionspruefung) | Gebaeude ineinander | Standort auf freie Flaeche verlegt, 0 Ueberschneidungen |

## 2. Modernes Autohaus – **fertig + getestet**

*Miami Motor Gallery* auf dem Sawgrass-Motors-Gelaende (freie Flaeche, Park bleibt): Glasfassade mit Pfosten, Vordach mit Lichtkante, Leuchtschild + Pylon, heller Innenraum (Marmorboden, Flaechenleuchten, Spots), Empfangstheke, 3 verglaste Verkaufsbueros mit Stuehlen, Lounge mit Kaffeebar, Pflanzen, 5 Mitarbeiter-NPCs (bestehendes NPC-Modell), 7 Fahrzeuge auf beleuchteten Drehtellern, 6 Fahrzeuge draussen mit Preisschildern, Fahnen, Laternen, Kundenparkplaetze, Probefahrtplatz, Garagen-Terminal.
- Klassen: Alltagsfahrzeuge, SUVs, Pickups, **Muscle Car (neu: Bayou Thunder)**, Luxuslimousine, Sportwagen, Supersportwagen – alle 10 Modelle im Gallery-Katalog.
- Kaufmenue: Name, Klasse, Preis, Hoechstgeschwindigkeit, Beschleunigung 0–100, Handling, Antrieb, Verbrauch, Beschreibung, Lackwahl, **360°-Vorschau** (Kamera umkreist das Ausstellungsfahrzeug, Lack wird live umgefaerbt), Zahlung **Bargeld oder Bank**, Bestaetigungsfenster mit Abbrechen, Kaufbeleg mit Kennzeichen und „Zur Garage“.
- Verbunden mit bestehendem Geld, Profil (Speicherung), Garage, Kennzeichen/MDT und Unternehmen (Provision an Sawgrass Motors/Bayfront Prestige).
- Getestet: Katalog (10 Modelle mit Werten), Kauf mit Bargeld ($100.000 → $36.000), Fahrzeug in der Garage mit Kennzeichen, Verkauf, Ausstellungsmodelle fuer die Vorschau beim Client vorhanden. Die Vorschau-Schaltflaeche selbst wurde **nicht per Klick** ausgeloest (Klick-Automatisierung traf das Fenster nicht).
- Grenzen: Fahrzeuge sind die vorhandenen Teile-Modelle und ihre Varianten (keine fremden Marken); detaillierte Innenraeume/realistische Mesh-Modelle waeren Asset-Arbeit (eigene 3D-Modelle oder lizenzierte Assets) – **offen**.

## 3. Spielerinteraktionen – **fertig, Einzelspieler getestet**

Interaktionsmenue (Taste X) zeigt je nach Situation: Begruessen (Wink-Emote), Ansprechen, Hand schuetteln (Anfrage, beide drehen sich zueinander), Um Hilfe bitten, Kontaktdaten tauschen (beidseitig), Anrufen, Nachricht schreiben, In Wohnung einladen (nur mit eigener Wohnung), Geld geben, Geld anfordern (der andere bestaetigt und zahlt bar). Polizei/EMS-Bereiche bleiben. NPC-Dialoge, Tueren, Sitze laufen weiter ueber die bestehenden Prompts.
Serverseitig (`SocialService`): Abstand, Spam-Sperre, max. 5 offene Anfragen, Ablauf nach 45 s. Getestet: Fehlerwege (kein Spieler, zu weit). **Mit zwei Spielern nicht getestet.**

## 4. Nachrichten – **fertig, Einzelspieler getestet**

Handy-App NACHRICHTEN: Chatliste mit Avatar, Vorschau, Uhrzeit, Ungelesen-Zaehler (auch am App-Symbol), neuer Chat ueber Kontakte oder Nummer, Chatblasen mit Zeitstempel, Stummschalten, Loeschen, dezente Benachrichtigung. Server (`CommsService`): Absender immer der echte Spieler, 1–200 Zeichen, max. 5 Nachrichten/10 s, **Roblox-Textfilter (PrivateChat)**, gespeichert wird nur der gefilterte Text (max. 30 Chats × 50 Nachrichten). Zustellung nur an Spieler auf demselben Server (Profile anderer Server sind gesperrt) – Offline-/Serveruebergreifend **offen**.

## 5. Telefon – **fertig, Einzelspieler getestet**

Eigene Nummer (305-xxx-xxxx, dauerhaft), Kontakte mit Favoriten, Waehlen per Nummer, Anrufverlauf, Anruffenster (eingehend: Annehmen/Ablehnen; ausgehend: Klingeln/Auflegen; aktiv: Gespraechsdauer/Auflegen), besetzt, verpasste Anrufe mit Hinweis und Zaehler, 25 s Klingeln.
**Sprache:** echte Verbindung nur ueber die Roblox Audio API (Mikrofon eines Spielers → Ausgabe nur beim anderen), wenn `VoiceChatService.UseAudioApi` aktiv ist und Voice Chat verfuegbar ist. In diesem Place ist sie **nicht aktiv** – Anrufe funktionieren ohne Sprache (keine vorgetaeuschte Sprache). Die Sprachweiterleitung ist **ungetestet**.

## 6. Stadt – **teilweise**

- Neu: clientseitiger **NPC-Verkehr** (10 Autos auf dem Strassengraph der Karte, Rechtsverkehr, halten vor Spielern/Fahrzeugen/einander) und **Passanten** (12, laufen zwischen Ladeneingaengen), abschaltbar im Handy (Einstellungen → „NPC-Verkehr & Passanten“), pausiert in Innenraeumen. Getestet: laeuft (10/12 aktiv), keine Fehler. Bekannt: auf Boulevards mit Mittelstreifen fahren einige Autos zu weit innen (fester Spurabstand).
- Downtown: 39 Strassenmoebel (Baenke mit Sitzfunktion, Blumenbeete, Muelleimer) und 6 Strassenimbisse (Hot Dog, Tacos, Limonade – bestellbar) auf freien Gehwegstellen (Kollisionspruefung).
- **Karte verkleinern: nicht umgesetzt.** Analyse: Stadtflaeche ca. 7.400 × 5.800 Studs; grosse Freiflaechen vor allem Sawgrass Park (Office/Public Parking je ca. 520 × 550, Gewerbe-Lots bis 540 × 730). Eine Verkleinerung bedeutet, ganze Viertel zu verschieben; viele Systeme haben feste Koordinaten (Stadtteile, Kartenexport, Depots, Unternehmen, Wohnungs- und Venue-Eingaenge, Haltestellen). Das ist ohne Risiko fuer bestehende Funktionen nicht in diesem Durchgang machbar – Entscheidung/Planung **offen**.

## 7. Design – **teilweise**

Alle Fenster (`UI.window`) skalieren sich jetzt automatisch auf kleine Aufloesungen (min. 55 %), Benachrichtigungen passen sich schmalen Bildschirmen an; Interaktionsmenue immer scrollbar; neue Menues im bestehenden dunklen Stil. Eine komplette Ueberarbeitung aller alten Menues wurde nicht gemacht.

## 8. Performance – **teilweise**

Neue Systeme ohne Serverlast (Verkehr/Passanten lokal, 30 Hz, Umkreis-begrenzt, ohne Schatten/Kollision); Fahrzeuganzeige/Uhr bereits gedrosselt (Prompt 10); Innenraeume ausserhalb des Streaming-Radius. Keine grossflaechige Reduktion bestehender Teile/Lichter vorgenommen (1.498 Lichter, alle ohne Schatten – vertretbar). Empfehlung fuer spaeter: `Workspace.StreamOutBehavior = Opportunistic` fuer schwache Geraete pruefen.

## 9. Neue / geaenderte Skripte

Neu: `Server/Services/CommsService.luau`, `SocialService.luau`, `Client/Controllers/PhoneComms.luau`, `Traffic.luau`, `MapBuild/Steps/27_Prompt12.luau`.
Geaendert: `DealershipService` (Gallery, Zahlart, Werte, Kauf-Fehler), `Config/Vehicles` (Muscle, Antrieb, Gallery), `Client/Controllers/Vehicles` (Kaufmenue, Vorschau), `Interact` (Spieleraktionen, Anfragen), `Phone` (Badges, Helpers, Einstellung Verkehr, Apps), `Activity` (Emotes), `Shared/UI` (Skalierung), `PhoneService` (Nummer am Kontakt, Einstellung), `DataService` (Phone.Number/Chats/Calls, Settings.Traffic), `Main` (Services), `MainClient`, Configs `Shops`/`Items`/`MapExtra`, Bauschritt `18_Gameplay`.

## 10. Tests

Erfolgreich (Studio, ein Spieler): Menues/Konsole fehlerfrei, Autohaus betreten, Katalog, Kauf (Bargeld), Abzug korrekt, Garage, Kennzeichen, Verkauf, Ausstellung beim Client, Verkehr/Passanten aktiv, Telefonnummer, Chat-/Anruf-Fehlerwege, Studio = Repo. Testdaten bereinigt (Profil $490/$2.415, Testfahrzeug verkauft).
**Nicht getestet:** alles mit zwei oder mehr Spielern (Nachrichten zustellen, Anrufe annehmen/beenden, Handschlag, Geld anfordern, Kontakte tauschen) – Studio-Mehrspielertest (Test → Server + 2 Clients) ist ueber die Automatisierung nicht startbar und muss manuell erfolgen; Sprachweiterleitung; Vorschau-Klick.
