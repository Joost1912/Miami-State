-- Schritt 27 (Prompt 12): Miami Motor Gallery (modernes Autohaus als echtes Gebaeude), Muscle-Car-Vorlage,
-- Downtown-Aufwertung (Sitzbaenke, Blumenbeete, Muelleimer, Imbissstaende).
-- Idempotent: workspace.Map.Prompt12 wird neu gebaut. Nichts Bestehendes wird veraendert oder entfernt.
return function(Kit)
	local CollectionService = game:GetService("CollectionService")
	local ServerStorage = game:GetService("ServerStorage")
	local rgb = Color3.fromRGB
	local M = Enum.Material

	local root = workspace.Map:FindFirstChild("Prompt12")
	if root then
		root:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "Prompt12"
	root.Parent = workspace.Map
	local log = {}

	local function model(parent, name)
		local m = Instance.new("Model")
		m.Name = name
		m.Parent = parent
		return m
	end
	local function mk(parent, name, size, cf, color, mat, o)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color or rgb(200, 200, 200)
		p.Material = mat or M.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		for k, v in pairs(o or {}) do
			p[k] = v
		end
		p.Parent = parent
		return p
	end
	local function signText(part, face, text, color, font)
		local sg = Instance.new("SurfaceGui")
		sg.Face = face or Enum.NormalId.Front
		sg.PixelsPerStud = 40
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.LightInfluence = 0
		sg.Parent = part
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextScaled = true
		l.Font = font or Enum.Font.GothamBlack
		l.TextColor3 = color or rgb(255, 255, 255)
		l.Parent = sg
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0.04, 0), UDim.new(0.04, 0)
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
		pad.Parent = l
		return l
	end
	local function interact(parent, name, cf, kind, text, objectText, attrs)
		local p = mk(parent, name, Vector3.new(3, 5, 1), cf, rgb(255, 255, 255), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		p:SetAttribute("InteractType", kind)
		p:SetAttribute("InteractText", text)
		p:SetAttribute("ObjectText", objectText)
		p:SetAttribute("Range", 10)
		for k, v in pairs(attrs or {}) do
			p:SetAttribute(k, v)
		end
		CollectionService:AddTag(p, "Interactable")
		return p
	end
	local function light(p, kind, range, brightness, color)
		local l = Instance.new(kind or "PointLight")
		l.Range = range or 16
		l.Brightness = brightness or 1
		l.Color = color or rgb(255, 244, 228)
		if l:IsA("SpotLight") or l:IsA("SurfaceLight") then
			l.Face = Enum.NormalId.Bottom
			l.Angle = 70
		end
		l.Parent = p
		return l
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root, workspace.Terrain }
	local function hit(x, z, fromY)
		return workspace:Raycast(Vector3.new(x, fromY or 400, z), Vector3.new(0, -(fromY or 400) - 100, 0), params)
	end

	----------------------------------------------------------------------------------------------------
	-- 1) MUSCLE-CAR-VORLAGE (Variante des Sportwagens: Hutze, Rennstreifen, breites Heck)
	----------------------------------------------------------------------------------------------------
	do
		local V = ServerStorage.Vehicles
		local old = V:FindFirstChild("Vehicle_Muscle")
		if old then
			old:Destroy()
		end
		local m = V.Vehicle_Sports:Clone()
		m.Name = "Vehicle_Muscle"
		m:SetAttribute("VehicleType", "Muscle")
		m:SetAttribute("MaxSpeed", 124)
		m:SetAttribute("Torque", 3100)
		m:SetAttribute("BrakeTorque", 5600)
		m:SetAttribute("MaxSteer", 26)
		local ch = m.Chassis
		local base = m.Body:FindFirstChild("LowerBody")
		local bc = base and base.Color
		for _, p in ipairs(m.Body:GetChildren()) do
			if p:IsA("BasePart") and bc and p.Color == bc then
				p.Color = rgb(25, 45, 95)
			elseif p:IsA("BasePart") and (p.Name == "Spoiler" or p.Name == "SpoilerPost") then
				p.Transparency = 1
				p.CanCollide = false
			end
		end
		local function add(name, size, off, color, mat)
			local p = mk(m.Body, name, size, ch.CFrame * off, color, mat)
			p.Anchored, p.Massless, p.CanCollide = false, true, false
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = p, ch
			w.Parent = p
			return p
		end
		local hood = m.Body:FindFirstChild("Hood")
		local hy = hood and ch.CFrame:ToObjectSpace(hood.CFrame).Y + hood.Size.Y / 2 or 2
		local hz = hood and ch.CFrame:ToObjectSpace(hood.CFrame).Z or -5
		add("HoodScoop", Vector3.new(2.2, 0.7, 2.6), CFrame.new(0, hy + 0.35, hz), rgb(20, 20, 22))
		for _, x in ipairs({ -0.7, 0.7 }) do
			add("RaceStripe", Vector3.new(0.5, 0.06, 15.4), CFrame.new(x, hy + 0.03, 0), rgb(240, 240, 240))
		end
		add("DuckTail", Vector3.new(7.4, 0.35, 1), CFrame.new(0, hy + 0.2, 7.6), rgb(20, 20, 22))
		m.Parent = V
		table.insert(log, "Vorlage Vehicle_Muscle")
	end

	----------------------------------------------------------------------------------------------------
	-- 2) MIAMI MOTOR GALLERY (Ausstellungsgelaende Sawgrass Motors)
	----------------------------------------------------------------------------------------------------
	local gallery = model(root, "MiamiMotorGallery")
	local GX, GZ = -2720, 1150 -- freie Flaeche des Gelaendes (Park im Norden bleibt unberuehrt)
	local h0 = hit(GX, GZ)
	local gy = h0 and h0.Position.Y or 0.6
	local o = CFrame.new(GX, gy, GZ) -- Front (Eingang) zeigt nach +Z (Sueden, zur Strasse)
	local W, D, H = 128, 72, 22
	local shell = model(gallery, "Building")
	mk(shell, "Plinth", Vector3.new(W + 8, 1.2, D + 8), o * CFrame.new(0, 0.6, 0), rgb(210, 212, 216), M.Concrete)
	mk(shell, "Floor", Vector3.new(W, 0.4, D), o * CFrame.new(0, 1.4, 0), rgb(236, 238, 242), M.Marble, { Reflectance = 0.08 })
	local FY = gy + 1.6
	mk(shell, "Roof", Vector3.new(W + 4, 1.6, D + 4), o * CFrame.new(0, H + 1.2, 0), rgb(34, 36, 42), M.Metal)
	mk(shell, "Canopy", Vector3.new(W + 4, 1, 14), o * CFrame.new(0, H + 0.8, D / 2 + 9), rgb(34, 36, 42), M.Metal)
	mk(shell, "CanopyEdge", Vector3.new(W + 4, 0.3, 0.3), o * CFrame.new(0, H + 0.2, D / 2 + 16), rgb(64, 224, 255), M.Neon)
	for i = 0, 6 do
		local lp = mk(shell, "CanopyLight", Vector3.new(4, 0.1, 4), o * CFrame.new(-W / 2 + 10 + i * (W - 20) / 6, H + 0.25, D / 2 + 9), rgb(255, 250, 240), M.Neon, { CanCollide = false })
		if i % 2 == 0 then
			light(lp, "SpotLight", 26, 1.3)
		end
	end
	-- Glasfassade mit Pfosten (drei Seiten), Rueckwand massiv mit Logo
	local function curtain(len, cf, gapCenter, gapWidth)
		local n = math.floor(len / 8)
		for i = 0, n do
			local x = -len / 2 + i * len / n
			mk(shell, "Mullion", Vector3.new(0.5, H, 0.6), cf * CFrame.new(x, 1.4 + H / 2, 0), rgb(30, 32, 38), M.Metal)
		end
		mk(shell, "Transom", Vector3.new(len, 0.5, 0.6), cf * CFrame.new(0, 1.4 + 12, 0), rgb(30, 32, 38), M.Metal)
		local segs = gapWidth and { { -len / 2, gapCenter - gapWidth / 2 }, { gapCenter + gapWidth / 2, len / 2 } } or { { -len / 2, len / 2 } }
		for _, s in ipairs(segs) do
			local w = s[2] - s[1]
			if w > 0.5 then
				mk(shell, "Glass", Vector3.new(w, H, 0.3), cf * CFrame.new((s[1] + s[2]) / 2, 1.4 + H / 2, 0), rgb(160, 205, 225), M.Glass, { Transparency = 0.72, Reflectance = 0.18 })
			end
		end
		if gapWidth then
			mk(shell, "Lintel", Vector3.new(gapWidth, H - 11, 0.4), cf * CFrame.new(gapCenter, 1.4 + 11 + (H - 11) / 2, 0), rgb(160, 205, 225), M.Glass, { Transparency = 0.72, Reflectance = 0.18 })
		end
	end
	curtain(W, o * CFrame.new(0, 0, D / 2), 0, 16) -- Front mit Eingang
	curtain(D, o * CFrame.new(W / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0))
	curtain(D, o * CFrame.new(-W / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0))
	local back = mk(shell, "BackWall", Vector3.new(W, H, 1), o * CFrame.new(0, 1.4 + H / 2, -D / 2), rgb(245, 245, 245), M.SmoothPlastic)
	local logo = mk(shell, "Logo", Vector3.new(44, 4, 0.2), o * CFrame.new(0, 15, -D / 2 + 0.6), rgb(14, 16, 22), M.SmoothPlastic)
	signText(logo, Enum.NormalId.Back, "MIAMI MOTOR GALLERY", rgb(64, 224, 255))
	local _ = back
	-- Aussenschild ueber dem Vordach + Pylon
	local fs = mk(shell, "FrontSign", Vector3.new(50, 4, 0.6), o * CFrame.new(0, H + 4, D / 2 + 1), rgb(14, 16, 22), M.SmoothPlastic)
	signText(fs, Enum.NormalId.Back, "MIAMI MOTOR GALLERY", rgb(255, 255, 255))
	signText(fs, Enum.NormalId.Front, "MIAMI MOTOR GALLERY", rgb(255, 255, 255))
	CollectionService:AddTag(mk(shell, "SignGlow", Vector3.new(50, 0.2, 0.2), o * CFrame.new(0, H + 1.9, D / 2 + 1.4), rgb(64, 224, 255), M.Neon), "NightAccent")
	local py = model(gallery, "Pylon")
	mk(py, "Pylon", Vector3.new(4, 30, 2), o * CFrame.new(W / 2 + 6, 15, D / 2 + 26), rgb(30, 32, 38), M.Metal)
	local pyFace = mk(py, "PylonFace", Vector3.new(3.4, 20, 0.2), o * CFrame.new(W / 2 + 6, 18, D / 2 + 27.1), rgb(64, 224, 255), M.Neon)
	signText(pyFace, Enum.NormalId.Back, "MMG", rgb(10, 12, 16))
	-- Innen: Deckenlicht (Flaechenleuchten), Pflanzen
	for ix = 0, 3 do
		for iz = 0, 1 do
			local lp = mk(shell, "Ceiling", Vector3.new(14, 0.2, 10), o * CFrame.new(-45 + ix * 30, H + 0.3, -16 + iz * 30), rgb(255, 252, 245), M.Neon, { CanCollide = false })
			light(lp, "SurfaceLight", 34, 0.9)
		end
	end
	local function plant(cf)
		mk(gallery, "Pot", Vector3.new(2.4, 2.6, 2.4), cf * CFrame.new(0, 1.3, 0), rgb(40, 40, 44), M.SmoothPlastic)
		for i = 0, 5 do
			mk(gallery, "Leaf", Vector3.new(0.4, 0.15, 3.2), cf * CFrame.new(0, 4.4, 0) * CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.new(0, 0, -1.4) * CFrame.Angles(math.rad(-25), 0, 0), rgb(60, 140, 70), M.Grass, { CanCollide = false })
		end
		mk(gallery, "Stem", Vector3.new(0.3, 3, 0.3), cf * CFrame.new(0, 3.2, 0), rgb(110, 80, 50), M.Wood)
	end
	local fo = CFrame.new(GX, FY, GZ)
	for _, p in ipairs({ { -60, 32 }, { 60, 32 }, { -60, -30 }, { 60, -30 }, { -10, 30 }, { 10, 30 } }) do
		plant(fo * CFrame.new(p[1], 0, p[2]))
	end
	-- Empfang (geschwungene Theke) + Interaktion
	local desk = model(gallery, "Reception")
	for i = -1, 1 do
		mk(desk, "Desk", Vector3.new(6, 3.6, 2.4), fo * CFrame.new(i * 5.6, 1.8, 18) * CFrame.Angles(0, math.rad(-i * 18), 0), rgb(245, 245, 245), M.Marble)
		mk(desk, "DeskTop", Vector3.new(6.2, 0.25, 2.6), fo * CFrame.new(i * 5.6, 3.7, 18) * CFrame.Angles(0, math.rad(-i * 18), 0), rgb(30, 32, 38), M.Metal)
	end
	mk(desk, "DeskGlow", Vector3.new(17, 0.2, 0.2), fo * CFrame.new(0, 0.3, 19.3), rgb(64, 224, 255), M.Neon)
	interact(desk, "ReceptionInteract", fo * CFrame.new(0, 2.6, 21) * CFrame.Angles(0, math.pi, 0), "Dealer", "Beratung & Kauf", "Miami Motor Gallery", { DealerId = "Gallery" })
	-- Verkaufsbueros (Rueckseite, Glaswaende)
	for i = 0, 2 do
		local oc = fo * CFrame.new(-36 + i * 36, 0, -D / 2 + 9)
		local off = model(gallery, "SalesOffice" .. (i + 1))
		mk(off, "GlassFront", Vector3.new(18, 10, 0.3), oc * CFrame.new(-3, 5, 8), rgb(180, 215, 230), M.Glass, { Transparency = 0.65 })
		mk(off, "GlassSide", Vector3.new(0.3, 10, 16), oc * CFrame.new(11, 5, 0), rgb(180, 215, 230), M.Glass, { Transparency = 0.65 })
		mk(off, "GlassSide", Vector3.new(0.3, 10, 16), oc * CFrame.new(-11, 5, 0), rgb(180, 215, 230), M.Glass, { Transparency = 0.65 })
		mk(off, "OfficeDesk", Vector3.new(7, 2.8, 3.2), oc * CFrame.new(0, 1.4, -2), rgb(60, 50, 44), M.Wood)
		mk(off, "Monitor", Vector3.new(2.4, 1.5, 0.2), oc * CFrame.new(0, 3.6, -3), rgb(10, 10, 12), M.Glass)
		for _, s in ipairs({ -1.6, 1.6 }) do
			local seat = Instance.new("Seat")
			seat.Anchored = true
			seat.Size = Vector3.new(2, 0.6, 2)
			seat.CFrame = oc * CFrame.new(s, 1.4, 1.6) * CFrame.Angles(0, math.pi, 0)
			seat.Color = rgb(40, 40, 44)
			seat.Parent = off
			mk(off, "Back", Vector3.new(2, 2, 0.3), oc * CFrame.new(s, 2.8, 2.6), rgb(40, 40, 44), M.Fabric)
		end
		local plate = mk(off, "OfficeSign", Vector3.new(6, 1, 0.1), oc * CFrame.new(-3, 9, 8.2), rgb(14, 16, 22))
		signText(plate, Enum.NormalId.Back, "VERKAUF " .. (i + 1), rgb(64, 224, 255))
		interact(off, "OfficeInteract", oc * CFrame.new(0, 2.6, 0.5) * CFrame.Angles(0, math.pi, 0), "Dealer", "Verkaufsberatung", "Verkaufsbuero " .. (i + 1), { DealerId = "Gallery" })
	end
	-- Lounge mit Kaffeebar
	local lounge = model(gallery, "Lounge")
	local lc = fo * CFrame.new(52, 0, -8)
	for _, r in ipairs({ 0, math.pi / 2 }) do
		mk(lounge, "Sofa", Vector3.new(9, 1.6, 3.2), lc * CFrame.Angles(0, r, 0) * CFrame.new(0, 0.8, 5), rgb(50, 52, 60), M.Fabric)
		mk(lounge, "SofaBack", Vector3.new(9, 2.2, 0.8), lc * CFrame.Angles(0, r, 0) * CFrame.new(0, 2.2, 6.3), rgb(50, 52, 60), M.Fabric)
	end
	mk(lounge, "Table", Vector3.new(4, 1.4, 4), lc * CFrame.new(-1, 0.7, 1), rgb(20, 20, 22), M.Glass)
	mk(lounge, "CoffeeBar", Vector3.new(10, 3.6, 2.6), lc * CFrame.new(0, 1.8, -12), rgb(30, 32, 38), M.Metal)
	-- Ausstellung: 7 Klassen auf Drehtellern mit Spots
	local displays = {
		{ "Compact", rgb(240, 120, 40) }, { "SUV", rgb(240, 240, 238) }, { "Pickup", rgb(170, 20, 28) }, { "Muscle", rgb(25, 45, 95) },
		{ "LuxurySedan", rgb(20, 20, 22) }, { "Sports", rgb(240, 200, 40) }, { "Supercar", rgb(255, 72, 168) },
	}
	local function displayCar(parent, typeName, cf, color)
		local t = ServerStorage.Vehicles:FindFirstChild("Vehicle_" .. typeName)
		if not t then
			return
		end
		local m = t:Clone()
		m.Name = "Display_" .. typeName
		CollectionService:RemoveTag(m, "Vehicle")
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("Constraint") or d:IsA("WeldConstraint") or d:IsA("Weld") or d:IsA("ProximityPrompt") then
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
		local base = m.Body:FindFirstChild("LowerBody")
		local bc = base and base.Color
		if color then
			for _, p in ipairs(m.Body:GetChildren()) do
				if p:IsA("BasePart") and bc and p.Color == bc then
					p.Color = color
				end
			end
		end
		m:PivotTo(cf)
		local bb, bs = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + Vector3.new(0, cf.Y - (bb.Y - bs.Y / 2), 0))
		m.Parent = parent
		return m
	end
	local show = model(gallery, "Showroom")
	for i, dsp in ipairs(displays) do
		local col = (i - 1) % 4
		local row = math.floor((i - 1) / 4)
		local dx = -48 + col * 32 + row * 16
		local dz = row == 0 and -2 or 4
		dz = row == 0 and 8 or -8
		local dcf = fo * CFrame.new(dx, 0, dz)
		local disc = mk(show, "Turntable", Vector3.new(0.6, 15, 15), dcf * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(30, 32, 38), M.Metal, { Shape = Enum.PartType.Cylinder })
		local _ = disc
		mk(show, "Ring", Vector3.new(0.2, 15.6, 15.6), dcf * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(64, 224, 255), M.Neon, { Shape = Enum.PartType.Cylinder, CanCollide = false })
		displayCar(show, dsp[1], dcf * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, math.rad(30 + i * 23), 0), dsp[2])
		local spot = mk(show, "Spot", Vector3.new(1, 0.6, 1), dcf * CFrame.new(0, H - 0.6, 0), rgb(30, 32, 38), M.Metal, { CanCollide = false })
		light(spot, "SpotLight", 26, 1.6, rgb(255, 248, 235))
	end
	-- NPC-Personal (Kopie eines bestehenden NPC-Modells, verankert, ohne Skripte)
	local npcSrc = workspace.Map:FindFirstChild("Gameplay") and workspace.Map.Gameplay:FindFirstChild("JobCenter") and workspace.Map.Gameplay.JobCenter:FindFirstChild("Jobcenter-Mitarbeiterin")
	local staff = 0
	local function npc(cf, name)
		if not npcSrc then
			return
		end
		local n = npcSrc:Clone()
		n.Name = name
		for _, d in ipairs(n:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		n:PivotTo(cf * CFrame.new(0, 3, 0))
		local bb, bs = n:GetBoundingBox()
		n:PivotTo(n:GetPivot() + Vector3.new(0, cf.Y - (bb.Y - bs.Y / 2), 0))
		n.Parent = gallery
		staff += 1
	end
	npc(fo * CFrame.new(0, 0, 16), "Empfang")
	for i = 0, 2 do
		npc(fo * CFrame.new(-36 + i * 36, 0, -D / 2 + 4.5), "Verkaeufer" .. (i + 1))
	end
	npc(fo * CFrame.new(46, 0, -2) * CFrame.Angles(0, math.rad(-90), 0), "Verkaeufer_Lounge")
	-- Aussenbereich: Ausstellungsreihe, Kundenparkplaetze, Fahnen, Laternen, Probefahrt, Garage
	local outside = model(gallery, "Outdoor")
	local oz = GZ + D / 2 + 34
	local outCars = { { "Sedan", rgb(30, 60, 110) }, { "LuxurySUV", rgb(200, 180, 140) }, { "Convertible", rgb(240, 240, 238) }, { "Muscle", rgb(170, 20, 28) }, { "Pickup", rgb(70, 74, 80) }, { "Compact", rgb(64, 200, 200) } }
	for i, c in ipairs(outCars) do
		local x = GX - 70 + (i - 1) * 28
		local hh = hit(x, oz)
		local yy = hh and hh.Position.Y or gy
		mk(outside, "DisplayPad", Vector3.new(14, 0.3, 22), CFrame.new(x, yy + 0.15, oz), rgb(225, 228, 232), M.Concrete)
		displayCar(outside, c[1], CFrame.new(x, yy + 0.3, oz) * CFrame.Angles(0, math.rad(180), 0), c[2])
		local tag = mk(outside, "PriceTag", Vector3.new(4, 1.6, 0.2), CFrame.new(x, yy + 3.4, oz + 12.4), rgb(14, 16, 22))
		local Vcfg = require(game.ReplicatedStorage.MiamiShared.Config.Vehicles:Clone())
		local mdl = Vcfg.ById[c[1]]
		signText(tag, Enum.NormalId.Back, mdl and ("$" .. tostring(mdl.Price)) or "", rgb(80, 220, 140))
		mk(outside, "TagPost", Vector3.new(0.3, 3, 0.3), CFrame.new(x, yy + 1.5, oz + 12.5), rgb(30, 32, 38), M.Metal)
	end
	for i = 0, 3 do
		local x = GX - 60 + i * 40
		local hh = hit(x, oz + 42)
		local yy = hh and hh.Position.Y or gy
		mk(outside, "FlagPole", Vector3.new(0.5, 26, 0.5), CFrame.new(x, yy + 13, oz + 42), rgb(220, 222, 226), M.Metal)
		mk(outside, "Flag", Vector3.new(0.2, 8, 4), CFrame.new(x, yy + 21, oz + 44), i % 2 == 0 and rgb(64, 224, 255) or rgb(255, 72, 168), M.Fabric)
		local lamp = mk(outside, "LotLamp", Vector3.new(0.5, 16, 0.5), CFrame.new(x + 20, yy + 8, oz + 42), rgb(40, 40, 44), M.Metal)
		local head = mk(outside, "LampHead", Vector3.new(3, 0.5, 1.4), CFrame.new(x + 20, yy + 16, oz + 42), rgb(255, 245, 225), M.Neon)
		CollectionService:AddTag(head, "NightAccent")
		light(head, "SpotLight", 40, 1.2)
		local _ = lamp
	end
	-- Kundenparkplaetze (Garage-Ausparken in der Naehe)
	for i = 0, 5 do
		local x = GX - 30 + i * 12
		local hh = hit(x, oz + 22)
		local yy = hh and hh.Position.Y or gy
		local spot = mk(outside, "CustomerParking", Vector3.new(10, 0.1, 18), CFrame.new(x, yy + 0.06, oz + 22), rgb(240, 240, 240), M.SmoothPlastic, { Transparency = 0.85, CanCollide = false })
		CollectionService:AddTag(spot, "VehicleParkSpot")
	end
	local pad = mk(outside, "TestDrivePad", Vector3.new(12, 0.2, 20), CFrame.new(GX + 70, gy + 0.1, oz), rgb(64, 224, 255), M.Neon, { Transparency = 0.6, CanCollide = false })
	pad:SetAttribute("DealerId", "Gallery")
	CollectionService:AddTag(pad, "TestDrivePad")
	local gk = model(outside, "GarageKiosk")
	local kcf = CFrame.new(GX + 30, gy + 1.2, GZ + D / 2 + 14)
	mk(gk, "Base", Vector3.new(2.4, 4.4, 1.2), kcf * CFrame.new(0, 2.2, 0), rgb(26, 28, 34), M.Metal)
	local scr = mk(gk, "Screen", Vector3.new(2, 1.6, 0.1), kcf * CFrame.new(0, 3.4, -0.62), rgb(80, 140, 255), M.Neon)
	signText(scr, Enum.NormalId.Front, "P", rgb(10, 12, 16))
	interact(gk, "GarageInteract", kcf * CFrame.new(0, 2.6, -1.6), "Garage", "Garage", "Miami Motor Gallery Garage")
	table.insert(log, string.format("Miami Motor Gallery @%d,%d (Personal %d)", GX, GZ, staff))

	----------------------------------------------------------------------------------------------------
	-- 3) DOWNTOWN-AUFWERTUNG: Sitzbaenke, Blumenbeete, Muelleimer, Imbissstaende auf Gehwegen
	----------------------------------------------------------------------------------------------------
	local street = model(root, "DowntownStreetLife")
	local function isRoad(h)
		return h and h.Instance:IsDescendantOf(workspace.Map.Roads)
	end
	local function freeAt(x, z)
		-- Gehweg: Grund unter 3 Studs, keine Strasse, nichts im Umkreis von 3 Studs hoeher als 1.5
		local h = hit(x, z, 40)
		if not h or isRoad(h) or h.Position.Y > 3 then
			return nil
		end
		for _, o2 in ipairs({ { 3, 0 }, { -3, 0 }, { 0, 3 }, { 0, -3 } }) do
			local h2 = hit(x + o2[1], z + o2[2], 40)
			if not h2 or isRoad(h2) or math.abs(h2.Position.Y - h.Position.Y) > 1.2 then
				return nil
			end
		end
		return h.Position
	end
	local function bench(pos, face)
		local cf = CFrame.lookAt(pos, pos + face)
		mk(street, "BenchSeat", Vector3.new(6, 0.4, 1.8), cf * CFrame.new(0, 1.7, 0), rgb(140, 100, 60), M.WoodPlanks)
		mk(street, "BenchBack", Vector3.new(6, 1.6, 0.3), cf * CFrame.new(0, 2.8, 0.85), rgb(140, 100, 60), M.WoodPlanks)
		for _, x in ipairs({ -2.6, 2.6 }) do
			mk(street, "BenchLeg", Vector3.new(0.3, 1.6, 1.6), cf * CFrame.new(x, 0.8, 0), rgb(40, 40, 44), M.Metal)
		end
		local s = Instance.new("Seat")
		s.Anchored, s.Transparency, s.CanCollide = true, 1, false
		s.Size = Vector3.new(4, 0.3, 1.6)
		s.CFrame = cf * CFrame.new(0, 1.9, 0) * CFrame.Angles(0, math.pi, 0)
		s.Parent = street
	end
	local FLOWERS = { rgb(240, 80, 120), rgb(250, 200, 60), rgb(180, 90, 220), rgb(255, 130, 60) }
	local function planter(pos, i)
		mk(street, "Planter", Vector3.new(6, 1.6, 3), CFrame.new(pos + Vector3.new(0, 0.8, 0)), rgb(220, 216, 208), M.Concrete)
		mk(street, "Soil", Vector3.new(5.6, 0.2, 2.6), CFrame.new(pos + Vector3.new(0, 1.65, 0)), rgb(80, 60, 40), M.Ground)
		for k = 0, 3 do
			mk(street, "Flowers", Vector3.new(1.2, 0.8, 1.2), CFrame.new(pos + Vector3.new(-2 + k * 1.35, 2.1, 0)), FLOWERS[(i + k) % #FLOWERS + 1], M.Grass, { CanCollide = false })
		end
	end
	local function bin(pos)
		mk(street, "Bin", Vector3.new(1.6, 3, 1.6), CFrame.new(pos + Vector3.new(0, 1.5, 0)), rgb(40, 70, 60), M.Metal)
		mk(street, "BinLid", Vector3.new(1.8, 0.3, 1.8), CFrame.new(pos + Vector3.new(0, 3.1, 0)), rgb(30, 30, 32), M.Metal)
	end
	local function foodCart(pos, face, idx)
		local cf = CFrame.lookAt(pos, pos + face)
		local m = model(street, "FoodCart" .. idx)
		mk(m, "Cart", Vector3.new(6, 3.4, 3), cf * CFrame.new(0, 2, 0), rgb(230, 230, 230), M.Metal)
		mk(m, "Umbrella", Vector3.new(7, 0.3, 7), cf * CFrame.new(0, 8, 0), idx % 2 == 0 and rgb(240, 80, 60) or rgb(60, 160, 230), M.Fabric)
		mk(m, "Pole", Vector3.new(0.3, 4.4, 0.3), cf * CFrame.new(0, 5.8, 0), rgb(200, 200, 205), M.Metal)
		for _, x in ipairs({ -2.4, 2.4 }) do
			mk(m, "Wheel", Vector3.new(0.6, 1.4, 1.4), cf * CFrame.new(x, 0.7, 1.4) * CFrame.Angles(0, 0, math.rad(90)), rgb(30, 30, 32), M.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
		end
		local sgn = mk(m, "Sign", Vector3.new(5, 1, 0.2), cf * CFrame.new(0, 4.3, -1.6), rgb(14, 16, 22))
		signText(sgn, Enum.NormalId.Front, "HOT DOGS · TACOS", rgb(255, 210, 60))
		interact(m, "CartInteract", cf * CFrame.new(0, 2.6, -2.6), "Shop", "Bestellen", "Strassenimbiss", { ShopId = "StreetFood" })
	end
	-- Gehwegpunkte entlang der Downtown-Hauptstrassen (Nord-Sued x und Ost-West z)
	local placed, carts = 0, 0
	local lines = {
		{ "NS", 80, -980, 980 }, { "NS", 480, -980, 980 }, { "NS", 880, -980, 980 }, { "NS", -320, -980, 980 },
		{ "EW", -200, -300, 870 }, { "EW", 600, -300, 870 }, { "EW", -1000, -300, 870 },
	}
	local idx = 0
	for _, ln in ipairs(lines) do
		local from, to = ln[3], ln[4]
		for t = from, to, 90 do
			for _, side in ipairs({ -1, 1 }) do
				idx += 1
				local x, z, perp
				if ln[1] == "NS" then
					x, z, perp = ln[2], t, Vector3.new(side, 0, 0)
				else
					x, z, perp = t, ln[2], Vector3.new(0, 0, side)
				end
				-- Gehweg suchen: von der Strassenmitte nach aussen
				local spot
				for off = 14, 60, 2 do
					local h = hit(x + perp.X * off, z + perp.Z * off, 40)
					if h and not isRoad(h) and h.Position.Y < 3 then
						spot = freeAt(x + perp.X * (off + 2), z + perp.Z * (off + 2))
						break
					end
				end
				if spot then
					local kind = idx % 5
					if kind == 0 and carts < 6 then
						foodCart(spot, -perp, carts)
						carts += 1
					elseif kind == 1 or kind == 3 then
						bench(spot, -perp)
					elseif kind == 2 then
						planter(spot, idx)
					else
						bin(spot)
					end
					placed += 1
				end
			end
		end
	end
	table.insert(log, string.format("Downtown: %d Strassenmoebel, %d Imbissstaende", placed, carts))
	local _ = Kit
	return table.concat(log, " | ")
end
