-- Ladensortimente (gemeinsame Grundlage fuer ALLE Geschaefte, Prompt 08).
-- Zuordnung ueber den Namen am Laden-Marker (Attribut "StoreName" bzw. "Shop") oder direkt per Attribut "ShopId"
-- an einer Kasse (Tag "Interactable", InteractType "Shop").
-- Preise in Dollar, Bezahlung bar oder per Karte (Bankkonto). Abgerechnet wird NUR mit diesen Serverwerten.
--
-- Katalogfelder:  Title, Subtitle, Kind ("Retail" | "Weapons" | "Clothing" | "Jeweler"), Icon, Color,
--                 Requires = { ... } (gilt fuer alle Artikel), MinPlayHours, Info (Text fuer Infobereich)
-- Artikelfelder:  Id, Price, Pack (Stueck pro Kauf, z.B. Munition), Requires = { ... }, MinPlayHours
-- Bedingungen:    "WeaponLicense" (Waffenschein im Inventar), "NoLicense" (noch keiner), "CleanRecord"
--                 (keine Fahndung/kein Haftbefehl), "Age21" (Charakter mind. 21 Jahre)
-- Neuer Laden: Katalog hier ergaenzen, Namen in Shops.ByName eintragen - fertig.
local Shops = {}
local rgb = Color3.fromRGB

