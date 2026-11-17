-- Feuerwehr (Fire) und Rettungsdienst (EMS): Fahrzeuge, Wachen-Terminals, Uniform, Brand- und Verletzungssystem.
-- Rechte stehen in Factions.luau und werden serverseitig mit JobService.HasPermission geprueft.
local Rescue = {}

-- Gemeinsame Dienstlogik je Fraktion (RescueService)
Rescue.Fire = {
	DutyTerminal = "FireDuty", -- Interaktionstyp am Dienst-Terminal
	GarageTerminal = "FireGarage",
	GarageSpawnTag = "FireGarageSpawn",
	GarageParkTag = "FireGaragePark",
	EquipmentTerminal = "FireEquipment",
	Radio = "FD1",
	PlatePrefix = "MSFD",
	Accent = Color3.fromRGB(255, 80, 60),
	-- Rufzeichen nach Rang: Engine/Ladder/Rescue/Battalion/Chief + Nummer
	CallsignUnits = { [1] = "ENGINE", [2] = "ENGINE", [3] = "LADDER", [4] = "RESCUE", [5] = "CAPTAIN", [6] = "BATTALION", [7] = "CHIEF" },
	Vehicles = {
		{ Id = "FireEngine", Name = "Fire Engine", MinRank = 1, Desc = "Loeschfahrzeug mit Pumpe und Schlauchhaspel - Wasserversorgung fuer Strahlrohre" },
		{ Id = "FireRescue", Name = "Rescue Squad", MinRank = 2, Desc = "Ruestwagen fuer technische Hilfeleistung" },
		{ Id = "LadderTruck", Name = "Ladder Truck", MinRank = 3, Desc = "Drehleiter, ebenfalls mit Wasserversorgung" },
		{ Id = "FireCommand", Name = "Command Vehicle", MinRank = 4, Desc = "Einsatzleitwagen (Lieutenant und hoeher)" },
	},
	-- Werkzeuge (Roblox-Tools), die beim Dienstantritt ausgegeben werden
	Tools = { "Extinguisher", "Hose" },
	Uniform = {
		Prefix = "FD_",
		Torso = Color3.fromRGB(176, 140, 80), Legs = Color3.fromRGB(150, 118, 66),
		Parts = {
			{ "Helmet", "HatAttachment", Vector3.new(1.5, 0.6, 1.7), Color3.fromRGB(30, 30, 34), "SmoothPlastic", CFrame.new(0, -0.1, 0) },
			{ "HelmetShield", "HatAttachment", Vector3.new(0.6, 0.5, 0.08), Color3.fromRGB(214, 172, 74), "Foil", CFrame.new(0, -0.15, -0.86) },
			{ "ReflectorChest", "BodyFrontAttachment", Vector3.new(2.05, 0.25, 0.08), Color3.fromRGB(210, 255, 90), "Neon", CFrame.new(0, -0.55, 0.06) },
			{ "ReflectorBack", "BodyBackAttachment", Vector3.new(2.05, 0.25, 0.08), Color3.fromRGB(210, 255, 90), "Neon", CFrame.new(0, -0.55, -0.06) },
			{ "AirTank", "BodyBackAttachment", Vector3.new(0.7, 1.4, 0.6), Color3.fromRGB(200, 200, 206), "Metal", CFrame.new(0, 0, -0.35) },
			{ "Radio", "LeftCollarAttachment", Vector3.new(0.3, 0.5, 0.2), Color3.fromRGB(30, 30, 32), "Plastic", CFrame.new(0, -0.2, 0.25) },
		},
	},
}

Rescue.EMS = {
	DutyTerminal = "EMSDuty",
	GarageTerminal = "EMSGarage",
	GarageSpawnTag = "EMSGarageSpawn",
	GarageParkTag = "EMSGaragePark",
	EquipmentTerminal = "EMSEquipment",
	Radio = "EMS1",
	PlatePrefix = "EMS",
	Accent = Color3.fromRGB(80, 200, 255),
	CallsignUnits = { [1] = "MEDIC", [2] = "MEDIC", [3] = "MEDIC", [4] = "EMS", [5] = "DIRECTOR" },
	Vehicles = {
		{ Id = "Ambulance", Name = "Ambulance", MinRank = 1, Desc = "Standard-Rettungswagen mit Patiententrage" },
		{ Id = "AmbulanceHeavy", Name = "Heavy Rescue Ambulance", MinRank = 2, Desc = "Grosser Rettungswagen, zwei Tragen" },
		{ Id = "EMSResponder", Name = "Medical Responder", MinRank = 3, Desc = "Notarzt-/Einsatzfuehrungsfahrzeug" },
	},
	Tools = {},
	-- Ausruestung im Inventar (wird bei Dienstende wieder eingezogen)
	Supplies = { Bandage = 10, Medkit = 4, Defibrillator = 1 },
	Uniform = {
		Prefix = "EM_",
		Torso = Color3.fromRGB(40, 46, 60), Legs = Color3.fromRGB(28, 32, 42),
		Parts = {
			{ "Cap", "HatAttachment", Vector3.new(1.3, 0.42, 1.4), Color3.fromRGB(28, 32, 42), "Fabric", CFrame.new(0, -0.15, 0) },
			{ "StarOfLife", "BodyFrontAttachment", Vector3.new(0.45, 0.45, 0.08), Color3.fromRGB(40, 110, 230), "SmoothPlastic", CFrame.new(-0.35, -0.3, 0.05) },
			{ "ReflectorChest", "BodyFrontAttachment", Vector3.new(2.05, 0.22, 0.08), Color3.fromRGB(220, 255, 90), "Neon", CFrame.new(0, -0.6, 0.06) },
			{ "ReflectorBack", "BodyBackAttachment", Vector3.new(2.05, 0.22, 0.08), Color3.fromRGB(220, 255, 90), "Neon", CFrame.new(0, -0.6, -0.06) },
			{ "Radio", "LeftCollarAttachment", Vector3.new(0.3, 0.5, 0.2), Color3.fromRGB(30, 30, 32), "Plastic", CFrame.new(0, -0.2, 0.25) },
		},
	},
}

