-- JusticeService: Festnahme, Durchsuchung, Eskorte, Haft, Strafzettel, Verwarnungen, Fahndung, Haftbefehle,
-- Personen-/Kennzeichenabfrage und Verkehrskontrolle. Alles serverseitig validiert und protokolliert.
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local PoliceCfg = require(Shared.Config.Police)
local Items = require(Shared.Config.Items)

local JusticeService = {}
local S
local cuffState = {} -- [target] = { Officer, WalkSpeed, JumpHeight }
local escorts = {} -- [target] = { Officer, Weld }
local detained = {} -- [target] = Seat (im Fahrzeug)
local jail = {} -- [target] = { Remaining, Cell }
local lastAction = {}

JusticeService.TestTargets = {} -- nur Studio-Tests: virtuelle Verdaechtige (UserId -> Tabelle)

function JusticeService.Init(services)
	S = services
end

-- Hilfen ---------------------------------------------------------------------------------------
local function resolve(userId)
	if typeof(userId) ~= "number" then
		return nil
	end
	local p = Players:GetPlayerByUserId(userId) or JusticeService.TestTargets[userId]
	return (p and S.DataService.Get(p)) and p or nil
end
JusticeService.Resolve = resolve

local function root(p)
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end
local function hum(p)
	return p.Character and p.Character:FindFirstChildOfClass("Humanoid")
end
local function dist(a, b)
	local ra, rb = root(a), root(b)
	return (ra and rb) and (ra.Position - rb.Position).Magnitude or math.huge
end
local function rpName(p)
	local d = S.DataService.Get(p)
	return d and (d.Character.FirstName .. " " .. d.Character.LastName) or p.Name
end
local function cs(p)
	return (typeof(p) == "Instance" and p:GetAttribute("Callsign")) or p.Name
end
local function throttle(officer)
	if lastAction[officer] and os.clock() - lastAction[officer] < 0.8 then
		return false
	end
	lastAction[officer] = os.clock()
	return true
end
local function filter(text, player, maxLen)
	if text == nil or text == "" then
		return ""
	end
	if typeof(text) ~= "string" or #text > maxLen then
		return nil
	end
	local ok, res = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	return ok and res or nil
end

-- Pruefung fuer Feldaktionen: Beamter im Dienst mit Recht, Ziel in Reichweite, nicht er selbst
local function field(officer, targetId, perm, range)
	if not S.PoliceService.IsOfficer(officer, perm) then
		return nil, "Keine Berechtigung (" .. perm .. ")"
	end
	if not throttle(officer) then
		return nil, "Bitte kurz warten"
	end
	local target = resolve(targetId)
	if not target or target == officer then
		return nil, "Person nicht gefunden"
	end
	if dist(officer, target) > (range or 10) then
		return nil, "Person ist zu weit entfernt"
	end
	return target
end

-- MDT-Zugriff: im Polizeifahrzeug oder an einem Terminal der Wache
function JusticeService.HasMDTAccess(officer)
	if not S.PoliceService.IsOfficer(officer, "Police.MDT") then
		return false
	end
	local v = S.VehicleService.VehicleOf(officer)
	if v and v:GetAttribute("Kind") == "Police" then
		return true
	end
	return S.InteractionService.NearestOfType(officer, "PoliceMDT", 30) ~= nil or S.InteractionService.NearestOfType(officer, "PoliceDispatch", 30) ~= nil
end

-- Handschellen ---------------------------------------------------------------------------------------
local function applyCuffs(target, officer)
	local h = hum(target)
	cuffState[target] = { Officer = officer, WalkSpeed = h and h.WalkSpeed or 16, JumpHeight = h and h.JumpHeight or 7.2 }
	if h then
		h.WalkSpeed = 7
		h.UseJumpPower = false
		h.JumpHeight = 0
		if h.SeatPart and h.SeatPart:IsA("VehicleSeat") then
			h.Sit = false
		end
	end
	target:SetAttribute("Cuffed", true)
end

local function stopEscort(target)
	local e = escorts[target]
	if e then
		if e.Weld then
			e.Weld:Destroy()
		end
		local h = hum(target)
		if h then
			h.PlatformStand = false
		end
		for _, p in ipairs(target.Character and target.Character:GetDescendants() or {}) do
			if p:IsA("BasePart") then
				p.Massless = false
			end
		end
		escorts[target] = nil
		target:SetAttribute("Escorted", nil)
	end
