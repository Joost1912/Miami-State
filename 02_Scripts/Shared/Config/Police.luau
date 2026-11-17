-- Polizei-Konfiguration: Fahrzeuge, Funk, Status, Strafkatalog, Verkehrsverstoesse, Notrufkategorien.
-- Der Server rechnet AUSSCHLIESSLICH mit diesen Werten (Clients zeigen sie nur an).
local Police = {}

-- Fuhrpark der Garage (MinRank = Index in Factions.Police.Ranks)
Police.Vehicles = {
	{ Id = "PoliceSedan", Name = "Police Sedan", MinRank = 1, Desc = "Standard-Streifenwagen" },
	{ Id = "PoliceSUV", Name = "Police SUV", MinRank = 2, Desc = "Gelaendegaengig, mehr Platz" },
	{ Id = "PoliceInterceptor", Name = "Police Interceptor", MinRank = 3, Desc = "Verfolgungsfahrzeug" },
	{ Id = "HighwayPatrol", Name = "Highway Patrol", MinRank = 4, Desc = "Autobahnpolizei, hohe Endgeschwindigkeit" },
	{ Id = "PoliceUnmarked", Name = "Unmarked Unit", MinRank = 5, Desc = "Zivilfahrzeug mit verdeckter Beleuchtung" },
}

-- Funkkanaele (Factions = wer darf, MinRank = ab welchem Rang innerhalb der Fraktion)
Police.Channels = {
	{ Id = "DISP", Name = "Dispatch", Factions = { "Police", "Fire", "EMS" }, MinRank = 1 },
	{ Id = "PD1", Name = "PD Main", Factions = { "Police" }, MinRank = 1 },
	{ Id = "PD2", Name = "PD Tactical", Factions = { "Police" }, MinRank = 2 },
	{ Id = "PDCMD", Name = "PD Command", Factions = { "Police" }, MinRank = 5 },
	{ Id = "INTEROP", Name = "Interop (PD/FD/EMS)", Factions = { "Police", "Fire", "EMS" }, MinRank = 1 },
	{ Id = "FD1", Name = "FD Main", Factions = { "Fire" }, MinRank = 1 },
	{ Id = "EMS1", Name = "EMS Main", Factions = { "EMS" }, MinRank = 1 },
}

-- Einheitenstatus (amerikanische 10-Codes)
Police.Statuses = {
	{ Id = "10-8", Name = "Einsatzbereit", Color = Color3.fromRGB(80, 220, 140) },
	{ Id = "10-6", Name = "Beschaeftigt", Color = Color3.fromRGB(255, 196, 80) },
	{ Id = "10-76", Name = "Auf Anfahrt", Color = Color3.fromRGB(64, 224, 255) },
	{ Id = "10-97", Name = "Vor Ort", Color = Color3.fromRGB(180, 120, 255) },
	{ Id = "10-7", Name = "Ausser Dienst", Color = Color3.fromRGB(150, 156, 170) },
}

-- Schnellmeldungen im Funk
Police.QuickCodes = {
	{ Code = "10-4", Text = "Verstanden" },
	{ Code = "10-9", Text = "Bitte wiederholen" },
	{ Code = "10-20", Text = "Standort?" },
	{ Code = "10-15", Text = "Verdaechtiger in Gewahrsam" },
	{ Code = "10-80", Text = "Verfolgung laeuft" },
	{ Code = "10-78", Text = "Verstaerkung benoetigt" },
	{ Code = "Code 4", Text = "Lage unter Kontrolle" },
}

