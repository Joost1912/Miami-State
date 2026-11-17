-- DealershipService (Prompt 10): Autohaeuser, Fahrzeugkauf/-verkauf, Probefahrt, Tuning, Garage, Tanken.
-- Baut auf VehicleService (Spawnen, Kennzeichen, Register) und EconomyService (Bank) auf - keine Doppelsysteme.
-- Welt-Interaktionen (Tag "Interactable"):
--   InteractType "Dealer"  + DealerId ("Standard" | "Luxury")  -> Autohaus-Menue
--   InteractType "Garage"  (+ GarageName)                       -> Garage (eigene Fahrzeuge aus-/einparken)
--   InteractType "Tuning"                                        -> Tuning-Werkstatt
--   Tag "TestDrivePad" (Attribut DealerId)                       -> Startpunkt der Probefahrt
--   Tag "FuelPump"                                                -> Zapfsaeule (Prompt "Tanken")
-- Alle Kaeufe: Serverpreise, Transaktions-ID (Doppelklick-Schutz), Ortspruefung, Bankkonto.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cfg = require(ReplicatedStorage:WaitForChild("MiamiShared").Config.Vehicles)

local D = {}
local S
local testDrives = {} -- [player] = { Model, Return = CFrame, Until }
local DEALER_RANGE = 45

function D.Init(services)
	S = services
end

local function nearDealer(player, dealerId)
	for _, inst in ipairs(CollectionService:GetTagged("Interactable")) do
		local t = inst:GetAttribute("InteractType")
		-- Prompt 12: "Gallery" (Miami Motor Gallery) fuehrt das komplette Sortiment beider Haendler
		local id = inst:GetAttribute("DealerId")
		if t == "Dealer" and (dealerId == nil or id == dealerId or id == "Gallery") and S.InteractionService.Near(player, inst, DEALER_RANGE) then
			return inst
		end
	end
	return nil
end

local function nearType(player, kind, range)
	return S.InteractionService.NearestOfType(player, kind, range or DEALER_RANGE)
end

local function specOf(modelId)
	local t = ServerStorage.Vehicles:FindFirstChild("Vehicle_" .. tostring(modelId))
	if not t then
		return nil
	end
	local seats = 0
	for _, c in ipairs(t:GetChildren()) do
		if c:IsA("Seat") or c:IsA("VehicleSeat") then
			seats += 1
		end
	end
	-- Prompt 12: Beschleunigung (0-100 km/h, Schaetzung aus Drehmoment/Masse) und Handling (Lenkung + Bremse, 0-10)
	local torque, mass = t:GetAttribute("Torque") or 2000, t:GetAttribute("Mass") or 140
	local accel = math.clamp(math.floor(1300 / (torque / mass)) / 10, 3, 16)
	local handling = math.clamp(math.floor(((t:GetAttribute("MaxSteer") or 30) / 35 * 6 + (t:GetAttribute("BrakeTorque") or 5000) / 8000 * 4) * 10) / 10, 1, 10)
	return { TopSpeed = math.floor((t:GetAttribute("MaxSpeed") or 90) * 0.28 * 3.6), Power = torque, Seats = seats, Accel = accel, Handling = handling }
end

local function validTx(player, txId)
	return S.EconomyService.ClaimTx(player, txId)
end