end

local function removeCuffs(target)
	stopEscort(target)
	local st = cuffState[target]
	local h = hum(target)
	if h then
		h.WalkSpeed = st and st.WalkSpeed or 16
		h.JumpHeight = st and st.JumpHeight or 7.2
	end
	cuffState[target] = nil
	detained[target] = nil
	target:SetAttribute("Cuffed", nil)
	target:SetAttribute("Detained", nil)
end

function JusticeService.Cuff(officer, targetId)
	local target, err = field(officer, targetId, "Police.Cuff", 8)
	if not target then
		return false, err
	end
	if target:GetAttribute("Cuffed") then
		return false, "Person ist bereits gefesselt"
	end
	if not S.InventoryService.Has(officer, "Handcuffs") then
		return false, "Keine Handschellen im Inventar"
	end
	applyCuffs(target, officer)
	S.Push(target, "Notify", { Text = "Dir wurden Handschellen angelegt (" .. cs(officer) .. ")", Kind = "warning" })
	S.Log("Cuff", officer, target, "Handschellen angelegt")
	return true, rpName(target) .. " gefesselt"
end

function JusticeService.Uncuff(officer, targetId)
	local target, err = field(officer, targetId, "Police.Cuff", 10)
	if not target then
		return false, err
	end
	if not target:GetAttribute("Cuffed") then
		return false, "Person ist nicht gefesselt"
	end
	removeCuffs(target)
	S.Push(target, "Notify", { Text = "Handschellen wurden abgenommen", Kind = "info" })
	S.Log("Uncuff", officer, target, "Handschellen abgenommen")
	return true, "Handschellen abgenommen"
end

