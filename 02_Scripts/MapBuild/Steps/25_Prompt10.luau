-- Schritt 25 (Prompt 10): Fahrzeugmodelle, Autohaeuser, Apartmenthaeuser + Innenraum-Vorlagen, Downtown-Venues.
-- Idempotent: baut workspace.Map.Prompt10, ServerStorage.ApartmentInteriors und die neuen Fahrzeugvorlagen neu auf.
-- Bestehende Gebaeude werden NICHT veraendert - Eingaenge (Vordach, Tuer, Schild, Interaktion) werden davor gesetzt.
-- Innenraeume liegen bei x 5200..5700, Y 600 - weit ausserhalb des Streaming-Radius (1024) der Stadt, daher dort unsichtbar.
-- Wohnungen erhalten ein eigenes Skyline-Panorama vor den Fenstern (Westen).
return function(Kit)
	local CollectionService = game:GetService("CollectionService")
	local ServerStorage = game:GetService("ServerStorage")
	local rgb = Color3.fromRGB
	local M = Enum.Material
	local Y0 = 600

	local root = workspace.Map:FindFirstChild("Prompt10")
	if root then
		root:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "Prompt10"
	root.Parent = workspace.Map
	local function folder(parent, name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
		return f
	end
	local exterior = folder(root, "Exterior")
	local interiors = folder(root, "Interiors")

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
	local function model(parent, name)
		local m = Instance.new("Model")
		m.Name = name
		m.Parent = parent
		return m
	end
	local function light(p, range, brightness, color, kind)
		local l = Instance.new(kind or "PointLight")
		l.Range = range or 16
		l.Brightness = brightness or 1
		l.Color = color or rgb(255, 236, 210)
		if l:IsA("SurfaceLight") or l:IsA("SpotLight") then
			l.Face = Enum.NormalId.Bottom
			l.Angle = 120
		end
		l.Parent = p
		return l
	end
	local function signText(part, face, text, color, bg, font)
		local sg = Instance.new("SurfaceGui")
		sg.Face = face or Enum.NormalId.Front
		sg.PixelsPerStud = 40
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.LightInfluence = 0
		sg.Parent = part
		local l = Instance.new("TextLabel")
		l.Name = "Text"
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = bg and 0 or 1
		l.BackgroundColor3 = bg or rgb(0, 0, 0)
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
	-- Interaktionspunkt (unsichtbar, Prompt via InteractionService)
	local function interact(parent, name, cf, kind, text, objectText, attrs, size)
		local p = mk(parent, name, size or Vector3.new(3, 5, 1), cf, rgb(255, 255, 255), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
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
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root, workspace.Terrain }
	local function groundY(x, z)
		local r = workspace:Raycast(Vector3.new(x, 9, z), Vector3.new(0, -30, 0), params)
		return r and r.Position.Y or 0.6
	end
	-- Eingang vor einer Fassade. face = Position auf der Fassade (Boden), dir = Blickrichtung nach aussen
	local function entrance(parent, name, facePos, dir, o)
		local m = model(parent, name)
		local gy = groundY(facePos.X + dir.X * 4, facePos.Z + dir.Z * 4)
		local base = CFrame.lookAt(Vector3.new(facePos.X, gy, facePos.Z), Vector3.new(facePos.X, gy, facePos.Z) + dir)
		local w = o.Width or 14
		local accent = o.Color or rgb(64, 224, 255)
		-- Tuer (Glas mit Rahmen) direkt an der Fassade
		mk(m, "DoorFrame", Vector3.new(w * 0.62, 11, 0.6), base * CFrame.new(0, 5.5, 0.1), rgb(30, 32, 38), M.Metal)
		mk(m, "DoorGlass", Vector3.new(w * 0.56, 10, 0.7), base * CFrame.new(0, 5.2, 0), rgb(120, 170, 200), M.Glass, { Transparency = 0.35, Reflectance = 0.15 })
		mk(m, "DoorSplit", Vector3.new(0.25, 10, 0.8), base * CFrame.new(0, 5.2, 0), rgb(30, 32, 38), M.Metal)
		-- Vordach + Stuetzen
		local canopy = mk(m, "Canopy", Vector3.new(w, 0.8, 9), base * CFrame.new(0, 12.4, -4.5), rgb(24, 26, 32), M.Metal)
		mk(m, "CanopyEdge", Vector3.new(w, 0.3, 0.3), base * CFrame.new(0, 12, -9), accent, M.Neon)
		light(mk(m, "CanopyLight", Vector3.new(w - 2, 0.1, 6), base * CFrame.new(0, 11.95, -4.5), rgb(255, 250, 240), M.Neon, { CanCollide = false }), 18, 1.2, rgb(255, 240, 220), "SurfaceLight")
		for _, sx in ipairs({ -1, 1 }) do
			mk(m, "Post", Vector3.new(0.5, 12, 0.5), base * CFrame.new(sx * (w / 2 - 0.5), 6, -8.6), rgb(30, 32, 38), M.Metal)
		end
		mk(m, "Mat", Vector3.new(w * 0.6, 0.12, 6), base * CFrame.new(0, 0.06, -3.5), o.MatColor or rgb(40, 42, 50), M.Fabric, { CanCollide = false })
		-- Schild ueber dem Vordach (beide Seiten lesbar)
		local sign = mk(m, "Sign", Vector3.new(w + 2, 3.2, 0.5), base * CFrame.new(0, 15, -0.6), rgb(14, 16, 22), M.SmoothPlastic)
		signText(sign, Enum.NormalId.Front, o.Sign, accent, nil, o.Font)
		local glow = mk(m, "SignGlow", Vector3.new(w + 2, 0.15, 0.15), base * CFrame.new(0, 13.35, -0.95), accent, M.Neon)
		CollectionService:AddTag(glow, "NightAccent")
		if o.Sub then
			local sub = mk(m, "SubSign", Vector3.new(w * 0.62, 1, 0.2), base * CFrame.new(0, 11.2, -0.3), rgb(14, 16, 22))
			signText(sub, Enum.NormalId.Front, o.Sub, rgb(220, 224, 232), nil, Enum.Font.GothamMedium)
		end
		local doorCF = base * CFrame.new(0, 2.6, -1.6)
		return m, doorCF, base, canopy
	end
	local function kiosk(parent, name, cf, color, label)
		local k = model(parent, name)
		mk(k, "Base", Vector3.new(2.4, 4.4, 1.2), cf * CFrame.new(0, 2.2, 0), rgb(26, 28, 34), M.Metal)
		local scr = mk(k, "Screen", Vector3.new(2, 1.6, 0.1), cf * CFrame.new(0, 3.4, -0.62), color, M.Neon)
		signText(scr, Enum.NormalId.Front, label, rgb(10, 12, 16), nil, Enum.Font.GothamBlack)
		return k
	end

	----------------------------------------------------------------------------------------------------
	-- 1) FAHRZEUGVORLAGEN (Varianten der bestehenden Modelle)
	----------------------------------------------------------------------------------------------------
	local V = ServerStorage.Vehicles
	local function variant(baseName, newName, attrs, tweak)
		local old = V:FindFirstChild("Vehicle_" .. newName)
		if old then
			old:Destroy()
		end
		local m = V["Vehicle_" .. baseName]:Clone()
		m.Name = "Vehicle_" .. newName
		m:SetAttribute("VehicleType", newName)
		for k, v in pairs(attrs) do
			m:SetAttribute(k, v)
		end
		local ch = m:FindFirstChild("Chassis")
		local function add(name, size, offset, color, mat, o)
			local p = mk(m.Body, name, size, ch.CFrame * offset, color, mat, o)
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = p, ch
			w.Parent = p
			return p
		end
		tweak(m, add, ch)
		m.Parent = V
		return m
	end
	local chrome = rgb(225, 228, 234)
	local function chromeTrim(m)
		for _, p in ipairs(m.Body:GetChildren()) do
			if p:IsA("BasePart") and (p.Name == "Grille" or p.Name == "DoorLine" or p.Name == "Handle" or p.Name == "Mirror") then
				p.Color = chrome
				p.Material = M.Metal
				p.Reflectance = 0.25
			end
		end
	end
	variant("Sedan", "Compact", { MaxSpeed = 82, Torque = 1500, BrakeTorque = 4200, Mass = 110 }, function(m)
		local ok = pcall(function()
			m:ScaleTo(0.9)
		end)
		if ok then
			m:SetAttribute("WheelRadius", (m:GetAttribute("WheelRadius") or 1.55) * 0.9)
		end
		for _, p in ipairs(m.Body:GetChildren()) do
			if p:IsA("BasePart") and p.Name == "Roof" then
				p.Color = rgb(30, 30, 34) -- Kontrastdach
			end
		end
	end)
	variant("Sedan", "LuxurySedan", { MaxSpeed = 118, Torque = 2500, BrakeTorque = 6200 }, function(m, add, ch)
		chromeTrim(m)
		add("HoodOrnament", Vector3.new(0.3, 0.5, 0.3), CFrame.new(0, 2.3, -7.2), chrome, M.Metal)
		add("ChromeStrip", Vector3.new(0.12, 0.18, 12), CFrame.new(-4.05, 0.9, 0), chrome, M.Metal)
		add("ChromeStrip", Vector3.new(0.12, 0.18, 12), CFrame.new(4.05, 0.9, 0), chrome, M.Metal)
	end)
	variant("SUV", "LuxurySUV", { MaxSpeed = 108, Torque = 2900, BrakeTorque = 7000 }, function(m, add, ch)
		chromeTrim(m)
		local roof
		for _, p in ipairs(m.Body:GetChildren()) do
			if p.Name == "Roof" then
				roof = p
			end
		end
		local ry = roof and ch.CFrame:ToObjectSpace(roof.CFrame).Y + roof.Size.Y / 2 + 0.25 or 4.6
		add("RoofRail", Vector3.new(0.25, 0.3, 8), CFrame.new(-2.6, ry, 0), chrome, M.Metal)
		add("RoofRail", Vector3.new(0.25, 0.3, 8), CFrame.new(2.6, ry, 0), chrome, M.Metal)
		add("SideStep", Vector3.new(0.6, 0.2, 8), CFrame.new(-4.3, -0.3, 0), chrome, M.Metal)
		add("SideStep", Vector3.new(0.6, 0.2, 8), CFrame.new(4.3, -0.3, 0), chrome, M.Metal)
	end)
	variant("Sports", "Convertible", { MaxSpeed = 132, Torque = 2600, BrakeTorque = 6500 }, function(m)
		-- offenes Verdeck: Dach, Saeulen und Heckscheibe ausblenden (Schweissverbindungen bleiben intakt)
		for _, p in ipairs(m.Body:GetChildren()) do
			if p:IsA("BasePart") and (p.Name == "Roof" or p.Name == "Pillar" or p.Name == "RearWindow" or p.Name == "Cabin") then
				p.Transparency = 1
				p.CanCollide = false
				p.CanQuery = false
			elseif p.Name == "Spoiler" or p.Name == "SpoilerPost" then
				p.Transparency = 1
				p.CanCollide = false
			end
		end
		chromeTrim(m)
	end)
	variant("Sports", "Supercar", { MaxSpeed = 165, Torque = 3400, BrakeTorque = 8200 }, function(m, add, ch)
		local spoilerCF
		for _, p in ipairs(m.Body:GetChildren()) do
			if p:IsA("BasePart") and p.Name == "Spoiler" then
				p.Size = Vector3.new(p.Size.X * 1.15, p.Size.Y * 1.3, p.Size.Z * 1.4)
				spoilerCF = p.CFrame
			elseif p:IsA("BasePart") and p.Name == "SideIntake" then
				p.Color = rgb(255, 72, 168)
				p.Material = M.Neon
			end
		end
		add("Splitter", Vector3.new(7.6, 0.15, 1.2), CFrame.new(0, -0.6, -8.1), rgb(20, 20, 22), M.SmoothPlastic)
		add("Diffuser", Vector3.new(6.4, 0.5, 0.8), CFrame.new(0, -0.3, 8), rgb(20, 20, 22), M.SmoothPlastic)
	end)

	----------------------------------------------------------------------------------------------------
	-- 2) AUSSTELLUNGSFAHRZEUGE (statisch, ohne Funktion)
	----------------------------------------------------------------------------------------------------
	local function displayCar(parent, typeName, cf, color)
		local t = V:FindFirstChild("Vehicle_" .. typeName)
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
		if color then
			local base = m.Body:FindFirstChild("LowerBody")
			local bc = base and base.Color
			for _, p in ipairs(m.Body:GetChildren()) do
				if p:IsA("BasePart") and bc and p.Color == bc then
					p.Color = color
				end
			end
		end
		m:PivotTo(cf)
		-- cf.Y = Oberflaeche: Unterkante der Bounding-Box exakt daraufsetzen
		local bb, bs = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + Vector3.new(0, cf.Y - (bb.Y - bs.Y / 2), 0))
		m.Parent = parent
		return m
	end

	----------------------------------------------------------------------------------------------------
	-- 3) RAUM-BAUKASTEN fuer Innenraeume
	----------------------------------------------------------------------------------------------------
	-- origin = Bodenmitte, -X = Westwand (Fenster), +X = Ostwand (Eingang)
	local function room(parent, origin, w, d, h, st)
		local shell = folder(parent, "Shell")
		mk(shell, "Floor", Vector3.new(w, 1, d), origin * CFrame.new(0, -0.5, 0), st.Floor, st.FloorMat or M.WoodPlanks)
		mk(shell, "Ceiling", Vector3.new(w, 1, d), origin * CFrame.new(0, h + 0.5, 0), st.Ceiling or rgb(245, 245, 242))
		mk(shell, "WallN", Vector3.new(w, h, 1), origin * CFrame.new(0, h / 2, -d / 2 - 0.5), st.Wall, st.WallMat)
		mk(shell, "WallS", Vector3.new(w, h, 1), origin * CFrame.new(0, h / 2, d / 2 + 0.5), st.Wall, st.WallMat)
		mk(shell, "WallE", Vector3.new(1, h, d), origin * CFrame.new(w / 2 + 0.5, h / 2, 0), st.Wall, st.WallMat)
		if st.Windows then
			-- Fensterfront West (mit Oeffnung zum Balkon, falls vorhanden)
			local gap = st.BalconyDepth and 8 or 0
			local seg = (d - gap) / 2
			for _, s in ipairs({ -1, 1 }) do
				mk(shell, "Glass", Vector3.new(0.4, h, seg), origin * CFrame.new(-w / 2 - 0.2, h / 2, s * (gap / 2 + seg / 2)), rgb(170, 210, 230), M.Glass, { Transparency = 0.75, Reflectance = 0.1 })
			end
			mk(shell, "WindowFrameTop", Vector3.new(0.8, 0.6, d), origin * CFrame.new(-w / 2 - 0.2, h - 0.3, 0), rgb(30, 32, 36), M.Metal)
			if st.BalconyDepth then
				local bd = st.BalconyDepth
				local bw = st.BalconyWidth or d
				mk(shell, "Balcony", Vector3.new(bd, 1, bw), origin * CFrame.new(-w / 2 - bd / 2, -0.5, 0), rgb(200, 196, 188), M.Concrete)
				mk(shell, "RailGlass", Vector3.new(0.3, 3.4, bw), origin * CFrame.new(-w / 2 - bd + 0.15, 1.7, 0), rgb(180, 220, 235), M.Glass, { Transparency = 0.6 })
				mk(shell, "Rail", Vector3.new(0.4, 0.3, bw), origin * CFrame.new(-w / 2 - bd + 0.15, 3.5, 0), rgb(40, 42, 46), M.Metal)
				for _, s in ipairs({ -1, 1 }) do
					mk(shell, "RailGlass", Vector3.new(bd, 3.4, 0.3), origin * CFrame.new(-w / 2 - bd / 2, 1.7, s * (bw / 2 - 0.15)), rgb(180, 220, 235), M.Glass, { Transparency = 0.6 })
				end
			end
		else
			mk(shell, "WallW", Vector3.new(1, h, d), origin * CFrame.new(-w / 2 - 0.5, h / 2, 0), st.Wall, st.WallMat)
		end
		-- Deckenlicht-Raster
		local nx, nz = math.max(1, math.floor(w / 18)), math.max(1, math.floor(d / 18))
		for ix = 1, nx do
			for iz = 1, nz do
				local lp = mk(shell, "CeilingLight", Vector3.new(3, 0.15, 3), origin * CFrame.new(-w / 2 + (ix - 0.5) * w / nx, h - 0.08, -d / 2 + (iz - 0.5) * d / nz), st.LightColor or rgb(255, 246, 230), st.NeonLights and M.Neon or M.SmoothPlastic, { CanCollide = false, Transparency = st.NeonLights and 0 or 0.2 })
				light(lp, st.LightRange or 24, st.LightBright or 0.9, st.LightColor or rgb(255, 236, 210))
			end
		end
		return shell
	end
	local function counter(parent, cf, len, color, top)
		mk(parent, "Counter", Vector3.new(len, 3.4, 2.6), cf * CFrame.new(0, 1.7, 0), color or rgb(240, 240, 238), M.SmoothPlastic)
		mk(parent, "CounterTop", Vector3.new(len + 0.2, 0.25, 2.8), cf * CFrame.new(0, 3.5, 0), top or rgb(40, 40, 44), M.Marble)
	end
	local function seat(parent, cf, color)
		local s = Instance.new("Seat")
		s.Name = "Seat"
		s.Anchored = true
		s.Size = Vector3.new(2, 0.6, 2)
		s.CFrame = cf * CFrame.new(0, 1.5, 0)
		s.Color = color or rgb(60, 60, 66)
		s.Material = M.Fabric
		s.TopSurface = Enum.SurfaceType.Smooth
		s.Parent = parent
		mk(parent, "SeatBack", Vector3.new(2, 2, 0.3), cf * CFrame.new(0, 2.8, 0.9), color or rgb(60, 60, 66), M.Fabric)
		mk(parent, "SeatLeg", Vector3.new(0.3, 1.2, 0.3), cf * CFrame.new(0, 0.6, 0), rgb(30, 30, 32), M.Metal)
		return s
	end
	local function diningTable(parent, cf, seats, top)
		mk(parent, "Table", Vector3.new(4, 0.25, 4), cf * CFrame.new(0, 3, 0), top or rgb(245, 245, 240), M.Marble)
		mk(parent, "TableLeg", Vector3.new(0.5, 3, 0.5), cf * CFrame.new(0, 1.5, 0), rgb(30, 30, 32), M.Metal)
		local cl = mk(parent, "Candle", Vector3.new(0.3, 0.5, 0.3), cf * CFrame.new(0, 3.4, 0), rgb(255, 210, 140), M.Neon, { CanCollide = false })
		light(cl, 8, 0.6, rgb(255, 190, 120))
		for i = 1, seats or 2 do
			local a = (i - 1) * (2 * math.pi / (seats or 2))
			seat(parent, cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 3.2), rgb(70, 60, 55))
		end
	end
	local function plant(parent, cf)
		mk(parent, "Pot", Vector3.new(1.8, 1.8, 1.8), cf * CFrame.new(0, 0.9, 0), rgb(230, 225, 215), M.Concrete)
		for i = 0, 5 do
			mk(parent, "Leaf", Vector3.new(0.3, 0.15, 2.6), cf * CFrame.new(0, 3.4, 0) * CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.new(0, 0, -1.1) * CFrame.Angles(math.rad(-28), 0, 0), rgb(60, 140, 70), M.Grass, { CanCollide = false })
		end
		mk(parent, "Stem", Vector3.new(0.25, 2.6, 0.25), cf * CFrame.new(0, 2.6, 0), rgb(110, 80, 50), M.Wood)
	end
	local function sofa(parent, cf, len, color)
		mk(parent, "SofaBase", Vector3.new(len, 1.4, 3.2), cf * CFrame.new(0, 0.9, 0), color, M.Fabric)
		mk(parent, "SofaBack", Vector3.new(len, 2, 0.8), cf * CFrame.new(0, 2.2, 1.2), color, M.Fabric)
		for i = 1, math.max(1, math.floor(len / 3)) do
			local s = Instance.new("Seat")
			s.Anchored, s.Transparency, s.CanCollide = true, 1, false
			s.Size = Vector3.new(2, 0.4, 2)
			s.CFrame = cf * CFrame.new(-len / 2 + (i - 0.5) * len / math.max(1, math.floor(len / 3)), 1.7, -0.2) * CFrame.Angles(0, math.pi, 0)
			s.Parent = parent
		end
	end
	-- Tuer im Innenraum (VenueDoor-Gegenstueck): Blickrichtung in den Raum
	local function innerDoor(parent, cf, link, label, attrs)
		mk(parent, "DoorPanel", Vector3.new(6, 10, 0.4), cf * CFrame.new(0, 5, 0.3), rgb(28, 30, 36), M.Metal)
		local s = mk(parent, "ExitSign", Vector3.new(3, 0.8, 0.1), cf * CFrame.new(0, 10.8, 0.05), rgb(20, 200, 90), M.Neon)
		signText(s, Enum.NormalId.Front, "EXIT", rgb(255, 255, 255))
		local a = { Link = link, Side = "In" }
		for k, v in pairs(attrs or {}) do
			a[k] = v
		end
		return interact(parent, "DoorInteract", cf * CFrame.new(0, 2.6, -1), "VenueDoor", "Verlassen", label, a)
	end

	----------------------------------------------------------------------------------------------------
	-- 4) APARTMENT-INNENRAEUME (Vorlagen in ServerStorage.ApartmentInteriors)
	----------------------------------------------------------------------------------------------------
	local aptFolder = ServerStorage:FindFirstChild("ApartmentInteriors")
	if aptFolder then
		aptFolder:Destroy()
	end
	aptFolder = folder(ServerStorage, "ApartmentInteriors")
	local TIERS = {
		Standard = { W = 44, D = 32, H = 12, Floor = rgb(176, 140, 104), Wall = rgb(236, 232, 224), Accent = rgb(90, 140, 120), Balcony = 6, Furnished = false },
		City = { W = 54, D = 38, H = 13, Floor = rgb(120, 110, 100), Wall = rgb(242, 242, 240), Accent = rgb(64, 160, 230), Balcony = 7, Furnished = false },
		Luxury = { W = 70, D = 46, H = 15, Floor = rgb(230, 228, 222), FloorMat = M.Marble, Wall = rgb(228, 222, 210), Accent = rgb(200, 170, 100), Balcony = 10, Furnished = true },
		Penthouse = { W = 96, D = 64, H = 18, Floor = rgb(60, 58, 56), FloorMat = M.Marble, Wall = rgb(226, 222, 214), Accent = rgb(255, 72, 168), Balcony = 22, Furnished = true },
	}
	for name, t in pairs(TIERS) do
		local m = model(aptFolder, name)
		local origin = CFrame.new(0, 0, 0)
		local o = mk(m, "Origin", Vector3.new(1, 1, 1), origin, rgb(255, 0, 0), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
		m.PrimaryPart = o
		m:SetAttribute("HalfSize", Vector3.new(t.W / 2 - 3, 0, t.D / 2 - 3))
		m:SetAttribute("Tier", name)
		room(m, origin, t.W, t.D, t.H, { Floor = t.Floor, FloorMat = t.FloorMat, Wall = t.Wall, Windows = true, BalconyDepth = t.Balcony, BalconyWidth = (name == "Penthouse") and t.D or math.min(t.D - 6, 24), LightBright = 0.35, LightRange = 20 })
		local deco = folder(m, "Decor")
		local W, D, H = t.W, t.D, t.H
		-- Skyline-Panorama vor der Fensterfront (Westen): je hoeher die Wohnungsklasse, desto tiefer liegen die Daecher
		do
			local view = folder(m, "View")
			local VIEW = { Standard = { 20, 170 }, City = { -20, 130 }, Luxury = { -90, 80 }, Penthouse = { -230, 20 } }
			local lo, hi = VIEW[name][1], VIEW[name][2]
			local rng = Random.new(#name * 97)
			local x0 = -W / 2 - t.Balcony
			mk(view, "Ground", Vector3.new(900, 2, 900), origin * CFrame.new(x0 - 450, -320, 0), rgb(30, 70, 90), M.Glass, { Transparency = 0.1, CanCollide = false, CanQuery = false })
			for row = 1, 3 do
				local dist = ({ 70, 150, 260 })[row]
				local zz = -320
				while zz < 320 do
					local bw = rng:NextNumber(26, 60)
					local top = rng:NextNumber(lo, hi) + row * 15
					local hgt = top + 320
					local cf = origin * CFrame.new(x0 - dist - rng:NextNumber(0, 30), -320 + hgt / 2, zz + bw / 2)
					local shade = rng:NextNumber(0.55, 0.85)
					local tw = rng:NextNumber(26, 50)
					mk(view, "Tower", Vector3.new(tw, hgt, bw), cf, Color3.new(shade * 0.85, shade * 0.9, shade), M.Glass, { CanCollide = false, CanQuery = false, Reflectance = 0.1 })
					-- Fensterbaender auf der Ostseite (nachts beleuchtet ueber den DayNightController)
					for k = 1, math.min(14, math.floor(hgt / 22)) do
						local wy = top - k * 18
						if wy > -320 and rng:NextNumber() < 0.7 then
							local strip = mk(view, "WindowStrip", Vector3.new(0.3, 2, bw * 0.8), origin * CFrame.new(cf.X - origin.X + tw / 2 + 0.2, wy, cf.Z - origin.Z), rgb(255, 214, 150), M.Neon, { CanCollide = false, CanQuery = false, Transparency = 1 })
							CollectionService:AddTag(strip, "NightWindow")
						end
					end
					zz += bw + rng:NextNumber(6, 22)
				end
			end
		end
		-- Eingang (Ost), Nummernschild, Verwaltung
		local exitDoor = mk(m, "ExitDoor", Vector3.new(0.4, 9, 5), origin * CFrame.new(W / 2 - 0.2, 4.5, 0), rgb(60, 50, 44), M.Wood)
		local num = mk(deco, "NumberPlate", Vector3.new(0.1, 1, 2.4), origin * CFrame.new(W / 2 - 0.45, 10, 0), rgb(20, 22, 26))
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Left
		sg.PixelsPerStud = 40
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.Parent = num
		local lbl = Instance.new("TextLabel")
		lbl.Name = "AptNumber"
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.TextScaled = true
		lbl.Font = Enum.Font.GothamBold
		lbl.TextColor3 = rgb(230, 230, 230)
		lbl.Text = "APT"
		lbl.Parent = sg
		local panel = mk(m, "ManagePanel", Vector3.new(0.3, 1.6, 1.2), origin * CFrame.new(W / 2 - 0.3, 5, 4.5), t.Accent, M.Neon)
		mk(m, "Spawn", Vector3.new(2, 0.2, 2), origin * CFrame.new(W / 2 - 6, 0.1, 0), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
		local _ = exitDoor, panel
		-- Kueche (Nordost)
		local kx = W / 4
		counter(deco, origin * CFrame.new(kx, 0, -D / 2 + 1.5), W / 2 - 6, rgb(245, 245, 243), rgb(40, 40, 44))
		mk(deco, "Fridge", Vector3.new(3.2, 7.5, 2.8), origin * CFrame.new(W / 2 - 3, 3.75, -D / 2 + 1.6), rgb(200, 204, 210), M.Metal)
		mk(deco, "Stove", Vector3.new(2.6, 0.1, 2), origin * CFrame.new(kx - 2, 3.66, -D / 2 + 1.5), rgb(20, 20, 22), M.Glass)
		mk(deco, "Cabinets", Vector3.new(W / 2 - 6, 3, 1.4), origin * CFrame.new(kx, H - 3, -D / 2 + 0.8), rgb(235, 235, 232))
		if name ~= "Standard" then
			counter(deco, origin * CFrame.new(kx, 0, -D / 2 + 8), math.min(14, W / 3), t.Accent:Lerp(rgb(30, 30, 34), 0.6), rgb(245, 245, 245))
			for i = -1, 1 do
				seat(deco, origin * CFrame.new(kx + i * 3, 0, -D / 2 + 10.4) * CFrame.Angles(0, 0, 0), rgb(40, 40, 44))
			end
		end
		-- Schlafzimmer + Bad (Suedost) mit Trennwaenden und Tueroeffnungen
		local bx0 = 2 -- Westkante des Schlafzimmers
		local bz0 = 4 -- Nordkante
		local sh = folder(m, "Partitions")
		mk(sh, "PartitionN1", Vector3.new((W / 2 - bx0) - 6, H, 0.6), origin * CFrame.new(bx0 + ((W / 2 - bx0) - 6) / 2, H / 2, bz0), t.Wall)
		mk(sh, "PartitionW", Vector3.new(0.6, H, D / 2 - bz0), origin * CFrame.new(bx0, H / 2, bz0 + (D / 2 - bz0) / 2), t.Wall)
		local bedCF = origin * CFrame.new(bx0 + 7, 0, D / 2 - 5) * CFrame.Angles(0, 0, 0)
		mk(deco, "BedFrame", Vector3.new(7, 1.2, 8), bedCF * CFrame.new(0, 0.6, 0), rgb(80, 64, 52), M.Wood)
		mk(deco, "Mattress", Vector3.new(6.6, 0.9, 7.4), bedCF * CFrame.new(0, 1.6, 0), rgb(240, 240, 242), M.Fabric)
		mk(deco, "Blanket", Vector3.new(6.8, 0.25, 4.4), bedCF * CFrame.new(0, 2.1, -1.4), t.Accent:Lerp(rgb(30, 40, 60), 0.4), M.Fabric)
		mk(deco, "Headboard", Vector3.new(7, 4, 0.5), bedCF * CFrame.new(0, 2, 4), rgb(80, 64, 52), M.Wood)
		mk(deco, "Pillow", Vector3.new(2.4, 0.5, 1.2), bedCF * CFrame.new(-1.6, 2.3, 2.8), rgb(255, 255, 255), M.Fabric)
		mk(deco, "Pillow", Vector3.new(2.4, 0.5, 1.2), bedCF * CFrame.new(1.6, 2.3, 2.8), rgb(255, 255, 255), M.Fabric)
		-- Bad in der Suedostecke
		local bathW = 10
		mk(sh, "BathWallW", Vector3.new(0.6, H, D / 2 - bz0 - 6), origin * CFrame.new(W / 2 - bathW, H / 2, bz0 + 6 + (D / 2 - bz0 - 6) / 2), t.Wall)
		mk(deco, "Tiles", Vector3.new(bathW, 0.1, D / 2 - bz0 - 6), origin * CFrame.new(W / 2 - bathW / 2, 0.05, bz0 + 6 + (D / 2 - bz0 - 6) / 2), rgb(220, 226, 230), M.Marble)
		mk(deco, "Toilet", Vector3.new(1.6, 1.8, 2.2), origin * CFrame.new(W / 2 - 1.5, 0.9, D / 2 - 6), rgb(250, 250, 250), M.SmoothPlastic)
		mk(deco, "Sink", Vector3.new(1.6, 3, 3), origin * CFrame.new(W / 2 - 1.2, 1.5, D / 2 - 10), rgb(250, 250, 250))
		mk(deco, "Mirror", Vector3.new(0.1, 3, 2.6), origin * CFrame.new(W / 2 - 0.05, 6, D / 2 - 10), rgb(200, 220, 230), M.Glass, { Reflectance = 0.6 })
		mk(deco, "ShowerGlass", Vector3.new(0.2, 8, 5), origin * CFrame.new(W / 2 - bathW + 4, 4, D / 2 - 3), rgb(200, 230, 240), M.Glass, { Transparency = 0.6 })
		mk(deco, "ShowerTray", Vector3.new(4, 0.3, 5), origin * CFrame.new(W / 2 - bathW + 2, 0.15, D / 2 - 3), rgb(240, 240, 240))
		-- Wohnbereich (West): Grundausstattung; Luxus/Penthouse moebliert
		mk(deco, "Rug", Vector3.new(12, 0.1, 9), origin * CFrame.new(-W / 4, 0.05, 0), t.Accent:Lerp(rgb(230, 225, 215), 0.7), M.Fabric, { CanCollide = false })
		plant(deco, origin * CFrame.new(-W / 2 + 3, 0, -D / 2 + 3))
		plant(deco, origin * CFrame.new(-W / 2 + 3, 0, D / 2 - 3))
		if t.Furnished then
			sofa(deco, origin * CFrame.new(-W / 4 + 6, 0, 0) * CFrame.Angles(0, math.rad(90), 0), 10, rgb(60, 62, 70))
			mk(deco, "CoffeeTable", Vector3.new(3, 1.4, 6), origin * CFrame.new(-W / 4, 0.7, 0), rgb(30, 30, 32), M.Marble)
			mk(deco, "TVWall", Vector3.new(0.3, 4.5, 8), origin * CFrame.new(-W / 4 - 9, 5, 0), rgb(12, 12, 14), M.Glass, { Reflectance = 0.25 })
			mk(deco, "Sideboard", Vector3.new(2, 2, 10), origin * CFrame.new(-W / 4 - 9.2, 1, 0), rgb(235, 232, 226), M.Wood)
			local chand = mk(deco, "Chandelier", Vector3.new(3, 0.6, 3), origin * CFrame.new(-W / 4, H - 1.5, 0), rgb(255, 230, 180), M.Neon, { CanCollide = false })
			light(chand, 26, 1.1, rgb(255, 220, 170))
			diningTable(deco, origin * CFrame.new(-W / 4, 0, -D / 2 + 8), 4, rgb(250, 250, 248))
		end
		if name == "Penthouse" then
			-- Dachterrasse mit Pool, Loungemoebeln
			local tc = origin * CFrame.new(-W / 2 - t.Balcony / 2, 0, 0)
			mk(deco, "Pool", Vector3.new(8, 0.4, 20), tc * CFrame.new(-2, 0.2, -12), rgb(40, 170, 220), M.Glass, { Transparency = 0.25, CanCollide = false })
			mk(deco, "PoolEdge", Vector3.new(9, 0.6, 21), tc * CFrame.new(-2, 0.1, -12), rgb(240, 238, 232), M.Marble)
			for i = 0, 2 do
				mk(deco, "Lounger", Vector3.new(2.4, 0.8, 6), tc * CFrame.new(4, 0.4, -18 + i * 5), rgb(250, 250, 250), M.Fabric)
			end
			sofa(deco, tc * CFrame.new(0, 0, 14) * CFrame.Angles(0, math.rad(180), 0), 12, rgb(240, 236, 226))
			for i = 1, 6 do
				local lp = mk(deco, "TerraceLight", Vector3.new(0.6, 0.6, 0.6), tc * CFrame.new(-t.Balcony / 2 + 1, 4, -t.D / 2 + i * t.D / 7), rgb(255, 210, 140), M.Neon, { CanCollide = false })
				light(lp, 14, 0.8, rgb(255, 200, 130))
			end
		end
	end

	----------------------------------------------------------------------------------------------------
	-- 5) APARTMENTHAEUSER (Eingaenge an Bestandsgebaeuden)
	----------------------------------------------------------------------------------------------------
	local aptExt = folder(exterior, "ApartmentBuildings")
	local BUILDINGS = {
		{ Id = "BayfrontOne", Sign = "BAYFRONT ONE", Sub = "LUXURY RESIDENCES & PENTHOUSES", Pos = Vector3.new(673, 0, -340), Dir = Vector3.new(0, 0, 1), Color = rgb(220, 180, 90), Width = 18 },
		{ Id = "BrickellHeights", Sign = "BRICKELL HEIGHTS", Sub = "CITY APARTMENTS", Pos = Vector3.new(594, 0, -1359.5), Dir = Vector3.new(0, 0, -1), Color = rgb(64, 170, 255), Width = 16 },
		{ Id = "OceanDrive", Sign = "OCEAN DRIVE RESIDENCES", Sub = "WATERFRONT LIVING", Pos = Vector3.new(2358, 0, -1006), Dir = Vector3.new(-1, 0, 0), Color = rgb(64, 224, 200), Width = 18 },
		{ Id = "SawgrassGardens", Sign = "SAWGRASS GARDENS", Sub = "APARTMENTS", Pos = Vector3.new(-2694, 0, -133.5), Dir = Vector3.new(0, 0, -1), Color = rgb(120, 200, 120), Width = 14 },
	}
	for _, b in ipairs(BUILDINGS) do
		local m, doorCF, base = entrance(aptExt, "Entrance_" .. b.Id, b.Pos, b.Dir, b)
		interact(m, "PropertyInteract", doorCF, "Property", "Wohnungen", b.Sign, { BuildingId = b.Id })
		local ex = mk(m, "PropertyExit", Vector3.new(4, 0.2, 4), base * CFrame.new(0, 0.2, -7), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
		ex:SetAttribute("BuildingId", b.Id)
		CollectionService:AddTag(ex, "PropertyExit")
		-- Garage am Haus
		local kcf = base * CFrame.new((b.Width or 14) / 2 + 4, 0, -3)
		kiosk(m, "GarageKiosk", kcf, rgb(80, 140, 255), "P")
		interact(m, "GarageInteract", kcf * CFrame.new(0, 2.6, -1.6), "Garage", "Garage", b.Sign .. " Garage")
	end

	----------------------------------------------------------------------------------------------------
	-- 6) VENUES (Innenraeume ueber der Bucht) + Eingaenge in der Stadt
	----------------------------------------------------------------------------------------------------
	local venueExt = folder(exterior, "Venues")
	local function venueEntrance(id, pos, dir, opts)
		local m, doorCF = entrance(venueExt, "Entrance_" .. id, pos, dir, opts)
		interact(m, "DoorInteract", doorCF, "VenueDoor", "Betreten", opts.Sign, { Link = id, Side = "Out", Welcome = opts.Welcome or "" })
		return m
	end

	-- 6a) BAYFRONT SOCIAL: Kino, Bowling, Arcade -------------------------------------------------------
	do
		local m = model(interiors, "BayfrontSocial")
		local o = CFrame.new(5250, Y0, 200)
		room(m, o, 120, 80, 18, { Floor = rgb(30, 28, 40), FloorMat = M.SmoothPlastic, Wall = rgb(36, 32, 52), Ceiling = rgb(20, 18, 28), LightColor = rgb(200, 180, 255), LightBright = 0.7 })
		innerDoor(m, o * CFrame.new(59.4, 0, 0) * CFrame.Angles(0, math.rad(90), 0), "Social", "Bayfront Social")
		-- Kasse
		counter(m, o * CFrame.new(46, 0, -20) * CFrame.Angles(0, math.rad(90), 0), 16, rgb(120, 70, 220), rgb(240, 240, 245))
		interact(m, "Cashier", o * CFrame.new(44, 2.6, -20), "Shop", "Kasse", "Kino-Tickets & Snacks", { ShopId = "CinemaBox" })
		local cs = mk(m, "CashierSign", Vector3.new(12, 2.4, 0.3), o * CFrame.new(46, 11, -28) , rgb(20, 16, 30))
		signText(cs, Enum.NormalId.Back, "TICKETS · SNACKS", rgb(190, 150, 255))
		-- Kinosaal (West, 50x80) mit Trennwand und Ticket-Tuer
		mk(m, "CinemaWall", Vector3.new(1, 18, 80), o * CFrame.new(-10, 9, 0), rgb(28, 24, 40))
		local screen = mk(m, "Screen", Vector3.new(0.4, 12, 34), o * CFrame.new(-59.3, 9, 0), rgb(10, 10, 14), M.SmoothPlastic)
		CollectionService:AddTag(screen, "CinemaScreen")
		local ssg = Instance.new("SurfaceGui")
		ssg.Name = "Film"
		ssg.Face = Enum.NormalId.Right
		ssg.PixelsPerStud = 20
		ssg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		ssg.LightInfluence = 0
		ssg.Parent = screen
		local fr = Instance.new("Frame")
		fr.Name = "Frame"
		fr.Size = UDim2.fromScale(1, 1)
		fr.BackgroundColor3 = rgb(20, 30, 60)
		fr.Parent = ssg
		local ft = Instance.new("TextLabel")
		ft.Name = "Title"
		ft.Size = UDim2.fromScale(1, 0.4)
		ft.Position = UDim2.fromScale(0, 0.3)
		ft.BackgroundTransparency = 1
		ft.TextScaled = true
		ft.Font = Enum.Font.GothamBlack
		ft.TextColor3 = rgb(255, 255, 255)
		ft.Text = "MIAMI NIGHTS"
		ft.ZIndex = 2
		ft.Parent = ssg
		for row = 0, 5 do
			mk(m, "Tier", Vector3.new(4, row * 0.8 + 0.1, 64), o * CFrame.new(-44 + row * 5.5, (row * 0.8 + 0.1) / 2, 0), rgb(40, 20, 30), M.Fabric)
			for s = -6, 6 do
				local st = seat(m, o * CFrame.new(-44 + row * 5.5, row * 0.8, s * 4.6) * CFrame.Angles(0, math.rad(-90), 0), rgb(150, 30, 40))
				st.Name = "CinemaSeat"
			end
		end
		interact(m, "WatchFilm", o * CFrame.new(-22, 2.6, 30), "Activity", "Film ansehen", "Kinosaal 1", { ActivityId = "Cinema" })
		-- Ticketkontrolle: Lobby -> Saal (Ticket wird entwertet), Saal -> Lobby frei
		mk(m, "HallDoorFrame", Vector3.new(1.4, 11, 7), o * CFrame.new(-10, 5.5, 30), rgb(150, 90, 255), M.Neon)
		interact(m, "HallEnter", o * CFrame.new(-8, 2.6, 30) * CFrame.Angles(0, math.rad(-90), 0), "VenueDoor", "Kinosaal betreten (Ticket)", "Kinosaal 1", { Link = "CinemaHall", Side = "Out", Requires = "CinemaTicket", Consume = true, Welcome = "Viel Spass im Film!" })
		interact(m, "HallExit", o * CFrame.new(-12, 2.6, 30) * CFrame.Angles(0, math.rad(90), 0), "VenueDoor", "Zur Lobby", "Kinosaal 1", { Link = "CinemaHall", Side = "In" })
		-- Bowling: 4 Bahnen (Ost, entlang X)
		for i = 0, 3 do
			local lane = model(m, "Lane" .. (i + 1))
			local lz = 8 + i * 7
			local lcf = o * CFrame.new(10, 0, lz)
			mk(lane, "LaneFloor", Vector3.new(40, 0.2, 5), lcf * CFrame.new(10, 0.1, 0), rgb(200, 160, 110), M.Wood, { Reflectance = 0.1 })
			mk(lane, "Gutter", Vector3.new(40, 0.15, 0.8), lcf * CFrame.new(10, 0.08, -2.9), rgb(30, 30, 34), M.Metal)
			local bs = mk(lane, "BallStart", Vector3.new(1, 1, 1), lcf * CFrame.new(28, 1.2, 0), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CanCollide = false })
			local _ = bs
			local pins = folder(lane, "Pins")
			local n = 0
			for r = 0, 3 do
				for k = 0, r do
					n += 1
					mk(pins, "Pin", Vector3.new(0.5, 1.6, 0.5), lcf * CFrame.new(-8 - r * 0.9, 0.9, (k - r / 2) * 1), rgb(250, 250, 250), M.SmoothPlastic, { CanCollide = false })
				end
			end
			mk(lane, "PinDeck", Vector3.new(4, 4, 5), lcf * CFrame.new(-11, 6, 0), rgb(20, 18, 28))
			local scoreBoard = mk(lane, "Score", Vector3.new(0.2, 2.4, 4), lcf * CFrame.new(-10, 9, 0), rgb(10, 10, 14), M.Neon)
			signText(scoreBoard, Enum.NormalId.Right, "LANE " .. (i + 1), rgb(255, 200, 80))
			interact(lane, "BowlInteract", lcf * CFrame.new(31, 2.6, 0), "Activity", "Bowling spielen ($20)", "Bahn " .. (i + 1), { ActivityId = "Bowling" })
			seat(lane, lcf * CFrame.new(36, 0, 1.5) * CFrame.Angles(0, math.rad(90), 0), rgb(255, 120, 40))
		end
		-- Arcade (Nordost)
		for i = 0, 5 do
			local acf = o * CFrame.new(4 + i * 6, 0, -36) * CFrame.Angles(0, math.pi, 0)
			local cab = model(m, "Arcade" .. (i + 1))
			mk(cab, "Cabinet", Vector3.new(3.6, 7, 3), acf * CFrame.new(0, 3.5, 0), Color3.fromHSV(i / 6, 0.7, 0.5))
			local scr = mk(cab, "Screen", Vector3.new(2.8, 2.2, 0.1), acf * CFrame.new(0, 4.6, -1.55), Color3.fromHSV(i / 6, 0.6, 1), M.Neon)
			signText(scr, Enum.NormalId.Front, ({ "NEON RACER", "BAY INVADERS", "PALM FIGHTER", "OCEAN DASH", "SKY HOOPS", "RETRO KART" })[i + 1], rgb(10, 10, 20))
			local marquee = mk(cab, "Marquee", Vector3.new(3.6, 0.8, 0.2), acf * CFrame.new(0, 6.6, -1.5), Color3.fromHSV(i / 6, 0.8, 1), M.Neon)
			CollectionService:AddTag(marquee, "NightAccent")
			interact(cab, "ArcadeInteract", acf * CFrame.new(0, 2.6, -3), "Activity", "Spielen ($5)", "Arcade", { ActivityId = "Arcade" })
		end
		local neon = mk(m, "NeonStrip", Vector3.new(120, 0.3, 0.3), o * CFrame.new(0, 17, -39.4), rgb(150, 90, 255), M.Neon)
		local _ = neon
	end
	venueEntrance("Social", Vector3.new(752, 0, -146.5), Vector3.new(0, 0, -1), { Sign = "BAYFRONT SOCIAL", Sub = "KINO · BOWLING · ARCADE", Color = rgb(170, 110, 255), Width = 16, Welcome = "Willkommen im Bayfront Social - Tickets und Snacks an der Kasse" })

	-- 6b) IRON BAY FITNESS ---------------------------------------------------------------------------
	do
		local m = model(interiors, "IronBayFitness")
		local o = CFrame.new(5250, Y0, 420)
		room(m, o, 80, 52, 16, { Floor = rgb(40, 42, 46), FloorMat = M.Fabric, Wall = rgb(60, 62, 68), WallMat = M.Concrete, LightColor = rgb(240, 250, 255) })
		innerDoor(m, o * CFrame.new(39.4, 0, 0) * CFrame.Angles(0, math.rad(90), 0), "Gym", "Iron Bay Fitness")
		counter(m, o * CFrame.new(30, 0, -16) * CFrame.Angles(0, math.rad(90), 0), 12, rgb(40, 200, 120), rgb(30, 30, 34))
		interact(m, "Desk", o * CFrame.new(28, 2.6, -16), "Shop", "Empfang", "Mitgliedschaft & Getraenke", { ShopId = "GymDesk" })
		mk(m, "MirrorWall", Vector3.new(0.2, 9, 50), o * CFrame.new(-39.4, 6, 0), rgb(200, 220, 230), M.Glass, { Reflectance = 0.5 })
		for i = 0, 5 do
			local tcf = o * CFrame.new(-30, 0, -20 + i * 8) * CFrame.Angles(0, math.rad(-90), 0)
			mk(m, "TreadmillBelt", Vector3.new(2.4, 0.6, 6), tcf * CFrame.new(0, 0.3, 0), rgb(25, 25, 28), M.Fabric)
			mk(m, "TreadmillConsole", Vector3.new(2.6, 4.4, 0.6), tcf * CFrame.new(0, 2.6, -3), rgb(60, 60, 66), M.Metal)
			interact(m, "Treadmill", tcf * CFrame.new(0, 2.6, 0), "Activity", "Laufband ($15)", "Cardio", { ActivityId = "Gym" })
		end
		for i = 0, 3 do
			local bcf = o * CFrame.new(-6 + i * 9, 0, 14)
			mk(m, "Bench", Vector3.new(1.6, 1.6, 5), bcf * CFrame.new(0, 0.8, 0), rgb(30, 30, 34), M.Fabric)
			mk(m, "Rack", Vector3.new(4, 6, 0.4), bcf * CFrame.new(0, 3, -2.8), rgb(180, 30, 40), M.Metal)
			mk(m, "Barbell", Vector3.new(6, 0.25, 0.25), bcf * CFrame.new(0, 4.6, -2.5), rgb(200, 200, 205), M.Metal)
			interact(m, "BenchPress", bcf * CFrame.new(2, 2.6, 0), "Activity", "Bankdruecken ($15)", "Kraft", { ActivityId = "Gym" })
		end
		for i = 0, 4 do
			mk(m, "Dumbbells", Vector3.new(1, 0.8, 4), o * CFrame.new(6 + i * 3, 0.4, -24), rgb(30, 30, 34), M.Metal)
		end
		local gs = mk(m, "GymSign", Vector3.new(20, 3, 0.3), o * CFrame.new(0, 12, -25.6), rgb(16, 18, 22))
		signText(gs, Enum.NormalId.Back, "IRON BAY FITNESS", rgb(80, 230, 140))
	end
	venueEntrance("Gym", Vector3.new(752, 0, -252.5), Vector3.new(0, 0, 1), { Sign = "IRON BAY FITNESS", Sub = "24/7 · KRAFT · CARDIO", Color = rgb(80, 220, 140), Width = 14, Welcome = "Iron Bay Fitness - Training $15 oder Mitgliedschaft am Empfang" })

	-- 6c) RESTAURANTS: Maison Azure (Luxus), Bayfront Kitchen (modern) --------------------------------
	local function restaurant(id, o, opts)
		local m = model(interiors, id)
		room(m, o, 64, 46, 15, { Floor = opts.Floor, FloorMat = opts.FloorMat, Wall = opts.Wall, WallMat = opts.WallMat, Ceiling = opts.Ceiling, LightColor = opts.Light, LightBright = 0.6 })
		innerDoor(m, o * CFrame.new(31.4, 0, 0) * CFrame.Angles(0, math.rad(90), 0), id, opts.Title)
		counter(m, o * CFrame.new(-26, 0, 0) * CFrame.Angles(0, math.rad(90), 0), 20, opts.Bar, opts.BarTop)
		interact(m, "Order", o * CFrame.new(-23.6, 2.6, 0) * CFrame.Angles(0, math.rad(90), 0), "Shop", "Bestellen", opts.Title, { ShopId = opts.ShopId })
		local bs = mk(m, "BarSign", Vector3.new(0.3, 2.6, 16), o * CFrame.new(-31.4, 10, 0), rgb(16, 16, 20))
		signText(bs, Enum.NormalId.Right, opts.Title, opts.Accent)
		for ix = 0, 2 do
			for iz = 0, 2 do
				diningTable(m, o * CFrame.new(-10 + ix * 12, 0, -14 + iz * 14), (ix + iz) % 2 == 0 and 4 or 2, opts.Table)
			end
		end
		for _, s in ipairs({ -1, 1 }) do
			plant(m, o * CFrame.new(28, 0, s * 19))
			plant(m, o * CFrame.new(-28, 0, s * 19))
		end
		if opts.Piano then
			mk(m, "Piano", Vector3.new(5, 3.4, 6), o * CFrame.new(20, 1.7, 16), rgb(10, 10, 12), M.SmoothPlastic, { Reflectance = 0.3 })
		end
		return m
	end
	restaurant("MaisonAzure", CFrame.new(5250, Y0, 640), { Title = "MAISON AZURE", ShopId = "FineDining", Floor = rgb(60, 40, 30), FloorMat = M.WoodPlanks, Wall = rgb(30, 50, 80), WallMat = M.Fabric, Ceiling = rgb(20, 28, 44), Light = rgb(255, 214, 160), Bar = rgb(40, 30, 24), BarTop = rgb(220, 200, 150), Table = rgb(250, 250, 248), Accent = rgb(230, 200, 120), Piano = true })
	restaurant("BayfrontKitchen", CFrame.new(5250, Y0, 820), { Title = "BAYFRONT KITCHEN", ShopId = "ModernKitchen", Floor = rgb(200, 196, 188), FloorMat = M.Concrete, Wall = rgb(240, 240, 236), Ceiling = rgb(250, 250, 250), Light = rgb(255, 246, 230), Bar = rgb(30, 32, 36), BarTop = rgb(245, 245, 245), Table = rgb(180, 140, 100), Accent = rgb(64, 224, 255) })
	venueEntrance("MaisonAzure", Vector3.new(-205, 0, -1359.5), Vector3.new(0, 0, -1), { Sign = "MAISON AZURE", Sub = "FINE DINING", Color = rgb(230, 200, 120), Width = 14, Font = Enum.Font.Garamond, Welcome = "Bonsoir - willkommen im Maison Azure" })
	venueEntrance("BayfrontKitchen", Vector3.new(168, 0, -1360), Vector3.new(0, 0, -1), { Sign = "BAYFRONT KITCHEN", Sub = "MODERN AMERICAN", Color = rgb(64, 224, 255), Width = 14, Welcome = "Willkommen in der Bayfront Kitchen" })

	-- 6d) CLUBS: bestehende Clubs erhalten Innenraeume -------------------------------------------------
	local function club(id, o, name, accent)
		local m = model(interiors, id)
		room(m, o, 84, 70, 20, { Floor = rgb(16, 14, 20), FloorMat = M.SmoothPlastic, Wall = rgb(20, 18, 26), Ceiling = rgb(8, 8, 12), LightColor = accent, LightBright = 0.7, LightRange = 28, NeonLights = true })
		innerDoor(m, o * CFrame.new(41.4, 0, 0) * CFrame.Angles(0, math.rad(90), 0), id, name)
		-- Tanzflaeche 7x7
		for ix = 0, 6 do
			for iz = 0, 6 do
				local t = mk(m, "DanceTile", Vector3.new(4.8, 0.2, 4.8), o * CFrame.new(-14 + ix * 5, 0.1, -15 + iz * 5), accent, M.Neon)
				t:SetAttribute("Seed", ix * 7 + iz)
				CollectionService:AddTag(t, "DanceTile")
			end
		end
		interact(m, "DanceInteract", o * CFrame.new(1, 2.6, 0), "Activity", "Tanzen", "Tanzflaeche", { ActivityId = "Dance" }, Vector3.new(4, 5, 4))
		-- DJ-Pult und Buehne (West)
		mk(m, "Stage", Vector3.new(12, 2, 30), o * CFrame.new(-36, 1, 0), rgb(30, 28, 36), M.SmoothPlastic)
		mk(m, "DJBooth", Vector3.new(4, 4, 10), o * CFrame.new(-33, 4, 0), rgb(14, 14, 18), M.Metal)
		local dj = mk(m, "DJGlow", Vector3.new(0.2, 1, 10), o * CFrame.new(-30.9, 4.6, 0), accent, M.Neon)
		local _ = dj
		for i = -2, 2 do
			mk(m, "Speaker", Vector3.new(3, 8, 3), o * CFrame.new(-39, 6, i * 7), rgb(10, 10, 12))
		end
		local ls = mk(m, "ClubSign", Vector3.new(0.3, 4, 26), o * CFrame.new(-41.4, 14, 0), rgb(8, 8, 10))
		signText(ls, Enum.NormalId.Right, name, accent)
		-- Bar (Nord)
		counter(m, o * CFrame.new(4, 0, -31), 36, rgb(20, 20, 26), accent:Lerp(rgb(255, 255, 255), 0.5))
		mk(m, "BarGlow", Vector3.new(36, 0.2, 0.2), o * CFrame.new(4, 3.2, -29.6), accent, M.Neon)
		interact(m, "BarInteract", o * CFrame.new(4, 2.6, -28.6), "Shop", "Bestellen", name .. " Bar", { ShopId = "ClubBar" })
		for i = -4, 4 do
			seat(m, o * CFrame.new(4 + i * 3.6, 0, -27.4) * CFrame.Angles(0, math.pi, 0), rgb(40, 40, 46))
		end
		-- Lounges (Sued)
		for i = 0, 2 do
			sofa(m, o * CFrame.new(-10 + i * 14, 0, 31) * CFrame.Angles(0, math.pi, 0), 9, rgb(60, 30, 60))
			mk(m, "LoungeTable", Vector3.new(4, 1.4, 2.4), o * CFrame.new(-10 + i * 14, 0.7, 27), rgb(20, 20, 24), M.Glass)
		end
		-- VIP-Lounge (Nordost, erhoeht, Glaswand) - Zugang nur mit VIP-Armband
		local vip = o * CFrame.new(32, 0, -24)
		mk(m, "VIPFloor", Vector3.new(18, 3, 20), vip * CFrame.new(0, 1.5, 0), rgb(40, 30, 10), M.SmoothPlastic)
		mk(m, "VIPGlass", Vector3.new(18, 8, 0.4), vip * CFrame.new(0, 7, 10), rgb(255, 220, 140), M.Glass, { Transparency = 0.55 })
		mk(m, "VIPGlass", Vector3.new(0.4, 8, 20), vip * CFrame.new(-9, 7, 0), rgb(255, 220, 140), M.Glass, { Transparency = 0.55 })
		local vs = mk(m, "VIPSign", Vector3.new(8, 1.6, 0.2), vip * CFrame.new(0, 12, 10.3), rgb(10, 8, 4))
		signText(vs, Enum.NormalId.Back, "VIP", rgb(255, 210, 110))
		sofa(m, vip * CFrame.new(0, 3, -6), 12, rgb(120, 90, 30))
		mk(m, "VIPTable", Vector3.new(5, 1.2, 2.6), vip * CFrame.new(0, 3.6, -1), rgb(20, 20, 22), M.Glass)
		interact(m, "VIPEnter", vip * CFrame.new(-4, 2.6, 12.5) * CFrame.Angles(0, math.pi, 0), "VenueDoor", "VIP-Lounge (Armband)", "VIP", { Link = id .. "_VIP", Side = "Out", Requires = "VIPPass", Welcome = "Willkommen in der VIP-Lounge" })
		interact(m, "VIPExit", vip * CFrame.new(-4, 5.6, 6) * CFrame.Angles(0, 0, 0), "VenueDoor", "VIP verlassen", "VIP", { Link = id .. "_VIP", Side = "In" })
		-- Stroboskop-Lichter
		for i = 0, 5 do
			local sp = mk(m, "ClubSpot", Vector3.new(1, 1, 1), o * CFrame.new(-14 + i * 6, 19, 0), accent, M.Neon, { CanCollide = false })
			local l = light(sp, 40, 3, Color3.fromHSV(i / 6, 0.8, 1), "SpotLight")
			l.Angle = 50
		end
		return m
	end
	local clubs = {
		{ Id = "Club_NEONROOM", Name = "NEONROOM", Accent = rgb(64, 224, 255), Door = Vector3.new(195.1, 0, -1898.5), Pos = CFrame.new(5460, Y0, 220) },
		{ Id = "Club_ECLIPSE", Name = "ECLIPSE", Accent = rgb(255, 72, 168), Door = Vector3.new(300.1, 0, -1898.5), Pos = CFrame.new(5460, Y0, 340) },
		{ Id = "Club_PULSE", Name = "PULSE", Accent = rgb(150, 90, 255), Door = Vector3.new(405.1, 0, -1898.5), Pos = CFrame.new(5460, Y0, 460) },
	}
	for _, c in ipairs(clubs) do
		club(c.Id, c.Pos, c.Name, c.Accent)
		-- Clubtueren existieren bereits: nur Interaktion vor die Tuer setzen
		local gy = groundY(c.Door.X, c.Door.Z + 3)
		interact(venueExt, "ClubDoor_" .. c.Name, CFrame.lookAt(Vector3.new(c.Door.X, gy + 2.6, c.Door.Z + 1.5), Vector3.new(c.Door.X, gy + 2.6, c.Door.Z + 10)), "VenueDoor", "Club betreten", c.Name, { Link = c.Id, Side = "Out", Welcome = "Willkommen im " .. c.Name .. " - Tanzflaeche, Bar und VIP-Lounge" })
	end

	-- 6e) SKYLINE 52: Rooftop-Restaurant auf Infill_bay_012 (Dachdeck y ~222) ------------------------
	do
		local deckY = 222
		local params2 = RaycastParams.new()
		params2.FilterType = Enum.RaycastFilterType.Exclude
		params2.FilterDescendantsInstances = { root }
		local hit = workspace:Raycast(Vector3.new(594, 400, 511), Vector3.new(0, -300, 0), params2)
		if hit and hit.Position.Y > 150 then
			deckY = hit.Position.Y
		end
		local m = model(exterior, "Skyline52")
		local o = CFrame.new(594, deckY, 511)
		mk(m, "Deck", Vector3.new(120, 0.4, 56), o * CFrame.new(0, 0.2, 0), rgb(150, 110, 80), M.WoodPlanks)
		for _, s in ipairs({ -1, 1 }) do
			mk(m, "Railing", Vector3.new(120, 3.6, 0.3), o * CFrame.new(0, 2.2, s * 28), rgb(190, 220, 235), M.Glass, { Transparency = 0.5 })
			mk(m, "Railing", Vector3.new(0.3, 3.6, 56), o * CFrame.new(s * 60, 2.2, 0), rgb(190, 220, 235), M.Glass, { Transparency = 0.5 })
		end
		counter(m, o * CFrame.new(-46, 0.4, 0) * CFrame.Angles(0, math.rad(90), 0), 22, rgb(30, 30, 34), rgb(240, 240, 240))
		interact(m, "Order", o * CFrame.new(-43.4, 3, 0) * CFrame.Angles(0, math.rad(90), 0), "Shop", "Bestellen", "SKYLINE 52", { ShopId = "Rooftop" })
		for ix = 0, 3 do
			for iz = 0, 1 do
				diningTable(m, o * CFrame.new(-26 + ix * 16, 0.4, -12 + iz * 24), 4, rgb(245, 245, 240))
			end
		end
		for i = 0, 11 do
			local lp = mk(m, "StringLight", Vector3.new(0.5, 0.5, 0.5), o * CFrame.new(-55 + i * 10, 9, 0), rgb(255, 210, 140), M.Neon, { CanCollide = false })
			light(lp, 16, 0.8, rgb(255, 200, 130))
		end
		mk(m, "LightWire", Vector3.new(110, 0.1, 0.1), o * CFrame.new(0, 9.3, 0), rgb(30, 30, 30), M.SmoothPlastic, { CanCollide = false })
		for _, s in ipairs({ -1, 1 }) do
			mk(m, "WirePole", Vector3.new(0.4, 9.4, 0.4), o * CFrame.new(s * 56, 4.7, 0), rgb(30, 30, 30), M.Metal)
		end
		-- Aufzug (Dach): Blick nach Norden auf das Deck
		local liftCF = o * CFrame.new(40, 0.4, 20) * CFrame.Angles(0, math.pi, 0)
		mk(m, "Lift", Vector3.new(8, 11, 6), liftCF * CFrame.new(0, 5.5, 3), rgb(30, 32, 36), M.Metal)
		local ls = mk(m, "LiftSign", Vector3.new(6, 1.2, 0.2), liftCF * CFrame.new(0, 9, -0.05), rgb(10, 10, 12))
		signText(ls, Enum.NormalId.Front, "LIFT · STRASSE", rgb(255, 160, 100))
		interact(m, "LiftInteract", liftCF * CFrame.new(0, 2.6, -1.5), "VenueDoor", "Aufzug nach unten", "SKYLINE 52", { Link = "Skyline52", Side = "In" })
		local sg = mk(m, "RoofSign", Vector3.new(26, 5, 0.6), o * CFrame.new(0, 7, -27.8), rgb(14, 14, 18))
		signText(sg, Enum.NormalId.Back, "SKYLINE 52", rgb(255, 140, 90))
	end
	venueEntrance("Skyline52", Vector3.new(594, 0, 546.5), Vector3.new(0, 0, 1), { Sign = "SKYLINE 52", Sub = "ROOFTOP · AUFZUG", Color = rgb(255, 140, 90), Width = 12, Welcome = "SKYLINE 52 - Rooftop-Restaurant ueber Bayfront" })

	----------------------------------------------------------------------------------------------------
	-- 7) AUTOHAEUSER
	----------------------------------------------------------------------------------------------------
	local dealerExt = folder(exterior, "Dealerships")
	-- 7a) Sawgrass Motors (Standard) - bestehendes Gebaeude SawgrassMotors + Ausstellungsgelaende
	do
		local m, doorCF, base = entrance(dealerExt, "SawgrassMotorsDealer", Vector3.new(-2693, 0, 764.5), Vector3.new(0, 0, 1), { Sign = "SAWGRASS MOTORS", Sub = "NEU- & GEBRAUCHTWAGEN", Color = rgb(64, 200, 255), Width = 20 })
		interact(m, "DealerInteract", doorCF, "Dealer", "Fahrzeuge ansehen", "Sawgrass Motors", { DealerId = "Standard" })
		kiosk(m, "GarageKiosk", base * CFrame.new(16, 0, -3), rgb(80, 140, 255), "P")
		interact(m, "GarageInteract", base * CFrame.new(16, 2.6, -4.6), "Garage", "Garage", "Sawgrass Motors Garage")
		kiosk(m, "TuneKiosk", base * CFrame.new(-16, 0, -3), rgb(255, 160, 60), "TUNING")
		interact(m, "TuneInteract", base * CFrame.new(-16, 2.6, -4.6), "Tuning", "Tuning", "Sawgrass Motors Service")
		local gy = groundY(-2693, 800)
		local cars = { { "Compact", rgb(240, 120, 40) }, { "Sedan", rgb(30, 60, 110) }, { "SUV", rgb(240, 240, 238) }, { "Pickup", rgb(170, 20, 28) } }
		for i, c in ipairs(cars) do
			local px = -2693 - 45 + (i - 1) * 30
			mk(m, "Podium", Vector3.new(22, 0.6, 26), CFrame.new(px, gy + 0.3, 812), rgb(230, 232, 236), M.SmoothPlastic)
			displayCar(m, c[1], CFrame.new(px, gy + 0.6, 812) * CFrame.Angles(0, math.rad(200), 0), c[2])
		end
		local pad = mk(m, "TestDrivePad", Vector3.new(12, 0.2, 20), CFrame.new(-2693, gy + 0.1, 1300), rgb(64, 200, 255), M.Neon, { Transparency = 0.6, CanCollide = false })
		pad:SetAttribute("DealerId", "Standard")
		CollectionService:AddTag(pad, "TestDrivePad")
		local ps = mk(m, "PadSign", Vector3.new(8, 1.4, 0.2), CFrame.new(-2693, gy + 4, 1288), rgb(14, 16, 22))
		signText(ps, Enum.NormalId.Front, "PROBEFAHRT", rgb(64, 200, 255))
		-- Autotreffen-Treffpunkt auf dem Gelaende
		interact(m, "CarMeet", CFrame.new(-2600, gy + 2.6, 1200), "Activity", "Autotreffen", "Treffpunkt Sawgrass Motors", { ActivityId = "CarMeet" })
	end
	-- 7b) Bayfront Prestige (Luxus) - Showroom-Innenraum + Eingang Downtown/Midtown
	do
		local m = model(interiors, "BayfrontPrestige")
		local o = CFrame.new(5660, Y0, 300)
		room(m, o, 100, 64, 18, { Floor = rgb(235, 235, 238), FloorMat = M.Marble, Wall = rgb(250, 250, 250), Ceiling = rgb(255, 255, 255), LightBright = 0.45, LightRange = 22 })
		innerDoor(m, o * CFrame.new(49.4, 0, 0) * CFrame.Angles(0, math.rad(90), 0), "Prestige", "Bayfront Prestige")
		counter(m, o * CFrame.new(36, 0, -20) * CFrame.Angles(0, math.rad(90), 0), 10, rgb(20, 20, 24), rgb(220, 190, 110))
		interact(m, "DealerInteract", o * CFrame.new(33.6, 2.6, -20) * CFrame.Angles(0, math.rad(90), 0), "Dealer", "Beratung & Kauf", "Bayfront Prestige", { DealerId = "Luxury" })
		interact(m, "TuneInteract", o * CFrame.new(33.6, 2.6, -14) * CFrame.Angles(0, math.rad(90), 0), "Tuning", "Individualisierung", "Prestige Atelier")
		local cars = { { "LuxurySedan", rgb(20, 20, 22) }, { "LuxurySUV", rgb(200, 180, 140) }, { "Sports", rgb(170, 20, 28) }, { "Convertible", rgb(240, 240, 238) }, { "Supercar", rgb(240, 200, 40) } }
		for i, c in ipairs(cars) do
			local px = -36 + (i - 1) * 16
			local pz = (i % 2 == 0) and 14 or -6
			local pod = mk(m, "Turntable", Vector3.new(12, 0.5, 12), o * CFrame.new(px, 0.25, pz), rgb(30, 30, 34), M.Metal, { Shape = Enum.PartType.Cylinder })
			pod.CFrame = o * CFrame.new(px, 0.25, pz) * CFrame.Angles(0, 0, math.rad(90))
			pod.Size = Vector3.new(0.5, 13, 13)
			local ring = mk(m, "TurntableGlow", Vector3.new(0.1, 13.4, 13.4), o * CFrame.new(px, 0.05, pz) * CFrame.Angles(0, 0, math.rad(90)), rgb(220, 180, 90), M.Neon, { Shape = Enum.PartType.Cylinder, CanCollide = false })
			local _ = ring
			displayCar(m, c[1], o * CFrame.new(px, 0.5, pz) * CFrame.Angles(0, math.rad(30 + i * 25), 0), c[2])
		end
		local s = mk(m, "WallLogo", Vector3.new(0.3, 4, 30), o * CFrame.new(-49.4, 12, 0), rgb(255, 255, 255))
		local _ = s
		local ws = mk(m, "LogoEast", Vector3.new(0.3, 3, 26), o * CFrame.new(49.3, 13, 0), rgb(255, 255, 255))
		signText(ws, Enum.NormalId.Left, "BAYFRONT PRESTIGE", rgb(180, 140, 60))
	end
	do
		local m = venueEntrance("Prestige", Vector3.new(-279.5, 0, -1127), Vector3.new(-1, 0, 0), { Sign = "BAYFRONT PRESTIGE", Sub = "LUXURY · SPORTS · SUPERCARS", Color = rgb(220, 180, 90), Width = 16, Welcome = "Willkommen bei Bayfront Prestige" })
		local gy = groundY(-312, -1080)
		local pad = mk(m, "TestDrivePad", Vector3.new(10, 0.2, 18), CFrame.lookAt(Vector3.new(-312, gy + 0.1, -1080), Vector3.new(-312, gy + 0.1, -1120)), rgb(220, 180, 90), M.Neon, { Transparency = 0.6, CanCollide = false })
		pad:SetAttribute("DealerId", "Luxury")
		CollectionService:AddTag(pad, "TestDrivePad")
	end

	----------------------------------------------------------------------------------------------------
	-- 8) GARAGEN (Parkhaeuser), TUNING-WERKSTATT, BASKETBALLPLATZ
	----------------------------------------------------------------------------------------------------
	local misc = folder(exterior, "Services")
	for i, ge in ipairs(CollectionService:GetTagged("GarageEntrance")) do
		if ge:IsA("BasePart") and ge:IsDescendantOf(workspace.Map) then
			local p = ge.Position + Vector3.new(8, 0, 0)
			local gy = groundY(p.X, p.Z)
			local cf = CFrame.new(p.X, gy, p.Z)
			kiosk(misc, "GarageKiosk" .. i, cf, rgb(80, 140, 255), "P")
			interact(misc, "GarageInteract" .. i, cf * CFrame.new(0, 2.6, -1.4), "Garage", "Garage", "Parkhaus")
		end
	end
	do
		local m, doorCF = entrance(misc, "AutoRepairTuning", Vector3.new(-3563.5, 0, -823), Vector3.new(-1, 0, 0), { Sign = "MIAMI AUTO REPAIR", Sub = "TUNING · LACK · FELGEN", Color = rgb(255, 160, 60), Width = 14 })
		interact(m, "TuneInteract", doorCF, "Tuning", "Tuning-Werkstatt", "Miami Auto Repair")
	end
	do
		local m = model(misc, "BayfrontCourt")
		local gy = groundY(965, 780)
		local o = CFrame.new(965, gy, 780)
		mk(m, "Court", Vector3.new(28, 0.2, 48), o * CFrame.new(0, 0.1, 0), rgb(40, 110, 160), M.SmoothPlastic)
		mk(m, "Key", Vector3.new(10, 0.22, 10), o * CFrame.new(0, 0.11, -19), rgb(220, 100, 60), M.SmoothPlastic)
		mk(m, "Key", Vector3.new(10, 0.22, 10), o * CFrame.new(0, 0.11, 19), rgb(220, 100, 60), M.SmoothPlastic)
		mk(m, "CenterLine", Vector3.new(28, 0.23, 0.3), o * CFrame.new(0, 0.12, 0), rgb(255, 255, 255), M.SmoothPlastic)
		for _, s in ipairs({ -1, 1 }) do
			local hcf = o * CFrame.new(0, 0, s * 23)
			mk(m, "HoopPole", Vector3.new(0.6, 12, 0.6), hcf * CFrame.new(0, 6, s * 1.5), rgb(40, 40, 44), M.Metal)
			mk(m, "Backboard", Vector3.new(6, 3.6, 0.3), hcf * CFrame.new(0, 11, s * 1), rgb(240, 240, 245), M.Glass, { Transparency = 0.3 })
			mk(m, "Rim", Vector3.new(2, 0.2, 2), hcf * CFrame.new(0, 10, -s * 0.2), rgb(240, 100, 30), M.Metal, { CanCollide = false })
			interact(m, "HoopsInteract", CFrame.lookAt((hcf * CFrame.new(0, 2.6, -s * 8)).Position, hcf.Position + Vector3.new(0, 2.6, 0)), "Activity", "Wuerfe ueben", "Bayfront Court", { ActivityId = "Hoops" })
		end
		for _, s in ipairs({ -1, 1 }) do
			mk(m, "Fence", Vector3.new(0.2, 6, 48), o * CFrame.new(s * 14.5, 3, 0), rgb(60, 60, 64), M.DiamondPlate, { Transparency = 0.4 })
		end
	end

	-- Zusammenfassung
	local n = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return string.format("Prompt 10 gebaut: %d Teile, %d Interaktionen", n, #CollectionService:GetTagged("Interactable"))
end
