-- Gegenstandsdefinitionen. Neue Gegenstaende: Eintrag ergaenzen, ggf. Use-Handler im InventoryService.
-- Stack = maximale Anzahl pro Gegenstand, Use = Name des Server-Handlers, Restricted = noch nicht nutzbar
local Items = {}

Items.Categories = {
	{ Id = "Tools", Name = "Werkzeuge", Color = Color3.fromRGB(64, 224, 255) },
	{ Id = "Keys", Name = "Schluessel", Color = Color3.fromRGB(255, 205, 80) },
	{ Id = "Medical", Name = "Medizin", Color = Color3.fromRGB(255, 90, 100) },
	{ Id = "Food", Name = "Essen & Trinken", Color = Color3.fromRGB(120, 230, 140) },
	{ Id = "Documents", Name = "Dokumente", Color = Color3.fromRGB(200, 180, 255) },
	{ Id = "Weapons", Name = "Waffen", Color = Color3.fromRGB(255, 120, 60) },
	{ Id = "Ammo", Name = "Munition", Color = Color3.fromRGB(220, 160, 90) },
	{ Id = "Gear", Name = "Zubehoer", Color = Color3.fromRGB(150, 200, 120) },
	{ Id = "Valuables", Name = "Wertsachen", Color = Color3.fromRGB(255, 215, 120) },
	{ Id = "Loot", Name = "Beute", Color = Color3.fromRGB(255, 86, 96) },
	{ Id = "Leisure", Name = "Freizeit", Color = Color3.fromRGB(255, 72, 168) }, -- Prompt 10
	{ Id = "Misc", Name = "Sonstiges", Color = Color3.fromRGB(170, 176, 190) },
}

