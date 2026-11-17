-- RescueService: Dienst fuer Feuerwehr (Fire) und Rettungsdienst (EMS).
-- Uniform, Rufzeichen/Dienstnummer, Einheitenstatus, Ausruestung (Werkzeuge + Inventar), Garage, Dashboard.
-- Dienstantritt selbst laeuft ueber JobService.SetDuty (Ort: Factions[..].DutyLocation).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TextService = game:GetService("TextService")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local Factions = require(Shared.Config.Factions)
local Rescue = require(Shared.Config.Rescue)

local RescueService = {}
local S

RescueService.Factions = { "Fire", "EMS" }

local ALL_PERMS = {
	Fire = { "Fire.Radio", "Fire.Extinguish", "Fire.Equipment", "Fire.Rescue", "EMS.Examine", "EMS.Stabilize", "Fire.IncidentCommand", "Dispatch.Assign", "Radio.Command", "Fire.Supervisor", "Faction.ManageRanks", "Faction.Hire", "Faction.Fire" },
	EMS = { "EMS.Radio", "EMS.Examine", "EMS.Stabilize", "EMS.Transport", "EMS.Revive", "EMS.Treat", "EMS.Medication", "EMS.Supervisor", "Dispatch.Assign", "Radio.Command", "Faction.ManageRanks", "Faction.Hire", "Faction.Fire" },
}

function RescueService.Init(services)
	S = services
end

local function cfgOf(faction)
	return Rescue[faction]
end

-- Mitglied (optional im Dienst) einer Rettungsfraktion; liefert Fraktions-Id
function RescueService.Member(player, requireDuty)
	if typeof(player) ~= "Instance" then
		return nil
	end
	local d = S.DataService.Get(player)
	if not d or not cfgOf(d.Job.Faction) then
		return nil
	end
	if requireDuty and not d.Job.OnDuty then
		return nil
	end
	return d.Job.Faction
end

function RescueService.IsResponder(player, faction, perm)
	if not S.JobService.IsInFaction(player, faction, true) then
		return false
	end
	return perm == nil or S.JobService.HasPermission(player, perm)
end

-- Dienstnummer / Rufzeichen -----------------------------------------------------------------------
local function defaultCallsign(faction, rank, badge)
	local unit = cfgOf(faction).CallsignUnits[rank] or faction:upper()
	return string.format("%s-%02d", unit, badge % 100)
end

local function ensureIdentity(player)
	local d = S.DataService.Get(player)
	local f = d and d.Job.Faction
	if not cfgOf(f) then
		return
	end
	local fd = d.FactionData[f]
	if fd.Badge == 0 or fd.Callsign == "" then
		S.DataService.Mutate(player, f .. "Identity", function(data)
			local x = data.FactionData[f]
			if x.Badge == 0 then
				x.Badge = 2000 + (math.abs(player.UserId) % 7000)
			end
			if x.Callsign == "" then
				x.Callsign = defaultCallsign(f, data.Job.Rank, x.Badge)
			end
		end)
	end
	d = S.DataService.Get(player)
	player:SetAttribute("Callsign", d.FactionData[f].Callsign)
	player:SetAttribute("Badge", d.FactionData[f].Badge)
end

function RescueService.SetCallsign(player, text)
	local f = RescueService.Member(player, true)
	if not f then
		return false, "Nur im Dienst (Feuerwehr/EMS)"
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
		d.FactionData[f].Callsign = text
	end)
	player:SetAttribute("Callsign", text)
	return true, "Rufzeichen: " .. text
end

-- Werkzeuge (Feuerloescher, Strahlrohr) ------------------------------------------------------------
local function makeTool(kind)
	local def = Rescue.Fires.Tools[kind]
	local tool = Instance.new("Tool")
	tool.Name = "MSFD_" .. kind
	tool.ToolTip = def.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("FireTool", kind)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.CanCollide = false
	handle.Massless = true
	if kind == "Extinguisher" then
		handle.Size = Vector3.new(0.7, 1.8, 0.7)
		handle.Color = Color3.fromRGB(210, 30, 30)
		handle.Material = Enum.Material.SmoothPlastic
		tool.GripPos = Vector3.new(0, -0.2, 0)
	else
		handle.Size = Vector3.new(0.45, 0.45, 2.4)
		handle.Color = Color3.fromRGB(60, 60, 64)
		handle.Material = Enum.Material.Metal
		tool.GripForward = Vector3.new(0, 0, -1)
		tool.GripPos = Vector3.new(0, 0, 0.5)
	end
	handle.Parent = tool
	local nozzle = Instance.new("Attachment")
	nozzle.Name = "Nozzle"
	nozzle.Position = (kind == "Extinguisher") and Vector3.new(0, 0.9, -0.4) or Vector3.new(0, 0, -1.25)
	nozzle.Parent = handle
	return tool
