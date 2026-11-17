-- DataService: laedt, haelt und speichert Spielerprofile (DataStoreService).
-- * Session-Lock: ein Profil ist immer nur auf EINEM Server aktiv (verhindert Duplikate / Datenverlust).
-- * UpdateAsync statt SetAsync, Wiederholungen mit Backoff, Request-Budget wird beachtet.
-- * Autosave, Speichern beim Verlassen und beim Herunterfahren (BindToClose).
-- * Versioniertes Datenschema; fehlende Felder werden beim Laden aus den Standardwerten ergaenzt.
-- * Studio ohne API-Zugriff: Ersatzspeicher im Arbeitsspeicher (deutlich gekennzeichnet, nicht dauerhaft).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local Economy = require(Shared.Config.Economy)
local Items = require(Shared.Config.Items)

local DataService = {}
DataService.SCHEMA_VERSION = 5
DataService.STORE_NAME = "MiamiState_Players_v1"

local LOCK_TIMEOUT = 600 -- Sekunden: verwaiste Locks (Server-Absturz) verfallen
local profiles = {} -- [Player] = { Data = table, Dirty = bool, Saving = bool }
local loadedEvent = Instance.new("BindableEvent")
local changedEvent = Instance.new("BindableEvent")
DataService.ProfileLoaded = loadedEvent.Event -- (player, data)
DataService.Changed = changedEvent.Event -- (player, data, reason)

-- Standardprofil -------------------------------------------------------------------------
local function defaults()
	local inv = {}
	for id, n in pairs(Items.StartInventory) do
		inv[id] = n
	end
	return {
		Version = DataService.SCHEMA_VERSION,
		Character = { Created = false, FirstName = "", LastName = "", Gender = "", BirthYear = 0, Appearance = { Skin = 1, Height = 2, Build = 2 }, CreatedAt = 0 },
		Money = { Cash = Economy.StartCash, Bank = Economy.StartBank, History = {} },
		Job = { Faction = "Civilian", Rank = 1, OnDuty = false },
		Inventory = { Items = inv },
		-- Schema 3: eigene Fahrzeuge { Id, Type, Plate, Color = {r,g,b}, Bought }
		Vehicles = { Owned = {} },
		Properties = { Owned = {} }, -- spaeter: Haeuser/Wohnungen
		Stats = { PlayTime = 0, Joins = 0, TotalEarned = 0, TotalSpent = 0 },
		-- Schema 2: Strafregister (jeder Spieler) und Fraktionsdaten
		Record = {
			Charges = {}, Citations = {}, Warnings = {}, Warrants = {},
			Wanted = false, WantedReason = "", JailSeconds = 0, LicensePoints = 0, LicenseSuspended = false, Arrests = 0,
			-- Schema 5: Fahndungsstufe 0-3 (Config.Crime.WantedLevels) und Ablaufzeit der aktuellen Stufe
			WantedLevel = 0, WantedUntil = 0,
		},
		-- Schema 5: Kriminalitaet - Statistik, Abklingzeiten, nachvollziehbares Buch ueber illegale Einnahmen
		Crime = {
			Heists = 0, HeistsFailed = 0, IllegalEarned = 0, LastHeist = 0,
			CapWindowStart = 0, CapEarned = 0, -- Stundenlimit beim Hehler
			Ledger = {}, -- { {T, Kind, Amount, Note} } (max. 30)
			Cooldowns = {}, -- [HeistId] = os.time() bis zur naechsten Teilnahme
			Organization = "", -- vorbereitet: kriminelle Organisationen
		},
		FactionData = {
			Police = { Badge = 0, Callsign = "", DutySeconds = 0, Arrests = 0, Citations = 0 },
			-- Schema 3: Feuerwehr und Rettungsdienst
			Fire = { Badge = 0, Callsign = "", DutySeconds = 0, Incidents = 0, Extinguished = 0 },
			EMS = { Badge = 0, Callsign = "", DutySeconds = 0, Patients = 0, Revives = 0 },
		},
		-- Schema 3: Verletzungszustand (ueberdauert Verlassen des Spiels), Smartphone
		Medical = { State = "Healthy", Health = 100, DownSince = 0 },
		Phone = {
			Contacts = {}, -- { {UserId, Name, Added} }
			Settings = { SoundVolume = 0.8, MusicVolume = 0.5, Minimap = true, MinimapZoom = 2, UIScale = 1, Particles = true, ShowHints = true, Wallpaper = 1 },
		},
		-- Schema 4 (Prompt 08): geladene Munition je Waffe, Kleidung (gekauft, aktuell getragen, gespeicherte Outfits)
		Weapons = { Loaded = {} }, -- [itemId] = Schuss im Magazin
		Wardrobe = { Owned = {}, Current = {}, Outfits = {} }, -- Owned: Liste von Kleidungs-Ids; Current: [Slot] = Id; Outfits: { {Slot=Id,...} }
		-- Prompt 10: Freizeitwerte (Fitness 0-100, Bestwerte). Fahrzeuge/Immobilien erweitern bestehende Listen:
		--   Vehicles.Owned[i] += { Price, Paint, Fuel, Tuning = { Rims, Tint, Underglow, Lights } }
		--   Properties.Owned[i] = { Id, Building, Tier, Number, Mode = "Own"|"Rent", Price, RentUntil, Locked, Keys, Furniture, Storage }
		Leisure = { Fitness = 0, Bowling = 0, Arcade = 0, Hoops = 0 },
		Meta = { FirstJoin = os.time(), LastJoin = 0, LastSave = 0, RecentTx = {}, Session = nil },
	}
