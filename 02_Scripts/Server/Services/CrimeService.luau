-- CrimeService (Prompt 09): Ueberfaelle (Bank, Juwelier), Hehler, vorbereitete Aktivitaeten.
-- Alles serverseitig: Start, Fortschritt, Zeit, Beute, Abklingzeiten, Fahndung, Polizeialarm.
-- * Ablauf Bank: Start am Tresor (gehaltener Prompt) -> Alarm -> Einsatz in der Leitstelle (DispatchService) -> Taeter muessen im
--   Tresorbereich bleiben, bis der Fortschritt voll ist -> Beute (markierte Geldbuendel) serverseitig berechnet und EINMAL verteilt.
-- * Ablauf Juwelier: erste Vitrine startet den Ueberfall -> jede Vitrine einmal ausraeumbar (Beute je Vitrine) -> Ende bei Zeitablauf,
--   allen Vitrinen oder Flucht.
-- * Status oeffentlich (ReplicatedStorage.MiamiCrime.<Id>, Attribute), Taeter-Details privat (Push \"Heist\").
-- * Beute ist illegal (Inventar), wird beim Hehler mit Abschlag + Stundenlimit zu Bargeld (EconomyService, Buchung im Profil).
-- * Mindestanzahl Polizei im Dienst, Abklingzeit je Ort und je Spieler, Spielzeit-Voraussetzung, max. Crew-Groesse.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local Crime = require(Shared.Config.Crime)
local Items = require(Shared.Config.Items)

local CrimeService = {}
local S
local heists = {} -- [id] = Laufzeitstatus
local folder -- ReplicatedStorage.MiamiCrime
local testMinPolice = nil -- nur Studio: Mindestanzahl Polizei ueberschreiben
local lastLoot = setmetatable({}, { __mode = "k" })
local lastAction = setmetatable({}, { __mode = "k" })
local activities = {} -- vorbereitete Aktivitaeten: [id] = handler

function CrimeService.Init(services)
	S = services
end

local function now()
	return os.time()
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function hum(p)
	return p.Character and p.Character:FindFirstChildOfClass("Humanoid")
end

local function root(p)
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end

local function tierOf(cfg)
	for _, t in ipairs(cfg.Tiers) do
		if t.Id == cfg.DefaultTier and t.Enabled then
			return t
		end
	end
	for _, t in ipairs(cfg.Tiers) do
		if t.Enabled then
			return t
		end
	end
end

local function zoneOf(id)
	for _, z in ipairs(CollectionService:GetTagged("HeistZone")) do
		if z:GetAttribute("HeistId") == id and z:IsDescendantOf(workspace) then
			return z
		end
	end
end

local function inZone(player, zone, margin)
	local r = root(player)
	if not r or not zone then
		return false
	end
	local rel = zone.CFrame:PointToObjectSpace(r.Position)
	local m = margin or 0
	return math.abs(rel.X) <= zone.Size.X / 2 + m and math.abs(rel.Z) <= zone.Size.Z / 2 + m and math.abs(rel.Y) <= zone.Size.Y / 2 + 6
end

local function policeOnDuty()
	local n = 0
	for _, p in ipairs(Players:GetPlayers()) do
		local d = S.DataService.Get(p)
		if d and d.Job.Faction == "Police" and d.Job.OnDuty then
			n += 1
		end
	end
	return n
end

local function minPolice(tier)
	if testMinPolice ~= nil and RunService:IsStudio() then
		return testMinPolice
	end
	return tier.MinPolice
end

-- Darf dieser Spieler an einem Ueberfall teilnehmen?
local function eligible(player, cfg)
	local d = S.DataService.Get(player)
	if not d or not d.Character.Created then
		return false, "Profil nicht geladen"
	end
	if d.Job.Faction == "Police" then
		return false, "Polizisten koennen keine Ueberfaelle begehen"
	end
	if d.Job.OnDuty then
		return false, "Nicht im Dienst moeglich"
	end
	if player:GetAttribute("Cuffed") or player:GetAttribute("Jailed") or player:GetAttribute("Injury") == "Unconscious" then
		return false, "Nicht moeglich"
	end
	local h = hum(player)
	if not h or h.Health <= 0 then
		return false, "Nicht moeglich"
	end
	local cd = d.Crime.Cooldowns[cfg.Id] or 0
	if cd > now() then
		return false, string.format("Du musst noch %d Min. warten", math.ceil((cd - now()) / 60))
	end
	local hours = ((d.Stats.PlayTime or 0) + (player:GetAttribute("SessionStart") and (os.time() - player:GetAttribute("SessionStart")) or 0)) / 3600
	if cfg.MinPlayHours and hours < cfg.MinPlayHours then
		return false, string.format("Erst ab %d Stunde(n) Spielzeit", cfg.MinPlayHours)
	end
	return true
end

local function ledger(player, kind, amount, note)
	S.DataService.Mutate(player, "CrimeLedger", function(d)
		table.insert(d.Crime.Ledger, 1, { T = now(), Kind = kind, Amount = amount, Note = note or "" })
		while #d.Crime.Ledger > 30 do
			table.remove(d.Crime.Ledger)
		end
	end)
end

-- Oeffentlicher Status (fuer alle Spieler synchron) ------------------------------------------------------
local function publish(h)
	local f = folder:FindFirstChild(h.Id)
	if not f then
		return
	end
	f:SetAttribute("State", h.State)
	f:SetAttribute("Tier", h.Tier and h.Tier.Name or "")
	f:SetAttribute("Progress", h.Progress or 0)
	f:SetAttribute("Duration", h.Tier and h.Tier.Duration or 0)
	f:SetAttribute("CooldownUntil", h.CooldownUntil or 0)
	f:SetAttribute("CallId", h.CallId or 0)
	local crew = 0
	for _ in pairs(h.Crew) do
		crew += 1
	end
	f:SetAttribute("CrewCount", crew)
	local units = 0
	local call = h.CallId and S.DispatchService.Get(h.CallId)
	if call then
		units = #call.Units
	end
	f:SetAttribute("Units", units)
	f:SetAttribute("CasesLeft", h.CasesLeft or 0)
end

-- Private Taeter-Ansicht
local function pushCrew(h, extra)
	for p in pairs(h.Crew) do
		if p.Parent then
			S.Push(p, "Heist", {
				Id = h.Id, Name = h.Cfg.Name, Tier = h.Tier.Name, State = h.State, Progress = h.Progress, Duration = h.Tier.Duration,
				Inside = h.Inside and h.Inside[p] or false, Loot = h.Loot[p] or 0, CasesLeft = h.CasesLeft, Units = folder[h.Id]:GetAttribute("Units"),
				CallId = h.CallId, Starter = h.Starter == p, Text = extra,
			})
		end
	end
end

local function addCrew(h, player)
	if h.Crew[player] then
		return true
	end
	local n = 0
	for _ in pairs(h.Crew) do
		n += 1
	end
	if n >= h.Cfg.MaxCrew then
		return false, "Crew ist voll"
	end
	local ok, why = eligible(player, h.Cfg)
	if not ok then
		return false, why
	end
	h.Crew[player] = true
	h.Loot[player] = h.Loot[player] or 0
	S.DataService.Mutate(player, "HeistJoin", function(d)
		d.Crime.Cooldowns[h.Id] = now() + h.Cfg.PlayerCooldown
		d.Crime.LastHeist = now()
	end)
	S.WantedService.Raise(player, h.Tier.Wanted, h.Cfg.Name .. ": Ueberfall")
	S.Push(player, "Notify", { Text = "Du bist am Ueberfall beteiligt: " .. h.Cfg.Name .. " - die Polizei ist alarmiert!", Kind = "warning" })
	S.Log("Heist", player, nil, h.Id .. ": Teilnahme")
	return true
end

-- Ueberfall beenden (einziger Ausgang) ---------------------------------------------------------------------
local function finish(h, result, text)
	if h.State ~= "Active" then
		return
	end
	h.State = "Cooldown"
	local tier = h.Tier
	local cdFactor = (result == "Cancelled") and 0.5 or 1
	h.CooldownUntil = serverNow() + tier.Cooldown * cdFactor
	h.CooldownUntilOs = now() + tier.Cooldown * cdFactor
	local summary = {}
	if result == "Success" and h.Cfg.Kind == "Vault" then
		-- Beute serverseitig: Gesamtsumme zufaellig in der Spanne, auf anwesende Taeter verteilt, je Person genau einmal
		local recipients = {}
		for p in pairs(h.Crew) do
			if p.Parent and h.Inside[p] and not h.Rewarded[p] then
				table.insert(recipients, p)
			end
		end
		local total = math.floor(Random.new():NextInteger(tier.Reward[1], tier.Reward[2]) / 100) * 100
		local value = Crime.LootValue[h.Cfg.Loot]
		local share = (#recipients > 0) and math.floor(total / #recipients / value) or 0
		for _, p in ipairs(recipients) do
			h.Rewarded[p] = true
			local units = share
			local d = S.DataService.Get(p)
			local have = d and (d.Inventory.Items[h.Cfg.Loot] or 0) or 0
			units = math.min(units, Items.Defs[h.Cfg.Loot].Stack - have)
			if units > 0 then
				local ok = S.InventoryService.Add(p, h.Cfg.Loot, units, "Heist")
				if ok then
					h.Loot[p] = (h.Loot[p] or 0) + units * value
					ledger(p, "Beute", units * value, h.Cfg.Name)
				end
			end
			if units < share then
				S.Push(p, "Notify", { Text = "Kein Platz fuer die ganze Beute - ein Teil bleibt zurueck", Kind = "warning" })
			end
			table.insert(summary, string.format("%s $%d", p.Name, units * value))
		end
		if #recipients == 0 then
			result = "Failed"
		end
	end
	local anyLoot = false
	for p, v in pairs(h.Loot) do
		if v > 0 then
			anyLoot = true
		end
	end
	if result == "Success" and not anyLoot then
		result = "Failed"
	end
	-- Statistik
	for p in pairs(h.Crew) do
		if p.Parent then
			S.DataService.Mutate(p, "HeistStat", function(d)
				if result == "Success" then
					d.Crime.Heists += 1
				else
					d.Crime.HeistsFailed += 1
				end
			end)
		end
	end
	-- Leitstelle: vereitelt/abgebrochen -> Einsatz schliessen; erfolgreich -> Taeter fluechtig, Einsatz bleibt offen
	if h.CallId then
		if result == "Success" then
			S.RadioService.Broadcast("DISP", string.format("#%d %s: Taeter mit Beute fluechtig! Fahndung laeuft.", h.CallId, h.Cfg.Name))
			local callId = h.CallId
			task.delay(600, function()
				local c = S.DispatchService.Get(callId)
				if c and c.Status ~= "Abgeschlossen" then
					S.DispatchService.CloseSystem(callId, "automatisch nach 10 Min.")
				end
			end)
		else
			S.DispatchService.CloseSystem(h.CallId, result == "Cancelled" and "Ueberfall abgebrochen" or "Ueberfall vereitelt")
		end
	end
	local texts = { Success = "Ueberfall erfolgreich - verschwinde mit der Beute und bring sie zum Hehler!", Failed = "Ueberfall gescheitert", Cancelled = "Ueberfall abgebrochen" }
	pushCrew(h, text or texts[result])
	for p in pairs(h.Crew) do
		if p.Parent then
			S.Push(p, "Notify", { Text = text or texts[result], Kind = result == "Success" and "success" or "error" })
		end
	end
	S.Log("Heist", h.Starter, nil, string.format("%s %s %s", h.Id, result, table.concat(summary, ", ")))
	h.LastResult = result
	h.Crew, h.Inside = {}, {}
	publish(h)
	folder[h.Id]:SetAttribute("Alarm", false)
	folder[h.Id]:SetAttribute("LastResult", result)
	-- nach der Abklingzeit wieder bereit (Vitrinen zuruecksetzen)
	task.delay(tier.Cooldown * cdFactor, function()
		if h.State == "Cooldown" then
			h.State = "Ready"
			h.Progress = 0
			h.CallId = nil
			if h.Cfg.Kind == "Cases" then
				CrimeService.ResetCases(h.Id)
			end
			publish(h)
		end
	end)
end

-- Ueberfall starten -----------------------------------------------------------------------------------------------
function CrimeService.StartHeist(player, id)
	local h = heists[id]
	if not h then
		return false, "Unbekannter Ort"
	end
	if lastAction[player] and os.clock() - lastAction[player] < 1 then
		return false, "Bitte kurz warten"
	end
	lastAction[player] = os.clock()
	if h.State == "Active" then
		if h.Cfg.Kind == "Vault" and not inZone(player, h.Zone, 6) then
			return false, "Du musst am Tatort sein"
		end
		local ok, why = addCrew(h, player)
		return ok, ok and "Du machst beim Ueberfall mit" or why
	end
	if h.State == "Cooldown" then
		return false, string.format("Hier ist gerade nichts zu holen (noch %d Min.)", math.ceil(math.max(0, h.CooldownUntilOs - now()) / 60))
	end
	local tier = tierOf(h.Cfg)
	if not tier then
		return false, "Ueberfall derzeit deaktiviert"
	end
	local zone = zoneOf(id)
	if not zone or not inZone(player, zone, 6) then
		return false, "Du musst am Tatort sein"
	end
	local ok, why = eligible(player, h.Cfg)
	if not ok then
		return false, why
	end
	local need = minPolice(tier)
	local have = policeOnDuty()
	if have < need then
		return false, string.format("Zu wenig Polizei im Dienst (%d/%d) - Ueberfall nicht moeglich", have, need)
	end
	-- Start (ab hier kein Yield bis State gesetzt ist)
	h.State = "Active"
	h.Tier = tier
	h.Progress = 0
	h.Empty = 0
	h.Crew, h.Inside, h.Loot, h.Rewarded = {}, {}, {}, {}
	h.Starter = player
	h.StartedAt = now()
	h.Zone = zone
	if h.Cfg.Kind == "Cases" then
		h.CasesLeft = #CrimeService.Cases(id)
	end
	addCrew(h, player)
	local pos = zone.Position
	local call = S.DispatchService.CreateSystemCall(h.Cfg.CallCategory, pos, "Stiller Alarm ausgeloest - bewaffnete Taeter moeglich. Bereich sichern.", 1, { "Police" }, h.Cfg.CallName)
	h.CallId = call and call.Id
	S.RadioService.Broadcast("PD1", string.format("ALLE EINHEITEN: %s - Einsatz #%s, Prioritaet 1", h.Cfg.CallName, tostring(h.CallId)))
	for _, p in ipairs(Players:GetPlayers()) do
		local d = S.DataService.Get(p)
		if d and d.Job.Faction == "Police" and d.Job.OnDuty then
			S.Push(p, "Notify", { Text = "ALARM: " .. h.Cfg.CallName .. " - MDT pruefen (Einsatz #" .. tostring(h.CallId) .. ")", Kind = "error" })
		end
	end
	folder[id]:SetAttribute("Alarm", true)
	folder[id]:SetAttribute("StartedAt", serverNow())
	publish(h)
	pushCrew(h, "Ueberfall gestartet - Alarm ausgeloest!")
	S.Log("Heist", player, nil, id .. ": gestartet (" .. tier.Id .. ")")
	return true, h.Cfg.Name .. ": Ueberfall gestartet!"
end

function CrimeService.Cancel(player)
	for _, h in pairs(heists) do
		if h.State == "Active" and h.Crew[player] then
			if h.Starter == player then
				finish(h, "Cancelled")
				return true, "Ueberfall abgebrochen"
			end
			h.Crew[player] = nil
			S.Push(player, "Heist", { Id = h.Id, State = "Left", Name = h.Cfg.Name })
			publish(h)
			return true, "Du hast den Ueberfall verlassen"
		end
	end
	return false, "Du bist an keinem Ueberfall beteiligt"
end

function CrimeService.IsCrew(player)
	for _, h in pairs(heists) do
		if h.State == "Active" and h.Crew[player] then
			return true
		end
	end
	return false
end

function CrimeService.OnArrest(player)
	for _, h in pairs(heists) do
		if h.Crew[player] then
			h.Crew[player] = nil
			if h.Inside then
				h.Inside[player] = nil
			end
			publish(h)
		end
	end
end

-- Juwelier: Vitrinen ------------------------------------------------------------------------------------------
function CrimeService.Cases(id)
	local list = {}
	for _, c in ipairs(CollectionService:GetTagged("JewelCase")) do
		if c:IsDescendantOf(workspace) then
			table.insert(list, c)
		end
	end
	return list
end

local function setCaseLooted(case, looted)
	case:SetAttribute("Looted", looted)
	case.Transparency = looted and 0.95 or 0.7
	local prompt = case:FindFirstChild("InteractPrompt")
	if prompt then
		prompt.Enabled = not looted
	end
	-- Schmuck unter dieser Vitrine ein-/ausblenden
	local model = case:FindFirstAncestorOfClass("Model")
	if model then
		for _, j in ipairs(model:GetDescendants()) do
			if j:IsA("BasePart") and j.Name == "Jewel" then
				local rel = case.CFrame:PointToObjectSpace(j.Position)
				if math.abs(rel.X) <= case.Size.X / 2 and math.abs(rel.Z) <= case.Size.Z / 2 and rel.Y < 0 and rel.Y > -2 then
					j.Transparency = looted and 1 or 0
				end
			end
		end
	end
end

function CrimeService.ResetCases(id)
	for _, c in ipairs(CrimeService.Cases(id)) do
		setCaseLooted(c, false)
	end
end

function CrimeService.LootCase(player, case)
	if not case or not CollectionService:HasTag(case, "JewelCase") then
		return false, "Ungueltig"
	end
	local h = heists.Jeweler
	if not h then
		return false, "Nicht verfuegbar"
	end
	local r = root(player)
	if not r or (r.Position - case.Position).Magnitude > 9 then
		return false, "Zu weit entfernt"
	end
	if case:GetAttribute("Looted") then
		return false, "Diese Vitrine ist leer"
	end
	-- Mindestabstand zwischen zwei Vitrinen je Spieler (Schutz gegen uebersprungene Haltezeit)
	if lastLoot[player] and os.clock() - lastLoot[player] < h.Cfg.CaseHold - 0.3 then
		return false, "Zu schnell"
	end
	if h.State ~= "Active" then
		local ok, why = CrimeService.StartHeist(player, "Jeweler")
		if not ok then
			return false, why
		end
	elseif not h.Crew[player] then
		local ok, why = addCrew(h, player)
		if not ok then
			return false, why
		end
	end
	lastLoot[player] = os.clock()
	-- Beute je Vitrine serverseitig
	local tier = h.Tier
	local value = Crime.LootValue.StolenJewelry
	local amount = Random.new():NextInteger(tier.Reward[1], tier.Reward[2])
	local units = math.max(1, math.floor(amount / value))
	local d = S.DataService.Get(player)
	units = math.min(units, Items.Defs.StolenJewelry.Stack - (d.Inventory.Items.StolenJewelry or 0))
	if units <= 0 then
		return false, "Kein Platz mehr fuer Beute"
	end
	setCaseLooted(case, true) -- vor dem Hinzufuegen: zweiter gleichzeitiger Versuch scheitert an \"Looted\"
	local ok = S.InventoryService.Add(player, "StolenJewelry", units, "Heist")
	if not ok then
		setCaseLooted(case, false)
		return false, "Kein Platz im Inventar"
	end
	h.Loot[player] = (h.Loot[player] or 0) + units * value
	h.CasesLeft = math.max(0, (h.CasesLeft or 1) - 1)
	ledger(player, "Beute", units * value, h.Cfg.Name)
	publish(h)
	pushCrew(h)
	if h.CasesLeft <= 0 then
		finish(h, "Success", "Alle Vitrinen leer - verschwinde und bring den Schmuck zum Hehler!")
	end
	return true, string.format("Vitrine ausgeraeumt: %dx Schmuck ($%d)", units, units * value)
end

-- Hehler -----------------------------------------------------------------------------------------------------
function CrimeService.Fence(player)
	if lastAction[player] and os.clock() - lastAction[player] < 1 then
		return false, "Bitte kurz warten"
	end
	lastAction[player] = os.clock()
	if not S.InteractionService.NearestOfType(player, "Fence", Crime.Fence.Range) then
		return false, "Kein Hehler in der Naehe"
	end
	local d = S.DataService.Get(player)
	if d.Job.Faction == "Police" and d.Job.OnDuty then
		return false, "Der Hehler redet nicht mit dir."
	end
	-- Stundenlimit
	local t = now()
	local windowStart, earned = d.Crime.CapWindowStart, d.Crime.CapEarned
	if t - windowStart >= 3600 then
		windowStart, earned = t, 0
	end
	local capLeft = Crime.Fence.HourlyCap - earned
	if capLeft <= 0 then
		return false, string.format("Der Hehler nimmt erst in %d Min. wieder etwas an", math.ceil((windowStart + 3600 - t) / 60))
	end
	-- Beute bewerten (nur so viel, wie das Limit zulaesst)
	local sell, payout, value = {}, 0, 0
	for id, unitValue in pairs(Crime.LootValue) do
		local n = d.Inventory.Items[id] or 0
		if n > 0 then
			local net = math.floor(unitValue * (1 - Crime.Fence.Cut))
			local can = math.min(n, math.floor((capLeft - payout) / net))
			if can > 0 then
				sell[id] = can
				payout += can * net
				value += can * unitValue
			end
		end
	end
	if payout <= 0 then
		return false, "Du hast keine Beute dabei (oder das Limit ist erreicht)"
	end
	-- Beute entfernen und Limit buchen in EINEM Mutate, danach Auszahlung ueber EconomyService
	local ok, err = S.DataService.Mutate(player, "Fence", function(dd)
		for id, n in pairs(sell) do
			if (dd.Inventory.Items[id] or 0) < n then
				return false, "Beute hat sich veraendert"
			end
		end
		for id, n in pairs(sell) do
			local rest = dd.Inventory.Items[id] - n
			dd.Inventory.Items[id] = rest > 0 and rest or nil
		end
		dd.Crime.CapWindowStart, dd.Crime.CapEarned = windowStart, earned + payout
		dd.Crime.IllegalEarned += payout
	end)
	if not ok then
		return false, err
	end
	local credited = S.EconomyService.Credit(player, "Cash", payout, "Hehler (illegal)")
	if not credited then
		-- Rueckabwicklung: Beute zurueck
		S.DataService.Mutate(player, "FenceRollback", function(dd)
			for id, n in pairs(sell) do
				dd.Inventory.Items[id] = (dd.Inventory.Items[id] or 0) + n
			end
			dd.Crime.CapEarned -= payout
			dd.Crime.IllegalEarned -= payout
		end)
		return false, "Geschaeft geplatzt"
	end
	ledger(player, "Hehler", payout, string.format("Beute im Wert von $%d verkauft", value))
	S.Log("Fence", player, nil, string.format("$%d (Wert $%d)", payout, value))
	return true, string.format("Der Hehler zahlt dir $%d bar (Wert $%d, %d %% Abschlag)", payout, value, Crime.Fence.Cut * 100)
end

-- Abfragen -----------------------------------------------------------------------------------------------------
-- Polizei: aktive Ueberfaelle (MDT)
function CrimeService.ActiveForPolice()
	local list = {}
	for id, h in pairs(heists) do
		if h.State == "Active" then
			local crew = 0
			for _ in pairs(h.Crew) do
				crew += 1
			end
			table.insert(list, { Id = id, Name = h.Cfg.Name, CallId = h.CallId, Crew = crew, Progress = h.Progress, Duration = h.Tier.Duration, X = h.Zone.Position.X, Z = h.Zone.Position.Z, Since = h.StartedAt })
		end
	end
	return list
end

-- Eigener Status (Spieler): Fahndung + laufender Ueberfall + Beute-Wert
function CrimeService.State(player)
	local d = S.DataService.Get(player)
	local loot = 0
	for id, v in pairs(Crime.LootValue) do
		loot += (d.Inventory.Items[id] or 0) * v
	end
	return { WantedLevel = d.Record.WantedLevel or 0, LootValue = loot, Heists = d.Crime.Heists, IllegalEarned = d.Crime.IllegalEarned, Cooldowns = d.Crime.Cooldowns }
end

-- Vorbereitete Aktivitaeten: spaeter mit CrimeService.Register(\"Shoplifting\", fn) freischalten
function CrimeService.Register(id, handler)
	activities[id] = handler
end

function CrimeService.Activity(player, id, ...)
	local cfg = Crime.Activities[id]
	if not cfg or not cfg.Enabled or not activities[id] then
		return false, "Diese Aktivitaet ist noch nicht verfuegbar"
	end
	return activities[id](player, ...)
end

-- Studio-Tests
function CrimeService._setTestMinPolice(n)
	testMinPolice = n
end
function CrimeService._resetCooldowns()
	for _, h in pairs(heists) do
		if h.State == "Cooldown" then
			h.State = "Ready"
			h.Progress = 0
			if h.Cfg.Kind == "Cases" then
				CrimeService.ResetCases(h.Id)
			end
			publish(h)
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		S.DataService.Mutate(p, "Test", function(d)
			d.Crime.Cooldowns = {}
		end)
	end
end

-- Hauptschleife (1 Hz, nur aktive Ueberfaelle) ------------------------------------------------------------------
local function tick(h)
	local zone = h.Zone
	if not zone or not zone.Parent then
		return finish(h, "Failed", "Tatort nicht verfuegbar")
	end
	-- Anwesenheit / Mitmachen
	local anyInside = false
	h.Inside = {}
	for p in pairs(h.Crew) do
		if not p.Parent or p:GetAttribute("Jailed") then
			h.Crew[p] = nil
		elseif not p:GetAttribute("Cuffed") and p:GetAttribute("Injury") ~= "Unconscious" and inZone(p, zone, 2) then
			h.Inside[p] = true
			anyInside = true
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if not h.Crew[p] and inZone(p, zone, 0) then
			local d = S.DataService.Get(p)
			if d and d.Job.Faction ~= "Police" and not d.Job.OnDuty and h.Cfg.Kind == "Vault" then
				if addCrew(h, p) then
					h.Inside[p] = true
					anyInside = true
				end
			end
		end
	end
	if anyInside then
		h.Empty = 0
		if h.Cfg.Kind == "Vault" then
			h.Progress += 1
		end
	else
		h.Empty += 1
	end
	if h.Cfg.Kind == "Cases" then
		h.Progress += 1 -- Zeitfenster laeuft immer
	end
	publish(h)
	pushCrew(h)
	if h.Cfg.Kind == "Vault" and h.Progress >= h.Tier.Duration then
		return finish(h, "Success")
	end
	if h.Cfg.Kind == "Cases" and h.Progress >= h.Tier.Duration then
		return finish(h, "Success", "Zeit abgelaufen - verschwinde mit der Beute!")
	end
	if h.Empty >= h.Cfg.AbandonSeconds then
		return finish(h, "Failed", "Tatort verlassen - Ueberfall beendet")
	end
end

function CrimeService.Start()
	folder = ReplicatedStorage:FindFirstChild("MiamiCrime") or Instance.new("Folder")
	folder.Name = "MiamiCrime"
	folder.Parent = ReplicatedStorage
	for id, cfg in pairs(Crime.Heists) do
		cfg.Id = id
		local f = folder:FindFirstChild(id) or Instance.new("Configuration")
		f.Name = id
		f:SetAttribute("Name", cfg.Name)
		f.Parent = folder
		heists[id] = { Id = id, Cfg = cfg, State = "Ready", Progress = 0, Crew = {}, Inside = {}, Loot = {}, Rewarded = {} }
		local zone = zoneOf(id)
		if zone then
			f:SetAttribute("X", zone.Position.X)
			f:SetAttribute("Z", zone.Position.Z)
		end
		publish(heists[id])
		f:SetAttribute("Alarm", false)
	end
	CrimeService.ResetCases("Jeweler")
	-- Interaktionen
	S.InteractionService.Register("HeistStart", function(player, inst)
		local ok, msg = CrimeService.StartHeist(player, inst:GetAttribute("HeistId"))
		S.Push(player, "Notify", { Text = tostring(msg), Kind = ok and "warning" or "error" })
	end)
	S.InteractionService.Register("HeistLoot", function(player, inst)
		local ok, msg = CrimeService.LootCase(player, inst)
		S.Push(player, "Notify", { Text = tostring(msg), Kind = ok and "success" or "error" })
	end)
	S.InteractionService.Register("Fence", function(player)
		local d = S.DataService.Get(player)
		local loot = {}
		for id, v in pairs(Crime.LootValue) do
			local n = d.Inventory.Items[id] or 0
			if n > 0 then
				table.insert(loot, { Id = id, Name = Items.Defs[id].Name, Count = n, Value = n * v, Net = math.floor(n * v * (1 - Crime.Fence.Cut)) })
			end
		end
		local t = now()
		local earned = (t - d.Crime.CapWindowStart >= 3600) and 0 or d.Crime.CapEarned
		S.Push(player, "OpenFence", { Loot = loot, Cut = Crime.Fence.Cut, CapLeft = Crime.Fence.HourlyCap - earned })
	end)
	Players.PlayerRemoving:Connect(function(p)
		for _, h in pairs(heists) do
			h.Crew[p] = nil
			if h.Inside then
				h.Inside[p] = nil
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, h in pairs(heists) do
				if h.State == "Active" then
					local ok, err = pcall(tick, h)
					if not ok then
						warn("[Crime] " .. tostring(err))
					end
				end
			end
		end
	end)
end

return CrimeService
