-- Schritt 19: Miami State Police Headquarters mit Innenraeumen (ersetzt den bisherigen Vollkoerper an gleicher Stelle).
-- Grundriss (Welt-Koordinaten, Front/Eingang nach Sueden zum Parkplatz):
--   X -266..-6, Z -146..-26 | Garage X -66..-6 | Vorderzone Z -66..-26 | Flur Z -76..-66 | Hinterzone Z -146..-76
--   Vorne: Umkleide/Dienstantritt (-266..-186), Lobby/Empfang (-186..-106), Bueros (-106..-66)
--   Hinten: Zellen+Booking (-266..-206), Vernehmung (-206..-166), Leitstelle (-166..-116), Besprechung (-116..-66)
return function(Kit)
	local C, M = Kit.C, Enum.Material
	local CS = game:GetService("CollectionService")
	local root = workspace.Map:FindFirstChild("PoliceStation")
	if root then
		root:Destroy()
	end
	root = Kit.folder(workspace.Map, "PoliceStation")
	local S = Kit.model(root, "Building")
	local I = Kit.model(root, "Interior")
	local G = Kit.model(root, "Gameplay")
	local Y = 0.6 -- Grundstueck
	local FL = Y + 0.2 -- Fussboden-Oberkante
	local H = 18 -- Raumhoehe
	local X0, X1, Z0, Z1 = -266, -6, -146, -26
	local WALL = Color3.fromRGB(234, 234, 230)
	local NAVY = Color3.fromRGB(24, 40, 78)
	local GLASS = Color3.fromRGB(40, 66, 96)
	local WOOD = Color3.fromRGB(120, 86, 60)
	local DARK = Color3.fromRGB(32, 34, 40)

	local function P(parent, name, size, pos, color, mat, o)
		return Kit.part(parent, name, size, typeof(pos) == "CFrame" and pos or CFrame.new(pos), color, mat, o)
	end
	local function marker(name, pos, tag, attrs)
		local p = Kit.tagMarker(G, name, typeof(pos) == "CFrame" and pos or CFrame.new(pos), tag, attrs)
		return p
	end
	local function interact(part, kind, text, objectText, range, extra)
		part:SetAttribute("InteractType", kind)
		part:SetAttribute("InteractText", text)
		part:SetAttribute("ObjectText", objectText)
		part:SetAttribute("Range", range or 10)
		for k, v in pairs(extra or {}) do
			part:SetAttribute(k, v)
		end
		CS:AddTag(part, "Interactable")
	end

	-- Waende mit Tueroeffnungen: entlang X (fester z) bzw. entlang Z (fester x); gaps = { {Mitte, Breite}, ... }
	local function wallX(z, a, b, gaps, color, thick, exterior)
		gaps = gaps or {}
		table.sort(gaps, function(p, q)
			return p[1] < q[1]
		end)
		local cur = a
		local segs = {}
		for _, g in ipairs(gaps) do
			table.insert(segs, { cur, g[1] - g[2] / 2 })
			cur = g[1] + g[2] / 2
			-- Sturz ueber der Oeffnung
			P(S, "Lintel", Vector3.new(g[2], H - 14, thick or 1), Vector3.new(g[1], FL + 14 + (H - 14) / 2, z), color or WALL, M.Plaster)
		end
		table.insert(segs, { cur, b })
		for _, s in ipairs(segs) do
			if s[2] - s[1] > 0.2 then
				P(S, "Wall", Vector3.new(s[2] - s[1], H, thick or 1), Vector3.new((s[1] + s[2]) / 2, FL + H / 2, z), color or WALL, exterior and M.Concrete or M.Plaster)
			end
		end
	end
	local function wallZ(x, a, b, gaps, color, thick, exterior)
		gaps = gaps or {}
		table.sort(gaps, function(p, q)
			return p[1] < q[1]
		end)
		local cur = a
		local segs = {}
		for _, g in ipairs(gaps) do
			table.insert(segs, { cur, g[1] - g[2] / 2 })
			cur = g[1] + g[2] / 2
			P(S, "Lintel", Vector3.new(thick or 1, H - 14, g[2]), Vector3.new(x, FL + 14 + (H - 14) / 2, g[1]), color or WALL, M.Plaster)
		end
		table.insert(segs, { cur, b })
		for _, s in ipairs(segs) do
			if s[2] - s[1] > 0.2 then
				P(S, "Wall", Vector3.new(thick or 1, H, s[2] - s[1]), Vector3.new(x, FL + H / 2, (s[1] + s[2]) / 2), color or WALL, exterior and M.Concrete or M.Plaster)
			end
		end
	end
	-- Tuer (Interaktion "Door"): Scharnier an der lokalen -X-Kante
	local function door(name, cf, width, locked, color)
		local m = Kit.model(G, name)
		local d = P(m, "Door", Vector3.new(width - 0.2, 13.8, 0.5), cf * CFrame.new(0, FL + 6.9, 0), color or Color3.fromRGB(200, 204, 210), M.Metal)
		P(m, "Handle", Vector3.new(0.3, 0.3, 1.2), d.CFrame * CFrame.new(width / 2 - 1.2, 0, 0), Color3.fromRGB(180, 180, 186), M.Metal, { decor = true })
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = d, m.Handle
		weld.Parent = m.Handle
		m.Handle.Anchored = false
		m.PrimaryPart = d
		m:SetAttribute("InteractType", "Door")
		m:SetAttribute("InteractText", "Tuer oeffnen / schliessen")
		m:SetAttribute("ObjectText", name)
		m:SetAttribute("Range", 9)
		if locked then
			m:SetAttribute("Locked", true)
			m:SetAttribute("RequiredFaction", "Police")
		end
		CS:AddTag(m, "Interactable")
		return m
	end
	local Xa = CFrame.new() -- Tuer in einer X-Wand
	local function doorX(name, x, z, w, locked, color)
		return door(name, CFrame.new(x, 0, z), w, locked, color)
	end
	local function doorZ(name, x, z, w, locked, color)
		return door(name, CFrame.new(x, 0, z) * CFrame.Angles(0, math.pi / 2, 0), w, locked, color)
	end
	local _ = Xa

	-- Boden, Decke, Obergeschoss -------------------------------------------------------------
	P(S, "Floor", Vector3.new(X1 - X0, 0.4, Z1 - Z0), Vector3.new((X0 + X1) / 2, Y + 0.0, (Z0 + Z1) / 2), Color3.fromRGB(214, 206, 192), M.Marble)
	P(S, "GarageFloor", Vector3.new(60, 0.45, Z1 - Z0), Vector3.new(-36, Y + 0.02, (Z0 + Z1) / 2), Color3.fromRGB(110, 112, 118), M.Concrete)
	P(S, "Ceiling", Vector3.new(X1 - X0, 1, Z1 - Z0), Vector3.new((X0 + X1) / 2, FL + H + 0.5, (Z0 + Z1) / 2), Color3.fromRGB(240, 240, 238), M.SmoothPlastic)
	P(S, "UpperFloor", Vector3.new(X1 - X0 + 2, 15, Z1 - Z0 + 2), Vector3.new((X0 + X1) / 2, FL + H + 1 + 7.5, (Z0 + Z1) / 2), Color3.fromRGB(236, 238, 242), M.Concrete)
	P(S, "UpperGlass", Vector3.new(X1 - X0 + 2.4, 6, Z1 - Z0 + 2.4), Vector3.new((X0 + X1) / 2, FL + H + 9, (Z0 + Z1) / 2), GLASS, M.Glass, { decor = true, refl = 0.2 })
	P(S, "Cornice", Vector3.new(X1 - X0 + 4, 2, Z1 - Z0 + 4), Vector3.new((X0 + X1) / 2, FL + H + 17, (Z0 + Z1) / 2), NAVY, M.Concrete)
	P(S, "BlueBand", Vector3.new(X1 - X0 + 2.6, 1.6, Z1 - Z0 + 2.6), Vector3.new((X0 + X1) / 2, FL + H + 1.6, (Z0 + Z1) / 2), Color3.fromRGB(40, 90, 200), M.SmoothPlastic, { decor = true })

	-- Aussenwaende ----------------------------------------------------------------------------
	wallX(Z0, X0, X1, nil, WALL, 1.4, true) -- Rueckwand
	wallZ(X0, Z0, Z1, nil, WALL, 1.4, true) -- West
	wallZ(X1, Z0, Z1, nil, WALL, 1.4, true) -- Ost (Garage)
	-- Front: Haupteingang (Lobby, x -146, 16 breit), ein durchgehendes Garagentor ueber alle drei Stellplaetze
	wallX(Z1, X0, X1, { { -146, 16 }, { -36, 56 } }, WALL, 1.4, true)
	for _, x in ipairs({ -246, -226, -206, -166, -126, -96, -76 }) do
		P(S, "Window", Vector3.new(14, 8, 0.4), Vector3.new(x, FL + 9, Z1 + 0.75), GLASS, M.Glass, { decor = true, refl = 0.25 })
	end
	P(S, "EntranceCanopy", Vector3.new(36, 1.2, 14), Vector3.new(-146, FL + 16, Z1 + 7), NAVY, M.Metal)
	P(S, "CanopyLight", Vector3.new(34, 0.2, 12), Vector3.new(-146, FL + 15.3, Z1 + 7), Color3.fromRGB(255, 244, 220), M.Neon, { decor = true })
	Kit.sign(S, CFrame.new(-146, FL + H + 9, Z1 + 1.8) * CFrame.Angles(0, math.pi, 0), Vector3.new(90, 7, 0.4), "MIAMI STATE POLICE", Color3.new(1, 1, 1), NAVY)
	Kit.sign(S, CFrame.new(-36, FL + 16, Z1 + 1.2) * CFrame.Angles(0, math.pi, 0), Vector3.new(40, 2.6, 0.3), "POLICE GARAGE", Color3.fromRGB(255, 210, 90), DARK)
	-- Dienstabzeichen (Stern) ueber dem Eingang
	P(S, "BadgeEmblem", Vector3.new(0.6, 9, 9), CFrame.new(-196, FL + H + 9, Z1 + 1.6) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(214, 172, 74), M.Foil, { shape = Enum.PartType.Cylinder, decor = true })
	-- Fahnenmasten
	for i, x in ipairs({ -186, -106 }) do
		P(S, "Flagpole", Vector3.new(0.6, 34, 0.6), Vector3.new(x, Y + 17, Z1 + 16), Color3.fromRGB(220, 222, 226), M.Metal)
		P(S, "Flag", Vector3.new(8, 5, 0.15), Vector3.new(x + 4.3, Y + 31, Z1 + 16), i == 1 and Color3.fromRGB(30, 60, 140) or Color3.fromRGB(255, 255, 255), M.Fabric, { decor = true })
		P(S, "FlagStar", Vector3.new(2, 2, 0.2), Vector3.new(x + 4.3, Y + 31, Z1 + 16), Color3.fromRGB(214, 172, 74), M.Foil, { decor = true })
	end

	-- Innenwaende -------------------------------------------------------------------------------
	wallX(-66, X0, -66, { { -226, 8 }, { -146, 8 }, { -86, 8 } }) -- Vorderzone | Flur
	wallX(-76, X0, -66, { { -236, 8 }, { -196, 6 }, { -176, 6 }, { -141, 8 }, { -91, 8 } }) -- Flur | Hinterzone
	wallZ(-66, Z0, Z1, { { -71, 8 } }, WALL, 1) -- Garage-Trennwand mit Tuer zum Flur
	wallZ(-186, -66, Z1, { { -46, 8 } }) -- Umkleide | Lobby
	wallZ(-106, -66, Z1, {}) -- Lobby | Bueros
	wallZ(-206, Z0, -76, {}) -- Zellen | Vernehmung
	wallZ(-186, Z0, -76, {}) -- Vernehmung 1 | 2
	wallZ(-166, Z0, -76, {}) -- Vernehmung | Leitstelle
	wallZ(-116, Z0, -76, {}) -- Leitstelle | Besprechung

	-- Tueren
	doorZ("Staff Door Locker", -186, -46, 8, true)
	doorX("Lobby Security Door", -146, -66, 8, true, Color3.fromRGB(40, 60, 110))
	doorX("Locker Room Door", -226, -66, 8, true)
	doorX("Offices Door", -86, -66, 8, true)
	doorX("Holding Area Door", -236, -76, 8, true, Color3.fromRGB(90, 96, 104))
	doorX("Interrogation 1", -196, -76, 6, true)
	doorX("Interrogation 2", -176, -76, 6, true)
	doorX("Dispatch Door", -141, -76, 8, true)
	doorX("Briefing Door", -91, -76, 8, true)
	doorZ("Garage Door", -66, -71, 8, true)

	-- Lobby + Empfang ----------------------------------------------------------------------------
	P(I, "ReceptionDesk", Vector3.new(30, 2.6, 4), Vector3.new(-146, FL + 1.3, -58), Color3.fromRGB(236, 232, 224), M.Marble)
	P(I, "ReceptionDeskSide", Vector3.new(4, 2.6, 8), Vector3.new(-161, FL + 1.3, -54), Color3.fromRGB(236, 232, 224), M.Marble)
	P(I, "DeskFront", Vector3.new(30.2, 0.6, 4.2), Vector3.new(-146, FL + 2.9, -58), NAVY, M.SmoothPlastic, { decor = true })
	for _, x in ipairs({ -152, -140 }) do
		P(I, "Monitor", Vector3.new(2.4, 1.6, 0.3), Vector3.new(x, FL + 4.1, -59), DARK, M.SmoothPlastic, { decor = true })
		P(I, "Screen", Vector3.new(2.1, 1.3, 0.1), Vector3.new(x, FL + 4.1, -58.8), Color3.fromRGB(64, 160, 255), M.Neon, { decor = true })
	end
	Kit.sign(I, CFrame.new(-146, FL + 12, -65.4) * CFrame.Angles(0, math.pi, 0), Vector3.new(24, 3, 0.3), "RECEPTION / EMPFANG", Color3.new(1, 1, 1), NAVY)
	for i = 0, 2 do
		P(I, "Bench", Vector3.new(14, 1.6, 3), Vector3.new(-176 + i * 15, FL + 1.6, -32), WOOD, M.WoodPlanks)
		P(I, "BenchBack", Vector3.new(14, 3, 0.6), Vector3.new(-176 + i * 15, FL + 3.6, -30.6), WOOD, M.WoodPlanks, { decor = true })
	end
	for _, x in ipairs({ -183, -109 }) do
		P(I, "Plant", Vector3.new(3, 2.4, 3), Vector3.new(x, FL + 1.2, -30), Color3.fromRGB(230, 226, 216), M.Concrete)
		P(I, "PlantLeaves", Vector3.new(4, 4, 4), Vector3.new(x, FL + 4.4, -30), Color3.fromRGB(70, 120, 60), M.LeafyGrass, { shape = Enum.PartType.Ball, decor = true })
	end
	-- Empfangs-NPC
	local okNpc, npc = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		local skin = Color3.fromRGB(224, 172, 128)
		desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, NAVY, NAVY
		desc.TorsoColor, desc.LeftLegColor, desc.RightLegColor = NAVY, Color3.fromRGB(20, 24, 40), Color3.fromRGB(20, 24, 40)
		return game:GetService("Players"):CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if okNpc and npc then
		npc.Name = "Desk Officer"
		for _, p in ipairs(npc:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
			end
		end
		npc:FindFirstChildOfClass("Humanoid").DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		npc:PivotTo(CFrame.lookAt(Vector3.new(-146, FL + 2.6, -62), Vector3.new(-146, FL + 2.6, -40)))
		npc.Parent = I
		interact(npc.PrimaryPart, "NPC", "Ansprechen", "Desk Officer", 12, {
			Dialog = "Willkommen bei der Miami State Police. Fuer Notfaelle waehlen Sie 911 (Taste N). Anzeigen nimmt jede Streife auf.",
		})
	end

	-- Umkleide + Dienstantritt ---------------------------------------------------------------------
	for i = 0, 3 do
		P(I, "LockerBank", Vector3.new(16, 11, 3), Vector3.new(-256 + i * 18, FL + 5.5, -60), Color3.fromRGB(70, 90, 130), M.Metal)
	end
	for i = 0, 3 do
		for j = 0, 3 do
			P(I, "LockerSeam", Vector3.new(0.15, 10.5, 0.1), Vector3.new(-264 + i * 18 + j * 4, FL + 5.5, -58.45), DARK, M.SmoothPlastic, { decor = true })
		end
	end
	for i = 0, 1 do
		P(I, "LockerBench", Vector3.new(30, 1.6, 2.4), Vector3.new(-236, FL + 1.6, -48 + i * 10), WOOD, M.WoodPlanks)
	end
	local duty = P(I, "DutyTerminal", Vector3.new(4, 7, 2), Vector3.new(-196, FL + 3.5, -40), DARK, M.Metal)
	P(I, "DutyScreen", Vector3.new(0.1, 2.4, 3.2), Vector3.new(-198.05, FL + 5.5, -40), Color3.fromRGB(64, 224, 255), M.Neon, { decor = true })
	duty.CFrame = CFrame.lookAt(duty.Position, duty.Position + Vector3.new(-1, 0, 0))
	interact(duty, "PoliceDuty", "Dienstterminal", "Dienstantritt / Police Dashboard", 10)
	Kit.sign(I, CFrame.new(-226, FL + 15, -65.4) * CFrame.Angles(0, math.pi, 0), Vector3.new(30, 2.6, 0.3), "LOCKER ROOM / DIENSTANTRITT", Color3.new(1, 1, 1), NAVY)

	-- Bueros -----------------------------------------------------------------------------------------
	local function desk(parent, pos, facing, mdt)
		local cf = CFrame.lookAt(pos, pos + facing)
		P(parent, "Desk", Vector3.new(8, 3.4, 4), cf * CFrame.new(0, 1.7, 0), WOOD, M.WoodPlanks)
		P(parent, "Monitor", Vector3.new(3, 2, 0.3), cf * CFrame.new(0, 4.6, 1), DARK, M.SmoothPlastic, { decor = true })
		local scr = P(parent, "Screen", Vector3.new(2.7, 1.7, 0.1), cf * CFrame.new(0, 4.6, 0.8), Color3.fromRGB(64, 160, 255), M.Neon, { decor = true })
		P(parent, "Chair", Vector3.new(2.6, 3, 2.6), cf * CFrame.new(0, 1.5, -3.5), DARK, M.Fabric)
		if mdt then
			local t = P(parent, "MDTTerminal", Vector3.new(3, 2, 1), cf * CFrame.new(2.6, 4, 0.4), DARK, M.SmoothPlastic)
			interact(t, "PoliceMDT", "MDT oeffnen", "Mobile Data Terminal", 9)
		end
		return scr
	end
	desk(I, Vector3.new(-96, FL, -54), Vector3.new(0, 0, 1), true)
	desk(I, Vector3.new(-78, FL, -54), Vector3.new(0, 0, 1), false)
	desk(I, Vector3.new(-87, FL, -36), Vector3.new(0, 0, 1), true)
	P(I, "FileCabinet", Vector3.new(3, 6, 3), Vector3.new(-69, FL + 3, -64), Color3.fromRGB(150, 154, 160), M.Metal)

	-- Besprechungsraum ---------------------------------------------------------------------------------
	for r = 0, 2 do
		P(I, "SeatRow", Vector3.new(30, 1.8, 2.6), Vector3.new(-91, FL + 1.6, -100 - r * 8), DARK, M.Fabric)
		P(I, "SeatBack", Vector3.new(30, 2.6, 0.5), Vector3.new(-91, FL + 3.4, -98.6 - r * 8), DARK, M.Fabric, { decor = true })
	end
	P(I, "Podium", Vector3.new(4, 4.4, 3), Vector3.new(-91, FL + 2.2, -134), WOOD, M.WoodPlanks)
	Kit.sign(I, CFrame.new(-91, FL + 9, -145.2), Vector3.new(36, 12, 0.3), "BRIEFING - MIAMI STATE POLICE", Color3.fromRGB(64, 224, 255), Color3.fromRGB(12, 16, 26))

	-- Leitstelle ------------------------------------------------------------------------------------------
	for i = 0, 2 do
		local x = -156 + i * 15
		desk(I, Vector3.new(x, FL, -118), Vector3.new(0, 0, -1), false)
		P(I, "SideMonitor", Vector3.new(2.6, 1.8, 0.3), Vector3.new(x - 3.2, FL + 4.6, -119), Color3.fromRGB(64, 224, 255), M.Neon, { decor = true })
	end
	local console = P(I, "DispatchConsole", Vector3.new(6, 4, 3), Vector3.new(-141, FL + 2, -100), DARK, M.Metal)
	interact(console, "PoliceDispatch", "Leitstelle oeffnen", "Dispatch Console", 10)
	Kit.sign(I, CFrame.new(-141, FL + 10, -145.2), Vector3.new(44, 14, 0.3), "DISPATCH / LEITSTELLE  -  MIAMI STATE", Color3.fromRGB(255, 72, 168), Color3.fromRGB(8, 12, 22))

	-- Vernehmungsraeume ------------------------------------------------------------------------------------
	for i, x in ipairs({ -196, -176 }) do
		P(I, "Table", Vector3.new(8, 3.2, 5), Vector3.new(x, FL + 1.6, -115), Color3.fromRGB(150, 150, 150), M.Metal)
		P(I, "Chair", Vector3.new(2.4, 3, 2.4), Vector3.new(x, FL + 1.5, -110), DARK, M.Metal)
		P(I, "Chair", Vector3.new(2.4, 3, 2.4), Vector3.new(x - 2, FL + 1.5, -120), DARK, M.Metal)
		P(I, "Chair", Vector3.new(2.4, 3, 2.4), Vector3.new(x + 2, FL + 1.5, -120), DARK, M.Metal)
		P(I, "OneWayMirror", Vector3.new(16, 6, 0.3), Vector3.new(x, FL + 8, -145.2), Color3.fromRGB(20, 26, 34), M.Glass, { decor = true, refl = 0.4 })
		Kit.sign(I, CFrame.new(x, FL + 15.5, -76.8), Vector3.new(16, 2, 0.3), "INTERVIEW " .. i, Color3.new(1, 1, 1), NAVY)
	end

	-- Zellen + Booking ------------------------------------------------------------------------------------
	local cellZ = -121 -- Gitterfront
	for i = 0, 2 do
		local x0 = -266 + i * 20
		local cx = x0 + 10
		if i > 0 then
			P(S, "CellWall", Vector3.new(1, H, 25), Vector3.new(x0, FL + H / 2, -133.5), WALL, M.Concrete)
		end
		for bx = x0 + 1.5, x0 + 19, 1.6 do
			if math.abs(bx - (cx + 4)) > 3.4 then
				P(S, "CellBar", Vector3.new(0.35, H, 0.35), Vector3.new(bx, FL + H / 2, cellZ), Color3.fromRGB(70, 74, 82), M.Metal)
			end
		end
		P(I, "CellBench", Vector3.new(10, 1.8, 3), Vector3.new(cx - 3, FL + 1.8, -144), Color3.fromRGB(170, 170, 170), M.Concrete)
		P(I, "CellToilet", Vector3.new(2.4, 2.4, 2.4), Vector3.new(x0 + 17, FL + 1.2, -144), Color3.fromRGB(200, 204, 208), M.Metal)
		local cd = door("Cell " .. (i + 1), CFrame.new(cx + 4, 0, cellZ), 6.6, true, Color3.fromRGB(110, 116, 126))
		cd.Door.Transparency = 0.45
		marker("JailCell_" .. (i + 1), Vector3.new(cx - 2, FL + 3, -134), "JailCell", { Cell = i + 1 })
	end
	Kit.sign(I, CFrame.new(-236, FL + 15.5, -76.8), Vector3.new(26, 2, 0.3), "HOLDING / ARRESTZELLEN", Color3.new(1, 1, 1), NAVY)
	P(I, "BookingDesk", Vector3.new(14, 4, 4), Vector3.new(-236, FL + 2, -100), Color3.fromRGB(150, 154, 160), M.Metal)
	P(I, "HeightChart", Vector3.new(10, 12, 0.2), CFrame.new(-265.2, FL + 7, -100) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(236, 236, 232), M.SmoothPlastic, { decor = true })
	for k = 1, 5 do
		P(I, "ChartLine", Vector3.new(10, 0.1, 0.25), CFrame.new(-265.0, FL + 1 + k * 2, -100) * CFrame.Angles(0, math.pi / 2, 0), DARK, M.SmoothPlastic, { decor = true })
	end
	marker("PoliceBooking", Vector3.new(-236, FL + 3, -95), "PoliceBooking")
	marker("JailRelease", Vector3.new(-146, Y + 3, -16), "JailRelease")

	-- Garage ------------------------------------------------------------------------------------------------
	for i, x in ipairs({ -56, -36, -16 }) do
		for _, s in ipairs({ -1, 1 }) do
			P(I, "BayLine", Vector3.new(0.4, 0.06, 40), Vector3.new(x + s * 9, Y + 0.3, -62), Color3.fromRGB(240, 200, 40), M.SmoothPlastic, { decor = true })
		end
		marker("PoliceGarageSpawn_" .. i, CFrame.lookAt(Vector3.new(x, Y + 3, -60), Vector3.new(x, Y + 3, 0)), "PoliceGarageSpawn", { Bay = i })
	end
	local gterm = P(I, "GarageTerminal", Vector3.new(3, 6, 2), Vector3.new(-63.5, FL + 3, -100), DARK, M.Metal)
	gterm.CFrame = CFrame.lookAt(gterm.Position, gterm.Position + Vector3.new(1, 0, 0))
	P(I, "GarageScreen", Vector3.new(0.1, 2.2, 2.6), Vector3.new(-62, FL + 4.6, -100), Color3.fromRGB(255, 210, 90), M.Neon, { decor = true })
	interact(gterm, "PoliceGarage", "Fuhrpark", "Police Garage", 10)
	marker("PoliceGaragePark", Vector3.new(-36, Y + 3, -86), "PoliceGaragePark")
	for i = 0, 3 do
		P(I, "ToolCabinet", Vector3.new(6, 7, 2.4), Vector3.new(-50 + i * 12, FL + 3.5, -144.5), Color3.fromRGB(180, 30, 30), M.Metal)
	end

	-- Deckenleuchten
	for _, p in ipairs({ { -226, -46 }, { -146, -46 }, { -86, -46 }, { -236, -110 }, { -186, -110 }, { -141, -110 }, { -91, -110 }, { -36, -60 }, { -36, -120 }, { -166, -71 } }) do
		local l = P(I, "CeilingLight", Vector3.new(8, 0.3, 4), Vector3.new(p[1], FL + H - 0.2, p[2]), Color3.fromRGB(255, 248, 236), M.Neon, { decor = true })
		local sl = Instance.new("SurfaceLight")
		sl.Face = Enum.NormalId.Bottom
		sl.Range = 26
		sl.Brightness = 1.6
		sl.Angle = 110
		sl.Shadows = false
		sl.Parent = l
	end

	local n = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	local doors, points = 0, 0
	for _, d in ipairs(root:GetDescendants()) do
		if CS:HasTag(d, "Interactable") then
			if d:GetAttribute("InteractType") == "Door" then
				doors += 1
			else
				points += 1
			end
		end
	end
	return string.format("Polizeistation: %d Parts, %d Tueren, %d Interaktionspunkte", n, doors, points)
end
