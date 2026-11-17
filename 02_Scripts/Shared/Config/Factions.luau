-- Fraktionen, Dienstgrade, Gehaelter und Berechtigungen.
-- Rang-Berechtigungen gelten ab dem angegebenen Rang (Index) aufwaerts.
-- Neue Berechtigungen einfach als String ergaenzen und serverseitig mit JobService.HasPermission pruefen.
local Factions = {}

Factions.Order = { "Civilian", "Police", "Fire", "EMS" }

Factions.Civilian = {
	Name = "Zivilbevoelkerung",
	Short = "CIV",
	Color = Color3.fromRGB(150, 156, 170),
	Whitelisted = false, -- frei waehlbar am Jobcenter
	DutyRequired = false,
	Ranks = {
		{ Id = "Citizen", Name = "Zivilist", Salary = 50 }, -- Prompt 11: Grundsicherung; Verdienst ueber Berufe (Config.Work)
		{ Id = "Employee", Name = "Angestellter", Salary = 50 },
		{ Id = "SelfEmployed", Name = "Selbststaendiger", Salary = 50 },
		{ Id = "Entrepreneur", Name = "Unternehmer", Salary = 50 },
	},
	Permissions = { "Vehicle.Civilian" },
	RankPermissions = {},
}

Factions.Police = {
	Name = "Miami State Police",
	Short = "MSP",
	Color = Color3.fromRGB(60, 120, 255),
	Whitelisted = true,
	DutyRequired = true, -- Gehalt nur im Dienst
	DutyLocation = "PoliceDuty", -- Dienstantritt nur am Dienst-Terminal der Wache
	Ranks = {
		{ Id = "Cadet", Name = "Cadet", Salary = 200 },
		{ Id = "Officer", Name = "Police Officer", Salary = 300 },
		{ Id = "SeniorOfficer", Name = "Senior Officer", Salary = 340 },
		{ Id = "Corporal", Name = "Corporal", Salary = 380 },
		{ Id = "Sergeant", Name = "Sergeant", Salary = 430 },
		{ Id = "Lieutenant", Name = "Lieutenant", Salary = 500 },
		{ Id = "Captain", Name = "Captain", Salary = 580 },
		{ Id = "DeputyChief", Name = "Deputy Chief", Salary = 660 },
		{ Id = "Chief", Name = "Chief of Police", Salary = 750 },
	},
	-- Basis fuer alle Raenge (auch Cadets): Funk, MDT lesen, Streifenwagen
	Permissions = { "Vehicle.Civilian", "Police.Radio", "Police.MDT", "Police.Duty" },
	RankPermissions = {
		[2] = { "Police.Cuff", "Police.Search", "Police.Escort", "Police.Cite", "Police.Arrest", "Police.Jail", "Police.Wanted", "Police.TrafficStop" },
		[3] = { "Police.Confiscate" },
		[5] = { "Police.Warrant", "Police.Supervisor", "Dispatch.Assign", "Radio.Command" },
		[6] = { "Faction.ManageRanks", "Faction.Hire" },
		[7] = { "Faction.Fire" },
	},
	-- Datenmigration Schema 1 -> 2 (alte 5 Raenge -> neue 9 Raenge)
	LegacyRankMap = { [1] = 2, [2] = 5, [3] = 6, [4] = 7, [5] = 9 },
}

Factions.Fire = {
	Name = "Miami State Fire Department",
	Short = "MSFD",
	Color = Color3.fromRGB(255, 80, 60),
	Whitelisted = true,
	DutyRequired = true,
	DutyLocation = "FireDuty", -- Dienstantritt nur an der Feuerwache
	Ranks = {
		{ Id = "Firefighter", Name = "Firefighter", Salary = 260 },
		{ Id = "SeniorFirefighter", Name = "Senior Firefighter", Salary = 310 },
		{ Id = "Engineer", Name = "Engineer", Salary = 360 },
		{ Id = "Lieutenant", Name = "Lieutenant", Salary = 430 },
		{ Id = "Captain", Name = "Captain", Salary = 510 },
		{ Id = "BattalionChief", Name = "Battalion Chief", Salary = 600 },
		{ Id = "Chief", Name = "Fire Chief", Salary = 700 },
	},
	-- Basis: Funk, Loeschen, Erste Hilfe (Untersuchen/Stabilisieren), Fire Engine
	Permissions = { "Vehicle.Civilian", "Fire.Radio", "Fire.Duty", "Fire.Extinguish", "Fire.Equipment", "EMS.Examine", "EMS.Stabilize" },
	RankPermissions = {
		[2] = { "Fire.Rescue" },
		[4] = { "Fire.IncidentCommand", "Dispatch.Assign", "Radio.Command", "Fire.Supervisor" },
		[5] = { "Faction.ManageRanks", "Faction.Hire" },
		[6] = { "Faction.Fire" },
	},
	-- Datenmigration Schema 2 -> 3 (alte 5 Raenge -> neue 7 Raenge)
	LegacyRankMap = { [1] = 1, [2] = 3, [3] = 4, [4] = 5, [5] = 7 },
}

Factions.EMS = {
	Name = "Miami State EMS",
	Short = "EMS",
	Color = Color3.fromRGB(240, 244, 255),
	Whitelisted = true,
	DutyRequired = true,
	DutyLocation = "EMSDuty", -- Dienstantritt nur im Krankenhaus
	Ranks = {
		{ Id = "EMT", Name = "EMT", Salary = 250 },
		{ Id = "Paramedic", Name = "Paramedic", Salary = 340 },
		{ Id = "SeniorParamedic", Name = "Senior Paramedic", Salary = 410 },
		{ Id = "Supervisor", Name = "EMS Supervisor", Salary = 500 },
		{ Id = "Director", Name = "Medical Director", Salary = 650 },
	},
	-- Basis: Funk, Untersuchen, Stabilisieren, Transport, Standard-Ambulanz
	Permissions = { "Vehicle.Civilian", "EMS.Radio", "EMS.Duty", "EMS.Examine", "EMS.Stabilize", "EMS.Transport" },
	RankPermissions = {
		[2] = { "EMS.Revive", "EMS.Treat" },
		[3] = { "EMS.Medication" },
		[4] = { "EMS.Supervisor", "Dispatch.Assign", "Radio.Command", "Faction.ManageRanks", "Faction.Hire" },
		[5] = { "Faction.Fire" },
	},
	LegacyRankMap = { [1] = 1, [2] = 2, [3] = 4, [4] = 5 },
}

-- Zuordnung Spawnpunkt-Gruppe (Attribut "RequiredJob" an VehicleSpawnPads) -> Fraktion
Factions.JobGroups = { Police = "Police", Fire = "Fire", EMS = "EMS" }

return Factions
