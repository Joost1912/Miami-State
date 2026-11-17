-- Fahrzeughandel (Prompt 10): Modelle, Preise, Autohaeuser, Tuning-Optionen.
-- Abgerechnet wird NUR mit diesen Serverwerten. Model = Vorlage ServerStorage.Vehicles.Vehicle_<Model>.
local rgb = Color3.fromRGB
local V = {}

V.MaxOwned = 8 -- Fahrzeuge pro Spieler
V.SellFactor = 0.6 -- Rueckkauf durch das Autohaus (Anteil vom Kaufpreis)
V.TestDriveSeconds = 90
V.RecallFee = 250 -- Abschleppen/Zurueckrufen eines ausgeparkten Fahrzeugs aus der Ferne
V.FuelPricePerPercent = 2 -- $ pro Prozent Tankfuellung
V.FuelPerStud = 0.0035 -- Prozent Verbrauch pro gefahrenem Stud (Faktor je Modell: Thirst)

-- Haendler: Kind "Standard" | "Luxury"
V.Dealers = {
	Standard = { Name = "Sawgrass Motors", Subtitle = "Alltagsfahrzeuge, SUVs und Pickups - Sawgrass Park", Color = rgb(64, 200, 255) },
	Luxury = { Name = "Bayfront Prestige", Subtitle = "Sportwagen, Luxuslimousinen und Supersportwagen - Downtown", Color = rgb(220, 180, 90) },
	-- Prompt 12: Flagship-Showroom auf dem Sawgrass-Motors-Gelaende, komplettes Sortiment beider Haendler
	Gallery = { Name = "Miami Motor Gallery", Subtitle = "Alle Klassen: Alltag, SUV, Pickup, Muscle, Luxus, Sport, Supersport", Color = rgb(64, 224, 255) },
}

-- Katalog (Reihenfolge = Anzeige). Class nur zur Anzeige.
-- Drive = Antrieb (Anzeige); Werte fuer Beschleunigung/Handling berechnet der Server aus der Vorlage (Torque/Mass/MaxSteer)
V.Models = {
	{ Id = "Compact", Name = "Volta C1", Class = "Alltagsfahrzeug", Dealer = "Standard", Price = 9500, Thirst = 0.7, Drive = "Frontantrieb", Desc = "Sparsamer Stadtflitzer fuer den Alltag." },
	{ Id = "Sedan", Name = "Meridian Sedan", Class = "Alltagsfahrzeug", Dealer = "Standard", Price = 18500, Thirst = 1.0, Drive = "Frontantrieb", Desc = "Solide Mittelklasse-Limousine mit Platz fuer vier." },
	{ Id = "SUV", Name = "Everglade SUV", Class = "SUV", Dealer = "Standard", Price = 32000, Thirst = 1.3, Drive = "Allrad", Desc = "Gelaendegaengiger Familien-SUV." },
	{ Id = "Pickup", Name = "Gulf Hauler", Class = "Pickup", Dealer = "Standard", Price = 29500, Thirst = 1.4, Drive = "Allrad", Desc = "Robuster Pickup mit grosser Ladeflaeche." },
	{ Id = "Muscle", Name = "Bayou Thunder", Class = "Muscle Car", Dealer = "Standard", Price = 64000, Thirst = 1.8, Drive = "Heckantrieb", Desc = "V8-Klassiker mit Rennstreifen und Hutzen - laut und stolz." },
	{ Id = "LuxurySedan", Name = "Aurelia S", Class = "Luxuslimousine", Dealer = "Luxury", Price = 78000, Thirst = 1.1, Drive = "Heckantrieb", Desc = "Chrom, Leder, Stille - die Chefetage auf Raedern." },
	{ Id = "LuxurySUV", Name = "Regent X", Class = "SUV", Dealer = "Luxury", Price = 96000, Thirst = 1.4, Drive = "Allrad", Desc = "Grosser Premium-SUV mit Dachreling und Chrompaket." },
	{ Id = "Sports", Name = "Vento GT", Class = "Sportwagen", Dealer = "Luxury", Price = 125000, Thirst = 1.5, Drive = "Heckantrieb", Desc = "Leichtes Coupe mit Heckspoiler." },
	{ Id = "Convertible", Name = "Riviera Spyder", Class = "Sportwagen", Dealer = "Luxury", Price = 148000, Thirst = 1.4, Drive = "Heckantrieb", Desc = "Offenes Cabrio fuer den Ocean Drive." },
	{ Id = "Supercar", Name = "Apex R", Class = "Supersportwagen", Dealer = "Luxury", Price = 285000, Thirst = 2.0, Drive = "Allrad", Desc = "Flach, breit, schnell - das Topmodell." },
}
V.ById = {}
for _, m in ipairs(V.Models) do
	V.ById[m.Id] = m
