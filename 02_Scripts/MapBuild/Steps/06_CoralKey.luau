-- Schritt 6: Coral Key – Hotelreihe am Ocean Avenue, Geschaefte, Apartments,
-- Strandpromenade, Strand mit Rettungstuermen, Sonnenschirmen und Beach Clubs.
return function(Kit)
	local C, M = Kit.C, Enum.Material
	local dist = workspace.Map.Districts.CoralKey
	local B, P = dist.Buildings, dist.Props
	B:ClearAllChildren()
	P:ClearAllChildren()
	local rng = Random.new(2026)

	local PASTEL = {
		Color3.fromRGB(250, 214, 200), Color3.fromRGB(206, 236, 226), Color3.fromRGB(252, 240, 206),
		Color3.fromRGB(232, 222, 248), Color3.fromRGB(246, 244, 238), Color3.fromRGB(255, 226, 226),
		Color3.fromRGB(210, 230, 250),
	}
	local ACCENT = {
		Color3.fromRGB(110, 205, 200), Color3.fromRGB(246, 150, 160), Color3.fromRGB(255, 196, 100),
		Color3.fromRGB(150, 180, 240), Color3.fromRGB(120, 210, 160),
	}
	local NEON = {
		Color3.fromRGB(255, 80, 180), Color3.fromRGB(60, 230, 255), Color3.fromRGB(180, 110, 255), Color3.fromRGB(255, 150, 60),
	}
	local NAMES = {
		"THE CORAL", "SEABREEZE", "FLAMINGO", "PALMS HOTEL", "AQUA", "SUNRISE", "BLUE WAVE", "LUNA",
		"SOL", "MARLIN", "PELICAN", "OCEANIA", "SANDS", "DOLPHIN", "LAGOON", "AZURE", "HARBOR LIGHT", "CABANA",
	}
	local function pick(t)
		return t[rng:NextInteger(1, #t)]
	end

	local CROSS = { -2500, -1400, -200, 1000, 2500 } -- Querstrassen (Freiraum lassen)
	local function nearCross(z, gap)
		for _, cz in ipairs(CROSS) do
			if math.abs(z - cz) < gap then
				return true
			end
		end
		return false
	end
	local LOT_Y = 0.6
	local FRONT_W, FRONT_E = -math.pi / 2, math.pi / 2 -- Vorderseite nach Osten / Westen

	-- Hotelreihe Ostseite (Front zur Ocean Ave, Rueckseite zum Strand)
	Kit.plaza(B, "Lot_HotelRow", 2349, -2560, 2520, 2560, Color3.fromRGB(226, 218, 200))
	local hotels, nameI = 0, 1
	local z = -2420
	while z <= 2420 do
		local w = rng:NextInteger(80, 104)
		if not nearCross(z, 70) then
			hotels += 1
			local x = 2404
			if hotels % 6 == 0 then
				-- moderner Glasturm zwischen den Art-Deco-Hotels
				Kit.tower(B, "CoralKey_HotelTower_" .. hotels, Vector3.new(x, LOT_Y, z), 80, 80, rng:NextInteger(170, 230), {
					glass = Color3.fromRGB(70, 130, 150), crown = pick(NEON), setback = false,
				})
			elseif z > 1750 and z < 2050 then
				Kit.parkingLot(B, "CoralKey_BeachParking", 2360, z - 60, 2510, z + 60)
			else
				Kit.decoBuilding(B, "CoralKey_Hotel_" .. hotels, Vector3.new(x, LOT_Y, z), w, 90, rng:NextInteger(4, 9), {
					rot = FRONT_W, color = pick(PASTEL), accent = pick(ACCENT), neon = pick(NEON), sign = NAMES[nameI],
				})
				nameI = nameI % #NAMES + 1
				-- Pool hinter dem Hotel
				Kit.part(P, "PoolDeck", Vector3.new(56, 0.4, w * 0.8), CFrame.new(2484, LOT_Y + 0.2, z), Color3.fromRGB(236, 230, 214), M.Limestone)
				Kit.part(P, "Pool", Vector3.new(34, 0.3, w * 0.5), CFrame.new(2484, LOT_Y + 0.45, z), Color3.fromRGB(70, 200, 230), M.Glass, { transp = 0.15, refl = 0.3, decor = true })
			end
		end
		z += w + 16
		if hotels % 4 == 0 then
			task.wait()
		end
	end

	-- Westseite: Geschaefte/Restaurants an der Ocean Ave, Apartments zur Bay Rd
	Kit.plaza(B, "Lot_WestBlocks", 1996, -2460, 2251, 2460, Color3.fromRGB(218, 210, 194))
	local shops, apts = 0, 0
	z = -2400
	while z <= 2400 do
		if not nearCross(z, 66) then
			shops += 1
			Kit.decoBuilding(B, "CoralKey_Shop_" .. shops, Vector3.new(2206, LOT_Y, z), 84, 66, rng:NextInteger(2, 3), {
				rot = FRONT_E, color = pick(PASTEL), accent = pick(ACCENT), neon = pick(NEON),
			})
			apts += 1
			Kit.midrise(B, "CoralKey_Apartments_" .. apts, Vector3.new(2050, LOT_Y, z), 84, 80, rng:NextInteger(5, 10), {
				rot = FRONT_W * -1, color = pick(PASTEL), glass = Color3.fromRGB(58, 92, 104), trim = Color3.fromRGB(250, 250, 248),
			})
		end
		z += 100
	end
	task.wait()

	-- Strandpromenade
	local prom = Kit.model(P, "BeachPromenade")
	Kit.part(prom, "Boardwalk", Vector3.new(40, 1, 5300), CFrame.new(2542, 0.1, 0), Color3.fromRGB(170, 132, 96), M.WoodPlanks)
	Kit.part(prom, "LowWall", Vector3.new(1.6, 2.4, 5300), CFrame.new(2562.8, 0.8, 0), Color3.fromRGB(246, 240, 228), M.Plaster)
	for zz = -2620, 2620, 52 do
		Kit.palm(prom, Vector3.new(2526, 0.6, zz))
	end
	for zz = -2560, 2560, 130 do
		Kit.streetLight(prom, CFrame.lookAt(Vector3.new(2558, 0.6, zz), Vector3.new(2548, 0.6, zz)))
	end
	task.wait()

	-- Strand: Rettungstuerme, Schirme, Liegen
	local beach = Kit.model(P, "Beach")
	local TOWER_COL = { Color3.fromRGB(255, 150, 170), Color3.fromRGB(120, 220, 210), Color3.fromRGB(255, 210, 110), Color3.fromRGB(170, 160, 255) }
	local ti = 0
	for zz = -2300, 2300, 460 do
		ti += 1
		local t = Kit.model(beach, "LifeguardTower_" .. ti)
		local base = Vector3.new(2700, 0, zz)
		for _, o in ipairs({ { -4, -4 }, { 4, -4 }, { -4, 4 }, { 4, 4 } }) do
			Kit.part(t, "Leg", Vector3.new(1, 10, 1), CFrame.new(base + Vector3.new(o[1], 5, o[2])), Color3.fromRGB(240, 240, 236), M.Wood)
		end
		Kit.part(t, "Floor", Vector3.new(14, 1, 14), CFrame.new(base + Vector3.new(0, 10.5, 0)), Color3.fromRGB(240, 240, 236), M.WoodPlanks)
		Kit.part(t, "Hut", Vector3.new(10, 8, 10), CFrame.new(base + Vector3.new(0, 15, 0)), TOWER_COL[(ti - 1) % #TOWER_COL + 1], M.Plaster)
		Kit.part(t, "Roof", Vector3.new(12, 1, 12), CFrame.new(base + Vector3.new(0, 19.5, 0)), Color3.fromRGB(240, 240, 236), M.Plaster)
		Kit.part(t, "Ramp", Vector3.new(4, 0.6, 16), CFrame.new(base + Vector3.new(-12, 5.2, 0)) * CFrame.Angles(0, math.rad(90), math.rad(36)), Color3.fromRGB(240, 240, 236), M.WoodPlanks)
	end
	local UMB = { Color3.fromRGB(255, 90, 110), Color3.fromRGB(60, 200, 220), Color3.fromRGB(255, 200, 70), Color3.fromRGB(250, 250, 250) }
	for zz = -2200, 2200, 240 do
		if not nearCross(zz, 40) then
			for i = 0, 5 do
				local p = Vector3.new(2610 + (i % 3) * 22, 0, zz + (i // 3) * 26)
				local u = Kit.model(beach, "Umbrella")
				Kit.part(u, "Pole", Vector3.new(9, 0.4, 0.4), CFrame.new(p + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.new(1, 1, 1), M.Metal, { shape = Enum.PartType.Cylinder, decor = true })
				Kit.part(u, "Canopy", Vector3.new(0.6, 12, 12), CFrame.new(p + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, math.rad(90)), UMB[(i % #UMB) + 1], M.Fabric, { shape = Enum.PartType.Cylinder, decor = true })
				Kit.part(u, "Lounger", Vector3.new(3, 0.8, 8), CFrame.new(p + Vector3.new(4, 0.6, 2)) * CFrame.Angles(math.rad(-6), 0, 0), Color3.new(1, 1, 1), M.Plastic)
			end
		end
	end
	task.wait()

	-- Beach Clubs
	for i, zz in ipairs({ -800, 1600 }) do
		local club = Kit.model(P, "BeachClub_" .. i)
		Kit.part(club, "Deck", Vector3.new(70, 1.2, 120), CFrame.new(2600, 0.4, zz), Color3.fromRGB(176, 136, 98), M.WoodPlanks)
		Kit.part(club, "Bar", Vector3.new(14, 5, 40), CFrame.new(2582, 3.5, zz), Color3.fromRGB(250, 248, 240), M.Plaster)
		Kit.part(club, "Roof", Vector3.new(26, 1, 56), CFrame.new(2582, 14, zz), Color3.fromRGB(200, 170, 120), M.Fabric)
		for _, o in ipairs({ { -10, -24 }, { 10, -24 }, { -10, 24 }, { 10, 24 } }) do
			Kit.part(club, "Post", Vector3.new(1, 13, 1), CFrame.new(2582 + o[1], 7, zz + o[2]), Color3.fromRGB(150, 110, 80), M.Wood)
		end
		Kit.sign(club, CFrame.new(2582, 17.5, zz) * CFrame.Angles(0, -math.pi / 2, 0), Vector3.new(36, 6, 1), i == 1 and "SUNSET BEACH CLUB" or "CORAL BEACH CLUB", NEON[i])
		Kit.palm(club, Vector3.new(2620, 1, zz - 50))
		Kit.palm(club, Vector3.new(2620, 1, zz + 50))
	end

	local n = 0
	for _, d in ipairs(dist:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return string.format("Hotels %d, Geschaefte %d, Apartments %d, Parts Coral Key %d", hotels, shops, apts, n)
end