Items.Defs = {
	Phone = { Name = "Smartphone", Category = "Tools", Stack = 1, Desc = "Dein Telefon. Funktionen folgen." },
	Flashlight = { Name = "Taschenlampe", Category = "Tools", Stack = 1, Desc = "Leuchtet im Dunkeln." },
	Wrench = { Name = "Schraubenschluessel", Category = "Tools", Stack = 1, Desc = "Fuer Reparaturen." },
	Handcuffs = { Name = "Handschellen", Category = "Tools", Stack = 2, Police = true, Desc = "Dienstausruestung. Festnahme ueber das Interaktionsmenue (X)." },
	CarKey = { Name = "Fahrzeugschluessel", Category = "Keys", Stack = 10, Desc = "Schluessel fuer ein eigenes Fahrzeug." },
	HouseKey = { Name = "Hausschluessel", Category = "Keys", Stack = 5, Desc = "Schluessel fuer eine Immobilie." },
	Bandage = { Name = "Verband", Category = "Medical", Stack = 10, Use = "Heal", Amount = 20, Desc = "Heilt 20 Lebenspunkte." },
	Medkit = { Name = "Erste-Hilfe-Set", Category = "Medical", Stack = 4, Use = "Heal", Amount = 60, Desc = "Heilt 60 Lebenspunkte." },
	Defibrillator = { Name = "Defibrillator", Category = "Medical", Stack = 1, EMS = true, Desc = "Dienstausruestung EMS. Wiederbelebung ueber das Interaktionsmenue (X)." },
	WaterBottle = { Name = "Wasserflasche", Category = "Food", Stack = 10, Use = "Consume", Desc = "Erfrischend." },
	Snack = { Name = "Snack", Category = "Food", Stack = 10, Use = "Consume", Desc = "Kleiner Hunger zwischendurch." },
	Coffee = { Name = "Kaffee", Category = "Food", Stack = 5, Use = "Consume", Desc = "Frisch gebruehter Kaffee." },
	IDCard = { Name = "Personalausweis", Category = "Documents", Stack = 1, Use = "ShowID", Desc = "Zeigt deinen Ausweis Spielern in der Naehe." },
	DriversLicense = { Name = "Fuehrerschein", Category = "Documents", Stack = 1, Desc = "Fahrerlaubnis Klasse B." },
	-- Waffen: fiktive Spielgegenstaende (Prompt 08). Weapon = { Ammo, Mag, Class = "Handgun" | "Long" }
	-- Ausruesten/Laden/Entladen ueber das Inventar (WeaponService). Besitz ohne Waffenschein gilt bei Kontrollen als illegal.
	Pistol = { Name = "P9 Compact", Category = "Weapons", Stack = 1, Weapon = { Ammo = "Ammo9mm", Mag = 15, Class = "Handgun" }, Desc = "Kompakte Pistole (Spielgegenstand). Magazin: 15 Schuss 9mm." },
	Pistol45 = { Name = "P45 Service", Category = "Weapons", Stack = 1, Weapon = { Ammo = "Ammo45", Mag = 8, Class = "Handgun" }, Desc = "Grosse Dienstpistole (Spielgegenstand). Magazin: 8 Schuss .45." },
	Revolver = { Name = "R6 Revolver", Category = "Weapons", Stack = 1, Weapon = { Ammo = "Ammo38", Mag = 6, Class = "Handgun" }, Desc = "Klassischer Revolver (Spielgegenstand). Trommel: 6 Schuss .38." },
	HuntingRifle = { Name = "Ranger 308", Category = "Weapons", Stack = 1, Weapon = { Ammo = "Ammo308", Mag = 5, Class = "Long" }, Desc = "Jagdgewehr (Langwaffe, Spielgegenstand). Magazin: 5 Schuss .308." },
	Shotgun = { Name = "Coastline 12", Category = "Weapons", Stack = 1, Weapon = { Ammo = "Ammo12g", Mag = 6, Class = "Long" }, Desc = "Vorderschaft-Flinte (Langwaffe, Spielgegenstand). 6 Patronen Kaliber 12." },
	Carbine = { Name = "Keystone Karabiner", Category = "Weapons", Stack = 1, Weapon = { Ammo = "Ammo556", Mag = 20, Class = "Long" }, Desc = "Halbautomatischer Karabiner (Langwaffe, Spielgegenstand). Magazin: 20 Schuss." },
	Ammo9mm = { Name = "9mm-Munition", Category = "Ammo", Stack = 120, Desc = "Fuer P9 Compact. Laden ueber die Waffe im Inventar." },
	Ammo45 = { Name = ".45-Munition", Category = "Ammo", Stack = 80, Desc = "Fuer P45 Service." },
	Ammo38 = { Name = ".38-Munition", Category = "Ammo", Stack = 60, Desc = "Fuer R6 Revolver." },
	Ammo308 = { Name = ".308-Munition", Category = "Ammo", Stack = 40, Desc = "Fuer Ranger 308." },
	Ammo12g = { Name = "Schrotpatronen Kal. 12", Category = "Ammo", Stack = 48, Desc = "Fuer Coastline 12." },
	Ammo556 = { Name = "5.56-Munition", Category = "Ammo", Stack = 120, Desc = "Fuer Keystone Karabiner." },
	WeaponLicense = { Name = "Waffenschein", Category = "Documents", Stack = 1, Desc = "Erlaubt Kauf und Besitz von Waffen. Ausstellung im Waffenladen (ab 21, ohne offene Fahndung/Haftbefehl)." },
	-- Zubehoer / Aufbewahrung
	Holster = { Name = "Holster", Category = "Gear", Stack = 1, Desc = "Guerteltasche fuer Kurzwaffen." },
	WeaponLight = { Name = "Waffenlicht", Category = "Gear", Stack = 2, Desc = "Aufsteckbare Lampe." },
	GunCase = { Name = "Waffenkoffer", Category = "Gear", Stack = 2, Desc = "Abschliessbarer Transportkoffer." },
	TriggerLock = { Name = "Abzugsschloss", Category = "Gear", Stack = 3, Desc = "Sichert eine Waffe gegen unbefugte Benutzung." },
	CleaningKit = { Name = "Reinigungsset", Category = "Gear", Stack = 2, Desc = "Pflegeset fuer Waffen." },
	RangeBag = { Name = "Schiessstand-Tasche", Category = "Gear", Stack = 1, Desc = "Tasche fuer Gehoerschutz und Zubehoer." },
	-- Supermarkt
	Soda = { Name = "Limonade", Category = "Food", Stack = 10, Use = "Consume", Desc = "Eiskalte Dose." },
	EnergyDrink = { Name = "Energy-Drink", Category = "Food", Stack = 6, Use = "Consume", Desc = "Fuer lange Schichten." },
	Sandwich = { Name = "Sandwich", Category = "Food", Stack = 6, Use = "Consume", Desc = "Frisch belegt." },
	Chips = { Name = "Chips", Category = "Food", Stack = 10, Use = "Consume", Desc = "Salzig und knusprig." },
	Fruit = { Name = "Obst", Category = "Food", Stack = 10, Use = "Consume", Desc = "Florida-Orangen." },
	Batteries = { Name = "Batterien", Category = "Misc", Stack = 10, Desc = "AA-Batterien." },
	Sunscreen = { Name = "Sonnencreme", Category = "Misc", Stack = 3, Desc = "LSF 50 - Pflicht in Miami." },
	Umbrella = { Name = "Regenschirm", Category = "Misc", Stack = 1, Desc = "Fuer Gewitter am Nachmittag." },
	-- Werkzeugladen
	Hammer = { Name = "Hammer", Category = "Tools", Stack = 1, Desc = "Allzweck-Hammer." },
	Screwdriver = { Name = "Schraubendreher-Set", Category = "Tools", Stack = 1, Desc = "Schlitz und Kreuz." },
	DuctTape = { Name = "Panzerband", Category = "Tools", Stack = 5, Desc = "Haelt fast alles zusammen." },
	Toolbox = { Name = "Werkzeugkasten", Category = "Tools", Stack = 1, Desc = "Gefuellter Werkzeugkasten." },
	Crowbar = { Name = "Brechstange", Category = "Tools", Stack = 1, Desc = "Schweres Werkzeug." },
	RepairKit = { Name = "Reparaturset", Category = "Tools", Stack = 3, Desc = "Fuer kleinere Reparaturen an Fahrzeugen (Funktion folgt)." },
	-- Beute aus Ueberfaellen (Prompt 09): illegal, beim Hehler zu Bargeld, von der Polizei beschlagnahmbar
	MarkedCash = { Name = "Markierte Geldbuendel", Category = "Loot", Stack = 120, Illegal = true, Desc = "Je $100, aus einem Banktresor. Nur beim Hehler verwertbar - die Polizei sucht danach." },
	StolenJewelry = { Name = "Gestohlener Schmuck", Category = "Loot", Stack = 40, Illegal = true, Desc = "Je $250 Wert. Nur beim Hehler verwertbar." },
	-- Juwelier
	Watch = { Name = "Armbanduhr", Category = "Valuables", Stack = 3, Desc = "Edelstahl-Chronograph." },
	GoldRing = { Name = "Goldring", Category = "Valuables", Stack = 5, Desc = "14 Karat." },
	Necklace = { Name = "Halskette", Category = "Valuables", Stack = 3, Desc = "Feine Goldkette." },
	DiamondEarrings = { Name = "Diamant-Ohrstecker", Category = "Valuables", Stack = 2, Desc = "Brillanten in Weissgold." },
	-- Prompt 10: Restaurants, Cafes, Bars (Use "Meal": heilt wenig, Amount), Freizeit, Shopping
	Burger = { Name = "Cheeseburger", Category = "Food", Stack = 5, Use = "Meal", Amount = 6, Desc = "Doppelt Kaese, frisch vom Grill." },
	Fries = { Name = "Pommes", Category = "Food", Stack = 5, Use = "Meal", Amount = 3, Desc = "Knusprig, mit Meersalz." },
	Milkshake = { Name = "Milkshake", Category = "Food", Stack = 5, Use = "Meal", Amount = 3, Desc = "Vanille, Erdbeer oder Schoko." },
	Pancakes = { Name = "Pancakes", Category = "Food", Stack = 5, Use = "Meal", Amount = 6, Desc = "Mit Ahornsirup - Diner-Klassiker." },
	Pizza = { Name = "Pizza", Category = "Food", Stack = 4, Use = "Meal", Amount = 8, Desc = "Steinofen, Margherita oder Pepperoni." },
	Sushi = { Name = "Sushi-Platte", Category = "Food", Stack = 4, Use = "Meal", Amount = 7, Desc = "Nigiri und Maki." },
	Tacos = { Name = "Tacos", Category = "Food", Stack = 5, Use = "Meal", Amount = 6, Desc = "Drei Tacos mit Salsa." },
	Cubano = { Name = "Cubano-Sandwich", Category = "Food", Stack = 5, Use = "Meal", Amount = 7, Desc = "Schwein, Schinken, Kaese, Pickles." },
	Pasta = { Name = "Pasta", Category = "Food", Stack = 4, Use = "Meal", Amount = 7, Desc = "Hausgemachte Tagliatelle." },
	Steak = { Name = "Ribeye-Steak", Category = "Food", Stack = 3, Use = "Meal", Amount = 10, Desc = "Dry aged, medium rare." },
	Lobster = { Name = "Hummer", Category = "Food", Stack = 2, Use = "Meal", Amount = 10, Desc = "Florida Spiny Lobster mit Butter." },
	Salad = { Name = "Bowl & Salat", Category = "Food", Stack = 5, Use = "Meal", Amount = 5, Desc = "Quinoa, Avocado, Mango." },
	Ribs = { Name = "BBQ Ribs", Category = "Food", Stack = 3, Use = "Meal", Amount = 9, Desc = "Langsam gegart, rauchig." },
	PadThai = { Name = "Pad Thai", Category = "Food", Stack = 4, Use = "Meal", Amount = 7, Desc = "Reisnudeln, Erdnuss, Limette." },
	Donut = { Name = "Donut", Category = "Food", Stack = 6, Use = "Meal", Amount = 2, Desc = "Glasiert." },
	Croissant = { Name = "Croissant", Category = "Food", Stack = 6, Use = "Meal", Amount = 3, Desc = "Buttrig und frisch." },
	Gelato = { Name = "Gelato", Category = "Food", Stack = 4, Use = "Meal", Amount = 2, Desc = "Zwei Kugeln nach Wahl." },
	IcedCoffee = { Name = "Iced Latte", Category = "Food", Stack = 5, Use = "Meal", Amount = 2, Desc = "Kalt gebruehter Kaffee." },
	Smoothie = { Name = "Smoothie", Category = "Food", Stack = 5, Use = "Meal", Amount = 3, Desc = "Mango-Maracuja." },
	Mocktail = { Name = "Mocktail (alkoholfrei)", Category = "Food", Stack = 5, Use = "Meal", Amount = 2, Desc = "Virgin Mojito oder Sunrise." },
	Lemonade = { Name = "Hausgemachte Limonade", Category = "Food", Stack = 5, Use = "Meal", Amount = 2, Desc = "Limette und Minze." },
	CinemaTicket = { Name = "Kinoticket", Category = "Leisure", Stack = 4, Desc = "Eintritt fuer den Kinosaal (Bayfront Social)." },
	VIPPass = { Name = "VIP-Armband", Category = "Leisure", Stack = 1, Desc = "Zugang zu den VIP-Lounges der Clubs. Gilt dauerhaft." },
	GymPass = { Name = "Fitness-Mitgliedschaft", Category = "Leisure", Stack = 1, Desc = "Training im Iron Bay Fitness ohne Tagesgebuehr." },
	Basketball = { Name = "Basketball", Category = "Leisure", Stack = 1, Desc = "Fuer den Court an der Bayfront-Promenade." },
	Book = { Name = "Buch", Category = "Misc", Stack = 5, Desc = "Ein Roman fuer den Strand." },
	Flowers = { Name = "Blumenstrauss", Category = "Misc", Stack = 3, Desc = "Frische Blumen." },
	Toy = { Name = "Spielzeug", Category = "Misc", Stack = 3, Desc = "Ein Geschenk." },
	Headphones = { Name = "Kopfhoerer", Category = "Tools", Stack = 1, Desc = "Kabellos, mit Geraeuschunterdrueckung." },
	Laptop = { Name = "Laptop", Category = "Tools", Stack = 1, Desc = "Fuer Arbeit und Spiel." },
	Sunglasses = { Name = "Sonnenbrille", Category = "Misc", Stack = 2, Desc = "Polarisiert." },
	Surfboard = { Name = "Surfbrett", Category = "Leisure", Stack = 1, Desc = "Fuer die Wellen an Coral Key." },
	HotDog = { Name = "Hot Dog", Category = "Food", Stack = 5, Use = "Meal", Amount = 4, Desc = "Mit Senf und Roestzwiebeln." }, -- Prompt 12
}

Items.MaxSlots = 24

Items.StartInventory = { Phone = 1, IDCard = 1, DriversLicense = 1, WaterBottle = 2, Snack = 2, Bandage = 1 }

return Items
