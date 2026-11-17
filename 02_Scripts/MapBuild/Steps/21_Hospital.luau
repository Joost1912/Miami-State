-- Schritt 21: Bayfront Medical Center mit begehbarem Erdgeschoss (ersetzt den bisherigen Vollkoerper an gleicher Stelle).
-- Grundriss Erdgeschoss (Welt): X -236..-17, Z -885..-765, Front nach Sueden zur Rettungswagen-Zufahrt (Z -711..-641)
--   Vorderzone Z -805..-765: Ambulanzgarage (X -236..-196) | Notaufnahme (-196..-136) | Empfang/Warten (-136..-66) | Rettungswache (-66..-17)
--   Flur Z -815..-805 | Hinterzone Z -885..-815: 4 Behandlungsraeume (-236..-136) | 4 Patientenzimmer (-136..-56) | Stationsbuero (-56..-17)
-- Darueber: Bettenturm (6 Geschosse) mit Hubschrauberlandeplatz.
return function(Kit)
	local M = Enum.Material
	local old = workspace.Map:FindFirstChild("BayfrontMedical", true)
	if old and old:IsA("Model") and old.Parent.Name == "Buildings" then
		old:Destroy()
	end
	local root = workspace.Map:FindFirstChild("Hospital")
	if root then
		root:Destroy()
	end
	root = Kit.folder(workspace.Map, "Hospital")
	local S, I, G = Kit.model(root, "Building"), Kit.model(root, "Interior"), Kit.model(root, "Gameplay")
	local Y, FL, H = 0.6, 0.8, 20
	local X0, X1, Z0, Z1 = -236, -17, -885, -765
	local WHITE = Color3.fromRGB(246, 246, 244)
	local RED = Color3.fromRGB(220, 30, 40)
	local TEAL = Color3.fromRGB(40, 150, 160)
	local GLASS = Color3.fromRGB(60, 100, 120)
	local DARK = Color3.fromRGB(32, 34, 40)
	local IK = Kit.interior({ S = S, I = I, G = G, FL = FL, H = H, wall = Color3.fromRGB(236, 240, 242), faction = "EMS" })
	local P, wallX, wallZ = IK.P, IK.wallX, IK.wallZ

	-- Boden/Decke --------------------------------------------------------------------------------------
	P(S, "Floor", Vector3.new(X1 - X0, 0.4, Z1 - Z0), Vector3.new((X0 + X1) / 2, Y, (Z0 + Z1) / 2), Color3.fromRGB(226, 230, 232), M.Marble)
	P(S, "GarageFloor", Vector3.new(40, 0.45, 40), Vector3.new(-216, Y + 0.02, -785), Color3.fromRGB(120, 122, 128), M.Concrete)
	P(S, "CorridorStripe", Vector3.new(X1 - X0 - 2, 0.05, 1.2), Vector3.new((X0 + X1) / 2, Y + 0.23, -810), TEAL, M.SmoothPlastic, { decor = true })
	P(S, "Ceiling", Vector3.new(X1 - X0, 1, Z1 - Z0), Vector3.new((X0 + X1) / 2, FL + H + 0.5, (Z0 + Z1) / 2), Color3.fromRGB(244, 244, 242), M.SmoothPlastic)

	-- Bettenturm darueber (gleiche Optik wie zuvor) + Landeplatz
	local tower, TH = Kit.midrise(S, "BedTower", Vector3.new((X0 + X1) / 2, FL + H + 1, (Z0 + Z1) / 2), X1 - X0, Z1 - Z0, 6, {
		color = WHITE, glass = GLASS, sign = "BAYFRONT MEDICAL CENTER", signColor = RED,
	})
	local top = FL + H + 1 + TH + 1.6
	local cx, cz = -126.5, -824.8
	P(tower, "Helipad", Vector3.new(1, 60, 60), CFrame.new(cx + 40, top + 0.5, cz) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 62, 66), M.Concrete, { shape = Enum.PartType.Cylinder })
	P(tower, "HelipadH", Vector3.new(4, 0.1, 22), Vector3.new(cx + 32, top + 1.05, cz), Color3.new(1, 1, 1), M.SmoothPlastic, { decor = true })
	P(tower, "HelipadH", Vector3.new(4, 0.1, 22), Vector3.new(cx + 48, top + 1.05, cz), Color3.new(1, 1, 1), M.SmoothPlastic, { decor = true })
	P(tower, "HelipadH", Vector3.new(12, 0.1, 4), Vector3.new(cx + 40, top + 1.05, cz), Color3.new(1, 1, 1), M.SmoothPlastic, { decor = true })
	P(S, "PodiumBand", Vector3.new(X1 - X0 + 2, 1.4, Z1 - Z0 + 2), Vector3.new((X0 + X1) / 2, FL + H + 0.7, (Z0 + Z1) / 2), TEAL, M.SmoothPlastic, { decor = true })

	-- Aussenwaende ---------------------------------------------------------------------------------------
	wallX(Z0, X0, X1, nil, WHITE, 1.4, true)
	wallZ(X0, Z0, Z1, nil, WHITE, 1.4, true)
	wallZ(X1, Z0, Z1, nil, WHITE, 1.4, true)
	-- Front: Garagentor (x -216, 30 breit), Notaufnahme (x -166, 16), Haupteingang (x -101, 14)
	wallX(Z1, X0, X1, { { -216, 30, 17 }, { -166, 16 }, { -101, 14 } }, WHITE, 1.4, true)
	for _, x in ipairs({ -140, -124, -78, -56, -38 }) do
		P(S, "Window", Vector3.new(12, 9, 0.4), Vector3.new(x, FL + 9, Z1 + 0.75), GLASS, M.Glass, { decor = true, refl = 0.25 })
	end
	for _, z in ipairs({ -870, -850, -830 }) do
		for _, x in ipairs({ X0 - 0.75, X1 + 0.75 }) do
			P(S, "SideWindow", Vector3.new(0.4, 8, 12), Vector3.new(x, FL + 9, z), GLASS, M.Glass, { decor = true, refl = 0.25 })
		end
	end
	-- Notaufnahme-Vordach und Schilder
	P(S, "ER_Canopy", Vector3.new(80, 2, 34), Vector3.new(-166.5, Y + 16, -748), Color3.fromRGB(236, 236, 232), M.Concrete)
	for _, x in ipairs({ -200, -133 }) do
		P(S, "CanopyPillar", Vector3.new(2, 15, 2), Vector3.new(x, Y + 7.5, -733), Color3.fromRGB(236, 236, 232), M.Concrete)
	end
	local cl = P(S, "CanopyLight", Vector3.new(76, 0.2, 30), Vector3.new(-166.5, Y + 14.9, -748), Color3.fromRGB(255, 252, 240), M.Neon, { decor = true })
	local cll = Instance.new("SurfaceLight")
	cll.Face, cll.Range, cll.Brightness = Enum.NormalId.Bottom, 18, 1.2
	cll.Parent = cl
	Kit.sign(S, CFrame.new(-166.5, Y + 20, -731) * CFrame.Angles(0, math.pi, 0), Vector3.new(40, 6, 1), "EMERGENCY", RED)
	Kit.sign(S, CFrame.new(-101, FL + 16, Z1 + 1.2) * CFrame.Angles(0, math.pi, 0), Vector3.new(24, 2.6, 0.3), "MAIN ENTRANCE", Color3.new(1, 1, 1), TEAL)
	Kit.sign(S, CFrame.new(-216, FL + 18.4, Z1 + 1.2) * CFrame.Angles(0, math.pi, 0), Vector3.new(26, 2.2, 0.3), "AMBULANCE ONLY", Color3.fromRGB(255, 220, 90), DARK)
	P(S, "EntranceCanopy", Vector3.new(24, 1, 12), Vector3.new(-101, FL + 15, Z1 + 6), TEAL, M.Metal)

	-- Innenwaende ------------------------------------------------------------------------------------------
	wallX(-805, X0, X1, { { -176, 10 }, { -101, 12 }, { -41, 8 } }) -- Vorderzone | Flur
	wallX(-815, X0, X1, { { -224, 8 }, { -199, 8 }, { -174, 8 }, { -149, 8 }, { -126, 6 }, { -106, 6 }, { -86, 6 }, { -66, 6 }, { -36, 8 } }) -- Flur | Hinterzone
	wallZ(-196, -805, Z1, { { -795, 8 } }) -- Garage | Notaufnahme
	wallZ(-136, -805, Z1, { { -785, 12 } }) -- Notaufnahme | Empfang (offen)
	wallZ(-66, -805, Z1, { { -785, 8 } }) -- Empfang | Rettungswache
	for _, x in ipairs({ -211, -186, -161 }) do
		wallZ(x, Z0, -815, {}) -- Behandlungsraeume
	end
	wallZ(-136, Z0, -815, {})
	for _, x in ipairs({ -116, -96, -76 }) do
		wallZ(x, Z0, -815, {}) -- Patientenzimmer
	end
	wallZ(-56, Z0, -815, {})

	-- Tueren
	IK.doorZ("Garage Door", -196, -795, 8, true)
	IK.doorZ("EMS Station Door", -66, -785, 8, true, Color3.fromRGB(40, 110, 200))
	IK.doorX("Staff Office Door", -36, -815, 8, true)

	-- Krankenhausbett: Gestell + Matratze + Kissen + Markierung fuer Behandlung
	local nBeds = 0
	local function bed(pos, facing)
		local cf = CFrame.lookAt(pos, pos + facing)
		P(I, "BedFrame", Vector3.new(3.6, 1.8, 7.6), cf * CFrame.new(0, 0.9, 0), Color3.fromRGB(200, 204, 210), M.Metal)
		P(I, "Mattress", Vector3.new(3.4, 0.6, 7.2), cf * CFrame.new(0, 2.1, 0), Color3.fromRGB(236, 240, 246), M.Fabric)
		P(I, "Pillow", Vector3.new(2.6, 0.5, 1.4), cf * CFrame.new(0, 2.6, 2.8), WHITE, M.Fabric, { decor = true })
		P(I, "Blanket", Vector3.new(3.5, 0.15, 3.6), cf * CFrame.new(0, 2.45, -1.5), TEAL, M.Fabric, { decor = true })
		P(I, "Monitor", Vector3.new(1.8, 1.4, 0.3), cf * CFrame.new(2.6, 5.2, 3.2), DARK, M.SmoothPlastic, { decor = true })
		P(I, "MonitorScreen", Vector3.new(1.5, 1.1, 0.1), cf * CFrame.new(2.6, 5.2, 3.0), Color3.fromRGB(80, 255, 140), M.Neon, { decor = true })
		P(I, "IVStand", Vector3.new(0.2, 6, 0.2), cf * CFrame.new(-2.4, 3, 2.6), Color3.fromRGB(200, 204, 210), M.Metal, { decor = true })
		IK.marker("HospitalBed", cf * CFrame.new(0, 3, 0), "HospitalBed")
		nBeds += 1
	end

	-- Ambulanzgarage ----------------------------------------------------------------------------------------
	for i, x in ipairs({ -226, -206 }) do
		IK.marker("EMSGarageSpawn_" .. i, CFrame.lookAt(Vector3.new(x, FL, -788), Vector3.new(x, FL, -700)), "EMSGarageSpawn")
		P(S, "BayLine", Vector3.new(0.5, 0.05, 34), Vector3.new(x + 9.5, Y + 0.26, -786), Color3.fromRGB(240, 200, 40), M.SmoothPlastic, { decor = true })
	end
	IK.marker("EMSGaragePark", Vector3.new(-200, FL, -760), "EMSGaragePark")
	IK.terminal("GarageTerminal", Vector3.new(-199, FL, -775), Vector3.new(-1, 0, 0), "EMSGarage", "Ambulanzgarage", "Rettungswagen ausparken / einparken", Color3.fromRGB(80, 200, 255))
	local gl = P(I, "GarageLight", Vector3.new(12, 0.4, 2), Vector3.new(-216, FL + H - 0.5, -785), Color3.fromRGB(255, 250, 235), M.Neon, { decor = true })
	local gll = Instance.new("PointLight")
	gll.Range, gll.Brightness, gll.Shadows = 30, 1.2, false
	gll.Parent = gl

	-- Notaufnahme (X -196..-136) ------------------------------------------------------------------------
	for i = 0, 2 do
		local x = -188 + i * 18
		bed(Vector3.new(x, FL, -798), Vector3.new(0, 0, -1))
		P(I, "CurtainRail", Vector3.new(0.2, 0.2, 14), Vector3.new(x + 8, FL + 12, -797), Color3.fromRGB(200, 204, 210), M.Metal, { decor = true })
		P(I, "Curtain", Vector3.new(0.15, 9, 12), Vector3.new(x + 8, FL + 7, -797), Color3.fromRGB(170, 210, 220), M.Fabric, { decor = true, transp = 0.15 })
	end
	P(I, "NurseStation", Vector3.new(16, 3.4, 4), Vector3.new(-160, FL + 1.7, -775), WHITE, M.Marble)
	P(I, "NurseStationTop", Vector3.new(16.2, 0.4, 4.2), Vector3.new(-160, FL + 3.6, -775), TEAL, M.SmoothPlastic, { decor = true })
	Kit.sign(I, CFrame.new(-166, FL + 15, -766.2) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, math.pi, 0), Vector3.new(30, 2.6, 0.3), "EMERGENCY DEPARTMENT / NOTAUFNAHME", Color3.new(1, 1, 1), RED)

	-- Empfang + Wartebereich (X -136..-66) ------------------------------------------------------------
	P(I, "ReceptionDesk", Vector3.new(24, 3, 4), Vector3.new(-101, FL + 1.5, -797), WHITE, M.Marble)
	P(I, "ReceptionTop", Vector3.new(24.2, 0.4, 4.2), Vector3.new(-101, FL + 3.2, -797), TEAL, M.SmoothPlastic, { decor = true })
	IK.npc("Hospital Receptionist", Vector3.new(-101, FL + 2.6, -800), Vector3.new(-101, FL + 2.6, -780), Color3.fromRGB(236, 240, 246), Color3.fromRGB(60, 120, 140),
		"Willkommen im Bayfront Medical Center. Verletzte werden vom Rettungsdienst in der Notaufnahme behandelt.")
	Kit.sign(I, CFrame.new(-101, FL + 13, -804.4) * CFrame.Angles(0, math.pi, 0), Vector3.new(22, 2.6, 0.3), "RECEPTION / EMPFANG", Color3.new(1, 1, 1), TEAL)
	for row = 0, 2 do
		for i = 0, 4 do
			P(I, "WaitingChair", Vector3.new(2.6, 1.8, 2.6), Vector3.new(-126 + i * 4, FL + 0.9, -786 + row * 7), Color3.fromRGB(60, 120, 140), M.Fabric)
			P(I, "WaitingChairBack", Vector3.new(2.6, 2.4, 0.4), Vector3.new(-126 + i * 4, FL + 2.4, -784.9 + row * 7), Color3.fromRGB(60, 120, 140), M.Fabric, { decor = true })
		end
	end
	for _, x in ipairs({ -132, -70 }) do
		P(I, "Planter", Vector3.new(3, 2.4, 3), Vector3.new(x, FL + 1.2, -769), Color3.fromRGB(230, 226, 216), M.Concrete)
		P(I, "PlanterLeaves", Vector3.new(4, 4, 4), Vector3.new(x, FL + 4.4, -769), Color3.fromRGB(70, 120, 60), M.LeafyGrass, { shape = Enum.PartType.Ball, decor = true })
	end
	IK.marker("HospitalRespawn", CFrame.new(-101, FL + 1, -775), "HospitalRespawn")

	-- Rettungswache (X -66..-17): Dienst, Ausruestung, Leitstelle ---------------------------------------
	IK.terminal("DutyTerminal", Vector3.new(-20, FL, -795), Vector3.new(-1, 0, 0), "EMSDuty", "Dienstterminal", "Dienstantritt / EMS Dashboard", Color3.fromRGB(80, 200, 255))
	IK.terminal("EquipmentTerminal", Vector3.new(-30, FL, -803), Vector3.new(0, 0, 1), "EMSEquipment", "Ausruestung", "Verbandsmaterial / Medikamente auffuellen", Color3.fromRGB(120, 255, 140))
	IK.terminal("DispatchTerminal", Vector3.new(-62, FL, -770), Vector3.new(1, 0, 0), "EMSDispatch", "Einsatzuebersicht", "Leitstelle / Einsaetze", Color3.fromRGB(255, 200, 80))
	for i = 0, 3 do
		P(I, "Locker", Vector3.new(4, 9, 2.4), Vector3.new(-58 + i * 5, FL + 4.5, -803), Color3.fromRGB(70, 110, 160), M.Metal)
	end
	P(I, "SupplyShelf", Vector3.new(2.4, 8, 14), Vector3.new(-19.5, FL + 4, -775), Color3.fromRGB(200, 204, 210), M.Metal)
	for j = 0, 3 do
		P(I, "SupplyBox", Vector3.new(1.6, 1.2, 12), Vector3.new(-19.5, FL + 1.2 + j * 1.9, -775), (j % 2 == 0) and RED or WHITE, M.SmoothPlastic, { decor = true })
	end
	Kit.sign(I, CFrame.new(-41, FL + 15, -766.2) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, math.pi, 0), Vector3.new(24, 2.4, 0.3), "EMS STATION", Color3.new(1, 1, 1), RED)

	-- Behandlungsraeume (X -236..-136) und Patientenzimmer (X -136..-56) ----------------------------------
	for i, x in ipairs({ -223.5, -198.5, -173.5, -148.5 }) do
		bed(Vector3.new(x, FL, -872), Vector3.new(0, 0, 1))
		P(I, "Cabinet", Vector3.new(8, 4, 2.4), Vector3.new(x, FL + 2, -817.4), WHITE, M.SmoothPlastic)
		P(I, "Lamp", Vector3.new(3, 0.4, 3), Vector3.new(x, FL + H - 1.5, -868), Color3.fromRGB(255, 252, 240), M.Neon, { decor = true })
		Kit.sign(I, CFrame.new(x, FL + 15.5, -815.7), Vector3.new(14, 1.8, 0.2), "TREATMENT " .. i, Color3.new(1, 1, 1), TEAL)
	end
	for i, x in ipairs({ -126, -106, -86, -66 }) do
		bed(Vector3.new(x, FL, -876), Vector3.new(0, 0, 1))
		P(I, "VisitorChair", Vector3.new(2.6, 3, 2.6), Vector3.new(x + 5, FL + 1.5, -868), Color3.fromRGB(60, 120, 140), M.Fabric)
		Kit.sign(I, CFrame.new(x, FL + 15.5, -815.7), Vector3.new(10, 1.8, 0.2), "ROOM 1" .. i, Color3.new(1, 1, 1), TEAL)
	end
	-- Stationsbuero
	P(I, "MeetingTable", Vector3.new(14, 0.6, 6), Vector3.new(-36, FL + 3, -850), Color3.fromRGB(230, 226, 216), M.Wood)
	for i = 0, 2 do
		for _, sz in ipairs({ -1, 1 }) do
			P(I, "Chair", Vector3.new(2.4, 3, 2.4), Vector3.new(-42 + i * 6, FL + 1.5, -850 + sz * 4.5), DARK, M.Fabric)
		end
	end
	-- Deckenlicht
	for _, pos in ipairs({ Vector3.new(-166, 0, -790), Vector3.new(-101, 0, -785), Vector3.new(-41, 0, -785), Vector3.new(-126, 0, -810), Vector3.new(-186, 0, -850), Vector3.new(-96, 0, -850), Vector3.new(-36, 0, -850) }) do
		local lamp = P(I, "CeilingLight", Vector3.new(10, 0.3, 2), Vector3.new(pos.X, FL + H - 0.4, pos.Z), Color3.fromRGB(255, 252, 240), M.Neon, { decor = true })
		local l = Instance.new("PointLight")
		l.Range, l.Brightness, l.Shadows = 28, 1, false
		l.Parent = lamp
	end

	local parts = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return string.format("%d Parts, %d Betten, Terminals: Dienst/Garage/Ausruestung/Leitstelle", parts, nBeds)
end
