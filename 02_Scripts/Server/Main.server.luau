-- MIAMI STATE Server-Einstieg.
-- Startet alle Services und stellt EINEN Anfrage-Endpunkt bereit (RemoteFunction "Request").
-- Jede Anfrage: Rate-Limit -> Profil geladen? -> Aktion bekannt? -> Typpruefung im Handler -> Ergebnis {ok,msg,data}.
-- Server -> Client: RemoteEvent "Push" (Profil-Sync, Hinweise, Menues oeffnen).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local ServicesFolder = script.Parent:WaitForChild("Services")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local EconomyConfig = require(Shared.Config.Economy)
local Factions = require(Shared.Config.Factions)

-- Remotes
local remotes = ReplicatedStorage:FindFirstChild("MiamiRemotes") or Instance.new("Folder")
remotes.Name = "MiamiRemotes"
remotes.Parent = ReplicatedStorage
local function remote(class, name)
	local r = remotes:FindFirstChild(name) or Instance.new(class)
	r.Name = name
	r.Parent = remotes
	return r
end
local Request = remote("RemoteFunction", "Request")
local PushRemote = remote("RemoteEvent", "Push")
local VehicleControl = remote("RemoteEvent", "VehicleControl")
local FireSpray = remote("RemoteEvent", "FireSpray") -- Loeschtreffer (eigener Takt, eigene Pruefung im FireService)

local function push(player, kind, data)
	if typeof(player) == "Instance" and player.Parent then
		PushRemote:FireClient(player, kind, data)
	end
end

-- Zentrales Aktionsprotokoll (Server-Log + Ringpuffer fuer Vorgesetzte)
local auditLog = {}
local function log(kind, actor, target, details)
	local entry = {
		T = os.time(), Kind = kind,
		Actor = actor and ((typeof(actor) == "Instance" and actor:GetAttribute("Callsign")) or actor.Name) or "System",
		Target = target and target.Name or "", Details = details or "",
	}
	table.insert(auditLog, 1, entry)
	if #auditLog > 300 then
		table.remove(auditLog)
	end
	print(string.format("[Audit] %s | %s -> %s | %s", entry.Kind, entry.Actor, entry.Target, entry.Details))
end

-- Services laden
local S = { Push = push, Log = log, Format = require(Shared.Format), Remotes = { Request = Request, Push = PushRemote, VehicleControl = VehicleControl, FireSpray = FireSpray } }
-- Prompt 10: DealershipService (Autohaus/Garage/Tuning), PropertyService (Apartments), ActivityService (Downtown)
for _, name in ipairs({ "DataService", "EconomyService", "InventoryService", "JobService", "PayrollService", "CharacterService", "InteractionService", "ShopService", "VehicleService", "UniformService", "PoliceService", "RescueService", "RadioService", "DispatchService", "JusticeService", "FireService", "MedicalService", "PhoneService", "WeaponService", "ClothingService", "WantedService", "CrimeService", "DealershipService", "PropertyService", "ActivityService", "WorkService", "BusinessService", "CommsService", "SocialService", "LottService", "GateService" }) do
	S[name] = require(ServicesFolder:WaitForChild(name))
end
S.DataService.SetPushRemote(PushRemote)
for _, svc in pairs(S) do
	if type(svc) == "table" and svc.Init then
		svc.Init(S)
	end
end

-- Rate-Limit: Token-Bucket je Spieler (10 Anfragen Puffer, 4 pro Sekunde)
local buckets = {}
local function allow(player)
	local b = buckets[player]
	local now = os.clock()
	if not b then
		b = { tokens = 10, t = now }
		buckets[player] = b
	end
	b.tokens = math.min(10, b.tokens + (now - b.t) * 4)
	b.t = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end
Players.PlayerRemoving:Connect(function(p)
	buckets[p] = nil
end)

local function playerByUserId(id)
	if typeof(id) ~= "number" then
		return nil
	end
	local p = Players:GetPlayerByUserId(id)
	return (p and S.DataService.Get(p)) and p or nil
end

local function distance(a, b)
	local ra = a.Character and a.Character:FindFirstChild("HumanoidRootPart")
	local rb = b.Character and b.Character:FindFirstChild("HumanoidRootPart")
	return (ra and rb) and (ra.Position - rb.Position).Magnitude or math.huge
end

local function rpName(d)
	return d.Character.FirstName .. " " .. d.Character.LastName
end

local function atATM(player)
	return S.InteractionService.NearestOfType(player, "ATM", EconomyConfig.ATMRange) ~= nil
end

