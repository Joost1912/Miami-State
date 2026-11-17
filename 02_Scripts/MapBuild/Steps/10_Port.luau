-- Schritt 10: Port Meridian – Containerhafen suedlich der Port St (Z 1036 .. 2600, X -284 .. 1000).
-- Vorzone (Z 1050..1200): Hafenbehoerde, LKW-Parkplatz, Zoll. Sicherheitstor am Ende der Palm Ave.
-- Terminal (Z 1200..2600): Kai mit Containerbruecken, zwei Frachtschiffe, Containerlager mit Portalkranen,
-- Lagerhallen entlang Frontage St, Flutlichtmasten, Zaun.
return function(Kit)
	local C, M = Kit.C, Enum.Material
	local dist = workspace.Map.Districts.PortMeridian
	local B, P = dist.Buildings, dist.Props
	B:ClearAllChildren()
	P:ClearAllChildren()
	local rng = Random.new(1200)
	local YARD = Color3.fromRGB(118, 116, 112)
	local Y = Kit.SURFACE_Y

	local function slab(name, x0, z0, x1, z1, col, mat)
		return Kit.part(B, name, Vector3.new(x1 - x0, 2, z1 - z0), CFrame.new((x0 + x1) / 2, Y - 1, (z0 + z1) / 2), col or YARD, mat or M.Asphalt)
	end

	-- Flaechen (Korridor der Palm Ave X 444..516 bis Z 1200 bleibt frei)
	slab("Yard_PreGateWest", -284, 1036, 444, 1200)
	slab("Yard_PreGateEast", 516, 1036, 998, 1200)
	slab("Yard_Terminal", -284, 1200, 998, 2600)
	slab("Quay_Apron", 900, 1200, 998, 2600, Color3.fromRGB(176, 172, 164), M.Concrete)

	-- Kaimauer mit Pollern und Fendern
	local quay = Kit.model(P, "Quay")
	Kit.part(quay, "QuayWall", Vector3.new(4, 14, 1564), CFrame.new(1000, -6.6, 1818), Color3.fromRGB(170, 166, 158), M.Concrete)
	for z = 1060, 2580, 40 do
		Kit.part(quay, "Bollard", Vector3.new(2.4, 2.2, 2.2), CFrame.new(995, Y + 1.2, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 40, 44), M.Metal, { shape = Enum.PartType.Cylinder })
		Kit.part(quay, "Fender", Vector3.new(1.6, 6, 6), CFrame.new(1002.6, -3, z), Color3.fromRGB(30, 30, 32), M.Rubber)
	end
	-- Kantenmarkierung
	Kit.part(quay, "EdgeLine", Vector3.new(1, 0.06, 1400), CFrame.new(992, Y + 0.03, 1900), Color3.fromRGB(240, 200, 40), M.SmoothPlastic, { decor = true })
	task.wait()

	-- Zaun (Terminal-Sicherheitsbereich)
	local fence = Kit.model(P, "SecurityFence")
	local function fenceLine(p0, p1)
		local len = (p1 - p0).Magnitude
		local mid = (p0 + p1) / 2 + Vector3.new(0, 6 + Y, 0)
		Kit.part(fence, "Mesh", Vector3.new(0.3, 12, len), CFrame.lookAt(mid, mid + (p1 - p0).Unit), Color3.fromRGB(150, 156, 160), M.Metal, { transp = 0.55 })
		local n = math.floor(len / 40)
		for i = 0, n do
			local p = p0:Lerp(p1, i / math.max(n, 1))
			Kit.part(fence, "Post", Vector3.new(0.6, 13, 0.6), CFrame.new(p + Vector3.new(0, 6.5 + Y, 0)), Color3.fromRGB(110, 114, 118), M.Metal, { noShadow = true })
		end
	end
	fenceLine(Vector3.new(-282, 0, 1200), Vector3.new(444, 0, 1200))
	fenceLine(Vector3.new(516, 0, 1200), Vector3.new(900, 0, 1200))
	fenceLine(Vector3.new(-282, 0, 1200), Vector3.new(-282, 0, 2598))
	fenceLine(Vector3.new(-282, 0, 2598), Vector3.new(998, 0, 2598))

	-- Sicherheitstor an der Palm Ave
	do
		local g = Kit.model(B, "TerminalGate")
		Kit.part(g, "Booth", Vector3.new(10, 10, 12), CFrame.new(530, Y + 5, 1196), Color3.fromRGB(236, 236, 232), M.Concrete)
		Kit.part(g, "BoothGlass", Vector3.new(10.4, 4, 12.4), CFrame.new(530, Y + 6.5, 1196), Color3.fromRGB(40, 60, 70), M.Glass, { decor = true })
		Kit.part(g, "Canopy", Vector3.new(90, 2, 30), CFrame.new(480, Y + 20, 1196), Color3.fromRGB(236, 236, 232), M.Metal)
		for _, x in ipairs({ 438, 522 }) do
			Kit.part(g, "CanopyPost", Vector3.new(2, 19, 2), CFrame.new(x, Y + 9.5, 1196), Color3.fromRGB(110, 114, 118), M.Metal)
		end
		for _, b in ipairs({ { 468, 1190 }, { 492, 1202 } }) do
			Kit.part(g, "BoomArm", Vector3.new(22, 0.8, 0.8), CFrame.new(b[1], Y + 4, b[2]), Color3.fromRGB(230, 40, 40), M.SmoothPlastic)
			Kit.part(g, "BoomArmStripe", Vector3.new(6, 0.85, 0.85), CFrame.new(b[1], Y + 4, b[2]), Color3.new(1, 1, 1), M.SmoothPlastic, { decor = true })
		end
		Kit.sign(g, CFrame.new(480, Y + 24.5, 1181) * CFrame.Angles(0, math.pi, 0), Vector3.new(80, 6, 0.6), "PORT MERIDIAN - SECURITY CHECKPOINT", Color3.new(1, 1, 1), Color3.fromRGB(20, 50, 90))
		local mk = Kit.part(workspace.Map.ServiceSites, "PortGate_Checkpoint", Vector3.new(4, 1, 4), CFrame.new(480, Y + 1, 1196), Color3.new(1, 1, 1), M.SmoothPlastic, { ghost = true })
		mk.Transparency = 1
		mk:SetAttribute("Service", "PortSecurity")
	end

	-- Vorzone: Hafenbehoerde, Zoll, LKW-Parkplatz
	Kit.midrise(B, "PortAuthority", Vector3.new(-150, Y, 1110), 220, 80, 4, {
		color = Color3.fromRGB(232, 232, 228), glass = Color3.fromRGB(40, 70, 100), sign = "PORT MERIDIAN AUTHORITY", signColor = Color3.fromRGB(40, 120, 200),
	})
	Kit.parkingLot(B, "TruckParking", 80, 1046, 436, 1192)
	Kit.midrise(B, "CustomsOffice", Vector3.new(740, Y, 1118), 200, 70, 3, {
		color = Color3.fromRGB(226, 224, 216), glass = Color3.fromRGB(40, 60, 80), sign = "CUSTOMS & BORDER", signColor = Color3.fromRGB(255, 255, 255),
	})
	task.wait()

	-- LKW (Sattelzug) als Requisite. cf: Mitte, LookVector = Fahrtrichtung
	local function semi(parent, cf, col)
		local m = Kit.model(parent, "SemiTruck")
		Kit.part(m, "Cab", Vector3.new(9, 11, 12), cf * CFrame.new(0, 6.5, -24), col, M.Metal)
		Kit.part(m, "CabGlass", Vector3.new(9.2, 3.5, 2), cf * CFrame.new(0, 9.5, -29.2), Color3.fromRGB(30, 40, 50), M.Glass, { decor = true })
		Kit.part(m, "Trailer", Vector3.new(9, 12, 44), cf * CFrame.new(0, 8, 6), Kit.CONTAINER_COLORS[rng:NextInteger(1, #Kit.CONTAINER_COLORS)], M.Metal)
		Kit.part(m, "Chassis", Vector3.new(8, 2, 58), cf * CFrame.new(0, 2, -4), Color3.fromRGB(30, 30, 32), M.Metal)
		return m
	end
	local TRUCK_COL = { Color3.fromRGB(200, 30, 30), Color3.fromRGB(240, 240, 236), Color3.fromRGB(30, 70, 150), Color3.fromRGB(30, 30, 34) }
	for i = 0, 5 do
		semi(P, CFrame.lookAt(Vector3.new(110 + i * 54, Y, 1150), Vector3.new(110 + i * 54, Y, 1100)), TRUCK_COL[i % #TRUCK_COL + 1])
	end

	-- Lagerhallen entlang der Frontage St (Laderampen zeigen ins Terminal nach Osten)
	local WH = {
		{ "MERIDIAN LOGISTICS", Color3.fromRGB(30, 90, 160) }, { "BAYLINE FREIGHT", Color3.fromRGB(200, 60, 40) },
		{ "SUNCOAST COLD STORAGE", Color3.fromRGB(40, 150, 140) }, { "ATLANTIC CARGO", Color3.fromRGB(230, 140, 30) },
	}
	for i, z in ipairs({ 1360, 1700, 2040, 2380 }) do
		Kit.warehouse(B, "Warehouse_" .. i, Vector3.new(-200, Y, z), 280, 120, 44, { rot = -math.pi / 2, sign = WH[i][1], accent = WH[i][2] })
		semi(P, CFrame.lookAt(Vector3.new(-110, Y, z - 60), Vector3.new(-60, Y, z - 60)), TRUCK_COL[i % #TRUCK_COL + 1])
		semi(P, CFrame.lookAt(Vector3.new(-110, Y, z + 40), Vector3.new(-60, Y, z + 40)), TRUCK_COL[(i + 1) % #TRUCK_COL + 1])
	end
	task.wait()

	-- Containerlager (Bloecke 5 x 3 Container, 1-4 hoch) mit Portalkranen
	local stacks = Kit.model(P, "ContainerYard")
	local bi = 0
	for z = 1250, 2520, 90 do
		for _, x in ipairs({ 150, 330, 510, 690 }) do
			bi += 1
			Kit.containerBlock(stacks, "Stack_" .. bi, CFrame.new(x - 42, Y, z - 9), 5, 3, 4, rng)
			if bi % 5 == 0 then
				Kit.rtgCrane(stacks, "RTG_" .. bi, CFrame.new(x, Y, z) * CFrame.Angles(0, math.rad(90), 0), 46)
			end
		end
		task.wait()
	end

	-- Containerbruecken am Kai
	local cranes = Kit.model(P, "STSCranes")
	local CRANE_COL = { Color3.fromRGB(200, 40, 36), Color3.fromRGB(30, 90, 170) }
	for i, z in ipairs({ 1360, 1560, 1800, 2060, 2300, 2500 }) do
		Kit.stsCrane(cranes, "STS_" .. i, CFrame.lookAt(Vector3.new(960, Y, z), Vector3.new(961, Y, z)), { color = CRANE_COL[(i <= 3) and 1 or 2] })
	end
	task.wait()

	-- Frachtschiffe an der Pier (Wasserlinie Y -8, Rumpfmitte so dass Freibord ~14)
	local ships = Kit.model(P, "Ships")
	Kit.cargoShip(ships, "MV_Atlantic_Star", CFrame.lookAt(Vector3.new(1038, 4, 1600), Vector3.new(1038, 4, 1500)), 420, 64, {
		seed = 4, name = "ATLANTIC STAR", hull = Color3.fromRGB(28, 40, 66), funnel = Color3.fromRGB(230, 120, 30),
	})
	Kit.cargoShip(ships, "MV_Coral_Trader", CFrame.lookAt(Vector3.new(1038, 4, 2290), Vector3.new(1038, 4, 2400)), 360, 60, {
		seed = 8, name = "CORAL TRADER", hull = Color3.fromRGB(120, 30, 30), funnel = Color3.fromRGB(30, 30, 30),
	})

	-- Flutlichtmasten
	for _, p in ipairs({ { 60, 1400 }, { 420, 1400 }, { 780, 1400 }, { 60, 2000 }, { 420, 2000 }, { 780, 2000 }, { 240, 2450 }, { 600, 2450 } }) do
		local mast = Kit.model(P, "FloodMast")
		Kit.part(mast, "Pole", Vector3.new(70, 2.2, 2.2), CFrame.new(p[1], Y + 35, p[2]) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 154, 158), M.Metal, { shape = Enum.PartType.Cylinder })
		local head = Kit.part(mast, "Head", Vector3.new(10, 2, 10), CFrame.new(p[1], Y + 71, p[2]), Color3.fromRGB(255, 240, 210), M.Neon, { decor = true })
		local l = Instance.new("SpotLight")
		l.Face = Enum.NormalId.Bottom
		l.Range = 120
		l.Angle = 120
		l.Brightness = 2
		l.Shadows = false
		l.Parent = head
		game:GetService("CollectionService"):AddTag(head, "StreetLamp")
	end

	local n = 0
	for _, d in ipairs(dist:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return string.format("Port Meridian: %d Containerbloecke, %d Parts", bi, n)
end