end

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = deepCopy(v)
	end
	return c
end

-- fehlende Felder aus den Standardwerten uebernehmen (bestehende Werte bleiben)
local function reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			data[k] = deepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" and k ~= "Items" and k ~= "Owned" and k ~= "History" and k ~= "RecentTx"
			and k ~= "Charges" and k ~= "Citations" and k ~= "Warnings" and k ~= "Warrants" and k ~= "Contacts"
			and k ~= "Loaded" and k ~= "Current" and k ~= "Outfits" and k ~= "Ledger" then
			reconcile(data[k], v)
		end
	end
	return data
end

local function migrate(data)
	-- Schema 1 -> 2: Polizei hatte 5 Raenge, jetzt 9 (Cadet .. Chief)
	if (data.Version or 1) < 2 and data.Job and data.Job.Faction == "Police" then
		local Factions = require(Shared.Config.Factions)
		data.Job.Rank = Factions.Police.LegacyRankMap[data.Job.Rank] or 2
	end
	-- Schema 4 -> 5: bestehende Fahndung (bool) wird Stufe 1
	if (data.Version or 1) < 5 and data.Record and data.Record.Wanted and (data.Record.WantedLevel or 0) == 0 then
		data.Record.WantedLevel = 1
	end
	-- Schema 2 -> 3: Feuerwehr 5 -> 7 Raenge, Rettungsdienst 4 -> 5 Raenge
	if (data.Version or 1) < 3 and data.Job and (data.Job.Faction == "Fire" or data.Job.Faction == "EMS") then
		local Factions = require(Shared.Config.Factions)
		data.Job.Rank = Factions[data.Job.Faction].LegacyRankMap[data.Job.Rank] or 1
	end
	data.Version = DataService.SCHEMA_VERSION
	return data
end

-- Speicher (echt oder Ersatz) -----------------------------------------------------------------
local MockStore = {}
MockStore.__index = MockStore
function MockStore.new()
	return setmetatable({ data = {} }, MockStore)
end
function MockStore:UpdateAsync(key, fn)
	local new = fn(deepCopy(self.data[key]))
	if new ~= nil then
		self.data[key] = deepCopy(new)
	end
	return new
end
function MockStore:GetAsync(key)
	return deepCopy(self.data[key])
end

local store
local usingMock = false
local function initStore()
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore(DataService.STORE_NAME)
	end)
	if ok then
		local probeOk, err = pcall(function()
			return s:GetAsync("__probe")
		end)
		if probeOk then
			store = s
			return
		end
		warn("[DataService] DataStore nicht erreichbar: " .. tostring(err))
	else
		warn("[DataService] GetDataStore fehlgeschlagen: " .. tostring(s))
	end
	if RunService:IsStudio() then
		warn("[DataService] Studio ohne API-Zugriff -> Ersatzspeicher (Daten gehen beim Stoppen verloren). "
			.. "Fuer echte Tests: Game Settings > Security > Enable Studio Access to API Services.")
		store = MockStore.new()
		usingMock = true
	else
		error("[DataService] Kein Datenspeicher verfuegbar")
	end
end

function DataService.IsMock()
	return usingMock
end

local function keyFor(userId)
	return "Player_" .. tostring(userId)
end

local function waitForBudget(requestType)
	if usingMock then
		return
	end
	local t0 = os.clock()
	while DataStoreService:GetRequestBudgetForRequestType(requestType) < 1 and os.clock() - t0 < 30 do
		task.wait(1)
	end
end

