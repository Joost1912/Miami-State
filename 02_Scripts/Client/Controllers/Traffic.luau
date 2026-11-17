-- Clientseitiger NPC-Verkehr und Passanten (Prompt 12).
-- * Nur lokal: keine Server-Last, kein Netzwerkverkehr, keine Kollision (rein optisch).
-- * Autos folgen dem Strassengraphen der Stadtkarte (MapGeo.Nodes/Edges, Rechtsverkehr), halten vor Spielern,
--   Fahrzeugen und vorausfahrenden NPC-Autos. Passanten laufen zwischen Ladeneingaengen auf den Gehwegen.
-- * Begrenzt: 10 Autos (Passanten seit Prompt 14 aus) im Umkreis des Spielers; 30 Hz; abschaltbar (Handy > Einstellungen).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local TR = {}
-- Prompt 14: keine Passanten mehr (NPCs entfernt), nur Fahrzeugverkehr
local MAX_CARS, MAX_PEDS = 10, 0
local CAR_SPEED = 38
local RADIUS = 480
local folder, nodes, adj
local cars, peds = {}, {}
local enabled = true
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local PALETTE = {
	Color3.fromRGB(240, 240, 238), Color3.fromRGB(20, 20, 22), Color3.fromRGB(150, 154, 160), Color3.fromRGB(30, 60, 110),
	Color3.fromRGB(150, 24, 28), Color3.fromRGB(40, 90, 70), Color3.fromRGB(200, 180, 140), Color3.fromRGB(70, 74, 80),
}
local SKIN = { Color3.fromRGB(255, 220, 190), Color3.fromRGB(230, 180, 140), Color3.fromRGB(180, 120, 80), Color3.fromRGB(110, 70, 45) }
local SHIRT = { Color3.fromRGB(240, 240, 240), Color3.fromRGB(40, 140, 200), Color3.fromRGB(230, 110, 150), Color3.fromRGB(60, 60, 66), Color3.fromRGB(250, 200, 60), Color3.fromRGB(80, 170, 110) }

