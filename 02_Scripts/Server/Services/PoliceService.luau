-- PoliceService: Dienst, Uniform, Ausruestung, Dienstnummer/Rufzeichen, Einheitenstatus, Garage, Dashboard.
-- Alle Entscheidungen serverseitig (JobService.HasPermission / IsInFaction).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local CollectionService = game:GetService("CollectionService")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local Factions = require(Shared.Config.Factions)
local PoliceCfg = require(Shared.Config.Police)

local PoliceService = {}
local S

local NAVY = Color3.fromRGB(24, 36, 70)
local NAVY_DARK = Color3.fromRGB(16, 22, 42)
local GOLD = Color3.fromRGB(214, 172, 74)

local ALL_PERMS = {
	"Police.Radio", "Police.MDT", "Police.Cuff", "Police.Search", "Police.Escort", "Police.Cite", "Police.Arrest",
	"Police.Jail", "Police.Wanted", "Police.TrafficStop", "Police.Confiscate", "Police.Warrant", "Police.Supervisor",
	"Dispatch.Assign", "Radio.Command", "Faction.ManageRanks", "Faction.Hire", "Faction.Fire",
}
PoliceService.AllPermissions = ALL_PERMS

function PoliceService.Init(services)
	S = services
end

function PoliceService.IsOfficer(player, perm)
	if typeof(player) ~= "Instance" then
		return false
	end
	if not S.JobService.IsInFaction(player, "Police", true) then
		return false
	end
	return perm == nil or S.JobService.HasPermission(player, perm)
end

local function rpName(player)
	local d = S.DataService.Get(player)
	return d and (d.Character.FirstName .. " " .. d.Character.LastName) or player.Name
end
PoliceService.RpName = rpName

-- Dienstnummer / Rufzeichen ----------------------------------------------------------------------
local function defaultCallsign(rank, badge)
	local unit = (rank <= 2 and "ADAM") or (rank <= 4 and "LINCOLN") or (rank == 5 and "SAM") or "CMD"
	return string.format("1-%s-%02d", unit, badge % 100)
end

local function ensureIdentity(player)
	local d = S.DataService.Get(player)
	if not d or d.Job.Faction ~= "Police" then
		return
	end
	local pd = d.FactionData.Police
	if pd.Badge == 0 or pd.Callsign == "" then
		S.DataService.Mutate(player, "PoliceIdentity", function(data)
			local p = data.FactionData.Police
			if p.Badge == 0 then
				p.Badge = 1000 + (math.abs(player.UserId) % 9000)
			end
			if p.Callsign == "" then
				p.Callsign = defaultCallsign(data.Job.Rank, p.Badge)
			end
		end)
	end
	d = S.DataService.Get(player)
	player:SetAttribute("Callsign", d.FactionData.Police.Callsign)
	player:SetAttribute("Badge", d.FactionData.Police.Badge)
end

function PoliceService.SetCallsign(player, text)
	if not PoliceService.IsOfficer(player) then
		return false, "Nur im Polizeidienst"
	end
	if typeof(text) ~= "string" then
		return false, "Ungueltig"
	end
	text = text:upper():gsub("%s", "")
	if #text < 2 or #text > 14 or not text:match("^[%w%-]+$") then
		return false, "Rufzeichen: 2-14 Zeichen, A-Z, 0-9 und -"
	end
	local ok, res = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	if not ok or res ~= text then
		return false, "Rufzeichen nicht erlaubt"
	end
	S.DataService.Mutate(player, "Callsign", function(d)
		d.FactionData.Police.Callsign = text
	end)
	player:SetAttribute("Callsign", text)
	return true, "Rufzeichen: " .. text
end

-- Einheitenstatus (10-8, 10-6, 10-76, 10-97, 10-7)
function PoliceService.SetStatus(player, status)
	if not S.JobService.Get(player) or S.JobService.Get(player) == "Civilian" then
		return false, "Nicht moeglich"
	end
	local valid = false
	for _, s in ipairs(PoliceCfg.Statuses) do
		if s.Id == status then
			valid = true
		end
	end
	if not valid then
		return false, "Unbekannter Status"
	end
	player:SetAttribute("UnitStatus", status)
	return true, "Status " .. status
end

