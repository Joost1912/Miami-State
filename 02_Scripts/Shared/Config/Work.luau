-- Berufe, Karriere und Wirtschaft (Prompt 11). Alle Zahlen hier sind die einzige Quelle fuer den Server.
-- Massstab: 1 Stud ~ 0.28 m. Richtwerte pro Stunde aktiver Arbeit (Stufe 1, ohne Trinkgeld) stehen bei jedem Beruf.
-- Zum Vergleich: Polizei/Feuerwehr/EMS verdienen im Dienst ca. $1.500-4.500/h (Config.Factions).
local rgb = Color3.fromRGB
local W = {}

-- Karriere ------------------------------------------------------------------------------------------
W.MaxLevel = 30
-- benoetigte Gesamt-XP fuer Stufe L (Stufe 1 = 0 XP)
function W.XPForLevel(level)
	if level <= 1 then
		return 0
	end
	return math.floor(120 * (level - 1) ^ 1.6)
end
function W.LevelFor(xp)
	local lvl = 1
	while lvl < W.MaxLevel and xp >= W.XPForLevel(lvl + 1) do
		lvl += 1
	end
	return lvl
end
W.PayBonusPerLevel = 0.02 -- +2 % Lohn je Stufe ueber 1 ...
W.PayBonusMax = 0.30 -- ... hoechstens +30 %
W.Unlocks = { -- Anzeige in der Karriere-Uebersicht (Pruefung erfolgt an der jeweiligen Stelle)
	{ Level = 2, Text = "Busfahrer und Mechaniker" },
	{ Level = 3, Text = "LKW-Fahrer, Unternehmen kaufen" },
	{ Level = 5, Text = "Fernverkehr-Auftraege (LKW, hoehere Bezahlung)" },
	{ Level = 8, Text = "Beförderung zum Supervisor in Unternehmen" },
	{ Level = 12, Text = "Beförderung zum Manager in Unternehmen" },
}
W.BusinessMinLevel = 3

-- Schutz gegen Ausnutzung --------------------------------------------------------------------------
W.HourlyCap = 4500 -- maximaler Arbeitslohn pro Spieler und Echtzeit-Stunde (alle Berufe zusammen)
W.MinSecondsPerStud = 1 / 75 -- schneller als ~75 Studs/s im Mittel = Teleport -> keine Bezahlung
W.SkipCooldown = 30
W.ActiveWindow = 600 -- Grundsicherung/Gehalt nur, wenn der Spieler in den letzten 10 Min aktiv war
W.ActiveMoveStuds = 25

