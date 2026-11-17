-- BusinessService (Prompt 11): Unternehmen besitzen, verwalten, Mitarbeiter beschaeftigen.
-- * Jedes Unternehmen ist ein Datensatz im DataStore "MiamiState_Business_v1" (Schluessel = Unternehmens-Id).
--   Besitzwechsel, Personal und Einstellungen laufen ueber UpdateAsync (atomar, serveruebergreifend eindeutig).
-- * Umsaetze/Ausgaben werden je Server gesammelt und alle 30 s als Differenz verbucht (keine Doppelbuchung).
-- * Laufkundschaft-Umsatz entsteht nur pro eingestempelter, aktiver Person vor Ort (kein AFK-/Mehrserver-Einkommen).
-- * Betriebskosten werden stundenweise atomar abgebucht (LastUpkeep), auch fuer Zeiten ohne Spieler (max. 72 h).
-- Welt: Interactable "BusinessOffice" (Attribut BusinessId) am Standort; Kassen/Tueren tragen Attribut BusinessId.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local Cfg = require(Shared.Config.Work)

local B = {}
local S
local store
local cache = {} -- [id] = record
local pending = {} -- [id] = { Account, Revenue, Expenses, Log = {} }
local lastActive = {} -- [player] = os.clock() der letzten Bewegung
local lastPos = {}
local mem = {} -- Ersatzspeicher, falls der DataStore nicht erreichbar ist

local function defaults(def)
	local t = Cfg.BusinessTypes[def.Type]
	return {
		Owner = 0, OwnerName = "", Bought = 0, Account = 0, Revenue = 0, Expenses = 0,
		Employees = {}, Applications = {}, Open = true, OpenHour = t.NightOnly and 20 or 8, CloseHour = t.NightOnly and 5 or 23,
		PriceFactor = 1, EntryFee = t.EntryFee and 20 or 0, LastUpkeep = os.time(), Log = {},
	}
end

function B.Init(services)
	S = services
end

-- Speicher ------------------------------------------------------------------------------------------
local function update(id, fn)
	local def = Cfg.BusinessById[id]
	local result, err
	local function apply(old)
		local rec = old or defaults(def)
		for k, v in pairs(defaults(def)) do
			if rec[k] == nil then
				rec[k] = v
			end
		end
		local ok, res, msg = pcall(fn, rec)
		if not ok then
			err = "Interner Fehler"
			warn("[Business] " .. tostring(res))
			return nil
		end
		if res == false then
			err = msg
			return nil
		end
		result = rec
		return rec
	end
	if store then
		local ok, e = pcall(function()
			store:UpdateAsync(id, apply)
		end)
		if not ok then
			warn("[Business] UpdateAsync " .. id .. ": " .. tostring(e))
			return nil, "Speicher nicht erreichbar - spaeter erneut"
		end
	else
		mem[id] = apply(mem[id]) or mem[id]
	end
	if result then
		cache[id] = result
	end
	return result, err
end

local function load(id)
	local rec
	if store then
		local ok, r = pcall(function()
			return store:GetAsync(id)
		end)
		if ok then
			rec = r
		end
	else
		rec = mem[id]
	end
	local def = Cfg.BusinessById[id]
	rec = rec or defaults(def)
	for k, v in pairs(defaults(def)) do
		if rec[k] == nil then
			rec[k] = v
		end
	end
	cache[id] = rec
	return rec
end

local function addLog(rec, text, amount)
	table.insert(rec.Log, 1, { T = os.time(), X = text, A = amount or 0 })
	while #rec.Log > 30 do
		table.remove(rec.Log)
	end
end

local function queue(id, account, revenue, expense, text)
	local p = pending[id] or { Account = 0, Revenue = 0, Expenses = 0, Log = {} }
	pending[id] = p
	p.Account += account
	p.Revenue += revenue or 0
	p.Expenses += expense or 0
	if text then
		table.insert(p.Log, { text, account })
		if #p.Log > 10 then
			table.remove(p.Log, 1)
		end
	end
end

local function account(id)
	local rec = cache[id]
	local p = pending[id]
	return (rec and rec.Account or 0) + (p and p.Account or 0)
