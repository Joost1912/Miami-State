-- WorkService (Prompt 11): zivile Berufe, Schichten, Auftraege, Karriere (XP/Stufen), Rechnungen.
-- Prinzip: Der Server erzeugt jeden Auftragsschritt (Ort, Radius, Haltezeit) und prueft selbst per Position,
-- ob der Spieler (bzw. sein Dienstfahrzeug) dort ist. Der Client zeigt nur Wegpunkt/Prompt an und meldet
-- "Aktion ausgefuehrt" - gueltig erst nach der Haltezeit seit der serverseitig festgestellten Ankunft.
-- Bezahlung: Serverwerte (Config.Work), Stufenbonus, Stundenlimit, Mindestfahrzeit (kein Teleport-Lohn).
-- Welt (Bauschritt 26): Depot-Terminal (Interactable "WorkDepot", JobId), Fahrzeugplaetze (Tag "WorkVehiclePad", JobId),
--   Tag "WorkDock" (Id = DeliveryDock | TruckDock), Tag "TruckDrop", Tag "BusStop" (Index), Tag "ConstructionPoint" (Kind)
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local Cfg = require(Shared.Config.Work)
local Items = require(Shared.Config.Items)

local Work = {}
local S
local shifts = {} -- [player] = { Job, Vehicle, Task, LastSkip, Seq }
local earnWindow = {} -- [player] = { Start, Sum }
local invoices = {} -- [target] = { [id] = { From, Amount, Reason, Until, Business } }
local lastInvoice = {}

function Work.Init(services)
	S = services
end

