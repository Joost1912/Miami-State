-- InfillKit (Prompt 08): verdichtet uebergrosse, fast leere Grundstuecke (Lots) kontrolliert.
-- * Gebaeudezeilen an den Strassenfronten (Front zur Strasse), Innenbereich bleibt Parkplatz/Zufahrt.
-- * Jeder Bauplatz wird geprueft: frei von Gebaeuden/Fahrzeugen/Markern (Tags), keine Zufahrtsrampe davor.
-- * Jeder 3. Platz bleibt offen (Zufahrt) bzw. wird kleine Gruenanlage -> keine geschlossenen Mauern.
-- * Liefert Kartendaten (Buildings/Green) fuer Config.MapExtra.
local CollectionService = game:GetService("CollectionService")
local Kit = require(game:GetService("ServerStorage").MapBuildTools.MapKit:Clone())
local Decor = game:GetService("ServerStorage").MapAssets.Decor
local InfillKit = {}
local rgb = Color3.fromRGB

local FACADES = { rgb(240, 228, 206), rgb(232, 222, 210), rgb(214, 226, 222), rgb(236, 214, 200), rgb(222, 222, 214), rgb(244, 236, 220), rgb(210, 216, 226) }
local ACCENTS = { rgb(200, 120, 90), rgb(110, 160, 170), rgb(180, 150, 100), rgb(120, 130, 150), rgb(170, 110, 100) }
local SHOPS = { "CORNER MARKET", "LAUNDROMAT", "BARBER CO", "PHONE FIX", "DELI & GRILL", "PET WORLD", "DENTAL CARE", "INSURANCE", "TAX SERVICE", "VET CLINIC", "FITNESS 24", "HAIR STUDIO", "TAQUERIA", "PIZZA SLICE", "DONUT TIME", "THRIFT SHOP" }

local function placeDecor(parent, name, pos, yaw, ground)
	local m = Decor[name]:Clone()
	m:PivotTo(CFrame.new(pos.X, 50, pos.Z) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	local cf, s = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + Vector3.new(0, ground - (cf.Y - s.Y / 2), 0))
	m.Parent = parent
	return m
end

-- Spielrelevante Marker (teils nicht abfragbar -> direkt ueber Tags pruefen)
local MARKER_TAGS = { "VehicleSpawnPad", "VehicleParkSpot", "FuelPump", "ParkedCar", "Interactable", "StoreEntrance", "ShopEntrance" }
local function markerInside(cf, size)
	for _, tag in ipairs(MARKER_TAGS) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			if inst:IsDescendantOf(workspace) then
				local p = inst:IsA("BasePart") and inst.Position or (inst:IsA("Model") and inst:GetPivot().Position)
				if p then
					local rel = cf:PointToObjectSpace(p)
					if math.abs(rel.X) < size.X / 2 + 4 and math.abs(rel.Z) < size.Z / 2 + 4 then
						return true
					end
				end
			end
		end
	end
	return false
end

-- Bauplatz frei? (alles >1.2 hoch, getaggte Objekte, Fahrzeuge -> belegt)
local function isFree(cf, size, ignore)
	if markerInside(cf, size) then
		return false, "Spielmarker"
	end
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = ignore
	local parts = workspace:GetPartBoundsInBox(cf * CFrame.new(0, size.Y / 2 + 1.0, 0), size + Vector3.new(6, 0, 6), op)
	for _, p in ipairs(parts) do
		if p.Name == "DrivewayRamp" then
			return false, "Zufahrt"
		end
		if #CollectionService:GetTags(p) > 0 and p.Name ~= "Lawn" then
			return false, "Marker " .. p.Name
		end
		if p.Size.Y > 1.2 and p.Transparency < 0.95 then
			return false, "belegt " .. p:GetFullName()
		end
	end
	return true
end