end

-- Rechte --------------------------------------------------------------------------------------------
local function roleOf(rec, userId)
	if rec.Owner == userId and userId ~= 0 then
		return 6
	end
	local e = rec.Employees[tostring(userId)]
	return e and e.Position or 0
end
B.RoleOf = roleOf

local function employerOf(userId)
	for id, rec in pairs(cache) do
		if rec.Employees[tostring(userId)] then
			return id, rec
		end
	end
	return nil
end

local function ownedCount(userId)
	local n = 0
	for _, rec in pairs(cache) do
		if rec.Owner == userId then
			n += 1
		end
	end
	return n
end

local function rpName(player)
	local d = S.DataService.Get(player)
	return d and d.Character.Created and (d.Character.FirstName .. " " .. d.Character.LastName) or player.Name
end

local function officeOf(id)
	for _, inst in ipairs(CollectionService:GetTagged("Interactable")) do
		if inst:GetAttribute("InteractType") == "BusinessOffice" and inst:GetAttribute("BusinessId") == id and inst:IsDescendantOf(workspace) then
			return inst
		end
	end
	return nil
end
local function officePos(id)
	local o = officeOf(id)
	local r = o and S.InteractionService.RootOf(o)
	local def = Cfg.BusinessById[id]
	return r and r.Position or Vector3.new(def.X, 0, def.Z)
end
local function nearOffice(player, id, range)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - officePos(id)).Magnitude <= (range or 25)
end

local function isOpenNow(rec, def)
	if not rec.Open then
		return false
	end
	local h = math.floor(Lighting.ClockTime)
	local o, c = rec.OpenHour, rec.CloseHour
	if o == c then
		return true
	end
	if o < c then
		return h >= o and h < c
	end
	return h >= o or h < c
end

local function status(id)
	local rec, def = cache[id], Cfg.BusinessById[id]
	if not rec or rec.Owner == 0 then
		return "Zu verkaufen"
	end
	if account(id) < 0 then
		return "Verschuldet"
	end
	return isOpenNow(rec, def) and "Geoeffnet" or "Geschlossen"
end

-- Umsaetze aus bestehenden Systemen -------------------------------------------------------------------
local function credit(id, amount, text)
	local rec = cache[id]
	if not rec or rec.Owner == 0 or amount <= 0 then
		return
	end
	amount = math.floor(amount + 0.5)
	if amount > 0 then
		queue(id, amount, amount, 0, text)
	end
end

-- Kasse/Tuer mit Attribut BusinessId (Shop-Verkauf, Club-Eintritt)
function B.OnSale(inst, total, label, fullAmount)
	local id = inst and inst:GetAttribute("BusinessId")
	local def = id and Cfg.BusinessById[id]
	if not def then
		return
	end
	local margin = fullAmount and 1 or Cfg.BusinessTypes[def.Type].Margin
	credit(id, total * margin, label or "Verkauf")
end
function B.OnDealer(dealerId, price)
	for _, def in ipairs(Cfg.Businesses) do
		if def.Link.Dealer == dealerId then
			credit(def.Id, price * Cfg.BusinessTypes.Dealer.Margin, "Fahrzeugverkauf")
		end
	end
end
function B.OnProperty(amount)
	for _, def in ipairs(Cfg.Businesses) do
		if def.Link.Property then
			credit(def.Id, amount * Cfg.BusinessTypes.RealEstate.Margin, "Provision Immobilie")
		end
	end
end
function B.OnWorkshopIncome(amount)
	for _, def in ipairs(Cfg.Businesses) do
		if def.Link.Workshop then
			credit(def.Id, amount, "Werkstatt")
		end
	end
end
function B.OnTuning(price)
	B.OnWorkshopIncome(price * Cfg.BusinessTypes.Workshop.Margin)
end
function B.OnJob(jobId, amount)
	for _, def in ipairs(Cfg.Businesses) do
		if def.Link.Job == jobId then
			credit(def.Id, amount * Cfg.BusinessTypes.Logistics.Margin, "Auftragsgebuehr")
		end
	end