-- Uniform (gemeinsamer UniformService) ---------------------------------------------------------
local POLICE_UNIFORM = {
	Prefix = "PD_",
	Torso = NAVY, Legs = NAVY_DARK,
	Parts = {
		{ "Cap", "HatAttachment", Vector3.new(1.3, 0.45, 1.4), NAVY_DARK, "Fabric", CFrame.new(0, -0.15, 0) },
		{ "CapBadge", "HatAttachment", Vector3.new(0.35, 0.35, 0.08), GOLD, "Foil", CFrame.new(0, -0.2, 0.72) },
		{ "Badge", "BodyFrontAttachment", Vector3.new(0.4, 0.45, 0.08), GOLD, "Foil", CFrame.new(-0.35, -0.35, 0.05) },
		{ "Belt", "WaistCenterAttachment", Vector3.new(2.15, 0.35, 1.15), Color3.fromRGB(20, 20, 22), "Leather" },
		{ "Radio", "LeftCollarAttachment", Vector3.new(0.3, 0.5, 0.2), Color3.fromRGB(30, 30, 32), "Plastic", CFrame.new(0, -0.2, 0.25) },
	},
}
local function applyUniform(player)
	S.UniformService.Apply(player, POLICE_UNIFORM)
end
local function removeUniform(player)
	S.UniformService.Remove(player, "PD_")
end

-- Dienstwechsel ----------------------------------------------------------------------------------
local policeDuty = {} -- [Player] = true waehrend eines Polizeidienstes (andere Fraktionen nicht beruehren)
local function onDutyChanged(player)
	local d = S.DataService.Get(player)
	if not d then
		return
	end
	local onDuty = d.Job.Faction == "Police" and d.Job.OnDuty
	if not onDuty and not policeDuty[player] then
		return -- kein Polizeidienst beendet (z.B. Feuerwehr/EMS-Dienstwechsel)
	end
	if onDuty then
		policeDuty[player] = true
		ensureIdentity(player)
		player:SetAttribute("UnitStatus", "10-8")
		if S.InventoryService.Count(player, "Handcuffs") == 0 then
			S.InventoryService.Add(player, "Handcuffs", 1, "Dienstausruestung")
		end
		applyUniform(player)
		S.RadioService.Join(player, "PD1")
		S.Log("Duty", player, nil, "Dienst angetreten")
	else
		policeDuty[player] = nil
		S.Log("Duty", player, nil, "Dienst beendet")
		player:SetAttribute("UnitStatus", nil)
		local n = S.InventoryService.Count(player, "Handcuffs")
		if n > 0 then
			S.InventoryService.Remove(player, "Handcuffs", n, "Dienstende")
		end
		removeUniform(player)
		S.VehicleService.Despawn(S.VehicleService.GetOwned(player, "Police"))
		if S.JusticeService then
			S.JusticeService.ReleaseAllBy(player)
		end
	end
end

-- Garage --------------------------------------------------------------------------------------------
function PoliceService.GarageList(player)
	local _, rank = S.JobService.Get(player)
	local list = {}
	for _, v in ipairs(PoliceCfg.Vehicles) do
		table.insert(list, { Id = v.Id, Name = v.Name, Desc = v.Desc, MinRank = v.MinRank, MinRankName = Factions.Police.Ranks[v.MinRank].Name, Allowed = (rank or 0) >= v.MinRank })
	end
	return list
end

function PoliceService.GarageSpawn(player, id)
	if not PoliceService.IsOfficer(player) then
		return false, "Nur im Polizeidienst"
	end
	if not S.InteractionService.NearestOfType(player, "PoliceGarage", 25) then
		return false, "Nur am Garagen-Terminal"
	end
	local def
	for _, v in ipairs(PoliceCfg.Vehicles) do
		if v.Id == id then
			def = v
		end
	end
	if not def then
		return false, "Unbekanntes Fahrzeug"
	end
	local _, rank = S.JobService.Get(player)
	if rank < def.MinRank then
		return false, def.Name .. " erst ab " .. Factions.Police.Ranks[def.MinRank].Name
	end
	-- freien Stellplatz suchen
	local spot
	for _, m in ipairs(CollectionService:GetTagged("PoliceGarageSpawn")) do
		local free = true
		for _, v in ipairs(S.VehicleService.All()) do
			local ch = v:FindFirstChild("Chassis")
			if ch and (ch.Position - m.Position).Magnitude < 12 then
				free = false
			end
		end
		if free then
			spot = m
			break
		end
	end
	if not spot then
		return false, "Alle Stellplaetze belegt"
	end
	local model, err = S.VehicleService.Spawn(player, def.Id, spot.CFrame, "Police", "Police")
	if not model then
		return false, err
	end
	S.Log("Garage", player, nil, "Ausgeparkt: " .. def.Name .. " " .. model:GetAttribute("Plate"))
	return true, def.Name .. " ausgeparkt (" .. model:GetAttribute("Plate") .. ")"
