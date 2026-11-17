-- Schritt 33 (Prompt 14): Hafen (Port Meridian) aufwerten.
-- * Fahrwege im Containerterminal: Ringstrasse am Tor, Hauptachsen zwischen den Containerreihen, Querspangen,
--   Lagerstrasse an den Hallen, Kaistrasse am Wasser - dunkler Asphalt, gelbe Mittellinie, weisse Randlinien,
--   Haltelinien an den Einmuendungen.
-- * Funktionierende Schranken am Terminaltor (Einfahrt/Ausfahrt): Pfosten mit Antriebskasten, rot-weisser Baum,
--   Ampel rot/gruen; oeffnet automatisch, wenn ein Spieler (zu Fuss oder im Fahrzeug) heranfaehrt (GateService).
-- * Beschilderung (Tempo 15, Wegweiser), Leitplanken an der Lagerstrasse, Bodenmarkierung "STOP".
-- Idempotent: workspace.Map.Harbor14. Die alten starren Schrankenbaeume werden nach ServerStorage.Backup_Harbor verschoben.
return function(Kit)
	local CollectionService = game:GetService("CollectionService")
	local ServerStorage = game:GetService("ServerStorage")
	local rgb = Color3.fromRGB
	local M = Enum.Material
	local DECOR = { decor = true }

	local root = workspace.Map:FindFirstChild("Harbor14")
	if root then
		root:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "Harbor14"

	local Y = 0.2 -- Oberkante Terminalflaeche
	local ASPH = rgb(54, 56, 60)
	local YEL = rgb(250, 200, 40)
	local WHITE = rgb(236, 236, 232)

	-- alte starre Schrankenbaeume sichern
	local gate = workspace.Map.Districts.PortMeridian.Buildings:FindFirstChild("TerminalGate")
	local backup = ServerStorage:FindFirstChild("Backup_Harbor") or Instance.new("Folder")
	backup.Name = "Backup_Harbor"
	backup.Parent = ServerStorage
	if gate then
		for _, p in ipairs(gate:GetChildren()) do
			if p.Name == "BoomArm" or p.Name == "BoomArmStripe" then
				p:SetAttribute("OrigPath", p:GetFullName())
				p.Parent = backup
			end
		end
	end

	----------------------------------------------------------------------------------------------------
	-- Fahrwege
	----------------------------------------------------------------------------------------------------
	local roads = Instance.new("Folder")
	roads.Name = "YardRoads"
	roads.Parent = root
	local NS = { 60, 240, 420, 600, 820 } -- Nord-Sued-Achsen (x)
	local EW = { 1218, 1474, 1744, 2014, 2284, 2500 } -- Ost-West-Achsen (z)
	local X0, X1, Z0, Z1 = 60, 820, 1218, 2500
	local W = 22

	local function nearCrossing(v, list)
		for _, c in ipairs(list) do
			if math.abs(v - c) < W / 2 + 6 then
				return true
			end
		end
		return false
	end

	local function lane(alongX, fixed, a, b)
		local len = b - a
		local mid = (a + b) / 2
		local function at(t, off, h)
			if alongX then
				return CFrame.new(t, Y + h, fixed + off)
			else
				return CFrame.new(fixed + off, Y + h, t)
			end
		end
		local function sz(l, w, h)
			return alongX and Vector3.new(l, h, w) or Vector3.new(w, h, l)
		end
		Kit.part(roads, "LaneAsphalt", sz(len + W, W, 0.12), at(mid, 0, 0.06), ASPH, M.Asphalt, DECOR)
		for _, off in ipairs({ -W / 2 + 1, W / 2 - 1 }) do
			Kit.part(roads, "EdgeLine", sz(len + W - 2, 0.6, 0.14), at(mid, off, 0.08), WHITE, M.SmoothPlastic, DECOR)
		end
		-- gestrichelte Mittellinie, an Kreuzungen ausgespart
		local cross = alongX and NS or EW
		local t = a + 4
		while t < b - 4 do
			if not nearCrossing(t, cross) and not nearCrossing(t + 8, cross) then
				Kit.part(roads, "CenterDash", sz(8, 0.6, 0.14), at(t + 4, 0, 0.09), YEL, M.SmoothPlastic, DECOR)
			end
			t += 16
		end
		-- Haltelinien vor jeder Kreuzung
		for _, c in ipairs(cross) do
			if c > a + 1 and c < b - 1 then
				for _, s in ipairs({ -1, 1 }) do
					Kit.part(roads, "StopLine", sz(1, W / 2 - 1, 0.14), at(c + s * (W / 2 + 3), -s * (W / 4), 0.09), WHITE, M.SmoothPlastic, DECOR)
				end
			end
		end
	end
	for _, x in ipairs(NS) do
		lane(false, x, Z0, Z1)
	end
	for _, z in ipairs(EW) do
		lane(true, z, X0, X1)
	end
	-- Zufahrt vom Tor auf die Ringstrasse
	Kit.part(roads, "GateLink", Vector3.new(48, 0.12, 24), CFrame.new(480, Y + 0.06, 1205), ASPH, M.Asphalt, DECOR)
	for _, x in ipairs({ 456.6, 503.4 }) do
		Kit.part(roads, "EdgeLine", Vector3.new(0.6, 0.14, 24), CFrame.new(x, Y + 0.08, 1205), WHITE, M.SmoothPlastic, DECOR)
	end

	-- Bodenschrift "STOP" vor den Schranken (auf der Strasse vor dem Tor)
	local function floorText(cf, text, w)
		local p = Kit.part(roads, "FloorText", Vector3.new(6, 0.1, w), cf, rgb(0, 0, 0), M.SmoothPlastic, { decor = true, transp = 1 })
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Top
		g.PixelsPerStud = 10
		g.LightInfluence = 1
		g.Parent = p
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = WHITE
		t.Text = text
		t.Parent = g
	end
	floorText(CFrame.new(468, 0.3, 1176) * CFrame.Angles(0, math.pi / 2, 0), "STOP", 16)
	floorText(CFrame.new(492, Y + 0.2, 1222) * CFrame.Angles(0, -math.pi / 2, 0), "STOP", 16)

	----------------------------------------------------------------------------------------------------
	-- Schranken
	----------------------------------------------------------------------------------------------------
	local gates = Instance.new("Folder")
	gates.Name = "BoomGates"
	gates.Parent = root
	-- post: Fusspunkt des Pfostens; dir: Richtung, in die der Baum zeigt (+1 = +X, -1 = -X); zone: Bereich (Mitte, Groesse)
	local function boomGate(name, post, dir, len, zoneCF, zoneSize)
		local m = Instance.new("Model")
		m.Name = name
		local base = CFrame.new(post)
		Kit.part(m, "Foot", Vector3.new(2.6, 0.6, 2.6), base * CFrame.new(0, 0.3, 0), rgb(150, 150, 150), M.Concrete)
		Kit.part(m, "Housing", Vector3.new(1.8, 3.6, 1.8), base * CFrame.new(0, 2.4, 0), rgb(240, 200, 40), M.Metal)
		Kit.part(m, "HousingTop", Vector3.new(2, 0.3, 2), base * CFrame.new(0, 4.35, 0), rgb(40, 40, 44), M.Metal, DECOR)
		-- Ampel am Pfosten
		Kit.part(m, "LightBox", Vector3.new(1, 2.2, 0.8), base * CFrame.new(0, 5.6, 0), rgb(30, 30, 34), M.SmoothPlastic, DECOR)
		local red = Kit.part(m, "LightRed", Vector3.new(0.7, 0.7, 0.3), base * CFrame.new(0, 6.1, -0.45), rgb(255, 40, 40), M.Neon, DECOR)
		local green = Kit.part(m, "LightGreen", Vector3.new(0.7, 0.7, 0.3), base * CFrame.new(0, 5.1, -0.45), rgb(30, 60, 30), M.SmoothPlastic, DECOR)
		Kit.part(m, "LightRedBack", Vector3.new(0.7, 0.7, 0.3), base * CFrame.new(0, 6.1, 0.45), rgb(255, 40, 40), M.Neon, DECOR).Name = "LightRed"
		Kit.part(m, "LightGreenBack", Vector3.new(0.7, 0.7, 0.3), base * CFrame.new(0, 5.1, 0.45), rgb(30, 60, 30), M.SmoothPlastic, DECOR).Name = "LightGreen"
		-- Baum (eigenes Modell, dreht um das Gelenk)
		local arm = Instance.new("Model")
		arm.Name = "Arm"
		local hingeCF = base * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, dir > 0 and 0 or math.pi, 0)
		local hinge = Kit.part(arm, "Hinge", Vector3.new(0.6, 0.6, 0.6), hingeCF, rgb(40, 40, 44), M.Metal, DECOR)
		local seg = len / 8
		for i = 1, 8 do
			Kit.part(arm, "Boom", Vector3.new(seg, 0.5, 0.35), hingeCF * CFrame.new(1 + (i - 0.5) * seg, 0, 0), (i % 2 == 0) and rgb(220, 30, 30) or WHITE, M.SmoothPlastic, DECOR)
		end
		Kit.part(arm, "Counterweight", Vector3.new(1.4, 0.9, 0.6), hingeCF * CFrame.new(-0.8, 0, 0), rgb(60, 60, 64), M.Metal, DECOR)
		Kit.part(arm, "TipLight", Vector3.new(0.3, 0.3, 0.3), hingeCF * CFrame.new(len + 0.9, 0.3, 0), rgb(255, 60, 40), M.Neon, DECOR)
		arm.PrimaryPart = hinge
		arm.Parent = m
		-- Stuetze am Ende des Baums
		Kit.part(m, "Rest", Vector3.new(0.5, 3.4, 0.5), hingeCF * CFrame.new(len + 0.4, -1.9, 0), rgb(240, 200, 40), M.Metal, DECOR)
		local zone = Kit.part(m, "Zone", zoneSize, zoneCF, rgb(0, 255, 0), M.SmoothPlastic, { ghost = true, transp = 1, noShadow = true })
		zone.CanQuery = false
		m:SetAttribute("OpenAngle", 82)
		m.PrimaryPart = m.Foot
		CollectionService:AddTag(m, "BoomGate")
		m.Parent = gates
		return m, red, green
	end
	-- Einfahrt (aussen kommend, Fahrspur x 456..480), Ausfahrt (innen kommend, Fahrspur x 480..504)
	boomGate("GateIn", Vector3.new(455, Y, 1190), 1, 23, CFrame.new(468, 4, 1180), Vector3.new(26, 10, 60))
	boomGate("GateOut", Vector3.new(505, Y, 1202), -1, 23, CFrame.new(492, 4, 1215), Vector3.new(26, 10, 60))
	-- Mittelinsel zwischen den Spuren
	Kit.part(gates, "Island", Vector3.new(2, 0.6, 30), CFrame.new(480, Y + 0.3, 1196), rgb(200, 200, 196), M.Concrete)
	for _, z in ipairs({ 1182, 1210 }) do
		Kit.part(gates, "Bollard", Vector3.new(3, 1, 1), CFrame.new(480, Y + 1.5, z) * CFrame.Angles(0, 0, math.rad(90)), rgb(240, 200, 40), M.Metal, { shape = Enum.PartType.Cylinder })
	end

	----------------------------------------------------------------------------------------------------
	-- Schilder, Leitplanken, Beleuchtung
	----------------------------------------------------------------------------------------------------
	local deco = Instance.new("Folder")
	deco.Name = "Signs"
	deco.Parent = root
	local function signPost(pos, faceYaw, text, color, bg, w)
		local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(faceYaw), 0)
		Kit.part(deco, "SignPole", Vector3.new(0.4, 9, 0.4), cf * CFrame.new(0, 4.5, 0.3), rgb(150, 154, 160), M.Metal)
		Kit.sign(deco, cf * CFrame.new(0, 8, 0), Vector3.new(w or 10, 3, 0.3), text, color, bg)
	end
	signPost(Vector3.new(452, Y, 1150), 180, "TEMPO 15", rgb(20, 20, 24), WHITE, 9)
	signPost(Vector3.new(452, Y, 1160), 180, "TERMINAL · LAGER · KAI", WHITE, rgb(30, 90, 160), 16)
	signPost(Vector3.new(510, Y, 1240), 0, "AUSFAHRT", WHITE, rgb(30, 120, 70), 10)
	local DIR = { { 240, "TERMINAL A" }, { 420, "TERMINAL B" }, { 600, "TERMINAL C" }, { 820, "KAI · SCHIFFE" }, { 60, "LAGERHALLEN" } }
	for _, d in ipairs(DIR) do
		signPost(Vector3.new(d[1] + W / 2 + 3, Y, 1240), 180, d[2], WHITE, rgb(30, 90, 160), 12)
	end
	-- Leitplanke (Betonschutzwand) zwischen Lagerstrasse und Containerflaeche
	local x = 60 + W / 2 + 3
	local z = Z0 + W / 2 + 8
	while z < Z1 - W / 2 - 8 do
		if not nearCrossing(z, EW) and not nearCrossing(z + 12, EW) then
			Kit.part(deco, "JerseyBarrier", Vector3.new(1.6, 2.6, 11.5), CFrame.new(x, Y + 1.3, z + 6), rgb(214, 212, 206), M.Concrete)
		end
		z += 12
	end
	-- Lichtmasten an den Kreuzungen der Hauptachsen
	for _, xx in ipairs({ 240, 600 }) do
		for _, zz in ipairs({ 1474, 2014 }) do
			local c = CFrame.new(xx + W / 2 + 2, Y, zz + W / 2 + 2)
			Kit.part(deco, "MastPole", Vector3.new(0.8, 26, 0.8), c * CFrame.new(0, 13, 0), rgb(150, 154, 160), M.Metal)
			local lamp = Kit.part(deco, "MastLamp", Vector3.new(3, 0.8, 1.6), c * CFrame.new(-1.2, 26, -1.2), rgb(255, 244, 220), M.Neon, DECOR)
			local l = Instance.new("SpotLight")
			l.Face = Enum.NormalId.Bottom
			l.Range = 50
			l.Angle = 110
			l.Brightness = 2
			l.Color = rgb(255, 236, 200)
			l.Parent = lamp
		end
	end

	root.Parent = workspace.Map
	local n = #root:GetDescendants()
	return string.format("Hafen: Fahrwege, 2 Schranken, Schilder - %d Objekte", n)
end