-- Berufe ----------------------------------------------------------------------------------------------
-- Vehicle = Vorlage ServerStorage.Vehicles.Vehicle_<Vehicle>; Depot = Attribut JobId am Depot-Terminal
W.Jobs = {
	Taxi = {
		Name = "Taxifahrer", Company = "Miami Cab Co.", Icon = "🚕", Color = rgb(250, 200, 40), Level = 1, Vehicle = "Taxi",
		Desc = "Fahrgaeste an ihren Adressen abholen und sicher ans Ziel bringen. Schnelle, saubere Fahrten bringen Trinkgeld.",
		Requires = "Fuehrerschein", Location = "Taxizentrale, Public Parking (Sawgrass Ost)", Hourly = "ca. $1.600-2.200 + Trinkgeld",
		Tasks = { "Fahrgast abholen", "Zum Ziel fahren", "Fahrpreis kassieren" },
		Pay = { Base = 20, PerStud = 0.035, TipMax = 0.25 }, XP = 18,
		Uniform = { Prefix = "WK_", Torso = rgb(30, 30, 34), Legs = rgb(40, 40, 46), Parts = { { "Cap", "HatAttachment", Vector3.new(1.4, 0.4, 1.5), rgb(250, 200, 40), "SmoothPlastic", CFrame.new(0, -0.1, 0) } } },
	},
	Delivery = {
		Name = "Paketzusteller", Company = "Gulf Coast Parcel", Icon = "📦", Color = rgb(240, 140, 50), Level = 1, Vehicle = "DeliveryVan",
		Desc = "Pakete im Depot laden und an Geschaefte in der ganzen Stadt zustellen.",
		Requires = "Fuehrerschein", Location = "Paketdepot, Office Parking (Sawgrass)", Hourly = "ca. $1.500-2.000",
		Tasks = { "Pakete laden", "Zustelladressen anfahren", "Pakete uebergeben" },
		Pay = { PerPackage = 30, PerStud = 0.012, Packages = 3 }, XP = 12,
		Uniform = { Prefix = "WK_", Torso = rgb(120, 70, 40), Legs = rgb(70, 50, 36), Parts = { { "Cap", "HatAttachment", Vector3.new(1.4, 0.4, 1.5), rgb(240, 140, 50), "SmoothPlastic", CFrame.new(0, -0.1, 0) } } },
	},
	Bus = {
		Name = "Busfahrer", Company = "Miami State Transit", Icon = "🚌", Color = rgb(60, 160, 240), Level = 2, Vehicle = "CityBus",
		Desc = "Die Stadtlinie fahren: Haltestellen in Reihenfolge anfahren, halten, Fahrgaeste ein- und aussteigen lassen.",
		Requires = "Fuehrerschein, Stufe 2", Location = "Busdepot, Public Parking (Sawgrass Nord)", Hourly = "ca. $1.800-2.400",
		Tasks = { "Bus ausparken", "Haltestellen anfahren", "Linie abschliessen" },
		Pay = { PerStop = 26, RouteBonus = 160 }, XP = 6,
		Uniform = { Prefix = "WK_", Torso = rgb(60, 110, 170), Legs = rgb(30, 40, 60), Parts = {} },
	},
	Trucker = {
		Name = "LKW-Fahrer", Company = "Meridian Freight", Icon = "🚚", Color = rgb(170, 120, 255), Level = 3, Vehicle = "BoxTruck",
		Desc = "Fracht am Hafen laden und zu Lagern, Tankstellen und Maerkten bringen. Lange Strecken zahlen mehr.",
		Requires = "Fuehrerschein, Stufe 3 (Fernverkehr ab Stufe 5)", Location = "Hafen Port Meridian, Terminal", Hourly = "ca. $2.200-3.000",
		Tasks = { "LKW ausparken", "Fracht laden", "Lieferziel anfahren", "Fracht entladen" },
		Pay = { Base = 90, PerStud = 0.05, LongHaulBonus = 0.25 }, XP = 35,
		Uniform = { Prefix = "WK_", Torso = rgb(70, 80, 100), Legs = rgb(40, 50, 70), Parts = { { "VestStripe", "BodyFrontAttachment", Vector3.new(2.05, 0.22, 0.08), rgb(255, 210, 60), "Neon", CFrame.new(0, -0.5, 0.06) } } },
	},
	Mechanic = {
		Name = "Mechaniker", Company = "Miami Auto Repair", Icon = "🔧", Color = rgb(255, 160, 60), Level = 2, Vehicle = "ServiceTruck",
		Desc = "Pannenfahrzeuge in der Stadt reparieren, Kundenfahrzeuge betanken und warten, Kunden per Rechnung abrechnen. Tuning in der Werkstatt.",
		Requires = "Stufe 2", Location = "Miami Auto Repair (Sawgrass West)", Hourly = "ca. $1.800-2.600 + Rechnungen",
		Tasks = { "Dienst antreten", "Pannenhilfe", "Fahrzeug warten", "Kunden abrechnen" },
		Pay = { Base = 70, PerStud = 0.015 }, XP = 25, InvoiceShare = 0.8, InvoiceMax = 5000,
		Uniform = { Prefix = "WK_", Torso = rgb(40, 60, 110), Legs = rgb(40, 60, 110), Parts = { { "Cap", "HatAttachment", Vector3.new(1.4, 0.4, 1.5), rgb(255, 160, 60), "SmoothPlastic", CFrame.new(0, -0.1, 0) } } },
	},
	Construction = {
		Name = "Bauarbeiter", Company = "Sunstate Construction", Icon = "🏗", Color = rgb(255, 200, 40), Level = 1,
		Desc = "Auf der Baustelle Material schleppen, mit Werkzeug arbeiten und Bauabschnitte fertigstellen. Kein Fuehrerschein noetig.",
		Requires = "keine", Location = "Baustelle Sawgrass West (Office Parking)", Hourly = "ca. $1.100-1.500",
		Tasks = { "Material holen", "Material abladen", "Werkzeug benutzen" },
		Pay = { Carry = 22, Tool = 30 }, XP = 8,
		Uniform = { Prefix = "WK_", Torso = rgb(255, 140, 30), Legs = rgb(50, 60, 80), Parts = {
			{ "HardHat", "HatAttachment", Vector3.new(1.6, 0.6, 1.7), rgb(255, 210, 40), "SmoothPlastic", CFrame.new(0, -0.05, 0) },
			{ "VestStripe", "BodyFrontAttachment", Vector3.new(2.05, 0.22, 0.08), rgb(220, 255, 90), "Neon", CFrame.new(0, -0.5, 0.06) },
		} },
	},
}
W.JobOrder = { "Construction", "Delivery", "Taxi", "Bus", "Mechanic", "Trucker" }

