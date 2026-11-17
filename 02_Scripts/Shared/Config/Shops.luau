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
		Items = { { Id = "Coffee", Price = 4 }, { Id = "IcedCoffee", Price = 5 }, { Id = "Croissant", Price = 4 }, { Id = "Donut", Price = 3 }, { Id = "Smoothie", Price = 6 }, { Id = "Snack", Price = 5 } },
	},
	-- Prompt 10: Gastronomie (Downtown & Stadt) --------------------------------------------------------
	Diner = {
		Title = "American Diner", Subtitle = "Pancakes, Burger & Milkshakes - seit 1958", Kind = "Restaurant", Icon = "🍔", Color = rgb(230, 70, 70),
		Items = { { Id = "Pancakes", Price = 9 }, { Id = "Burger", Price = 11 }, { Id = "Fries", Price = 4 }, { Id = "Milkshake", Price = 6 }, { Id = "Coffee", Price = 3 }, { Id = "Soda", Price = 3 } },
	},
	FastFood = {
		Title = "Fast Food", Subtitle = "Schnell, heiss, guenstig", Kind = "Restaurant", Icon = "🍟", Color = rgb(250, 190, 40),
		Items = { { Id = "Burger", Price = 7 }, { Id = "Fries", Price = 3 }, { Id = "Milkshake", Price = 4 }, { Id = "Soda", Price = 2 } },
	},
	Pizzeria = {
		Title = "Pizzeria", Subtitle = "Steinofen-Pizza", Kind = "Restaurant", Icon = "🍕", Color = rgb(220, 90, 50),
		Items = { { Id = "Pizza", Price = 12 }, { Id = "Pasta", Price = 13 }, { Id = "Salad", Price = 9 }, { Id = "Lemonade", Price = 4 }, { Id = "Gelato", Price = 5 } },
	},
	Sushi = {
		Title = "Sushi Bar", Subtitle = "Frischer Fisch aus der Bucht", Kind = "Restaurant", Icon = "🍣", Color = rgb(230, 100, 110),
		Items = { { Id = "Sushi", Price = 16 }, { Id = "Salad", Price = 8 }, { Id = "WaterBottle", Price = 3 }, { Id = "Mocktail", Price = 7 } },
	},
	Mexican = {
		Title = "Taqueria", Subtitle = "Tacos, Salsa, Limonade", Kind = "Restaurant", Icon = "🌮", Color = rgb(120, 190, 70),
		Items = { { Id = "Tacos", Price = 9 }, { Id = "Lemonade", Price = 4 }, { Id = "Soda", Price = 3 } },
	},
	Cuban = {
		Title = "Cuban Cafe", Subtitle = "Cafecito und Cubanos wie in Little Havana", Kind = "Restaurant", Icon = "🥪", Color = rgb(240, 160, 60),
		Items = { { Id = "Cubano", Price = 10 }, { Id = "Coffee", Price = 3 }, { Id = "Croissant", Price = 4 }, { Id = "Smoothie", Price = 6 } },
	},
	Grill = {
		Title = "Grill & Seafood", Subtitle = "Vom Grill und aus dem Meer", Kind = "Restaurant", Icon = "🍤", Color = rgb(70, 160, 220),
		Items = { { Id = "Burger", Price = 13 }, { Id = "Steak", Price = 32 }, { Id = "Salad", Price = 11 }, { Id = "Lemonade", Price = 5 }, { Id = "Mocktail", Price = 8 } },
	},
	BBQ = {
		Title = "Smokehouse BBQ", Kind = "Restaurant", Icon = "🍖", Color = rgb(150, 80, 40),
		Items = { { Id = "Ribs", Price = 22 }, { Id = "Burger", Price = 12 }, { Id = "Fries", Price = 4 }, { Id = "Lemonade", Price = 4 } },
	},
	Thai = {
		Title = "Thai Kueche", Kind = "Restaurant", Icon = "🍜", Color = rgb(200, 120, 200),
		Items = { { Id = "PadThai", Price = 13 }, { Id = "Salad", Price = 8 }, { Id = "Smoothie", Price = 6 } },
	},
	Gelateria = {
		Title = "Gelateria", Kind = "Restaurant", Icon = "🍨", Color = rgb(250, 170, 200),
		Items = { { Id = "Gelato", Price = 5 }, { Id = "Milkshake", Price = 6 }, { Id = "IcedCoffee", Price = 5 } },
	},
	Bakery = {
		Title = "Baeckerei", Kind = "Restaurant", Icon = "🥐", Color = rgb(200, 150, 90),
		Items = { { Id = "Croissant", Price = 3 }, { Id = "Donut", Price = 3 }, { Id = "Sandwich", Price = 6 }, { Id = "Coffee", Price = 3 } },
	},
	ModernKitchen = {
		Title = "Bayfront Kitchen", Subtitle = "Modernes Restaurant - saisonale Kueche", Kind = "Restaurant", Icon = "🍽", Color = rgb(64, 224, 255),
		Items = { { Id = "Salad", Price = 14 }, { Id = "Pasta", Price = 19 }, { Id = "Steak", Price = 38 }, { Id = "Sushi", Price = 22 }, { Id = "Lemonade", Price = 6 }, { Id = "Mocktail", Price = 9 } },
	},
	FineDining = {
		Title = "Maison Azure", Subtitle = "Fine Dining - franzoesisch-karibische Kueche", Kind = "Restaurant", Icon = "🦞", Color = rgb(220, 180, 90),
		Info = "Reservierung nicht noetig. Smart Casual erwuenscht.",
		Items = { { Id = "Lobster", Price = 95 }, { Id = "Steak", Price = 72 }, { Id = "Salad", Price = 24 }, { Id = "Mocktail", Price = 16 }, { Id = "Gelato", Price = 14 } },
	},
	Rooftop = {
		Title = "SKYLINE 52", Subtitle = "Rooftop-Restaurant & Bar ueber Bayfront", Kind = "Restaurant", Icon = "🌇", Color = rgb(255, 120, 80),
		Items = { { Id = "Sushi", Price = 26 }, { Id = "Steak", Price = 54 }, { Id = "Salad", Price = 18 }, { Id = "Mocktail", Price = 12 }, { Id = "Lemonade", Price = 7 } },
	},
	ClubBar = {
		Title = "Club-Bar", Subtitle = "Drinks (alkoholfrei) und VIP-Zugang", Kind = "Restaurant", Icon = "🍹", Color = rgb(255, 72, 168),
		Info = "Das VIP-Armband gilt dauerhaft fuer die VIP-Lounges aller Clubs.",
		Items = { { Id = "Mocktail", Price = 9 }, { Id = "EnergyDrink", Price = 6 }, { Id = "WaterBottle", Price = 4 }, { Id = "Lemonade", Price = 6 }, { Id = "VIPPass", Price = 750 } },
	},
	CinemaBox = {
		Title = "Bayfront Social - Kasse", Subtitle = "Kino, Bowling, Arcade", Kind = "Restaurant", Icon = "🎬", Color = rgb(150, 90, 255),
		Items = { { Id = "CinemaTicket", Price = 12 }, { Id = "Snack", Price = 4 }, { Id = "Soda", Price = 3 }, { Id = "Chips", Price = 3 } },
	},
	GymDesk = {
		Title = "Iron Bay Fitness - Empfang", Subtitle = "Mitgliedschaft, Getraenke", Kind = "Retail", Icon = "🏋", Color = rgb(80, 220, 140),
		Info = "Mit Mitgliedschaft trainierst du ohne Tagesgebuehr ($15).",
		Items = { { Id = "GymPass", Price = 450 }, { Id = "WaterBottle", Price = 2 }, { Id = "EnergyDrink", Price = 4 }, { Id = "Smoothie", Price = 6 } },
	},
	-- Prompt 10: weitere Geschaefte
	Sports = {
		Title = "Pro Sports", Subtitle = "Sportartikel", Kind = "Retail", Icon = "🏀", Color = rgb(255, 140, 50),
		Items = { { Id = "Basketball", Price = 35 }, { Id = "WaterBottle", Price = 2 }, { Id = "Sunglasses", Price = 60 }, { Id = "EnergyDrink", Price = 4 } },
	},
	Books = {
		Title = "Buchhandlung", Kind = "Retail", Icon = "📚", Color = rgb(170, 130, 90),
		Items = { { Id = "Book", Price = 18 }, { Id = "Coffee", Price = 4 } },
	},
	Florist = {
		Title = "Blumenladen", Kind = "Retail", Icon = "💐", Color = rgb(240, 120, 170),
		Items = { { Id = "Flowers", Price = 35 } },
	},
	Toys = {
		Title = "Spielwaren", Kind = "Retail", Icon = "🧸", Color = rgb(255, 190, 60),
		Items = { { Id = "Toy", Price = 25 }, { Id = "Basketball", Price = 30 } },
	},
	Surf = {
		Title = "Surf & Sun", Subtitle = "Surfbretter, Sonnenbrillen, Strand", Kind = "Retail", Icon = "🏄", Color = rgb(60, 200, 230),
		Items = { { Id = "Surfboard", Price = 480 }, { Id = "Sunglasses", Price = 55 }, { Id = "Sunscreen", Price = 12 } },
	},
	Optician = {
		Title = "Optiker", Kind = "Clothing", Icon = "👓", Color = rgb(120, 160, 230),
		Items = { { Id = "Glasses_Clear", Price = 40 }, { Id = "Shades_Black", Price = 45 }, { Id = "Shades_Gold", Price = 150 } },
	},
	-- Prompt 12: Strassenimbisse in Downtown
	StreetFood = {
		Title = "Strassenimbiss", Subtitle = "Hot Dogs, Tacos, Limonade", Kind = "Restaurant", Icon = "🌭", Color = rgb(255, 180, 60),
		Items = { { Id = "HotDog", Price = 5 }, { Id = "Tacos", Price = 7 }, { Id = "Lemonade", Price = 3 }, { Id = "Soda", Price = 2 } },
	},
	Market = {
		Title = "Corner Market", Subtitle = "Kleiner Supermarkt", Kind = "Retail", Icon = "🛒", Color = rgb(90, 180, 110),
		Items = { { Id = "WaterBottle", Price = 2 }, { Id = "Soda", Price = 2 }, { Id = "Sandwich", Price = 6 }, { Id = "Chips", Price = 3 }, { Id = "Fruit", Price = 3 }, { Id = "Batteries", Price = 6 } },
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
	-- Prompt 10: Gastronomie und weitere Geschaefte an bestehenden Ladenmarkern
	["LITTLE HAVANA DINER"] = "Diner",
	["SAWGRASS DINER"] = "Diner",
	["THE BURGER JOINT"] = "FastFood",
	["BURGER BAR"] = "FastFood",
	["STAR BURGER"] = "FastFood",
	["MIAMI PIZZA CO."] = "Pizzeria",
	["PIZZA NAPOLI"] = "Pizzeria",
	["PIZZA SLICE"] = "Pizzeria",
	["PASTA PALMA"] = "Pizzeria",
	["SUSHI WAVE"] = "Sushi",
	["SUSHI GO"] = "Sushi",
	["OCEAN TACOS"] = "Mexican",
	["TACO LOCO"] = "Mexican",
	["TAQUERIA"] = "Mexican",
	["LA COCINA"] = "Mexican",
	["CUBAN CORNER CAFE"] = "Cuban",
	["BAYSIDE GRILL"] = "Grill",
	["DELI & GRILL"] = "Grill",
	["SMOKEHOUSE BBQ"] = "BBQ",
	["THAI ORCHID"] = "Thai",
	["GELATERIA"] = "Gelateria",
	["GELATO"] = "Gelateria",
	["BAKERY"] = "Bakery",
	["PRO SPORTS"] = "Sports",
	["BOOK NOOK"] = "Books",
	["BAYSIDE BOOKS"] = "Books",
	["FLOWER SHOP"] = "Florist",
	["FLORIDA FLOWERS"] = "Florist",
	["TOY BOX"] = "Toys",
	["SURF & SUN"] = "Surf",
	["OPTICIAN"] = "Optician",
	["OPTICAL VISION"] = "Optician",
	["CORNER MARKET"] = "Market",
	["THRIFT SHOP"] = "Clothing",
}

return Shops
