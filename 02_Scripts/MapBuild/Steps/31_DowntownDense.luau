-- Schritt 31 (Prompt 14): Downtown verdichten.
-- Die Downtown-Bloecke (315 x 315) bestehen zu grossen Teilen aus leerem Pflaster -> Downtown wirkt riesig und leer.
-- Freie Flaechen der Bloecke werden mit Buerotuermen und Buerobauten gefuellt (nicht ueber Spielmarker, Fahrzeuge,
-- Baeume, bestehende Gebaeude oder Zufahrten). Bloecke mit Dienstgebaeuden (Polizei, Klinik, Feuerwehr, Rathaus,
-- Parkhaus, Einkaufszentrum) bleiben unangetastet. Pro Block bleibt ein Teil als Platz frei.
-- Ergebnis: workspace.Map.DowntownDense (idempotent), Kartendaten in ServerStorage.DowntownDenseMapData.
-- Danach Schritt 30_Facades erneut ausfuehren (Fensterraster/Bueros fuer die neuen Gebaeude).
return function(Kit)
	local CollectionService = game:GetService("CollectionService")
	local ServerStorage = game:GetService("ServerStorage")
	local rgb = Color3.fromRGB

	local root = workspace.Map:FindFirstChild("DowntownDense")
	if root then
		root:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "DowntownDense"

	-- Dienstgrundstuecke (Polizei, Klinik, Feuerwehr, Rathaus) haben grosse Leerflaechen: dort hoechstens 2 Bauten,
	-- Parkplaetze/Spawns/Zufahrten bleiben ueber Sperrzonen frei. Parkhaus und Einkaufszentrum sind voll.
	local SKIP = { Lot_Garage = true, Lot_Retail = true }
	local SERVICE = { Lot_Hospital = true, Lot_PoliceHQ = true, Lot_FireStation1 = true, Lot_CityHall = true }
	local GLASS = { rgb(70, 120, 135), rgb(46, 80, 104), rgb(90, 110, 130), rgb(60, 96, 104), rgb(110, 130, 150) }
	local FRAMES = { rgb(226, 226, 220), rgb(200, 204, 210), rgb(236, 230, 218), rgb(180, 186, 196) }
	local BODIES = { rgb(232, 228, 220), rgb(214, 218, 222), rgb(226, 214, 200), rgb(200, 206, 214), rgb(236, 232, 224) }
	local MARKER_TAGS = { "VehicleSpawnPad", "VehicleParkSpot", "FuelPump", "ParkedCar", "Interactable", "StoreEntrance", "ShopEntrance", "Vehicle" }

	local markers = {}
	for _, tag in ipairs(MARKER_TAGS) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			if inst:IsDescendantOf(workspace) then
				local p = inst:IsA("BasePart") and inst.Position or (inst:IsA("Model") and inst:GetPivot().Position)
				if p then
					table.insert(markers, p)
				end
			end
		end
	end

	-- Sperrzonen: Dienst-Parkplaetze, Rampen, Vorfelder, Spawnpunkte
	local keepOut = {}
	local B = workspace.Map.Districts.BayfrontDowntown.Buildings
	for _, n in ipairs({ "PoliceHQ_Parking", "ParkingGarage", "Hospital_AmbulanceBay", "FireStation1_Apron" }) do
		local o = B:FindFirstChild(n)
		if o then
			local cf, s
			if o:IsA("Model") then
				cf, s = o:GetBoundingBox()
			else
				cf, s = o.CFrame, o.Size
			end
			table.insert(keepOut, { cf.X, cf.Z, s.X / 2 + 24, s.Z / 2 + 24 })
		end
	end
	for _, f in ipairs({ workspace.Map:FindFirstChild("ServiceSites"), workspace.Map:FindFirstChild("SpawnPoints") }) do
		for _, p in ipairs(f and f:GetDescendants() or {}) do
			if p:IsA("BasePart") then
				table.insert(keepOut, { p.Position.X, p.Position.Z, 40, 40 })
			end
		end
	end
	local function isFree(cx, cz, w, d, ground, ignore)
		for _, k in ipairs(keepOut) do
			if math.abs(k[1] - cx) < w / 2 + k[3] and math.abs(k[2] - cz) < d / 2 + k[4] then
				return false
			end
		end
		for _, p in ipairs(markers) do
			if math.abs(p.X - cx) < w / 2 + 10 and math.abs(p.Z - cz) < d / 2 + 10 then
				return false
			end
		end
		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Exclude
		op.FilterDescendantsInstances = ignore
		local parts = workspace:GetPartBoundsInBox(CFrame.new(cx, ground + 16, cz), Vector3.new(w + 16, 30, d + 16), op)
		for _, p in ipairs(parts) do
			if p.Size.Y > 1.2 and p.Transparency < 0.95 then
				return false
			end
			if p.Name == "DrivewayRamp" or (#CollectionService:GetTags(p) > 0 and p.Name ~= "Lawn") then
				return false
			end
		end
		return true
	end

	local SIZES = { { 76, 76 }, { 64, 84 }, { 84, 64 }, { 60, 60 }, { 48, 64 }, { 64, 48 }, { 44, 44 } }
	local mapData = { Buildings = {} }
	local built, lotsDone = 0, 0
	local lots = {}
	for _, p in ipairs(workspace.Map.Districts.BayfrontDowntown.Buildings:GetChildren()) do
		if p:IsA("BasePart") and p.Name:match("^Lot_") and not SKIP[p.Name] and p.Size.X >= 300 then
			table.insert(lots, p)
		end
	end
	table.sort(lots, function(a, b)
		return a.Name < b.Name
	end)
	for li, lot in ipairs(lots) do
		local rng = Random.new(3100 + li * 31)
		local ground = lot.Position.Y + lot.Size.Y / 2
		local x0, x1 = lot.Position.X - lot.Size.X / 2 + 16, lot.Position.X + lot.Size.X / 2 - 16
		local z0, z1 = lot.Position.Z - lot.Size.Z / 2 + 16, lot.Position.Z + lot.Size.Z / 2 - 16
		local folder = Instance.new("Folder")
		folder.Name = "Dense_" .. lot.Name
		folder.Parent = root
		root.Parent = workspace.Map -- frisch Gebautes muss fuer die Belegungspruefung sichtbar sein
		local n = 0
		local ignore = { lot }
		-- Raster von den Raendern nach innen; ab 4 neuen Gebaeuden je Block bleibt der Rest Platz
		for _, sz in ipairs(SIZES) do
			for gx = x0, x1, 12 do
				for gz = z0, z1, 12 do
					if n >= (SERVICE[lot.Name] and 2 or 4) then
						break
					end
					local w, d = sz[1], sz[2]
					local cx, cz = gx + w / 2, gz + d / 2
					if cx + w / 2 <= x1 and cz + d / 2 <= z1 and isFree(cx, cz, w, d, ground, ignore) then
						n += 1
						built += 1
						local name = string.format("Office_%d_%d", math.floor(cx), math.floor(cz))
						local pos = Vector3.new(cx, ground, cz)
						local h
						if w * d >= 3600 then
							local kind = rng:NextInteger(1, 2)
							h = rng:NextInteger(110, 230)
							local st = { glass = GLASS[rng:NextInteger(1, #GLASS)], frame = FRAMES[rng:NextInteger(1, #FRAMES)], seed = li * 10 + n, crown = rgb(80, 220, 255) }
							if kind == 1 then
								Kit.tower(folder, name, pos, w - 4, d - 4, h, st)
							else
								Kit.towerStepped(folder, name, pos, w - 4, d - 4, h, st)
							end
						else
							local floors = rng:NextInteger(5, 9)
							local _, H = Kit.midrise(folder, name, pos, w, d, floors, { color = BODIES[rng:NextInteger(1, #BODIES)], floorH = 13 })
							h = H
						end
						table.insert(mapData.Buildings, { math.floor(cx), math.floor(cz), w, d, 0, math.floor(h) })
					end
				end
				if n >= (SERVICE[lot.Name] and 2 or 4) then
					break
				end
				task.wait()
			end
		end
		lotsDone += 1
		ServerStorage:SetAttribute("DenseStatus", string.format("%d/%d Bloecke, %d Gebaeude", lotsDone, #lots, built))
	end
	root.Parent = workspace.Map
	local md = ServerStorage:FindFirstChild("DowntownDenseMapData") or Instance.new("StringValue")
	md.Name = "DowntownDenseMapData"
	md.Value = game:GetService("HttpService"):JSONEncode(mapData)
	md.Parent = ServerStorage
	return string.format("%d Bloecke, %d neue Buerogebaeude", lotsDone, built)
end