-- Durchsuchen / Beschlagnahmen ----------------------------------------------------------------------
function JusticeService.Search(officer, targetId)
	local target, err = field(officer, targetId, "Police.Search", 8)
	if not target then
		return false, err
	end
	if not target:GetAttribute("Cuffed") then
		return false, "Durchsuchung nur bei gefesselten Personen"
	end
	local d = S.DataService.Get(target)
	local list = {}
	-- Waffen/Munition sind nur ohne gueltigen Waffenschein illegal (Prompt 08: legaler Waffenhandel)
	local licensed = (d.Inventory.Items.WeaponLicense or 0) > 0
	for id, n in pairs(d.Inventory.Items) do
		local def = Items.Defs[id]
		if def then
			table.insert(list, { Id = id, Name = def.Name, Count = n, Illegal = def.Illegal == true or ((def.Category == "Weapons" or def.Category == "Ammo") and not licensed) })
		end
	end
	S.Log("Search", officer, target, string.format("%d Gegenstaende, $%d bar", #list, d.Money.Cash))
	S.Push(target, "Notify", { Text = "Du wirst durchsucht (" .. cs(officer) .. ")", Kind = "warning" })
	return true, nil, { Name = rpName(target), Cash = d.Money.Cash, Items = list, UserId = target.UserId }
end

function JusticeService.Confiscate(officer, targetId, itemId)
	local target, err = field(officer, targetId, "Police.Confiscate", 8)
	if not target then
		return false, err
	end
	local def = typeof(itemId) == "string" and Items.Defs[itemId]
	if not def or not (def.Category == "Weapons" or def.Category == "Ammo" or itemId == "WeaponLicense" or def.Illegal) then
		return false, "Nur Waffen, Munition, Waffenscheine und Beute koennen beschlagnahmt werden"
	end
	local n = S.InventoryService.Count(target, itemId)
	if n == 0 then
		return false, "Gegenstand nicht vorhanden"
	end
	S.InventoryService.Remove(target, itemId, n, "Beschlagnahmt")
	S.Log("Confiscate", officer, target, n .. "x " .. def.Name)
	return true, n .. "x " .. def.Name .. " beschlagnahmt"
end

-- Eskortieren ------------------------------------------------------------------------------------------
function JusticeService.Escort(officer, targetId)
	local target, err = field(officer, targetId, "Police.Escort", 8)
	if not target then
		return false, err
	end
	if escorts[target] then
		stopEscort(target)
		S.Log("Escort", officer, target, "Eskorte beendet")
		return true, "Eskorte beendet"
	end
	if not target:GetAttribute("Cuffed") then
		return false, "Nur gefesselte Personen eskortieren"
	end
	local ro, rt, h = root(officer), root(target), hum(target)
	if not (ro and rt and h) then
		return false, "Nicht moeglich"
	end
	if h.SeatPart then
		h.Sit = false
		task.wait(0.1)
	end
	for _, p in ipairs(target.Character:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Massless = true
		end
	end
	h.PlatformStand = true
	rt.CFrame = ro.CFrame * CFrame.new(1.5, 0, -3)
	local w = Instance.new("WeldConstraint")
	w.Name = "EscortWeld"
	w.Part0, w.Part1 = ro, rt
	w.Parent = rt
	escorts[target] = { Officer = officer, Weld = w }
	target:SetAttribute("Escorted", true)
	S.Log("Escort", officer, target, "Eskorte begonnen")
	return true, "Eskortiere " .. rpName(target)
end

-- In Fahrzeug setzen / herausholen --------------------------------------------------------------------
local function nearestPoliceVehicle(officer, range)
	local ro = root(officer)
	local best, bd
	for _, m in ipairs(S.VehicleService.All()) do
		local ch = m:FindFirstChild("Chassis")
		if ch and m:GetAttribute("Kind") == "Police" and ro then
			local d = (ch.Position - ro.Position).Magnitude
			if d <= range and (not bd or d < bd) then
				best, bd = m, d
			end
		end
	end
	return best
end

function JusticeService.PutInVehicle(officer, targetId)
	local target, err = field(officer, targetId, "Police.Arrest", 12)
	if not target then
		return false, err
	end
	if not target:GetAttribute("Cuffed") then
		return false, "Nur gefesselte Personen"
	end
	local v = nearestPoliceVehicle(officer, 18)
	if not v then
		return false, "Kein Polizeifahrzeug in der Naehe"
	end
	local seat
	for i = 3, 1, -1 do
		local s = v:FindFirstChild("PassengerSeat" .. i)
		if s and not s.Occupant then
			seat = s
			break
		end
	end
	if not seat then
		return false, "Kein freier Sitz"
	end
	stopEscort(target)
	seat:Sit(hum(target))
	detained[target] = seat
	target:SetAttribute("Detained", true)
	S.Log("Vehicle", officer, target, "In Fahrzeug " .. tostring(v:GetAttribute("Plate")) .. " gesetzt")
	return true, rpName(target) .. " ins Fahrzeug gesetzt"
end

function JusticeService.TakeOut(officer, targetId)
	local target = resolve(targetId)
	if not S.PoliceService.IsOfficer(officer, "Police.Arrest") or not target then
		return false, "Nicht moeglich"
	end
	local seat = detained[target]
	if not seat then
		return false, "Person sitzt nicht in einem Polizeifahrzeug"
	end
	if (seat.Position - root(officer).Position).Magnitude > 16 then
		return false, "Zu weit vom Fahrzeug entfernt"
	end
	detained[target] = nil
	target:SetAttribute("Detained", nil)
	-- Sitz serverseitig loesen (Sit=false allein greift bei Spieler-Humanoiden nicht zuverlaessig)
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	local h = hum(target)
	if h then
		h.Sit = false
	end
	task.wait(0.1)
	local rt = root(target)
	if rt then
		-- hinter den Beamten, weg vom Fahrzeug, damit kein Sitz beruehrt wird
		rt.CFrame = root(officer).CFrame * CFrame.new(0, 0, 4)
	end
	S.Log("Vehicle", officer, target, "Aus Fahrzeug geholt")
	return true, "Person aus dem Fahrzeug geholt"
end

-- Haft ---------------------------------------------------------------------------------------------------
local function freeCell()
	local cells = CollectionService:GetTagged("JailCell")
	table.sort(cells, function(a, b)
		return (a:GetAttribute("Cell") or 0) < (b:GetAttribute("Cell") or 0)
	end)
	local used = {}
	for _, j in pairs(jail) do
		used[j.Cell] = (used[j.Cell] or 0) + 1
	end
	local best, bestN
	for _, c in ipairs(cells) do
		local n = used[c] or 0
		if not bestN or n < bestN then
			best, bestN = c, n
		end
	end
	return best
end

local function sendToCell(target)
	local j = jail[target]
	local r = root(target)
	if j and j.Cell and r then
		r.CFrame = j.Cell.CFrame * CFrame.new(math.random(-2, 2), 1, math.random(-2, 2))
	end
end

local function startJail(target, seconds)
	jail[target] = { Remaining = seconds, Cell = freeCell(), Saved = os.clock() }
	target:SetAttribute("Jailed", true)
	target:SetAttribute("JailRemaining", seconds)
	sendToCell(target)
end

local function release(target, reason)
	jail[target] = nil
	target:SetAttribute("Jailed", nil)
	target:SetAttribute("JailRemaining", nil)
	S.DataService.Mutate(target, "JailRelease", function(d)
		d.Record.JailSeconds = 0
	end)
	local out = CollectionService:GetTagged("JailRelease")[1]
	local r = root(target)
	if out and r then
		r.CFrame = out.CFrame * CFrame.new(0, 2, 0)
	end
	S.Push(target, "Notify", { Text = "Du wurdest entlassen" .. (reason and (" (" .. reason .. ")") or ""), Kind = "success" })
end

function JusticeService.Jail(officer, targetId, chargeIds)
	local target, err = field(officer, targetId, "Police.Jail", 12)
	if not target then
		return false, err
	end
	local booking = CollectionService:GetTagged("PoliceBooking")[1]
	if not booking or (booking.Position - root(officer).Position).Magnitude > 30 then
		return false, "Inhaftierung nur im Booking-Bereich der Wache"
	end
	if not target:GetAttribute("Cuffed") then
		return false, "Person muss gefesselt sein"
	end
	if typeof(chargeIds) ~= "table" or #chargeIds < 1 or #chargeIds > PoliceCfg.MaxChargesPerArrest then
		return false, "1 bis " .. PoliceCfg.MaxChargesPerArrest .. " Tatbestaende waehlen"
	end
	local fine, minutes, titles, seen = 0, 0, {}, {}
	for _, id in ipairs(chargeIds) do
		if typeof(id) ~= "string" or seen[id] then
			return false, "Ungueltige Tatbestaende"
		end
		seen[id] = true
		local c
		for _, pc in ipairs(PoliceCfg.PenalCode) do
			if pc.Id == id then
				c = pc
			end
		end
		if not c then
			return false, "Unbekannter Tatbestand " .. id
		end
		fine += c.Fine
		minutes += c.Jail
		table.insert(titles, c.Title)
	end
	minutes = math.min(minutes, PoliceCfg.MaxJailMinutes)
	-- Geldstrafe: Konto, dann Bargeld; Rest wird als offen vermerkt
	local d = S.DataService.Get(target)
	local fromBank = math.min(fine, d.Money.Bank)
	local fromCash = math.min(fine - fromBank, d.Money.Cash)
	if fromBank > 0 then
		S.EconomyService.Charge(target, "Bank", fromBank, "Geldstrafe")
	end
	if fromCash > 0 then
		S.EconomyService.Charge(target, "Cash", fromCash, "Geldstrafe")
	end
	local unpaid = fine - fromBank - fromCash
	local seized = {}
	S.DataService.Mutate(target, "Jail", function(data)
		table.insert(data.Record.Charges, 1, { T = os.time(), Ids = chargeIds, Titles = titles, Fine = fine, Unpaid = unpaid, Jail = minutes, Officer = cs(officer) })
		data.Record.Arrests += 1
		data.Record.Wanted = false
		data.Record.WantedReason = ""
		-- Prompt 09: Fahndungsstufe zuruecksetzen, Beute (illegale Gegenstaende) automatisch beschlagnahmen
		data.Record.WantedLevel = 0
		data.Record.WantedUntil = 0
		for id, n in pairs(data.Inventory.Items) do
			local def = Items.Defs[id]
			if def and def.Illegal and n > 0 then
				table.insert(seized, n .. "x " .. def.Name)
				data.Inventory.Items[id] = nil
			end
		end
		for _, w in ipairs(data.Record.Warrants) do
			w.Active = false
		end
		data.Record.JailSeconds = minutes * 60
	end)
	S.DataService.Mutate(officer, "ArrestStat", function(data)
		data.FactionData.Police.Arrests += 1
	end)
	removeCuffs(target)
	if minutes > 0 then
		startJail(target, minutes * 60)
	end
	S.Push(target, "Notify", { Text = string.format("Festgenommen: %s - Strafe $%d, Haft %d Min.", table.concat(titles, ", "), fine, minutes), Kind = "error" })
	S.Log("Jail", officer, target, string.format("%s | $%d (offen $%d) | %d Min.%s", table.concat(titles, ", "), fine, unpaid, minutes, #seized > 0 and (" | beschlagnahmt: " .. table.concat(seized, ", ")) or ""))
	if S.WantedService then
		S.WantedService.PushState(target)
	end
	if S.CrimeService then
		S.CrimeService.OnArrest(target)
	end
	S.RadioService.Broadcast("PD1", string.format("%s: %s in Gewahrsam (10-15), %d Min. Haft", cs(officer), rpName(target), minutes))
	return true, string.format("%s inhaftiert: $%d, %d Min.", rpName(target), fine, minutes)
end

function JusticeService.Release(officer, targetId)
	if not S.PoliceService.IsOfficer(officer, "Police.Supervisor") then
		return false, "Keine Berechtigung (Police.Supervisor)"
	end
	local target = resolve(targetId)
	if not target or not jail[target] then
		return false, "Person ist nicht in Haft"
	end
	release(target, "vorzeitig durch " .. cs(officer))
	S.Log("Release", officer, target, "Vorzeitige Entlassung")
	return true, "Entlassen"
end

-- Strafzettel / Verwarnung -------------------------------------------------------------------------------
function JusticeService.Cite(officer, targetId, code)
	local target, err = field(officer, targetId, "Police.Cite", 14)
	if not target then
		return false, err
	end
	local v
	for _, tc in ipairs(PoliceCfg.TrafficCode) do
		if tc.Id == code then
			v = tc
		end
	end
	if not v then
		return false, "Unbekannter Verstoss"
	end
	local d = S.DataService.Get(target)
	local paid = false
	if d.Money.Bank >= v.Fine then
		paid = S.EconomyService.Charge(target, "Bank", v.Fine, "Strafzettel " .. v.Id)
	elseif d.Money.Cash >= v.Fine then
		paid = S.EconomyService.Charge(target, "Cash", v.Fine, "Strafzettel " .. v.Id)
	end
	local suspended = false
	S.DataService.Mutate(target, "Citation", function(data)
		table.insert(data.Record.Citations, 1, { T = os.time(), Id = v.Id, Title = v.Title, Fine = v.Fine, Points = v.Points, Paid = paid, Officer = cs(officer) })
		data.Record.LicensePoints += v.Points
		if data.Record.LicensePoints >= PoliceCfg.LicenseSuspendPoints and not data.Record.LicenseSuspended then
			data.Record.LicenseSuspended = true
			suspended = true
		end
	end)
	S.DataService.Mutate(officer, "CitationStat", function(data)
		data.FactionData.Police.Citations += 1
	end)
	S.Push(target, "Notify", { Text = string.format("Strafzettel: %s - $%d%s", v.Title, v.Fine, paid and " (bezahlt)" or " (offen)"), Kind = "warning" })
	if suspended then
		S.Push(target, "Notify", { Text = "Dein Fuehrerschein wurde entzogen (zu viele Punkte)", Kind = "error" })
	end
	S.Log("Citation", officer, target, string.format("%s $%d %s", v.Id, v.Fine, paid and "bezahlt" or "offen"))
	return true, string.format("Strafzettel ausgestellt: %s ($%d)%s", v.Title, v.Fine, suspended and " - Fuehrerschein entzogen" or "")
end

function JusticeService.Warn(officer, targetId, text)
	local target, err = field(officer, targetId, "Police.Cite", 14)
	if not target then
		return false, err
	end
	local note = filter(text, officer, 80)
	if note == nil or note == "" then
		return false, "Grund angeben (max. 80 Zeichen)"
	end
	S.DataService.Mutate(target, "Warning", function(data)
		table.insert(data.Record.Warnings, 1, { T = os.time(), Text = note, Officer = cs(officer) })
	end)
	S.Push(target, "Notify", { Text = "Muendliche Verwarnung: " .. note, Kind = "warning" })
	S.Log("Warning", officer, target, note)
	return true, "Verwarnung erteilt"
end

-- Fahndung / Haftbefehl (ueber MDT) ------------------------------------------------------------------------
function JusticeService.SetWanted(officer, targetId, on, reason)
	if not JusticeService.HasMDTAccess(officer) or not S.JobService.HasPermission(officer, "Police.Wanted") then
		return false, "Keine Berechtigung oder kein MDT-Zugriff"
	end
	local target = resolve(targetId)
	if not target then
		return false, "Person nicht gefunden"
	end
	local why = ""
	if on then
		why = filter(reason, officer, 80)
		if not why or why == "" then
			return false, "Grund angeben (max. 80 Zeichen)"
		end
	end
	-- Fahndung ueber das Stufensystem (Prompt 09): ausschreiben = mind. Stufe 1, aufheben = 0
	if on then
		S.WantedService.Raise(target, 1, why, officer)
	else
		S.WantedService.Clear(target, officer)
	end
	S.Log("Wanted", officer, target, on and ("Fahndung: " .. why) or "Fahndung aufgehoben")
	if on then
		S.RadioService.Broadcast("DISP", string.format("BOLO: %s wird gesucht - %s", rpName(target), why))
	end
	return true, on and "Fahndung ausgeschrieben" or "Fahndung aufgehoben"
end

function JusticeService.IssueWarrant(officer, targetId, chargeIds)
	if not JusticeService.HasMDTAccess(officer) or not S.JobService.HasPermission(officer, "Police.Warrant") then
		return false, "Keine Berechtigung (Police.Warrant) oder kein MDT-Zugriff"
	end
	local target = resolve(targetId)
	if not target then
		return false, "Person nicht gefunden"
	end
	if typeof(chargeIds) ~= "table" or #chargeIds < 1 or #chargeIds > PoliceCfg.MaxChargesPerArrest then
		return false, "Tatbestaende waehlen"
	end
	local titles = {}
	for _, id in ipairs(chargeIds) do
		local found
		for _, pc in ipairs(PoliceCfg.PenalCode) do
			if pc.Id == id then
				found = pc
			end
		end
		if not found then
			return false, "Unbekannter Tatbestand"
		end
		table.insert(titles, found.Title)
	end
	S.DataService.Mutate(target, "Warrant", function(d)
		table.insert(d.Record.Warrants, 1, { T = os.time(), Ids = chargeIds, Titles = titles, Officer = cs(officer), Active = true })
	end)
	S.WantedService.Raise(target, 2, "Haftbefehl: " .. table.concat(titles, ", "), officer)
	S.Log("Warrant", officer, target, table.concat(titles, ", "))
	S.RadioService.Broadcast("DISP", string.format("Haftbefehl gegen %s: %s", rpName(target), table.concat(titles, ", ")))
	return true, "Haftbefehl ausgestellt"
end

-- Abfragen -----------------------------------------------------------------------------------------------
local function summary(p)
	local d = S.DataService.Get(p)
	local active = 0
	for _, w in ipairs(d.Record.Warrants) do
		if w.Active then
			active += 1
		end
	end
	return {
		UserId = p.UserId, Name = rpName(p), Username = p.Name, Wanted = d.Record.Wanted, WantedReason = d.Record.WantedReason,
		WantedLevel = d.Record.WantedLevel or 0,
		Warrants = active, License = d.Record.LicenseSuspended and "Entzogen" or "Gueltig", Points = d.Record.LicensePoints,
		Faction = d.Job.Faction, Jailed = jail[p] ~= nil,
	}
end

function JusticeService.SearchPerson(officer, query)
	if not JusticeService.HasMDTAccess(officer) then
		return false, "Kein MDT-Zugriff (Streifenwagen oder Wache)"
	end
	if typeof(query) ~= "string" or #query < 2 or #query > 30 then
		return false, "Suchbegriff: 2-30 Zeichen"
	end
	local q = query:lower()
	local res = {}
	local pool = Players:GetPlayers()
	for _, t in pairs(JusticeService.TestTargets) do
		table.insert(pool, t)
	end
	for _, p in ipairs(pool) do
		local d = S.DataService.Get(p)
		if d and d.Character.Created then
			local name = (d.Character.FirstName .. " " .. d.Character.LastName):lower()
			if name:find(q, 1, true) or p.Name:lower():find(q, 1, true) then
				table.insert(res, summary(p))
			end
		end
		if #res >= 10 then
			break
		end
	end
	S.Log("MDT", officer, nil, "Personensuche: " .. query)
	return true, nil, res
end

function JusticeService.PersonDetail(officer, targetId)
	if not JusticeService.HasMDTAccess(officer) then
		return false, "Kein MDT-Zugriff"
	end
	local target = resolve(targetId)
	if not target then
		return false, "Person nicht gefunden (nur anwesende Personen)"
	end
	local d = S.DataService.Get(target)
	local s = summary(target)
	s.BirthYear = d.Character.BirthYear
	s.Gender = d.Character.Gender
	s.Charges = d.Record.Charges
	s.Citations = d.Record.Citations
	s.Warnings = d.Record.Warnings
	s.WarrantList = d.Record.Warrants
	s.Arrests = d.Record.Arrests
	s.JailRemaining = jail[target] and math.floor(jail[target].Remaining) or 0
	S.Log("MDT", officer, target, "Akte abgerufen")
	return true, nil, s
end

function JusticeService.PlateLookup(officer, plate)
	if not JusticeService.HasMDTAccess(officer) then
		return false, "Kein MDT-Zugriff"
	end
	local r = S.VehicleService.Lookup(plate)
	if not r then
		return false, "Kennzeichen nicht gefunden"
	end
	local owner = resolve(r.OwnerUserId)
	local d = owner and S.DataService.Get(owner)
	S.Log("MDT", officer, nil, "Kennzeichen: " .. tostring(plate))
	return true, nil, {
		Plate = r.Plate or r.Model:GetAttribute("Plate"), Type = (r.Model and r.Model:GetAttribute("DisplayName")) or r.Type, Owner = r.OwnerName, Kind = r.Kind,
		Status = r.Status, -- Prompt 10: "Im Strassenverkehr" | "In der Garage"
		Registered = r.Registered and "Zugelassen" or "Nicht zugelassen",
		OwnerLicense = d and (d.Record.LicenseSuspended and "Entzogen" or "Gueltig") or "Unbekannt",
		OwnerWanted = d and d.Record.Wanted or false, OwnerId = r.OwnerUserId,
	}
end

-- Verkehrskontrolle: Fahrzeug vor dem Streifenwagen anhalten lassen
-- Fahrer eines Fahrzeugs; in Studio auch die Test-Person (NPC, Attribut TestTargetId)
local function driverOf(m)
	local d = S.VehicleService.DriverOf(m)
	if d then
		return d
	end
	local seat = m:FindFirstChild("DriverSeat")
	local char = seat and seat.Occupant and seat.Occupant.Parent
	local id = char and char:GetAttribute("TestTargetId")
	return id and resolve(id) or nil
end

function JusticeService.TrafficStop(officer)
	if not S.PoliceService.IsOfficer(officer, "Police.TrafficStop") then
		return false, "Keine Berechtigung (Police.TrafficStop)"
	end
	if not throttle(officer) then
		return false, "Bitte kurz warten"
	end
	local v, isDriver = S.VehicleService.VehicleOf(officer)
	if not v or v:GetAttribute("Kind") ~= "Police" then
		return false, "Nur aus einem Polizeifahrzeug"
	end
	local ch = v:FindFirstChild("Chassis")
	local best, bd
	for _, m in ipairs(S.VehicleService.All()) do
		local c = m:FindFirstChild("Chassis")
		local driver = driverOf(m)
		if m ~= v and c and driver and driver ~= officer then
			local off = c.Position - ch.Position
			local d = off.Magnitude
			if d < 90 and off.Unit:Dot(ch.CFrame.LookVector) > 0.4 and (not bd or d < bd) then
				best, bd = m, d
			end
		end
	end
	local _ = isDriver
	if not best then
		return false, "Kein Fahrzeug vor dir"
	end
	local driver = driverOf(best)
	best:SetAttribute("StopRequested", os.time())
	S.Push(driver, "TrafficStop", { Callsign = cs(officer), Plate = best:GetAttribute("Plate") })
	local _, _, info = JusticeService.PlateLookup(officer, best:GetAttribute("Plate"))
	S.Log("TrafficStop", officer, driver, tostring(best:GetAttribute("Plate")))
	S.RadioService.Broadcast("PD1", string.format("%s: Verkehrskontrolle %s (%s)", cs(officer), tostring(best:GetAttribute("Plate")), best:GetAttribute("VehicleType") or "Fahrzeug"))
	return true, "Anhaltesignal an " .. tostring(best:GetAttribute("Plate")), { Vehicle = info, DriverId = driver.UserId, DriverName = rpName(driver) }
end

-- Info fuer das Interaktionsmenue
function JusticeService.TargetState(target)
	return { Cuffed = target:GetAttribute("Cuffed") == true, Escorted = escorts[target] ~= nil, Detained = detained[target] ~= nil, Jailed = jail[target] ~= nil }
end

-- Alle Massnahmen eines Beamten aufloesen (Dienstende, Verlassen)
function JusticeService.ReleaseAllBy(officer)
	for t, e in pairs(escorts) do
		if e.Officer == officer then
			stopEscort(t)
		end
	end
end

function JusticeService.Start()
	-- Haftzeit herunterzaehlen, Ausbruch verhindern, regelmaessig speichern
	task.spawn(function()
		while true do
			task.wait(1)
			for target, j in pairs(jail) do
				if (typeof(target) == "Instance" and not target.Parent) then
					jail[target] = nil
				else
					j.Remaining -= 1
					target:SetAttribute("JailRemaining", math.max(0, math.floor(j.Remaining)))
					local r = root(target)
					if r and j.Cell and (r.Position - j.Cell.Position).Magnitude > 16 then
						sendToCell(target)
					end
					if os.clock() - j.Saved > 10 then
						j.Saved = os.clock()
						S.DataService.Mutate(target, "JailTick", function(d)
							d.Record.JailSeconds = math.max(0, math.floor(j.Remaining))
						end)
					end
					if j.Remaining <= 0 then
						release(target, "Haftzeit verbuesst")
					end
				end
			end
		end
	end)
	-- Festgehaltene Personen bleiben im Fahrzeug sitzen
	RunService.Heartbeat:Connect(function()
		for target, seat in pairs(detained) do
			local h = hum(target)
			if h and seat.Parent and h.SeatPart ~= seat and not seat.Occupant then
				seat:Sit(h)
			elseif not seat.Parent then
				detained[target] = nil
			end
		end
	end)
	-- Haft nach Neubeitritt fortsetzen, Zustaende bei Tod/Respawn aufloesen
	S.DataService.ProfileLoaded:Connect(function(player, data)
		if data.Record.JailSeconds > 0 then
			task.delay(2, function()
				if player.Parent then
					startJail(player, data.Record.JailSeconds)
				end
			end)
		end
	end)
	local function hook(player)
		player.CharacterAdded:Connect(function()
			if cuffState[player] then
				removeCuffs(player)
			end
			if jail[player] then
				task.wait(1)
				sendToCell(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		JusticeService.ReleaseAllBy(p)
		stopEscort(p)
		cuffState[p], detained[p], lastAction[p] = nil, nil, nil
		local j = jail[p]
		if j then
			-- Restzeit wurde ueber JailTick/Mutate gespeichert; letzter Stand:
			S.DataService.Mutate(p, "JailTick", function(d)
				d.Record.JailSeconds = math.max(0, math.floor(j.Remaining))
			end)
			jail[p] = nil
		end
	end)
	table.insert(S.DataService.BeforeRelease, function(p)
		local j = jail[p]
		if j then
			S.DataService.Mutate(p, "JailTick", function(d)
				d.Record.JailSeconds = math.max(0, math.floor(j.Remaining))
			end)
		end
	end)
end

return JusticeService
