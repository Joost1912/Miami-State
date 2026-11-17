-- Schritt 14: Sawgrass Park – Vorort, Wohnen, Gewerbe (X -4200 .. -700, Z -2400 .. 2200).
-- Spalten zwischen den Nord-Sued-Strassen (03_Roads): c1 Glades-Cypress, c2 Cypress-Sawgrass Ave,
-- c3 Sawgrass Ave-Mangrove, c4 Mangrove-HeightsWest, c5/c6 suedlich von Coconut Heights.
return function(Kit)
	local C, M = Kit.C, Enum.Material
	local dist = workspace.Map.Districts.SawgrassPark
	local B, P = dist.Buildings, dist.Props
	B:ClearAllChildren()
	P:ClearAllChildren()
	local rng = Random.new(3000)
	local Y = 0.6 -- Grundstuecks-Oberkante (Plaza)

	-- Terrain nach Westen erweitern (Land bis X -4600)
	local T = workspace.Terrain
	for x = -4600, -2400 - 1, 512 do
		for z = -3200, 2800 - 1, 512 do
			local xe, ze = math.min(x + 512, -2400), math.min(z + 512, 2800)
			T:FillBlock(CFrame.new((x + xe) / 2, -29, (z + ze) / 2), Vector3.new(xe - x, 54, ze - z), M.Grass)
		end
		task.wait()
	end

	local cols = {
		{ -4164, -3636 }, { -3564, -3049 }, { -2951, -2436 }, { -2364, -1923 }, { -1877, -1336 }, { -1264, -723 },
	}
	local R1, R2, R3, R4 = { -951, -249 }, { -151, 551 }, { 649, 1364 }, { 1436, 2164 }
	local function pick(t)
		return t[rng:NextInteger(1, #t)]
	end
	local stats = { houses = 0, apartments = 0, shops = 0, offices = 0, workshops = 0 }

	-- Wohnreihen -----------------------------------------------------------------------------
	local LOT_W, LOT_D = 75, 150
	local function houseRow(x0, x1, zFront, side, villaChance)
		local count = math.floor((x1 - x0) / LOT_W)
		local start = (x0 + x1) / 2 - (count - 1) * LOT_W / 2
		for i = 0, count - 1 do
			stats.houses += 1
			local x = start + i * LOT_W
			local zc = zFront + side * LOT_D / 2
			local cf = CFrame.lookAt(Vector3.new(x, 0, zc), Vector3.new(x, 0, zFront - side))
			local seed = stats.houses * 17 + 5
			Kit.house(B, string.format("SG_House_%03d", stats.houses), cf, {
				seed = seed, lotW = LOT_W, lotD = LOT_D, villa = rng:NextNumber() < (villaChance or 0.15), palm = (i % 3 == 0),
			})
			if i % 3 == 1 then
				Kit.tree(P, (cf * CFrame.new(LOT_W * 0.3, 0, -LOT_D * 0.35)).Position, seed)
			end
		end
	end
	-- Nordteil: an den durchgehenden Wohnstrassen, Spalten c1..c4
	for _, zs in ipairs({ -1350, -1700, -2050, -2400 }) do
		for ci = 1, 4 do
			local c = cols[ci]
			houseRow(c[1], c[2], zs - 23, -1, (zs == -2400) and 0.6 or 0.12)
			houseRow(c[1], c[2], zs + 23, 1, 0.12)
		end
		task.wait()
	end
	-- c1 Suedbloecke mit eigenen Wohnstrassen (Palmetto Ln, Breeze Ln), c1/c2 an der Sunset Ln
	houseRow(cols[1][1], cols[1][2], -951, 1)
	houseRow(cols[1][1], cols[1][2], -623, -1)
	houseRow(cols[1][1], cols[1][2], -577, 1)
	houseRow(cols[1][1], cols[1][2], -249, -1)
	houseRow(cols[1][1], cols[1][2], -151, 1)
	houseRow(cols[1][1], cols[1][2], 177, -1)
	houseRow(cols[1][1], cols[1][2], 223, 1)
	houseRow(cols[1][1], cols[1][2], 551, -1)
	for ci = 1, 2 do
		houseRow(cols[ci][1], cols[ci][2], 1436, 1)
		houseRow(cols[ci][1], cols[ci][2], 1777, -1)
		houseRow(cols[ci][1], cols[ci][2], 1823, 1)
		houseRow(cols[ci][1], cols[ci][2], 2164, -1)
	end
	task.wait()

	-- Ladenzeile am Coconut Blvd (Nordseite, Front nach Sueden) ---------------------------
	local SHOPS = {
		"SUNNY CAFE", "LA COCINA", "NAIL SPA", "BARBER CO", "PET WORLD", "BOOK NOOK", "TACO LOCO", "DONUT TIME",
		"FLOWER SHOP", "DRY CLEANERS", "PHONE FIX", "GELATO", "BAKERY", "SUSHI GO", "YOGA STUDIO", "PIZZA NAPOLI",
		"OPTICIAN", "TOY BOX", "SURF SHOP", "BANK OF SAWGRASS",
	}
	local SIGNC = { Color3.fromRGB(255, 200, 80), Color3.fromRGB(80, 220, 255), Color3.fromRGB(255, 110, 150), Color3.fromRGB(140, 255, 160) }
	local FAC = { Color3.fromRGB(242, 230, 210), Color3.fromRGB(226, 236, 232), Color3.fromRGB(246, 222, 212), Color3.fromRGB(232, 228, 240) }
	local si = 0
	for ci = 1, 4 do
		local c = cols[ci]
		local n = math.floor((c[2] - c[1] - 20) / 72)
		local x0 = (c[1] + c[2]) / 2 - (n * 72) / 2 + 36
		for i = 0, n - 1 do
			si += 1
			stats.shops += 1
			local cf = CFrame.new(x0 + i * 72, Y - 0.6, -1062) * CFrame.Angles(0, math.pi, 0)
			Kit.storefront(B, cf, 70, 20, 60, SHOPS[(si - 1) % #SHOPS + 1], FAC[si % #FAC + 1], SIGNC[si % #SIGNC + 1])
		end
	end
	task.wait()

	-- Apartmentanlage (Block): 3 Gebaeude um einen Poolhof, Parkplatz, Spielplatz ------------
	local APT = { "PALM VILLAS", "CORAL GARDENS", "SAWGRASS COMMONS", "MANGROVE POINTE" }
	local aptN = 0
	local function apartmentComplex(c, r)
		aptN += 1
		local x0, x1, z0, z1 = c[1], c[2], r[1], r[2]
		local cx = (x0 + x1) / 2
		Kit.plaza(B, "Lot_Apartments_" .. aptN, x0, z0, x1, z1, Color3.fromRGB(214, 206, 190))
		local col = pick({ Color3.fromRGB(244, 230, 206), Color3.fromRGB(226, 236, 230), Color3.fromRGB(248, 222, 210) })
		local acc = pick({ Color3.fromRGB(200, 120, 90), Color3.fromRGB(90, 160, 170), Color3.fromRGB(210, 170, 90) })
		local seed = aptN * 101
		Kit.lowriseApartments(B, "Apartments_" .. aptN .. "_A", Vector3.new(cx, Y, z0 + 50), x1 - x0 - 60, 60, 3, { rot = math.pi, color = col, accent = acc, seed = seed })
		Kit.lowriseApartments(B, "Apartments_" .. aptN .. "_B", Vector3.new(x0 + 50, Y, z0 + 230), 140, 60, 3, { rot = -math.pi / 2, color = col, accent = acc, seed = seed + 1 })
		Kit.lowriseApartments(B, "Apartments_" .. aptN .. "_C", Vector3.new(x1 - 50, Y, z0 + 230), 140, 60, 3, { rot = math.pi / 2, color = col, accent = acc, seed = seed + 2 })
		stats.apartments += 3
		Kit.part(P, "PoolDeck", Vector3.new(140, 0.4, 90), CFrame.new(cx, Y + 0.2, z0 + 220), Color3.fromRGB(236, 230, 214), M.Limestone)
		Kit.part(P, "Pool", Vector3.new(80, 0.3, 40), CFrame.new(cx, Y + 0.45, z0 + 220), Color3.fromRGB(70, 200, 230), M.Glass, { transp = 0.15, refl = 0.3, decor = true })
		Kit.palm(P, Vector3.new(cx - 60, Y, z0 + 180))
		Kit.palm(P, Vector3.new(cx + 60, Y, z0 + 260))
		Kit.playground(P, Vector3.new(cx, Y, z0 + 320))
		local lz0 = z0 + 360
		Kit.parkingLot(B, "Apartments_" .. aptN .. "_Parking", x0 + 10, lz0, x1 - 10, z1 - 10, Y)
		for lx = x0 + 70, x1 - 70, 130 do
			Kit.lotLight(P, Vector3.new(lx, Y, (lz0 + z1) / 2))
		end
		Kit.sign(P, CFrame.new(x1 - 40, Y + 3, z1 - 4) * CFrame.Angles(0, math.pi, 0), Vector3.new(40, 5, 1), APT[(aptN - 1) % #APT + 1], Color3.fromRGB(40, 80, 90), Color3.fromRGB(240, 236, 226))
	end

	-- Buero-Park (Block)
	local function officePark(c, r, publicParking)
		local x0, x1, z0, z1 = c[1], c[2], r[1], r[2]
		Kit.plaza(B, "Lot_Office_" .. x0 .. "_" .. z0, x0, z0, x1, z1)
		local w = (x1 - x0 - 50) / 2
		for i = 0, 1 do
			stats.offices += 1
			local m, H = Kit.midrise(B, string.format("SG_Office_%02d", stats.offices), Vector3.new(x0 + 20 + w / 2 + i * (w + 10), Y, z0 + 70), w, 90, rng:NextInteger(3, 5), {
				color = pick({ Color3.fromRGB(226, 228, 232), Color3.fromRGB(212, 206, 196) }), glass = Color3.fromRGB(40, 80, 110), floorH = 14,
			})
			Kit.litWindows(m, function(x, y, z)
				return CFrame.new(x0 + 20 + w / 2 + i * (w + 10) + x, Y + y, z0 + 70 + z)
			end, w, 90, 0, H, rng, 0.4)
		end
		Kit.parkingLot(B, publicParking and "PublicParking" or "OfficeParking", x0 + 10, z0 + 150, x1 - 10, z1 - 10, Y)
		for lx = x0 + 70, x1 - 70, 130 do
			for lz = z0 + 210, z1 - 50, 140 do
				Kit.lotLight(P, Vector3.new(lx, Y, lz))
			end
		end
		if publicParking then
			Kit.part(P, "ParkingSignPole", Vector3.new(1, 14, 1), CFrame.new(x0 + 20, Y + 7, z1 - 8), C.metal, M.Metal)
			Kit.sign(P, CFrame.new(x0 + 20, Y + 15, z1 - 8.6) * CFrame.Angles(0, math.pi, 0), Vector3.new(14, 5, 0.4), "PUBLIC PARKING", Color3.new(1, 1, 1), Color3.fromRGB(20, 60, 140))
		end
	end

	-- Gewerbe: Werkstaetten / Lagerhallen in einer Reihe
	local WORKSHOPS = {
		{ "SAWGRASS AUTO REPAIR", Color3.fromRGB(200, 40, 40) }, { "TIRE PRO", Color3.fromRGB(30, 30, 30) },
		{ "GLADES BODY SHOP", Color3.fromRGB(30, 90, 170) }, { "SUNCOAST PLUMBING", Color3.fromRGB(40, 140, 120) },
		{ "BLUE WAVE BOATS", Color3.fromRGB(20, 110, 180) }, { "METRO ELECTRIC", Color3.fromRGB(230, 160, 30) },
		{ "PRINT & SIGN CO", Color3.fromRGB(150, 60, 140) }, { "GULF COAST SUPPLY", Color3.fromRGB(110, 110, 120) },
	}
	local function workshopRow(c, r)
		local x0, x1, z0, z1 = c[1], c[2], r[1], r[2]
		Kit.plaza(B, "Lot_Commercial_" .. x0 .. "_" .. z0, x0, z0, x1, z1, Color3.fromRGB(176, 172, 164))
		local n = math.max(1, math.floor((x1 - x0) / 130))
		local w = (x1 - x0 - 20) / n - 14
		for i = 0, n - 1 do
			stats.workshops += 1
			local ws = WORKSHOPS[(stats.workshops - 1) % #WORKSHOPS + 1]
			local x = x0 + 10 + (w + 14) * i + w / 2 + 7
			Kit.warehouse(B, "SG_Workshop_" .. stats.workshops, Vector3.new(x, Y, z0 + 90), w, 90, 26, { rot = math.pi, sign = ws[1], accent = ws[2] })
			Kit.warehouse(B, "SG_Workshop_" .. stats.workshops .. "b", Vector3.new(x, Y, z1 - 80), w, 80, 22, { sign = WORKSHOPS[(stats.workshops + 3) % #WORKSHOPS + 1][1], accent = Color3.fromRGB(90, 96, 104) })
		end
	end

	-- Self-Storage
	local function selfStorage(c, r)
		local x0, x1, z0, z1 = c[1], c[2], r[1], r[2]
		Kit.plaza(B, "Lot_Storage", x0, z0, x1, z1, Color3.fromRGB(176, 172, 164))
		local st = Kit.model(B, "SelfStorage")
		for row = 0, 4 do
			local z = z0 + 60 + row * 120
			if z + 20 < z1 then
				Kit.part(st, "Unit", Vector3.new(x1 - x0 - 60, 11, 34), CFrame.new((x0 + x1) / 2, Y + 5.5, z), Color3.fromRGB(236, 232, 224), M.Plaster)
				for dx = x0 + 42, x1 - 42, 14 do
					Kit.part(st, "Door", Vector3.new(10, 8, 0.4), CFrame.new(dx, Y + 4, z - 17.2), Color3.fromRGB(240, 130, 30), M.Metal, { decor = true })
				end
			end
		end
		Kit.sign(st, CFrame.new((x0 + x1) / 2, Y + 16, z0 + 40), Vector3.new(60, 8, 1), "SAWGRASS SELF STORAGE", Color3.fromRGB(255, 140, 40), Color3.fromRGB(20, 22, 26))
	end

	-- R1 ------------------------------------------------------------------------------
	apartmentComplex(cols[2], R1)
	do -- Shopping Center (c3)
		local c = cols[3]
		Kit.plaza(B, "Lot_ShoppingCenter", c[1], R1[1], c[2], R1[2], Color3.fromRGB(214, 206, 190))
		Kit.shoppingCenter(B, "SawgrassCenter", c[1], R1[1], c[2], R1[2], {
			{ name = "FRESHWAY MARKET", w = 140, h = 32, color = Color3.fromRGB(120, 230, 120) },
			{ name = "VOLT ELECTRONICS", w = 80, color = Color3.fromRGB(80, 200, 255) },
			{ name = "URBAN THREADS", w = 70, color = Color3.fromRGB(255, 120, 170) },
			{ name = "CAREPLUS PHARMACY", w = 64, color = Color3.fromRGB(255, 80, 80) },
			{ name = "PRO SPORTS", w = 64, color = Color3.fromRGB(255, 200, 60) },
			{ name = "CASA FURNITURE", w = 56, color = Color3.fromRGB(230, 200, 150) },
		}, { y = Y, garageW = 130, sign = "SAWGRASS CENTER" })
		Kit.parkingGarage(B, "SawgrassCenter_Garage", Vector3.new(c[2] - 70, Y, R1[2] - 110), 120, 200, 4, { sign = "CENTER PARKING", accent = Color3.fromRGB(220, 120, 40) })
		-- Outparcels: Fast Food mit Drive-Thru und Cafe
		local ff = Kit.storefront(B, CFrame.new(c[1] + 110, Y, R1[2] - 70) * CFrame.Angles(0, math.pi, 0), 56, 18, 40, "STAR BURGER", Color3.fromRGB(250, 220, 80), Color3.fromRGB(230, 40, 40))
		Kit.part(ff, "DriveThruLane", Vector3.new(14, 0.1, 90), CFrame.new(c[1] + 150, Y + 0.12, R1[2] - 90), Color3.fromRGB(230, 200, 60), M.SmoothPlastic, { decor = true, transp = 0.6 })
		Kit.part(ff, "PoleSign", Vector3.new(2, 30, 2), CFrame.new(c[1] + 60, Y + 15, R1[2] - 30), C.metal, M.Metal)
		Kit.sign(ff, CFrame.new(c[1] + 60, Y + 30, R1[2] - 31.2) * CFrame.Angles(0, math.pi, 0), Vector3.new(18, 8, 1), "STAR BURGER", Color3.fromRGB(255, 220, 60), Color3.fromRGB(200, 30, 30))
		local cafe = Kit.storefront(B, CFrame.new(c[1] + 240, Y, R1[2] - 70) * CFrame.Angles(0, math.pi, 0), 40, 16, 34, "BEAN & LEAF", Color3.fromRGB(226, 236, 226), Color3.fromRGB(60, 140, 90))
		Kit.outdoorSeating(cafe, CFrame.new(c[1] + 240, Y, R1[2] - 58), 3, Color3.fromRGB(60, 140, 90))
		-- Zufahrten vom Coconut Blvd und Causeway Blvd
		for _, x in ipairs({ c[1] + 60, c[1] + 300 }) do
			Kit.driveway(P, Vector3.new(x, 0.2, -235), Vector3.new(0, 0, 1), 26)
		end
	end
	do -- grosse Tankstelle (c4) am Coconut Blvd
		local c = cols[4]
		local cx = (c[1] + c[2]) / 2
		Kit.plaza(B, "Lot_GasStation1", c[1], R1[1], c[2], R1[2], Color3.fromRGB(214, 206, 190))
		Kit.gasStation(B, "GasStation_SunshineFuel_Sawgrass", CFrame.lookAt(Vector3.new(cx, 0, -846), Vector3.new(cx, 0, -1000)), {
			large = true, brand = "SUNSHINE FUEL", shopName = "SUNSHINE MART", y = Y + 0.2,
		})
		for _, x in ipairs({ cx - 90, cx + 90 }) do
			Kit.driveway(P, Vector3.new(x, 0.2, -965), Vector3.new(0, 0, -1), 26)
		end
		local diner = Kit.storefront(B, CFrame.new(cx, Y, R1[2] - 150) * CFrame.Angles(0, math.pi, 0), 120, 18, 60, "SAWGRASS DINER", Color3.fromRGB(230, 236, 240), Color3.fromRGB(255, 80, 100))
		Kit.outdoorSeating(diner, CFrame.new(cx, Y, R1[2] - 136), 4, Color3.fromRGB(255, 80, 100))
		Kit.parkingLot(B, "Diner_Parking", c[1] + 10, R1[2] - 120, c[2] - 10, R1[2] - 10, Y)
	end
	apartmentComplex(cols[5], R1)
	officePark(cols[6], R1, true)
	task.wait()

	-- R2 ------------------------------------------------------------------------------
	do -- Sawgrass Park (Gruenanlage) + Restaurantzeile zur Sawgrass Ave
		local c = cols[2]
		Kit.park(P, "SawgrassCentralPark", c[1], R2[1], c[2] - 140, R2[2], rng, true)
		Kit.plaza(B, "Lot_RestaurantRow", c[2] - 135, R2[1], c[2], R2[2], Color3.fromRGB(214, 206, 190))
		local REST = { "LA COCINA", "SUSHI GO", "PIZZA NAPOLI", "CAFE MOKA", "BURGER BAR", "GELATERIA", "THAI ORCHID", "SMOKEHOUSE BBQ" }
		for i = 0, 7 do
			local z = R2[1] + 44 + i * 84
			if z + 40 < R2[2] then
				local cf = CFrame.new(c[2] - 24, Y, z) * CFrame.Angles(0, -math.pi / 2, 0)
				local st = Kit.storefront(B, cf, 80, 18, 90, REST[i + 1], FAC[i % #FAC + 1], SIGNC[i % #SIGNC + 1])
				Kit.outdoorSeating(st, CFrame.new(c[2] - 14, Y, z) * CFrame.Angles(0, math.rad(90), 0), 3, SIGNC[(i + 1) % #SIGNC + 1])
				stats.shops += 1
			end
		end
	end
	apartmentComplex(cols[3], R2)
	do -- kleine Tankstelle (c4) am Causeway Blvd
		local c = cols[4]
		local cx = (c[1] + c[2]) / 2
		Kit.plaza(B, "Lot_GasStation2", c[1], R2[1], c[2], R2[2], Color3.fromRGB(214, 206, 190))
		Kit.gasStation(B, "GasStation_BayFuel_Causeway", CFrame.lookAt(Vector3.new(cx, 0, -71), Vector3.new(cx, 0, -200)), {
			large = false, brand = "BAY FUEL", brandColor = Color3.fromRGB(40, 140, 220), shopName = "BAY MART", y = Y + 0.2,
			prices = { "REGULAR 3.45", "MIDGRADE 3.75", "PREMIUM 4.05", "DIESEL 3.95" },
		})
		for _, x in ipairs({ cx - 60, cx + 60 }) do
			Kit.driveway(P, Vector3.new(x, 0.2, -165), Vector3.new(0, 0, -1), 24)
		end
		Kit.parkingLot(B, "GasStation2_RearParking", c[1] + 10, R2[1] + 170, c[2] - 10, R2[2] - 10, Y)
		Kit.lotLight(P, Vector3.new(cx, Y, (R2[1] + 170 + R2[2]) / 2))
	end
	apartmentComplex(cols[5], R2)
	officePark(cols[6], R2, true)
	task.wait()

	-- R3 / R4: Gewerbe ----------------------------------------------------------------
	workshopRow(cols[1], R3)
	officePark(cols[2], R3, false)
	do -- Autohaus
		local c = cols[3]
		Kit.plaza(B, "Lot_Dealership", c[1], R3[1], c[2], R3[2], Color3.fromRGB(214, 206, 190))
		local m, H = Kit.midrise(B, "SawgrassMotors", Vector3.new((c[1] + c[2]) / 2, Y, R3[1] + 70), 260, 90, 2, {
			color = Color3.fromRGB(240, 240, 240), glass = Color3.fromRGB(50, 80, 100), floorH = 16, sign = "SAWGRASS MOTORS", signColor = Color3.fromRGB(40, 120, 220), rot = math.pi,
		})
		local _ = H
		m:SetAttribute("Interactable", "Dealership")
		Kit.parkingLot(B, "Dealership_DisplayLot", c[1] + 10, R3[1] + 140, c[2] - 10, R3[2] - 10, Y)
		local oldMk = workspace.Map.ServiceSites:FindFirstChild("Dealership_Showroom")
		if oldMk then
			oldMk:Destroy()
		end
		Kit.tagMarker(workspace.Map.ServiceSites, "Dealership_Showroom", CFrame.new((c[1] + c[2]) / 2, Y + 1, R3[1] + 130), "ShopEntrance", { Shop = "Dealership" })
	end
	selfStorage(cols[4], R3)
	officePark(cols[5], R3, false)
	workshopRow(cols[6], R3)
	workshopRow(cols[3], R4)
	workshopRow(cols[4], R4)
	workshopRow(cols[5], R4)
	workshopRow(cols[6], R4)

	local n = 0
	for _, d in ipairs(dist:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return string.format("Haeuser %d, Apartmenthaeuser %d, Laeden/Restaurants %d, Bueros %d, Gewerbe %d, Parts %d",
		stats.houses, stats.apartments, stats.shops, stats.offices, stats.workshops, n)
end