end
-- Club-Eintritt (Venue-Tuer): Gebuehr des Besitzers
function B.EntryFee(inst)
	local id = inst and inst:GetAttribute("BusinessId")
	local rec = id and cache[id]
	if not rec or rec.Owner == 0 then
		return 0
	end
	return math.clamp(rec.EntryFee or 0, 0, 500)
end
-- Preisfaktor fuer Kassen (nur Typen mit Prices)
function B.PriceFactor(inst)
	local id = inst and inst:GetAttribute("BusinessId")
	local rec, def = id and cache[id], id and Cfg.BusinessById[id]
	if not rec or rec.Owner == 0 or not Cfg.BusinessTypes[def.Type].Prices then
		return 1
	end
	return math.clamp(rec.PriceFactor or 1, 0.8, 1.5)
end
-- Arbeitgeber fuer einen Beruf (Mitarbeiter eines Lieferunternehmens bekommen Bonus)
function B.EmployerFor(player, jobId)
	local id = employerOf(player.UserId)
	return id and Cfg.BusinessById[id].Link.Job == jobId and id or nil
end
function B.CanInvoice(player)
	local id = player:GetAttribute("BizDuty")
	return id ~= nil and Cfg.BusinessById[id] and Cfg.BusinessById[id].Type == "Workshop"
end

-- Aktionen ------------------------------------------------------------------------------------------
local function summary(id, viewer)
	local def, rec = Cfg.BusinessById[id], cache[id] or load(id)
	local t = Cfg.BusinessTypes[def.Type]
	local role = viewer and roleOf(rec, viewer.UserId) or 0
	local pos = officePos(id)
	local out = {
		Id = id, Name = def.Name, Type = def.Type, TypeName = t.Name, Price = def.Price, Owner = rec.OwnerName, Owned = rec.Owner ~= 0,
		Status = status(id), Value = math.floor(def.Price * Cfg.SellFactor) + math.max(0, account(id)), Upkeep = t.Upkeep,
		Employees = 0, Role = role, X = pos.X, Y = pos.Y, Z = pos.Z, Hours = string.format("%02d:00 - %02d:00", rec.OpenHour, rec.CloseHour),
		Prices = t.Prices == true, EntryFeeSupported = t.EntryFee == true, Hiring = rec.Owner ~= 0 and true or false,
	}
	for _ in pairs(rec.Employees) do
		out.Employees += 1
	end
	if role >= Cfg.PositionRights.ViewFinances then
		out.Account = account(id)
		out.Revenue = rec.Revenue + (pending[id] and pending[id].Revenue or 0)
		out.Expenses = rec.Expenses + (pending[id] and pending[id].Expenses or 0)
		out.Log = rec.Log
		out.PriceFactor = rec.PriceFactor
		out.EntryFee = rec.EntryFee
		out.Open = rec.Open
		out.OpenHour, out.CloseHour = rec.OpenHour, rec.CloseHour
		out.Staff = {}
		for uid, e in pairs(rec.Employees) do
			local p = Players:GetPlayerByUserId(tonumber(uid))
			table.insert(out.Staff, { UserId = tonumber(uid), Name = e.Name, Position = e.Position, PositionName = Cfg.Positions[e.Position].Name, Salary = e.Salary, Hired = e.Hired, Online = p ~= nil, OnDuty = p ~= nil and p:GetAttribute("BizDuty") == id })
		end
		out.Applications = {}
		for uid, a in pairs(rec.Applications) do
			table.insert(out.Applications, { UserId = tonumber(uid), Name = a.Name, T = a.T, Level = a.Level })
		end
	end
	return out
end

function B.List(player)
	local list = {}
	for _, def in ipairs(Cfg.Businesses) do
		table.insert(list, summary(def.Id, player))
	end
	local emp, rec = employerOf(player.UserId)
	return true, nil, { Businesses = list, Employer = emp, EmployerName = emp and Cfg.BusinessById[emp].Name, Position = emp and rec.Employees[tostring(player.UserId)].Position, OnDuty = player:GetAttribute("BizDuty"), MinLevel = Cfg.BusinessMinLevel, Positions = Cfg.Positions, Rights = Cfg.PositionRights }