-- Vorplatz zur Strasse frei von Zufahrten?
local function frontClear(cf, w, d, ignore)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = ignore
	local parts = workspace:GetPartBoundsInBox(cf * CFrame.new(0, 2, -d / 2 - 22), Vector3.new(w + 10, 6, 40), op)
	for _, p in ipairs(parts) do
		if p.Name == "DrivewayRamp" then
			return false
		end
	end
	return true
end

local function pocketGreen(parent, cf, w, d, ground, rng, map)
	local m = Instance.new("Model")
	m.Name = "PocketGreen"
	Kit.part(m, "Lawn", Vector3.new(w, 0.5, d), cf * CFrame.new(0, 0.25, 0), rgb(86, 146, 70), Enum.Material.Grass)
	Kit.part(m, "Path", Vector3.new(6, 0.55, d), cf * CFrame.new(0, 0.28, 0), rgb(214, 204, 184), Enum.Material.Pavement)
	local trees = { "Tree_Oak", "Tree_Round", "Tree_Blossom", "Tree_Cypress" }
	for i = 1, rng:NextInteger(2, 3) do
		local p = cf * Vector3.new(rng:NextNumber(-w / 2 + 8, -6), 0, rng:NextNumber(-d / 2 + 8, d / 2 - 8))
		if rng:NextNumber() < 0.4 then
			Kit.palm(m, Vector3.new(p.X, ground + 0.5, p.Z))
		else
			placeDecor(m, trees[rng:NextInteger(1, #trees)], p, rng:NextInteger(0, 359), ground + 0.5)
		end
	end
	for _, z in ipairs({ -d / 4, d / 4 }) do
		local p = cf * Vector3.new(6, 0, z)
		placeDecor(m, "Bench", p, math.deg(math.atan2(-cf.LookVector.X, -cf.LookVector.Z)) + 90, ground + 0.5)
	end
	placeDecor(m, "FlowerBed_" .. rng:NextInteger(1, 3), cf * Vector3.new(w / 2 - 7, 0, 0), 90, ground + 0.5)
	placeDecor(m, "ParkLamp", cf * Vector3.new(4, 0, -d / 2 + 3), 0, ground + 0.5)
	m.Parent = parent
	table.insert(map.Green, { math.floor(cf.X), math.floor(cf.Z), w, d, 0 })
	return m
end

-- Ein Grundstueck verdichten. lot = Part (Lot_*). Gibt Anzahl neuer Gebaeude/Gruenflaechen zurueck.
function InfillKit.fill(lot, parent, seed, map)
	local rng = Random.new(seed)
	local ground = lot.Position.Y + lot.Size.Y / 2
	local x0, x1 = lot.Position.X - lot.Size.X / 2, lot.Position.X + lot.Size.X / 2
	local z0, z1 = lot.Position.Z - lot.Size.Z / 2, lot.Position.Z + lot.Size.Z / 2
	local folder = Instance.new("Folder")
	folder.Name = "Infill_" .. lot.Name
	local built, greens, skipped = 0, 0, 0
	local ignore = { lot }
	-- Kanten: { Startpunkt, Laufrichtung, Front-Richtung(rot), Laenge }
	local M = 14
	local edges = {
		{ Vector3.new(x0, 0, z0), Vector3.new(0, 0, 1), math.rad(90), z1 - z0 }, -- West, Front -X
		{ Vector3.new(x1, 0, z0), Vector3.new(0, 0, 1), math.rad(-90), z1 - z0 }, -- Ost, Front +X
		{ Vector3.new(x0, 0, z0), Vector3.new(1, 0, 0), 0, x1 - x0 }, -- Nord, Front -Z
		{ Vector3.new(x0, 0, z1), Vector3.new(1, 0, 0), math.rad(180), x1 - x0 }, -- Sued, Front +Z
	}
	local slot = 0
	for _, e in ipairs(edges) do
		local start, dir, rot, len = e[1], e[2], e[3], e[4]
		local front = CFrame.Angles(0, rot, 0).LookVector -- zeigt zur Strasse
		local inward = -front
		local t = 40 -- Ecken frei lassen (Sicht, Kreuzung)
		while t < len - 40 do
			slot += 1
			local w = rng:NextInteger(44, 64)
			local d = rng:NextInteger(34, 46)
			local center = start + dir * (t + w / 2) + inward * (M + d / 2)
			local cf = CFrame.new(center.X, ground, center.Z) * CFrame.Angles(0, rot, 0)
			if t + w > len - 40 then
				break
			end
			local free, why = isFree(cf, Vector3.new(w, 30, d), ignore)
			if free and slot % 3 == 0 then
				pocketGreen(folder, cf, w, d, ground, rng, map)
				greens += 1
			elseif free and frontClear(cf, w, d, ignore) then
				local kind = rng:NextInteger(1, 3)
				local name = string.format("Infill_%d_%d", math.floor(center.X), math.floor(center.Z))
				local color = FACADES[rng:NextInteger(1, #FACADES)]
				local h
				if kind == 1 then
					local floors = rng:NextInteger(2, 4)
					Kit.lowriseApartments(folder, name, Vector3.new(center.X, ground, center.Z), w, d, floors, { rot = rot, color = color, accent = ACCENTS[rng:NextInteger(1, #ACCENTS)], seed = slot })
					h = floors * 11 + 8
				elseif kind == 2 then
					local floors = rng:NextInteger(3, 6)
					local _, H = Kit.midrise(folder, name, Vector3.new(center.X, ground, center.Z), w, d, floors, { rot = rot, color = color, floorH = 12 })
					h = H
				else
					local sh = rng:NextInteger(14, 20)
					local fcf = CFrame.new(center.X, ground, center.Z) * CFrame.Angles(0, rot, 0) * CFrame.new(0, 0, -d / 2)
					Kit.storefront(folder, fcf, w, sh, d, SHOPS[rng:NextInteger(1, #SHOPS)], color, rgb(255, 236, 200))
					h = sh
				end
				-- Vorgarten: Strassenbaum und Pflanzkuebel
				local tp = cf * Vector3.new(rng:NextNumber(-w / 2 + 5, w / 2 - 5), 0, -d / 2 - 6)
				if rng:NextNumber() < 0.5 then
					Kit.palm(folder, Vector3.new(tp.X, ground, tp.Z))
				else
					placeDecor(folder, "Bush_" .. (rng:NextNumber() < 0.5 and "A" or "Flower"), tp, 0, ground)
				end
				table.insert(map.Buildings, { math.floor(center.X), math.floor(center.Z), (rot % math.pi == 0) and w or d, (rot % math.pi == 0) and d or w, 0, math.floor(h) })
				built += 1
			else
				skipped += 1
			end
			t += w + rng:NextInteger(10, 22) -- Gassen zwischen den Haeusern
		end
	end
	folder.Parent = parent
	return built, greens, skipped
end

-- Zentrale Gruenanlage auf der groessten freien Innenflaeche (Wege, Baeume, Baenke, optional Spielplatz)
function InfillKit.centerPark(lot, parent, seed, map)
	local rng = Random.new(seed)
	local ground = lot.Position.Y + lot.Size.Y / 2
	local x0, x1 = lot.Position.X - lot.Size.X / 2 + 90, lot.Position.X + lot.Size.X / 2 - 90
	local z0, z1 = lot.Position.Z - lot.Size.Z / 2 + 90, lot.Position.Z + lot.Size.Z / 2 - 90
	for _, sz in ipairs({ { 200, 170 }, { 170, 140 }, { 140, 110 }, { 110, 90 } }) do
		local w, d = sz[1], sz[2]
		local best
		for x = x0 + w / 2, x1 - w / 2, 20 do
			for z = z0 + d / 2, z1 - d / 2, 20 do
				local cf = CFrame.new(x, ground, z)
				if isFree(cf, Vector3.new(w, 30, d), { lot }) then
					local dist = (Vector3.new(x, 0, z) - Vector3.new(lot.Position.X, 0, lot.Position.Z)).Magnitude
					if not best or dist < best[2] then
						best = { cf, dist }
					end
				end
			end
			task.wait()
		end
		if best then
			local cf = best[1]
			local m = Instance.new("Model")
			m.Name = "NeighborhoodPark"
			Kit.part(m, "Lawn", Vector3.new(w, 0.5, d), cf * CFrame.new(0, 0.25, 0), rgb(86, 146, 70), Enum.Material.Grass)
			for _, s in ipairs({ { w + 1.6, 0.8, 0.8, 0, -d / 2 - 0.4 }, { w + 1.6, 0.8, 0.8, 0, d / 2 + 0.4 }, { 0.8, 0.8, d, -w / 2 - 0.4, 0 }, { 0.8, 0.8, d, w / 2 + 0.4, 0 } }) do
				Kit.part(m, "Curb", Vector3.new(s[1], s[2], s[3]), cf * CFrame.new(s[4], 0.4, s[5]), rgb(205, 205, 200), Enum.Material.Concrete)
			end
			Kit.part(m, "PathEW", Vector3.new(w, 0.55, 8), cf * CFrame.new(0, 0.28, 0), rgb(214, 204, 184), Enum.Material.Pavement)
			Kit.part(m, "PathNS", Vector3.new(8, 0.55, d), cf * CFrame.new(0, 0.28, 0), rgb(214, 204, 184), Enum.Material.Pavement)
			Kit.part(m, "Plaza", Vector3.new(26, 0.6, 26), cf * CFrame.new(0, 0.3, 0), rgb(222, 214, 196), Enum.Material.Pavement)
			local trees = { "Tree_Oak", "Tree_Round", "Tree_Blossom", "Tree_Cypress" }
			local n = math.floor(w * d / 2200)
			for _ = 1, n do
				local px, pz = rng:NextNumber(-w / 2 + 10, w / 2 - 10), rng:NextNumber(-d / 2 + 10, d / 2 - 10)
				if math.abs(px) > 12 and math.abs(pz) > 12 and not (px < -w / 4 + 34 and px > -w / 4 - 34 and pz > d / 4 - 26 and pz < d / 4 + 26) then
					local p = cf * Vector3.new(px, 0, pz)
					if rng:NextNumber() < 0.35 then
						Kit.palm(m, Vector3.new(p.X, ground + 0.5, p.Z))
					else
						placeDecor(m, trees[rng:NextInteger(1, #trees)], p, rng:NextInteger(0, 359), ground + 0.5)
					end
				end
			end
			for _, b in ipairs({ { 18, 8, 0 }, { -18, 8, 0 }, { 18, -8, 180 }, { -18, -8, 180 }, { 8, 18, -90 }, { -8, -18, 90 } }) do
				placeDecor(m, "Bench", cf * Vector3.new(b[1], 0, b[2]), b[3], ground + 0.5)
			end
			for _, l in ipairs({ { 14, 14 }, { -14, -14 }, { 14, -14 }, { -14, 14 } }) do
				placeDecor(m, "ParkLamp", cf * Vector3.new(l[1], 0, l[2]), 0, ground + 0.5)
			end
			for i = 1, 4 do
				placeDecor(m, "FlowerBed_" .. ((i - 1) % 3 + 1), cf * Vector3.new(({ 30, -30, 30, -30 })[i], 0, ({ 10, 10, -10, -10 })[i]), 0, ground + 0.5)
			end
			if w >= 140 then
				Kit.playground(m, cf * Vector3.new(-w / 4, 0.5, d / 4))
			end
			for i = 1, 6 do
				local side = (i % 2 == 0) and 1 or -1
				placeDecor(m, "Hedge_24", cf * Vector3.new(-w / 2 + 20 + (i - 1) * (w - 40) / 5, 0, side * (d / 2 - 2)), 0, ground + 0.5)
			end
			m.Parent = parent:FindFirstChild("Infill_" .. lot.Name) or parent
			table.insert(map.Green, { math.floor(cf.X), math.floor(cf.Z), w, d, 0 })
			return w, d
		end
	end
	return nil
end

return InfillKit