-- Katalog eines Autohauses ---------------------------------------------------------------------------
function D.Catalog(player, dealerId)
	if not Cfg.Dealers[dealerId] then
		return false, "Unbekanntes Autohaus"
	end
	if not nearDealer(player, dealerId) then
		return false, "Du bist nicht im Autohaus"
	end
	local d = S.DataService.Get(player)
	local list = {}
	for _, m in ipairs(Cfg.Models) do
		if m.Dealer == dealerId or dealerId == "Gallery" then
			local spec = specOf(m.Id)
			if spec then
				table.insert(list, { Id = m.Id, Name = m.Name, Class = m.Class, Price = m.Price, Desc = m.Desc, TopSpeed = spec.TopSpeed, Power = spec.Power, Seats = spec.Seats, Thirst = m.Thirst, Accel = spec.Accel, Handling = spec.Handling, Drive = m.Drive or "-" })
			end
		end
	end
	local paints = {}
	for i, p in ipairs(Cfg.Paints) do
		paints[i] = { Name = p.Name, R = math.floor(p.C.R * 255), G = math.floor(p.C.G * 255), B = math.floor(p.C.B * 255) }
	end
	return true, nil, { Dealer = dealerId, Title = Cfg.Dealers[dealerId].Name, Subtitle = Cfg.Dealers[dealerId].Subtitle, Models = list, Paints = paints, Owned = #d.Vehicles.Owned, MaxOwned = Cfg.MaxOwned, Bank = d.Money.Bank, Cash = d.Money.Cash, TestDrive = Cfg.TestDriveSeconds }
end

function D.Buy(player, p)
	local m = Cfg.ById[p.Model]
	if not m then
		return false, "Unbekanntes Modell"
	end
	if not nearDealer(player, m.Dealer) then
		return false, "Kauf nur im Autohaus " .. Cfg.Dealers[m.Dealer].Name
	end
	if not specOf(m.Id) then
		return false, "Modell derzeit nicht lieferbar"
	end
	local paint = Cfg.Paints[typeof(p.Paint) == "number" and p.Paint or 1]
	if not paint then
		return false, "Ungueltige Lackierung"
	end
	local d = S.DataService.Get(player)
	if #d.Vehicles.Owned >= Cfg.MaxOwned then
		return false, "Maximal " .. Cfg.MaxOwned .. " Fahrzeuge - verkaufe zuerst eines"
	end
	-- Prompt 12: Zahlart waehlbar (Bargeld oder Bankkonto); Pruefung vor dem Verbrauch der Transaktions-ID
	local account = p.Method == "Cash" and "Cash" or "Bank"
	if d.Money[account] < m.Price then
		return false, (account == "Cash" and "Nicht genug Bargeld" or "Kontostand nicht ausreichend") .. " (" .. S.Format.money(m.Price) .. ")"
	end
	if not validTx(player, p.TxId) then
		return false, "Vorgang bereits ausgefuehrt"
	end
	local ok, err = S.EconomyService.Charge(player, account, m.Price, "Fahrzeugkauf " .. m.Name)
	if not ok then
		return false, err
	end
	local plate = S.VehicleService.NewPlate()
	local c = paint.C
	local added, addErr = S.DataService.Mutate(player, "VehicleBuy", function(data)
		if #data.Vehicles.Owned >= Cfg.MaxOwned then
			return false, "Maximal " .. Cfg.MaxOwned .. " Fahrzeuge"
		end
		local maxId = 0
		for _, v in ipairs(data.Vehicles.Owned) do
			maxId = math.max(maxId, v.Id)
		end
		table.insert(data.Vehicles.Owned, {
			Id = maxId + 1, Type = m.Id, Name = m.Name, Plate = plate, Color = { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) },
			Paint = table.find(Cfg.Paints, paint), Price = m.Price, Bought = os.time(), Fuel = 100, Tuning = {},
		})
	end)
	if not added then
		-- Fahrzeug konnte nicht eingetragen werden: Kaufpreis erstatten (kein Geldverlust)
		S.EconomyService.Credit(player, account, m.Price, "Erstattung Fahrzeugkauf " .. m.Name)
		return false, addErr or "Kauf fehlgeschlagen - Betrag erstattet"
	end
	S.Log("Vehicle", player, nil, string.format("Kauf %s (%s) fuer $%d", m.Name, plate, m.Price))
	if S.BusinessService then
		S.BusinessService.OnDealer(m.Dealer, m.Price) -- Prompt 11: Provision des Autohaus-Inhabers
	end
	return true, string.format("Glueckwunsch! %s gekauft - Kennzeichen %s. Abholung ueber Garage oder Handy.", m.Name, plate), { Plate = plate, Name = m.Name, Price = m.Price, Method = account }