-- Unternehmen ----------------------------------------------------------------------------------------
W.Positions = {
	{ Id = "Intern", Name = "Praktikant", MaxSalary = 120 },
	{ Id = "Employee", Name = "Mitarbeiter", MaxSalary = 220 },
	{ Id = "Senior", Name = "Senior Employee", MaxSalary = 320 },
	{ Id = "Supervisor", Name = "Supervisor", MaxSalary = 420, MinLevel = 8 },
	{ Id = "Manager", Name = "Manager", MaxSalary = 560, MinLevel = 12 },
}
-- Rechte je Position (Owner hat alle)
W.PositionRights = {
	Hire = 4, -- Supervisor: Bewerbungen annehmen (nur Praktikant/Mitarbeiter)
	ViewFinances = 4,
	Promote = 5, -- Manager: befoerdern/entlassen unterhalb der eigenen Position, Gehaelter
	Prices = 5,
}
W.MaxEmployees = 8
W.SalaryInterval = 600 -- Gehalt an Mitarbeiter im Dienst, aus dem Unternehmenskonto
W.SellFactor = 0.7

-- Typen: Margin = Anteil vom Kundenumsatz, der aufs Unternehmenskonto geht; Walkin = Umsatz pro Minute je
-- anwesender Dienstkraft (Laufkundschaft), Upkeep = Betriebskosten pro Echtzeit-Tag
W.BusinessTypes = {
	Restaurant = { Name = "Restaurant", Margin = 0.30, Walkin = 9, Upkeep = 900, Prices = true },
	Cafe = { Name = "Cafe", Margin = 0.30, Walkin = 6, Upkeep = 500, Prices = true },
	Club = { Name = "Nachtclub", Margin = 0.35, Walkin = 12, Upkeep = 1500, Prices = true, EntryFee = true, NightOnly = true },
	Dealer = { Name = "Autohaus", Margin = 0.06, Walkin = 10, Upkeep = 2600 },
	Workshop = { Name = "Werkstatt", Margin = 0.25, Walkin = 8, Upkeep = 900 },
	Retail = { Name = "Geschaeft", Margin = 0.25, Walkin = 7, Upkeep = 700, Prices = true },
	RealEstate = { Name = "Immobilienunternehmen", Margin = 0.02, Walkin = 6, Upkeep = 1200 },
	Logistics = { Name = "Lieferunternehmen", Margin = 0.12, Walkin = 5, Upkeep = 1000 },
}

