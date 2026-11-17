# Code-Export aus Roblox Studio (2026-11-17)

## Quelle

- **Quelle des Exports: Roblox Studio** (Place 122392352890697, Universe 10777124772, Place-Version **54**, Edit-Modus).
- Datum: 2026-11-17. In Studio wurde nichts veraendert (nur `Source` gelesen; Uebertragung per HttpService-POST an einen temporaeren lokalen Empfaenger auf `localhost:34872`).
- Studio ist die neueste Quelle: Prompt 08 (Laeden, Waffen, Kleidung, Verdichtung) und Prompt 09 (Kriminalitaet) wurden direkt in Studio entwickelt und existierten bis zu diesem Export nur dort.

## Inhalt von `02_Scripts`

| Studio | Repo |
|---|---|
| `ReplicatedStorage.MiamiShared` (inkl. generierte `Config.MapGeo`, `Config.MapExtra`) | `Shared/`, `Shared/Config/` |
| `ServerScriptService.MiamiServer.Main` / `.Services/*` | `Server/Main.server.luau`, `Server/Services/` |
| `ServerScriptService.DayNightController`, `.TrafficSignalController` | `Server/<Name>.server.luau` |
| `StarterPlayerScripts.MainClient` / `.Controllers/*` | `Client/MainClient.client.luau`, `Client/Controllers/` |
| `StarterPlayerScripts.VehicleClient`, `.VehicleEffects` | `Client/<Name>.client.luau` |
| `StarterCharacterScripts.Health` (leeres Skript, schaltet Regeneration ab) | `Character/Health.server.luau` |
| `ServerStorage.MapBuildTools` (MapKit, Runner, ShopKit, InfillKit) | `MapBuild/` |

67 Skripte aus Studio = 67 exportierte Dateien (Byte-Laengen beim Export bestaetigt, alle LF).

Nicht exportiert: 11 identische Roblox-Standard-`Animate`-LocalScripts in NPCs unter `Workspace.Map` (Teil der Map, kein Projektcode).

Aus dem alten lokalen Repo `C:\Dev\MIAMI STATE` (Commit b8eb452) uebernommen, weil es sie in Studio nicht gibt: `MapBuild/Steps/*.luau` (01–24), `MapBuild/VehicleKit.luau`, `MapBuild/serve.ps1` (Pfad jetzt `Miami-State\02_Scripts`), Berichte `02_`–`08_Phase7_*`.

## WARNUNG: Bau-Schritte 17_Vehicles / 18_Gameplay

`MapBuild/Steps/17_Vehicles.luau` und `18_Gameplay.luau` (auch `13_Night`, `22_MapExport`) **installieren Skripte aus dem Repo in Studio und ueberschreiben dabei die Studio-Fassung**. Sie duerfen nur nach diesem Abgleich und nur mit diesem Repo-Stand ausgefuehrt werden.

**Nachtrag Prompt 10:** Die Modullisten in `18_Gameplay` wurden um alle Module aus Prompt 08–10 ergaenzt; seither ist Studio wieder = Repo (75 Skripte). Der folgende Absatz beschreibt den Stand vor dieser Korrektur.

Urspruenglich galt: `18_Gameplay` kannte nur die Modulliste von Phase 7. Die Module aus Prompt 08/09 fehlen dort (`Config.Clothing`, `Config.Crime`, `Config.MapGeo`/`MapExtra`, `WeaponService`, `ClothingService`, `WantedService`, `CrimeService`, Controller `WeaponHud`, `Crime`). Da der Schritt `MainClient` komplett neu anlegt, wuerden die Controller `WeaponHud` und `Crime` verloren gehen. **18_Gameplay vor einem erneuten Lauf um diese Module erweitern.**