end

local function giveTools(player, faction)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	for _, kind in ipairs(cfgOf(faction).Tools) do
		local name = "MSFD_" .. kind
		local has = backpack:FindFirstChild(name) or (player.Character and player.Character:FindFirstChild(name))
		if not has then
			makeTool(kind).Parent = backpack
		end
	end
end

local function removeTools(player)
	for _, holder in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if holder then
			for _, t in ipairs(holder:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("FireTool") then
					t:Destroy()
				end
			end
		end
	end
end

-- Ausruestung im Inventar (EMS): auffuellen bei Dienstantritt, einziehen bei Dienstende
local function giveSupplies(player, faction)
	for id, n in pairs(cfgOf(faction).Supplies or {}) do
		local have = S.InventoryService.Count(player, id)
		if have < n then
			S.InventoryService.Add(player, id, n - have, "Dienstausruestung")
		end
	end
end
local function takeSupplies(player, faction)
	local d = S.DataService.Get(player)
	local issued = player:GetAttribute("IssuedSupplies")
	if not issued then
		return
	end
	for id in pairs(cfgOf(faction).Supplies or {}) do
		local n = S.InventoryService.Count(player, id)
		if n > 0 then
			S.InventoryService.Remove(player, id, n, "Dienstende")
		end
	end
	player:SetAttribute("IssuedSupplies", nil)
	local _ = d
end

-- Dienstwechsel ------------------------------------------------------------------------------------
local lastFaction = {} -- [Player] = Fraktion beim letzten Dienstantritt

local function onDutyChanged(player)
	local d = S.DataService.Get(player)
	if not d then
		return
	end
	local f = d.Job.Faction
	local onDuty = cfgOf(f) ~= nil and d.Job.OnDuty
	if onDuty then
		lastFaction[player] = f
		ensureIdentity(player)
		player:SetAttribute("UnitStatus", "10-8")
		S.UniformService.Apply(player, cfgOf(f).Uniform)
		giveTools(player, f)
		if cfgOf(f).Supplies then
			giveSupplies(player, f)
			player:SetAttribute("IssuedSupplies", true)
		end
		S.RadioService.Join(player, cfgOf(f).Radio)
		S.Log("Duty", player, nil, f .. ": Dienst angetreten")
	else
		local prev = lastFaction[player]
		if not prev then
			return
		end
		lastFaction[player] = nil
		S.Log("Duty", player, nil, prev .. ": Dienst beendet")
		player:SetAttribute("UnitStatus", nil)
		S.UniformService.Remove(player, cfgOf(prev).Uniform.Prefix)
		removeTools(player)
		takeSupplies(player, prev)
		S.VehicleService.Despawn(S.VehicleService.GetOwned(player, "Service"))
		if S.MedicalService then
			S.MedicalService.ReleaseAllBy(player)
		end
	end
end

-- Garage -------------------------------------------------------------------------------------------
function RescueService.GarageList(player)
	local f = RescueService.Member(player, true)
	if not f then
		return false, "Nur im Dienst (Feuerwehr/EMS)"
	end
	local _, rank = S.JobService.Get(player)
	local list = {}
	for _, v in ipairs(cfgOf(f).Vehicles) do
		table.insert(list, { Id = v.Id, Name = v.Name, Desc = v.Desc, MinRank = v.MinRank, MinRankName = Factions[f].Ranks[v.MinRank].Name, Allowed = rank >= v.MinRank })
	end
	return true, nil, { Faction = f, Vehicles = list }
end

function RescueService.GarageSpawn(player, id)
	local f = RescueService.Member(player, true)
	if not f then
		return false, "Nur im Dienst (Feuerwehr/EMS)"
	end
	local cfg = cfgOf(f)
	if not S.InteractionService.NearestOfType(player, cfg.GarageTerminal, 25) then
		return false, "Nur am Garagen-Terminal der Wache"
	end
	local def
	for _, v in ipairs(cfg.Vehicles) do
		if v.Id == id then
			def = v
		end
	end
	if not def then
		return false, "Unbekanntes Fahrzeug"
	end
	local _, rank = S.JobService.Get(player)
	if rank < def.MinRank then
		return false, def.Name .. " erst ab " .. Factions[f].Ranks[def.MinRank].Name
	end
	local spot
	for _, m in ipairs(CollectionService:GetTagged(cfg.GarageSpawnTag)) do
		local free = true
		for _, v in ipairs(S.VehicleService.All()) do
			local ch = v:FindFirstChild("Chassis")
			if ch and (ch.Position - m.Position).Magnitude < 14 then
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
	local model, err = S.VehicleService.Spawn(player, def.Id, spot.CFrame, "Service", f)
	if not model then
		return false, err
	end
	S.Log("Garage", player, nil, "Ausgeparkt: " .. def.Name .. " " .. model:GetAttribute("Plate"))
	return true, def.Name .. " ausgeparkt (" .. model:GetAttribute("Plate") .. ")"
end

function RescueService.GaragePark(player)
	local f = RescueService.Member(player, true)
	if not f then
		return false, "Nur im Dienst (Feuerwehr/EMS)"
	end
	local m = S.VehicleService.GetOwned(player, "Service")
	if not m then
		return false, "Du hast kein Dienstfahrzeug draussen"
	end
	local ch = m:FindFirstChild("Chassis")
	for _, park in ipairs(CollectionService:GetTagged(cfgOf(f).GarageParkTag)) do
		if ch and (ch.Position - park.Position).Magnitude <= 80 then
			S.VehicleService.Despawn(m)
			S.Log("Garage", player, nil, "Eingeparkt")
			return true, "Fahrzeug eingeparkt"
		end
	end
	return false, "Fahrzeug muss an der Wache stehen"
end

-- Dashboard ----------------------------------------------------------------------------------------
function RescueService.Roster(faction)
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local d = S.DataService.Get(p)
		if d and d.Job.Faction == faction then
			table.insert(list, {
				UserId = p.UserId, Name = d.Character.FirstName .. " " .. d.Character.LastName, Rank = d.Job.Rank,
				RankName = Factions[faction].Ranks[d.Job.Rank].Name, Callsign = d.FactionData[faction].Callsign,
				OnDuty = d.Job.OnDuty, Status = p:GetAttribute("UnitStatus") or "10-7",
			})
		end
	end
	table.sort(list, function(a, b)
		return a.Rank > b.Rank
	end)
	return list
end

function RescueService.Dashboard(player)
	local f = RescueService.Member(player, false)
	if not f then
		return false, "Nur fuer Feuerwehr und Rettungsdienst"
	end
	ensureIdentity(player)
	local d = S.DataService.Get(player)
	local fd = d.FactionData[f]
	local perms = {}
	for _, p in ipairs(ALL_PERMS[f]) do
		if S.JobService.HasPermission(player, p) then
			table.insert(perms, p)
		end
	end
	local since = player:GetAttribute("DutySince")
	return true, nil, {
		Faction = f, FactionName = Factions[f].Name, OnDuty = d.Job.OnDuty, Rank = d.Job.Rank, RankName = Factions[f].Ranks[d.Job.Rank].Name,
		Callsign = fd.Callsign, Badge = fd.Badge, Status = player:GetAttribute("UnitStatus") or "10-7",
		DutySeconds = fd.DutySeconds + (since and (os.time() - since) or 0), CurrentShift = since and (os.time() - since) or 0,
		StatA = (f == "Fire") and fd.Incidents or fd.Patients, StatB = (f == "Fire") and fd.Extinguished or fd.Revives,
		StatALabel = (f == "Fire") and "Einsaetze" or "Patienten", StatBLabel = (f == "Fire") and "Geloeschte Brandherde" or "Wiederbelebungen",
		Permissions = perms, Roster = RescueService.Roster(f),
		CanManage = S.JobService.HasPermission(player, "Faction.ManageRanks") or S.JobService.IsAdmin(player),
		CanHire = S.JobService.HasPermission(player, "Faction.Hire") or S.JobService.IsAdmin(player),
		CanFire = S.JobService.HasPermission(player, "Faction.Fire") or S.JobService.IsAdmin(player),
		AtStation = S.InteractionService.NearestOfType(player, cfgOf(f).DutyTerminal, 20) ~= nil,
		Ranks = Factions[f].Ranks,
	}
end

-- Statistik fortschreiben (FireService/MedicalService)
function RescueService.AddStat(player, faction, key, n)
	S.DataService.Mutate(player, "RescueStat", function(d)
		local fd = d.FactionData[faction]
		if fd and fd[key] then
			fd[key] += n or 1
		end
	end)
end

function RescueService.Start()
	S.DataService.Changed:Connect(function(player, _, reason)
		if reason == "Duty" or reason == "SetJob" or reason == "Resign" or reason == "Dismiss" then
			if typeof(player) == "Instance" then
				task.spawn(onDutyChanged, player)
			end
		end
	end)
	S.DataService.ProfileLoaded:Connect(function(player)
		ensureIdentity(player)
	end)
	local function hook(player)
		player.CharacterAdded:Connect(function()
			task.wait(1.2)
			local f = RescueService.Member(player, true)
			if f then
				S.UniformService.Forget(player)
				S.UniformService.Apply(player, cfgOf(f).Uniform)
				giveTools(player, f)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastFaction[player] = nil
	end)
end

return RescueService
