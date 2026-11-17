-- Kriminalitaet (Prompt 09): rein fiktive, abstrakte Gameplay-Mechaniken.
-- Der Server rechnet AUSSCHLIESSLICH mit diesen Werten (Clients zeigen sie nur an).
local rgb = Color3.fromRGB
local Crime = {}

-- Fahndungsstufen (Record.WantedLevel). Decay = Minuten bis zur naechst niedrigeren Stufe ohne neue Straftat.
Crime.WantedLevels = {
	[0] = { Name = "Unauffaellig", Color = rgb(80, 220, 140), Decay = 0 },
	[1] = { Name = "Gesucht", Color = rgb(255, 196, 80), Decay = 10 },
	[2] = { Name = "Hoch gesucht", Color = rgb(255, 130, 60), Decay = 15 },
	[3] = { Name = "Prioritaetsfahndung", Color = rgb(255, 70, 80), Decay = 20 },
}
Crime.MaxWantedLevel = 3

-- Ueberfaelle. Tiers = Schwierigkeitsstufen (Standard aktiv, weitere fuer spaetere Erweiterungen vorbereitet).
-- MinPolice: Polizisten im Dienst | Duration: Sekunden Arbeit im Ueberfallbereich | Reward: Gesamtbeute in $ (Spanne)
-- Cooldown: Sekunden bis zum naechsten Ueberfall dieses Ortes | Wanted: Fahndungsstufe der Taeter
Crime.Heists = {
	Bank = {
		Name = "Miami State Bank", Kind = "Vault", CallCategory = "BankRobbery", CallName = "10-90 Bankueberfall - Miami State Bank",
		DefaultTier = "Standard", MaxCrew = 4, Radius = 18, AbandonSeconds = 25, PlayerCooldown = 2700, MinPlayHours = 1,
		Loot = "MarkedCash",
		Tiers = {
			{ Id = "Easy", Name = "Leicht (vorbereitet)", Enabled = false, MinPolice = 2, Duration = 90, Reward = { 2500, 3500 }, Cooldown = 1500, Wanted = 2 },
			{ Id = "Standard", Name = "Standard", Enabled = true, MinPolice = 3, Duration = 150, Reward = { 4500, 6500 }, Cooldown = 1800, Wanted = 3 },
			{ Id = "Hard", Name = "Schwer (vorbereitet)", Enabled = false, MinPolice = 5, Duration = 240, Reward = { 8000, 11000 }, Cooldown = 3600, Wanted = 3 },
		},
	},
	Jeweler = {
		Name = "Miami Gold Jewelers", Kind = "Cases", CallCategory = "JewelryRobbery", CallName = "10-90 Juwelierueberfall - Miami Gold Jewelers",
		DefaultTier = "Standard", MaxCrew = 3, Radius = 22, AbandonSeconds = 25, PlayerCooldown = 1800,
		Loot = "StolenJewelry", CaseHold = 3.5,
		Tiers = {
			{ Id = "Standard", Name = "Standard", Enabled = true, MinPolice = 2, Duration = 120, Reward = { 500, 800 }, Cooldown = 1200, Wanted = 2 }, -- Reward je Vitrine
		},
	},
}

-- Hehler: wandelt Beute in Bargeld (ueber EconomyService, mit Abschlag und Stundenlimit)
Crime.Fence = {
	Cut = 0.2, -- 20 % Abschlag
	HourlyCap = 12000, -- max. $ illegale Einnahmen pro Spieler und Stunde
	Range = 10,
}
-- Wert je Beute-Einheit (Gegenstaende in Config.Items, Category "Loot")
Crime.LootValue = { MarkedCash = 100, StolenJewelry = 250 }

-- Studio-Tests: Mindestanzahl Polizei aufheben (nur RunService:IsStudio() + Debug-Befehl)
Crime.StudioTestMinPolice = 0

-- Vorbereitete Aktivitaeten (technische Grundlage, noch nicht spielbar). CrimeService.Register(id, handler) schaltet frei.
Crime.Activities = {
	Shoplifting = { Name = "Ladendiebstahl", Enabled = false, Wanted = 1, Charges = { "PC-201" }, Note = "Kassen in begehbaren Laeden (Tag Interactable/Register), kleine Beute, kurze Abklingzeit" },
	CarTheft = { Name = "Fahrzeugdiebstahl", Enabled = false, Wanted = 2, Charges = { "PC-301" }, Note = "Geparkte NPC-Fahrzeuge (Tag ParkedCar), abstrakte Interaktion, Abgabe beim Hehler" },
	IllegalRace = { Name = "Illegales Rennen", Enabled = false, Wanted = 1, Charges = { "PC-302" }, Note = "Start/Ziel-Marker, Teilnehmerliste, Einsatz bei Polizei als P2" },
	NPCCrime = { Name = "Kriminelle NPC-Ereignisse", Enabled = false, Wanted = 0, Note = "Zufaellige Einsaetze fuer die Polizei (Ladenueberfall durch NPC, Verfolgung)" },
}

-- Spaeter: kriminelle Organisationen (Gruppen, gemeinsame Kasse, Reviere) - Profilfeld Crime.Organization vorbereitet
Crime.Organizations = { Enabled = false, MaxMembers = 8 }

return Crime
