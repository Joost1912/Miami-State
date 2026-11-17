-- Schritt 5: Bayfront Downtown – Skyline, Rathaus, Einsatzstandorte, Uferpromenade.
-- Bloecke liegen zwischen den Strassen aus 03_Roads (je ca. 315 x 315 Studs).
return function(Kit)
	local C, M = Kit.C, Enum.Material
	local dist = workspace.Map.Districts.BayfrontDowntown
	local B, P = dist.Buildings, dist.Props
	B:ClearAllChildren()
	P:ClearAllChildren()
	local svc = workspace.Map.ServiceSites
	-- nur eigene Marker neu setzen (andere Schritte legen hier ebenfalls Marker ab)
	for _, n in ipairs({ "CityHall_Entrance", "PoliceHQ_VehicleSpawn", "FireStation1_VehicleSpawn", "Hospital_AmbulanceSpawn" }) do
		local o = svc:FindFirstChild(n)
		if o then
			o:Destroy()
		end
	end

	local LOT_Y = 0.6
	local cols = { { -284, 31 }, { 129, 444 }, { 516, 831 } }
	local rows = { { -951, -636 }, { -564, -249 }, { -151, 164 }, { 236, 551 }, { 649, 964 } }
	local GLASS = {
		Color3.fromRGB(64, 118, 134), Color3.fromRGB(56, 92, 128), Color3.fromRGB(38, 54, 68),
		Color3.fromRGB(104, 138, 138), Color3.fromRGB(96, 84, 70),
	}
	local CROWN = { Color3.fromRGB(80, 220, 255), Color3.fromRGB(255, 80, 180), Color3.fromRGB(170, 110, 255), Color3.fromRGB(255, 255, 255) }
	local rng = Random.new(305)
	local towerN = 0

	local function bounds(ci, ri)
		local c, r = cols[ci], rows[ri]
		return c[1], r[1], c[2], r[2], (c[1] + c[2]) / 2, (r[1] + r[2]) / 2
	end
	local function lot(name, ci, ri)
		local x0, z0, x1, z1 = bounds(ci, ri)
		Kit.plaza(B, "Lot_" .. name, x0, z0, x1, z1)
	end
	local function palm(x, z)
		Kit.palm(P, Vector3.new(x, LOT_Y, z))
	end
	local function tower(x, z, w, d, h, st)
		towerN += 1
		st = st or {}
		st.glass = st.glass or GLASS[rng:NextInteger(1, #GLASS)]
		st.crown = st.crown or CROWN[rng:NextInteger(1, #CROWN)]
		return Kit.tower(B, string.format("Downtown_Tower_%02d", towerN), Vector3.new(x, LOT_Y, z), w, d, h, st)
	end
	local function marker(name, pos, service)
		local p = Kit.part(svc, name, Vector3.new(4, 1, 4), CFrame.new(pos), Color3.new(1, 1, 1), M.SmoothPlastic, { ghost = true })
		p.Transparency = 1
		p:SetAttribute("Service", service)
		return p
	end

	-- Bloecke mit Hochhaeusern ---------------------------------------------------------
	local function single(ci, ri, h, st)
		local x0, z0, x1, z1, cx, cz = bounds(ci, ri)
		lot(ci .. ri, ci, ri)
		tower(cx, cz, 120, 120, h, st)
		for _, p in ipairs({ { x0 + 22, z0 + 22 }, { x1 - 22, z0 + 22 }, { x0 + 22, z1 - 22 }, { x1 - 22, z1 - 22 } }) do
			palm(p[1], p[2])
		end
	end
	local function pair(ci, ri, h1, h2, st1, st2)
		local x0, z0, x1, z1, cx, cz = bounds(ci, ri)
		lot(ci .. ri, ci, ri)
		tower(cx - 72, cz - 72, 96, 96, h1, st1)
		tower(cx + 72, cz + 72, 96, 96, h2, st2)
		for _, p in ipairs({ { x1 - 30, z0 + 30 }, { x1 - 70, z0 + 30 }, { x0 + 30, z1 - 30 }, { x0 + 30, z1 - 70 } }) do
			palm(p[1], p[2])
		end
	end

	-- Uferreihe (hoechste Gebaeude, Skyline von Coral Key aus)
	pair(3, 1, 380, 300)
	single(3, 2, 450, { spire = 60, crown = Color3.fromRGB(80, 220, 255) })
	pair(3, 3, 340, 260)
	single(3, 4, 400, { crown = Color3.fromRGB(255, 80, 180) })
	pair(3, 5, 320, 280)
	-- Mittlere Reihe
	pair(2, 1, 240, 200)
	single(2, 2, 280)
	pair(2, 4, 220, 180)
	-- Westreihe
	pair(1, 2, 150, 120, { setback = false }, { setback = false })

	-- Rathaus mit Platz und Brunnen (Block 2/3) --------------------------------------------
	do
		local x0, z0, x1, z1, cx, cz = bounds(2, 3)
		lot("CityHall", 2, 3)
		Kit.midrise(B, "CityHall", Vector3.new(cx, LOT_Y, z0 + 70), 190, 90, 4, {
			color = Color3.fromRGB(244, 242, 236), floorH = 15, sign = "CITY HALL", signColor = Color3.fromRGB(30, 60, 90),
			rot = math.pi, -- Front nach Sueden zum Platz
		})
		local f = Kit.model(P, "Fountain")
		Kit.part(f, "Basin", Vector3.new(2.4, 44, 44), CFrame.new(cx, LOT_Y + 1.2, cz + 60) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(226, 220, 206), M.Limestone, { shape = Enum.PartType.Cylinder })
		Kit.part(f, "Water", Vector3.new(0.4, 40, 40), CFrame.new(cx, LOT_Y + 2.3, cz + 60) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 170, 200), M.Glass, { shape = Enum.PartType.Cylinder, transp = 0.25, decor = true })
		Kit.part(f, "Column", Vector3.new(10, 4, 4), CFrame.new(cx, LOT_Y + 5, cz + 60) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(226, 220, 206), M.Limestone, { shape = Enum.PartType.Cylinder })
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			palm(cx + math.cos(a) * 70, cz + 60 + math.sin(a) * 70)
		end
		marker("CityHall_Entrance", Vector3.new(cx, LOT_Y + 1, z0 + 125), "CityHall")
	end

	-- Parkhaus + kleineres Buerohaus (Block 2/5)
	do
		local x0, z0, x1, z1, cx, cz = bounds(2, 5)
		lot("Garage", 2, 5)
		-- Phase 3: befahrbares Parkhaus (ersetzt den bisherigen Platzhalter an gleicher Stelle), Einfahrt zur Port St
		Kit.parkingGarage(B, "ParkingGarage", Vector3.new(cx - 70, LOT_Y, cz), 150, 280, 5, { sign = "DOWNTOWN PARKING" })
		tower(cx + 95, cz, 90, 90, 180, { setback = false })
	end

	-- Polizei-Hauptquartier (Block 1/3) ----------------------------------------------------------
	do
		local x0, z0, x1, z1, cx, cz = bounds(1, 3)
		lot("PoliceHQ", 1, 3)
		-- Phase 6: Gebaeude mit Innenraeumen entsteht in Schritt 19_PoliceStation (Map.PoliceStation)
		Kit.parkingLot(B, "PoliceHQ_Parking", x0 + 10, z0 + 150, x1 - 10, z1 - 10)
		marker("PoliceHQ_VehicleSpawn", Vector3.new(cx, LOT_Y + 1, (z0 + 150 + z1) / 2), "Police")
	end

	-- Feuerwache 1 (Block 1/4) -------------------------------------------------------------------
	do
		local x0, z0, x1, z1, cx, cz = bounds(1, 4)
		lot("FireStation1", 1, 4)
		local fs = Kit.midrise(B, "FireStation1", Vector3.new(cx, LOT_Y, z1 - 90), 170, 80, 2, {
			color = Color3.fromRGB(150, 56, 44), material = M.Brick, glass = Color3.fromRGB(46, 50, 56), trim = Color3.fromRGB(236, 232, 224),
			floorH = 16, sign = "FIRE STATION 1", signColor = Color3.fromRGB(255, 230, 120), rot = math.pi,
		})
		-- Fahrzeughallen-Tore zur Harbor Blvd (Sueden)
		for i = 0, 3 do
			Kit.part(fs, "BayDoor", Vector3.new(26, 16, 0.6), CFrame.new(cx - 60 + i * 40, LOT_Y + 8, z1 - 90 + 40.4), Color3.fromRGB(236, 232, 224), M.Metal, { decor = true })
		end
		Kit.part(B, "FireStation1_Apron", Vector3.new(170, 0.3, 46), CFrame.new(cx, LOT_Y + 0.15, z1 - 26), C.concrete, M.Concrete)
		marker("FireStation1_VehicleSpawn", Vector3.new(cx, LOT_Y + 1, z1 - 26), "Fire")
		Kit.midrise(B, "Office_FireBlock", Vector3.new(cx, LOT_Y, z0 + 70), 180, 100, 7, { color = Color3.fromRGB(214, 206, 192) })
	end

	-- Krankenhaus (Block 1/1, nahe Anschlussstelle Coconut) ------------------------------------
	do
		local x0, z0, x1, z1, cx, cz = bounds(1, 1)
		lot("Hospital", 1, 1)
		local hm, H = Kit.midrise(B, "BayfrontMedical", Vector3.new(cx, LOT_Y, cz - 30), 220, 120, 8, {
			color = Color3.fromRGB(246, 246, 244), glass = Color3.fromRGB(60, 100, 120), sign = "BAYFRONT MEDICAL CENTER", signColor = Color3.fromRGB(220, 30, 40),
		})
		-- Hubschrauberlandeplatz
		local pad = Kit.part(hm, "Helipad", Vector3.new(1, 60, 60), CFrame.new(cx + 40, LOT_Y + H + 2.1, cz - 30) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 62, 66), M.Concrete, { shape = Enum.PartType.Cylinder })
		Kit.part(hm, "HelipadH", Vector3.new(4, 0.1, 22), CFrame.new(cx + 32, LOT_Y + H + 2.65, cz - 30), Color3.new(1, 1, 1), M.SmoothPlastic, { decor = true })
		Kit.part(hm, "HelipadH", Vector3.new(4, 0.1, 22), CFrame.new(cx + 48, LOT_Y + H + 2.65, cz - 30), Color3.new(1, 1, 1), M.SmoothPlastic, { decor = true })
		Kit.part(hm, "HelipadH", Vector3.new(12, 0.1, 4), CFrame.new(cx + 40, LOT_Y + H + 2.65, cz - 30), Color3.new(1, 1, 1), M.SmoothPlastic, { decor = true })
		local _ = pad
		-- Notaufnahme (Suedseite) mit Vordach
		Kit.part(hm, "ER_Canopy", Vector3.new(80, 2, 34), CFrame.new(cx - 40, LOT_Y + 16, cz + 30 + 17), Color3.fromRGB(236, 236, 232), M.Concrete)
		Kit.sign(hm, CFrame.new(cx - 40, LOT_Y + 20, cz + 30 + 34.6) * CFrame.Angles(0, math.pi, 0), Vector3.new(40, 6, 1), "EMERGENCY", Color3.fromRGB(255, 40, 50))
		Kit.part(B, "Hospital_AmbulanceBay", Vector3.new(120, 0.3, 70), CFrame.new(cx - 40, LOT_Y + 0.15, z1 - 40), C.concrete, M.Concrete)
		marker("Hospital_AmbulanceSpawn", Vector3.new(cx - 40, LOT_Y + 1, z1 - 40), "EMS")
	end

	-- Westreihe Sued: Einzelhandel (Block 1/5)
	do
		local x0, z0, x1, z1, cx, cz = bounds(1, 5)
		lot("Retail", 1, 5)
		Kit.midrise(B, "RetailCenter", Vector3.new(cx, LOT_Y, cz), 240, 160, 3, {
			color = Color3.fromRGB(240, 226, 206), floorH = 16, sign = "BAYSIDE MARKET", signColor = Color3.fromRGB(255, 120, 90), rot = math.pi,
		})
	end

	-- Uferpromenade und Kaimauer entlang der Bucht --------------------------------------------
	local prom = Kit.model(P, "BayfrontPromenade")
	-- Luecke fuer die Bruecke; suedlich Z 1040 beginnt der Hafen (eigene Kaimauer)
	local segments = { { -2600, -262 }, { -138, 1040 } }
	-- Gelaender mit Durchgang zur Marina und zum Marina Village (Z -2570 .. -1450)
	for _, r in ipairs({ { -2600, -2570 }, { -1450, -262 }, { -138, 1040 } }) do
		Kit.part(prom, "Railing", Vector3.new(0.6, 3.4, r[2] - r[1]), CFrame.new(1001.5, 2.3, (r[1] + r[2]) / 2), Kit.C.metal, M.Metal)
	end
	for _, s in ipairs(segments) do
		local len, mid = s[2] - s[1], (s[1] + s[2]) / 2
		Kit.part(prom, "Seawall", Vector3.new(4, 12, len), CFrame.new(1000, -5.4, mid), Color3.fromRGB(206, 200, 188), M.Concrete)
		Kit.part(prom, "Walkway", Vector3.new(64, 1, len), CFrame.new(966, 0.1, mid), Color3.fromRGB(222, 212, 192), M.Pavement)
		for z = s[1] + 30, s[2] - 30, 56 do
			Kit.palm(prom, Vector3.new(944, 0.6, z))
		end
		for z = s[1] + 60, s[2] - 60, 112 do
			Kit.streetLight(prom, CFrame.lookAt(Vector3.new(990, 0.6, z), Vector3.new(980, 0.6, z)))
		end
		task.wait()
	end

	-- Spawn auf dem Rathausplatz
	local spawn = workspace:FindFirstChild("SpawnLocation") or workspace.Map.SpawnPoints:FindFirstChild("SpawnLocation")
	if spawn then
		local _, _, _, _, cx, cz = bounds(2, 3)
		spawn.CFrame = CFrame.new(cx, LOT_Y + 0.5, cz + 120)
		spawn.Parent = workspace.Map.SpawnPoints
	end

	local n = 0
	for _, d in ipairs(dist:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return string.format("Hochhaeuser %d, Parts Downtown %d", towerN, n)
end