end

function D.Sell(player, id)
	if not nearDealer(player) then
		return false, "Verkauf nur in einem Autohaus"
	end
	local entry = S.VehicleService.OwnedEntry(player, id)
	if not entry then
		return false, "Fahrzeug nicht gefunden"
	end
	local live = S.VehicleService.LiveModel(player, entry)
	if live then
		local drv = S.VehicleService.DriverOf(live)
		if drv and drv ~= player then
			return false, "Fahrzeug wird gerade gefahren"
		end
		S.VehicleService.Despawn(live)
	end
	local value = S.VehicleService.SellValue(entry)
	local removed = false
	S.DataService.Mutate(player, "VehicleSell", function(data)
		for i, v in ipairs(data.Vehicles.Owned) do
			if v.Id == id then
				table.remove(data.Vehicles.Owned, i)
				removed = true
				return
			end
		end
		return false, "Fahrzeug nicht gefunden"
	end)
	if not removed then
		return false, "Fahrzeug nicht gefunden"
	end
	S.EconomyService.Credit(player, "Bank", value, "Fahrzeugverkauf " .. tostring(entry.Plate))
	S.Log("Vehicle", player, nil, string.format("Verkauf %s (%s) fuer $%d", tostring(entry.Type), tostring(entry.Plate), value))
	return true, string.format("%s verkauft - %s gutgeschrieben", entry.Plate, S.Format.money(value))
end

-- Probefahrt ---------------------------------------------------------------------------------------
local function endTestDrive(player, msg)
	local t = testDrives[player]
	if not t then
		return
	end
	testDrives[player] = nil
	if t.Model and t.Model.Parent then
		S.VehicleService.Despawn(t.Model)
	end
	local root = player.Parent and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and t.Return then
		task.wait(0.2)
		player.Character:PivotTo(t.Return)
	end
	if msg and player.Parent then
		S.Push(player, "Notify", { Text = msg, Kind = "info" })
	end
	player:SetAttribute("TestDrive", nil)
end

function D.TestDrive(player, modelId)
	local m = Cfg.ById[modelId]
	if not m then
		return false, "Unbekanntes Modell"
	end
	local dealer = nearDealer(player, m.Dealer)
	if not dealer then
		return false, "Probefahrt nur im Autohaus"
	end
	if testDrives[player] then
		return false, "Du machst bereits eine Probefahrt"
	end
	local pad
	-- naechster Probefahrt-Stellplatz zum Haendler, an dem der Spieler steht (Prompt 12: auch Gallery)
	local dRoot = S.InteractionService.RootOf(dealer)
	local bestD
	for _, p in ipairs(CollectionService:GetTagged("TestDrivePad")) do
		local id = p:GetAttribute("DealerId")
		if (id == m.Dealer or id == "Gallery") and p:IsDescendantOf(workspace) then
			local dist = dRoot and (p.Position - dRoot.Position).Magnitude or 0
			if not bestD or dist < bestD then
				pad, bestD = p, dist
			end
		end
	end
	if not pad then
		return false, "Probefahrt-Stellplatz nicht gefunden"
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum) then
		return false, "Nicht moeglich"
	end
	local model, err = S.VehicleService.Spawn(player, m.Id, pad.CFrame, "Test", "TestDrive", "PROBE-" .. math.random(10, 99))
	if not model then
		return false, err
	end
	model:SetAttribute("DisplayName", m.Name .. " (Probefahrt)")
	testDrives[player] = { Model = model, Return = root.CFrame, Until = os.clock() + Cfg.TestDriveSeconds }
	player:SetAttribute("TestDrive", os.time() + Cfg.TestDriveSeconds)
	pcall(function()
		player:RequestStreamAroundAsync(pad.Position, 5)
	end)
	char:PivotTo(pad.CFrame * CFrame.new(-7, 3, 0))
	task.delay(0.4, function()
		local seat = model.Parent and model:FindFirstChild("DriverSeat")
		if seat and hum.Parent and not seat.Occupant then
			seat:Sit(hum)
		end
	end)
	return true, string.format("Probefahrt gestartet: %d Sekunden. Aussteigen beendet die Fahrt.", Cfg.TestDriveSeconds)
