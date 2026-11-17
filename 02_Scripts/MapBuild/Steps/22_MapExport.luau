-- Schritt 22: Kartendaten aus der gebauten Welt erzeugen (gemeinsame Quelle fuer Stadtkarte, Minimap und Navigation).
-- Erzeugt ReplicatedStorage.MiamiShared.Config.MapGeo (ModuleScript, generierter Inhalt):
--   Roads     = { {cx, cz, w, l, rotDeg, kind} }   Fahrbahnflaechen (Asphalt) als gedrehte Rechtecke
--   Buildings = { {cx, cz, w, d, rotDeg, h} }      Gebaeudegrundrisse
--   Lots      = { {cx, cz, w, d, rotDeg} }         Parkplaetze
--   Green     = { {cx, cz, w, d, rotDeg} }         Gruenflaechen
--   POI       = { {cat, name, x, z} }              Kartenmarker
--   Nodes     = { {x, z} }, Edges = { {a, b} }      Strassengraph fuer die Routenberechnung
-- Nach Aenderungen an Strassen/Gebaeuden erneut ausfuehren.
return function(Kit)
	local CS = game:GetService("CollectionService")
	local RS = game:GetService("ReplicatedStorage")
	local map = workspace.Map

	local function r(n)
		return math.floor(n + 0.5)
	end
	local function rotOf(cf)
		local _, y = cf:ToOrientation()
		return r(math.deg(y))
	end

	-- Strassen -----------------------------------------------------------------------------------------
	local roads, rects = {}, {}
	for _, p in ipairs(map.Roads:GetDescendants()) do
		if p:IsA("BasePart") and p.Name == "Asphalt" and p.Size.X >= 8 and p.Size.Z >= 8 then
			local kind = (p.Position.Y > 9) and "Highway" or "Street"
			if p:FindFirstAncestor("Intersections") then
				kind = "Junction"
			elseif p:FindFirstAncestor("Bridges") then
				kind = "Bridge"
			end
			table.insert(roads, { r(p.Position.X), r(p.Position.Z), r(p.Size.X), r(p.Size.Z), rotOf(p.CFrame), kind })
			table.insert(rects, { part = p, kind = kind })
		end
	end
	-- Rampen der Autobahn (geneigte Fahrbahnstuecke)
	for _, p in ipairs(map.Roads.Highways:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "Asphalt" and p:FindFirstAncestor("Ramps") and p.Size.X >= 20 and p.Size.Y <= 3 then
			table.insert(roads, { r(p.Position.X), r(p.Position.Z), r(p.Size.X), r(p.Size.Z), rotOf(p.CFrame), "Ramp" })
			table.insert(rects, { part = p, kind = "Ramp" })
		end
	end

	-- Strassengraph: Mittellinie jedes Fahrbahnstuecks entlang der laengeren Seite; Kreuzungen als Knoten
	local nodes, edges = {}, {}
	local junctions = {}
	local function addNode(x, z, snap)
		for i, n in ipairs(nodes) do
			if (n[1] - x) ^ 2 + (n[2] - z) ^ 2 <= snap * snap then
				return i
			end
		end
		table.insert(nodes, { r(x), r(z) })
		return #nodes
	end
	for _, rc in ipairs(rects) do
		if rc.kind == "Junction" then
			local p = rc.part
			local idx = addNode(p.Position.X, p.Position.Z, 4)
			table.insert(junctions, { idx = idx, cf = p.CFrame, size = p.Size })
		end
	end
	local function insideJunction(pos)
		for _, j in ipairs(junctions) do
			local lp = j.cf:PointToObjectSpace(pos)
			if math.abs(lp.X) <= j.size.X / 2 + 8 and math.abs(lp.Z) <= j.size.Z / 2 + 8 then
				return j.idx
			end
		end
		return nil
	end
	local function addEdge(a, b)
		if a == b then
			return
		end
		for _, e in ipairs(edges) do
			if (e[1] == a and e[2] == b) or (e[1] == b and e[2] == a) then
				return
			end
		end
		table.insert(edges, { a, b })
	end
	for _, rc in ipairs(rects) do
		if rc.kind ~= "Junction" then
			local p = rc.part
			local along = (p.Size.Z >= p.Size.X) and Vector3.zAxis or Vector3.xAxis
			local half = math.max(p.Size.X, p.Size.Z) / 2
			local a = p.CFrame:PointToWorldSpace(along * half)
			local b = p.CFrame:PointToWorldSpace(-along * half)
			local ia = insideJunction(a) or addNode(a.X, a.Z, 18)
			local ib = insideJunction(b) or addNode(b.X, b.Z, 18)
			-- lange Stuecke unterteilen, damit Abzweige (Rampen) einhaken koennen
			local len = (a - b).Magnitude
			local steps = math.max(1, math.floor(len / 160))
			local prev = ia
			for s = 1, steps - 1 do
				local q = a:Lerp(b, s / steps)
				local mid = addNode(q.X, q.Z, 18)
				addEdge(prev, mid)
				prev = mid
			end
			addEdge(prev, ib)
		end
	end

	-- Gebaeude, Parkplaetze, Gruen ---------------------------------------------------------------------
	local buildings, lots, green = {}, {}, {}
	local function box(m)
		local cf, size
		if m:IsA("Model") then
			cf, size = m:GetBoundingBox()
		else
			cf, size = m.CFrame, m.Size
		end
		return cf, size
	end
	local function collectBuildings(folder)
		for _, m in ipairs(folder:GetChildren()) do
			if m:IsA("Folder") then
				collectBuildings(m)
			elseif m:IsA("Model") or m:IsA("BasePart") then
				local cf, size = box(m)
				if size.X >= 6 and size.Z >= 6 then
					local entry = { r(cf.Position.X), r(cf.Position.Z), r(size.X), r(size.Z), rotOf(cf) }
					if m.Name:find("Parking") or m.Name:find("Lot") or m.Name:find("Apron") or m.Name:find("Bay") then
						table.insert(lots, entry)
					elseif m.Name:find("Park") and not m.Name:find("Garage") then
						table.insert(green, entry)
					elseif size.Y >= 6 then
						table.insert(entry, r(size.Y))
						table.insert(buildings, entry)
					end
				end
			end
		end
	end
	for _, d in ipairs(map.Districts:GetChildren()) do
		local b = d:FindFirstChild("Buildings")
		if b then
			collectBuildings(b)
		end
	end
	for _, n in ipairs({ "PoliceStation", "FireStation", "Hospital" }) do
		local f = map:FindFirstChild(n)
		local b = f and f:FindFirstChild("Building")
		if b then
			local cf, size = b:GetBoundingBox()
			table.insert(buildings, { r(cf.Position.X), r(cf.Position.Z), r(size.X), r(size.Z), rotOf(cf), r(size.Y) })
		end
	end
	-- Stadtueberarbeitung (Schritt 24): neue Laeden als Gebaeude, Plaetze/Parks als Gruen
	local refine = map:FindFirstChild("Refinement")
	if refine then
		if refine:FindFirstChild("Infill") then
			collectBuildings(refine.Infill)
		end
		for _, p in ipairs(refine:GetDescendants()) do
			if p:IsA("BasePart") and (p.Name == "Lawn" or p.Name == "Paving") then
				table.insert(green, { r(p.Position.X), r(p.Position.Z), r(p.Size.X), r(p.Size.Z), rotOf(p.CFrame) })
			end
		end
	end
	-- Gruenflaechen: grosse Gras-Parts ausserhalb der Strassen
	for _, p in ipairs(map.Districts:GetDescendants()) do
		if p:IsA("BasePart") and (p.Material == Enum.Material.Grass or p.Material == Enum.Material.LeafyGrass) and p.Size.X * p.Size.Z >= 900 and p.Size.Y <= 4 then
			table.insert(green, { r(p.Position.X), r(p.Position.Z), r(p.Size.X), r(p.Size.Z), rotOf(p.CFrame) })
		end
	end

	-- Kartenmarker -------------------------------------------------------------------------------------
	local poi = {}
	local function add(cat, name, pos)
		for _, q in ipairs(poi) do
			if q[1] == cat and (q[3] - pos.X) ^ 2 + (q[4] - pos.Z) ^ 2 < 40 * 40 then
				return -- Duplikate in der Naehe zusammenfassen
			end
		end
		table.insert(poi, { cat, name, r(pos.X), r(pos.Z) })
	end
	local function center(inst)
		if inst:IsA("BasePart") then
			return inst.Position
		end
		return (inst:GetBoundingBox()).Position
	end
	if map:FindFirstChild("PoliceStation") then
		add("Police", "Miami State Police HQ", center(map.PoliceStation.Building))
	end
	if map:FindFirstChild("FireStation") then
		add("Fire", "Fire Station 1", center(map.FireStation.Building))
	end
	if map:FindFirstChild("Hospital") then
		add("Hospital", "Bayfront Medical Center", center(map.Hospital.Building))
	end
	for _, i in ipairs(CS:GetTagged("Interactable")) do
		local t = i:GetAttribute("InteractType")
		if t == "ATM" then
			add("Bank", "Geldautomat", center(i))
		elseif t == "JobCenter" then
			add("Jobs", "Jobcenter", center(i))
		end
	end
	local CAFE = { ["BEAN & LEAF"] = true, ["SUNNY CAFE"] = true, ["CAFE MOKA"] = true, ["DONUT TIME"] = true, ["BAKERY"] = true }
	for _, s in ipairs(CS:GetTagged("StoreEntrance")) do
		local name = s:GetAttribute("StoreName") or "Geschaeft"
		local up = tostring(name):upper()
		if CAFE[up] or up:find("CAFE") or up:find("PIZZA") or up:find("BURGER") or up:find("GRILL") or up:find("DINER") or up:find("TACO") or up:find("SUSHI") then
			add("Restaurant", name, center(s))
		elseif up:find("JEWEL") then
			add("Jeweler", name, center(s))
		else
			add("Shop", name, center(s))
		end
	end
	for _, s in ipairs(CS:GetTagged("ShopEntrance")) do
		local shop = s:GetAttribute("Shop")
		if shop == "Dealership" then
			add("Dealership", "Autohaus", center(s))
		elseif shop == "GasStationShop" then
			add("Shop", "Tankstellen-Shop", center(s))
		end
	end
	for _, g in ipairs(CS:GetTagged("GarageEntrance")) do
		add("Parking", "Parkhaus", center(g))
	end
	for _, d in ipairs(map.Districts:GetDescendants()) do
		if d:IsA("Model") then
			local n = d.Name
			if n:match("^GasStation") and not n:find("Parking") then
				add("Gas", "Tankstelle", center(d))
			elseif n:match("^Club_") or n:match("^BeachClub") or n:find("Nightclub") then
				add("Club", (n:gsub("^Club_", ""):gsub("_", " ")), center(d))
			elseif n:match("^Restaurant_") or n == "MarinaGrill" or (n:match("^Diner") and not n:find("Parking")) then
				add("Restaurant", (n:gsub("^Restaurant_", ""):gsub("_", " ")), center(d))
			elseif n == "PortAuthority" then
				add("Port", "Port Meridian", center(d))
			elseif n == "CityHall" then
				add("Jobs", "City Hall", center(d))
			elseif n:find("Casino") or n:find("Arena") then
				add("Club", (n:gsub("(%l)(%u)", "%1 %2")), center(d))
			elseif n:match("^ParkingGarage") or n:match("Center_Garage") then
				add("Parking", "Parkhaus", center(d))
			end
		end
	end
	-- frei gesetzte Marker (Tag "MapPOI", Attribute Category/Name) aus spaeteren Bauschritten
	for _, m in ipairs(CS:GetTagged("MapPOI")) do
		if m:IsA("BasePart") then
			add(m:GetAttribute("Category") or "Shop", m:GetAttribute("Name") or m.Name, m.Position)
		end
	end

	-- Modul schreiben ------------------------------------------------------------------------------------
	local function list(t)
		local parts = {}
		for _, e in ipairs(t) do
			local f = {}
			for _, v in ipairs(e) do
				table.insert(f, type(v) == "string" and string.format("%q", v) or tostring(v))
			end
			table.insert(parts, "{" .. table.concat(f, ",") .. "}")
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	local src = table.concat({
		"-- GENERIERT von MapBuild/Steps/22_MapExport.luau - nicht von Hand bearbeiten.",
		"local G = {}",
		"G.Roads = " .. list(roads),
		"G.Buildings = " .. list(buildings),
		"G.Lots = " .. list(lots),
		"G.Green = " .. list(green),
		"G.POI = " .. list(poi),
		"G.Nodes = " .. list(nodes),
		"G.Edges = " .. list(edges),
		"return G",
	}, "\n")
	local cfg = RS.MiamiShared.Config
	local mod = cfg:FindFirstChild("MapGeo") or Instance.new("ModuleScript")
	mod.Name = "MapGeo"
	mod.Source = src
	mod.Parent = cfg
	return string.format("Strassen %d, Gebaeude %d, Parkplaetze %d, Gruen %d, Marker %d, Knoten %d, Kanten %d, Quelltext %d KB",
		#roads, #buildings, #lots, #green, #poi, #nodes, #edges, math.floor(#src / 1024))
end