-- Brandsystem (FireService) ---------------------------------------------------------------------------------
Rescue.Fires = {
	MaxIncidents = 3, -- gleichzeitige Brand-/Hilfeleistungseinsaetze
	MaxFlames = 14, -- harte Obergrenze aller Brandherde auf dem Server
	MaxPerIncident = 4, -- Brandherde je Einsatz
	AutoIncidentEvery = { 420, 720 }, -- Sekunden zwischen automatischen Einsaetzen (nur wenn Feuerwehr im Dienst)
	SpreadEvery = 45, -- Ausbreitung eines ungeloeschten Brandherds
	DamagePerSecond = 6, -- Schaden fuer Personen im Brandherd (ohne Schutzausruestung)
	Reward = { Base = 250, PerFlame = 60 }, -- Praemie fuer beteiligte Einsatzkraefte
	ParticipationRadius = 120,
	-- Einsatzarten: Kategorie im Dispatch, Brandlast (HP je Herd), Herde, Fundorte (Tag der Weltmarker)
	Types = {
		Building = { Category = "StructureFire", Name = "Gebaeudebrand", Flames = { 3, 4 }, HP = 160, Spot = "FireSpot_Building" },
		Vehicle = { Category = "VehicleFire", Name = "Fahrzeugbrand", Flames = { 1, 2 }, HP = 110, Spot = "FireSpot_Vehicle" },
		Dumpster = { Category = "DumpsterFire", Name = "Muellcontainerbrand", Flames = { 1, 1 }, HP = 70, Spot = "FireSpot_Dumpster" },
		Brush = { Category = "BrushFire", Name = "Flaechenbrand", Flames = { 2, 4 }, HP = 80, Spot = "FireSpot_Brush" },
		Rescue = { Category = "TechRescue", Name = "Technische Hilfeleistung", Flames = { 0, 0 }, HP = 0, Spot = "FireSpot_Rescue", WorkSeconds = 20 },
	},
	-- Loeschgeraete: Reichweite, Wirkung je Treffer, Abstand zwischen Treffern
	Tools = {
		Extinguisher = { Name = "Feuerloescher", Range = 16, Power = 9, Interval = 0.25, Charges = 60 },
		Hose = { Name = "Strahlrohr", Range = 42, Power = 16, Interval = 0.2, NeedsEngine = 90 }, -- Wasser nur in Reichweite eines Loeschfahrzeugs
	},
}

-- Verletzungssystem (MedicalService) ------------------------------------------------------------------------
Rescue.Medical = {
	MinorBelow = 70, -- Lebenspunkte: darunter leicht verletzt
	SevereBelow = 35, -- darunter schwer verletzt (langsamer)
	SevereWalkSpeed = 9,
	BleedoutSeconds = 300, -- bewusstlos ohne Hilfe -> Krankenhaus
	StabilizedBonus = 300, -- Stabilisieren verlaengert die Zeit
	ReviveHealth = 40,
	TreatCost = 250, -- Behandlungskosten im Krankenhaus (Konto, sonst bar)
	RespawnCost = 500, -- Selbsteinweisung nach Ablauf der Zeit
	FallDamageSpeed = 62, -- Fallgeschwindigkeit (Studs/s), ab der Sturzschaden entsteht
	FallDamageFactor = 1.3,
	VehicleHitSpeed = 30, -- Geschwindigkeit eines Fahrzeugs, ab der ein Zusammenstoss verletzt
	CrashDecel = 55, -- Geschwindigkeitsverlust (Studs/s in 0.2 s) fuer Insassen
	Treatments = {
		Bandage = { Heal = 15, MaxTo = 70 },
		Medkit = { Heal = 45, MaxTo = 90 },
	},
}

-- Einsatzkategorien fuer Feuerwehr/EMS (ergaenzen Police.CallCategories im gemeinsamen Dispatch)
Rescue.CallCategories = {
	{ Id = "StructureFire", Name = "Gebaeudebrand", Services = { "Fire", "Police" }, Priority = 1 },
	{ Id = "VehicleFire", Name = "Fahrzeugbrand", Services = { "Fire" }, Priority = 2 },
	{ Id = "DumpsterFire", Name = "Muellcontainerbrand", Services = { "Fire" }, Priority = 3 },
	{ Id = "BrushFire", Name = "Flaechenbrand", Services = { "Fire" }, Priority = 2 },
	{ Id = "TechRescue", Name = "Technische Hilfeleistung", Services = { "Fire", "EMS" }, Priority = 2 },
	{ Id = "Unconscious", Name = "Bewusstlose Person", Services = { "EMS" }, Priority = 1 },
	{ Id = "Injured", Name = "Verletzte Person", Services = { "EMS" }, Priority = 2 },
}

return Rescue
