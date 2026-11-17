-- Kartendaten fuer Leitstellen-/MDT-Karte und Standortbestimmung (deckungsgleich mit den Bauschritten).
local MapData = {}

MapData.Bounds = { X0 = -4400, X1 = 3000, Z0 = -3000, Z1 = 2800 }

-- Reihenfolge = Prioritaet bei Ueberschneidung
MapData.Districts = {
	{ Name = "Coconut Heights", X0 = -1900, X1 = -700, Z0 = -2600, Z1 = -1000, Color = Color3.fromRGB(90, 170, 110) },
	{ Name = "Starlight District", X0 = -320, X1 = 1000, Z0 = -2200, Z1 = -1400, Color = Color3.fromRGB(200, 90, 200) },
	{ Name = "Midtown", X0 = -320, X1 = 1000, Z0 = -1400, Z1 = -1000, Color = Color3.fromRGB(110, 130, 200) },
	{ Name = "Bayfront Downtown", X0 = -320, X1 = 1000, Z0 = -1000, Z1 = 1000, Color = Color3.fromRGB(70, 140, 230) },
	{ Name = "Port Meridian", X0 = -320, X1 = 1000, Z0 = 1000, Z1 = 2600, Color = Color3.fromRGB(200, 140, 60) },
	{ Name = "Sawgrass Park", X0 = -4300, X1 = -700, Z0 = -2600, Z1 = 2300, Color = Color3.fromRGB(120, 180, 90) },
	{ Name = "Palmetto Bay", X0 = 1000, X1 = 1800, Z0 = -2800, Z1 = 2800, Color = Color3.fromRGB(30, 90, 120) },
	{ Name = "Coral Key", X0 = 1800, X1 = 2800, Z0 = -2800, Z1 = 2800, Color = Color3.fromRGB(240, 200, 120) },
}

-- Hauptstrassen (fuer die Kartenzeichnung)
MapData.Roads = {
	-- Nord-Sued
	{ -520, -2900, -520, 2500, "Highway" }, { 880, -2600, 880, 1000, "Boulevard" }, { 80, -2200, 80, 1000, "Boulevard" },
	{ -320, -2200, -320, 2500, "Street" }, { 480, -2200, 480, 1200, "Street" }, { 2300, -2500, 2300, 2500, "Boulevard" },
	{ 1960, -2500, 1960, 2500, "Street" }, { -3000, -2400, -3000, 2200, "Boulevard" }, { -2400, -2400, -2400, 2200, "Street" },
	{ -3600, -2400, -3600, 2200, "Street" }, { -4200, -2400, -4200, 2200, "Street" }, { -1300, -2400, -1300, 2200, "Street" },
	{ -1900, -2400, -1900, 2200, "Street" }, { -700, -2400, -700, 2200, "Street" },
	-- Ost-West
	{ -4200, -1000, 880, -1000, "Boulevard" }, { -4200, -200, 1000, -200, "Boulevard" }, { 1000, -200, 1800, -200, "Bridge" },
	{ 1800, -200, 2300, -200, "Boulevard" }, { -4200, 600, 880, 600, "Boulevard" }, { -320, -1800, 880, -1800, "Boulevard" },
	{ -4200, 1400, -700, 1400, "Street" }, { -4200, 2200, -700, 2200, "Street" }, { -320, 1000, 880, 1000, "Street" },
}

-- Wichtige Orte (Markierungen auf der Karte)
MapData.Landmarks = {
	{ Name = "Police HQ", X = -126, Z = -80 }, { Name = "Fire Station 1", X = -126, Z = 460 },
	{ Name = "Bayfront Medical", X = -126, Z = -820 }, { Name = "City Hall", X = 286, Z = -60 },
	{ Name = "Sawgrass Center", X = -2690, Z = -600 }, { Name = "Port Gate", X = 480, Z = 1200 },
}

-- Kartenmarker-Kategorien (Stadtkarte + Minimap). Die Orte selbst erzeugt 22_MapExport in MapGeo.POI.
MapData.POICategories = {
	{ Id = "Police", Name = "Polizei", Icon = "🚓", Color = Color3.fromRGB(60, 120, 255), Mini = true },
	{ Id = "Hospital", Name = "Krankenhaus", Icon = "🏥", Color = Color3.fromRGB(235, 60, 70), Mini = true },
	{ Id = "Fire", Name = "Feuerwehr", Icon = "🚒", Color = Color3.fromRGB(255, 110, 40), Mini = true },
	{ Id = "Bank", Name = "Bank / Geldautomat", Icon = "🏧", Color = Color3.fromRGB(70, 200, 120), Mini = true },
	{ Id = "Gas", Name = "Tankstelle", Icon = "⛽", Color = Color3.fromRGB(255, 170, 40), Mini = true },
	{ Id = "Dealership", Name = "Autohaus", Icon = "🚗", Color = Color3.fromRGB(40, 190, 200), Mini = true },
	{ Id = "Workshop", Name = "Werkstatt", Icon = "🔧", Color = Color3.fromRGB(150, 156, 170), Mini = true },
	{ Id = "Port", Name = "Hafen", Icon = "⚓", Color = Color3.fromRGB(70, 110, 190), Mini = false },
	{ Id = "Jeweler", Name = "Juwelier", Icon = "💎", Color = Color3.fromRGB(170, 110, 255), Mini = false },
	{ Id = "Guns", Name = "Waffenhaendler", Icon = "🎯", Color = Color3.fromRGB(200, 120, 60), Mini = false },
	{ Id = "Club", Name = "Clubs & Unterhaltung", Icon = "🎵", Color = Color3.fromRGB(255, 72, 168), Mini = false },
	{ Id = "Restaurant", Name = "Restaurants & Cafes", Icon = "🍴", Color = Color3.fromRGB(240, 190, 60), Mini = false },
	{ Id = "Shop", Name = "Geschaefte", Icon = "🛍", Color = Color3.fromRGB(64, 224, 255), Mini = false },
	{ Id = "Parking", Name = "Parkhaus", Icon = "🅿", Color = Color3.fromRGB(80, 140, 255), Mini = false },
	{ Id = "Jobs", Name = "Arbeit & Behoerden", Icon = "💼", Color = Color3.fromRGB(200, 150, 90), Mini = true },
}

function MapData.Category(id)
	for _, c in ipairs(MapData.POICategories) do
		if c.Id == id then
			return c
		end
	end
	return MapData.POICategories[#MapData.POICategories]
end

function MapData.DistrictAt(x, z)
	for _, d in ipairs(MapData.Districts) do
		if x >= d.X0 and x <= d.X1 and z >= d.Z0 and z <= d.Z1 then
			return d.Name
		end
	end
	return "Stadtgebiet"
end

return MapData