end

function B.Buy(player, id, txId)
	local def = Cfg.BusinessById[id]
	if not def then
		return false, "Unbekanntes Unternehmen"
	end
	if not nearOffice(player, id, 30) then
		return false, "Kauf nur vor Ort (Buero / Eingang) - Standort auf der Karte markieren"
	end
	if S.WorkService.Level(player) < Cfg.BusinessMinLevel then
		return false, "Unternehmen ab Karrierestufe " .. Cfg.BusinessMinLevel
	end
	if ownedCount(player.UserId) >= 2 then
		return false, "Maximal 2 Unternehmen"
	end
	local d = S.DataService.Get(player)
	if d.Money.Bank < def.Price then
		return false, "Kontostand nicht ausreichend (" .. S.Format.money(def.Price) .. ")"
	end
	if not S.EconomyService.ClaimTx(player, txId) then
		return false, "Vorgang bereits ausgefuehrt"
	end
	-- erst Eigentum atomar sichern, dann bezahlen (bei Zahlungsfehler zurueckgeben)
	local rec, err = update(id, function(r)
		if r.Owner ~= 0 then
			return false, "Bereits verkauft an " .. r.OwnerName
		end
		r.Owner, r.OwnerName, r.Bought = player.UserId, rpName(player), os.time()
		r.Account, r.Revenue, r.Expenses, r.LastUpkeep = 0, 0, 0, os.time()
		r.Employees, r.Applications = {}, {}
		addLog(r, "Uebernahme durch " .. rpName(player), 0)
	end)
	if not rec then
		return false, err
	end
	local ok, cerr = S.EconomyService.Charge(player, "Bank", def.Price, "Unternehmenskauf " .. def.Name)
	if not ok then
		update(id, function(r)
			if r.Owner == player.UserId then
				r.Owner, r.OwnerName = 0, ""
			end
		end)
		return false, cerr
	end
	pending[id] = nil
	S.Log("Business", player, nil, string.format("Kauf %s fuer $%d", def.Name, def.Price))
	S.WorkService.AddXP(player, 150, "Unternehmen gekauft")
	return true, "Glueckwunsch - du bist Inhaber von " .. def.Name
end

function B.Sell(player, id)
	local def = Cfg.BusinessById[id]
	local rec = cache[id]
	if not def or not rec or rec.Owner ~= player.UserId then
		return false, "Nicht dein Unternehmen"
	end
	B.Flush(id)
	local payout
	local r, err = update(id, function(x)
		if x.Owner ~= player.UserId then
			return false, "Nicht dein Unternehmen"
		end
		payout = math.floor(def.Price * Cfg.SellFactor) + (x.Account or 0)
		local fresh = defaults(def)
		for k, v in pairs(fresh) do
			x[k] = v
		end
		addLog(x, "Verkauf an die Stadt", 0)
	end)
	if not r then
		return false, err
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("BizDuty") == id then
			p:SetAttribute("BizDuty", nil)
		end
	end
	if payout > 0 then
		S.EconomyService.Credit(player, "Bank", math.min(payout, 10_000_000), "Verkauf " .. def.Name)
	elseif payout < 0 then
		S.EconomyService.Charge(player, "Bank", math.min(-payout, S.DataService.Get(player).Money.Bank), "Schulden " .. def.Name)
	end
	S.Log("Business", player, nil, string.format("Verkauf %s, Auszahlung $%d", def.Name, payout))
	return true, string.format("%s verkauft - Auszahlung %s", def.Name, S.Format.money(payout))
end

