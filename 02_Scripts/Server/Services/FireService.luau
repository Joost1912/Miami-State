-- FireService: Brandeinsaetze der Feuerwehr (Gebaeude, Fahrzeug, Muellcontainer, Flaeche) und technische Hilfeleistung.
-- * Einsaetze entstehen automatisch (nur wenn Feuerwehr im Dienst) an Weltmarkern (Tags "FireSpot_*")
-- * Harte Obergrenzen: Einsaetze und Brandherde gesamt (Rescue.Fires.MaxIncidents / MaxFlames)
-- * Loeschen: Client meldet Treffer ueber RemoteEvent "FireSpray"; Server prueft Dienst, Werkzeug, Reichweite, Takt
-- * Ungeloeschte Herde breiten sich langsam aus; Personen im Herd nehmen Schaden (Feuerwehr in Schutzkleidung nicht)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local Rescue = require(Shared.Config.Rescue)

local FireService = {}
local S
local CFG = Rescue.Fires
local folder
local incidents = {} -- [id] = { Id, Type, Pos, Flames = {Part}, CallId, Participants = {[Player]=true}, Started, Site }
local nextIncident = 0
local nextFlame = 0
local lastSpray = {}
local rng = Random.new()

function FireService.Init(services)
	S = services
end

local function flameCount()
	local n = 0
	for _, inc in pairs(incidents) do
		n += #inc.Flames
	end
	return n
end

local function incidentCount()
	local n = 0
	for _ in pairs(incidents) do
		n += 1
	end
	return n
end

-- Brandherd ----------------------------------------------------------------------------------------
local function styleFlame(part)
	local frac = math.clamp(part:GetAttribute("HP") / part:GetAttribute("MaxHP"), 0, 1)
	local fire = part:FindFirstChildOfClass("Fire")
	if fire then
		fire.Size = 4 + 9 * frac
		fire.Heat = 6 + 12 * frac
	end
	local smoke = part:FindFirstChildOfClass("Smoke")
	if smoke then
		smoke.Opacity = 0.12 + 0.25 * frac
		smoke.Size = 6 + 10 * frac
	end
	local light = part:FindFirstChildOfClass("PointLight")
	if light then
		light.Brightness = 1 + 3 * frac
	end
	part:SetAttribute("Radius", 4 + 5 * frac)
end

local function makeFlame(inc, pos)
	if flameCount() >= CFG.MaxFlames or #inc.Flames >= CFG.MaxPerIncident then
		return nil
	end
	nextFlame += 1
	local p = Instance.new("Part")
	p.Name = "Flame_" .. nextFlame
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true -- Client-Raycast beim Loeschen
	p.Transparency = 1
	p.Size = Vector3.new(6, 6, 6)
	p.Position = pos + Vector3.new(0, 2, 0)
	local hp = CFG.Types[inc.Type].HP
	p:SetAttribute("HP", hp)
	p:SetAttribute("MaxHP", hp)
	p:SetAttribute("IncidentId", inc.Id)
	local fire = Instance.new("Fire")
	fire.Color = Color3.fromRGB(255, 120, 30)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
	fire.Parent = p
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(60, 60, 64)
	smoke.RiseVelocity = 7
	smoke.Parent = p
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 50)
	light.Range = 26
	light.Shadows = false
	light.Parent = p
	styleFlame(p)
	CollectionService:AddTag(p, "Flame")
	p.Parent = folder
	table.insert(inc.Flames, p)
	return p
end

-- Einsatz ------------------------------------------------------------------------------------------
local function spotsOf(kind)
	local list = {}
	for _, m in ipairs(CollectionService:GetTagged(CFG.Types[kind].Spot)) do
		if m:IsDescendantOf(workspace) then
			local busy = false
			for _, inc in pairs(incidents) do
				if (inc.Pos - m.Position).Magnitude < 60 then
					busy = true
				end
			end
			if not busy then
				table.insert(list, m)
			end
		end
	end
	return list
