-- LottService (Prompt 13): LOTT E-Scooter-Sharing.
-- * Roller: workspace.LottScooters (Attribut ScooterId, eindeutig). Ruhend verankert; bei Miete freigegeben.
-- * Miete nur direkt am Roller (ProximityPrompt + serverseitige Abstandspruefung), ein Roller pro Spieler,
--   ein Spieler pro Roller. Fremde werden vom Sitz entfernt.
-- * Abrechnung ausschliesslich serverseitig: 50 $ je angefangener Minute, abgebucht zu Beginn jeder Minute
--   (Minutenzaehler je Miete -> keine Doppelbuchung). Reicht das Geld nicht -> Miete endet, keine Schulden.
-- * Verbindungsabbruch: Miete endet sofort (bezahlte Minute verfaellt).
-- * Synchronisierung: Attribute am Roller (Available, RenterId) + App fragt alle 4 s eine kompakte Liste ab.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cfg = require(ReplicatedStorage:WaitForChild("MiamiShared").Config.Lott)

local L = {}
local S
local folder
local scooters = {} -- [id] = model
local rentals = {} -- [player] = { Id, Model, Start, Minutes, Paid, Method }
local lastAsk = {}
L._rentals = rentals -- nur fuer den Studio-Test (MiamiDebug "Lott")

function L.Init(services)
	S = services
end