end
-- Startfahrzeug (bestehende Profile): Wiederverkaufswert gering
V.StarterValue = 3000

-- Lackfarben (Index wird gespeichert)
V.Paints = {
	{ Name = "Polarweiss", C = rgb(240, 240, 238) }, { Name = "Obsidian", C = rgb(20, 20, 22) }, { Name = "Silber", C = rgb(160, 164, 170) },
	{ Name = "Graphit", C = rgb(70, 74, 80) }, { Name = "Ozeanblau", C = rgb(30, 60, 110) }, { Name = "Miami Tuerkis", C = rgb(40, 190, 200) },
	{ Name = "Flamingo", C = rgb(240, 110, 150) }, { Name = "Rosso", C = rgb(170, 20, 28) }, { Name = "Sunset Orange", C = rgb(240, 120, 40) },
	{ Name = "Limette", C = rgb(150, 210, 60) }, { Name = "Everglades Gruen", C = rgb(40, 90, 70) }, { Name = "Champagner", C = rgb(200, 180, 140) },
	{ Name = "Violett", C = rgb(100, 60, 160) }, { Name = "Gelb", C = rgb(240, 200, 40) },
}
V.PaintPrice = 1200

-- Optische Tuningteile: Kategorie -> Optionen (Index 1 = Serie, kostenlos)
V.Tuning = {
	Rims = { Title = "Felgen", Options = {
		{ Name = "Serie", Price = 0 }, { Name = "Chrom", Price = 1800, C = rgb(220, 224, 230), M = "Metal" },
		{ Name = "Schwarz matt", Price = 1500, C = rgb(25, 25, 28), M = "SmoothPlastic" }, { Name = "Gold", Price = 3200, C = rgb(212, 175, 55), M = "Metal" },
		{ Name = "Bronze", Price = 2400, C = rgb(150, 100, 60), M = "Metal" },
	} },
	Tint = { Title = "Scheibentoenung", Options = {
		{ Name = "Serie", Price = 0 }, { Name = "Leicht", Price = 600, T = 0.35 }, { Name = "Dunkel", Price = 900, T = 0.15 }, { Name = "Limousine", Price = 1300, T = 0.03 },
	} },
	Underglow = { Title = "Unterbodenbeleuchtung", Options = {
		{ Name = "Aus", Price = 0 }, { Name = "Tuerkis", Price = 2500, C = rgb(40, 230, 255) }, { Name = "Pink", Price = 2500, C = rgb(255, 60, 180) },
		{ Name = "Violett", Price = 2500, C = rgb(150, 70, 255) }, { Name = "Weiss", Price = 2500, C = rgb(240, 240, 255) },
	} },
	Lights = { Title = "Scheinwerfer", Options = {
		{ Name = "Serie", Price = 0 }, { Name = "Xenon blau", Price = 900, C = rgb(170, 210, 255) }, { Name = "Gelb", Price = 700, C = rgb(255, 214, 120) },
	} },
}
V.TuningOrder = { "Rims", "Tint", "Underglow", "Lights" }

return V