Shops.Catalogs = {
	Mart = {
		Title = "Tankstellen-Shop", Kind = "Retail", Icon = "⛽", Color = rgb(230, 150, 50),
		Items = { { Id = "WaterBottle", Price = 3 }, { Id = "Snack", Price = 4 }, { Id = "Coffee", Price = 5 }, { Id = "Soda", Price = 3 }, { Id = "EnergyDrink", Price = 5 }, { Id = "Bandage", Price = 15 }, { Id = "Flashlight", Price = 25 } },
	},
	Supermarket = {
		Title = "Freshway Market", Subtitle = "Supermarkt - Lebensmittel & Alltag", Kind = "Retail", Icon = "🛒", Color = rgb(70, 170, 90),
		Items = {
			{ Id = "WaterBottle", Price = 2 }, { Id = "Soda", Price = 2 }, { Id = "EnergyDrink", Price = 4 }, { Id = "Coffee", Price = 4 },
			{ Id = "Sandwich", Price = 6 }, { Id = "Snack", Price = 3 }, { Id = "Chips", Price = 3 }, { Id = "Fruit", Price = 3 },
			{ Id = "Bandage", Price = 14 }, { Id = "Batteries", Price = 6 }, { Id = "Sunscreen", Price = 12 }, { Id = "Umbrella", Price = 18 },
		},
	},
	GunStore = {
		Title = "Suncoast Arms", Subtitle = "Lizenzierter Waffenhandel - Kurzwaffen, Munition, Zubehoer", Kind = "Weapons", Icon = "🎯", Color = rgb(200, 120, 60),
		Info = "Verkauf nur mit Waffenschein. Den Waffenschein stellen wir aus, wenn du mindestens 21 bist und keine offene Fahndung oder Haftbefehl hast. Langwaffen fuehrt ausschliesslich Everglades Outfitters (Sawgrass Park).",
		Items = {
			{ Id = "WeaponLicense", Price = 500, Requires = { "NoLicense", "Age21", "CleanRecord" } },
			{ Id = "Pistol", Price = 850, Requires = { "WeaponLicense", "CleanRecord" } },
			{ Id = "Revolver", Price = 950, Requires = { "WeaponLicense", "CleanRecord" } },
			{ Id = "Pistol45", Price = 1200, Requires = { "WeaponLicense", "CleanRecord" } },
			{ Id = "Ammo9mm", Price = 30, Pack = 15, Requires = { "WeaponLicense" } },
			{ Id = "Ammo45", Price = 32, Pack = 8, Requires = { "WeaponLicense" } },
			{ Id = "Ammo38", Price = 24, Pack = 6, Requires = { "WeaponLicense" } },
			{ Id = "Holster", Price = 60 }, { Id = "WeaponLight", Price = 90 }, { Id = "GunCase", Price = 120 },
			{ Id = "TriggerLock", Price = 25 }, { Id = "CleaningKit", Price = 35 }, { Id = "RangeBag", Price = 70 },
		},
	},
	LongGuns = {
		Title = "Everglades Outfitters", Subtitle = "Fachhandel fuer Langwaffen - Jagd & Sport", Kind = "Weapons", Icon = "🦌", Color = rgb(110, 140, 80),
		Requires = { "WeaponLicense", "CleanRecord" }, MinPlayHours = 2,
		Info = "Langwaffen nur fuer erfahrene Buerger: Waffenschein, sauberes Register und mindestens 2 Stunden Spielzeit. Der Keystone Karabiner erfordert 5 Stunden.",
		Items = {
			{ Id = "Shotgun", Price = 1900 },
			{ Id = "HuntingRifle", Price = 2400 },
			{ Id = "Carbine", Price = 3800, MinPlayHours = 5 },
			{ Id = "Ammo12g", Price = 30, Pack = 12 },
			{ Id = "Ammo308", Price = 45, Pack = 10 },
			{ Id = "Ammo556", Price = 60, Pack = 20 },
			{ Id = "GunCase", Price = 140 }, { Id = "CleaningKit", Price = 35 }, { Id = "TriggerLock", Price = 25 },
		},
	},
	Clothing = {
		Title = "Palm Boutique", Subtitle = "Mode fuer Miami - kaufen, anprobieren, Outfits speichern", Kind = "Clothing", Icon = "👕", Color = rgb(230, 110, 150),
		Items = {
			{ Id = "Tee_White", Price = 25 }, { Id = "Tee_Black", Price = 25 }, { Id = "Tee_Coral", Price = 28 }, { Id = "Tee_Teal", Price = 28 },
			{ Id = "Polo_Navy", Price = 40 }, { Id = "Polo_Mint", Price = 40 }, { Id = "Shirt_Linen", Price = 55 }, { Id = "Shirt_Hawaii", Price = 45 },
			{ Id = "Hoodie_Grey", Price = 60 }, { Id = "Hoodie_Black", Price = 60 }, { Id = "Jacket_Denim", Price = 85 },
			{ Id = "Blazer_Navy", Price = 180 }, { Id = "Blazer_White", Price = 220 },
			{ Id = "Jeans_Blue", Price = 60 }, { Id = "Jeans_Black", Price = 60 }, { Id = "Chinos_Beige", Price = 50 }, { Id = "Chinos_Olive", Price = 50 },
			{ Id = "Shorts_Khaki", Price = 35 }, { Id = "Shorts_Navy", Price = 35 }, { Id = "Suit_Navy", Price = 120 }, { Id = "Joggers_Grey", Price = 40 },
			{ Id = "Sneakers_White", Price = 90 }, { Id = "Sneakers_Black", Price = 90 }, { Id = "Loafers_Brown", Price = 140 }, { Id = "Boots_Tan", Price = 120 },
			{ Id = "Cap_Black", Price = 25 }, { Id = "Cap_Teal", Price = 25 }, { Id = "Cap_Red", Price = 25 }, { Id = "Beanie_Grey", Price = 22 },
			{ Id = "Fedora_Straw", Price = 60 }, { Id = "Bucket_White", Price = 35 },
			{ Id = "Shades_Black", Price = 45 }, { Id = "Shades_Gold", Price = 160 }, { Id = "Glasses_Clear", Price = 40 },
		},
	},
	Sneakers = {
		Title = "Sneaker Station", Subtitle = "Schuhe und Caps", Kind = "Clothing", Icon = "👟", Color = rgb(240, 150, 60),
		Items = {
			{ Id = "Sneakers_White", Price = 85 }, { Id = "Sneakers_Black", Price = 85 }, { Id = "Boots_Tan", Price = 115 }, { Id = "Loafers_Brown", Price = 135 },
			{ Id = "Cap_Black", Price = 24 }, { Id = "Cap_Teal", Price = 24 }, { Id = "Cap_Red", Price = 24 },
		},
	},
	Jeweler = {
		Title = "Miami Gold Jewelers", Subtitle = "Feiner Schmuck seit 1962 - Bayfront Downtown", Kind = "Jeweler", Icon = "💎", Color = rgb(220, 180, 80),
		Info = "Willkommen bei Miami Gold Jewelers. In unseren Vitrinen finden Sie Uhren, Ringe, Ketten und Diamantschmuck. Alle Stuecke sind versichert, die Ausstellung ist alarmgesichert und videoueberwacht.",
		Items = { { Id = "GoldRing", Price = 900 }, { Id = "Necklace", Price = 1200 }, { Id = "Watch", Price = 1500 }, { Id = "DiamondEarrings", Price = 2800 } },
	},
	Pharmacy = {
		Title = "Apotheke", Kind = "Retail", Icon = "💊", Color = rgb(220, 70, 80),
		Items = { { Id = "Bandage", Price = 12 }, { Id = "Medkit", Price = 75 } },
	},
	Electronics = {
		Title = "Elektronik", Kind = "Retail", Icon = "📱", Color = rgb(80, 130, 230),
		Items = { { Id = "Phone", Price = 400 }, { Id = "Flashlight", Price = 20 } },
	},
	Hardware = {
		Title = "Gulf Coast Supply", Subtitle = "Werkzeugladen - Werkzeug & Baubedarf", Kind = "Retail", Icon = "🔧", Color = rgb(230, 170, 40),
		Items = {
			{ Id = "Hammer", Price = 25 }, { Id = "Screwdriver", Price = 18 }, { Id = "Wrench", Price = 35 }, { Id = "DuctTape", Price = 8 },
			{ Id = "Crowbar", Price = 45 }, { Id = "Toolbox", Price = 120 }, { Id = "RepairKit", Price = 150 }, { Id = "Flashlight", Price = 22 }, { Id = "Batteries", Price = 6 },
		},
	},
	Cafe = {
		Title = "Cafe", Kind = "Retail", Icon = "☕", Color = rgb(170, 110, 70),
		Items = { { Id = "Coffee", Price = 4 }, { Id = "Snack", Price = 5 } },
	},
}

-- Ladenname -> Katalog
Shops.ByName = {
	GasStationShop = "Mart",
	["FRESHWAY MARKET"] = "Supermarket",
	["CAREPLUS PHARMACY"] = "Pharmacy",
	["VOLT ELECTRONICS"] = "Electronics",
	["GULF COAST SUPPLY"] = "Hardware",
	["BEAN & LEAF"] = "Cafe",
	["SUNNY CAFE"] = "Cafe",
	["CAFE MOKA"] = "Cafe",
	["DONUT TIME"] = "Cafe",
	["BAKERY"] = "Cafe",
	-- Prompt 08
	["SUNCOAST ARMS"] = "GunStore",
	["EVERGLADES OUTFITTERS"] = "LongGuns",
	["PALM BOUTIQUE"] = "Clothing",
	["URBAN THREADS"] = "Clothing",
	["SNEAKER STATION"] = "Sneakers",
	["MIAMI GOLD JEWELERS"] = "Jeweler",
}

return Shops