local function rpRoot(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function chassisOf(m)
	return m and m:FindFirstChild("Chassis")
end

local function district(pos)
	local MapData = require(ReplicatedStorage.MiamiShared.Config.MapData)
	return MapData.DistrictAt(pos.X, pos.Z)
end

local function setAvailable(m, on, renter)
	m:SetAttribute("Available", on)
	m:SetAttribute("RenterId", renter and renter.UserId or nil)
	local seat = m:FindFirstChild("DriverSeat")
	if seat then
		seat.Disabled = on
		-- "Einsteigen" (F, VehicleService) nur waehrend einer Miete anbieten
		local ep = seat:FindFirstChild("EnterPrompt")
		if ep then
			ep.Enabled = not on and seat.Occupant == nil
			ep.ActionText = "Aufsteigen"
		end
	end
	local pr = chassisOf(m) and chassisOf(m):FindFirstChild("LottPrompt")
	if pr then
		pr.ActionText = on and "Mieten (50 $/Min)" or "Miete verwalten"
		pr.ObjectText = m:GetAttribute("ScooterId") .. (on and "  ·  verfuegbar" or "  ·  vermietet")
	end
	local disp = m:FindFirstChild("Body") and m.Body:FindFirstChild("Display")
	local txt = disp and disp:FindFirstChildWhichIsA("SurfaceGui") and disp:FindFirstChildWhichIsA("SurfaceGui"):FindFirstChild("DisplayText")
	if txt then
		txt.Text = on and "LOTT  FREI" or "LOTT  AKTIV"
	end
end

-- Roller abstellen: aufrecht hinstellen und verankern (sobald er steht)
local function park(m)
	local ch = chassisOf(m)
	if not ch then
		return
	end
	task.spawn(function()
		for _ = 1, 20 do
			if m:GetAttribute("Available") ~= true or not m.Parent then
				return
			end
			if ch.AssemblyLinearVelocity.Magnitude < 1 and not (m.DriverSeat and m.DriverSeat.Occupant) then
				break
			end
			task.wait(0.5)
		end
		if m:GetAttribute("Available") ~= true or not m.Parent then
			return
		end
		local pos = ch.Position
		local look = ch.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
		pcall(function()
			ch:SetNetworkOwner(nil)
		end)
		m:PivotTo(CFrame.lookAt(pos, pos + flat) * CFrame.new(0, 0.05, 0))
		ch.Anchored = true
	end)
end

local function charge(player, r)
	-- naechste angefangene Minute abbuchen (bevorzugte Zahlart, sonst die andere)
	local d = S.DataService.Get(player)
	if not d then
		return false
	end
	local price = Cfg.PricePerMinute
	local order = r.Method == "Cash" and { "Cash", "Bank" } or { "Bank", "Cash" }
	for _, acc in ipairs(order) do
		if d.Money[acc] >= price then
			local ok = S.EconomyService.Charge(player, acc, price, string.format("LOTT %s Minute %d", r.Id, r.Minutes + 1))
			if ok then
				r.Minutes += 1
				r.Paid += price
				return true
			end
		end
	end
	return false
end

local function finish(player, reason)
	local r = rentals[player]
	if not r then
		return nil
	end
	rentals[player] = nil -- zuerst austragen: keine zweite Abrechnung moeglich
	local m = r.Model
	local seat = m and m:FindFirstChild("DriverSeat")
	if seat and seat.Occupant then
		seat.Occupant.Sit = false
	end
	if m and m.Parent then
		setAvailable(m, true)
		park(m)
	end
	player:SetAttribute("LottRental", nil)
	local duration = os.time() - r.Start
	local entry = { Id = r.Id, Start = r.Start, Duration = duration, Minutes = r.Minutes, Cost = r.Paid, Reason = reason or "Beendet" }
	if player.Parent and S.DataService.Get(player) then
		S.DataService.Mutate(player, "LottHistory", function(d)
			d.Lott = d.Lott or { History = {}, Total = 0, Rides = 0 }
			table.insert(d.Lott.History, 1, entry)
			while #d.Lott.History > Cfg.MaxHistory do
				table.remove(d.Lott.History)
			end
			d.Lott.Total = (d.Lott.Total or 0) + r.Paid
			d.Lott.Rides = (d.Lott.Rides or 0) + 1
		end)
		S.Push(player, "LottState", { Active = false, Last = entry })
	end
	S.Log("Lott", player, nil, string.format("%s %s: %d Min, $%d (%s)", r.Id, "Miete Ende", r.Minutes, r.Paid, entry.Reason))
	return entry
end

function L.Rent(player, id, method)
	local m = scooters[id]
	if typeof(id) ~= "string" or not m or not m.Parent then
		return false, "Roller nicht gefunden"
	end
	if rentals[player] then
		return false, "Du hast bereits einen Roller gemietet (" .. rentals[player].Id .. ")"
	end
	if m:GetAttribute("Available") ~= true then
		return false, "Dieser Roller ist bereits vermietet"
	end
	local root, ch = rpRoot(player), chassisOf(m)
	if not root or not ch or (root.Position - ch.Position).Magnitude > Cfg.RentRange then
		return false, "Du musst direkt am Roller stehen"
	end
	if player:GetAttribute("Cuffed") or player:GetAttribute("Jailed") or player:GetAttribute("Injury") == "Unconscious" then
		return false, "Nicht moeglich"
	end
	local r = { Id = id, Model = m, Start = os.time(), Minutes = 0, Paid = 0, Method = method == "Cash" and "Cash" or "Bank" }
	-- Sperre setzen, bevor gebucht wird (zweite Anfrage im selben Moment scheitert an Available/rentals)
	rentals[player] = r
	setAvailable(m, false, player)
	if not charge(player, r) then
		rentals[player] = nil
		setAvailable(m, true)
		return false, "Nicht genug Geld fuer die erste Minute (" .. S.Format.money(Cfg.PricePerMinute) .. ")"
	end
	ch.Anchored = false
	pcall(function()
		ch:SetNetworkOwner(player)
	end)
	player:SetAttribute("LottRental", id)
	-- direkt aufsteigen (Sitz ist jetzt freigegeben)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = m:FindFirstChild("DriverSeat")
	if hum and seat and hum.Health > 0 and not hum.SeatPart and not seat.Occupant then
		task.defer(function()
			if rentals[player] == r and not seat.Occupant then
				seat:Sit(hum)
			end
		end)
	end
	S.Push(player, "LottState", { Active = true, Id = id, Start = r.Start, Minutes = r.Minutes, Paid = r.Paid, Price = Cfg.PricePerMinute })
	S.Log("Lott", player, nil, id .. " Miete Start")
	return true, string.format("%s gemietet - erste Minute %s bezahlt. Einsteigen mit F.", id, S.Format.money(Cfg.PricePerMinute))
end

function L.End(player)
	if not rentals[player] then
		return false, "Keine aktive Miete"
	end
	local e = finish(player, "Beendet")
	return true, string.format("Miete beendet: %d angefangene Minute(n), gesamt %s", e.Minutes, S.Format.money(e.Cost))
end

function L.List(player)
	local root = rpRoot(player)
	local out = {}
	for id, m in pairs(scooters) do
		local ch = chassisOf(m)
		if ch and m.Parent then
			local p = ch.Position
			local mine = rentals[player] and rentals[player].Id == id
			table.insert(out, {
				Id = id, X = math.floor(p.X), Y = math.floor(p.Y), Z = math.floor(p.Z), Available = m:GetAttribute("Available") == true, Mine = mine,
				Dist = root and math.floor((p - root.Position).Magnitude * 0.28) or nil,
			})
		end
	end
	table.sort(out, function(a, b)
		return (a.Dist or 1e9) < (b.Dist or 1e9)
	end)
	local r = rentals[player]
	local d = S.DataService.Get(player)
	return true, nil, {
		Scooters = out, Price = Cfg.PricePerMinute, Rules = Cfg.Rules,
		Active = r and { Id = r.Id, Start = r.Start, Minutes = r.Minutes, Paid = r.Paid, Now = os.time() } or nil,
		History = d.Lott and d.Lott.History or {}, Total = d.Lott and d.Lott.Total or 0, Rides = d.Lott and d.Lott.Rides or 0,
	}
end

function L.Info(player, id)
	local m = scooters[id]
	local ch = chassisOf(m)
	if not ch then
		return false, "Roller nicht gefunden"
	end
	local root = rpRoot(player)
	return true, nil, { Id = id, Available = m:GetAttribute("Available") == true, Mine = rentals[player] and rentals[player].Id == id, District = district(ch.Position), X = ch.Position.X, Y = ch.Position.Y, Z = ch.Position.Z, Dist = root and math.floor((ch.Position - root.Position).Magnitude * 0.28) or nil, Price = Cfg.PricePerMinute }
end

local function setupScooter(m)
	local id = m:GetAttribute("ScooterId")
	local ch = chassisOf(m)
	if not id or not ch or scooters[id] then
		return
	end
	scooters[id] = m
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "LottPrompt"
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr.MaxActivationDistance = 8
	pr.HoldDuration = 0
	pr.RequiresLineOfSight = false
	pr.Parent = ch
	pr.Triggered:Connect(function(player)
		if not S.DataService.Get(player) then
			return
		end
		if lastAsk[player] and os.clock() - lastAsk[player] < 0.5 then
			return
		end
		lastAsk[player] = os.clock()
		local r = rentals[player]
		if r and r.Id == id then
			S.Push(player, "LottManage", { Id = id, Start = r.Start, Minutes = r.Minutes, Paid = r.Paid })
		elseif m:GetAttribute("Available") == true then
			local d = S.DataService.Get(player)
			S.Push(player, "LottOffer", { Id = id, Price = Cfg.PricePerMinute, District = district(ch.Position), Cash = d.Money.Cash, Bank = d.Money.Bank, Rules = Cfg.Rules, HasRental = r ~= nil and r.Id or nil })
		else
			S.Push(player, "Notify", { Text = id .. " ist gerade vermietet", Kind = "warning" })
		end
	end)
	-- nur der Mieter darf fahren
	local seat = m:FindFirstChild("DriverSeat")
	if seat then
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			local occ = seat.Occupant
			local p = occ and Players:GetPlayerFromCharacter(occ.Parent)
			if occ and (not p or not rentals[p] or rentals[p].Id ~= id) then
				local w = seat:FindFirstChild("SeatWeld")
				if w then
					w:Destroy()
				end
				occ.Sit = false
				if p then
					S.Push(p, "Notify", { Text = "Erst mieten: LOTT-App oder E am Roller", Kind = "error" })
				end
			end
			-- VehicleService schaltet "Einsteigen" bei Sitzwechsel wieder ein -> danach korrigieren
			task.defer(function()
				local ep = seat:FindFirstChild("EnterPrompt")
				if ep then
					ep.Enabled = m:GetAttribute("Available") ~= true and seat.Occupant == nil
				end
			end)
		end)
	end
	setAvailable(m, true)
