-- Schritt 23: Wiederverwendbare Deko-Vorlagen fuer die Stadtueberarbeitung (ServerStorage.MapAssets.Decor).
-- Jede Vorlage wird aus Einzelteilen gebaut und per GeometryService zu EINER Union verschmolzen (Farben bleiben).
-- Gleiche Union-Geometrie rendert die Engine instanziert -> wenige Draw Calls trotz vieler Objekte.
-- Kollision: Baeume/Banke erhalten einen einfachen unsichtbaren Kollider, reine Optik ist nicht kollidierbar.
return function(Kit)
	local GS = game:GetService("GeometryService")
	local SS = game:GetService("ServerStorage")
	local M = Enum.Material
	local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder
	local UP = CFrame.Angles(0, 0, math.rad(90))
	local assets = Kit.folder(SS, "MapAssets")
	local old = assets:FindFirstChild("Decor")
	if old then
		old:Destroy()
	end
	local decor = Kit.folder(assets, "Decor")
	local O = Vector3.new(0, 2500, 0)
	local report = {}

	local function P(list, size, cf, color, mat, shape)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = CFrame.new(O) * cf
		p.Color = color
		p.Material = mat or M.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = workspace
		table.insert(list, p)
		return p
	end

	-- Teile -> Union-Vorlage (+ optionaler Kollider)
	local function make(name, parts, collider, opts)
		local base = table.remove(parts, 1)
		local ok, res = pcall(function()
			return GS:UnionAsync(base, parts, { CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Automatic, SplitApart = false })
		end)
		local m = Instance.new("Model")
		m.Name = name
		if ok and res and res[1] then
			local u = res[1]
			u.Name = "Mesh"
			u.UsePartColor = false
			u.Anchored = true
			u.CanCollide, u.CanQuery, u.CanTouch = false, false, false
			u.CastShadow = not (opts and opts.noShadow)
			u.Parent = m
			base:Destroy()
			for _, p in ipairs(parts) do
				p:Destroy()
			end
		else
			-- Fallback: Einzelteile behalten
			table.insert(parts, base)
			for _, p in ipairs(parts) do
				p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
				p.Parent = m
			end
		end
		if collider then
			local c = Instance.new("Part")
			c.Name = "Collider"
			c.Anchored = true
			c.Transparency = 1
			c.CastShadow = false
			c.CanTouch = false
			c.Size = collider[1]
			c.CFrame = CFrame.new(O) * collider[2]
			if collider[3] then
				c.Shape = collider[3]
			end
			c.Parent = m
		end
		m.WorldPivot = CFrame.new(O)
		m.Parent = decor
		table.insert(report, name)
		task.wait()
		return m
	end

	local WOOD = Color3.fromRGB(150, 108, 72)
	local IRON = Color3.fromRGB(36, 40, 44)
	local TRUNK = Color3.fromRGB(96, 74, 54)

	-- Amerikanische Parkbank (Holzlatten, gusseiserne Seitenteile), Sitzflaeche Richtung -Z
	do
		local t = {}
		for i = 0, 2 do
			P(t, Vector3.new(6, 0.25, 0.55), CFrame.new(0, 1.75, -0.5 + i * 0.65), WOOD, M.WoodPlanks)
		end
		for i = 0, 2 do
			P(t, Vector3.new(6, 0.5, 0.2), CFrame.new(0, 2.5 + i * 0.6, 1.05) * CFrame.Angles(math.rad(-12), 0, 0), WOOD, M.WoodPlanks)
		end
		for _, x in ipairs({ -2.7, 2.7 }) do
			P(t, Vector3.new(0.3, 1.7, 0.3), CFrame.new(x, 0.85, -0.6), IRON, M.Metal)
			P(t, Vector3.new(0.3, 3.6, 0.3), CFrame.new(x, 1.8, 1.0) * CFrame.Angles(math.rad(-10), 0, 0), IRON, M.Metal)
			P(t, Vector3.new(0.3, 0.25, 2.2), CFrame.new(x, 2.5, 0), IRON, M.Metal)
		end
		make("Bench", t, { Vector3.new(6, 1.9, 2), CFrame.new(0, 0.95, 0) })
	end

	-- Baeume: Rundkrone (Laubbaum), grosse Eiche, Zypresse, Bluehender Baum
	local function crownTree(name, h, crowns, leaf, trunkW)
		local t = {}
		P(t, Vector3.new(h, trunkW, trunkW), CFrame.new(0, h / 2, 0) * UP, TRUNK, M.Wood, CYL)
		for _, c in ipairs(crowns) do
			P(t, Vector3.new(c[4], c[4] * 0.85, c[4]), CFrame.new(c[1], h + c[2], c[3]), c[5] or leaf, M.LeafyGrass, BALL)
		end
		return make(name, t, { Vector3.new(h, trunkW, trunkW), CFrame.new(0, h / 2, 0) * UP, CYL })
	end
	crownTree("Tree_Round", 13, { { 0, 2, 0, 15 }, { 3, 5, -2, 10 }, { -3, 4.5, 2, 10 } }, Color3.fromRGB(74, 118, 56), 1.5)
	crownTree("Tree_Oak", 15, { { 0, 3, 0, 20 }, { 6, 1, 3, 13 }, { -6, 2, -3, 13 }, { 2, 7, -4, 11 } }, Color3.fromRGB(56, 96, 46), 2.2)
	crownTree("Tree_Blossom", 11, { { 0, 2, 0, 12 }, { 2.5, 4, 1, 8 }, { -2.5, 3.5, -1, 8 } }, Color3.fromRGB(240, 140, 180), 1.2) -- Bluehender Baum (Jacaranda-Stil)
	do -- Zypresse / Strassenbaum (schmal)
		local t = {}
		P(t, Vector3.new(5, 1, 1), CFrame.new(0, 2.5, 0) * UP, TRUNK, M.Wood, CYL)
		local g = Color3.fromRGB(46, 84, 50)
		P(t, Vector3.new(7, 14, 7), CFrame.new(0, 11, 0), g, M.LeafyGrass, BALL)
		P(t, Vector3.new(5, 10, 5), CFrame.new(0, 18, 0), g, M.LeafyGrass, BALL)
		make("Tree_Cypress", t, { Vector3.new(5, 1, 1), CFrame.new(0, 2.5, 0) * UP, CYL })
	end
	-- Bueshe
	do
		local t = {}
		P(t, Vector3.new(6, 4, 6), CFrame.new(0, 1.8, 0), Color3.fromRGB(64, 110, 54), M.LeafyGrass, BALL)
		P(t, Vector3.new(4, 3, 4), CFrame.new(2.4, 1.4, 1.2), Color3.fromRGB(74, 124, 60), M.LeafyGrass, BALL)
		make("Bush_A", t, nil, { noShadow = true })
		local t2 = {}
		P(t2, Vector3.new(5, 3.2, 5), CFrame.new(0, 1.4, 0), Color3.fromRGB(52, 98, 50), M.LeafyGrass, BALL)
		P(t2, Vector3.new(2.2, 1.2, 2.2), CFrame.new(1.2, 2.8, 0.6), Color3.fromRGB(240, 90, 120), M.SmoothPlastic, BALL) -- Bluete (Hibiskus)
		P(t2, Vector3.new(2, 1.1, 2), CFrame.new(-1.4, 2.6, -0.8), Color3.fromRGB(255, 170, 60), M.SmoothPlastic, BALL)
		make("Bush_Flower", t2, nil, { noShadow = true })
	end
	-- Blumenbeete (Steinkante + Erde + Blueten), drei Farbvarianten
	for i, cols in ipairs({
		{ Color3.fromRGB(240, 70, 110), Color3.fromRGB(255, 200, 60) },
		{ Color3.fromRGB(170, 90, 230), Color3.fromRGB(255, 255, 255) },
		{ Color3.fromRGB(255, 120, 40), Color3.fromRGB(240, 60, 70) },
	}) do
		local t = {}
		local stone = Color3.fromRGB(214, 206, 190)
		P(t, Vector3.new(10, 1, 0.6), CFrame.new(0, 0.5, -2.7), stone, M.Concrete)
		P(t, Vector3.new(10, 1, 0.6), CFrame.new(0, 0.5, 2.7), stone, M.Concrete)
		P(t, Vector3.new(0.6, 1, 6), CFrame.new(-4.7, 0.5, 0), stone, M.Concrete)
		P(t, Vector3.new(0.6, 1, 6), CFrame.new(4.7, 0.5, 0), stone, M.Concrete)
		P(t, Vector3.new(9, 0.7, 4.8), CFrame.new(0, 0.45, 0), Color3.fromRGB(80, 58, 40), M.Ground)
		for k = 0, 7 do
			local c = cols[(k % 2) + 1]
			P(t, Vector3.new(1.3, 1, 1.3), CFrame.new(-3.6 + (k % 4) * 2.4, 1.2, (k < 4) and -1.1 or 1.1), c, M.SmoothPlastic, BALL)
		end
		make("FlowerBed_" .. i, t, nil, { noShadow = true })
	end
	-- Bushaltestelle (Dach, Glasrueckwand, Bank, Mast mit Schild) - Front Richtung -Z (Strasse)
	do
		local t = {}
		local frame = Color3.fromRGB(40, 46, 56)
		P(t, Vector3.new(14, 0.5, 6), CFrame.new(0, 9, 0), frame, M.Metal)
		P(t, Vector3.new(14, 0.2, 6.2), CFrame.new(0, 9.35, 0), Color3.fromRGB(64, 224, 255), M.Neon)
		for _, x in ipairs({ -6.8, 6.8 }) do
			P(t, Vector3.new(0.4, 9, 0.4), CFrame.new(x, 4.5, 2.6), frame, M.Metal)
			P(t, Vector3.new(0.2, 7, 5), CFrame.new(x, 4.5, 0.2), Color3.fromRGB(150, 190, 210), M.Glass)
		end
		P(t, Vector3.new(13.6, 7, 0.2), CFrame.new(0, 4.5, 2.8), Color3.fromRGB(150, 190, 210), M.Glass)
		P(t, Vector3.new(10, 0.4, 1.6), CFrame.new(0, 1.8, 1.8), WOOD, M.WoodPlanks)
		P(t, Vector3.new(0.4, 12, 0.4), CFrame.new(-8.5, 6, -1.8), frame, M.Metal)
		P(t, Vector3.new(0.2, 2.4, 2.4), CFrame.new(-8.5, 11, -1.8), Color3.fromRGB(30, 110, 200), M.SmoothPlastic)
		P(t, Vector3.new(0.25, 1, 1), CFrame.new(-8.5, 11, -1.8), Color3.new(1, 1, 1), M.SmoothPlastic)
		make("BusShelter", t, { Vector3.new(14, 9, 0.6), CFrame.new(0, 4.5, 2.8) })
	end
	-- Muellcontainer (Gewerbe) - Brandstelle fuer die Feuerwehr
	do
		local t = {}
		P(t, Vector3.new(7, 4.4, 4), CFrame.new(0, 2.4, 0), Color3.fromRGB(40, 90, 60), M.Metal)
		P(t, Vector3.new(7.2, 0.4, 4.2), CFrame.new(0, 4.8, 0) * CFrame.Angles(math.rad(-6), 0, 0), Color3.fromRGB(30, 34, 36), M.Plastic)
		for _, x in ipairs({ -2.8, 2.8 }) do
			P(t, Vector3.new(0.6, 0.6, 0.6), CFrame.new(x, 0.3, 1.4), IRON, M.Metal, BALL)
			P(t, Vector3.new(0.6, 0.6, 0.6), CFrame.new(x, 0.3, -1.4), IRON, M.Metal, BALL)
		end
		make("Dumpster", t, { Vector3.new(7, 4.8, 4), CFrame.new(0, 2.4, 0) })
	end
	-- Hecke (2 Laengen)
	for _, len in ipairs({ 12, 24 }) do
		local t = {}
		P(t, Vector3.new(len, 3.2, 2.6), CFrame.new(0, 1.6, 0), Color3.fromRGB(52, 96, 48), M.LeafyGrass)
		P(t, Vector3.new(len - 0.4, 0.6, 2.2), CFrame.new(0, 3.3, 0), Color3.fromRGB(62, 110, 54), M.LeafyGrass)
		make("Hedge_" .. len, t, { Vector3.new(len, 3.2, 2.6), CFrame.new(0, 1.6, 0) }, { noShadow = true })
	end
	-- Parklaterne (Fussgaengerbereich)
	do
		local t = {}
		P(t, Vector3.new(12, 0.5, 0.5), CFrame.new(0, 6, 0) * UP, IRON, M.Metal, CYL)
		P(t, Vector3.new(1.4, 1.6, 1.4), CFrame.new(0, 12.6, 0), Color3.fromRGB(255, 236, 190), M.Neon)
		P(t, Vector3.new(1.8, 0.4, 1.8), CFrame.new(0, 13.6, 0), IRON, M.Metal)
		P(t, Vector3.new(1.2, 0.6, 1.2), CFrame.new(0, 0.3, 0), IRON, M.Metal)
		make("ParkLamp", t, { Vector3.new(12, 0.5, 0.5), CFrame.new(0, 6, 0) * UP, CYL })
	end
	return #report .. " Vorlagen: " .. table.concat(report, ", ")
end