end

-- Garage / Fahrzeugverwaltung ----------------------------------------------------------------------
function D.Locate(player, id)
	local entry = S.VehicleService.OwnedEntry(player, id)
	if not entry then
		return false, "Fahrzeug nicht gefunden"
	end
	local live = S.VehicleService.LiveModel(player, entry)
	local ch = live and live:FindFirstChild("Chassis")
	if not ch then
		return false, entry.Plate .. " steht in der Garage"
	end
	S.Push(player, "Waypoint", { X = ch.Position.X, Y = ch.Position.Y, Z = ch.Position.Z, Label = entry.Plate })
	return true, entry.Plate .. " auf der Karte markiert"
end

function D.Recall(player, id, txId)
	local entry = S.VehicleService.OwnedEntry(player, id)
	if not entry then
		return false, "Fahrzeug nicht gefunden"
	end
	local live = S.VehicleService.LiveModel(player, entry)
	if not live then
		return false, "Fahrzeug steht bereits in der Garage"
	end
	local drv = S.VehicleService.DriverOf(live)
	if drv and drv ~= player then
		return false, "Jemand faehrt dein Fahrzeug - zurueckrufen nicht zulaessig"
	end
	if drv == player then
		return false, "Steig zuerst aus"
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local ch = live:FindFirstChild("Chassis")
	local near = root and ch and (root.Position - ch.Position).Magnitude <= 60
	if not near then
		if not validTx(player, txId) then
			return false, "Vorgang bereits ausgefuehrt"
		end
		local ok, err = S.EconomyService.Charge(player, "Bank", Cfg.RecallFee, "Abschleppdienst " .. entry.Plate)
		if not ok then
			return false, err
		end
	end
	S.VehicleService.Despawn(live)
	return true, near and (entry.Plate .. " eingeparkt") or string.format("%s abgeschleppt und in die Garage gebracht (%s)", entry.Plate, S.Format.money(Cfg.RecallFee))
end

-- Tuning: Lack (Paint) oder Teil (Category/Option)
function D.Tune(player, p)
	if not (nearType(player, "Tuning", 40) or nearDealer(player)) then
		return false, "Tuning nur in der Werkstatt oder im Autohaus"
	end
	local entry = S.VehicleService.OwnedEntry(player, p.Id)
	if not entry then
		return false, "Fahrzeug nicht gefunden"
	end
	local price, apply, label
	if p.Paint ~= nil then
		local paint = Cfg.Paints[typeof(p.Paint) == "number" and p.Paint or 0]
		if not paint then
			return false, "Ungueltige Lackierung"
		end
		price, label = Cfg.PaintPrice, "Lackierung " .. paint.Name
		apply = function(v)
			v.Color = { math.floor(paint.C.R * 255), math.floor(paint.C.G * 255), math.floor(paint.C.B * 255) }
			v.Paint = p.Paint
		end
	else
		local cat = Cfg.Tuning[p.Category]
		local opt = cat and cat.Options[typeof(p.Option) == "number" and p.Option or 0]
		if not opt then
			return false, "Ungueltige Auswahl"
		end
		if (entry.Tuning and entry.Tuning[p.Category] or 1) == p.Option then
			return false, "Bereits verbaut"
		end
		price, label = opt.Price, cat.Title .. ": " .. opt.Name
		apply = function(v)
			v.Tuning = v.Tuning or {}
			v.Tuning[p.Category] = p.Option
		end
	end
	if price > 0 then
		if not validTx(player, p.TxId) then
			return false, "Vorgang bereits ausgefuehrt"
		end
		local ok, err = S.EconomyService.Charge(player, "Bank", price, "Tuning " .. entry.Plate)
		if not ok then
			return false, err
		end
		-- Prompt 11: Umsatzanteil fuer die Werkstatt/das Autohaus (Interaktionspunkt mit BusinessId)
		local shop = nearType(player, "Tuning", 40) or nearDealer(player)
		if S.BusinessService and shop then
			S.BusinessService.OnSale(shop, price, "Tuning")
		end
	end
	S.DataService.Mutate(player, "VehicleTune", function(data)
		for _, v in ipairs(data.Vehicles.Owned) do
			if v.Id == entry.Id then
				apply(v)
			end
		end
	end)
	local live = S.VehicleService.LiveModel(player, entry)
	if live then
		-- Lack neu: Fahrzeug neu einparken noetig (Grundfarbe sitzt in der Vorlage), Teile sofort sichtbar
		S.VehicleService.ApplyLook(live, S.VehicleService.OwnedEntry(player, entry.Id))
	end
	return true, label .. " verbaut" .. (price > 0 and (" (" .. S.Format.money(price) .. ")") or "") .. ((live and p.Paint ~= nil) and " - neue Farbe nach dem naechsten Ausparken" or "")