-- Hilfen ---------------------------------------------------------------------------------------------
local function rootOf(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end
local function rpName(player)
	local d = S.DataService.Get(player)
	return d and d.Character.Created and (d.Character.FirstName .. " " .. d.Character.LastName) or player.Name
end
local function workData(player)
	local d = S.DataService.Get(player)
	return d and d.Work
end
local function tagged(tag, filterAttr, value)
	local out = {}
	for _, p in ipairs(CollectionService:GetTagged(tag)) do
		if p:IsA("BasePart") and p:IsDescendantOf(workspace) and (filterAttr == nil or p:GetAttribute(filterAttr) == value) then
			table.insert(out, p)
		end
	end
	return out
end
local function pick(list)
	return #list > 0 and list[math.random(1, #list)] or nil
end
-- Zufaellige Adresse (Ladenmarker) in einem Entfernungsband
local function addressNear(from, minD, maxD)
	local cands = {}
	for _, m in ipairs(CollectionService:GetTagged("StoreEntrance")) do
		if m:IsA("BasePart") and m:IsDescendantOf(workspace) then
			local d = (m.Position - from).Magnitude
			if d >= minD and d <= maxD then
				table.insert(cands, m)
			end
		end
	end
	local m = pick(cands)
	if not m then
		return nil
	end
	return { Pos = m.Position, Name = m:GetAttribute("StoreName") or "Adresse", CF = m.CFrame }
end

function Work.Level(player)
	local w = workData(player)
	return w and Cfg.LevelFor(w.XP or 0) or 1
end

function Work.AddXP(player, amount, reason)
	if typeof(amount) ~= "number" or amount <= 0 then
		return
	end
	local before, after
	S.DataService.Mutate(player, "XP", function(d)
		d.Work.XP = (d.Work.XP or 0) + math.floor(amount)
		before = Cfg.LevelFor(d.Work.XP - math.floor(amount))
		after = Cfg.LevelFor(d.Work.XP)
	end)
	player:SetAttribute("WorkLevel", after)
	if after and before and after > before then
		S.Push(player, "Notify", { Text = string.format("Karriere: Stufe %d erreicht! %s", after, reason and ("(" .. reason .. ")") or ""), Kind = "success" })
		for _, u in ipairs(Cfg.Unlocks) do
			if u.Level == after then
				S.Push(player, "Notify", { Text = "Freigeschaltet: " .. u.Text, Kind = "success" })
			end
		end
	end
end

-- Lohn: Stufenbonus, Arbeitgeber-Bonus, Stundenlimit
local function reward(player, jobId, amount, xp, label, cashTip)
	local job = Cfg.Jobs[jobId]
	local lvl = Work.Level(player)
	local bonus = math.min(Cfg.PayBonusMax, (lvl - 1) * Cfg.PayBonusPerLevel)
	local employed = S.BusinessService and S.BusinessService.EmployerFor(player, jobId)
	if employed then
		bonus += 0.10
	end
	amount = math.floor(amount * (1 + bonus) + 0.5)
	local win = earnWindow[player]
	if not win or os.time() - win.Start >= 3600 then
		win = { Start = os.time(), Sum = 0 }
		earnWindow[player] = win
	end
	if win.Sum >= Cfg.HourlyCap then
		S.Push(player, "Notify", { Text = "Stundenlimit fuer Arbeitslohn erreicht - weiter in " .. math.ceil((3600 - (os.time() - win.Start)) / 60) .. " Min", Kind = "warning" })
		amount, cashTip = 0, 0
	else
		amount = math.min(amount, Cfg.HourlyCap - win.Sum)
		win.Sum += amount
	end
	if amount > 0 then
		S.EconomyService.Credit(player, "Bank", amount, job.Company .. ": " .. label)
	end
	if cashTip and cashTip > 0 then
		S.EconomyService.Credit(player, "Cash", cashTip, "Trinkgeld")
	end
	S.DataService.Mutate(player, "WorkStats", function(d)
		local st = d.Work.Stats[jobId] or { Tasks = 0, Earned = 0 }
		st.Tasks += 1
		st.Earned += amount + (cashTip or 0)
		d.Work.Stats[jobId] = st
		d.Work.Earned = (d.Work.Earned or 0) + amount + (cashTip or 0)
	end)
	Work.AddXP(player, xp, job.Name)
	if S.BusinessService then
		S.BusinessService.OnJob(jobId, amount, player)
	end
	local text = string.format("%s: +%s%s  ·  +%d XP", label, S.Format.money(amount), (cashTip and cashTip > 0) and (" + " .. S.Format.money(cashTip) .. " Trinkgeld") or "", xp)
	S.Push(player, "WorkDone", { Text = text, Amount = amount, Tip = cashTip, XP = xp })
	return amount
end

-- Auftragsschritte ------------------------------------------------------------------------------------
-- step = { Kind = "Drive"|"Hold", Pos, Radius, Label, Hold, Action, Vehicle = bool (Fahrer des Dienstfahrzeugs),
--          VehicleNear = Studs (Dienstfahrzeug in der Naehe), StopSeconds, Done = function(player, s) }
local function pushStep(player, s)
	local t = s.Task
	local st = t and t.Steps[t.Index]
	if not st then
		S.Push(player, "WorkTask", { Clear = true })
		return
	end
	st.StartedAt = os.clock()
	st.StartPos = (rootOf(player) and rootOf(player).Position) or st.Pos
	st.ArrivedAt = nil
	S.Push(player, "WorkTask", {
		Id = t.Id, Job = s.Job, Title = t.Title, Step = t.Index, Steps = #t.Steps, Kind = st.Kind, Label = st.Label,
		X = st.Pos.X, Y = st.Pos.Y, Z = st.Pos.Z, Radius = st.Radius, Hold = st.Hold or 0, Action = st.Action, Info = t.Info,
	})
end

local function finishStep(player, s)
	local t = s.Task
	local st = t.Steps[t.Index]
	-- Mindestzeit fuer den zurueckgelegten Weg (Teleport-Schutz)
	local dist = (st.Pos - st.StartPos).Magnitude
	if dist > 200 and os.clock() - st.StartedAt < dist * Cfg.MinSecondsPerStud then
		S.Push(player, "Notify", { Text = "Auftrag ungueltig (zu schnell) - neuer Auftrag", Kind = "error" })
		S.Log("WorkExploit", player, nil, string.format("%s Schritt %d: %.0f Studs in %.1fs", s.Job, t.Index, dist, os.clock() - st.StartedAt))
		Work.NewTask(player)
		return
	end
	local ok, err = pcall(st.Done or function() end, player, s, st)
	if not ok then
		warn("[Work] Schritt-Fehler: " .. tostring(err))
	end
	if s.Task ~= t then
		return -- Done hat bereits einen neuen Auftrag gesetzt
	end
	t.Index += 1
	if t.Steps[t.Index] then
		pushStep(player, s)
	else
		task.delay(1.5, function()
			if shifts[player] == s then
				Work.NewTask(player)
			end
		end)
		S.Push(player, "WorkTask", { Clear = true, Between = true })
	end
end

-- Generatoren je Beruf --------------------------------------------------------------------------------
local Gen = {}

function Gen.Taxi(player, s)
	local root = rootOf(player)
	local a = addressNear(root.Position, 250, 1400)
	local b = a and addressNear(a.Pos, 600, 2600)
	if not (a and b) then
		return nil
	end
	local dist = (b.Pos - a.Pos).Magnitude
	local job = Cfg.Jobs.Taxi
	local t
	t = { Title = "Fahrt: " .. a.Name .. " → " .. b.Name, Info = string.format("%d m Strecke", math.floor(dist * 0.28)), Steps = {
		{ Kind = "Drive", Pos = a.Pos, Radius = 26, Vehicle = true, StopSeconds = 1.5, Label = "Fahrgast abholen: " .. a.Name, Done = function()
			t.PickedAt = os.clock()
			S.Push(player, "Notify", { Text = "Fahrgast eingestiegen - Ziel: " .. b.Name, Kind = "info" })
		end },
		{ Kind = "Drive", Pos = b.Pos, Radius = 26, Vehicle = true, StopSeconds = 1.5, Label = "Fahrgast absetzen: " .. b.Name, Done = function()
			local expected = dist / 34 + 25
			local took = os.clock() - (t.PickedAt or os.clock())
			local tip = 0
			if took <= expected then
				tip = math.floor((job.Pay.Base + dist * job.Pay.PerStud) * job.Pay.TipMax * math.clamp(1.4 - took / expected, 0.2, 1))
			end
			reward(player, "Taxi", job.Pay.Base + dist * job.Pay.PerStud, job.XP, "Fahrt " .. b.Name, tip)
		end },
	} }
	return t
end

function Gen.Delivery(player, s)
	local job = Cfg.Jobs.Delivery
	local dock = pick(tagged("WorkDock", "Id", "DeliveryDock"))
	if not dock then
		return nil
	end
	local steps = {
		{ Kind = "Hold", Pos = dock.Position, Radius = 12, Hold = 3, Action = "Pakete laden", VehicleNear = 60, Label = "Pakete im Depot laden" },
	}
	local prev = dock.Position
	local names = {}
	for i = 1, job.Pay.Packages do
		local a = addressNear(prev, 350, 1500)
		if a then
			local from = prev
			table.insert(names, a.Name)
			table.insert(steps, { Kind = "Hold", Pos = a.Pos, Radius = 12, Hold = 1.5, Action = "Paket uebergeben", VehicleNear = 90, Label = string.format("Paket %d/%d: %s", i, job.Pay.Packages, a.Name), Done = function()
				reward(player, "Delivery", job.Pay.PerPackage + (a.Pos - from).Magnitude * job.Pay.PerStud, job.XP, "Paket " .. a.Name)
			end })
			prev = a.Pos
		end
	end
	return { Title = "Tour: " .. #names .. " Pakete", Info = table.concat(names, ", "), Steps = steps }
end

function Gen.Bus(player, s)
	local job = Cfg.Jobs.Bus
	local stops = tagged("BusStop")
	table.sort(stops, function(a, b)
		return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
	end)
	if #stops < 2 then
		return nil
	end
	local steps = {}
	for i, stop in ipairs(stops) do
		table.insert(steps, { Kind = "Drive", Pos = stop.Position, Radius = 24, Vehicle = true, StopSeconds = 3, Label = string.format("Haltestelle %d/%d: %s", i, #stops, stop:GetAttribute("StopName") or "Halt"), Done = function()
			local board, leave = math.random(0, 6), math.random(0, 5)
			S.Push(player, "Notify", { Text = string.format("%s: %d steigen ein, %d steigen aus", stop:GetAttribute("StopName") or "Halt", board, leave), Kind = "info" })
			local amount = job.Pay.PerStop + (i == #stops and job.Pay.RouteBonus or 0)
			reward(player, "Bus", amount, job.XP + (i == #stops and 20 or 0), i == #stops and "Linie abgeschlossen" or "Haltestelle")
		end })
	end
	return { Title = "Linie 1 · Stadtrundkurs", Info = #stops .. " Haltestellen", Steps = steps }
end

function Gen.Trucker(player, s)
	local job = Cfg.Jobs.Trucker
	local dock = pick(tagged("WorkDock", "Id", "TruckDock"))
	if not dock then
		return nil
	end
	local long = Work.Level(player) >= 5 and math.random() < 0.5
	local cands = {}
	for _, p in ipairs(tagged("TruckDrop")) do
		local d = (p.Position - dock.Position).Magnitude
		if (long and d >= 2600) or (not long and d >= 900) then
			table.insert(cands, p)
		end
	end
	local drop = pick(cands) or pick(tagged("TruckDrop"))
	if not drop then
		return nil
	end
	local dist = (drop.Position - dock.Position).Magnitude
	local cargo = pick({ "Lebensmittel", "Elektronik", "Baumaterial", "Getraenke", "Moebel", "Ersatzteile" })
	return { Title = (long and "Fernverkehr: " or "Fracht: ") .. cargo .. " → " .. (drop:GetAttribute("DropName") or "Ziel"), Info = string.format("%d m", math.floor(dist * 0.28)), Steps = {
		{ Kind = "Hold", Pos = dock.Position, Radius = 14, Hold = 4, Action = "Fracht laden", VehicleNear = 45, Label = "Fracht am Hafen laden" },
		{ Kind = "Drive", Pos = drop.Position, Radius = 40, Vehicle = true, StopSeconds = 1, Label = "Lieferziel: " .. (drop:GetAttribute("DropName") or "Ziel") },
		{ Kind = "Hold", Pos = drop.Position, Radius = 16, Hold = 4, Action = "Fracht entladen", VehicleNear = 45, Label = "Fracht entladen", Done = function()
			local amount = (job.Pay.Base + dist * job.Pay.PerStud) * (long and (1 + job.Pay.LongHaulBonus) or 1)
			reward(player, "Trucker", amount, job.XP + (long and 15 or 0), "Fracht " .. cargo)
		end },
	} }
end

local brokenFolder
local function spawnBroken(pos, cf)
	brokenFolder = brokenFolder or workspace:FindFirstChild("WorkProps") or Instance.new("Folder")
	brokenFolder.Name = "WorkProps"
	brokenFolder.Parent = workspace
	local t = game:GetService("ServerStorage").Vehicles:FindFirstChild("Vehicle_Sedan")
	if not t then
		return nil
	end
	local m = t:Clone()
	m.Name = "Breakdown"
	CollectionService:RemoveTag(m, "Vehicle")
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Constraint") or d:IsA("WeldConstraint") or d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("VehicleSeat") or d:IsA("Seat") then
			d.Disabled = true
			d.Anchored = true
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	for k in pairs(m:GetAttributes()) do
		m:SetAttribute(k, nil)
	end
	m:PivotTo(cf * CFrame.new(0, 2.2, 0))
	local hood = m.Body:FindFirstChild("Hood")
	if hood then
		local smoke = Instance.new("Smoke")
		smoke.Color = Color3.fromRGB(80, 80, 80)
		smoke.Size = 3
		smoke.RiseVelocity = 4
		smoke.Parent = hood
	end
	m.Parent = brokenFolder
	return m
end

function Gen.Mechanic(player, s)
	local job = Cfg.Jobs.Mechanic
	local root = rootOf(player)
	local cands = {}
	for _, p in ipairs(tagged("VehicleParkSpot")) do
		local d = (p.Position - root.Position).Magnitude
		if d > 400 and d < 2500 then
			table.insert(cands, p)
		end
	end
	local spot = pick(cands)
	if not spot then
		return nil
	end
	local dist = (spot.Position - root.Position).Magnitude
	local car
	local t
	t = { Title = "Pannenhilfe", Info = string.format("%d m entfernt", math.floor(dist * 0.28)), Cleanup = function()
		if car then
			car:Destroy()
		end
	end, Steps = {
		{ Kind = "Drive", Pos = spot.Position, Radius = 45, Vehicle = true, StopSeconds = 1, Label = "Pannenfahrzeug anfahren" },
		{ Kind = "Hold", Pos = spot.Position, Radius = 14, Hold = 6, Action = "Fahrzeug reparieren", VehicleNear = 70, Label = "Fahrzeug reparieren", Done = function()
			if car then
				car:Destroy()
				car = nil
			end
			reward(player, "Mechanic", job.Pay.Base + dist * job.Pay.PerStud, job.XP, "Pannenhilfe")
		end },
	} }
	car = spawnBroken(spot.Position, spot.CFrame)
	return t
end

function Gen.Construction(player, s)
	local job = Cfg.Jobs.Construction
	if math.random() < 0.55 then
		local pile = pick(tagged("ConstructionPoint", "Kind", "Pile"))
		local drop = pick(tagged("ConstructionPoint", "Kind", "Drop"))
		if pile and drop then
			local mat = pick({ "Zementsaecke", "Stahltraeger", "Ziegel", "Holzbalken", "Rohre" })
			return { Title = "Material: " .. mat, Info = drop:GetAttribute("Label") or "", Steps = {
				{ Kind = "Hold", Pos = pile.Position, Radius = 10, Hold = 2, Action = mat .. " aufnehmen", Label = mat .. " am Lager holen", Done = function()
					player:SetAttribute("Carrying", mat)
				end },
				{ Kind = "Hold", Pos = drop.Position, Radius = 10, Hold = 2, Action = "Abladen", Label = "Abladen: " .. (drop:GetAttribute("Label") or "Bauabschnitt"), Done = function()
					player:SetAttribute("Carrying", nil)
					reward(player, "Construction", job.Pay.Carry, job.XP, mat .. " geliefert")
				end },
			} }
		end
	end
	local tool = pick(tagged("ConstructionPoint", "Kind", "Tool"))
	if not tool then
		return nil
	end
	return { Title = "Arbeit: " .. (tool:GetAttribute("Label") or "Werkzeug"), Info = "", Steps = {
		{ Kind = "Hold", Pos = tool.Position, Radius = 10, Hold = 6, Action = tool:GetAttribute("Label") or "Arbeiten", Label = tool:GetAttribute("Label") or "Werkzeug benutzen", Done = function()
			reward(player, "Construction", job.Pay.Tool, job.XP + 2, tool:GetAttribute("Label") or "Werkzeug")
		end },
	} }
end

function Work.NewTask(player)
	local s = shifts[player]
	if not s then
		return
	end
	if s.Task and s.Task.Cleanup then
		pcall(s.Task.Cleanup)
	end
	s.Task = nil
	player:SetAttribute("Carrying", nil)
	if not rootOf(player) then
		return
	end
	local t = Gen[s.Job](player, s)
	if not t then
		S.Push(player, "Notify", { Text = "Gerade keine Auftraege verfuegbar", Kind = "warning" })
		S.Push(player, "WorkTask", { Clear = true })
		return
	end
	s.Seq += 1
	t.Id = HttpService:GenerateGUID(false)
	t.Index = 1
	s.Task = t
	pushStep(player, s)
end

-- Schicht --------------------------------------------------------------------------------------------
local function depotFor(jobId)
	for _, inst in ipairs(CollectionService:GetTagged("Interactable")) do
		if inst:GetAttribute("InteractType") == "WorkDepot" and inst:GetAttribute("JobId") == jobId and inst:IsDescendantOf(workspace) then
			return inst
		end
	end
	return nil
end

local function hasLicense(player)
	return S.InventoryService.Count(player, "DriversLicense") > 0 and not S.DataService.Get(player).Record.LicenseSuspended
end

function Work.Select(player, jobId)
	local job = Cfg.Jobs[jobId]
	if not job then
		return false, "Unbekannter Beruf"
	end
	if Work.Level(player) < job.Level then
		return false, string.format("%s erfordert Stufe %d", job.Name, job.Level)
	end
	local d = S.DataService.Get(player)
	if d.Job.Faction ~= "Civilian" and d.Job.OnDuty then
		return false, "Beende zuerst deinen Dienst bei " .. d.Job.Faction
	end
	if shifts[player] then
		Work.EndShift(player)
	end
	S.DataService.Mutate(player, "WorkSelect", function(data)
		data.Work.Job = jobId
	end)
	player:SetAttribute("WorkJob", jobId)
	local depot = depotFor(jobId)
	if depot then
		local r = S.InteractionService.RootOf(depot)
		S.Push(player, "Waypoint", { X = r.Position.X, Y = r.Position.Y, Z = r.Position.Z, Label = job.Company })
	end
	return true, string.format("Neuer Beruf: %s bei %s - Schicht am Depot beginnen (auf der Karte markiert)", job.Name, job.Company)
end

function Work.Quit(player)
	if shifts[player] then
		Work.EndShift(player)
	end
	S.DataService.Mutate(player, "WorkQuit", function(d)
		d.Work.Job = ""
	end)
	player:SetAttribute("WorkJob", nil)
	return true, "Beruf aufgegeben"
end

function Work.StartShift(player, depotInst)
	local d = S.DataService.Get(player)
	local jobId = d.Work.Job
	local job = Cfg.Jobs[jobId]
	if not job then
		return false, "Waehle zuerst einen Beruf (Handy: Jobs)"
	end
	if depotInst and depotInst:GetAttribute("JobId") ~= jobId then
		return false, "Dieses Depot gehoert zu " .. (Cfg.Jobs[depotInst:GetAttribute("JobId")] or {}).Name .. " - dein Beruf: " .. job.Name
	end
	local depot = depotInst or depotFor(jobId)
	if not depot or not S.InteractionService.Near(player, depot, 25) then
		return false, "Schicht nur am Depot von " .. job.Company .. " beginnen"
	end
	if shifts[player] then
		return false, "Du arbeitest bereits"
	end
	if d.Job.Faction ~= "Civilian" and d.Job.OnDuty then
		return false, "Beende zuerst deinen Fraktionsdienst"
	end
	if job.Vehicle and not hasLicense(player) then
		return false, "Fuehrerschein erforderlich"
	end
	local s = { Job = jobId, Seq = 0, Started = os.time() }
	if job.Vehicle then
		local pad
		for _, p in ipairs(tagged("WorkVehiclePad", "JobId", jobId)) do
			local free = true
			for _, v in ipairs(workspace:FindFirstChild("Vehicles") and workspace.Vehicles:GetChildren() or {}) do
				local ch = v:FindFirstChild("Chassis")
				if ch and (ch.Position - p.Position).Magnitude < 12 then
					free = false
				end
			end
			if free then
				pad = p
				break
			end
		end
		if not pad then
			return false, "Alle Dienstfahrzeuge sind gerade unterwegs - kurz warten"
		end
		local m, err = S.VehicleService.Spawn(player, job.Vehicle, pad.CFrame, "Work", "Work")
		if not m then
			return false, err
		end
		m:SetAttribute("DisplayName", job.Company)
		m:SetAttribute("WorkVehicle", jobId)
		s.Vehicle = m
	end
	shifts[player] = s
	player:SetAttribute("OnShift", jobId)
	if job.Uniform then
		S.UniformService.Apply(player, job.Uniform)
	end
	S.Log("Work", player, nil, "Schichtbeginn " .. job.Name)
	task.delay(0.5, Work.NewTask, player)
	return true, string.format("Schicht als %s begonnen%s", job.Name, job.Vehicle and " - Dienstfahrzeug steht bereit" or "")
end

function Work.EndShift(player)
	local s = shifts[player]
	if not s then
		return false, "Du arbeitest gerade nicht"
	end
	if s.Task and s.Task.Cleanup then
		pcall(s.Task.Cleanup)
	end
	shifts[player] = nil
	if s.Vehicle then
		S.VehicleService.Despawn(s.Vehicle)
	end
	player:SetAttribute("OnShift", nil)
	player:SetAttribute("Carrying", nil)
	pcall(S.UniformService.Remove, player, "WK_")
	S.Push(player, "WorkTask", { Clear = true })
	return true, "Schicht beendet"
end

-- Client meldet: Haltezeit an einem Hold-Schritt abgeschlossen
function Work.Action(player, taskId)
	local s = shifts[player]
	local t = s and s.Task
	local st = t and t.Steps[t.Index]
	if not st or t.Id ~= taskId or st.Kind ~= "Hold" then
		return false, "Kein passender Auftragsschritt"
	end
	if not st.ArrivedAt or os.clock() - st.ArrivedAt < (st.Hold or 0) - 0.6 then
		return false, "Noch nicht fertig"
	end
	finishStep(player, s)
	return true
end

function Work.Skip(player)
	local s = shifts[player]
	if not s then
		return false, "Keine Schicht"
	end
	if s.LastSkip and os.clock() - s.LastSkip < Cfg.SkipCooldown then
		return false, "Neuer Auftrag erst in " .. math.ceil(Cfg.SkipCooldown - (os.clock() - s.LastSkip)) .. " s"
	end
	s.LastSkip = os.clock()
	Work.NewTask(player)
	return true, "Neuer Auftrag"
end

-- Positionspruefung (2x pro Sekunde)
local function inVehicle(player, s)
	local v = s.Vehicle
	return v and v.Parent and S.VehicleService.DriverOf(v) == player
end
local function tick()
	for player, s in pairs(shifts) do
		local t = s.Task
		local st = t and t.Steps[t.Index]
		local root = rootOf(player)
		if st and root then
			local pos = root.Position
			local ok = true
			if st.Vehicle then
				ok = inVehicle(player, s)
				local ch = s.Vehicle and s.Vehicle:FindFirstChild("Chassis")
				pos = ch and ch.Position or pos
			end
			if ok and st.VehicleNear and s.Vehicle then
				local ch = s.Vehicle.Parent and s.Vehicle:FindFirstChild("Chassis")
				ok = ch ~= nil and (ch.Position - root.Position).Magnitude <= st.VehicleNear
			end
			local flat = Vector3.new(pos.X - st.Pos.X, 0, pos.Z - st.Pos.Z).Magnitude
			local inside = ok and flat <= st.Radius and math.abs(pos.Y - st.Pos.Y) < 30
			if inside and st.Kind == "Drive" then
				local ch = s.Vehicle and s.Vehicle:FindFirstChild("Chassis")
				local speed = ch and ch.AssemblyLinearVelocity.Magnitude or 0
				if speed < 6 then
					st.ArrivedAt = st.ArrivedAt or os.clock()
					if os.clock() - st.ArrivedAt >= (st.StopSeconds or 1) then
						finishStep(player, s)
					end
				else
					st.ArrivedAt = nil
				end
			elseif inside then
				if not st.ArrivedAt then
					st.ArrivedAt = os.clock()
					S.Push(player, "WorkArrive", { Id = t.Id, Step = t.Index })
				end
			else
				st.ArrivedAt = nil
			end
		end
		-- Dienstfahrzeug verloren (zerstoert/abgeschleppt): neu holen am Depot
		if s.Vehicle and not s.Vehicle.Parent then
			s.Vehicle = nil
			S.Push(player, "Notify", { Text = "Dienstfahrzeug weg - Schicht beendet, am Depot neu beginnen", Kind = "error" })
			Work.EndShift(player)
		end
	end
end

-- Rechnungen (Mechaniker im Dienst, Werkstatt-Mitarbeiter) --------------------------------------------
function Work.Invoice(player, p)
	local s = shifts[player]
	local canBill = (s and s.Job == "Mechanic") or (S.BusinessService and S.BusinessService.CanInvoice(player))
	if not canBill then
		return false, "Rechnungen nur im Mechaniker-Dienst oder als Werkstatt-Mitarbeiter"
	end
	local target = typeof(p.Target) == "number" and Players:GetPlayerByUserId(p.Target)
	if not target or target == player then
		return false, "Kunde nicht gefunden"
	end
	local r1, r2 = rootOf(player), rootOf(target)
	if not (r1 and r2) or (r1.Position - r2.Position).Magnitude > 20 then
		return false, "Kunde muss in der Naehe sein"
	end
	local amount = p.Amount
	local max = Cfg.Jobs.Mechanic.InvoiceMax
	if typeof(amount) ~= "number" or amount % 1 ~= 0 or amount < 10 or amount > max then
		return false, "Betrag $10 - " .. S.Format.money(max)
	end
	if lastInvoice[player] and os.clock() - lastInvoice[player] < 10 then
		return false, "Bitte kurz warten"
	end
	lastInvoice[player] = os.clock()
	local reason = typeof(p.Reason) == "string" and p.Reason:sub(1, 40) or "Werkstattleistung"
	local okF, filtered = pcall(function()
		return game:GetService("TextService"):FilterStringAsync(reason, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	reason = okF and filtered or "Werkstattleistung"
	local id = HttpService:GenerateGUID(false)
	invoices[target] = invoices[target] or {}
	invoices[target][id] = { From = player, Amount = amount, Reason = reason, Until = os.clock() + 120 }
	S.Push(target, "Invoice", { Id = id, From = rpName(player), Amount = amount, Reason = reason })
	return true, "Rechnung ueber " .. S.Format.money(amount) .. " an " .. rpName(target) .. " gesendet"
end

function Work.PayInvoice(player, p)
	local list = invoices[player]
	local inv = list and list[p.Id]
	if not inv then
		return false, "Rechnung nicht gefunden"
	end
	list[p.Id] = nil
	if os.clock() > inv.Until or not inv.From.Parent then
		return false, "Rechnung abgelaufen"
	end
	if p.Accept ~= true then
		S.Push(inv.From, "Notify", { Text = rpName(player) .. " hat die Rechnung abgelehnt", Kind = "warning" })
		return true, "Rechnung abgelehnt"
	end
	local method = p.Method == "Cash" and "Cash" or "Bank"
	local ok, err = S.EconomyService.Charge(player, method, inv.Amount, "Rechnung " .. rpName(inv.From) .. ": " .. inv.Reason)
	if not ok then
		S.Push(inv.From, "Notify", { Text = "Zahlung von " .. rpName(player) .. " fehlgeschlagen", Kind = "error" })
		return false, err
	end
	local share = math.floor(inv.Amount * Cfg.Jobs.Mechanic.InvoiceShare)
	S.EconomyService.Credit(inv.From, "Bank", share, "Rechnung bezahlt: " .. inv.Reason)
	if S.BusinessService then
		S.BusinessService.OnWorkshopIncome(inv.Amount - share, inv.From)
	end
	Work.AddXP(inv.From, 10, "Kunde abgerechnet")
	S.Push(inv.From, "Notify", { Text = string.format("%s hat %s bezahlt (dein Anteil %s)", rpName(player), S.Format.money(inv.Amount), S.Format.money(share)), Kind = "success" })
	return true, "Rechnung bezahlt"
end

-- Fahrzeug warten (Mechaniker): naechstes Fahrzeug volltanken - Abrechnung per Rechnung
function Work.Service(player)
	local s = shifts[player]
	if not s or s.Job ~= "Mechanic" then
		return false, "Nur im Mechaniker-Dienst"
	end
	local root = rootOf(player)
	local best, bd
	for _, v in ipairs(workspace:FindFirstChild("Vehicles") and workspace.Vehicles:GetChildren() or {}) do
		local ch = v:FindFirstChild("Chassis")
		if ch and v:GetAttribute("Fuel") and root then
			local d = (ch.Position - root.Position).Magnitude
			if d < 14 and (not bd or d < bd) then
				best, bd = v, d
			end
		end
	end
	if not best then
		return false, "Kein Kundenfahrzeug in der Naehe"
	end
	best:SetAttribute("Fuel", 100)
	return true, (best:GetAttribute("Plate") or "Fahrzeug") .. " gewartet und vollgetankt - jetzt Rechnung stellen"
end

-- Uebersicht fuer Dashboard / Handy ----------------------------------------------------------------
function Work.Info(player)
	local d = S.DataService.Get(player)
	local w = d.Work
	local lvl = Cfg.LevelFor(w.XP or 0)
	local jobs = {}
	for _, id in ipairs(Cfg.JobOrder) do
		local j = Cfg.Jobs[id]
		local st = w.Stats[id] or { Tasks = 0, Earned = 0 }
		table.insert(jobs, { Id = id, Name = j.Name, Company = j.Company, Icon = j.Icon, Desc = j.Desc, Requires = j.Requires, Location = j.Location, Hourly = j.Hourly, Tasks = j.Tasks, Level = j.Level, Unlocked = lvl >= j.Level, Done = st.Tasks, Earned = st.Earned, Uniform = j.Uniform ~= nil })
	end
	local s = shifts[player]
	local win = earnWindow[player]
	return true, nil, {
		Current = w.Job, OnShift = s ~= nil, Task = s and s.Task and { Title = s.Task.Title, Step = s.Task.Index, Steps = #s.Task.Steps, Label = s.Task.Steps[s.Task.Index] and s.Task.Steps[s.Task.Index].Label } or nil,
		Jobs = jobs, XP = w.XP or 0, Level = lvl, NextXP = Cfg.XPForLevel(lvl + 1), LevelXP = Cfg.XPForLevel(lvl), MaxLevel = Cfg.MaxLevel,
		PayBonus = math.min(Cfg.PayBonusMax, (lvl - 1) * Cfg.PayBonusPerLevel), Unlocks = Cfg.Unlocks, Earned = w.Earned or 0,
		HourEarned = win and (os.time() - win.Start < 3600) and win.Sum or 0, HourlyCap = Cfg.HourlyCap,
		Faction = d.Job.Faction, FactionDuty = d.Job.OnDuty,
	}
end

-- Studio-Test (MiamiDebug): Zustand des laufenden Auftrags
function Work.Debug(player)
	local s = shifts[player]
	local t = s and s.Task
	local st = t and t.Steps[t.Index]
	if not st then
		return "keine Schicht/kein Schritt"
	end
	local root = rootOf(player)
	local ch = s.Vehicle and s.Vehicle:FindFirstChild("Chassis")
	return string.format("%s Schritt %d/%d %s pos=%s radius=%d arrived=%s inVehicle=%s chassis=%s player=%s",
		s.Job, t.Index, #t.Steps, st.Kind, tostring(st.Pos), st.Radius, tostring(st.ArrivedAt), tostring(s.Vehicle and S.VehicleService.DriverOf(s.Vehicle) == player),
		tostring(ch and ch.Position), tostring(root and root.Position))
end

local function tbl(p)
	return typeof(p) == "table" and p or {}
end
Work.Actions = {
	["Work.Info"] = function(player)
		return Work.Info(player)
	end,
	["Work.Select"] = function(player, p)
		return Work.Select(player, tbl(p).Job)
	end,
	["Work.Quit"] = function(player)
		return Work.Quit(player)
	end,
	["Work.StartShift"] = function(player)
		return Work.StartShift(player)
	end,
	["Work.EndShift"] = function(player)
		return Work.EndShift(player)
	end,
	["Work.Action"] = function(player, p)
		return Work.Action(player, tbl(p).Id)
	end,
	["Work.Skip"] = function(player)
		return Work.Skip(player)
	end,
	["Work.Invoice"] = function(player, p)
		return Work.Invoice(player, tbl(p))
	end,
	["Work.PayInvoice"] = function(player, p)
		return Work.PayInvoice(player, tbl(p))
	end,
	["Work.Service"] = function(player)
		return Work.Service(player)
	end,
}

function Work.Start()
	S.InteractionService.Register("WorkDepot", function(player, inst)
		local d = S.DataService.Get(player)
		local jobId = inst:GetAttribute("JobId")
		if shifts[player] then
			local ok, msg = Work.EndShift(player)
			S.Push(player, "Notify", { Text = msg, Kind = ok and "info" or "error" })
			return
		end
		if d.Work.Job ~= jobId then
			-- Beruf direkt am Depot annehmen (Jobzentrum vor Ort)
			local ok, msg = Work.Select(player, jobId)
			S.Push(player, "Notify", { Text = msg, Kind = ok and "success" or "error" })
			if not ok then
				return
			end
		end
		local ok, msg = Work.StartShift(player, inst)
		S.Push(player, "Notify", { Text = msg, Kind = ok and "success" or "error" })
	end)
	S.DataService.ProfileLoaded:Connect(function(player, data)
		player:SetAttribute("WorkLevel", Cfg.LevelFor(data.Work and data.Work.XP or 0))
		player:SetAttribute("WorkJob", (data.Work and data.Work.Job ~= "") and data.Work.Job or nil)
	end)
	Players.PlayerRemoving:Connect(function(player)
		if shifts[player] then
			Work.EndShift(player)
		end
		earnWindow[player], invoices[player], lastInvoice[player] = nil, nil, nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(tick)
			if not ok then
				warn("[Work] " .. tostring(err))
			end
		end
	end)
	local _ = Items
end

return Work