local function retry(label, fn, attempts)
	attempts = attempts or 4
	local lastErr
	for i = 1, attempts do
		local ok, res = pcall(fn)
		if ok then
			return true, res
		end
		lastErr = res
		warn(string.format("[DataService] %s fehlgeschlagen (Versuch %d/%d): %s", label, i, attempts, tostring(res)))
		task.wait(math.min(2 ^ i, 16))
	end
	return false, lastErr
end

-- Laden mit Session-Lock ---------------------------------------------------------------------
local function loadProfile(player)
	local key = keyFor(player.UserId)
	-- Studio hat keine JobId: feste Kennung, damit ein abrupt gestoppter Test das Profil nicht 10 Min. sperrt
	local jobId = game.JobId ~= "" and game.JobId or "studio-session"
	DataService._jobId = DataService._jobId or jobId
	jobId = DataService._jobId
	for attempt = 1, 5 do
		local locked = false
		waitForBudget(Enum.DataStoreRequestType.UpdateAsync)
		local ok, result = retry("Laden " .. key, function()
			return store:UpdateAsync(key, function(old)
				locked = false
				local holder = old and old.Meta and old.Meta.Session and old.Meta.Session.JobId
				local studioOwn = jobId == "studio-session" and typeof(holder) == "string" and holder:sub(1, 6) == "studio"
				if holder and holder ~= jobId and not studioOwn
					and os.time() - (old.Meta.Session.Time or 0) < LOCK_TIMEOUT then
					locked = true
					return nil -- nichts schreiben, anderer Server haelt das Profil
				end
				local data = old and migrate(reconcile(old, defaults())) or defaults()
				data.Meta.Session = { JobId = jobId, Time = os.time() }
				data.Meta.LastJoin = os.time()
				data.Stats.Joins += 1
				return data
			end)
		end)
		if not ok then
			return nil, "Speicherdienst nicht erreichbar"
		end
		if not locked and result then
			return result
		end
		if not player.Parent then
			return nil, "Spieler hat das Spiel verlassen"
		end
		task.wait(5) -- Lock eines anderen Servers: kurz warten (z.B. Serverwechsel)
	end
	return nil, "Profil ist noch auf einem anderen Server aktiv"
end

local function sanitizeForClient(data)
	local c = deepCopy(data)
	c.Meta = { FirstJoin = data.Meta.FirstJoin, LastJoin = data.Meta.LastJoin }
	return c
end

-- Oeffentliche Werte als (nur serverseitig schreibbare) Spieler-Attribute fuer HUD und andere Spieler
local function publish(player, data)
	player:SetAttribute("ProfileLoaded", true)
	player:SetAttribute("CharacterCreated", data.Character.Created)
	player:SetAttribute("RPName", data.Character.Created and (data.Character.FirstName .. " " .. data.Character.LastName) or "")
	player:SetAttribute("Cash", data.Money.Cash)
	player:SetAttribute("Bank", data.Money.Bank)
	player:SetAttribute("Faction", data.Job.Faction)
	player:SetAttribute("Rank", data.Job.Rank)
	player:SetAttribute("OnDuty", data.Job.OnDuty)
end

local pushRemote -- wird von Main gesetzt
function DataService.SetPushRemote(r)
	pushRemote = r
end

function DataService.Sync(player)
	local p = profiles[player]
	if not p or typeof(player) ~= "Instance" then
		return -- Testprofile (keine echten Spieler) werden nicht synchronisiert
	end
	publish(player, p.Data)
	if pushRemote then
		pushRemote:FireClient(player, "Profile", sanitizeForClient(p.Data))
	end
end

-- API -------------------------------------------------------------------------------------
function DataService.Get(player)
	local p = profiles[player]
	return p and p.Data or nil
end

function DataService.WaitFor(player, timeout)
	local t0 = os.clock()
	while player.Parent and not profiles[player] and os.clock() - t0 < (timeout or 30) do
		task.wait(0.1)
	end
	return DataService.Get(player)
end

-- Einzige Stelle, an der Profile veraendert werden. fn darf nicht yielden (atomar auf diesem Server).
function DataService.Mutate(player, reason, fn)
	local p = profiles[player]
	if not p then
		return false, "Profil nicht geladen"
	end
	local ok, res, extra = pcall(fn, p.Data)
	if not ok then
		warn("[DataService] Mutate-Fehler (" .. tostring(reason) .. "): " .. tostring(res))
		return false, "Interner Fehler"
	end
	if res == false then
		return false, extra
	end
	p.Dirty = true
	DataService.Sync(player)
	changedEvent:Fire(player, p.Data, reason)
	-- zeitnah speichern (entprellt): begrenzt Datenverlust bei Absturz auf wenige Sekunden
	if typeof(player) == "Instance" and not p.SaveScheduled then
		p.SaveScheduled = true
		task.delay(15, function()
			p.SaveScheduled = false
			if profiles[player] == p and p.Dirty then
				DataService.Save(player, false)
			end
		end)
	end
	return true, extra