end

local function addRescueSite(inc, cf)
	-- Unfallfahrzeug (verankerte Kopie) + Arbeitsaufforderung fuer die Feuerwehr
	local site = Instance.new("Model")
	site.Name = "RescueSite_" .. inc.Id
	local template = ServerStorage:FindFirstChild("Vehicles") and ServerStorage.Vehicles:FindFirstChild("Vehicle_Sedan")
	if template then
		local car = template:Clone()
		CollectionService:RemoveTag(car, "Vehicle")
		for _, d in ipairs(car:GetDescendants()) do
			if d:IsA("Constraint") or d:IsA("Light") or d:IsA("Sound") then
				d:Destroy()
			elseif d:IsA("Seat") or d:IsA("VehicleSeat") then
				d.Disabled = true
			end
		end
		for _, d in ipairs(car:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		car:PivotTo(cf * CFrame.new(0, 2.2, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(14)))
		car.Parent = site
		local smoke = Instance.new("Smoke")
		smoke.Opacity = 0.15
		smoke.Color = Color3.fromRGB(120, 120, 124)
		smoke.Parent = car.PrimaryPart
	end
	local anchor = Instance.new("Part")
	anchor.Name = "WorkPoint"
	anchor.Anchored, anchor.CanCollide, anchor.Transparency = true, false, 1
	anchor.Size = Vector3.new(2, 2, 2)
	anchor.CFrame = cf * CFrame.new(5, 3, 0)
	anchor.Parent = site
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Technische Hilfe leisten"
	prompt.ObjectText = "Eingeklemmte Person"
	prompt.HoldDuration = CFG.Types.Rescue.WorkSeconds
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		if not S.RescueService.IsResponder(player, "Fire", "Fire.Rescue") then
			S.Push(player, "Notify", { Text = "Nur Feuerwehr im Dienst (ab Senior Firefighter)", Kind = "error" })
			return
		end
		inc.Participants[player] = true
		FireService.Complete(inc.Id, "Person befreit")
	end)
	site.Parent = folder
	inc.Site = site
end

