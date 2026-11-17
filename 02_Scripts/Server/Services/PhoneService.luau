-- PhoneService: Server-Seite des Smartphones (Einstellungen, Kontakte, Spielerliste/Server-App).
-- Bank-, Fahrzeug- und Notruf-Apps nutzen die vorhandenen Systeme (EconomyService, VehicleService, DispatchService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local Factions = require(Shared.Config.Factions)

local PhoneService = {}
local S
local MAX_CONTACTS = 50

-- Erlaubte Einstellungen: Typ und Wertebereich
local SETTINGS = {
	SoundVolume = { "number", 0, 1 },
	MusicVolume = { "number", 0, 1 },
	Minimap = { "boolean" },
	MinimapZoom = { "number", 1, 4, true },
	UIScale = { "number", 0.8, 1.25 },
	Particles = { "boolean" },
	ShowHints = { "boolean" },
	Wallpaper = { "number", 1, 4, true },
}

function PhoneService.Init(services)
	S = services
end

local function rpName(d, p)
	return d and d.Character.Created and (d.Character.FirstName .. " " .. d.Character.LastName) or (p and p.Name) or "?"
end

function PhoneService.SaveSettings(player, values)
	if typeof(values) ~= "table" then
		return false, "Ungueltig"
	end
	local clean = {}
	for k, v in pairs(values) do
		local rule = SETTINGS[k]
		if not rule or typeof(v) ~= rule[1] then
			return false, "Ungueltige Einstellung: " .. tostring(k)
		end
		if rule[1] == "number" then
			if v ~= v or v < rule[2] or v > rule[3] or (rule[4] and v % 1 ~= 0) then
				return false, "Wert ausserhalb des Bereichs: " .. k
			end
			v = math.floor(v * 100 + 0.5) / 100
		end
		clean[k] = v
	end
	return S.DataService.Mutate(player, "PhoneSettings", function(d)
		for k, v in pairs(clean) do
			d.Phone.Settings[k] = v
		end
	end)
end

function PhoneService.AddContact(player, userId)
	local target = typeof(userId) == "number" and Players:GetPlayerByUserId(userId)
	if not target or target == player then
		return false, "Spieler nicht gefunden"
	end
	local td = S.DataService.Get(target)
	if not td then
		return false, "Spieler nicht gefunden"
	end
	local name = rpName(td, target)
	local ok, err = S.DataService.Mutate(player, "Contacts", function(d)
		for _, c in ipairs(d.Phone.Contacts) do
			if c.UserId == userId then
				return false, "Kontakt existiert bereits"
			end
		end
		if #d.Phone.Contacts >= MAX_CONTACTS then
			return false, "Maximal " .. MAX_CONTACTS .. " Kontakte"
		end
		table.insert(d.Phone.Contacts, { UserId = userId, Name = name, Added = os.time() })
	end)
	return ok, ok and (name .. " gespeichert") or err
end

function PhoneService.RemoveContact(player, userId)
	if typeof(userId) ~= "number" then
		return false, "Ungueltig"
	end
	return S.DataService.Mutate(player, "Contacts", function(d)
		for i, c in ipairs(d.Phone.Contacts) do
			if c.UserId == userId then
				table.remove(d.Phone.Contacts, i)
				return
			end
		end
		return false, "Kontakt nicht gefunden"
	end)
end

-- Server-App: aktive Spieler (nur oeffentliche Angaben)
function PhoneService.Server(player)
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local d = S.DataService.Get(p)
		if d then
			local f = Factions[d.Job.Faction] or Factions.Civilian
			table.insert(list, {
				UserId = p.UserId, Name = rpName(d, p), Username = p.Name, Faction = f.Name, FactionId = d.Job.Faction,
				Rank = (f.Ranks[d.Job.Rank] or f.Ranks[1]).Name, OnDuty = d.Job.OnDuty, Self = p == player,
				Since = d.Meta.LastJoin,
			})
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	local d = S.DataService.Get(player)
	return true, nil, {
		Players = list, MaxPlayers = Players.MaxPlayers, ServerAge = math.floor(workspace.DistributedGameTime),
		Me = d and {
			Name = rpName(d, player), BirthYear = d.Character.BirthYear, Gender = d.Character.Gender,
			Faction = (Factions[d.Job.Faction] or Factions.Civilian).Name, PlayTime = d.Stats.PlayTime, Joins = d.Stats.Joins,
			FirstJoin = d.Meta.FirstJoin, License = d.Record.LicenseSuspended and "Entzogen" or "Gueltig", Points = d.Record.LicensePoints,
			Vehicles = #d.Vehicles.Owned,
		},
	}
end

function PhoneService.Start() end

return PhoneService
