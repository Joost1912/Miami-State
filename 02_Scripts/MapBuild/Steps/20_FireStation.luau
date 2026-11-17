-- Schritt 20: Fire Station 1 mit Innenraeumen (ersetzt den bisherigen Vollkoerper "FireStation1" an gleicher Stelle).
-- Grundriss (Welt): X -211..-42, Z 420..502, Front mit Hallentoren nach Sueden (Harbor Blvd, Vorplatz Z 502..548)
--   Vorderzone Z 448..502: Empfang/Lobby (X -211..-171) | Fahrzeughalle (X -171..-42, drei Tore)
--   Hinterzone Z 420..448: Umkleide/Dienst | Aufenthaltsraum/Kueche | Besprechung | Buero | Geraeteraum
return function(Kit)
	local M = Enum.Material
	local old = workspace.Map:FindFirstChild("FireStation1", true)
	if old and old:IsA("Model") and old.Parent.Name == "Buildings" then
		old:Destroy()
	end
	local root = workspace.Map:FindFirstChild("FireStation")
	if root then
		root:Destroy()
	end
	root = Kit.folder(workspace.Map, "FireStation")
	local S, I, G = Kit.model(root, "Building"), Kit.model(root, "Interior"), Kit.model(root, "Gameplay")
	local Y, FL, H = 0.6, 0.8, 20
	local X0, X1, Z0, Z1 = -211, -42, 420, 502
	local BRICK = Color3.fromRGB(150, 56, 44)
	local TRIM = Color3.fromRGB(236, 232, 224)
	local RED = Color3.fromRGB(190, 20, 24)
	local DARK = Color3.fromRGB(32, 34, 40)
	local WOOD = Color3.fromRGB(120, 86, 60)
	local IK = Kit.interior({ S = S, I = I, G = G, FL = FL, H = H, wall = Color3.fromRGB(238, 232, 222), faction = "Fire" })
	local P, wallX, wallZ = IK.P, IK.wallX, IK.wallZ

	-- Boden, Decke, Obergeschoss ------------------------------------------------------------------
	P(S, "Floor", Vector3.new(X1 - X0, 0.4, Z1 - Z0), Vector3.new((X0 + X1) / 2, Y, (Z0 + Z1) / 2), Color3.fromRGB(206, 198, 186), M.Slate)
	P(S, "BayFloor", Vector3.new(-42 - -171, 0.45, 54), Vector3.new((-171 - 42) / 2, Y + 0.02, 475), Color3.fromRGB(120, 122, 128), M.Concrete)
	for _, x in ipairs({ -150, -107, -64 }) do
		P(S, "BayLine", Vector3.new(0.6, 0.05, 50), Vector3.new(x - 15, Y + 0.26, 475), Color3.fromRGB(240, 200, 40), M.SmoothPlastic, { decor = true })
		P(S, "BayLine", Vector3.new(0.6, 0.05, 50), Vector3.new(x + 15, Y + 0.26, 475), Color3.fromRGB(240, 200, 40), M.SmoothPlastic, { decor = true })
	end
	P(S, "Ceiling", Vector3.new(X1 - X0, 1, Z1 - Z0), Vector3.new((X0 + X1) / 2, FL + H + 0.5, (Z0 + Z1) / 2), Color3.fromRGB(240, 240, 238), M.SmoothPlastic)
	P(S, "UpperFloor", Vector3.new(X1 - X0 + 1, 12, Z1 - Z0 + 1), Vector3.new((X0 + X1) / 2, FL + H + 1 + 6, (Z0 + Z1) / 2), BRICK, M.Brick)
	for i = 0, 9 do
		P(S, "UpperWindow", Vector3.new(9, 5, 0.4), Vector3.new(X0 + 10 + i * 16.5, FL + H + 7, Z1 + 0.65), Color3.fromRGB(46, 50, 56), M.Glass, { decor = true, refl = 0.2 })
		P(S, "UpperSill", Vector3.new(10, 0.5, 0.8), Vector3.new(X0 + 10 + i * 16.5, FL + H + 4.3, Z1 + 0.8), TRIM, M.Concrete, { decor = true })
	end
	P(S, "Cornice", Vector3.new(X1 - X0 + 3, 1.6, Z1 - Z0 + 3), Vector3.new((X0 + X1) / 2, FL + H + 13.8, (Z0 + Z1) / 2), TRIM, M.Concrete)
	P(S, "BeltCourse", Vector3.new(X1 - X0 + 2, 1.2, Z1 - Z0 + 2), Vector3.new((X0 + X1) / 2, FL + H + 1.2, (Z0 + Z1) / 2), TRIM, M.Concrete, { decor = true })

	-- Aussenwaende ---------------------------------------------------------------------------------
	wallX(Z0, X0, X1, nil, BRICK, 1.4, true)
	wallZ(X0, Z0, Z1, nil, BRICK, 1.4, true)
	wallZ(X1, Z0, Z1, nil, BRICK, 1.4, true)
	-- Front: Haupteingang Lobby (x -191) und drei Hallentore (je 30 breit, 17 hoch)
	wallX(Z1, X0, X1, { { -191, 12 }, { -150, 30, 17 }, { -107, 30, 17 }, { -64, 30, 17 } }, BRICK, 1.4, true)
	for _, x in ipairs({ -150, -107, -64 }) do
		-- aufgerolltes Sektionaltor (Kasten) + Torrahmen
		P(S, "DoorRoll", Vector3.new(31, 2.4, 2), Vector3.new(x, FL + 17.8, Z1 - 1.2), TRIM, M.Metal)
		for _, sx in ipairs({ -1, 1 }) do
			P(S, "DoorFrame", Vector3.new(0.8, 17, 1.8), Vector3.new(x + sx * 15.2, FL + 8.5, Z1 + 0.2), TRIM, M.Concrete, { decor = true })
		end
		P(S, "BayNumber", Vector3.new(4, 4, 0.2), Vector3.new(x, FL + 19, Z1 + 0.8), TRIM, M.SmoothPlastic, { decor = true })
	end
	for _, x in ipairs({ -205, -177 }) do
		P(S, "LobbyWindow", Vector3.new(8, 8, 0.4), Vector3.new(x, FL + 8, Z1 + 0.75), Color3.fromRGB(46, 50, 56), M.Glass, { decor = true, refl = 0.25 })
	end
	P(S, "EntranceCanopy", Vector3.new(20, 1, 10), Vector3.new(-191, FL + 15, Z1 + 5), RED, M.Metal)
	Kit.sign(S, CFrame.new(-107, FL + H + 7, Z1 + 1.4) * CFrame.Angles(0, math.pi, 0), Vector3.new(70, 6, 0.4), "FIRE STATION 1", Color3.fromRGB(255, 230, 120), RED)
	Kit.sign(S, CFrame.new(-191, FL + 17, Z1 + 1.2) * CFrame.Angles(0, math.pi, 0), Vector3.new(22, 2.4, 0.3), "MIAMI STATE FIRE DEPT.", Color3.new(1, 1, 1), RED)
	-- Malteserkreuz-Emblem (vereinfacht) ueber dem Eingang
	P(S, "Emblem", Vector3.new(0.5, 7, 7), CFrame.new(-191, FL + H + 6.5, Z1 + 1.5) * CFrame.Angles(0, math.pi / 2, 0), RED, M.SmoothPlastic, { shape = Enum.PartType.Cylinder, decor = true })
	P(S, "EmblemRing", Vector3.new(0.4, 8, 8), CFrame.new(-191, FL + H + 6.5, Z1 + 1.3) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(214, 172, 74), M.Foil, { shape = Enum.PartType.Cylinder, decor = true })
	-- Fahnenmast
	P(S, "Flagpole", Vector3.new(0.6, 32, 0.6), Vector3.new(-206, Y + 16, Z1 + 12), Color3.fromRGB(220, 222, 226), M.Metal)
	P(S, "Flag", Vector3.new(8, 5, 0.15), Vector3.new(-201.7, Y + 29, Z1 + 12), RED, M.Fabric, { decor = true })

	-- Innenwaende ----------------------------------------------------------------------------------
	wallX(448, X0, X1, { { -181, 8 }, { -151, 8 }, { -113, 8 }, { -83, 6 }, { -56, 10 } }) -- Hinterzone | Vorderzone
	wallZ(-171, 448, Z1, { { 470, 8 } }) -- Lobby | Fahrzeughalle
	wallZ(-171, Z0, 448, {}) -- Umkleide | Aufenthaltsraum
	wallZ(-131, Z0, 448, {}) -- Aufenthaltsraum | Besprechung
	wallZ(-96, Z0, 448, {}) -- Besprechung | Buero
	wallZ(-71, Z0, 448, {}) -- Buero | Geraeteraum

	-- Tueren
	IK.doorX("Locker Room Door", -181, 448, 8, true)
	IK.doorX("Day Room Door", -151, 448, 8, true)
	IK.doorX("Briefing Door", -113, 448, 8, true)
	IK.doorX("Office Door", -83, 448, 6, true)
	IK.doorZ("Apparatus Bay Door", -171, 470, 8, true, Color3.fromRGB(190, 40, 40))

	-- Lobby + Empfang ------------------------------------------------------------------------------
	P(I, "ReceptionDesk", Vector3.new(16, 2.6, 4), Vector3.new(-191, FL + 1.3, 462), TRIM, M.Marble)
	P(I, "DeskFront", Vector3.new(16.2, 0.6, 4.2), Vector3.new(-191, FL + 2.9, 462), RED, M.SmoothPlastic, { decor = true })
	P(I, "Monitor", Vector3.new(2.4, 1.6, 0.3), Vector3.new(-189, FL + 4.1, 461), DARK, M.SmoothPlastic, { decor = true })
	Kit.sign(I, CFrame.new(-191, FL + 12, 449) * CFrame.Angles(0, math.pi, 0), Vector3.new(20, 2.6, 0.3), "RECEPTION / EMPFANG", Color3.new(1, 1, 1), RED)
	IK.npc("Fire Station Clerk", Vector3.new(-191, FL + 2.6, 458), Vector3.new(-191, FL + 2.6, 480), Color3.fromRGB(40, 46, 70), Color3.fromRGB(26, 28, 40),
		"Willkommen bei Fire Station 1. Bei Feuer oder Unfall waehle 911 (Taste N oder Notruf-App im Handy).")
	for i = 0, 1 do
		IK.bench(I, CFrame.new(-205 + i * 0, FL, 480 + i * 12) * CFrame.Angles(0, math.pi / 2, 0), 10, WOOD)
	end
	-- historische Ausstellung: alter Feuerwehrhelm und Axt
	P(I, "DisplayCase", Vector3.new(6, 4, 3), Vector3.new(-176, FL + 2, 495), DARK, M.Wood)
	P(I, "DisplayGlass", Vector3.new(6, 3, 3), Vector3.new(-176, FL + 5.5, 495), Color3.fromRGB(200, 220, 230), M.Glass, { decor = true, transp = 0.6 })
	P(I, "OldHelmet", Vector3.new(1.6, 1, 2), Vector3.new(-177, FL + 4.6, 495), Color3.fromRGB(30, 30, 34), M.SmoothPlastic, { decor = true })

	-- Fahrzeughalle ----------------------------------------------------------------------------------
	for i, x in ipairs({ -150, -107, -64 }) do
		IK.marker("FireGarageSpawn_" .. i, CFrame.lookAt(Vector3.new(x, FL, 472), Vector3.new(x, FL, 520)), "FireGarageSpawn")
		-- Schlauchhalter an den Pfeilern
		P(I, "HoseRack", Vector3.new(1, 6, 3), Vector3.new(x + 19.5, FL + 5, 452), RED, M.Metal)
	end
	IK.marker("FireGaragePark", Vector3.new(-107, FL, 500), "FireGaragePark")
	IK.terminal("GarageTerminal", Vector3.new(-128, FL, 450), Vector3.new(0, 0, 1), "FireGarage", "Fahrzeughalle", "Fahrzeug ausparken / einparken")
	-- Schlauchturm-Imitat (Trocknungsgestell) und Werkbank
	P(I, "Workbench", Vector3.new(10, 3.4, 3), Vector3.new(-50, FL + 1.7, 455), Color3.fromRGB(90, 92, 98), M.DiamondPlate)
	P(I, "ToolWall", Vector3.new(12, 6, 0.4), Vector3.new(-50, FL + 7, 449), Color3.fromRGB(70, 72, 78), M.Metal, { decor = true })
	-- Hallenbeleuchtung
	for _, x in ipairs({ -150, -107, -64 }) do
		local lamp = P(I, "BayLight", Vector3.new(10, 0.4, 2), Vector3.new(x, FL + H - 0.5, 475), Color3.fromRGB(255, 250, 235), M.Neon, { decor = true })
		local l = Instance.new("PointLight")
		l.Range, l.Brightness, l.Shadows = 34, 1.4, false
		l.Parent = lamp
	end

	-- Umkleide + Dienstantritt (X -211..-171) ---------------------------------------------------------
	for i = 0, 3 do
		P(I, "TurnoutRack", Vector3.new(8, 9, 2.4), Vector3.new(-205 + i * 9, FL + 4.5, 422.4), Color3.fromRGB(90, 92, 98), M.Metal)
		P(I, "TurnoutGear", Vector3.new(6, 5, 1.2), Vector3.new(-205 + i * 9, FL + 5, 423.8), Color3.fromRGB(176, 140, 80), M.Fabric, { decor = true })
		P(I, "GearHelmet", Vector3.new(1.6, 1, 1.8), Vector3.new(-205 + i * 9, FL + 8.4, 423.4), Color3.fromRGB(30, 30, 34), M.SmoothPlastic, { decor = true })
	end
	P(I, "LockerBench", Vector3.new(24, 1.6, 2.4), Vector3.new(-191, FL + 1.6, 434), WOOD, M.WoodPlanks)
	IK.terminal("DutyTerminal", Vector3.new(-208, FL, 440), Vector3.new(1, 0, 0), "FireDuty", "Dienstterminal", "Dienstantritt / Fire Dashboard", Color3.fromRGB(255, 120, 80))
	Kit.sign(I, CFrame.new(-191, FL + 15, 447.4) * CFrame.Angles(0, 0, 0), Vector3.new(26, 2.4, 0.3), "LOCKER ROOM / DIENSTANTRITT", Color3.new(1, 1, 1), RED)

	-- Aufenthaltsraum + Kueche (X -171..-131) --------------------------------------------------------
	P(I, "KitchenCounter", Vector3.new(30, 3.4, 3), Vector3.new(-151, FL + 1.7, 422), Color3.fromRGB(230, 226, 216), M.Marble)
	P(I, "Fridge", Vector3.new(4, 9, 3.4), Vector3.new(-134, FL + 4.5, 422.4), Color3.fromRGB(210, 212, 216), M.Metal)
	P(I, "DiningTable", Vector3.new(14, 0.6, 5), Vector3.new(-151, FL + 3, 434), WOOD, M.Wood)
	for _, sx in ipairs({ -1, 1 }) do
		P(I, "TableLeg", Vector3.new(0.6, 3, 4), Vector3.new(-151 + sx * 6, FL + 1.5, 434), DARK, M.Metal, { decor = true })
		IK.bench(I, CFrame.new(-151, FL, 434 + sx * 4) * CFrame.Angles(0, sx > 0 and 0 or math.pi, 0), 12, WOOD)
	end
	P(I, "Couch", Vector3.new(12, 2.4, 4), Vector3.new(-160, FL + 1.2, 444), Color3.fromRGB(70, 60, 54), M.Fabric)
	P(I, "TV", Vector3.new(0.4, 5, 8), Vector3.new(-170, FL + 7, 436), DARK, M.SmoothPlastic, { decor = true })

	-- Besprechung (X -131..-96) + Leitstellen-Terminal ----------------------------------------------
	P(I, "BriefingTable", Vector3.new(22, 0.6, 7), Vector3.new(-113, FL + 3, 432), Color3.fromRGB(230, 226, 216), M.Wood)
	for i = 0, 3 do
		for _, sz in ipairs({ -1, 1 }) do
			P(I, "Chair", Vector3.new(2.4, 3, 2.4), Vector3.new(-122 + i * 6, FL + 1.5, 432 + sz * 5), DARK, M.Fabric)
		end
	end
	P(I, "BriefingScreen", Vector3.new(14, 7, 0.3), Vector3.new(-113, FL + 9, 420.9), DARK, M.SmoothPlastic, { decor = true })
	P(I, "BriefingMap", Vector3.new(13, 6, 0.1), Vector3.new(-113, FL + 9, 421.1), Color3.fromRGB(64, 120, 200), M.Neon, { decor = true })
	IK.terminal("DispatchTerminal", Vector3.new(-128, FL, 444), Vector3.new(1, 0, 0), "FireDispatch", "Einsatzuebersicht", "Leitstelle / Einsaetze", Color3.fromRGB(255, 200, 80))

	-- Buero (X -96..-71) -----------------------------------------------------------------------------
	for _, z in ipairs({ 428, 440 }) do
		P(I, "Desk", Vector3.new(8, 3.4, 4), Vector3.new(-84, FL + 1.7, z), WOOD, M.WoodPlanks)
		P(I, "Monitor", Vector3.new(3, 2, 0.3), Vector3.new(-84, FL + 4.6, z - 1), DARK, M.SmoothPlastic, { decor = true })
		P(I, "Chair", Vector3.new(2.6, 3, 2.6), Vector3.new(-84, FL + 1.5, z + 3.5), DARK, M.Fabric)
	end
	Kit.sign(I, CFrame.new(-84, FL + 12, 420.9) * CFrame.Angles(0, math.pi, 0), Vector3.new(16, 2.4, 0.3), "CAPTAIN'S OFFICE", Color3.new(1, 1, 1), RED)

	-- Geraeteraum (X -71..-42) --------------------------------------------------------------------------
	for i = 0, 4 do
		P(I, "AirTankRack", Vector3.new(4, 7, 2), Vector3.new(-68 + i * 5.5, FL + 3.5, 422), Color3.fromRGB(90, 92, 98), M.Metal)
		for j = 0, 2 do
			P(I, "AirTank", Vector3.new(1, 2.6, 1), Vector3.new(-69.4 + i * 5.5 + j * 1.3, FL + 5, 423.2), Color3.fromRGB(220, 220, 226), M.Metal, { decor = true })
		end
	end
	P(I, "HoseShelf", Vector3.new(3, 8, 16), Vector3.new(-44.5, FL + 4, 434), Color3.fromRGB(90, 92, 98), M.Metal)
	for j = 0, 3 do
		P(I, "HoseRoll", Vector3.new(2.4, 2.4, 1.4), CFrame.new(-44.5, FL + 1.6 + j * 2, 434) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(210, 190, 140), M.Fabric, { decor = true, shape = Enum.PartType.Cylinder })
	end
	IK.terminal("EquipmentTerminal", Vector3.new(-56, FL, 442), Vector3.new(0, 0, 1), "FireEquipment", "Ausruestung", "Feuerloescher auffuellen", Color3.fromRGB(120, 255, 140))
	Kit.sign(I, CFrame.new(-56, FL + 15, 447.4), Vector3.new(18, 2.4, 0.3), "EQUIPMENT", Color3.new(1, 1, 1), RED)

	-- Deckenlicht in den Raeumen
	for _, x in ipairs({ -191, -151, -113, -84, -56 }) do
		local lamp = P(I, "CeilingLight", Vector3.new(8, 0.3, 2), Vector3.new(x, FL + H - 0.4, 434), Color3.fromRGB(255, 250, 235), M.Neon, { decor = true })
		local l = Instance.new("PointLight")
		l.Range, l.Brightness, l.Shadows = 24, 1, false
		l.Parent = lamp
	end
	local light = P(I, "LobbyLight", Vector3.new(10, 0.3, 2), Vector3.new(-191, FL + H - 0.4, 478), Color3.fromRGB(255, 250, 235), M.Neon, { decor = true })
	local l = Instance.new("PointLight")
	l.Range, l.Brightness, l.Shadows = 26, 1, false
	l.Parent = light

	local parts = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return string.format("%d Parts, 3 Stellplaetze, Terminals: Dienst/Garage/Leitstelle/Ausruestung", parts)
end