-- Konkrete Unternehmen (Standorte = bestehende Gebaeude/Innenraeume). Link bestimmt, welche Umsaetze zaehlen:
--   StoreNames = Ladenmarker-Namen (Kette), ShopIds = Venue-Kassen, Venue = Club-Link, Dealer = Autohaus,
--   Workshop = true (Tuning + Mechaniker-Rechnungen), Property = true (Provision Wohnungskaeufe), Job = Beruf (Auftragsgebuehr)
W.Businesses = {
	{ Id = "MaisonAzure", Name = "Maison Azure", Type = "Restaurant", Price = 420000, X = -205, Z = -1370, Link = { ShopIds = { "FineDining" } } },
	{ Id = "BayfrontKitchen", Name = "Bayfront Kitchen", Type = "Restaurant", Price = 260000, X = 168, Z = -1370, Link = { ShopIds = { "ModernKitchen" } } },
	{ Id = "Skyline52", Name = "SKYLINE 52", Type = "Restaurant", Price = 380000, X = 594, Z = 556, Link = { ShopIds = { "Rooftop" } } },
	{ Id = "BurgerJoint", Name = "The Burger Joint (Kette)", Type = "Restaurant", Price = 300000, X = 134, Z = 328, Link = { StoreNames = { "THE BURGER JOINT" } } },
	{ Id = "LittleHavana", Name = "Little Havana Diner", Type = "Restaurant", Price = 160000, X = 176, Z = -946, Link = { StoreNames = { "LITTLE HAVANA DINER" } } },
	{ Id = "CafeMoka", Name = "Cafe Moka (Kette)", Type = "Cafe", Price = 180000, X = 662, Z = -265, Link = { StoreNames = { "CAFE MOKA" } } },
	{ Id = "BeanLeaf", Name = "Bean & Leaf", Type = "Cafe", Price = 120000, X = 815, Z = -61, Link = { StoreNames = { "BEAN & LEAF" } } },
	{ Id = "Neonroom", Name = "NEONROOM", Type = "Club", Price = 520000, X = 195, Z = -1890, Link = { Venue = "Club_NEONROOM" } },
	{ Id = "Eclipse", Name = "ECLIPSE", Type = "Club", Price = 560000, X = 300, Z = -1890, Link = { Venue = "Club_ECLIPSE" } },
	{ Id = "Pulse", Name = "PULSE", Type = "Club", Price = 480000, X = 405, Z = -1890, Link = { Venue = "Club_PULSE" } },
	{ Id = "SawgrassMotors", Name = "Sawgrass Motors", Type = "Dealer", Price = 650000, X = -2693, Z = 775, Link = { Dealer = "Standard" } },
	{ Id = "BayfrontPrestige", Name = "Bayfront Prestige", Type = "Dealer", Price = 1200000, X = -290, Z = -1127, Link = { Dealer = "Luxury" } },
	{ Id = "AutoRepair", Name = "Miami Auto Repair", Type = "Workshop", Price = 240000, X = -3570, Z = -823, Link = { Workshop = true } },
	{ Id = "Freshway", Name = "Freshway Market (Kette)", Type = "Retail", Price = 280000, X = -2690, Z = -600, Link = { StoreNames = { "FRESHWAY MARKET" } } },
	{ Id = "VoltElectronics", Name = "Volt Electronics", Type = "Retail", Price = 220000, X = 383, Z = -600, Link = { StoreNames = { "VOLT ELECTRONICS" } } },
	{ Id = "PalmBoutique", Name = "Palm Boutique", Type = "Retail", Price = 240000, X = -2496, Z = -900, Link = { StoreNames = { "PALM BOUTIQUE" } } },
	{ Id = "BayfrontRealty", Name = "Bayfront Realty", Type = "RealEstate", Price = 450000, X = 673, Z = -330, Link = { Property = true } },
	{ Id = "GulfCoastParcel", Name = "Gulf Coast Parcel", Type = "Logistics", Price = 300000, X = -1606, Z = 1076, Link = { Job = "Delivery" } },
	{ Id = "MiamiCab", Name = "Miami Cab Co.", Type = "Logistics", Price = 260000, X = -993, Z = 270, Link = { Job = "Taxi" } },
}
W.BusinessById = {}
for _, b in ipairs(W.Businesses) do
	W.BusinessById[b.Id] = b
end

-- Wirtschafts-Uebersicht (Finanzen-App)
W.CostHints = {
	{ "Miete Apartment", "$900 - $12.500 / Woche" },
	{ "Tanken", "$2 pro %" },
	{ "Abschleppdienst", "$250" },
	{ "Lackierung", "$1.200" },
	{ "Unternehmen: Betriebskosten", "$500 - $2.600 / Tag" },
}

return W