end

function PoliceService.GaragePark(player)
	local m = S.VehicleService.GetOwned(player, "Police")
	if not m then
		return false, "Du hast kein Dienstfahrzeug draussen"
	end
	local park = CollectionService:GetTagged("PoliceGaragePark")[1]
	local ch = m:FindFirstChild("Chassis")
	if not park or not ch or (ch.Position - park.Position).Magnitude > 70 then
		return false, "Fahrzeug muss in der Polizeigarage stehen"
	end
	S.VehicleService.Despawn(m)
	S.Log("Garage", player, nil, "Eingeparkt")
	return true, "Fahrzeug eingeparkt"
end

-- Dashboard ------------------------------------------------------------------------------------------
function PoliceService.Roster()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local d = S.DataService.Get(p)
		if d and d.Job.Faction == "Police" then
			table.insert(list, {
				UserId = p.UserId, Name = rpName(p), Rank = d.Job.Rank, RankName = Factions.Police.Ranks[d.Job.Rank].Name,
				Callsign = d.FactionData.Police.Callsign, OnDuty = d.Job.OnDuty, Status = p:GetAttribute("UnitStatus") or "10-7",
			})
		end
	end
	table.sort(list, function(a, b)
		return a.Rank > b.Rank
	end)
	return list
end

function PoliceService.Dashboard(player)
	local d = S.DataService.Get(player)
	if not d or d.Job.Faction ~= "Police" then
		return false, "Nur fuer Mitglieder der Miami State Police"
	end
	ensureIdentity(player)
	d = S.DataService.Get(player)
	local perms = {}
	for _, p in ipairs(ALL_PERMS) do
		if S.JobService.HasPermission(player, p) then
			table.insert(perms, p)
		end
	end
	local since = player:GetAttribute("DutySince")
	return true, nil, {
		OnDuty = d.Job.OnDuty, Rank = d.Job.Rank, RankName = Factions.Police.Ranks[d.Job.Rank].Name,
		Callsign = d.FactionData.Police.Callsign, Badge = d.FactionData.Police.Badge, Status = player:GetAttribute("UnitStatus") or "10-7",
		DutySeconds = d.FactionData.Police.DutySeconds + (since and (os.time() - since) or 0), CurrentShift = since and (os.time() - since) or 0,
		Arrests = d.FactionData.Police.Arrests, Citations = d.FactionData.Police.Citations,
		Permissions = perms, Roster = PoliceService.Roster(),
		CanManage = S.JobService.HasPermission(player, "Faction.ManageRanks") or S.JobService.IsAdmin(player),
		CanHire = S.JobService.HasPermission(player, "Faction.Hire") or S.JobService.IsAdmin(player),
		CanFire = S.JobService.HasPermission(player, "Faction.Fire") or S.JobService.IsAdmin(player),
		AtStation = S.InteractionService.NearestOfType(player, "PoliceDuty", 20) ~= nil,
	}
end

function PoliceService.Start()
	S.DataService.Changed:Connect(function(player, _, reason)
		if reason == "Duty" or reason == "SetJob" or reason == "Resign" or reason == "Dismiss" then
			if typeof(player) == "Instance" then
				task.spawn(onDutyChanged, player)
			end
		end
	end)
	S.DataService.ProfileLoaded:Connect(function(player)
		local d = S.DataService.Get(player)
		-- Nach Neubeitritt ist niemand im Dienst (Dienstantritt nur an der Wache)
		if d.Job.OnDuty then
			S.DataService.Mutate(player, "Duty", function(data)
				data.Job.OnDuty = false
			end)
		end
		ensureIdentity(player)
	end)
	local function hook(player)
		player.CharacterAdded:Connect(function()
			task.wait(1.2)
			local d = S.DataService.Get(player)
			if d and d.Job.Faction == "Police" and d.Job.OnDuty then
				S.UniformService.Forget(player)
				applyUniform(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		policeDuty[p] = nil
	end)
	-- Dienstzeit vor dem finalen Speichern verbuchen
	table.insert(S.DataService.BeforeRelease, function(player)
		S.JobService.EndDuty(player)
	end)
end

return PoliceService