function B.Money(player, id, amount, deposit, txId)
	local rec = cache[id]
	if not rec then
		return false, "Unbekannt"
	end
	local role = roleOf(rec, player.UserId)
	if (deposit and role < 5) or (not deposit and role < 6) then
		return false, deposit and "Einzahlen: Inhaber oder Manager" or "Auszahlen nur durch den Inhaber"
	end
	if not S.EconomyService.ValidAmount(amount) then
		return false, "Ungueltiger Betrag"
	end
	if not S.EconomyService.ClaimTx(player, txId) then
		return false, "Vorgang bereits ausgefuehrt"
	end
	B.Flush(id)
	if deposit then
		local ok, err = S.EconomyService.Charge(player, "Bank", amount, "Einlage " .. Cfg.BusinessById[id].Name)
		if not ok then
			return false, err
		end
		update(id, function(r)
			r.Account += amount
			addLog(r, "Einlage " .. rpName(player), amount)
		end)
		return true, S.Format.money(amount) .. " eingezahlt"
	end
	local r, err = update(id, function(x)
		if x.Account < amount then
			return false, "Unternehmenskonto nicht ausreichend"
		end
		x.Account -= amount
		addLog(x, "Entnahme Inhaber", -amount)
	end)
	if not r then
		return false, err
	end
	S.EconomyService.Credit(player, "Bank", amount, "Entnahme " .. Cfg.BusinessById[id].Name)
	return true, S.Format.money(amount) .. " auf dein Bankkonto"
end

function B.Settings(player, id, p)
	local rec, def = cache[id], Cfg.BusinessById[id]
	if not rec or roleOf(rec, player.UserId) < Cfg.PositionRights.Prices then
		return false, "Keine Berechtigung"
	end
	local t = Cfg.BusinessTypes[def.Type]
	local _, err = update(id, function(r)
		if typeof(p.Open) == "boolean" then
			r.Open = p.Open
		end
		if typeof(p.OpenHour) == "number" and p.OpenHour % 1 == 0 and p.OpenHour >= 0 and p.OpenHour < 24 then
			r.OpenHour = p.OpenHour
		end
		if typeof(p.CloseHour) == "number" and p.CloseHour % 1 == 0 and p.CloseHour >= 0 and p.CloseHour < 24 then
			r.CloseHour = p.CloseHour
		end
		if t.Prices and typeof(p.PriceFactor) == "number" then
			r.PriceFactor = math.clamp(math.floor(p.PriceFactor * 20 + 0.5) / 20, 0.8, 1.5)
		end
		if t.EntryFee and typeof(p.EntryFee) == "number" then
			r.EntryFee = math.clamp(math.floor(p.EntryFee), 0, 500)
		end
	end)
	if err then
		return false, err
	end
	return true, "Einstellungen gespeichert"
end

function B.Apply(player, id)
	local rec = cache[id]
	if not rec or rec.Owner == 0 then
		return false, "Unternehmen hat keinen Inhaber"
	end
	if rec.Owner == player.UserId or employerOf(player.UserId) then
		return false, "Du bist bereits angestellt (zuerst kuendigen)"
	end
	local _, err = update(id, function(r)
		local n = 0
		for _ in pairs(r.Applications) do
			n += 1
		end
		if n >= 15 then
			return false, "Keine weiteren Bewerbungen moeglich"
		end
		r.Applications[tostring(player.UserId)] = { Name = rpName(player), T = os.time(), Level = S.WorkService.Level(player) }
	end)
	if err then
		return false, err
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if roleOf(rec, p.UserId) >= Cfg.PositionRights.Hire then
			S.Push(p, "Notify", { Text = string.format("Neue Bewerbung bei %s: %s", Cfg.BusinessById[id].Name, rpName(player)), Kind = "info" })
		end
	end
	return true, "Bewerbung bei " .. Cfg.BusinessById[id].Name .. " abgeschickt"
end