end

-- Tanken ---------------------------------------------------------------------------------------------
local function refuel(player, pump)
	local best, bd
	for _, m in ipairs(workspace:FindFirstChild("Vehicles") and workspace.Vehicles:GetChildren() or {}) do
		local ch = m:FindFirstChild("Chassis")
		if ch and m:GetAttribute("Fuel") and (m:GetAttribute("OwnerUserId") == player.UserId or S.VehicleService.DriverOf(m) == player) then
			local dd = (ch.Position - pump.Position).Magnitude
			if dd < 30 and (not bd or dd < bd) then
				best, bd = m, dd
			end
		end
	end
	if not best then
		S.Push(player, "Notify", { Text = "Kein eigenes Fahrzeug an der Zapfsaeule", Kind = "error" })
		return
	end
	local missing = math.floor(100 - best:GetAttribute("Fuel"))
	if missing < 1 then
		S.Push(player, "Notify", { Text = "Tank ist bereits voll", Kind = "info" })
		return
	end
	local cost = missing * Cfg.FuelPricePerPercent
	local d = S.DataService.Get(player)
	local account = d.Money.Cash >= cost and "Cash" or "Bank"
	local ok, err = S.EconomyService.Charge(player, account, cost, "Tankstelle")
	if not ok then
		S.Push(player, "Notify", { Text = err, Kind = "error" })
		return
	end
	best:SetAttribute("Fuel", 100)
	S.Push(player, "Notify", { Text = string.format("Vollgetankt: %d%% fuer %s (%s)", missing, S.Format.money(cost), account == "Cash" and "bar" or "Karte"), Kind = "success" })
end

local function setupPump(pump)
	if not pump:IsA("BasePart") or not pump:IsDescendantOf(workspace) or pump:FindFirstChild("FuelPrompt") then
		return
	end
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "FuelPrompt"
	pr.ActionText = "Tanken"
	pr.ObjectText = "Zapfsaeule"
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr.HoldDuration = 1.2
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr.Parent = pump
	pr.Triggered:Connect(function(player)
		if S.DataService.Get(player) then
			refuel(player, pump)
		end
	end)
end

-- Aktionen fuer den Request-Endpunkt (Main uebernimmt D.Actions) ------------------------------------
local function tbl(p)
	return typeof(p) == "table" and p or {}