end

local activeSaves = 0
function DataService.Save(player, release)
	local p = profiles[player]
	if not p then
		return false
	end
	if p.Saving then
		-- laufende Speicherung abwarten; bei release danach erneut speichern (Lock freigeben)
		while p.Saving do
			task.wait(0.1)
		end
		if not release then
			return true
		end
	end
	p.Saving = true
	activeSaves += 1
	local key = keyFor(player.UserId)
	local snapshot = deepCopy(p.Data)
	waitForBudget(Enum.DataStoreRequestType.UpdateAsync)
	local lostLock = false
	local ok = retry("Speichern " .. key, function()
		return store:UpdateAsync(key, function(old)
			local holder = old and old.Meta and old.Meta.Session and old.Meta.Session.JobId
			if holder and holder ~= DataService._jobId and not (DataService._jobId == "studio-session" and holder:sub(1, 6) == "studio") then
				lostLock = true
				return nil -- anderer Server hat das Profil uebernommen -> nicht ueberschreiben
			end
			snapshot.Meta.LastSave = os.time()
			snapshot.Meta.Session = (not release) and { JobId = DataService._jobId, Time = os.time() } or nil
			return snapshot
		end)
	end)
	p.Saving = false
	activeSaves -= 1
	if ok and not lostLock then
		p.Dirty = false
		p.Data.Meta.LastSave = snapshot.Meta.LastSave
	end
	if lostLock then
		warn("[DataService] Session-Lock verloren fuer " .. key .. " - Speichern verworfen")
	end
	return ok and not lostLock
end

-- Nur fuer Tests: Profil eines virtuellen Spielers (Tabelle mit UserId/Name) im Speicher anlegen
function DataService._registerTestProfile(fakePlayer)
	profiles[fakePlayer] = { Data = defaults(), Dirty = false }
	profiles[fakePlayer].Data.Character = { Created = true, FirstName = "Test", LastName = "Person", Gender = "d", BirthYear = 1990, Appearance = { Skin = 1, Height = 2, Build = 2 }, CreatedAt = os.time() }
	return profiles[fakePlayer].Data
end
function DataService._unregister(fakePlayer)
	profiles[fakePlayer] = nil
end
function DataService._peek(userId)
	return store and store:GetAsync(keyFor(userId))
end

-- Lebenszyklus -----------------------------------------------------------------------------
local function onPlayerAdded(player)
	local data, err = loadProfile(player)
	if not player.Parent then
		return
	end
	if not data then
		player:Kick("MIAMI STATE: Dein Profil konnte nicht geladen werden (" .. tostring(err) .. "). Bitte erneut beitreten.")
		return
	end
	profiles[player] = { Data = data, Dirty = false, JoinTime = os.clock() }
	player:SetAttribute("SessionStart", os.time()) -- laufende Spielzeit (z.B. Freischaltungen im Shop)
	DataService.Sync(player)
	loadedEvent:Fire(player, data)
end

DataService.BeforeRelease = {} -- Funktionen(player), die vor dem letzten Speichern laufen (z.B. Dienstzeit buchen)
local function onPlayerRemoving(player)
	local p = profiles[player]
	if not p then
		return
	end
	for _, fn in ipairs(DataService.BeforeRelease) do
		pcall(fn, player)
	end
	p.Data.Stats.PlayTime += math.floor(os.clock() - (p.JoinTime or os.clock()))
	DataService.Save(player, true)
	profiles[player] = nil
end

function DataService.Start()
	initStore()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, pl in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, pl)
	end
	-- Autosave
	task.spawn(function()
		while true do
			task.wait(Economy.AutosaveInterval)
			for pl, p in pairs(profiles) do
				if typeof(pl) == "Instance" and p.Dirty then
					task.spawn(DataService.Save, pl, false)
				end
			end
		end
	end)
	-- Herunterfahren: alle Profile speichern und Locks freigeben
	game:BindToClose(function()
		for pl in pairs(profiles) do
			if typeof(pl) == "Instance" then
				task.spawn(DataService.Save, pl, true)
			end
		end
		-- warten, bis ALLE Speichervorgaenge (auch die aus PlayerRemoving) abgeschlossen sind
		local t0 = os.clock()
		task.wait(0.1)
		while activeSaves > 0 and os.clock() - t0 < 25 do
			task.wait(0.2)
		end
	end)
end

return DataService
