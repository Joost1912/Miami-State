-- Schritt 7: Coconut Heights – Einfamilienhaeuser, Villen mit Pool, Park,
-- Tankstelle und Einkaufszeile am Coconut Blvd.
return function(Kit)
	local C, M = Kit.C, Enum.Material
	local dist = workspace.Map.Districts.CoconutHeights
	local B, P = dist.Buildings, dist.Props
	B:ClearAllChildren()
	P:ClearAllChildren()
	local rng = Random.new(77)
	local Y = 0

	local RES_HALF = Kit.totalWidth(Kit.SPECS.Residential) / 2 -- 23
	local LOT_W, LOT_D = 75, 150
	local SEGMENTS = { { -1877, -1336 }, { -1264, -723 } }
	local STREETS = { -1350, -1700, -2050, -2400 }

	local houses = 0
	for si, zs in ipairs(STREETS) do
		for _, side in ipairs({ -1, 1 }) do -- -1 = Nordseite, 1 = Suedseite
			for gi, seg in ipairs(SEGMENTS) do
				local isPark = (zs == -1700 and side == -1 and gi == 2)
				local zc = zs + side * (RES_HALF + LOT_D / 2)
				if isPark then
					local park = Kit.model(P, "HeightsPark")
					local x0, x1 = seg[1], seg[2]
					Kit.part(park, "Path", Vector3.new(x1 - x0 - 40, 0.3, 8), CFrame.new((x0 + x1) / 2, 0.15, zc), Color3.fromRGB(214, 204, 184), M.Pavement)
					Kit.part(park, "Path", Vector3.new(8, 0.3, LOT_D - 20), CFrame.new((x0 + x1) / 2, 0.15, zc), Color3.fromRGB(214, 204, 184), M.Pavement)
					for i = 0, 9 do
						Kit.palm(park, Vector3.new(x0 + 30 + i * ((x1 - x0 - 60) / 9), Y, zc + ((i % 2 == 0) and -45 or 45)))
					end
					local pg = Kit.model(park, "Playground")
					Kit.part(pg, "Sandpit", Vector3.new(40, 0.4, 30), CFrame.new(x1 - 70, 0.2, zc - 30), Color3.fromRGB(230, 214, 170), M.Sand)
					Kit.part(pg, "Slide", Vector3.new(4, 0.6, 16), CFrame.new(x1 - 70, 4, zc - 30) * CFrame.Angles(math.rad(30), 0, 0), Color3.fromRGB(255, 120, 60), M.Plastic)
					Kit.part(pg, "Tower", Vector3.new(6, 8, 6), CFrame.new(x1 - 70, 4, zc - 41), Color3.fromRGB(80, 170, 230), M.Plastic)
					for i = 0, 3 do
						Kit.part(park, "Bench", Vector3.new(8, 1.6, 2.4), CFrame.new(x0 + 80 + i * 110, 0.8, zc + 8), Color3.fromRGB(150, 110, 76), M.WoodPlanks)
					end
				else
					local count = math.floor((seg[2] - seg[1]) / LOT_W)
					local start = (seg[1] + seg[2]) / 2 - (count - 1) * LOT_W / 2
					for i = 0, count - 1 do
						houses += 1
						local x = start + i * LOT_W
						local villa = (zs == -2400 and side == -1) or rng:NextNumber() < 0.12
						local cf = CFrame.lookAt(Vector3.new(x, Y, zc), Vector3.new(x, Y, zs))
						Kit.house(B, string.format("House_%03d", houses), cf, {
							seed = houses * 31 + si,
							lotW = LOT_W,
							lotD = LOT_D,
							villa = villa,
							palm = (houses % 2 == 0),
						})
					end
				end
				task.wait()
			end
		end
	end

	-- Coconut Blvd: Tankstelle und Einkaufszeile (zwischen Boulevard und erster Wohnreihe)
	local zFront = -1049 - 64 -- Mitte des Streifens nordlich des Boulevards
	do
		local gs = Kit.model(B, "GasStation_SunshineFuel")
		gs.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		local gx = -1600
		Kit.part(gs, "Apron", Vector3.new(160, 0.4, 110), CFrame.new(gx, 0.2, zFront), C.concrete, M.Concrete)
		Kit.part(gs, "Canopy", Vector3.new(80, 3, 46), CFrame.new(gx - 20, 18, zFront + 10), Color3.fromRGB(250, 250, 248), M.SmoothPlastic)
		Kit.part(gs, "CanopyStripe", Vector3.new(80.4, 1.2, 46.4), CFrame.new(gx - 20, 17, zFront + 10), Color3.fromRGB(255, 140, 40), M.Neon, { decor = true })
		for _, o in ipairs({ { -36, -6 }, { -4, -6 }, { -36, 26 }, { -4, 26 } }) do
			Kit.part(gs, "Pillar", Vector3.new(2, 16, 2), CFrame.new(gx + o[1], 8, zFront + o[2]), Color3.fromRGB(240, 240, 236), M.Metal)
			Kit.part(gs, "Pump", Vector3.new(3, 6, 6), CFrame.new(gx + o[1], 3, zFront + o[2] + 8), Color3.fromRGB(230, 60, 50), M.Plastic)
		end
		Kit.midrise(gs, "Store", Vector3.new(gx + 50, 0.4, zFront - 20), 50, 40, 1, {
			color = Color3.fromRGB(250, 246, 236), floorH = 16, sign = "SUNSHINE FUEL", signColor = Color3.fromRGB(255, 150, 40),
			rot = math.pi,
		})
		Kit.part(gs, "PriceSignPole", Vector3.new(2, 24, 2), CFrame.new(gx - 70, 12, zFront + 46), C.metal, M.Metal)
		Kit.sign(gs, CFrame.new(gx - 70, 26, zFront + 46) * CFrame.Angles(0, math.pi, 0), Vector3.new(16, 8, 1), "FUEL 3.49", Color3.fromRGB(255, 230, 120))
	end
	do
		local mx = -1000
		Kit.parkingLot(B, "StripMall_Parking", mx - 140, zFront - 10, mx + 140, zFront + 60)
		Kit.midrise(B, "StripMall_HeightsPlaza", Vector3.new(mx, 0, zFront - 38), 280, 40, 1, {
			color = Color3.fromRGB(242, 230, 212), floorH = 18, sign = "HEIGHTS PLAZA", signColor = Color3.fromRGB(60, 200, 210), rot = math.pi,
		})
	end

	local n = 0
	for _, d in ipairs(dist:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return string.format("Haeuser %d, Parts Coconut Heights %d", houses, n)
end