end
D.Actions = {
	["Dealer.Catalog"] = function(player, p)
		return D.Catalog(player, tbl(p).Dealer)
	end,
	["Dealer.Buy"] = function(player, p)
		return D.Buy(player, tbl(p))
	end,
	["Dealer.TestDrive"] = function(player, p)
		return D.TestDrive(player, tbl(p).Model)
	end,
	["Vehicle.Sell"] = function(player, p)
		return D.Sell(player, tbl(p).Id)
	end,
	["Vehicle.Locate"] = function(player, p)
		return D.Locate(player, tbl(p).Id)
	end,
	["Vehicle.Recall"] = function(player, p)
		return D.Recall(player, tbl(p).Id, tbl(p).TxId)
	end,
	["Vehicle.Tune"] = function(player, p)
		return D.Tune(player, tbl(p))
	end,
	["Vehicle.TuningInfo"] = function(player)
		local out = {}
		for _, k in ipairs(Cfg.TuningOrder) do
			local c = Cfg.Tuning[k]
			local opts = {}
			for i, o in ipairs(c.Options) do
				opts[i] = { Name = o.Name, Price = o.Price }
			end
			table.insert(out, { Id = k, Title = c.Title, Options = opts })
		end
		local paints = {}
		for i, p in ipairs(Cfg.Paints) do
			paints[i] = { Name = p.Name, R = math.floor(p.C.R * 255), G = math.floor(p.C.G * 255), B = math.floor(p.C.B * 255) }
		end
		return true, nil, { Categories = out, Paints = paints, PaintPrice = Cfg.PaintPrice, AtShop = (nearType(player, "Tuning", 40) or nearDealer(player)) ~= nil }
	end,
}

function D.Start()
	S.InteractionService.Register("Dealer", function(player, inst)
		S.Push(player, "OpenVehicles", { Dealer = inst:GetAttribute("DealerId") or "Standard" })
	end)
	S.InteractionService.Register("Garage", function(player, inst)
		S.Push(player, "OpenVehicles", { Tab = "Garage", GarageName = inst:GetAttribute("ObjectText") or "Garage" })
	end)
	S.InteractionService.Register("Tuning", function(player)
		S.Push(player, "OpenVehicles", { Tab = "Tuning" })
	end)
	-- Tankstand beim Einparken/Despawnen ins Profil schreiben
	S.VehicleService.OnDespawn = function(model)
		local id = model:GetAttribute("OwnedId")
		local fuel = model:GetAttribute("Fuel")
		local owner = Players:GetPlayerByUserId(model:GetAttribute("OwnerUserId") or 0)
		if id and fuel and owner and S.DataService.Get(owner) then
			S.DataService.Mutate(owner, "VehicleFuel", function(data)
				for _, v in ipairs(data.Vehicles.Owned) do
					if v.Id == id then
						v.Fuel = math.floor(fuel)
					end
				end
			end)
		end
	end
	CollectionService:GetInstanceAddedSignal("FuelPump"):Connect(setupPump)
	for _, p in ipairs(CollectionService:GetTagged("FuelPump")) do
		setupPump(p)
	end
	-- Probefahrt: Zeitlimit / Aussteigen
	task.spawn(function()
		while true do
			task.wait(1)
			for player, t in pairs(testDrives) do
				local model = t.Model
				local seated = model and model.Parent and S.VehicleService.DriverOf(model) == player
				if not player.Parent or not model or not model.Parent then
					testDrives[player] = nil
				elseif os.clock() > t.Until then
					task.spawn(endTestDrive, player, "Probefahrt beendet - zurueck im Autohaus")
				elseif not seated and os.clock() > t.Until - Cfg.TestDriveSeconds + 3 then
					t.Out = (t.Out or 0) + 1
					if t.Out >= 6 then
						task.spawn(endTestDrive, player, "Probefahrt beendet (ausgestiegen)")
					end
				else
					t.Out = 0
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local t = testDrives[player]
		if t and t.Model then
			S.VehicleService.Despawn(t.Model)
		end
		testDrives[player] = nil
	end)
end

return D
