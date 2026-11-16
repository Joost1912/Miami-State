# MIAMI STATE – Entwicklungsumgebung

Stand: 16.11.2026 · Status: **Einrichtung läuft** (Git, VS Code, Blender installiert; Roblox Studio fehlt noch)

## 1. Systemanalyse (geprüft)

| Komponente | Ergebnis |
|---|---|
| Betriebssystem | Windows 11 Pro 64-Bit, Build 26200 |
| CPU | AMD Ryzen 5 4500 (6 Kerne / 12 Threads) |
| RAM | 16 GB |
| GPU | NVIDIA GeForce RTX 4060 (Treiber 32.0.16.1742) |
| Freier Speicher C: | ca. 555 GB |
| Paketmanager | `winget` vorhanden |

Fazit: Die Hardware reicht für Roblox Studio, Blender und große Maps gut aus. 16 GB RAM sind bei sehr großen Places + Blender gleichzeitig die erste Grenze.

## 2. Werkzeuge – Ist-Zustand

| Werkzeug | Status | Hinweis |
|---|---|---|
| Roblox Studio | ❌ fehlt | Kein Eintrag unter `%LOCALAPPDATA%\Roblox` |
| Claude (Desktop-App inkl. Claude Code) | ✅ installiert | Store-Paket `Claude 5.11492`; Claude Code läuft in der App |
| `claude` CLI im Terminal | ❌ nicht im PATH | Nur nötig, wenn Claude Code auch außerhalb der App laufen soll |
| Git | ✅ installiert 16.11.2026 | 2.56.0 (winget), `C:\Program Files\Git` |
| GitHub Desktop | ✅ installiert | 3.6.7 |
| Visual Studio Code | ✅ installiert 16.11.2026 | 1.146.0 (winget, Benutzerinstallation) |
| Blender | ✅ installiert 16.11.2026 | 5.3 (winget), `C:\Program Files\Blender Foundation\Blender 5.3` |
| Python | ❌ fehlt | Nur der Windows-Store-Platzhalter (wird nicht benötigt) |
| Rojo / Rokit / Luau-Tools | ❌ fehlen | Optional, siehe Abschnitt 5 |

## 3. Installationsplan (offizielle Quellen)

Reihenfolge nach Wichtigkeit. Jede Installation erst nach Freigabe.

| # | Programm | Befehl (winget) | Offizielle Quelle |
|---|---|---|---|
| 1 | Roblox Studio | Installer von der Website (kein offizielles winget-Paket) | https://create.roblox.com/ → „Start Creating" |
| 2 | Git | `winget install --id Git.Git -e` | https://git-scm.com |
| 3 | Visual Studio Code | `winget install --id Microsoft.VisualStudioCode -e` | https://code.visualstudio.com |
| 4 | Blender | `winget install --id BlenderFoundation.Blender -e` | https://www.blender.org |
| 5 (optional) | Rokit (Toolmanager für Rojo, StyLua, Selene) | über GitHub-Release | https://github.com/rojo-rbx/rokit |

VS-Code-Erweiterungen (später): *Luau Language Server* (JohnnyMorganz), *StyLua*, *Selene*, *Rojo*.

## 4. Verbindung Claude ↔ Roblox Studio

**Gewählte Lösung: der offizielle, in Roblox Studio eingebaute MCP-Server.**
Doku: https://create.roblox.com/docs/studio/mcp

Warum: von Roblox selbst gepflegt, läuft lokal (stdio), kein Fremd-Plugin nötig. Das ältere `Roblox/studio-rust-mcp-server` und Community-Server wie `robloxstudio-mcp` sind damit nicht mehr nötig.

### Einrichtung (sobald Studio installiert ist)
1. Roblox Studio starten und anmelden, irgendeinen Place öffnen.
2. **Assistant** öffnen → **…** → **Manage MCP Servers** → **Enable Studio as MCP server** einschalten.
3. Unter **Quick connect** → **Claude Code** und/oder **Claude Desktop** aktivieren.
   Alternativ manuell in Claude Code registrieren (stdio-Server):
   `cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`
4. Claude-App neu starten.
5. Prüfen: In Studio zeigt der grüne Punkt die Zahl verbundener Clients; in Claude müssen Werkzeuge wie `execute_luau` und `get_studio_state` auftauchen.

### Was Claude damit kann
- Skripte lesen/bearbeiten/durchsuchen (`script_read`, `multi_edit`, `script_grep`)
- Objekte erstellen und ändern über Luau (`execute_luau`) → Gebäude, Straßen, Licht
- Spielbaum untersuchen (`search_game_tree`, `inspect_instance`)
- Playtests starten/stoppen, Konsole lesen, Screenshots (`start_stop_play`, `get_console_output`, `screen_capture`)
- Place speichern (`save_place`)

### Sicherheit
- MCP-Clients können offene Places lesen **und verändern** → nur vertrauenswürdige Clients verbinden.
- Vor größeren Umbauten Place-Kopie in `10_Backups` sichern bzw. Roblox-Versionsverlauf nutzen.
- Bei mehreren Studio-Fenstern immer das richtige über `list_roblox_studios` wählen.

## 5. Technische Empfehlungen

### Projektort (wichtig)
Das Projekt liegt in **OneDrive**. OneDrive-Synchronisierung und Git (`.git`-Ordner) vertragen sich schlecht (Sperrkonflikte, beschädigte Repos). Empfehlung: Projekt nach `C:\Dev\MIAMI STATE` verschieben und für Backups Git + GitHub (privates Repo) nutzen.

### Code-Workflow
- **Variante A (Start):** Skripte direkt in Studio, Claude bearbeitet sie über MCP. Einfach, sofort nutzbar.
- **Variante B (empfohlen ab Phase 2):** Rojo. Luau-Code liegt als Dateien in `02_Scripts`, wird in Studio synchronisiert → echte Git-Versionierung, Code-Reviews, Linting.

### Client/Server-Trennung (`02_Scripts`)
| Ordner | Roblox-Ziel | Inhalt |
|---|---|---|
| `Server/` | ServerScriptService | Spiellogik, Wirtschaft, Datenspeicherung, Anti-Cheat |
| `Client/` | StarterPlayerScripts | UI, Eingabe, Kamera, Effekte |
| `Shared/` | ReplicatedStorage | Konfiguration, Module, Remote-Definitionen |

Grundregel: Der Server ist die einzige Wahrheit (Geld, Inventar, Jobs, Fahrzeuge). Der Client sendet nur Wünsche über Remotes, der Server prüft alles.

## 6. Ordnerstruktur

```
MIAMI STATE/
├─ 01_Project        Place-Dateien (.rbxl), später Rojo-Projektdatei
├─ 02_Scripts        Luau-Code (Server / Client / Shared)
├─ 03_Maps           Stadtteile, Terrain, Layout-Planung
├─ 04_Models         Gebäude, Props, Blender-Quelldateien
├─ 05_Vehicles       Fahrzeugmodelle und Fahrphysik
├─ 06_UI             UI-Entwürfe und Assets
├─ 07_Sounds         Eigene Sounds und Lizenznachweise
├─ 08_Textures       Texturen und Materialien
├─ 09_Documentation  Entscheidungen, Pläne, Anleitungen
└─ 10_Backups        Sicherungen von Places/Modellen
```