-- Strafkatalog (Fine in $, Jail in Minuten Echtzeit)
Police.PenalCode = {
	{ Id = "PC-101", Title = "Hausfriedensbruch", Class = "Vergehen", Fine = 300, Jail = 1 },
	{ Id = "PC-102", Title = "Ruhestoerung / ungebuehrliches Verhalten", Class = "Vergehen", Fine = 250, Jail = 0 },
	{ Id = "PC-201", Title = "Diebstahl", Class = "Vergehen", Fine = 1200, Jail = 4 },
	{ Id = "PC-202", Title = "Widerstand gegen Vollstreckungsbeamte", Class = "Vergehen", Fine = 800, Jail = 3 },
	{ Id = "PC-203", Title = "Koerperverletzung", Class = "Verbrechen", Fine = 2000, Jail = 6 },
	{ Id = "PC-301", Title = "Fahrzeugdiebstahl", Class = "Verbrechen", Fine = 2500, Jail = 8 },
	{ Id = "PC-302", Title = "Flucht vor der Polizei", Class = "Verbrechen", Fine = 1500, Jail = 5 },
	{ Id = "PC-303", Title = "Unerlaubter Waffenbesitz", Class = "Verbrechen", Fine = 3000, Jail = 6 },
	{ Id = "PC-401", Title = "Raub", Class = "Verbrechen", Fine = 5000, Jail = 12 },
	{ Id = "PC-402", Title = "Unfallflucht mit Personenschaden", Class = "Verbrechen", Fine = 3500, Jail = 8 },
}
Police.MaxJailMinutes = 30
Police.MaxChargesPerArrest = 6

-- Verkehrsverstoesse (Strafzettel)
Police.TrafficCode = {
	{ Id = "TC-01", Title = "Geschwindigkeitsueberschreitung", Fine = 150, Points = 2 },
	{ Id = "TC-02", Title = "Rotlichtverstoss", Fine = 200, Points = 2 },
	{ Id = "TC-03", Title = "Falschparken", Fine = 75, Points = 0 },
	{ Id = "TC-04", Title = "Vorfahrt missachtet", Fine = 150, Points = 2 },
	{ Id = "TC-05", Title = "Falsche Fahrtrichtung", Fine = 300, Points = 3 },
	{ Id = "TC-06", Title = "Ruecksichtsloses Fahren", Fine = 500, Points = 4 },
	{ Id = "TC-07", Title = "Fahren ohne Fahrerlaubnis", Fine = 400, Points = 0 },
}
Police.LicenseSuspendPoints = 12

-- Notruf 911
Police.CallCategories = {
	{ Id = "Robbery", Name = "Raub / Ueberfall", Services = { "Police" }, Priority = 1 },
	-- Systemalarme (Prompt 09, nicht im 911-Menue waehlbar: werden von CrimeService ausgeloest)
	{ Id = "BankRobbery", Name = "Bankueberfall", Services = { "Police" }, Priority = 1, System = true },
	{ Id = "JewelryRobbery", Name = "Juwelierueberfall", Services = { "Police" }, Priority = 1, System = true },
	{ Id = "Assault", Name = "Koerperverletzung", Services = { "Police", "EMS" }, Priority = 1 },
	{ Id = "Theft", Name = "Diebstahl", Services = { "Police" }, Priority = 2 },
	{ Id = "Accident", Name = "Verkehrsunfall", Services = { "Police", "EMS" }, Priority = 2 },
	{ Id = "Fire", Name = "Brand", Services = { "Fire" }, Priority = 1 },
	{ Id = "Medical", Name = "Medizinischer Notfall", Services = { "EMS" }, Priority = 1 },
	{ Id = "Suspicious", Name = "Verdaechtige Person / Aktivitaet", Services = { "Police" }, Priority = 3 },
	{ Id = "Other", Name = "Sonstiges", Services = { "Police" }, Priority = 3 },
}
Police.PriorityNames = { [1] = "P1 - Notfall", [2] = "P2 - Dringend", [3] = "P3 - Routine" }
Police.PriorityColors = { [1] = Color3.fromRGB(255, 86, 96), [2] = Color3.fromRGB(255, 196, 80), [3] = Color3.fromRGB(64, 224, 255) }

-- Sirenen (freie Audio-Assets aus dem Creator Store, "Quality looped police sirens")
Police.SirenTones = {
	{ Name = "Wail", SoundId = "rbxassetid://4832498807" },
	{ Name = "Yelp", SoundId = "rbxassetid://4832422661" },
	{ Name = "Priority", SoundId = "rbxassetid://4832478256" },
}
Police.HornSoundId = "rbxassetid://4832500775"

return Police