local function part(m, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = m
	return p
end

local function makeCar()
	local m = Instance.new("Model")
	m.Name = "NPCCar"
	local c = PALETTE[math.random(1, #PALETTE)]
	local base = part(m, Vector3.new(6.4, 2, 13), CFrame.new(0, 1.9, 0), c)
	m.PrimaryPart = base
	part(m, Vector3.new(5.8, 1.9, 6.8), CFrame.new(0, 3.85, 0.6), Color3.fromRGB(25, 28, 34), Enum.Material.Glass)
	part(m, Vector3.new(5.9, 0.3, 6.4), CFrame.new(0, 4.9, 0.6), c)
	for _, x in ipairs({ -3.1, 3.1 }) do
		for _, z in ipairs({ -4.2, 4.2 }) do
			part(m, Vector3.new(1, 2.4, 2.4), CFrame.new(x, 1.2, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(25, 25, 28), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
	end
	for _, x in ipairs({ -2.3, 2.3 }) do
		part(m, Vector3.new(1.2, 0.5, 0.2), CFrame.new(x, 2.3, -6.55), Color3.fromRGB(255, 250, 230), Enum.Material.Neon)
		part(m, Vector3.new(1.2, 0.5, 0.2), CFrame.new(x, 2.3, 6.55), Color3.fromRGB(200, 30, 30), Enum.Material.Neon)
	end
	return m
end

local function makePed()
	local m = Instance.new("Model")
	m.Name = "NPCPedestrian"
	local skin, shirt = SKIN[math.random(1, #SKIN)], SHIRT[math.random(1, #SHIRT)]
	local pants = PALETTE[math.random(1, #PALETTE)]
	local torso = part(m, Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), shirt)
	torso.Name = "Torso"
	m.PrimaryPart = torso
	part(m, Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 4.6, 0), skin).Name = "Head"
	local l = part(m, Vector3.new(0.95, 2, 1), CFrame.new(-0.5, 1, 0), pants)
	local r = part(m, Vector3.new(0.95, 2, 1), CFrame.new(0.5, 1, 0), pants)
	local la = part(m, Vector3.new(0.9, 2, 0.9), CFrame.new(-1.45, 3, 0), skin)
	local ra = part(m, Vector3.new(0.9, 2, 0.9), CFrame.new(1.45, 3, 0), skin)
	l.Name, r.Name, la.Name, ra.Name = "LL", "RL", "LA", "RA"
	return m
end

local function groundY(x, z, fallback)
	local hit = workspace:Raycast(Vector3.new(x, 14, z), Vector3.new(0, -40, 0), params) -- unter Baumkronen starten
	return hit and hit.Position.Y or fallback
end

local function rootPos()
	local c = Players.LocalPlayer.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return r and r.Position
end

-- Strassengraph ---------------------------------------------------------------------------------------
local function buildGraph(geo)
	nodes, adj = {}, {}
	for i, n in ipairs(geo.Nodes or {}) do
		nodes[i] = Vector3.new(n[1], 0, n[2])
		adj[i] = {}
	end
	for _, e in ipairs(geo.Edges or {}) do
		local a, b = e[1], e[2]
		if nodes[a] and nodes[b] and a ~= b then
			table.insert(adj[a], b)
			table.insert(adj[b], a)
		end
	end
end

local function spawnCar(car, around)
	-- zufaellige Kante mit Mittelpunkt 120-420 Studs vom Spieler
	for _ = 1, 40 do
		local a = math.random(1, #nodes)
		local nb = adj[a]
		if #nb > 0 then
			local b = nb[math.random(1, #nb)]
			local mid = (nodes[a] + nodes[b]) / 2
			local d = (Vector3.new(mid.X, 0, mid.Z) - Vector3.new(around.X, 0, around.Z)).Magnitude
			if d > 120 and d < 420 and (nodes[b] - nodes[a]).Magnitude > 30 then
				car.A, car.B, car.Prev = a, b, nil
				car.T = math.random() * 0.7
				car.Y = groundY(mid.X, mid.Z, around.Y)
				car.YAt = 0
				return true
			end
		end
	end
	return false
end

local function stepCar(car, dt, playerPos)
	local a, b = nodes[car.A], nodes[car.B]
	local dir = (b - a)
	local len = dir.Magnitude
	if len < 1 then
		return spawnCar(car, playerPos)
	end
	dir = dir / len
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local pos = a + dir * (car.T * len) + right * 7
	-- Hindernisse voraus (Spieler, Fahrzeuge, andere NPC-Autos)
	local ahead = pos + dir * 12
	local blocked = false
	if playerPos and (Vector3.new(playerPos.X, 0, playerPos.Z) - Vector3.new(ahead.X, 0, ahead.Z)).Magnitude < 10 then
		blocked = true
	end
	local vf = workspace:FindFirstChild("Vehicles")
	if not blocked and vf then
		for _, v in ipairs(vf:GetChildren()) do
			local ch = v:FindFirstChild("Chassis")
			if ch and (Vector3.new(ch.Position.X, 0, ch.Position.Z) - Vector3.new(ahead.X, 0, ahead.Z)).Magnitude < 11 then
				blocked = true
				break
			end
		end
	end
	if not blocked then
		for _, o in ipairs(cars) do
			if o ~= car and o.Pos and (o.Pos - ahead).Magnitude < 9 then
				blocked = true
				break
			end
		end
	end
	car.Speed = blocked and math.max(0, (car.Speed or CAR_SPEED) - 80 * dt) or math.min(CAR_SPEED, (car.Speed or 0) + 20 * dt)
	car.T += car.Speed * dt / len
	if car.T >= 1 then
		-- Kreuzung: naechste Kante (moeglichst nicht zurueck)
		local nb = adj[car.B]
		local options = {}
		for _, n in ipairs(nb) do
			if n ~= car.A then
				table.insert(options, n)
			end
		end
		if #options == 0 then
			options = nb
		end
		car.A, car.B = car.B, options[math.random(1, #options)]
		car.T = 0
		return true
	end
	car.YAt -= dt
	if car.YAt <= 0 then
		car.YAt = 0.4
		car.Y = groundY(pos.X, pos.Z, car.Y)
	end
	pos = Vector3.new(pos.X, car.Y, pos.Z)
	car.Pos = pos
	local target = CFrame.lookAt(pos, pos + dir)
	car.CF = car.CF and car.CF:Lerp(target, math.clamp(dt * 6, 0, 1)) or target
	car.Model:PivotTo(car.CF)
	return true
end

-- Passanten -------------------------------------------------------------------------------------------
local function markersNear(p, minD, maxD)
	local out = {}
	for _, m in ipairs(CollectionService:GetTagged("StoreEntrance")) do
		if m:IsA("BasePart") then
			local d = (m.Position - p).Magnitude
			if d >= minD and d <= maxD then
				table.insert(out, m)
			end
		end
	end
	return out
end

local function pedTarget(ped)
	local list = markersNear(ped.Pos, 20, 110)
	local m = #list > 0 and list[math.random(1, #list)]
	if m then
		local off = m.CFrame.LookVector * -3 + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
		ped.Goal = m.Position + off
	else
		ped.Goal = nil
	end
end

local function spawnPed(ped, around)
	local list = markersNear(around, 40, 300)
	local m = #list > 0 and list[math.random(1, #list)]
	if not m then
		return false
	end
	ped.Pos = m.Position + m.CFrame.LookVector * -4
	ped.Y = groundY(ped.Pos.X, ped.Pos.Z, ped.Pos.Y)
	ped.Wait = math.random() * 2
	pedTarget(ped)
	return true
end

local function stepPed(ped, dt)
	if ped.Wait > 0 then
		ped.Wait -= dt
		return
	end
	if not ped.Goal then
		pedTarget(ped)
		ped.Wait = 2
		return
	end
	local flat = Vector3.new(ped.Goal.X - ped.Pos.X, 0, ped.Goal.Z - ped.Pos.Z)
	local d = flat.Magnitude
	if d < 1.5 then
		ped.Goal = nil
		ped.Wait = 1 + math.random() * 4
		return
	end
	local dir = flat / d
	ped.Pos += dir * math.min(d, 6 * dt)
	ped.YAt = (ped.YAt or 0) - dt
	if ped.YAt <= 0 then
		ped.YAt = 0.5
		ped.Y = groundY(ped.Pos.X, ped.Pos.Z, ped.Y)
	end
	ped.Phase = (ped.Phase or 0) + dt * 8
	local swing = math.sin(ped.Phase) * 0.5
	local base = CFrame.lookAt(Vector3.new(ped.Pos.X, ped.Y, ped.Pos.Z), Vector3.new(ped.Pos.X, ped.Y, ped.Pos.Z) + dir)
	local m = ped.Model
	m.PrimaryPart.CFrame = base * CFrame.new(0, 3, 0)
	m.Head.CFrame = base * CFrame.new(0, 4.6, 0)
	m.LL.CFrame = base * CFrame.new(-0.5, 2, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -1, 0)
	m.RL.CFrame = base * CFrame.new(0.5, 2, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -1, 0)
	m.LA.CFrame = base * CFrame.new(-1.45, 4, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -1, 0)
	m.RA.CFrame = base * CFrame.new(1.45, 4, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -1, 0)
end

local function setEnabled(on)
	enabled = on
	if folder then
		folder.Parent = on and workspace or nil
	end
end

function TR.Start(ctx)
	local geo = ctx.Config.MapGeo
	if not geo then
		return
	end
	buildGraph(geo)
	if #nodes < 2 then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "LocalAmbient"
	folder.Parent = workspace
	params.FilterDescendantsInstances = { folder }
	local function applySettings(p)
		local s = p and p.Phone and p.Phone.Settings
		setEnabled(not s or s.Traffic ~= false)
	end
	applySettings(ctx.Profile)
	ctx.ProfileChanged:Connect(applySettings)
	for i = 1, MAX_CARS do
		cars[i] = { Model = makeCar() }
	end
	for i = 1, MAX_PEDS do
		peds[i] = { Model = makePed() }
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / 30 or not enabled then
			return
		end
		local step = acc
		acc = 0
		local p = rootPos()
		if not p or p.Y > 520 then -- Innenraeume: nichts simulieren
			for _, c in ipairs(cars) do
				c.Model.Parent = nil
			end
			for _, pd in ipairs(peds) do
				pd.Model.Parent = nil
			end
			return
		end
		local exclude = { folder }
		if Players.LocalPlayer.Character then
			table.insert(exclude, Players.LocalPlayer.Character)
		end
		params.FilterDescendantsInstances = exclude
		for _, c in ipairs(cars) do
			if not c.A or (c.Pos and (c.Pos - p).Magnitude > RADIUS) then
				c.Model.Parent = nil
				c.CF = nil
				if not spawnCar(c, p) then
					continue
				end
			end
			c.Model.Parent = folder
			stepCar(c, step, p)
		end
		for _, pd in ipairs(peds) do
			if not pd.Pos or (pd.Pos - p).Magnitude > 330 then
				pd.Model.Parent = nil
				if not spawnPed(pd, p) then
					continue
				end
			end
			pd.Model.Parent = folder
			stepPed(pd, step)
		end
	end)
end

return TR
