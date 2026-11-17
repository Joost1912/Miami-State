-- DispatchService: Notrufe (911), Einsaetze, Einheitenzuweisung, Lagebild fuer Leitstelle/MDT-Karte.
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local PoliceCfg = require(Shared.Config.Police)
local MapData = require(Shared.Config.MapData)
local Rescue = require(Shared.Config.Rescue)

local DispatchService = {}
local S
local calls = {} -- [id] = call
local nextId = 1000
local last911 = {}
local CALL_COOLDOWN = 45
local EXPIRE = 45 * 60

function DispatchService.Init(services)
	S = services
end

local function category(id)
	for _, list in ipairs({ PoliceCfg.CallCategories, Rescue.CallCategories }) do
		for _, c in ipairs(list) do
			if c.Id == id then
				return c
			end
		end
	end
	return nil
end
DispatchService.Category = category

local SUPERVISOR = { "Police.Supervisor", "Fire.Supervisor", "EMS.Supervisor" }
local function isSupervisor(player)
	for _, p in ipairs(SUPERVISOR) do
		if S.JobService.HasPermission(player, p) then
			return true
		end
	end
	return false
end

local function responderFaction(player)
	local d = S.DataService.Get(player)
	return d and d.Job.OnDuty and d.Job.Faction ~= "Civilian" and d.Job.Faction or nil
end

local function visibleTo(call, player)
	local f = responderFaction(player)
	return f ~= nil and table.find(call.Services, f) ~= nil
end

local function public(call)
	local units = {}
	for _, uid in ipairs(call.Units) do
		local p = Players:GetPlayerByUserId(uid)
		table.insert(units, p and (p:GetAttribute("Callsign") or p.Name) or "?")
	end
	return {
		Id = call.Id, Category = call.Category, Name = call.Name, Priority = call.Priority, Desc = call.Desc,
		X = call.X, Y = call.Y, Z = call.Z, District = call.District, Caller = call.Caller, T = call.T,
		Status = call.Status, Units = units, UnitIds = call.Units, Services = call.Services,
	}
end
DispatchService.Public = public

local function notify(call, kind)
	for _, p in ipairs(Players:GetPlayers()) do
		if visibleTo(call, p) then
			S.Push(p, kind or "CallUpdate", public(call))
		end
	end
end

local function create(catId, name, pos, desc, priority, services, caller, callerId)
	services = table.clone(services) -- eigene Kopie: Weitergabe darf die Konfiguration nicht veraendern
	nextId += 1
	local call = {
		Id = nextId, Category = catId, Name = name, Priority = priority, Desc = desc,
		X = math.floor(pos.X), Y = math.floor(pos.Y), Z = math.floor(pos.Z), District = MapData.DistrictAt(pos.X, pos.Z),
		Caller = caller, CallerId = callerId, T = os.time(), Status = "Neu", Units = {}, Services = services,
	}
	calls[call.Id] = call
	notify(call, "CallNew")
	S.RadioService.Broadcast("DISP", string.format("Neuer Einsatz #%d %s - %s - %s [%s]", call.Id, PoliceCfg.PriorityNames[priority], name, call.District, table.concat(services, "/")))
	return call
end

function DispatchService.CreateSystemCall(catId, pos, desc, priority, services, name)
	local cat = category(catId)
	return create(catId, name or (catId == "Panic" and "10-99 Officer Needs Assistance") or (cat and cat.Name) or catId, pos, desc, priority or (cat and cat.Priority) or 2, services or (cat and cat.Services) or { "Police" }, "System", 0)
end

-- Einsatz ohne Spieler abschliessen (z.B. Brand geloescht, Patient versorgt)
function DispatchService.CloseSystem(id, text)
	local c = typeof(id) == "number" and calls[id]
	if not c or c.Status == "Abgeschlossen" then
		return
	end
	c.Status = "Abgeschlossen"
	for _, uid in ipairs(c.Units) do
		local p = Players:GetPlayerByUserId(uid)
		if p then
			p:SetAttribute("UnitStatus", "10-8")
			S.Push(p, "WaypointClear", { CallId = c.Id })
		end
	end
	notify(c)
	S.RadioService.Broadcast("DISP", string.format("Einsatz #%d abgeschlossen%s", c.Id, text and (" - " .. text) or " (Code 4)"))
end

function DispatchService.Get(id)
	return typeof(id) == "number" and calls[id] or nil
end

-- Einsatz an weitere Dienste weitergeben (z.B. Unfall: Polizei -> Rettungsdienst)
function DispatchService.Forward(player, id, service)
	local c = typeof(id) == "number" and calls[id]
	if not c or c.Status == "Abgeschlossen" or not visibleTo(c, player) then
		return false, "Einsatz nicht verfuegbar"
	end
	if service ~= "Police" and service ~= "Fire" and service ~= "EMS" then
		return false, "Unbekannter Dienst"
	end
	if table.find(c.Services, service) then
		return false, "Dienst ist bereits alarmiert"
	end
	table.insert(c.Services, service)
	for _, p in ipairs(Players:GetPlayers()) do
		if responderFaction(p) == service then
			S.Push(p, "CallNew", public(c))
		end
	end
	notify(c)
	local names = { Police = "Polizei", Fire = "Feuerwehr", EMS = "Rettungsdienst" }
	S.RadioService.Broadcast("DISP", string.format("Einsatz #%d: %s nachalarmiert durch %s", c.Id, names[service], player:GetAttribute("Callsign") or player.Name))
	S.Log("Dispatch", player, nil, "Weitergabe #" .. c.Id .. " an " .. service)
	return true, names[service] .. " alarmiert"
end