local function filterNote(note, player)
	if note == nil or note == "" then
		return ""
	end
	if typeof(note) ~= "string" or #note > 40 then
		return nil
	end
	local ok, res = pcall(function()
		return TextService:FilterStringAsync(note, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	return ok and res or nil
end

-- Aktionen ---------------------------------------------------------------------------------
local A = {}
local function tbl(p)
	return typeof(p) == "table" and p or {}
end

A["Profile.Get"] = function(player)
	S.DataService.Sync(player)
	return true
end

A["Character.Create"] = function(player, p)
	return S.CharacterService.Create(player, p)
end

A["Bank.Deposit"] = function(player, p)
	if typeof(p) ~= "table" then
		return false, "Ungueltig"
	end
	if not atATM(player) then
		return false, "Kein Geldautomat in der Naehe"
	end
	local ok, err = S.EconomyService.Deposit(player, p.Amount, p.TxId)
	return ok, ok and ("$" .. p.Amount .. " eingezahlt") or err
end

A["Bank.Withdraw"] = function(player, p)
	if typeof(p) ~= "table" then
		return false, "Ungueltig"
	end
	if not atATM(player) then
		return false, "Kein Geldautomat in der Naehe"
	end
	local ok, err = S.EconomyService.Withdraw(player, p.Amount, p.TxId)
	return ok, ok and ("$" .. p.Amount .. " abgehoben") or err
end

A["Bank.Transfer"] = function(player, p)
	if typeof(p) ~= "table" then
		return false, "Ungueltig"
	end
	-- Ueberweisung: am Geldautomaten oder mobil per Banking-App (Smartphone im Inventar)
	if not atATM(player) and not (p.Mobile == true and S.InventoryService.Count(player, "Phone") > 0) then
		return false, "Kein Geldautomat in der Naehe"
	end
	local target = playerByUserId(p.Target)
	if not target then
		return false, "Empfaenger ist nicht online"
	end
	local note = filterNote(p.Note, player)
	if note == nil then
		return false, "Verwendungszweck ungueltig (max. 40 Zeichen)"
	end
	local ok, err = S.EconomyService.Transfer(player, target, "Bank", p.Amount, p.TxId, note)
	if ok then
		push(target, "Notify", { Text = string.format("Ueberweisung erhalten: $%d von %s", p.Amount, rpName(S.DataService.Get(player))), Kind = "success" })
	end
	return ok, ok and ("$" .. p.Amount .. " ueberwiesen") or err
end

A["Cash.Give"] = function(player, p)
	if typeof(p) ~= "table" then
		return false, "Ungueltig"
	end
	local target = playerByUserId(p.Target)
	if not target then
		return false, "Spieler nicht gefunden"
	end
	if distance(player, target) > EconomyConfig.GiveRange then
		return false, "Spieler ist zu weit entfernt"
	end
	local ok, err = S.EconomyService.Transfer(player, target, "Cash", p.Amount, p.TxId)
	if ok then
		push(target, "Notify", { Text = string.format("%s hat dir $%d gegeben", rpName(S.DataService.Get(player)), p.Amount), Kind = "success" })
	end
	return ok, ok and ("$" .. p.Amount .. " uebergeben") or err
end

A["Player.Inspect"] = function(player, p)
	local target = typeof(p) == "table" and (playerByUserId(p.Target) or S.JusticeService.Resolve(p.Target))
	if not target then
		return false, "Spieler nicht gefunden"
	end
	if distance(player, target) > 25 then
		return false, "Zu weit entfernt"
	end
	local d = S.DataService.Get(target)
	local f = Factions[d.Job.Faction]
	return true, nil, {
		Name = d.Character.Created and rpName(d) or target.Name,
		Faction = f.Name,
		FactionId = d.Job.Faction,
		Rank = f.Ranks[d.Job.Rank].Name,
		OnDuty = d.Job.OnDuty,
		UserId = target.UserId,
		State = S.JusticeService.TargetState(target),
		IsOfficer = S.PoliceService.IsOfficer(player),
		Injury = target:GetAttribute("Injury"), Stabilized = target:GetAttribute("Stabilized") == true,
		Carried = target:GetAttribute("Carried") == true, Loaded = target:GetAttribute("Loaded") == true,
		Responder = S.RescueService.Member(player, true),
		CanAddContact = typeof(target) == "Instance",
	}
end

-- Polizei -----------------------------------------------------------------------------------------
A["Police.Dashboard"] = function(player)
	return S.PoliceService.Dashboard(player)
end
A["Police.SetCallsign"] = function(player, p)
	return S.PoliceService.SetCallsign(player, tbl(p).Callsign)
end
A["Police.SetStatus"] = function(player, p)
	return S.PoliceService.SetStatus(player, tbl(p).Status)
end
A["Police.GarageList"] = function(player)
	if not S.PoliceService.IsOfficer(player) then
		return false, "Nur im Polizeidienst"
	end
	return true, nil, S.PoliceService.GarageList(player)
end
A["Police.GarageSpawn"] = function(player, p)
	return S.PoliceService.GarageSpawn(player, tbl(p).Id)
end
A["Police.GaragePark"] = function(player)
	return S.PoliceService.GaragePark(player)
end
A["Police.SetRank"] = function(player, p)
	local target = Players:GetPlayerByUserId(typeof(tbl(p).Target) == "number" and p.Target or 0)
	local ok, msg = S.JobService.SetJob(player, target, "Police", tbl(p).Rank)
	if ok and target ~= player then
		push(target, "Notify", { Text = "Personalaenderung: " .. tostring(msg), Kind = "info" })
	end
	return ok, msg
end
A["Police.Dismiss"] = function(player, p)
	local target = Players:GetPlayerByUserId(typeof(tbl(p).Target) == "number" and p.Target or 0)
	return S.JobService.Dismiss(player, target)
end
A["Police.Log"] = function(player)
	if not S.PoliceService.IsOfficer(player, "Police.Supervisor") then
		return false, "Keine Berechtigung (Police.Supervisor)"
	end
	local out = {}
	for i = 1, math.min(60, #auditLog) do
		out[i] = auditLog[i]
	end
	return true, nil, out
end

-- Funk
A["Radio.State"] = function(player)
	return true, nil, S.RadioService.State(player)
end
A["Radio.Join"] = function(player, p)
	return S.RadioService.Join(player, tbl(p).Channel)
end
A["Radio.Send"] = function(player, p)
	return S.RadioService.Send(player, tbl(p).Text)
end
A["Radio.Panic"] = function(player)
	return S.RadioService.Panic(player)
end

-- Leitstelle / Notruf
A["Emergency.Call"] = function(player, p)
	return S.DispatchService.Call911(player, p)
end
A["Dispatch.List"] = function(player)
	return true, nil, { Calls = S.DispatchService.List(player), Units = S.DispatchService.Units(player), CanAssign = S.JobService.HasPermission(player, "Dispatch.Assign") }
end
A["Dispatch.Attach"] = function(player, p)
	return S.DispatchService.Attach(player, tbl(p).Id)
end
A["Dispatch.Assign"] = function(player, p)
	return S.DispatchService.Assign(player, tbl(p).Id, tbl(p).Target)
end
A["Dispatch.OnScene"] = function(player, p)
	return S.DispatchService.OnScene(player, tbl(p).Id)
end
A["Dispatch.Close"] = function(player, p)
	return S.DispatchService.Close(player, tbl(p).Id)
end

-- MDT
A["MDT.Access"] = function(player)
	return true, nil, { Access = S.JusticeService.HasMDTAccess(player) }
end
A["MDT.SearchPerson"] = function(player, p)
	return S.JusticeService.SearchPerson(player, tbl(p).Query)
end
A["MDT.Person"] = function(player, p)
	return S.JusticeService.PersonDetail(player, tbl(p).UserId)
end
A["MDT.Plate"] = function(player, p)
	return S.JusticeService.PlateLookup(player, tbl(p).Plate)
end
A["MDT.SetWanted"] = function(player, p)
	return S.JusticeService.SetWanted(player, tbl(p).UserId, tbl(p).On == true, tbl(p).Reason)
end
A["MDT.Warrant"] = function(player, p)
	return S.JusticeService.IssueWarrant(player, tbl(p).UserId, tbl(p).Charges)
end

-- Einsatzmassnahmen
for action, fn in pairs({
	Cuff = "Cuff", Uncuff = "Uncuff", Search = "Search", Escort = "Escort", PutInVehicle = "PutInVehicle",
	TakeOut = "TakeOut", Release = "Release",
}) do
	A["Justice." .. action] = function(player, p)
		return S.JusticeService[fn](player, tbl(p).Target)
	end
end
A["Justice.Confiscate"] = function(player, p)
	return S.JusticeService.Confiscate(player, tbl(p).Target, tbl(p).ItemId)
end
A["Justice.Jail"] = function(player, p)
	return S.JusticeService.Jail(player, tbl(p).Target, tbl(p).Charges)
end
A["Justice.Cite"] = function(player, p)
	return S.JusticeService.Cite(player, tbl(p).Target, tbl(p).Code)
end
A["Justice.Warn"] = function(player, p)
	return S.JusticeService.Warn(player, tbl(p).Target, tbl(p).Text)
end
A["Justice.TrafficStop"] = function(player)
	return S.JusticeService.TrafficStop(player)
end

A["Inventory.Use"] = function(player, p)
	return S.InventoryService.Use(player, typeof(p) == "table" and p.ItemId)
end

A["Inventory.Drop"] = function(player, p)
	if typeof(p) ~= "table" or typeof(p.ItemId) ~= "string" then
		return false, "Ungueltig"
	end
	local ok, err = S.InventoryService.Remove(player, p.ItemId, p.Count or 1, "Drop")
	return ok, ok and "Gegenstand entfernt" or err
end

A["Job.Info"] = function(player)
	return true, nil, {
		IsAdmin = S.JobService.IsAdmin(player),
		CanManage = S.JobService.HasPermission(player, "Faction.ManageRanks"),
		Salary = S.PayrollService.SalaryFor(S.DataService.Get(player)),
		PayInterval = EconomyConfig.PayInterval,
	}
end

A["Job.SelectCivilian"] = function(player, p)
	return S.JobService.SelectCivilianRole(player, typeof(p) == "table" and p.Rank)
end

A["Job.SetDuty"] = function(player, p)
	return S.JobService.SetDuty(player, typeof(p) == "table" and p.On)
end

A["Job.Resign"] = function(player)
	return S.JobService.Resign(player)
end

A["Job.Set"] = function(player, p)
	if typeof(p) ~= "table" then
		return false, "Ungueltig"
	end
	local target = Players:GetPlayerByUserId(typeof(p.Target) == "number" and p.Target or 0)
	local ok, msg = S.JobService.SetJob(player, target, p.Faction, p.Rank)
	if ok and target ~= player then
		push(target, "Notify", { Text = "Deine Fraktion wurde geaendert: " .. tostring(msg), Kind = "info" })
	end
	return ok, msg
end

A["Players.List"] = function(player)
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local d = S.DataService.Get(pl)
		if d and d.Character.Created then
			table.insert(list, { UserId = pl.UserId, Name = rpName(d), Faction = d.Job.Faction, Rank = d.Job.Rank, Self = (pl == player) })
		end
	end
	return true, nil, list
end

A["Shop.Buy"] = function(player, p)
	return S.ShopService.Buy(player, p)
end
-- Katalog neu laden (nach Kauf: Sperren/Bestand aktualisieren) - nur im Laden
A["Shop.Info"] = function(player, p)
	local id = tbl(p).ShopId
	if typeof(id) ~= "string" or not S.ShopService.AtShop(player, id) then
		return false, "Du bist nicht im Laden"
	end
	return true, nil, S.ShopService.Describe(player, id)
end

-- Waffen (Prompt 08)
A["Weapon.Equip"] = function(player, p)
	return S.WeaponService.Equip(player, tbl(p).ItemId)
end
A["Weapon.Holster"] = function(player)
	return S.WeaponService.Holster(player)
end
A["Weapon.Load"] = function(player, p)
	return S.WeaponService.Load(player, tbl(p).ItemId)
end
A["Weapon.Unload"] = function(player, p)
	return S.WeaponService.Unload(player, tbl(p).ItemId)
end

-- Kleidung (Prompt 08)
A["Clothing.Wear"] = function(player, p)
	return S.ClothingService.Wear(player, tbl(p).Selection)
end
A["Clothing.SaveOutfit"] = function(player, p)
	return S.ClothingService.SaveOutfit(player, tbl(p).Index)
end
A["Clothing.WearOutfit"] = function(player, p)
	return S.ClothingService.WearOutfit(player, tbl(p).Index)
end
A["Clothing.DeleteOutfit"] = function(player, p)
	return S.ClothingService.DeleteOutfit(player, tbl(p).Index)
end
A["Clothing.Reset"] = function(player)
	return S.ClothingService.Reset(player)
end

-- Kriminalitaet (Prompt 09)
A["Crime.Cancel"] = function(player)
	return S.CrimeService.Cancel(player)
end
A["Crime.Fence"] = function(player)
	return S.CrimeService.Fence(player)
end
A["Crime.State"] = function(player)
	S.WantedService.PushState(player)
	return true, nil, S.CrimeService.State(player)
end
-- Polizei: aktive Ueberfaelle + Fahndungsliste (nur mit MDT-Zugriff)
A["Crime.PoliceView"] = function(player)
	if not S.JusticeService.HasMDTAccess(player) then
		return false, "Kein MDT-Zugriff"
	end
	return true, nil, { Heists = S.CrimeService.ActiveForPolice(), Wanted = S.WantedService.List() }
end

-- Feuerwehr / Rettungsdienst (gemeinsamer Dienst) -----------------------------------------------
A["Rescue.Dashboard"] = function(player)
	return S.RescueService.Dashboard(player)
end
A["Rescue.SetCallsign"] = function(player, p)
	return S.RescueService.SetCallsign(player, tbl(p).Callsign)
end
A["Rescue.SetStatus"] = function(player, p)
	if not S.RescueService.Member(player, true) then
		return false, "Nur im Dienst (Feuerwehr/EMS)"
	end
	return S.PoliceService.SetStatus(player, tbl(p).Status)
end
A["Rescue.GarageList"] = function(player)
	return S.RescueService.GarageList(player)
end
A["Rescue.GarageSpawn"] = function(player, p)
	return S.RescueService.GarageSpawn(player, tbl(p).Id)
end
A["Rescue.GaragePark"] = function(player)
	return S.RescueService.GaragePark(player)
end
-- Personal: Rang setzen innerhalb der eigenen Fraktion (Rechte prueft JobService.SetJob)
A["Faction.SetRank"] = function(player, p)
	local target = Players:GetPlayerByUserId(typeof(tbl(p).Target) == "number" and p.Target or 0)
	local faction = S.DataService.Get(player).Job.Faction
	if faction == "Civilian" then
		return false, "Keine Berechtigung"
	end
	local ok, msg = S.JobService.SetJob(player, target, faction, tbl(p).Rank)
	if ok and target ~= player then
		push(target, "Notify", { Text = "Personalaenderung: " .. tostring(msg), Kind = "info" })
	end
	return ok, msg
end
A["Faction.Dismiss"] = function(player, p)
	local target = Players:GetPlayerByUserId(typeof(tbl(p).Target) == "number" and p.Target or 0)
	return S.JobService.Dismiss(player, target)
end
A["Fire.Refill"] = function(player)
	return S.FireService.Refill(player)
end
A["Fire.Active"] = function(player)
	if not S.RescueService.IsResponder(player, "Fire") then
		return false, "Nur Feuerwehr im Dienst"
	end
	return true, nil, S.FireService.Active()
end

-- Rettungsdienst-Massnahmen (Ziel: Target = UserId)
for action, fn in pairs({ Examine = "Examine", Stabilize = "Stabilize", Medicate = "Medicate", Revive = "Revive", Carry = "Carry", Load = "Load", Unload = "Unload", Treat = "Treat" }) do
	A["Medical." .. action] = function(player, p)
		return S.MedicalService[fn](player, tbl(p).Target)
	end
end
A["Medical.Respawn"] = function(player)
	return S.MedicalService.Respawn(player)
end
A["Medical.CallHelp"] = function(player)
	return S.MedicalService.CallHelp(player)
end

-- Leitstelle: Einsatz an weiteren Dienst weitergeben
A["Dispatch.Forward"] = function(player, p)
	return S.DispatchService.Forward(player, tbl(p).Id, tbl(p).Service)
end

-- Smartphone ---------------------------------------------------------------------------------------
A["Phone.SaveSettings"] = function(player, p)
	return S.PhoneService.SaveSettings(player, p)
end
A["Phone.AddContact"] = function(player, p)
	return S.PhoneService.AddContact(player, tbl(p).UserId)
end
A["Phone.RemoveContact"] = function(player, p)
	return S.PhoneService.RemoveContact(player, tbl(p).UserId)
end
A["Phone.Server"] = function(player)
	return S.PhoneService.Server(player)
end
A["Vehicle.Owned"] = function(player)
	return true, nil, S.VehicleService.OwnedList(player)
end
A["Vehicle.SpawnOwned"] = function(player, p)
	return S.VehicleService.SpawnOwned(player, tbl(p).Id)
end
A["Vehicle.ParkOwned"] = function(player, p)
	return S.VehicleService.ParkOwned(player, tbl(p).Id)
end
A["Map.NearestATM"] = function(player)
	local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not r then
		return false, "Nicht moeglich"
	end
	local best, bd
	for _, inst in ipairs(game:GetService("CollectionService"):GetTagged("Interactable")) do
		if inst:GetAttribute("InteractType") == "ATM" and inst:IsDescendantOf(workspace) then
			local pos = inst:IsA("BasePart") and inst.Position or inst:GetPivot().Position
			local dd = (pos - r.Position).Magnitude
			if not bd or dd < bd then
				best, bd = pos, dd
			end
		end
	end
	if not best then
		return false, "Kein Geldautomat gefunden"
	end
	return true, nil, { X = best.X, Y = best.Y, Z = best.Z, Distance = math.floor(bd * 0.28) }
end

-- Prompt 10: Services koennen eigene Aktionen mitbringen (Tabelle Actions); vorhandene Namen werden nicht ueberschrieben
for _, svc in pairs(S) do
	if type(svc) == "table" and type(svc.Actions) == "table" then
		for name, fn in pairs(svc.Actions) do
			if A[name] == nil then
				A[name] = fn
			else
				warn("[Main] Aktion doppelt, ignoriert: " .. name)
			end
		end
	end
end

-- Dispatcher
local NEEDS_CHARACTER = { ["Profile.Get"] = false, ["Character.Create"] = false }
local DETAINED_OK = { ["Profile.Get"] = true, ["Players.List"] = true, ["Job.Info"] = true }
-- Bewusstlose Spieler: nur Hilfe rufen, Krankenhaus, lesen
local UNCONSCIOUS_OK = { ["Profile.Get"] = true, ["Medical.CallHelp"] = true, ["Medical.Respawn"] = true, ["Phone.Server"] = true, ["Job.Info"] = true }
Request.OnServerInvoke = function(player, action, payload)
	if typeof(action) ~= "string" or not A[action] then
		return { ok = false, msg = "Unbekannte Aktion" }
	end
	if not allow(player) then
		return { ok = false, msg = "Zu viele Anfragen - kurz warten" }
	end
	local d = S.DataService.Get(player)
	if not d then
		return { ok = false, msg = "Profil wird noch geladen" }
	end
	if NEEDS_CHARACTER[action] ~= false and not d.Character.Created then
		return { ok = false, msg = "Erstelle zuerst deinen Charakter" }
	end
	if player:GetAttribute("Injury") == "Unconscious" and not UNCONSCIOUS_OK[action] then
		return { ok = false, msg = "Nicht moeglich - du bist bewusstlos" }
	end
	-- Gefesselte / inhaftierte Spieler: nur lesende Aktionen und Notruf (nicht in Haft)
	if (player:GetAttribute("Cuffed") or player:GetAttribute("Jailed")) and not DETAINED_OK[action] then
		if not (action == "Emergency.Call" and not player:GetAttribute("Jailed")) then
			return { ok = false, msg = player:GetAttribute("Jailed") and "Nicht moeglich - du bist in Haft" or "Nicht moeglich - du bist gefesselt" }
		end
	end
	local ok, okRes, msg, data = pcall(A[action], player, payload)
	if not ok then
		warn("[Request] " .. action .. " Fehler: " .. tostring(okRes))
		return { ok = false, msg = "Serverfehler" }
	end
	return { ok = okRes == true, msg = msg, data = data }
end

-- Start
S.DataService.Start()
for _, name in ipairs({ "JobService", "PayrollService", "CharacterService", "InteractionService", "VehicleService", "UniformService", "PoliceService", "RescueService", "RadioService", "DispatchService", "JusticeService", "FireService", "MedicalService", "PhoneService", "WeaponService", "ClothingService", "WantedService", "CrimeService", "DealershipService", "PropertyService", "ActivityService", "WorkService", "BusinessService", "CommsService", "SocialService", "LottService", "GateService" }) do
	S[name].Start()
end
-- Interaktionspunkte der Polizeiwache
S.InteractionService.Register("PoliceDuty", function(player)
	push(player, "OpenPolice", {})
end)
S.InteractionService.Register("PoliceGarage", function(player)
	push(player, "OpenGarage", {})
end)
S.InteractionService.Register("PoliceMDT", function(player)
	push(player, "OpenMDT", {})
end)
S.InteractionService.Register("PoliceDispatch", function(player)
	push(player, "OpenMDT", { Tab = "Calls" })
end)
-- Feuerwache und Krankenhaus
for _, f in ipairs({ "Fire", "EMS" }) do
	S.InteractionService.Register(f .. "Duty", function(player)
		push(player, "OpenRescue", { Faction = f })
	end)
	S.InteractionService.Register(f .. "Garage", function(player)
		push(player, "OpenRescue", { Faction = f, Garage = true })
	end)
	S.InteractionService.Register(f .. "Dispatch", function(player)
		push(player, "OpenMDT", { Tab = "Calls" })
	end)
end
S.InteractionService.Register("FireEquipment", function(player)
	local ok, msg = S.FireService.Refill(player)
	push(player, "Notify", { Text = msg, Kind = ok and "success" or "error" })
end)
S.InteractionService.Register("EMSEquipment", function(player)
	if not S.RescueService.IsResponder(player, "EMS") then
		push(player, "Notify", { Text = "Nur Rettungsdienst im Dienst", Kind = "error" })
		return
	end
	for id, n in pairs(require(Shared.Config.Rescue).EMS.Supplies) do
		local have = S.InventoryService.Count(player, id)
		if have < n then
			S.InventoryService.Add(player, id, n - have, "Nachschub")
		end
	end
	push(player, "Notify", { Text = "Ausruestung aufgefuellt", Kind = "success" })
end)
-- Test-Schnittstelle NUR in Studio: BindableFunction in ServerStorage (fuer Clients unsichtbar/unerreichbar)
if game:GetService("RunService"):IsStudio() then
	local dbg = game:GetService("ServerStorage"):FindFirstChild("MiamiDebug") or Instance.new("BindableFunction")
	dbg.Name = "MiamiDebug"
	dbg.Parent = game:GetService("ServerStorage")
	local fake = { UserId = -1001, Name = "TestBuerger" }
	local C = {}
	function C.Profile()
		local p = Players:GetPlayers()[1]
		local d = p and S.DataService.Get(p)
		return d and game:GetService("HttpService"):JSONEncode({ Cash = d.Money.Cash, Bank = d.Money.Bank, Job = d.Job, Items = d.Inventory.Items, History = #d.Money.History, Name = d.Character.FirstName .. " " .. d.Character.LastName, Mock = S.DataService.IsMock() })
	end
	function C.PayOnce()
		return S.PayrollService.PayOnce()
	end
	function C.ForceNonAdmin(on)
		S.JobService._forceNonAdmin = on
		return true
	end
	function C.Damage(n)
		local h = Players:GetPlayers()[1].Character.Humanoid
		h.Health -= n
		return h.Health
	end
	function C.FakeTransfer(amount, account)
		local p = Players:GetPlayers()[1]
		S.DataService._registerTestProfile(fake)
		local tx = game:GetService("HttpService"):GenerateGUID(false)
		local ok1, e1 = S.EconomyService.Transfer(p, fake, account, amount, tx)
		local dup, e2 = S.EconomyService.Transfer(p, fake, account, amount, tx)
		local fd = S.DataService.Get(fake)
		local res = string.format("Transfer %s: %s %s | Duplikat: %s %s | Empfaenger %s=%d", account, tostring(ok1), tostring(e1), tostring(dup), tostring(e2), account, fd.Money[account])
		local back = S.EconomyService.Transfer(fake, p, account, amount, game:GetService("HttpService"):GenerateGUID(false))
		S.DataService._unregister(fake)
		return res .. " | Rueckbuchung: " .. tostring(back)
	end
	function C.SaveAndPeek()
		local p = Players:GetPlayers()[1]
		local ok = S.DataService.Save(p, false)
		local stored = S.DataService._peek(p.UserId)
		return string.format("Gespeichert=%s, im Speicher: Name=%s %s, Bank=%s, Session=%s", tostring(ok), stored and stored.Character.FirstName or "-", stored and stored.Character.LastName or "-", stored and tostring(stored.Money.Bank) or "-", stored and stored.Meta.Session and "gesetzt" or "frei")
	end
	-- Virtueller Verdaechtiger (NPC + Profil) fuer Polizeitests im Einzelspieler-Studio
	local suspect
	function C.SpawnSuspect()
		local p = Players:GetPlayers()[1]
		local r = p.Character.HumanoidRootPart
		if suspect and suspect.Character then
			suspect.Character:Destroy()
		end
		local desc = Instance.new("HumanoidDescription")
		local npc = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		npc.Name = "Suspect_TestNPC"
		npc:SetAttribute("TestTargetId", -2001) -- nur Studio: Client-Interaktionsmenue findet die Test-Person
		npc:PivotTo(r.CFrame * CFrame.new(0, 0, -5))
		npc.Parent = workspace
		local attrs = {}
		suspect = {
			UserId = -2001, Name = "TestSuspect", Character = npc, Parent = game,
			SetAttribute = function(self, k, v)
				attrs[k] = v
				npc:SetAttribute(k, v)
			end,
			GetAttribute = function(self, k)
				return attrs[k]
			end,
		}
		local d = S.DataService._registerTestProfile(suspect)
		d.Character.FirstName, d.Character.LastName = "Tony", "Vega"
		d.Inventory.Items.Pistol = 1
		d.Inventory.Items.Ammo9mm = 24
		d.Money.Bank = 4000
		S.JusticeService.TestTargets[-2001] = suspect
		return "Verdaechtiger Tony Vega (UserId -2001) vor dir"
	end
	-- Testperson steigt in ein eigenes Zivilfahrzeug direkt vor dem Polizeifahrzeug des Testers (Verkehrskontrolle)
	function C.SuspectCar()
		local p = Players:GetPlayers()[1]
		local pc = p and S.VehicleService.VehicleOf(p)
		if not (suspect and suspect.Character and pc) then
			return "Testperson oder Polizeifahrzeug fehlt"
		end
		local car, err = S.VehicleService.Spawn(suspect, "Sedan", pc:GetPivot() * CFrame.new(0, 1, -24), "Civil", "Civil")
		if not car then
			return "Spawn fehlgeschlagen: " .. tostring(err)
		end
		task.wait(0.5)
		car.DriverSeat:Sit(suspect.Character.Humanoid)
		return "Testperson faehrt " .. tostring(car:GetAttribute("Plate"))
	end
	function C.SuspectGive(itemId, n)
		if not suspect then
			return "kein Verdaechtiger"
		end
		return tostring(S.InventoryService.Add(suspect, itemId, n or 1, "Test"))
	end
	function C.SuspectInfo()
		local d = suspect and S.DataService.Get(suspect)
		if not d then
			return "kein Verdaechtiger"
		end
		local hum = suspect.Character:FindFirstChildOfClass("Humanoid")
		return game:GetService("HttpService"):JSONEncode({
			Cuffed = suspect:GetAttribute("Cuffed"), Escorted = suspect:GetAttribute("Escorted"), Detained = suspect:GetAttribute("Detained"),
			Jailed = suspect:GetAttribute("Jailed"), JailRemaining = suspect:GetAttribute("JailRemaining"), WalkSpeed = hum.WalkSpeed,
			Pos = tostring(suspect.Character.HumanoidRootPart.Position), Bank = d.Money.Bank, Cash = d.Money.Cash, Items = d.Inventory.Items,
			Charges = #d.Record.Charges, Citations = #d.Record.Citations, Points = d.Record.LicensePoints, Wanted = d.Record.Wanted,
			Warrants = #d.Record.Warrants, JailSeconds = d.Record.JailSeconds,
		})
	end
	-- Prompt 08: Geld/Spielzeit/Gegenstaende fuer Shop- und Waffentests
	function C.Give(itemId, n)
		return tostring(S.InventoryService.Add(Players:GetPlayers()[1], itemId, n or 1, "Test"))
	end
	function C.SetMoney(cash, bank)
		S.DataService.Mutate(Players:GetPlayers()[1], "Test", function(d)
			d.Money.Cash, d.Money.Bank = cash, bank
		end)
		return "ok"
	end
	function C.SetPlayTime(hours)
		S.DataService.Mutate(Players:GetPlayers()[1], "Test", function(d)
			d.Stats.PlayTime = hours * 3600
		end)
		return "ok"
	end
	-- Prompt 09: Kriminalitaet
	function C.CrimeTest(minPolice)
		S.CrimeService._setTestMinPolice(minPolice)
		return "MinPolice Test=" .. tostring(minPolice)
	end
	function C.CrimeReset()
		S.CrimeService._resetCooldowns()
		return "Cooldowns zurueckgesetzt"
	end
	function C.HeistStartOnce(id)
		local ok, msg = S.CrimeService.StartHeist(Players:GetPlayers()[1], id)
		return tostring(ok) .. " " .. tostring(msg)
	end
	function C.LootCase(i)
		local cases = S.CrimeService.Cases("Jeweler")
		local ok, msg = S.CrimeService.LootCase(Players:GetPlayers()[1], cases[i])
		return tostring(ok) .. " " .. tostring(msg)
	end
	function C.FenceSell()
		local ok, msg = S.CrimeService.Fence(Players:GetPlayers()[1])
		return tostring(ok) .. " " .. tostring(msg)
	end
	function C.CrimeInfo()
		local p = Players:GetPlayers()[1]
		local d = S.DataService.Get(p)
		return game:GetService("HttpService"):JSONEncode({ Wanted = d.Record.WantedLevel, WantedBool = d.Record.Wanted, Reason = d.Record.WantedReason, Crime = d.Crime, Loot = { d.Inventory.Items.MarkedCash, d.Inventory.Items.StolenJewelry }, Cash = d.Money.Cash, Police = S.CrimeService.ActiveForPolice() })
	end
	function C.CrimeWipe()
		local p = Players:GetPlayers()[1]
		S.DataService.Mutate(p, "Test", function(d)
			d.Crime = { Heists = 0, HeistsFailed = 0, IllegalEarned = 0, LastHeist = 0, CapWindowStart = 0, CapEarned = 0, Ledger = {}, Cooldowns = {}, Organization = "" }
			d.Record.WantedLevel, d.Record.WantedUntil, d.Record.Wanted, d.Record.WantedReason = 0, 0, false, ""
			d.Inventory.Items.MarkedCash, d.Inventory.Items.StolenJewelry = nil, nil
		end)
		S.WantedService.PushState(p)
		return "ok"
	end
	function C.Wanted(level)
		S.WantedService.Set(Players:GetPlayers()[1], level, "Test")
		return "ok"
	end
	function C.ResetWardrobe()
		S.DataService.Mutate(Players:GetPlayers()[1], "Test", function(d)
			d.Wardrobe = { Owned = {}, Current = {}, Outfits = {} }
		end)
		return "ok"
	end
	function C.SetWanted(on)
		S.DataService.Mutate(Players:GetPlayers()[1], "Test", function(d)
			d.Record.Wanted = on
		end)
		return "ok"
	end
	function C.SetJobDirect(faction, rank)
		local p = Players:GetPlayers()[1]
		S.DataService.Mutate(p, "SetJob", function(d)
			d.Job.Faction, d.Job.Rank, d.Job.OnDuty = faction, rank, false
		end)
		return "Job gesetzt: " .. faction .. " " .. rank
	end
	-- Phase 7: Brand-/Verletzungstests
	function C.StartFire(kind)
		local inc, err = S.FireService._startNear(Players:GetPlayers()[1], kind)
		return inc and ("Einsatz " .. inc.Id .. " " .. inc.Type .. " Herde=" .. #inc.Flames .. " Call=" .. tostring(inc.CallId)) or tostring(err)
	end
	function C.Fires()
		return game:GetService("HttpService"):JSONEncode(S.FireService.Active())
	end
	function C.SetHealth(hp, who)
		local target = (who == "suspect") and suspect or Players:GetPlayers()[1]
		S.MedicalService._setHealth(target, hp, "Test")
		return string.format("Health=%s Injury=%s", tostring(target.Character.Humanoid.Health), tostring(target:GetAttribute("Injury")))
	end
	function C.Medical(who)
		local target = (who == "suspect") and suspect or Players:GetPlayers()[1]
		local d = S.DataService.Get(target)
		return game:GetService("HttpService"):JSONEncode({ Injury = target:GetAttribute("Injury"), Stabilized = target:GetAttribute("Stabilized"), Health = target.Character and target.Character.Humanoid.Health, Saved = d and d.Medical, WalkSpeed = target.Character and target.Character.Humanoid.WalkSpeed })
	end
	-- Prompt 11: Berufe/Unternehmen testen
	function C.WorkState()
		return S.WorkService.Debug(Players:GetPlayers()[1])
	end
	function C.SetXP(xp)
		local p = Players:GetPlayers()[1]
		S.DataService.Mutate(p, "DebugXP", function(d)
			d.Work.XP = xp
		end)
		p:SetAttribute("WorkLevel", require(Shared.Config.Work).LevelFor(xp))
		return "XP " .. xp
	end
	function C.BusinessFlush()
		S.BusinessService.Flush()
		return "ok"
	end
	function C.Audit(n)
		local out = {}
		for i = 1, math.min(n or 10, #auditLog) do
			local e = auditLog[i]
			table.insert(out, e.Kind .. " | " .. e.Actor .. " -> " .. e.Target .. " | " .. e.Details)
		end
		return table.concat(out, "\n")
	end
	-- Prompt 13: LOTT testen (Miete als erster Spieler, Zeitsprung fuer die Minutenabrechnung, Doppelmiete durch Testperson)
	function C.Lott(op, id, arg)
		local p = Players:GetPlayers()[1]
		local L = S.LottService
		local HS = game:GetService("HttpService")
		if op == "Goto" then
			local m = workspace.LottScooters[id]
			p:RequestStreamAroundAsync(m.Chassis.Position)
			p.Character:PivotTo(m.Chassis.CFrame * CFrame.new(3, 3, 0))
			return "ok"
		elseif op == "Rent" then
			return HS:JSONEncode({ L.Rent(p, id, arg or "Bank") })
		elseif op == "End" then
			return HS:JSONEncode({ L.End(p) })
		elseif op == "List" then
			local _, _, data = L.List(p)
			return HS:JSONEncode(data)
		elseif op == "Shift" then
			-- Mietbeginn um arg Sekunden vorverlegen (simuliert vergangene Fahrzeit)
			local r = L._rentals[p]
			if r then
				r.Start -= arg
			end
			return r and (r.Start .. "") or "keine Miete"
		elseif op == "Other" then
			-- zweite Person versucht denselben Roller zu mieten
			local other = { UserId = -3001, Name = "TestZwei", Character = p.Character, GetAttribute = function() end, SetAttribute = function() end }
			return HS:JSONEncode({ L.Rent(other, id, "Bank") })
		end
		return "?"
	end
	dbg.OnInvoke = function(cmd, ...)
		return C[cmd] and C[cmd](...) or "unbekannter Befehl"
	end
end
print("[MIAMI STATE] Server gestartet" .. (S.DataService.IsMock() and " (Ersatzspeicher - Studio ohne API-Zugriff)" or ""))