function B.Staff(player, p)
	local id = p.Id
	local rec, def = cache[id], Cfg.BusinessById[id]
	if not rec then
		return false, "Unbekannt"
	end
	local role = roleOf(rec, player.UserId)
	local target = typeof(p.Target) == "number" and p.Target or 0
	local key = tostring(target)
	local action = p.Do
	local targetPlayer = Players:GetPlayerByUserId(target)
	if action == "Hire" then
		local pos = typeof(p.Position) == "number" and p.Position or 1
		if role < Cfg.PositionRights.Hire or (role < 6 and pos >= role) or (role < 5 and pos > 2) then
			return false, "Keine Berechtigung fuer diese Position"
		end
		if not Cfg.Positions[pos] then
			return false, "Ungueltige Position"
		end
		local other = employerOf(target)
		if other and other ~= id then
			return false, "Bereits bei " .. Cfg.BusinessById[other].Name .. " angestellt"
		end
	elseif action == "Fire" or action == "Promote" or action == "Salary" then
		local e = rec.Employees[key]
		if not e then
			return false, "Kein Mitarbeiter"
		end
		if role < 6 and (role < Cfg.PositionRights.Promote or e.Position >= role) then
			return false, "Keine Berechtigung"
		end
	elseif action == "Reject" then
		if role < Cfg.PositionRights.Hire then
			return false, "Keine Berechtigung"
		end
	else
		return false, "Unbekannte Aktion"
	end
	if action == "Promote" then
		local pos = p.Position
		local cfgPos = typeof(pos) == "number" and Cfg.Positions[pos]
		if not cfgPos or (role < 6 and pos >= role) then
			return false, "Ungueltige Position"
		end
		if cfgPos.MinLevel then
			if not targetPlayer then
				return false, "Befoerderung zu " .. cfgPos.Name .. " nur, wenn der Mitarbeiter online ist (Stufenpruefung)"
			end
			if S.WorkService.Level(targetPlayer) < cfgPos.MinLevel then
				return false, cfgPos.Name .. " erfordert Karrierestufe " .. cfgPos.MinLevel
			end
		end
	end
	local msg
	local _, err = update(id, function(r)
		if action == "Hire" then
			local app = r.Applications[key]
			if not app then
				return false, "Keine Bewerbung dieses Spielers"
			end
			local n = 0
			for _ in pairs(r.Employees) do
				n += 1
			end
			if n >= Cfg.MaxEmployees then
				return false, "Maximal " .. Cfg.MaxEmployees .. " Mitarbeiter"
			end
			local pos = p.Position or 1
			r.Employees[key] = { Name = app.Name, Position = pos, Salary = math.floor(Cfg.Positions[pos].MaxSalary * 0.6), Hired = os.time() }
			r.Applications[key] = nil
			addLog(r, "Eingestellt: " .. app.Name, 0)
			msg = app.Name .. " eingestellt als " .. Cfg.Positions[pos].Name
		elseif action == "Reject" then
			r.Applications[key] = nil
			msg = "Bewerbung abgelehnt"
		elseif action == "Fire" then
			local e = r.Employees[key]
			r.Employees[key] = nil
			addLog(r, "Entlassen: " .. e.Name, 0)
			msg = e.Name .. " entlassen"
		elseif action == "Promote" then
			local e = r.Employees[key]
			e.Position = p.Position
			e.Salary = math.min(e.Salary, Cfg.Positions[p.Position].MaxSalary)
			addLog(r, e.Name .. " -> " .. Cfg.Positions[p.Position].Name, 0)
			msg = e.Name .. " ist jetzt " .. Cfg.Positions[p.Position].Name
		elseif action == "Salary" then
			local e = r.Employees[key]
			local max = Cfg.Positions[e.Position].MaxSalary
			if typeof(p.Salary) ~= "number" or p.Salary % 1 ~= 0 or p.Salary < 0 or p.Salary > max then
				return false, "Gehalt $0 - " .. S.Format.money(max) .. " pro 10 Min"
			end
			e.Salary = p.Salary
			msg = "Gehalt von " .. e.Name .. ": " .. S.Format.money(p.Salary) .. " / 10 Min"
		end
	end)
	if err then
		return false, err
	end
	if targetPlayer and (action == "Hire" or action == "Fire" or action == "Promote") then
		if action == "Fire" and targetPlayer:GetAttribute("BizDuty") == id then
			targetPlayer:SetAttribute("BizDuty", nil)
		end
		S.Push(targetPlayer, "Notify", { Text = def.Name .. ": " .. msg, Kind = action == "Fire" and "warning" or "success" })
	end
	return true, msg
end

function B.Resign(player)
	local id = employerOf(player.UserId)
	if not id then
		return false, "Du bist nirgends angestellt"
	end
	update(id, function(r)
		local e = r.Employees[tostring(player.UserId)]
		if e then
			addLog(r, "Gekuendigt: " .. e.Name, 0)
		end
		r.Employees[tostring(player.UserId)] = nil
	end)
	player:SetAttribute("BizDuty", nil)
	return true, "Du hast bei " .. Cfg.BusinessById[id].Name .. " gekuendigt"
