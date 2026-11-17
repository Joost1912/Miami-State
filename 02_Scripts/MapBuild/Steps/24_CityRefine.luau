-- Schritt 24: Stadtueberarbeitung (Phase 7). Baut NUR auf freien Flaechen (Kollisionsabfrage), loescht nichts Bestehendes.
-- Ergebnis in workspace.Map.Refinement (bei erneutem Ausfuehren wird nur dieser Ordner neu aufgebaut):
--   Infill    - Laeden/Cafes/Restaurants entlang der Strassen auf leeren Grundstuecksflaechen (Downtown/Midtown/Condo)
--   Plazas    - Pocket-Parks und kleine Plaetze auf Restflaechen
--   Parks     - Gestaltung freier Gruenflaechen (Terrain-Gras): Parks mit Wegen/Baenken, begruente Flaechen, Strassenbegleitgruen
--   Parking   - Pflanzinseln in grossen Parkplaetzen + Stellplatz-Marker fuer eigene Fahrzeuge
--   Street    - Bushaltestellen, Strassennamen-Schilder, Sitzbaenke/Muelleimer an Gehwegen
--   Markers   - Brandstellen (Feuerwehr), Kartenmarker (Bank, Juwelier, Werkstatt)
-- Deko stammt aus den Union-Vorlagen von Schritt 23 (instanziert gerendert).
return function(Kit)
	local CS = game:GetService("CollectionService")
	local SS = game:GetService("ServerStorage")
	local M = Enum.Material
	local decorT = SS:FindFirstChild("MapAssets") and SS.MapAssets:FindFirstChild("Decor")
	assert(decorT, "Schritt 23_DecorTemplates zuerst ausfuehren")
	local map = workspace.Map
	local old = map:FindFirstChild("Refinement")
	if old then
		old:Destroy()
	end
	local root = Kit.folder(map, "Refinement")
	local F = {}
	for _, n in ipairs({ "Infill", "Plazas", "Parks", "Parking", "Street", "Markers" }) do
		F[n] = Kit.folder(root, n)
	end
	local rng = Random.new(20261116)
	local stats = { shops = 0, plazas = 0, parks = 0, greens = 0, trees = 0, benches = 0, flowers = 0, bushes = 0, busStops = 0, signs = 0, islands = 0, parkSpots = 0, fireSpots = 0, parts = 0 }

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root }
	params.RespectCanCollide = false
	local ignore = nil -- aktuell gepruefte Grundstuecksflaeche (zaehlt nicht als belegt)
	local ignoreTop = 0
	local DRIVE = { "Asphalt", "Parking", "Apron", "Bay", "Drive", "Road", "Pad", "Lot", "Ramp", "Stall", "Garage", "Pool", "Fountain", "Water" }
	local function isDrive(name)
		for _, k in ipairs(DRIVE) do
			if name:find(k) then
				return true
			end
		end
		return false
	end
	local function isFree(cf, size)
		for _, p in ipairs(workspace:GetPartBoundsInBox(cf, size, params)) do
			if p ~= ignore and ((p.CanQuery and p.Transparency < 1) or p.CanCollide) then
				-- reine Pflasterflaechen (Vorplaetze) auf dem Grundstueck duerfen bebaut werden, Fahrflaechen nicht
				local flat = ignore and p.Size.Y <= 3 and (p.Position.Y + p.Size.Y / 2) <= ignoreTop + 0.7 and not isDrive(p.Name) and not isDrive(p.Parent.Name)
				if not flat then
					return false
				end
			end
		end
		return true
	end

	-- Vorlage platzieren
	local function place(name, cf, parent)
		local t = decorT:FindFirstChild(name)
		if not t then
			return nil
		end
		local m = t:Clone()
		m:PivotTo(cf)
		m.Parent = parent
		return m
	end
	local TREES = { "Tree_Round", "Tree_Oak", "Tree_Cypress", "Tree_Blossom" }
	local function tree(pos, parent, kind)
		stats.trees += 1
		if kind == "Palm" or (not kind and rng:NextNumber() < 0.28) then
			return Kit.palm(parent, pos, rng:NextNumber(24, 36))
		end
		return place(kind or TREES[rng:NextInteger(1, #TREES)], CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), parent)
	end
	local function bench(cf, parent)
		stats.benches += 1
		return place("Bench", cf, parent)
	end
	local function flowerBed(cf, parent)
		stats.flowers += 1
		return place("FlowerBed_" .. rng:NextInteger(1, 3), cf, parent)
	end
	local function bush(pos, parent)
		stats.bushes += 1
		return place(rng:NextNumber() < 0.35 and "Bush_Flower" or "Bush_A", CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), parent)
	end
	local function lamp(pos, parent)
		local m = place("ParkLamp", CFrame.new(pos), parent)
		if m then
			local glow = Kit.part(m, "Glow", Vector3.new(0.6, 0.6, 0.6), CFrame.new(pos + Vector3.new(0, 12.6, 0)), Color3.fromRGB(255, 236, 190), M.SmoothPlastic, { ghost = true, transp = 1 })
			local l = Instance.new("PointLight")
			l.Range, l.Brightness, l.Color, l.Shadows = 22, 1.2, Color3.fromRGB(255, 226, 170), false
			l.Parent = glow
			CS:AddTag(glow, "StreetLamp")
		end
		return m
	end
	local function marker(name, cf, tag, attrs)
		stats.fireSpots += (tag and tag:match("^FireSpot")) and 1 or 0
		return Kit.tagMarker(F.Markers, name, cf, tag, attrs)
	end

	local function inUrban(x, z)
		return x >= -320 and x <= 1000 and z >= -2200 and z <= 1000
	end

	-- Namen fuer neue Geschaefte (Cafes/Laeden mit vorhandenem Sortiment sind ueber Shops.ByName kaufbar)
	local CAFES = { "BEAN & LEAF", "SUNNY CAFE", "CAFE MOKA", "DONUT TIME", "BAKERY" }
	local RESTAURANTS = { "OCEAN TACOS", "MIAMI PIZZA CO.", "LITTLE HAVANA DINER", "SUSHI WAVE", "BAYSIDE GRILL", "CUBAN CORNER CAFE", "THE BURGER JOINT", "PASTA PALMA" }
	local SHOPS = { "PALM BOUTIQUE", "SURF & SUN", "BAYSIDE BOOKS", "FLORIDA FLOWERS", "VOLT ELECTRONICS", "CAREPLUS PHARMACY", "FRESHWAY MARKET", "SNEAKER STATION", "OPTICAL VISION", "SUNSET BARBERS", "LUXE NAILS", "GULF COAST SUPPLY" }
	local FACADES = {
		Color3.fromRGB(244, 226, 200), Color3.fromRGB(230, 214, 230), Color3.fromRGB(206, 232, 226), Color3.fromRGB(250, 236, 214),
		Color3.fromRGB(236, 206, 196), Color3.fromRGB(214, 222, 236), Color3.fromRGB(240, 240, 232),
	}
	local SIGNCOLS = { Color3.fromRGB(255, 120, 170), Color3.fromRGB(64, 224, 255), Color3.fromRGB(255, 210, 90), Color3.fromRGB(120, 255, 180), Color3.fromRGB(255, 255, 255) }
	local specials = { { "MIAMI STATE BANK", "Bank" }, { "MIAMI GOLD JEWELERS", "Jeweler" } }
	local nameIdx = 0
	local function nextShop()
		nameIdx += 1
		if specials[1] and nameIdx % 5 == 2 then
			local s = table.remove(specials, 1)
			return s[1], s[2]
		end
		local r = rng:NextNumber()
		if r < 0.25 then
			return CAFES[rng:NextInteger(1, #CAFES)], "Restaurant"
		elseif r < 0.55 then
			return RESTAURANTS[rng:NextInteger(1, #RESTAURANTS)], "Restaurant"
		end
		return SHOPS[rng:NextInteger(1, #SHOPS)], "Shop"
	end

	-- A) Leere Grundstuecksflaechen ------------------------------------------------------------------------
	local SKIP = { "Hospital", "FireStation", "PoliceHQ", "GasStation", "Dealership", "Garage", "Storage", "Arena", "Port", "Container", "Marina", "CityHall" }
	local lots = {}
	for _, p in ipairs(map.Districts:GetDescendants()) do
		if p:IsA("BasePart") and p.Name:match("^Lot_") and p.Size.Y <= 3 and p.Position.Y < 3 and p.Size.X * p.Size.Z >= 12000 then
			local skip = false
			for _, s in ipairs(SKIP) do
				if p.Name:find(s) then
					skip = true
				end
			end
			if not skip then
				table.insert(lots, p)
			end
		end
	end
	table.sort(lots, function(a, b)
		return a.Name < b.Name
	end)
	local CELL = 16
	local workshopDone = false

	-- groesstes freies Rechteck im Raster (Histogramm-Methode)
	local function largestRect(grid, nx, nz)
		local h = {}
		for i = 1, nx do
			h[i] = 0
		end
		local best = { area = 0 }
		for j = 1, nz do
			for i = 1, nx do
				h[i] = grid[i][j] and (h[i] + 1) or 0
			end
			for i = 1, nx do
				local minH = math.huge
				for k = i, nx do
					minH = math.min(minH, h[k])
					if minH == 0 then
						break
					end
					local area = minH * (k - i + 1)
					if area > best.area then
						best = { area = area, i0 = i, i1 = k, j0 = j - minH + 1, j1 = j }
					end
				end
			end
		end
		return best
	end

	local function shopRow(lot, top, rect, nx, nz, outward, urban)
		-- Front liegt an der Grundstueckskante (8 Studs Abstand fuer Vorplatz/Gehweg)
		local cf0 = lot.CFrame
		local sx, sz = lot.Size.X, lot.Size.Z
		local function lp(cx, cz)
			return cf0:PointToWorldSpace(Vector3.new(cx - sx / 2, 0, cz - sz / 2))
		end
		local along, depth, a0, a1, front
		if outward == "-Z" or outward == "+Z" then
			a0, a1 = (rect.i0 - 1) * CELL, rect.i1 * CELL
			depth = (rect.j1 - rect.j0 + 1) * CELL
			front = (outward == "-Z") and (rect.j0 - 1) * CELL or rect.j1 * CELL
		else
			a0, a1 = (rect.j0 - 1) * CELL, rect.j1 * CELL
			depth = (rect.i1 - rect.i0 + 1) * CELL
			front = (outward == "-X") and (rect.i0 - 1) * CELL or rect.i1 * CELL
		end
		local dirLocal = ({ ["-Z"] = Vector3.new(0, 0, -1), ["+Z"] = Vector3.new(0, 0, 1), ["-X"] = Vector3.new(-1, 0, 0), ["+X"] = Vector3.new(1, 0, 0) })[outward]
		local dirWorld = cf0:VectorToWorldSpace(dirLocal)
		local inset = 8
		local shopDepth = math.max(18, math.min(depth - inset - 2, urban and rng:NextInteger(30, 40) or 30))
		local cur = a0 + 2
		local made = 0
		while a1 - cur >= 24 do
			local w = math.min(a1 - cur - 2, rng:NextInteger(26, 40))
			if a1 - cur - w < 24 and a1 - cur - w > 0 then
				w = a1 - cur - 2 -- Rest nicht verschwenden
			end
			local mid = cur + w / 2
			local fpos
			if outward == "-Z" or outward == "+Z" then
				fpos = lp(mid, front - dirLocal.Z * inset)
			else
				fpos = lp(front - dirLocal.X * inset, mid)
			end
			fpos = Vector3.new(fpos.X, top, fpos.Z)
			local cf = CFrame.lookAt(fpos, fpos + dirWorld)
			local name, cat = nextShop()
			local h = ({ 16, 20, 26, 32 })[rng:NextInteger(1, urban and 4 or 2)]
			local m = Kit.storefront(F.Infill, cf, w - 2, h, shopDepth, name, FACADES[rng:NextInteger(1, #FACADES)], SIGNCOLS[rng:NextInteger(1, #SIGNCOLS)])
			-- Dachkante, Markise
			Kit.part(m, "Cornice", Vector3.new(w - 1.2, 1.2, shopDepth + 0.8), cf * CFrame.new(0, h + 0.6, shopDepth / 2), Color3.fromRGB(250, 248, 244), M.Concrete)
			Kit.part(m, "Awning", Vector3.new(w * 0.8, 0.4, 5), cf * CFrame.new(0, 11.2, -2.4) * CFrame.Angles(math.rad(-14), 0, 0), SIGNCOLS[rng:NextInteger(1, #SIGNCOLS)], M.Fabric, { decor = true })
			if cat == "Bank" or cat == "Jeweler" then
				Kit.tagMarker(m, "MapPOI", cf * CFrame.new(0, 1, -3), "MapPOI", { Category = cat, Name = name })
			end
			-- Cafe/Restaurant: Aussensitzplaetze auf dem Vorplatz
			if cat == "Restaurant" and w >= 30 and isFree(cf * CFrame.new(0, 3, -4), Vector3.new(w - 6, 5, 5)) then
				Kit.outdoorSeating(m, cf * CFrame.new(0, 0, -4.2), math.max(1, math.floor((w - 6) / 10)), SIGNCOLS[rng:NextInteger(1, #SIGNCOLS)])
			end
			-- Muellcontainer hinter dem Laden (Brandstelle)
			local back = cf * CFrame.new(w * 0.3, 0, shopDepth + 5)
			if isFree(back * CFrame.new(0, 3, 0), Vector3.new(8, 5, 5)) then
				place("Dumpster", back, m)
				marker("FireSpot_Dumpster", back * CFrame.new(0, 1, 0), "FireSpot_Dumpster")
			end
			if made % 2 == 0 then
				marker("FireSpot_Building", cf * CFrame.new(0, 1, 2), "FireSpot_Building")
			end
			stats.shops += 1
			made += 1
			cur += w + 2
		end
		return made, inset + shopDepth + 12
	end

	local function workshop(cf, w, d)
		local m = Kit.model(F.Infill, "AutoRepair")
		local body = Color3.fromRGB(214, 218, 224)
		Kit.part(m, "Body", Vector3.new(w, 22, d), cf * CFrame.new(0, 11, d / 2), body, M.Metal)
		for i, x in ipairs({ -w * 0.25, w * 0.25 }) do
			Kit.part(m, "BayDoor" .. i, Vector3.new(w * 0.36, 15, 0.5), cf * CFrame.new(x, 7.5, -0.1), Color3.fromRGB(120, 126, 136), M.DiamondPlate, { decor = true })
		end
		Kit.sign(m, cf * CFrame.new(0, 19, -0.5), Vector3.new(w * 0.7, 4, 0.5), "MIAMI AUTO REPAIR", Color3.fromRGB(255, 196, 40), Color3.fromRGB(26, 30, 40))
		Kit.part(m, "Forecourt", Vector3.new(w, 0.3, 14), cf * CFrame.new(0, 0.15, -7), Color3.fromRGB(70, 74, 80), M.Asphalt)
		Kit.tagMarker(m, "MapPOI", cf * CFrame.new(0, 1, -6), "MapPOI", { Category = "Workshop", Name = "Miami Auto Repair" })
		marker("FireSpot_Vehicle", cf * CFrame.new(w * 0.25, 1, -8), "FireSpot_Vehicle")
		return m
	end

	local function pocketPlaza(center, W, D, urban)
		local m = Kit.model(F.Plazas, "PocketPlaza")
		local big = W >= 64 and D >= 64
		if big then
			-- kleiner Park: Rasen, Wegkreuz, Baeume, Baenke, Blumen, Laternen
			Kit.part(m, "Lawn", Vector3.new(W - 4, 0.3, D - 4), CFrame.new(center + Vector3.new(0, 0.15, 0)), Color3.fromRGB(96, 150, 70), M.Grass)
			Kit.part(m, "PathA", Vector3.new(W - 4, 0.35, 7), CFrame.new(center + Vector3.new(0, 0.2, 0)), Color3.fromRGB(214, 204, 184), M.Pavement)
			Kit.part(m, "PathB", Vector3.new(7, 0.35, D - 4), CFrame.new(center + Vector3.new(0, 0.2, 0)), Color3.fromRGB(214, 204, 184), M.Pavement)
			for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
				local p = center + Vector3.new(q[1] * W * 0.27, 0.3, q[2] * D * 0.27)
				tree(p, m)
				bench(CFrame.lookAt(center + Vector3.new(q[1] * 10, 0.3, q[2] * 6), center + Vector3.new(q[1] * 10, 0.3, 0)), m)
			end
			flowerBed(CFrame.new(center + Vector3.new(W * 0.3, 0.3, 0)), m)
			flowerBed(CFrame.new(center + Vector3.new(-W * 0.3, 0.3, 0)), m)
			lamp(center + Vector3.new(6, 0.3, 6), m)
			lamp(center + Vector3.new(-6, 0.3, -6), m)
			Kit.trashBin(m, center + Vector3.new(5, 0.3, -5))
			marker("FireSpot_Brush", CFrame.new(center + Vector3.new(W * 0.25, 1, D * 0.25)), "FireSpot_Brush")
			stats.parks += 1
		else
			-- Platz: Pflaster, Baum im Hochbeet, Sitzbaenke, Blumenbeet
			Kit.part(m, "Paving", Vector3.new(W - 4, 0.3, D - 4), CFrame.new(center + Vector3.new(0, 0.15, 0)), urban and Color3.fromRGB(226, 218, 204) or Color3.fromRGB(206, 198, 184), M.Pavement)
			Kit.part(m, "Planter", Vector3.new(9, 1.6, 9), CFrame.new(center + Vector3.new(0, 0.8, 0)), Color3.fromRGB(200, 194, 182), M.Concrete)
			Kit.part(m, "PlanterSoil", Vector3.new(8, 0.3, 8), CFrame.new(center + Vector3.new(0, 1.6, 0)), Color3.fromRGB(80, 58, 40), M.Ground, { decor = true })
			tree(center + Vector3.new(0, 1.6, 0), m)
			for _, q in ipairs({ { 0, -1 }, { 0, 1 } }) do
				bench(CFrame.lookAt(center + Vector3.new(0, 0.3, q[2] * 9.5), center + Vector3.new(0, 0.3, q[2] * 30)), m)
			end
			if W >= 40 then
				flowerBed(CFrame.new(center + Vector3.new(W * 0.3, 0.3, 0)), m)
			end
			if rng:NextNumber() < 0.5 then
				lamp(center + Vector3.new(-W * 0.3, 0.3, D * 0.25), m)
			end
			stats.plazas += 1
		end
	end

	for li, lot in ipairs(lots) do
		ignore = lot
		local top = lot.Position.Y + lot.Size.Y / 2
		ignoreTop = top
		local nx, nz = math.floor(lot.Size.X / CELL), math.floor(lot.Size.Z / CELL)
		local grid = {}
		for i = 1, nx do
			grid[i] = {}
			for j = 1, nz do
				local lc = Vector3.new((i - 0.5) * CELL - lot.Size.X / 2, 0, (j - 0.5) * CELL - lot.Size.Z / 2)
				local cf = lot.CFrame * CFrame.new(lc.X, lot.Size.Y / 2 + 6, lc.Z)
				grid[i][j] = isFree(cf, Vector3.new(CELL - 0.5, 12.2, CELL - 0.5))
			end
		end
		local c = lot.Position
		local urban = inUrban(c.X, c.Z)
		local suburbanSawgrass = c.X < -700
		for _ = 1, 24 do
			local r = largestRect(grid, nx, nz)
			if r.area < 4 then
				break
			end
			local W, D = (r.i1 - r.i0 + 1) * CELL, (r.j1 - r.j0 + 1) * CELL
			local center = lot.CFrame:PointToWorldSpace(Vector3.new(((r.i0 - 1) * CELL + W / 2) - lot.Size.X / 2, lot.Size.Y / 2, ((r.j0 - 1) * CELL + D / 2) - lot.Size.Z / 2))
			-- Kante zur Strasse?
			local edge
			if r.j0 == 1 and W >= 48 and D >= 32 then
				edge = "-Z"
			elseif r.j1 == nz and W >= 48 and D >= 32 then
				edge = "+Z"
			elseif r.i0 == 1 and D >= 48 and W >= 32 then
				edge = "-X"
			elseif r.i1 == nx and D >= 48 and W >= 32 then
				edge = "+X"
			end
			if not workshopDone and suburbanSawgrass and W >= 64 and D >= 56 and edge then
				local dir = lot.CFrame:VectorToWorldSpace(({ ["-Z"] = Vector3.new(0, 0, -1), ["+Z"] = Vector3.new(0, 0, 1), ["-X"] = Vector3.new(-1, 0, 0), ["+X"] = Vector3.new(1, 0, 0) })[edge])
				local frontPos = center + dir * ((edge:find("Z") and D or W) / 2 - 16)
				workshop(CFrame.lookAt(Vector3.new(frontPos.X, top, frontPos.Z), Vector3.new(frontPos.X, top, frontPos.Z) + dir), 56, 40)
				workshopDone = true
			elseif urban and edge then
				-- nur den bebauten Randstreifen belegen, der Rest bleibt fuer weitere Bebauung frei
				local _, used = shopRow(lot, top, r, nx, nz, edge, true)
				local k = math.ceil(used / CELL)
				if edge == "-Z" then
					r.j1 = math.min(r.j1, r.j0 + k - 1)
				elseif edge == "+Z" then
					r.j0 = math.max(r.j0, r.j1 - k + 1)
				elseif edge == "-X" then
					r.i1 = math.min(r.i1, r.i0 + k - 1)
				else
					r.i0 = math.max(r.i0, r.i1 - k + 1)
				end
			elseif urban and W >= 48 and D >= 48 and rng:NextNumber() < 0.7 then
				-- Innenbereich: kleines Buero-/Wohnhaus statt leerer Flaeche (Downtown dichter)
				local bw, bd = math.min(W - 12, 80), math.min(D - 12, 80)
				local floors = rng:NextInteger(3, 7)
				Kit.midrise(F.Infill, "Infill_MixedUse", Vector3.new(center.X, top, center.Z), bw, bd, floors, {
					color = FACADES[rng:NextInteger(1, #FACADES)], glass = Color3.fromRGB(48, 70, 86), floorH = 13,
				})
				marker("FireSpot_Building", CFrame.new(center.X, top + 1, center.Z + bd / 2 + 4), "FireSpot_Building")
				stats.shops += 1
			elseif W >= 32 and D >= 32 then
				pocketPlaza(Vector3.new(center.X, top, center.Z), math.min(W, 96), math.min(D, 96), urban)
			elseif rng:NextNumber() < 0.6 then
				local m = Kit.model(F.Plazas, "Planter")
				Kit.part(m, "Planter", Vector3.new(7, 1.4, 7), CFrame.new(center + Vector3.new(0, 0.7, 0)), Color3.fromRGB(200, 194, 182), M.Concrete)
				if rng:NextNumber() < 0.5 then
					tree(Vector3.new(center.X, top + 1.4, center.Z), m, "Tree_Cypress")
				else
					bush(Vector3.new(center.X, top + 1.4, center.Z), m)
				end
			end
			for i = r.i0, r.i1 do
				for j = r.j0, r.j1 do
					grid[i][j] = false
				end
			end
		end
		if li % 3 == 0 then
			task.wait()
		end
	end

	ignore = nil

	-- B) Gruenflaechen (Terrain-Gras) ----------------------------------------------------------------------
	local B = { X0 = -4300, X1 = 2900, Z0 = -2900, Z1 = 2700 }
	local GS = 40
	local cells, keys = {}, {}
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { root }
	local ix = 0
	for x = B.X0, B.X1, GS do
		ix += 1
		local iz = 0
		for z = B.Z0, B.Z1, GS do
			iz += 1
			local hit = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -160, 0), rp)
			if hit and hit.Instance == workspace.Terrain and (hit.Material == M.Grass or hit.Material == M.LeafyGrass) and hit.Position.Y > -3 and hit.Position.Y < 4 then
				if isFree(CFrame.new(hit.Position + Vector3.new(0, 7, 0)), Vector3.new(GS - 4, 13, GS - 4)) then
					local k = ix .. ":" .. iz
					cells[k] = { ix = ix, iz = iz, pos = hit.Position }
					table.insert(keys, k)
				end
			end
		end
		if ix % 12 == 0 then
			task.wait()
		end
	end
	-- zusammenhaengende Flaechen
	local seen, comps = {}, {}
	table.sort(keys)
	for _, k in ipairs(keys) do
		if not seen[k] then
			local comp, stack = {}, { k }
			seen[k] = true
			while #stack > 0 do
				local cur = table.remove(stack)
				local c = cells[cur]
				table.insert(comp, c)
				for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
					local nk = (c.ix + d[1]) .. ":" .. (c.iz + d[2])
					if cells[nk] and not seen[nk] then
						seen[nk] = true
						table.insert(stack, nk)
					end
				end
			end
			table.insert(comps, comp)
		end
	end
	-- grosse zusammenhaengende Flaechen in Kacheln (6x6 Zellen = 240 Studs) teilen: jede Kachel eigenstaendig gestalten
	local split = {}
	for _, comp in ipairs(comps) do
		if #comp > 48 then
			local tiles, order = {}, {}
			for _, c in ipairs(comp) do
				local tk = math.floor(c.ix / 6) .. ":" .. math.floor(c.iz / 6)
				if not tiles[tk] then
					tiles[tk] = {}
					table.insert(order, tk)
				end
				table.insert(tiles[tk], c)
			end
			table.sort(order)
			for _, tk in ipairs(order) do
				table.insert(split, tiles[tk])
			end
		else
			table.insert(split, comp)
		end
	end
	comps = split
	local MAX_TREES, MAX_BENCH = 1300, 300
	for ci, comp in ipairs(comps) do
		local n = #comp
		local c0 = comp[1].pos
		local corridor = c0.X > -720 and c0.X < -300 -- Autobahn-Korridor: Strassenbegleitgruen
		local roll = rng:NextNumber()
		local m = Kit.model(F.Parks, "Green_" .. ci)
		if corridor then
			-- Baumreihen und Strauchgruppen, keine Sitzplaetze
			for i, c in ipairs(comp) do
				if i % 2 == 0 and stats.trees < MAX_TREES then
					tree(c.pos + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)), m, (rng:NextNumber() < 0.5) and "Palm" or "Tree_Round")
				elseif rng:NextNumber() < 0.3 then
					bush(c.pos + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10)), m)
				end
			end
			stats.greens += 1
		elseif n >= 12 and roll < 0.7 then
			-- Park: Hauptweg durch die Flaeche, Baenke am Weg, Baumgruppen, Blumen, Laternen
			stats.parks += 1
			local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
			for _, c in ipairs(comp) do
				minX, maxX = math.min(minX, c.pos.X), math.max(maxX, c.pos.X)
				minZ, maxZ = math.min(minZ, c.pos.Z), math.max(maxZ, c.pos.Z)
			end
			local alongX = (maxX - minX) >= (maxZ - minZ)
			local midLine = alongX and (minZ + maxZ) / 2 or (minX + maxX) / 2
			for i, c in ipairs(comp) do
				local onPath = alongX and math.abs(c.pos.Z - midLine) < GS / 2 or (not alongX and math.abs(c.pos.X - midLine) < GS / 2)
				if onPath then
					local cf = alongX and CFrame.new(c.pos.X, c.pos.Y + 0.15, midLine) or CFrame.new(midLine, c.pos.Y + 0.15, c.pos.Z)
					local pathSize = alongX and Vector3.new(GS + 0.5, 0.3, 8) or Vector3.new(8, 0.3, GS + 0.5)
					Kit.part(m, "Path", pathSize, cf, Color3.fromRGB(214, 204, 184), M.Pavement, { noShadow = true })
					if i % 3 == 0 and stats.benches < MAX_BENCH then
						local side = (i % 2 == 0) and 1 or -1
						local bpos = alongX and Vector3.new(c.pos.X, c.pos.Y + 0.3, midLine + side * 7.5) or Vector3.new(midLine + side * 7.5, c.pos.Y + 0.3, c.pos.Z)
						local look = alongX and Vector3.new(bpos.X, bpos.Y, midLine) or Vector3.new(midLine, bpos.Y, bpos.Z)
						bench(CFrame.lookAt(bpos, look) * CFrame.Angles(0, math.pi, 0), m)
						if i % 6 == 0 then
							flowerBed(CFrame.new(bpos + (alongX and Vector3.new(9, 0, 0) or Vector3.new(0, 0, 9))), m)
						end
					end
					if i % 5 == 0 then
						lamp(alongX and Vector3.new(c.pos.X, c.pos.Y, midLine + 5.5) or Vector3.new(midLine + 5.5, c.pos.Y, c.pos.Z), m)
					end
				elseif stats.trees < MAX_TREES and rng:NextNumber() < 0.55 then
					tree(c.pos + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10)), m)
					if rng:NextNumber() < 0.35 then
						bush(c.pos + Vector3.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-14, 14)), m)
					end
				end
			end
			marker("FireSpot_Brush", CFrame.new(comp[math.max(1, math.floor(n / 3))].pos + Vector3.new(0, 1, 0)), "FireSpot_Brush")
		elseif n >= 3 and roll < 0.75 then
			-- begruente Flaeche: lockere Baumgruppen, Straeucher, gelegentlich eine Bank
			stats.greens += 1
			for _, c in ipairs(comp) do
				local r2 = rng:NextNumber()
				if r2 < 0.35 and stats.trees < MAX_TREES then
					tree(c.pos + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8)), m)
				elseif r2 < 0.55 then
					bush(c.pos + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10)), m)
				elseif r2 < 0.6 then
					flowerBed(CFrame.new(c.pos + Vector3.new(rng:NextNumber(-8, 8), 0.2, rng:NextNumber(-8, 8))) * CFrame.Angles(0, rng:NextNumber(0, 3.14), 0), m)
				elseif r2 < 0.65 and stats.benches < MAX_BENCH then
					bench(CFrame.new(c.pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), m)
				end
			end
		end
		-- (kleinste Flaechen bleiben einfache Rasenflaechen)
		if ci % 20 == 0 then
			task.wait()
		end
	end

	-- C) Parkplaetze: Pflanzinseln an den Reihenenden + Stellplatz-Marker -----------------------------
	for _, lotModel in ipairs(map:GetDescendants()) do
		if lotModel:IsA("Model") and lotModel:GetAttribute("Parking") then
			local a = lotModel:FindFirstChild("Asphalt")
			if a and a.Size.X * a.Size.Z >= 9000 then
				local top = a.Position.Y + a.Size.Y / 2
				local spots, islands = 0, 0
				-- Stellplaetze 12 x 22 rasterweise pruefen
				for zx = -a.Size.Z / 2 + 15, a.Size.Z / 2 - 15, 50 do
					for xx = -a.Size.X / 2 + 12, a.Size.X / 2 - 12, 24 do
						if spots >= 8 then
							break
						end
						local cf = a.CFrame * CFrame.new(xx, a.Size.Y / 2, zx)
						local pos = Vector3.new(cf.Position.X, top, cf.Position.Z)
						if isFree(CFrame.new(pos + Vector3.new(0, 4, 0)), Vector3.new(10, 7, 20)) then
							marker("ParkSpot", CFrame.lookAt(pos + Vector3.new(0, 1, 0), pos + Vector3.new(0, 1, 0) + a.CFrame.LookVector), "VehicleParkSpot")
							spots += 1
							stats.parkSpots += 1
						end
					end
				end
				-- sehr grosse Parkplaetze: bepflanzte Mittelstreifen alle ~110 Studs gliedern die Flaeche
				if a.Size.X * a.Size.Z >= 60000 then
					local longX = a.Size.X >= a.Size.Z
					local span = longX and a.Size.Z or a.Size.X
					local len = (longX and a.Size.X or a.Size.Z) - 50
					for off = -span / 2 + 110, span / 2 - 60, 110 do
						local cf = a.CFrame * CFrame.new(longX and 0 or off, a.Size.Y / 2, longX and off or 0)
						local pos = Vector3.new(cf.Position.X, top, cf.Position.Z)
						local size = longX and Vector3.new(len, 6, 7) or Vector3.new(7, 6, len)
						if isFree(CFrame.new(pos + Vector3.new(0, 3.5, 0)), size) then
							local m = Kit.model(F.Parking, "MedianStrip")
							local rot = a.CFrame - a.CFrame.Position
							Kit.part(m, "Curb", Vector3.new(longX and len or 7, 0.8, longX and 7 or len), CFrame.new(pos + Vector3.new(0, 0.4, 0)) * rot, Color3.fromRGB(206, 200, 188), M.Concrete)
							Kit.part(m, "Lawn", Vector3.new(longX and len - 1 or 6, 0.2, longX and 6 or len - 1), CFrame.new(pos + Vector3.new(0, 0.85, 0)) * rot, Color3.fromRGB(96, 150, 70), M.Grass, { decor = true })
							for t = -len / 2 + 15, len / 2 - 15, 34 do
								local tp = cf * CFrame.new(longX and t or 0, 0, longX and 0 or t)
								tree(Vector3.new(tp.Position.X, top + 0.8, tp.Position.Z), m, (rng:NextNumber() < 0.6) and "Palm" or "Tree_Round")
							end
							stats.islands += 1
						end
					end
				end
				-- Inseln an beiden Enden (kompaktere, gegliederte Flaeche)
				for _, sx in ipairs({ -1, 1 }) do
					for zx = -a.Size.Z / 2 + 30, a.Size.Z / 2 - 30, 60 do
						if islands < 6 then
							local cf = a.CFrame * CFrame.new(sx * (a.Size.X / 2 - 5), a.Size.Y / 2, zx)
							local pos = Vector3.new(cf.Position.X, top, cf.Position.Z)
							if isFree(CFrame.new(pos + Vector3.new(0, 4, 0)), Vector3.new(9, 7, 16)) then
								local m = Kit.model(F.Parking, "Island")
								Kit.part(m, "Curb", Vector3.new(8, 0.8, 14), CFrame.new(pos + Vector3.new(0, 0.4, 0)), Color3.fromRGB(206, 200, 188), M.Concrete)
								Kit.part(m, "Soil", Vector3.new(7, 0.2, 13), CFrame.new(pos + Vector3.new(0, 0.85, 0)), Color3.fromRGB(96, 150, 70), M.Grass, { decor = true })
								tree(pos + Vector3.new(0, 0.8, 0), m, (rng:NextNumber() < 0.5) and "Palm" or "Tree_Round")
								islands += 1
								stats.islands += 1
							end
						end
					end
				end
			end
		end
	end
	task.wait()

	-- D) Strassen: Bushaltestellen, Strassenschilder, Baenke ---------------------------------------------
	local function words(s)
		return (s:gsub("(%l)(%u)", "%1 %2"):gsub("(%a)(%d)", "%1 %2")):upper()
	end
	local segs = map.Roads.Mainland.Segments:GetChildren()
	table.sort(segs, function(a, b)
		return a.Name < b.Name
	end)
	for si, seg in ipairs(segs) do
		local sw = {}
		for _, p in ipairs(seg:GetChildren()) do
			if p:IsA("BasePart") and p.Name == "Sidewalk" then
				table.insert(sw, p)
			end
		end
		local asphalt = seg:FindFirstChild("Asphalt")
		if asphalt and #sw > 0 then
			local c = asphalt.Position
			local urban = inUrban(c.X, c.Z)
			for k, s in ipairs(sw) do
				local long = math.max(s.Size.X, s.Size.Z)
				local alongZ = s.Size.Z >= s.Size.X
				local axis = alongZ and s.CFrame.LookVector or s.CFrame.RightVector
				-- Seite des Gehwegs (weg von der Fahrbahn)
				local away = (s.Position - c)
				away = Vector3.new(away.X, 0, away.Z)
				if away.Magnitude < 1 then
					away = Vector3.new(1, 0, 0)
				end
				away = away.Unit
				local sTop = s.Position.Y + s.Size.Y / 2
				-- Bushaltestelle (jede 3. Strasse in der Stadt, eine Seite)
				if urban and k == 1 and si % 3 == 0 and long > 120 then
					local p = s.Position + axis * (long * 0.15) + away * 2
					local pos = Vector3.new(p.X, sTop, p.Z)
					local cf = CFrame.lookAt(pos, pos - away)
					if isFree(cf * CFrame.new(0, 5, 0), Vector3.new(18, 9, 7)) then
						place("BusShelter", cf, F.Street)
						Kit.sign(F.Street, cf * CFrame.new(-8.5, 11, -1.95) * CFrame.Angles(0, 0, 0), Vector3.new(2.2, 0.9, 0.05), "BUS", Color3.new(1, 1, 1), Color3.fromRGB(30, 110, 200))
						stats.busStops += 1
					end
				end
				-- Sitzbank + Muelleimer am Gehweg (Stadtgebiet)
				if urban and long > 100 then
					for _, f in ipairs({ -0.3, 0.32 }) do
						local p = s.Position + axis * (long * f) + away * 4.5
						local pos = Vector3.new(p.X, sTop, p.Z)
						local cf = CFrame.lookAt(pos, pos - away) * CFrame.Angles(0, math.pi, 0)
						if isFree(CFrame.new(pos + Vector3.new(0, 2.5, 0)), Vector3.new(8, 4, 4)) and stats.benches < MAX_BENCH + 120 then
							bench(cf, F.Street)
							local tb = pos + axis * 5
							if isFree(CFrame.new(tb + Vector3.new(0, 2, 0)), Vector3.new(3, 3, 3)) then
								Kit.trashBin(F.Street, tb)
							end
						end
					end
				end
			end
		end
		if si % 25 == 0 then
			task.wait()
		end
	end
	-- Strassennamen an Kreuzungen (Stadtgebiet): Mast + zwei Namensschilder (US-Stil gruen)
	for _, j in ipairs(map.Roads.Mainland.Intersections:GetChildren()) do
		local a = j:FindFirstChild("Asphalt")
		local s1, s2 = j.Name:match("^X_([%w]+)_([%w]+)$")
		if a and s1 and inUrban(a.Position.X, a.Position.Z) then
			local corner = a.CFrame * CFrame.new(a.Size.X / 2 + 4, 0, -(a.Size.Z / 2 + 4))
			local pos = Vector3.new(corner.Position.X, a.Position.Y + a.Size.Y / 2 + 0.6, corner.Position.Z)
			if isFree(CFrame.new(pos + Vector3.new(0, 6, 0)), Vector3.new(2, 10, 2)) then
				local m = Kit.model(F.Street, "StreetSign")
				Kit.part(m, "Pole", Vector3.new(0.5, 13, 0.5), CFrame.new(pos + Vector3.new(0, 6.5, 0)), Color3.fromRGB(60, 64, 70), M.Metal)
				local green = Color3.fromRGB(16, 110, 60)
				local rot = a.CFrame - a.CFrame.Position
				Kit.sign(m, CFrame.new(pos + Vector3.new(0, 12.4, 0)) * rot * CFrame.new(0, 0, 0.05), Vector3.new(9, 1.4, 0.1), words(s1), Color3.new(1, 1, 1), green)
				Kit.sign(m, CFrame.new(pos + Vector3.new(0, 11, 0)) * rot * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0, 0.05), Vector3.new(9, 1.4, 0.1), words(s2), Color3.new(1, 1, 1), green)
				stats.signs += 1
			end
		end
	end
	task.wait()

	-- E) Weitere Brandstellen: geparkte Fahrzeuge, Gebaeude, Unfallorte -----------------------------------
	for i, car in ipairs(map.ParkedVehicles:GetChildren()) do
		if i % 2 == 1 then
			marker("FireSpot_Vehicle", CFrame.new(car:GetPivot().Position + Vector3.new(0, 1, 0)), "FireSpot_Vehicle")
		end
	end
	local bcount = 0
	for _, d in ipairs(map.Districts:GetChildren()) do
		local b = d:FindFirstChild("Buildings")
		for _, m in ipairs(b and b:GetChildren() or {}) do
			if m:IsA("Model") and bcount < 40 and rng:NextNumber() < 0.08 then
				local cf, size = m:GetBoundingBox()
				if size.Y > 12 then
					local pos = (cf * CFrame.new(0, 0, -size.Z / 2 - 4)).Position
					marker("FireSpot_Building", CFrame.new(pos.X, 1.6, pos.Z), "FireSpot_Building")
					bcount += 1
				end
			end
		end
	end
	for i, seg in ipairs(segs) do
		local a = seg:FindFirstChild("Asphalt")
		if a and i % 9 == 0 and a.Position.Y < 3 then
			local cf = a.CFrame * CFrame.new(a.Size.X / 2 - 9, a.Size.Y / 2 + 0.5, 0)
			marker("FireSpot_Rescue", cf, "FireSpot_Rescue")
		end
	end

	-- F) Pruefung: Testobjekte (nur melden, nichts loeschen)
	local tests = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if (d:IsA("BasePart") or d:IsA("Model")) and (d.Name:match("^[Tt]est") or d.Name:match("_[Tt]est") or d.Name:match("^[Tt]emp") or d.Name:find("[Dd]ebug")) and d.Name ~= "Suspect_TestNPC" then
			table.insert(tests, d:GetFullName())
		end
	end

	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			stats.parts += 1
		end
	end
	return string.format(
		"Laeden %d, Plaetze %d, Parks %d, begruente Flaechen %d, Baeume %d, Baenke %d, Blumenbeete %d, Strauecher %d, Bushaltestellen %d, Strassenschilder %d, Parkinseln %d, Stellplaetze %d, Brandstellen %d, Parts %d | Werkstatt %s | Testobjekte: %s",
		stats.shops, stats.plazas, stats.parks, stats.greens, stats.trees, stats.benches, stats.flowers, stats.bushes, stats.busStops, stats.signs, stats.islands, stats.parkSpots, stats.fireSpots, stats.parts,
		tostring(workshopDone), #tests > 0 and table.concat(tests, ", ", 1, math.min(#tests, 5)) or "keine")
end