function FireService.StartIncident(kind, cf, reason)
	local def = CFG.Types[kind]
	if not def then
		return nil, "Unbekannte Einsatzart"
	end
	if incidentCount() >= CFG.MaxIncidents then
		return nil, "Maximale Anzahl gleichzeitiger Einsaetze erreicht"
	end
	if def.Flames[2] > 0 and flameCount() >= CFG.MaxFlames then
		return nil, "Maximale Anzahl Brandherde erreicht"
	end
	nextIncident += 1
	local inc = { Id = nextIncident, Type = kind, Pos = cf.Position, Flames = {}, Participants = {}, Started = os.time() }
	incidents[inc.Id] = inc
	if kind == "Rescue" then
		addRescueSite(inc, cf)
	else
		local n = rng:NextInteger(def.Flames[1], def.Flames[2])
		for i = 1, n do
			local off = (i == 1) and Vector3.zero or Vector3.new(rng:NextNumber(-9, 9), 0, rng:NextNumber(-9, 9))
			makeFlame(inc, cf.Position + off)
		end
	end
	local call = S.DispatchService.CreateSystemCall(def.Category, cf.Position, (reason or "Automatische Brandmeldeanlage") .. " - " .. def.Name)
	inc.CallId = call and call.Id
	S.Log("Fire", nil, nil, string.format("Einsatz %d %s gestartet (%d Herde)", inc.Id, kind, #inc.Flames))
	return inc
end

local function participantsNear(inc)
	for _, p in ipairs(Players:GetPlayers()) do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r and S.RescueService.IsResponder(p, "Fire") and (r.Position - inc.Pos).Magnitude <= CFG.ParticipationRadius then
			inc.Participants[p] = true
		end
	end
end

function FireService.Complete(id, text)
	local inc = incidents[id]
	if not inc then
		return
	end
	incidents[id] = nil
	for _, f in ipairs(inc.Flames) do
		f:Destroy()
	end
	if inc.Site then
		inc.Site:Destroy()
	end
	participantsNear(inc)
	local def = CFG.Types[inc.Type]
	local reward = CFG.Reward.Base + CFG.Reward.PerFlame * (inc.TotalFlames or 0)
	for p in pairs(inc.Participants) do
		if p.Parent and S.RescueService.IsResponder(p, "Fire") then
			S.EconomyService.Credit(p, "Bank", reward, "Einsatzpraemie: " .. def.Name)
			S.RescueService.AddStat(p, "Fire", "Incidents", 1)
			S.Push(p, "Notify", { Text = string.format("Einsatz abgeschlossen: %s - Praemie $%d", def.Name, reward), Kind = "success" })
		end
	end
	if inc.CallId then
		S.DispatchService.CloseSystem(inc.CallId, text or "Feuer aus")
	end
	S.Log("Fire", nil, nil, string.format("Einsatz %d abgeschlossen", id))
end

-- Loeschen -----------------------------------------------------------------------------------------
local function hasEngineNear(pos, range)
	for _, v in ipairs(S.VehicleService.All()) do
		local t = v:GetAttribute("VehicleType")
		local ch = v:FindFirstChild("Chassis")
		if ch and (t == "FireEngine" or t == "LadderTruck") and (ch.Position - pos).Magnitude <= range then
			return true
		end
	end
	return false
end

local function onSpray(player, flame)
	if typeof(flame) ~= "Instance" or not flame:IsA("BasePart") or flame.Parent ~= folder or not CollectionService:HasTag(flame, "Flame") then
		return
	end
	if not S.RescueService.IsResponder(player, "Fire", "Fire.Extinguish") then
		return
	end
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local kind = tool and tool:GetAttribute("FireTool")
	local def = kind and CFG.Tools[kind]
	if not def then
		return
	end
	local now = os.clock()
	if lastSpray[player] and now - lastSpray[player] < def.Interval * 0.8 then
		return
	end
	lastSpray[player] = now
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - flame.Position).Magnitude > def.Range + (flame:GetAttribute("Radius") or 4) then
		return
	end
	if def.NeedsEngine and not hasEngineNear(root.Position, def.NeedsEngine) then
		if not lastSpray[tool] or now - lastSpray[tool] > 4 then
			lastSpray[tool] = now
			S.Push(player, "Notify", { Text = "Kein Wasser: Loeschfahrzeug (Engine/Ladder) muss in der Naehe stehen", Kind = "warning" })
		end
		return
	end
	if def.Charges then
		local left = tool:GetAttribute("Charges") or def.Charges
		if left <= 0 then
			return
		end
		tool:SetAttribute("Charges", left - 1)
	end
	local inc = incidents[flame:GetAttribute("IncidentId")]
	if inc then
		inc.Participants[player] = true
	end
	local hp = flame:GetAttribute("HP") - def.Power
	if hp <= 0 then
		if inc then
			local i = table.find(inc.Flames, flame)
			if i then
				table.remove(inc.Flames, i)
			end
			inc.TotalFlames = (inc.TotalFlames or 0) + 1
		end
		flame:Destroy()
		S.RescueService.AddStat(player, "Fire", "Extinguished", 1)
		if inc and #inc.Flames == 0 then
			FireService.Complete(inc.Id, "Feuer aus")
		end
	else
		flame:SetAttribute("HP", hp)
		styleFlame(flame)
	end
end

function FireService.Active()
	local list = {}
	for _, inc in pairs(incidents) do
		table.insert(list, { Id = inc.Id, Type = inc.Type, Flames = #inc.Flames, X = inc.Pos.X, Z = inc.Pos.Z, CallId = inc.CallId })
	end
	return list
end

-- Fuellt Feuerloescher an Fahrzeugen/Wache wieder auf
function FireService.Refill(player)
	if not S.RescueService.IsResponder(player, "Fire") then
		return false, "Nur Feuerwehr im Dienst"
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not (hasEngineNear(root.Position, 25) or S.InteractionService.NearestOfType(player, Rescue.Fire.EquipmentTerminal, 20)) then
		return false, "Nur am Loeschfahrzeug oder im Geraeteraum"
	end
	for _, holder in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		for _, t in ipairs(holder and holder:GetChildren() or {}) do
			if t:IsA("Tool") and t:GetAttribute("FireTool") == "Extinguisher" then
				t:SetAttribute("Charges", CFG.Tools.Extinguisher.Charges)
			end
		end
	end
	return true, "Feuerloescher aufgefuellt"
end

-- Schleifen ----------------------------------------------------------------------------------------
local function fireOnDuty()
	for _, p in ipairs(Players:GetPlayers()) do
		if S.RescueService.IsResponder(p, "Fire") then
			return true
		end
	end
	return false
end

local AUTO_KINDS = { "Dumpster", "Dumpster", "Vehicle", "Vehicle", "Building", "Brush", "Rescue" }

function FireService.Start()
	folder = workspace:FindFirstChild("ActiveFires") or Instance.new("Folder")
	folder.Name = "ActiveFires"
	folder:ClearAllChildren()
	folder.Parent = workspace
	local spray = S.Remotes.FireSpray
	spray.OnServerEvent:Connect(onSpray)
	Players.PlayerRemoving:Connect(function(p)
		lastSpray[p] = nil
		for _, inc in pairs(incidents) do
			inc.Participants[p] = nil
		end
	end)

	-- Schaden im Brandherd (1 Hz)
	task.spawn(function()
		while true do
			task.wait(1)
			if next(incidents) then
				local flames = CollectionService:GetTagged("Flame")
				for _, p in ipairs(Players:GetPlayers()) do
					local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
					if r and not S.RescueService.IsResponder(p, "Fire") then
						for _, f in ipairs(flames) do
							if (f.Position - r.Position).Magnitude <= (f:GetAttribute("Radius") or 4) then
								S.MedicalService.Damage(p, CFG.DamagePerSecond, "Verbrennung")
								break
							end
						end
					end
				end
			end
		end
	end)

	-- Ausbreitung und Ablauf
	task.spawn(function()
		while true do
			task.wait(CFG.SpreadEvery)
			for id, inc in pairs(incidents) do
				if os.time() - inc.Started > 30 * 60 then
					FireService.Complete(id, "Einsatzstelle uebergeben (Zeitablauf)")
				elseif #inc.Flames > 0 and #inc.Flames < CFG.MaxPerIncident then
					local base = inc.Flames[rng:NextInteger(1, #inc.Flames)]
					makeFlame(inc, base.Position - Vector3.new(0, 2, 0) + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10)))
				end
			end
		end
	end)

	-- automatische Einsaetze (nur wenn Feuerwehr im Dienst)
	task.spawn(function()
		while true do
			task.wait(rng:NextInteger(CFG.AutoIncidentEvery[1], CFG.AutoIncidentEvery[2]))
			if fireOnDuty() and incidentCount() < CFG.MaxIncidents then
				local kind = AUTO_KINDS[rng:NextInteger(1, #AUTO_KINDS)]
				local spots = spotsOf(kind)
				if #spots > 0 then
					FireService.StartIncident(kind, spots[rng:NextInteger(1, #spots)].CFrame)
				end
			end
		end
	end)
end

-- fuer Tests in Studio
function FireService._startNear(player, kind)
	local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not r then
		return nil, "kein Charakter"
	end
	return FireService.StartIncident(kind or "Dumpster", r.CFrame * CFrame.new(0, -3, -20), "Test")
end

return FireService
