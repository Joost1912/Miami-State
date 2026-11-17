-- Schritt 28 (Prompt 12, Nachtrag): Freiflaechen verkleinern und Stadtgrenze.
-- 1) Grosse, fast leere Parkplaetze in Sawgrass verdichten (InfillKit: Gebaeudezeilen an den Strassenfronten,
--    kleine Gruenanlagen; Spielmarker, Depots, Parkplatz-Marker und vorhandene Objekte werden ausgespart).
-- 2) Gruenring ausserhalb der Stadt verkleinern: Grenze abschnittsweise ca. 80 Studs hinter der letzten Bebauung,
--    dahinter Wasser statt Gras/Absturzkante; Baum-/Palmenguertel, "City Limits"-Schilder, unsichtbare Barrieren.
-- Idempotent fuer die Objekte (workspace.Map.CityEdge). Die Terrain-Aenderung (Gras -> Wasser) ist dauerhaft;
-- Sicherung = Place-Version vor dem Lauf (69).
return function(Kit)
	local CollectionService = game:GetService("CollectionService")
	local ServerStorage = game:GetService("ServerStorage")
	local Terrain = workspace.Terrain
	local rgb = Color3.fromRGB
	local M = Enum.Material
	local log = {}

	local root = workspace.Map:FindFirstChild("CityEdge")
	if root then
		root:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "CityEdge"
	root.Parent = workspace.Map
	local mapData = { Buildings = {}, Green = {} }

	----------------------------------------------------------------------------------------------------
	-- 1) PARKPLAETZE VERDICHTEN
	----------------------------------------------------------------------------------------------------
	local Infill = require(ServerStorage.MapBuildTools.InfillKit:Clone())
	local infillFolder = Instance.new("Folder")
	infillFolder.Name = "ParkingInfill"
	infillFolder.Parent = root
	local lots = {}
	for _, d in ipairs(workspace.Map.Districts.SawgrassPark.Buildings:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Asphalt" and d.Size.X >= 300 and d.Size.Z >= 300 and d.Parent.Name ~= "Dealership_DisplayLot" then
			table.insert(lots, d)
		end
	end
	local built, greens = 0, 0
	for i, lot in ipairs(lots) do
		local b, g = Infill.fill(lot, infillFolder, 1200 + i * 17, mapData)
		built += b
		greens += g
		task.wait()
	end
	table.insert(log, string.format("Parkplaetze: %d verdichtet, %d Gebaeude, %d Gruenanlagen", #lots, built, greens))

	----------------------------------------------------------------------------------------------------
	-- 2) STADTGRENZE
	----------------------------------------------------------------------------------------------------
	local mp = RaycastParams.new()
	mp.FilterType = Enum.RaycastFilterType.Include
	mp.FilterDescendantsInstances = { workspace.Map }
	local tp = RaycastParams.new()
	tp.FilterType = Enum.RaycastFilterType.Include
	tp.FilterDescendantsInstances = { Terrain }
	tp.IgnoreWater = false
	local function mapAt(x, z)
		return workspace:Raycast(Vector3.new(x, 700, z), Vector3.new(0, -900, 0), mp) ~= nil
	end
	-- aeusserste Bebauung in einem Streifen (Breite SEG) entlang einer Seite
	local SEG, MARGIN = 300, 80
	local function outermost(side, a0, a1)
		-- side: "W" (min x), "E" (max x), "N" (min z), "S" (max z); a0..a1 = Streifen auf der anderen Achse
		local best
		for a = a0, a1, 50 do
			local found
			if side == "W" then
				for x = -4700, -1500, 25 do
					if mapAt(x, a) then
						found = x
						break
					end
				end
				best = found and math.min(best or found, found) or best
			elseif side == "N" then
				for z = -3300, -1000, 25 do
					if mapAt(a, z) then
						found = z
						break
					end
				end
				best = found and math.min(best or found, found) or best
			elseif side == "S" then
				for z = 3200, 1000, -25 do
					if mapAt(a, z) then
						found = z
						break
					end
				end
				best = found and math.max(best or found, found) or best
			end
		end
		return best
	end

	local edgeFolder = Instance.new("Folder")
	edgeFolder.Name = "Border"
	edgeFolder.Parent = root
	local Decor = ServerStorage:FindFirstChild("MapAssets") and ServerStorage.MapAssets:FindFirstChild("Decor")
	local function wall(cf, len)
		local p = Instance.new("Part")
		p.Name = "BoundaryWall"
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, true, false, false, false
		p.Transparency = 1
		p.Size = Vector3.new(len, 200, 2)
		p.CFrame = cf * CFrame.new(0, 90, 0)
		p.Parent = edgeFolder
	end
	local rng = Random.new(2812)
	local trees = 0
	local function greenBelt(p0, p1, inward)
		-- Baum-/Palmenguertel auf dem verbleibenden Grasstreifen
		local dir = (p1 - p0)
		local len = dir.Magnitude
		if len < 1 then
			return
		end
		dir = dir / len
		for t = 0, len, 26 do
			local p = p0 + dir * t + inward * rng:NextNumber(14, 34)
			local h = workspace:Raycast(Vector3.new(p.X, 200, p.Z), Vector3.new(0, -260, 0), tp)
			if h and h.Material == M.Grass then
				if rng:NextNumber() < 0.45 then
					Kit.palm(edgeFolder, Vector3.new(p.X, h.Position.Y, p.Z), rng:NextInteger(26, 40), rng:NextInteger(1, 999))
				elseif Decor and Decor:FindFirstChild("Tree_Oak") then
					local m = Decor[rng:NextNumber() < 0.5 and "Tree_Oak" or "Tree_Round"]:Clone()
					m:PivotTo(CFrame.new(p.X, 60, p.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
					local cf, s = m:GetBoundingBox()
					m:PivotTo(m:GetPivot() + Vector3.new(0, h.Position.Y - (cf.Y - s.Y / 2), 0))
					m.Parent = edgeFolder
				end
				trees += 1
			end
		end
	end
	-- Terrain jenseits der Grenze: Gras -> Wasser (Hoehe wie die bestehende Bucht), oberhalb Luft
	local WATER_TOP = -9
	local function toWater(x0, x1, z0, z1)
		local CH = 512
		for x = x0, x1 - 1, CH do
			for z = z0, z1 - 1, CH do
				local w = math.min(CH, x1 - x)
				local d = math.min(CH, z1 - z)
				local cx, cz = x + w / 2, z + d / 2
				Terrain:FillBlock(CFrame.new(cx, WATER_TOP + 30, cz), Vector3.new(w, 60, d), M.Air)
				Terrain:FillBlock(CFrame.new(cx, WATER_TOP - 20, cz), Vector3.new(w, 40, d), M.Water)
				Terrain:FillBlock(CFrame.new(cx, WATER_TOP - 48, cz), Vector3.new(w, 16, d), M.Sand)
			end
			task.wait()
		end
	end

	local OUT = 1600 -- Wasserflaeche hinter der Grenze (Horizont statt Absturzkante)
	local XMIN, XMAX, ZMIN, ZMAX = -4700, 3300, -3300, 3000
	-- Westseite (Abschnitte entlang z)
	local westLine = {}
	for z = ZMIN, ZMAX - 1, SEG do
		local o = outermost("W", z, z + SEG)
		local bx = (o or -4225) - MARGIN
		table.insert(westLine, { z, z + SEG, bx })
	end
	-- Nord- und Suedseite (Abschnitte entlang x, Ostseite: Kueste/Bucht bleibt)
	local northLine, southLine = {}, {}
	for x = XMIN, XMAX - 1, SEG do
		local on = outermost("N", x, x + SEG)
		local os_ = outermost("S", x, x + SEG)
		table.insert(northLine, { x, x + SEG, (on or -2900) - MARGIN })
		table.insert(southLine, { x, x + SEG, (os_ or 2600) + MARGIN })
	end
	-- Wasser setzen und Barrieren/Guertel bauen
	for _, s in ipairs(westLine) do
		toWater(s[3] - OUT, math.floor(s[3]), s[1], s[2])
		wall(CFrame.new(s[3] - 40, 0, (s[1] + s[2]) / 2) * CFrame.Angles(0, math.rad(90), 0), SEG + 4)
		greenBelt(Vector3.new(s[3], 0, s[1]), Vector3.new(s[3], 0, s[2]), Vector3.new(1, 0, 0))
	end
	for _, s in ipairs(northLine) do
		toWater(s[1], s[2], s[3] - OUT, math.floor(s[3]))
		wall(CFrame.new((s[1] + s[2]) / 2, 0, s[3] - 40), SEG + 4)
		greenBelt(Vector3.new(s[1], 0, s[3]), Vector3.new(s[2], 0, s[3]), Vector3.new(0, 0, 1))
	end
	for _, s in ipairs(southLine) do
		toWater(s[1], s[2], math.ceil(s[3]), s[3] + OUT)
		wall(CFrame.new((s[1] + s[2]) / 2, 0, s[3] + 40), SEG + 4)
		greenBelt(Vector3.new(s[1], 0, s[3]), Vector3.new(s[2], 0, s[3]), Vector3.new(0, 0, -1))
	end
	-- Ecken + Ostseite (Meer): Wasser bis zum Horizont, Barriere im Meer
	toWater(XMIN - OUT, XMIN, ZMIN - OUT, ZMIN)
	toWater(XMIN - OUT, XMIN, ZMAX, ZMAX + OUT)
	toWater(XMAX, XMAX + OUT, ZMIN - OUT, ZMAX + OUT)
	wall(CFrame.new(3700, 0, 0) * CFrame.Angles(0, math.rad(90), 0), ZMAX - ZMIN + 2 * OUT)
	-- Verbindungswaende zwischen Abschnitten mit unterschiedlicher Grenzlinie (keine Luecken)
	local function joins(line, horizontal)
		for i = 1, #line - 1 do
			local a, b = line[i][3], line[i + 1][3]
			if math.abs(a - b) > 1 then
				local at = line[i][2]
				local off = horizontal and (a < 0 and -40 or 40) or -40
				if horizontal then
					wall(CFrame.new(at, 0, (a + b) / 2 + off) * CFrame.Angles(0, math.rad(90), 0), math.abs(a - b) + 4)
				else
					wall(CFrame.new((a + b) / 2 + off, 0, at), math.abs(a - b) + 4)
				end
			end
		end
	end
	joins(westLine, false)
	joins(northLine, true)
	joins(southLine, true)
	table.insert(log, string.format("Grenze: West %d, Nord %d, Sued %d Abschnitte, %d Baeume/Palmen", #westLine, #northLine, #southLine, trees))

	-- Schilder an Strassen, die an der Grenze enden
	local signs = 0
	local roads = workspace.Map.Roads
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { roads }
	local function signAt(pos, face)
		local m = Instance.new("Model")
		m.Name = "CityLimits"
		local cf = CFrame.lookAt(pos, pos + face)
		Kit.part(m, "Post", Vector3.new(0.5, 9, 0.5), cf * CFrame.new(-3, 4.5, 0), rgb(200, 200, 205), M.Metal)
		Kit.part(m, "Post", Vector3.new(0.5, 9, 0.5), cf * CFrame.new(3, 4.5, 0), rgb(200, 200, 205), M.Metal)
		local board = Kit.part(m, "Board", Vector3.new(8, 3.4, 0.3), cf * CFrame.new(0, 8, 0), rgb(30, 110, 60), M.SmoothPlastic)
		for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local sg = Instance.new("SurfaceGui")
			sg.Face = f
			sg.PixelsPerStud = 40
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.Parent = board
			local l = Instance.new("TextLabel")
			l.Size = UDim2.fromScale(1, 1)
			l.BackgroundTransparency = 1
			l.TextScaled = true
			l.Font = Enum.Font.GothamBlack
			l.TextColor3 = rgb(255, 255, 255)
			l.Text = "MIAMI STATE\nCITY LIMITS"
			l.Parent = sg
		end
		-- Absperrung quer ueber die Fahrbahn
		Kit.part(m, "Barrier", Vector3.new(30, 1.2, 0.6), cf * CFrame.new(0, 2.2, 8), rgb(240, 60, 40), M.SmoothPlastic)
		Kit.part(m, "BarrierStripe", Vector3.new(30, 0.4, 0.62), cf * CFrame.new(0, 2.2, 8), rgb(255, 255, 255), M.SmoothPlastic)
		m.Parent = edgeFolder
		signs += 1
	end
	for _, s in ipairs(northLine) do
		for x = s[1], s[2], 25 do
			local h = workspace:Raycast(Vector3.new(x, 50, s[3] + MARGIN - 20), Vector3.new(0, -80, 0), rp)
			if h then
				signAt(Vector3.new(x, h.Position.Y, s[3] + 30), Vector3.new(0, 0, 1))
				break
			end
		end
	end
	for _, s in ipairs(southLine) do
		for x = s[1], s[2], 25 do
			local h = workspace:Raycast(Vector3.new(x, 50, s[3] - MARGIN + 20), Vector3.new(0, -80, 0), rp)
			if h then
				signAt(Vector3.new(x, h.Position.Y, s[3] - 30), Vector3.new(0, 0, -1))
				break
			end
		end
	end
	for _, s in ipairs(westLine) do
		for z = s[1], s[2], 25 do
			local h = workspace:Raycast(Vector3.new(s[3] + MARGIN - 20, 50, z), Vector3.new(0, -80, 0), rp)
			if h then
				signAt(Vector3.new(s[3] + 30, h.Position.Y, z), Vector3.new(1, 0, 0))
				break
			end
		end
	end
	table.insert(log, "City-Limits-Schilder: " .. signs)

	-- Kartendaten der neuen Gebaeude/Gruenflaechen fuer Stadtkarte/Minimap
	local function ser(list)
		local parts = {}
		for _, e in ipairs(list) do
			local vals = {}
			for _, v in ipairs(e) do
				table.insert(vals, tostring(v))
			end
			table.insert(parts, "{" .. table.concat(vals, ",") .. "}")
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	local lines = {}
	table.insert(lines, "Buildings=" .. ser(mapData.Buildings))
	table.insert(lines, "Green=" .. ser(mapData.Green))
	local holder = ServerStorage:FindFirstChild("CityEdgeMapData") or Instance.new("StringValue")
	holder.Name = "CityEdgeMapData"
	holder.Value = table.concat(lines, "\n")
	holder.Parent = ServerStorage
	table.insert(log, string.format("Kartendaten: %d Gebaeude, %d Gruen (ServerStorage.CityEdgeMapData)", #mapData.Buildings, #mapData.Green))
	return table.concat(log, " | ")
end