end

function B.Clock(player, id, on)
	local rec = cache[id]
	if not rec or roleOf(rec, player.UserId) == 0 then
		return false, "Du arbeitest nicht fuer dieses Unternehmen"
	end
	if on then
		if not nearOffice(player, id, 60) then
			return false, "Einstempeln nur vor Ort"
		end
		player:SetAttribute("BizDuty", id)
		player:SetAttribute("BizDutySince", os.time())
		return true, "Eingestempelt bei " .. Cfg.BusinessById[id].Name
	end
	player:SetAttribute("BizDuty", nil)
	return true, "Ausgestempelt"
end

-- Takt: Laufkundschaft, Gehaelter, Betriebskosten, Speichern ------------------------------------------
local function isActive(player)
	return lastActive[player] and os.clock() - lastActive[player] < 120
end
local function atWork(player, id)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	if (root.Position - officePos(id)).Magnitude < 400 then
		return true
	end
	-- Innenraeume der Venues liegen ausserhalb der Stadt (x > 4000)
	local def = Cfg.BusinessById[id]
	return root.Position.X > 4000 and (def.Link.Venue ~= nil or def.Link.ShopIds ~= nil or def.Link.Dealer == "Luxury")
end

local salaryClock = {}
local function minuteTick()
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			if not lastPos[player] or (root.Position - lastPos[player]).Magnitude > 6 then
				lastActive[player] = os.clock()
			end
			lastPos[player] = root.Position
		end
		local id = player:GetAttribute("BizDuty")
		local rec = id and cache[id]
		if rec then
			if roleOf(rec, player.UserId) == 0 then
				player:SetAttribute("BizDuty", nil)
			elseif isActive(player) and atWork(player, id) and status(id) == "Geoeffnet" then
				local def = Cfg.BusinessById[id]
				local t = Cfg.BusinessTypes[def.Type]
				local demand = math.clamp(2 - (rec.PriceFactor or 1), 0.5, 1.2)
				local amount = math.floor(t.Walkin * demand * (0.7 + math.random() * 0.6))
				queue(id, amount, amount, 0, nil)
				-- Gehalt alle SalaryInterval Sekunden aktiver Dienstzeit
				salaryClock[player] = (salaryClock[player] or 0) + 60
				if salaryClock[player] >= Cfg.SalaryInterval then
					salaryClock[player] = 0
					local e = rec.Employees[tostring(player.UserId)]
					if e and e.Salary > 0 then
						if account(id) >= e.Salary then
							queue(id, -e.Salary, 0, e.Salary, "Gehalt " .. e.Name)
							S.EconomyService.Credit(player, "Bank", e.Salary, "Gehalt " .. def.Name)
							S.Push(player, "Notify", { Text = string.format("Gehalt von %s: %s", def.Name, S.Format.money(e.Salary)), Kind = "success" })
							S.WorkService.AddXP(player, 15, "Arbeit bei " .. def.Name)
						else
							S.Push(player, "Notify", { Text = def.Name .. " kann dein Gehalt nicht zahlen (Konto leer)", Kind = "error" })
						end
					elseif rec.Owner == player.UserId then
						S.WorkService.AddXP(player, 10, "Unternehmen gefuehrt")
					end
				end
			end
		end
	end
end

