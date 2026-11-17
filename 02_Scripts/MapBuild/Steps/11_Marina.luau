-- Schritt 11: Bayfront Marina in der Palmetto Bay (Z -2560 .. -1450, X 1000 .. 1320).
-- Schwimmstege mit Luxusyachten und Motorbooten, Zugangsrampen von der Uferpromenade,
-- "Marina Village" auf einer Plattform ueber dem Wasser mit Restaurants, Cafes und Yachtclub.
return function(Kit)
	local C, M = Kit.C, Enum.Material
	local dist = Kit.folder(workspace.Map.Districts, "Marina")
	local B = Kit.folder(dist, "Buildings")
	local P = Kit.folder(dist, "Props")
	B:ClearAllChildren()
	P:ClearAllChildren()
	local rng = Random.new(1450)
	local WATER = -8
	local DOCK_TOP = -5
	local WOOD = Color3.fromRGB(176, 140, 102)
	local CYL = Enum.PartType.Cylinder
	local UP = CFrame.Angles(0, 0, math.rad(90))

	local docks = Kit.model(P, "Docks")
	local function piling(x, z, top)
		Kit.part(docks, "Piling", Vector3.new(top + 22, 1.4, 1.4), CFrame.new(x, (top - 22) / 2, z) * UP, Color3.fromRGB(120, 100, 80), M.Wood, { shape = CYL })
	end

	-- Hauptsteg parallel zur Kaimauer
	Kit.part(docks, "MainDock", Vector3.new(12, 1.2, 900), CFrame.new(1016, DOCK_TOP - 0.6, -1900), WOOD, M.WoodPlanks)
	for z = -2340, -1460, 60 do
		piling(1010, z, DOCK_TOP + 2)
		piling(1022, z, DOCK_TOP + 2)
	end
	-- Rampen von der Promenade (Y 0.6) auf den Steg
	for _, z in ipairs({ -2200, -1900, -1600 }) do
		local p0, p1 = Vector3.new(999, 0.6, z), Vector3.new(1012, DOCK_TOP, z)
		local mid = (p0 + p1) / 2
		Kit.part(docks, "Gangway", Vector3.new(6, 0.6, (p1 - p0).Magnitude), CFrame.lookAt(mid, p1), Color3.fromRGB(200, 200, 196), M.DiamondPlate)
	end

	-- Fingerstege mit Booten
	local boats = Kit.model(P, "Boats")
	local STRIPES = { Color3.fromRGB(30, 50, 90), Color3.fromRGB(20, 20, 24), Color3.fromRGB(150, 120, 70), Color3.fromRGB(40, 110, 140) }
	local yachts, small = 0, 0
	for _, pz in ipairs({ -2250, -2050, -1850, -1650 }) do
		Kit.part(docks, "FingerDock", Vector3.new(280, 1.2, 8), CFrame.new(1162, DOCK_TOP - 0.6, pz), WOOD, M.WoodPlanks)
		for x = 1040, 1300, 52 do
			piling(x, pz - 4, DOCK_TOP + 2)
			piling(x, pz + 4, DOCK_TOP + 2)
		end
		Kit.part(docks, "DockLight", Vector3.new(1, 1, 1), CFrame.new(1300, DOCK_TOP + 3, pz), Color3.fromRGB(255, 220, 160), M.Neon, { decor = true })
		for _, side in ipairs({ -1, 1 }) do
			local x = 1060
			while x < 1290 do
				local big = rng:NextNumber() < 0.55
				local L = big and rng:NextInteger(54, 84) or rng:NextInteger(20, 30)
				local cx = x + L / 2
				if cx + L / 2 > 1305 then
					break
				end
				local zc = pz + side * (4 + (big and L * 0.22 or L * 0.32) / 2 + 3)
				local cf = CFrame.lookAt(Vector3.new(cx, WATER, zc), Vector3.new(cx + 1, WATER, zc))
				if big then
					yachts += 1
					Kit.yacht(boats, "Yacht_" .. yachts, cf, L, { stripe = STRIPES[rng:NextInteger(1, #STRIPES)] })
				else
					small += 1
					Kit.motorboat(boats, "Motorboat_" .. small, cf * CFrame.new(0, 1, 0), L, STRIPES[rng:NextInteger(1, #STRIPES)])
				end
				x += L + 10
			end
		end
		task.wait()
	end

	-- Marina Village: Plattform ueber dem Wasser am Nordende
	local deck = Kit.model(P, "VillageDeck")
	local X0, X1, Z0, Z1 = 1002, 1130, -2560, -2380
	Kit.part(deck, "Deck", Vector3.new(X1 - X0, 1.2, Z1 - Z0), CFrame.new((X0 + X1) / 2, 0, (Z0 + Z1) / 2), WOOD, M.WoodPlanks)
	for x = X0 + 8, X1 - 8, 30 do
		for z = Z0 + 8, Z1 - 8, 30 do
			Kit.part(deck, "Piling", Vector3.new(24, 1.8, 1.8), CFrame.new(x, -12, z) * UP, Color3.fromRGB(120, 100, 80), M.Wood, { shape = CYL })
		end
	end
	for _, s in ipairs({ { X1, (Z0 + Z1) / 2, 0.4, Z1 - Z0 }, { (X0 + X1) / 2, Z0, X1 - X0, 0.4 }, { (X0 + X1) / 2, Z1, X1 - X0, 0.4 } }) do
		Kit.part(deck, "GlassRail", Vector3.new(s[3], 3.6, s[4]), CFrame.new(s[1], 2.4, s[2]), Color3.fromRGB(180, 220, 230), M.Glass, { transp = 0.6 })
	end
	local function shop(name, z, sign, accent, neon)
		Kit.decoBuilding(B, name, Vector3.new(1040, 0.6, z), 60, 44, 2, {
			rot = -math.pi / 2, color = Color3.fromRGB(250, 248, 242), accent = accent, neon = neon, sign = sign,
		})
		Kit.outdoorSeating(P, CFrame.new(1100, 0.6, z) * CFrame.Angles(0, math.rad(90), 0), 3, accent)
	end
	shop("HarborCafe", -2530, "HARBOR CAFE", Color3.fromRGB(60, 160, 180), Color3.fromRGB(60, 230, 255))
	shop("MarinaGrill", -2470, "MARINA GRILL", Color3.fromRGB(200, 90, 70), Color3.fromRGB(255, 150, 60))
	shop("YachtClub", -2410, "BAYFRONT YACHT CLUB", Color3.fromRGB(30, 50, 90), Color3.fromRGB(255, 215, 110))
	for z = Z0 + 20, Z1 - 20, 40 do
		Kit.palm(P, Vector3.new(1124, 0.6, z), 22)
	end

	local n = 0
	for _, d in ipairs(dist:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return string.format("Marina: %d Yachten, %d Motorboote, %d Parts", yachts, small, n)
end