-- Notruf eines Spielers
function DispatchService.Call911(player, p)
	if typeof(p) ~= "table" then
		return false, "Ungueltig"
	end
	local cat = category(p.Category)
	if not cat then
		return false, "Bitte Kategorie waehlen"
	end
	if last911[player] and os.clock() - last911[player] < CALL_COOLDOWN then
		return false, string.format("Bitte warte %d s bis zum naechsten Notruf", math.ceil(CALL_COOLDOWN - (os.clock() - last911[player])))
	end
	local text = p.Description
	if typeof(text) ~= "string" or #text < 3 or #text > 140 then
		return false, "Beschreibung: 3-140 Zeichen"
	end
	local ok, filtered = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return false, "Leitung gestoert - bitte erneut versuchen"
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "Nicht moeglich"
	end
	last911[player] = os.clock()
	local d = S.DataService.Get(player)
	local call = create(cat.Id, cat.Name, root.Position, filtered, cat.Priority, cat.Services, d.Character.FirstName .. " " .. d.Character.LastName, player.UserId)
	S.Log("911", player, nil, string.format("#%d %s: %s", call.Id, cat.Name, filtered))
	return true, string.format("Notruf #%d gesendet - Hilfe ist unterwegs", call.Id)
end

function DispatchService.List(player)
	local list = {}
	for _, c in pairs(calls) do
		if c.Status ~= "Abgeschlossen" and visibleTo(c, player) then
			table.insert(list, public(c))
		end
	end
	table.sort(list, function(a, b)
		if a.Priority ~= b.Priority then
			return a.Priority < b.Priority
		end
		return a.T > b.T
	end)
	return list
end

-- Lagebild: Einheiten im Dienst (fuer Karte)
function DispatchService.Units(player)
	if not responderFaction(player) then
		return {}
	end
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local f = responderFaction(p)
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if f and root then
			table.insert(list, { Callsign = p:GetAttribute("Callsign") or p.Name, Faction = f, Status = p:GetAttribute("UnitStatus") or "10-8", X = math.floor(root.Position.X), Z = math.floor(root.Position.Z), UserId = p.UserId })
		end
	end
	return list
end

local function getCall(id)
	local c = typeof(id) == "number" and calls[id]
	if not c or c.Status == "Abgeschlossen" then
		return nil
	end
	return c
end

function DispatchService.Attach(player, id, byActor)
	local c = getCall(id)
	if not c or not visibleTo(c, player) then
		return false, "Einsatz nicht verfuegbar"
	end
	if not table.find(c.Units, player.UserId) then
		table.insert(c.Units, player.UserId)
	end
	if c.Status == "Neu" then
		c.Status = "Zugewiesen"
	end
	player:SetAttribute("UnitStatus", "10-76")
	S.Push(player, "Waypoint", { X = c.X, Y = c.Y, Z = c.Z, Label = string.format("#%d %s", c.Id, c.Name), CallId = c.Id })
	notify(c)
	S.RadioService.Broadcast("DISP", string.format("%s uebernimmt Einsatz #%d (10-76)%s", player:GetAttribute("Callsign") or player.Name, c.Id, byActor and (" - zugewiesen von " .. (byActor:GetAttribute("Callsign") or byActor.Name)) or ""))
	return true, "Einsatz #" .. c.Id .. " uebernommen - Wegpunkt gesetzt"
end

function DispatchService.Assign(actor, id, targetUserId)
	if not S.JobService.HasPermission(actor, "Dispatch.Assign") then
		return false, "Keine Berechtigung (Dispatch.Assign)"
	end
	local target = typeof(targetUserId) == "number" and Players:GetPlayerByUserId(targetUserId)
	if not target then
		return false, "Einheit nicht gefunden"
	end
	local ok, msg = DispatchService.Attach(target, id, actor)
	if ok then
		S.Push(target, "Notify", { Text = "Dir wurde Einsatz #" .. id .. " zugewiesen", Kind = "warning" })
		S.Log("Dispatch", actor, target, "Zuweisung #" .. tostring(id))
	end
	return ok, ok and "Einheit zugewiesen" or msg
end

function DispatchService.OnScene(player, id)
	local c = getCall(id)
	if not c or not table.find(c.Units, player.UserId) then
		return false, "Du bist diesem Einsatz nicht zugewiesen"
	end
	c.Status = "Vor Ort"
	player:SetAttribute("UnitStatus", "10-97")
	notify(c)
	S.RadioService.Broadcast("DISP", string.format("%s vor Ort bei #%d (10-97)", player:GetAttribute("Callsign") or player.Name, c.Id))
	return true, "Status: vor Ort"
end

function DispatchService.Close(player, id)
	local c = getCall(id)
	if not c then
		return false, "Einsatz nicht verfuegbar"
	end
	if not table.find(c.Units, player.UserId) and not isSupervisor(player) then
		return false, "Nur zugewiesene Einheiten oder Vorgesetzte"
	end
	c.Status = "Abgeschlossen"
	for _, uid in ipairs(c.Units) do
		local p = Players:GetPlayerByUserId(uid)
		if p then
			p:SetAttribute("UnitStatus", "10-8")
			S.Push(p, "WaypointClear", { CallId = c.Id })
		end
	end
	notify(c)
	S.RadioService.Broadcast("DISP", string.format("Einsatz #%d abgeschlossen (Code 4)", c.Id))
	S.Log("Dispatch", player, nil, "Abschluss #" .. c.Id)
	return true, "Einsatz abgeschlossen"
end

function DispatchService.Start()
	Players.PlayerRemoving:Connect(function(p)
		last911[p] = nil
		for _, c in pairs(calls) do
			local i = table.find(c.Units, p.UserId)
			if i then
				table.remove(c.Units, i)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for id, c in pairs(calls) do
				if os.time() - c.T > EXPIRE then
					calls[id] = nil
				end
			end
		end
	end)
end

return DispatchService
