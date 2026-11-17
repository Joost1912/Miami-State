-- LOTT E-Scooter-Sharing (Prompt 13). Einzige Quelle fuer Preise und Regeln - der Server rechnet nur hiermit.
local L = {}

L.Brand = "LOTT"
L.Color = Color3.fromRGB(0, 214, 160) -- LOTT-Mint
L.PricePerMinute = 50 -- $ pro angefangener Minute
L.RentRange = 12 -- Studs: Miete nur direkt am Roller
L.MaxHistory = 10
L.ListRefresh = 4 -- Sekunden: Aktualisierung der Live-Karte in der App (nur solange die App offen ist)

-- Abrechnung: Jede angefangene Minute wird zu Beginn der Minute serverseitig abgebucht (Vorauszahlung).
-- Reicht das Geld fuer die naechste Minute nicht, endet die Miete automatisch - es entstehen keine Schulden.
-- Verbindungsabbruch: Miete endet sofort, bereits bezahlte Minute verfaellt, nichts wird nachberechnet.
L.Rules = {
	"50 $ pro angefangener Minute - Abbuchung jeweils zu Beginn der Minute.",
	"Beispiel: 2 Min 10 s = 3 angefangene Minuten = 150 $.",
	"Reicht dein Geld fuer die naechste Minute nicht, endet die Miete automatisch (keine Schulden).",
	"Absteigen beendet die Miete nicht - beenden ueber die LOTT-App oder am Roller.",
	"Spiel verlassen beendet die Miete sofort.",
}

return L