end

local function tbl(p)
	return typeof(p) == "table" and p or {}
end
L.Actions = {
	["Lott.List"] = function(player)
		return L.List(player)
	end,
	["Lott.Info"] = function(player, p)
		return L.Info(player, tbl(p).Id)
	end,
	["Lott.Rent"] = function(player, p)
		return L.Rent(player, tbl(p).Id, tbl(p).Method)
	end,
	["Lott.End"] = function(player)
		return L.End(player)
	end,
}

function L.Start()
	folder = workspace:WaitForChild("LottScooters", 10)
	if not folder then
		warn("[Lott] workspace.LottScooters fehlt (Bauschritt 29)")
		return
	end
	for _, m in ipairs(folder:GetChildren()) do
		setupScooter(m)
	end
	folder.ChildAdded:Connect(setupScooter)
	-- Prompts des Fahrzeugsystems koennen spaeter entstehen -> Zustand nachziehen
	task.delay(3, function()
		for _, m in pairs(scooters) do
			if m:GetAttribute("Available") == true then
				setAvailable(m, true)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if rentals[player] then
			finish(player, "Spiel verlassen")
		end
		lastAsk[player] = nil
	end)
	-- Minutentakt: zu Beginn jeder angefangenen Minute abbuchen
	task.spawn(function()
		while true do
			task.wait(1)
			for player, r in pairs(rentals) do
				local elapsed = os.time() - r.Start
				local due = math.floor(elapsed / 60) + 1 -- angefangene Minuten
				if due > r.Minutes then
					if not charge(player, r) then
						finish(player, "Guthaben aufgebraucht")
						S.Push(player, "Notify", { Text = "LOTT: Miete beendet - nicht genug Geld fuer die naechste Minute", Kind = "error" })
					else
						S.Push(player, "LottState", { Active = true, Id = r.Id, Start = r.Start, Minutes = r.Minutes, Paid = r.Paid, Price = Cfg.PricePerMinute })
					end
				end
				-- Roller verloren (zerstoert/aus der Welt gefallen)
				if r.Model and (not r.Model.Parent or (chassisOf(r.Model) and chassisOf(r.Model).Position.Y < -60)) then
					finish(player, "Roller verloren")
				end
			end
		end
	end)
end

return L