function B.Flush(onlyId)
	for id, p in pairs(pending) do
		if (onlyId == nil or onlyId == id) and (p.Account ~= 0 or #p.Log > 0) then
			pending[id] = nil
			local def = Cfg.BusinessById[id]
			local _, err = update(id, function(r)
				if r.Owner == 0 then
					return false, "kein Inhaber"
				end
				r.Account += p.Account
				r.Revenue += p.Revenue
				r.Expenses += p.Expenses
				for _, l in ipairs(p.Log) do
					addLog(r, l[1], l[2])
				end
			end)
			if err and err ~= "kein Inhaber" then
				-- Wiederholung beim naechsten Takt
				local q = pending[id] or { Account = 0, Revenue = 0, Expenses = 0, Log = {} }
				q.Account += p.Account
				q.Revenue += p.Revenue
				q.Expenses += p.Expenses
				pending[id] = q
			end
			local _ = def
		end
	end
end

local function upkeep()
	for _, def in ipairs(Cfg.Businesses) do
		local rec = cache[def.Id]
		if rec and rec.Owner ~= 0 and os.time() - (rec.LastUpkeep or 0) >= 3600 then
			update(def.Id, function(r)
				if r.Owner == 0 then
					return false
				end
				local hours = math.min(72, math.floor((os.time() - r.LastUpkeep) / 3600))
				if hours < 1 then
					return false
				end
				local cost = math.floor(Cfg.BusinessTypes[def.Type].Upkeep / 24 * hours)
				r.Account -= cost
				r.Expenses += cost
				r.LastUpkeep += hours * 3600
				addLog(r, string.format("Betriebskosten %d h", hours), -cost)
			end)
		end
	end
end

local function tbl(p)
	return typeof(p) == "table" and p or {}
end
B.Actions = {
	["Business.List"] = function(player)
		return B.List(player)
	end,
	["Business.Info"] = function(player, p)
		local id = tbl(p).Id
		if not Cfg.BusinessById[id] then
			return false, "Unbekannt"
		end
		return true, nil, summary(id, player)
	end,
	["Business.Buy"] = function(player, p)
		return B.Buy(player, tbl(p).Id, tbl(p).TxId)
	end,
	["Business.Sell"] = function(player, p)
		return B.Sell(player, tbl(p).Id)
	end,
	["Business.Deposit"] = function(player, p)
		return B.Money(player, tbl(p).Id, tbl(p).Amount, true, tbl(p).TxId)
	end,
	["Business.Withdraw"] = function(player, p)
		return B.Money(player, tbl(p).Id, tbl(p).Amount, false, tbl(p).TxId)
	end,
	["Business.Settings"] = function(player, p)
		return B.Settings(player, tbl(p).Id, tbl(p))
	end,
	["Business.Apply"] = function(player, p)
		return B.Apply(player, tbl(p).Id)
	end,
	["Business.Staff"] = function(player, p)
		return B.Staff(player, tbl(p))
	end,
	["Business.Resign"] = function(player)
		return B.Resign(player)
	end,
	["Business.Clock"] = function(player, p)
		return B.Clock(player, tbl(p).Id, tbl(p).On == true)
	end,
}

function B.Start()
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore("MiamiState_Business_v1")
	end)
	store = (ok and not S.DataService.IsMock()) and s or nil
	for _, def in ipairs(Cfg.Businesses) do
		task.spawn(load, def.Id)
	end
	-- Kassen/Tueren der Ketten mit BusinessId versehen (Ladenmarker nach Namen)
	local byStore = {}
	for _, def in ipairs(Cfg.Businesses) do
		for _, n in ipairs(def.Link.StoreNames or {}) do
			byStore[n] = def.Id
		end
	end
	local function tagMarker(inst)
		local id = byStore[inst:GetAttribute("StoreName") or ""]
		if id and not inst:GetAttribute("BusinessId") then
			inst:SetAttribute("BusinessId", id)
		end
	end
	for _, tag in ipairs({ "StoreEntrance", "ShopEntrance" }) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			tagMarker(inst)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(tagMarker)
	end
	S.InteractionService.Register("BusinessOffice", function(player, inst)
		S.Push(player, "OpenWork", { Tab = "Business", Business = inst:GetAttribute("BusinessId") })
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastActive[p], lastPos[p], salaryClock[p] = nil, nil, nil
	end)
	task.spawn(function()
		local n = 0
		while true do
			task.wait(30)
			n += 1
			if n % 2 == 0 then
				pcall(minuteTick)
			end
			pcall(B.Flush)
			if n % 4 == 0 then
				pcall(upkeep)
				for _, def in ipairs(Cfg.Businesses) do
					task.spawn(load, def.Id)
				end
			end
		end
	end)
	game:BindToClose(function()
		pcall(B.Flush)
	end)
end

return B
