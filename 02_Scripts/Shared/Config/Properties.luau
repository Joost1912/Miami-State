-- Immobilien (Prompt 10): Apartmenthaeuser, Wohnungsklassen, Preise, Miete, Moebel.
-- Abgerechnet wird NUR mit diesen Serverwerten. Wohnungen sind instanziert: jede Wohnung erhaelt beim Betreten
-- einen eigenen Innenraum (Vorlage ServerStorage.ApartmentInteriors.<Tier>) ueber der Palmetto Bay.
local rgb = Color3.fromRGB
local P = {}

P.MaxProperties = 2
P.SellFactor = 0.7 -- Rueckkauf durch die Hausverwaltung
P.RentDays = 7 -- Mietzeitraum in echten Tagen (Vorauszahlung, automatische Verlaengerung vom Bankkonto)
P.InviteSeconds = 300 -- Einladung gilt 5 Minuten
P.MaxKeys = 6
P.MaxFurniture = 30

P.Tiers = {
	Standard = { Name = "Standard Apartment", Price = 65000, Rent = 900, Rooms = "Wohnzimmer, Schlafzimmer, Kueche, Bad, kleiner Balkon", Color = rgb(120, 200, 140) },
	City = { Name = "Moderne Stadtwohnung", Price = 140000, Rent = 1900, Rooms = "Offener Wohn-/Essbereich, Schlafzimmer, Designkueche, Bad, Balkon", Color = rgb(80, 170, 255) },
	Luxury = { Name = "Luxury Apartment", Price = 320000, Rent = 4200, Rooms = "Grosses Wohnzimmer, moderne Kueche, Master-Schlafzimmer, Bad, Balkon mit Stadtblick", Color = rgb(220, 180, 90) },
	Penthouse = { Name = "Penthouse", Price = 950000, Rent = 12500, Rooms = "Fensterfronten, Dachterrasse, Luxusmoebel, ueber 400 qm mit Blick auf Downtown", Color = rgb(255, 72, 168) },
}
P.TierOrder = { "Standard", "City", "Luxury", "Penthouse" }

-- Gebaeude: Eingang = Tag "Interactable", InteractType "Property", Attribut BuildingId
P.Buildings = {
	SawgrassGardens = { Name = "Sawgrass Gardens", District = "Sawgrass Park", Prefix = "SG", Tiers = { "Standard" }, Desc = "Ruhige Wohnanlage im Gruenen - bezahlbar und familienfreundlich." },
	BrickellHeights = { Name = "Brickell Heights", District = "Midtown (Brickell)", Prefix = "BH", Tiers = { "Standard", "City" }, Desc = "Moderne Stadtwohnungen im Finanzviertel, kurze Wege zu Buero und Bar." },
	OceanDrive = { Name = "Ocean Drive Residences", District = "Waterfront (Coral Key)", Prefix = "OD", Tiers = { "City", "Luxury" }, Desc = "Wohnen am Wasser mit Meerblick und Concierge." },
	BayfrontOne = { Name = "Bayfront One", District = "Bayfront Downtown", Prefix = "B1", Tiers = { "Luxury", "Penthouse" }, Desc = "Das hoechste Wohnhaus der Stadt - Luxus und Penthouses ueber Downtown." },
}
P.BuildingOrder = { "SawgrassGardens", "BrickellHeights", "OceanDrive", "BayfrontOne" }

-- Moebel (Grundlage Einrichtungssystem): wird im Innenraum frei platziert (Position vor dem Spieler)
P.Furniture = {
	{ Id = "Sofa", Name = "Sofa (3-Sitzer)", Price = 1400, Size = Vector3.new(8, 3, 3.4), Color = rgb(70, 74, 84) },
	{ Id = "Armchair", Name = "Sessel", Price = 650, Size = Vector3.new(3.6, 3, 3.4), Color = rgb(150, 110, 80) },
	{ Id = "CoffeeTable", Name = "Couchtisch", Price = 380, Size = Vector3.new(5, 1.4, 2.6), Color = rgb(60, 45, 35) },
	{ Id = "DiningTable", Name = "Esstisch mit Stuehlen", Price = 1200, Size = Vector3.new(7, 3, 4), Color = rgb(190, 160, 120) },
	{ Id = "TV", Name = "TV-Board mit Fernseher", Price = 1800, Size = Vector3.new(7, 4.6, 1.6), Color = rgb(25, 25, 28) },
	{ Id = "Bookshelf", Name = "Buecherregal", Price = 520, Size = Vector3.new(4, 7, 1.4), Color = rgb(120, 85, 55) },
	{ Id = "Plant", Name = "Zimmerpalme", Price = 180, Size = Vector3.new(2, 6, 2), Color = rgb(60, 140, 70) },
	{ Id = "FloorLamp", Name = "Stehlampe", Price = 240, Size = Vector3.new(1.4, 6.5, 1.4), Color = rgb(230, 220, 200) },
	{ Id = "Rug", Name = "Teppich", Price = 300, Size = Vector3.new(9, 0.1, 6), Color = rgb(200, 190, 175) },
	{ Id = "Bed", Name = "Doppelbett", Price = 1600, Size = Vector3.new(6, 2.4, 7.5), Color = rgb(230, 232, 236) },
}
P.FurnitureById = {}
for _, f in ipairs(P.Furniture) do
	P.FurnitureById[f.Id] = f
end

return P
