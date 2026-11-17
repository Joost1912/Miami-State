-- MapKit: wiederverwendbare Bausteine fuer die MIAMI-STATE-Map.
-- Laeuft nur zur Bearbeitungszeit (Generator), liegt in ServerStorage.MapBuildTools.
-- Konventionen: +X = Osten, -Z = Norden, Fahrbahnoberflaeche Y = Kit.SURFACE_Y.
local CollectionService = game:GetService("CollectionService")

local Kit = {}
Kit.SURFACE_Y = 0.2

local M = Enum.Material
local C = {
	asphalt = Color3.fromRGB(44, 45, 48),
	asphaltHighway = Color3.fromRGB(58, 59, 62),
	sidewalk = Color3.fromRGB(201, 195, 183),
	curb = Color3.fromRGB(224, 220, 210),
	white = Color3.fromRGB(236, 236, 230),
	yellow = Color3.fromRGB(236, 184, 40),
	grass = Color3.fromRGB(84, 124, 56),
	concrete = Color3.fromRGB(188, 184, 174),
	barrier = Color3.fromRGB(200, 197, 190),
	metal = Color3.fromRGB(56, 58, 62),
	lamp = Color3.fromRGB(255, 212, 158),
	trunk = Color3.fromRGB(130, 110, 88),
	plaza = Color3.fromRGB(214, 206, 190),
}
Kit.C = C

Kit.SPECS = {
	Highway = { kind = "Highway", lanes = 3, laneW = 14, shoulder = 10, median = 6, sidewalk = 0, parking = 0, barrier = true },
	Boulevard = { kind = "Boulevard", lanes = 2, laneW = 14, median = 14, sidewalk = 14, parking = 0, planted = true },
	Street = { kind = "Street", lanes = 1, laneW = 14, median = 0, sidewalk = 12, parking = 10 },
	Residential = { kind = "Residential", lanes = 1, laneW = 13, median = 0, sidewalk = 10, parking = 0 },
	Ramp = { kind = "Ramp", lanes = 1, laneW = 16, shoulder = 6, median = 0, sidewalk = 0, parking = 0, oneWay = true, barrier = true },
	Bridge = { kind = "Bridge", lanes = 2, laneW = 14, median = 6, shoulder = 4, sidewalk = 14, parking = 0 },
}

function Kit.asphaltWidth(s)
	local n = s.oneWay and s.lanes or s.lanes * 2
	return n * s.laneW + (s.median or 0) + 2 * (s.parking or 0) + 2 * (s.shoulder or 0)
end

function Kit.totalWidth(s)
	return Kit.asphaltWidth(s) + 2 * (s.sidewalk or 0)
end

-- Grundbausteine -----------------------------------------------------------

local function apply(p, name, size, cf, color, material, o)
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o then
		if o.shape then
			p.Shape = o.shape
		end
		if o.decor then -- reine Optik: keine Kollision, keine Raycasts, kein Schatten
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
		end
		if o.ghost then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
		if o.noShadow then
			p.CastShadow = false
		end
		if o.refl then
			p.Reflectance = o.refl
		end
		if o.transp then
			p.Transparency = o.transp
		end
	end
	return p
end

function Kit.part(parent, name, size, cf, color, material, o)
	local p = apply(Instance.new("Part"), name, size, cf, color, material, o)
	p.Parent = parent
	return p
end

-- WedgePart: Schraege steigt Richtung lokales +Z an
function Kit.wedge(parent, name, size, cf, color, material, o)
	local p = apply(Instance.new("WedgePart"), name, size, cf, color, material, o)
	p.Parent = parent
	return p
end

function Kit.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Kit.folder(parent, name)
	local f = parent:FindFirstChild(name)
	if f then
		return f
	end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local CYL = Enum.PartType.Cylinder
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- Zylinderachse X -> Y

-- Strassenmoebel -------------------------------------------------------------

-- base: Fusspunkt am Boden, LookVector = Richtung des Auslegers
function Kit.streetLight(parent, base)
	local m = Kit.model(parent, "StreetLight")
	local h = 26
	Kit.part(m, "Pole", Vector3.new(h, 0.9, 0.9), base * CFrame.new(0, h / 2, 0) * UPRIGHT, C.metal, M.Metal, { shape = CYL, noShadow = true })
	Kit.part(m, "Arm", Vector3.new(0.5, 0.5, 9), base * CFrame.new(0, h - 0.4, -4.5), C.metal, M.Metal, { decor = true })
	Kit.part(m, "Head", Vector3.new(1.8, 0.6, 3.6), base * CFrame.new(0, h - 0.7, -9.6), C.metal, M.Metal, { decor = true })
	local glow = Kit.part(m, "Lamp", Vector3.new(1.3, 0.1, 3), base * CFrame.new(0, h - 1.05, -9.6), C.lamp, M.Neon, { decor = true })
	local l = Instance.new("SpotLight")
	l.Face = Enum.NormalId.Bottom
	l.Range = 50
	l.Angle = 120
	l.Brightness = 1.6
	l.Color = C.lamp
	l.Shadows = false
	l.Parent = glow
	CollectionService:AddTag(glow, "StreetLamp")
	return m
end

local SIGNAL_COLORS = {
	Red = Color3.fromRGB(255, 45, 35),
	Yellow = Color3.fromRGB(255, 170, 0),
	Green = Color3.fromRGB(40, 255, 120),
}

-- Ampel mit Mastarm. armDir = Richtung des Auslegers, faceDir = Blickrichtung der Signalgeber (zum Verkehr)
function Kit.signal(parent, polePos, armDir, faceDir, armLen, approach)
	local m = Kit.model(parent, "Signal_" .. approach)
	m:SetAttribute("Approach", approach)
	CollectionService:AddTag(m, "TrafficSignal")
	local h = 22
	Kit.part(m, "Pole", Vector3.new(h, 1.1, 1.1), CFrame.new(polePos + Vector3.new(0, h / 2, 0)) * UPRIGHT, C.metal, M.Metal, { shape = CYL })
	local armMid = polePos + Vector3.new(0, h - 1, 0) + armDir * (armLen / 2)
	Kit.part(m, "Arm", Vector3.new(0.7, 0.7, armLen), CFrame.lookAt(armMid, armMid + armDir), C.metal, M.Metal, { decor = true })
	for _, frac in ipairs({ 0.45, 0.88 }) do
		local p = polePos + Vector3.new(0, h - 4.4, 0) + armDir * (armLen * frac)
		local cf = CFrame.lookAt(p, p + faceDir)
		Kit.part(m, "Head", Vector3.new(2.2, 6.4, 1.6), cf, Color3.fromRGB(26, 26, 28), M.SmoothPlastic, { decor = true })
		for j, nm in ipairs({ "Red", "Yellow", "Green" }) do
			Kit.part(m, nm, Vector3.new(1.3, 1.3, 0.3), cf * CFrame.new(0, 2 - (j - 1) * 2, -0.85), SIGNAL_COLORS[nm], M.Neon, {
				decor = true,
				transp = (nm == "Red") and 0 or 0.85,
			})
		end
	end
	return m
end

function Kit.stopSign(parent, pos, faceDir)
	local m = Kit.model(parent, "StopSign")
	Kit.part(m, "Pole", Vector3.new(9, 0.35, 0.35), CFrame.new(pos + Vector3.new(0, 4.5, 0)) * UPRIGHT, C.metal, M.Metal, { shape = CYL, noShadow = true })
	local p = pos + Vector3.new(0, 9, 0)
	Kit.part(m, "Sign", Vector3.new(0.2, 3, 3), CFrame.lookAt(p, p + faceDir) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(200, 30, 30), M.SmoothPlastic, {
		shape = CYL,
		decor = true,
	})
	return m
end

-- Optimierte Palme: Klon einer vorgefertigten Union-Variante aus ServerStorage.MapAssets.Palms
-- (2 Instanzen statt ~19 Parts). Faellt auf Kit.palmParts zurueck, solange keine Vorlagen existieren.
local function palmTemplates()
	local a = game:GetService("ServerStorage"):FindFirstChild("MapAssets")
	local f = a and a:FindFirstChild("Palms")
	if f and #f:GetChildren() > 0 then
		return f:GetChildren()
	end
	return nil
end

function Kit.palm(parent, pos, height, seed)
	local tpl = palmTemplates()
	if not tpl then
		return Kit.palmParts(parent, pos, height, seed)
	end
	table.sort(tpl, function(a, b)
		return a.Name < b.Name
	end)
	local s = seed or math.floor(pos.X * 7 + pos.Z * 13)
	local rng = Random.new(s)
	local src = tpl[(math.abs(s) % #tpl) + 1]
	local m = src:Clone()
	m.Name = "Palm"
	if height then
		local scale = height / (src:GetAttribute("Height") or height)
		if math.abs(scale - 1) > 0.12 then
			m:ScaleTo(scale)
		end
	end
	m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	m.Parent = parent
	return m
end

-- Palme aus Einzelteilen (Quelle fuer die Union-Vorlagen)
function Kit.palmParts(parent, pos, height, seed)
	local rng = Random.new(seed or math.floor(pos.X * 7 + pos.Z * 13))
	height = height or rng:NextNumber(26, 40)
	local m = Kit.model(parent, "Palm")
	local cur = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local bend = math.rad(rng:NextNumber(2, 6))
	local segs = 4
	local segLen = height / segs
	for i = 1, segs do
		cur = cur * CFrame.Angles(bend, 0, 0)
		local d = 1.7 - i * 0.18
		Kit.part(m, "Trunk", Vector3.new(segLen + 0.4, d, d), cur * CFrame.new(0, segLen / 2, 0) * UPRIGHT, C.trunk, M.Wood, {
			shape = CYL,
			ghost = i > 1,
		})
		cur = cur * CFrame.new(0, segLen, 0)
	end
	local top = cur
	local fronds = 7
	for i = 1, fronds do
		local g = rng:NextInteger(0, 30)
		local col = Color3.fromRGB(60 + g, 112 + g, 40 + g // 2)
		local yaw = (i / fronds) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local b1 = top * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(rng:NextNumber(12, 28)), 0, 0)
		Kit.part(m, "Frond", Vector3.new(3.2, 0.2, 9), b1 * CFrame.new(0, 0, -4.5), col, M.Grass, { decor = true })
		local b2 = b1 * CFrame.new(0, 0, -9) * CFrame.Angles(math.rad(-rng:NextNumber(35, 55)), 0, 0)
		Kit.part(m, "Frond", Vector3.new(2.4, 0.2, 8), b2 * CFrame.new(0, 0, -4), col, M.Grass, { decor = true })
	end
	Kit.part(m, "Coconuts", Vector3.new(1.8, 1.8, 1.8), top * CFrame.new(0, -0.8, 0), Color3.fromRGB(96, 74, 40), M.SmoothPlastic, {
		shape = Enum.PartType.Ball,
		decor = true,
	})
	return m
end

-- Strassen -------------------------------------------------------------------

-- Gerader Strassenabschnitt. cf = Mitte der Fahrbahnoberflaeche, Fahrtrichtung = cf.LookVector.
-- o: name, swLen/swOff (Gehweg-Laenge/Versatz entlang Fahrtrichtung), mi0/mi1 (Mittelinsel-Abstand Anfang/Ende),
--    lights (Abstand), palms (Abstand), noBarrierL/noBarrierR, railings, deck (Brueckentraeger-Hoehe)
function Kit.roadStrip(parent, cf, length, s, o)
	o = o or {}
	local m = Kit.model(parent, o.name or ("Road_" .. s.kind))
	local aw = Kit.asphaltWidth(s)
	local sw = s.sidewalk or 0
	local med = s.median or 0
	local function at(x, y, z)
		return cf * CFrame.new(x, y, -z)
	end
	local asphaltCol = (s.kind == "Highway" or s.kind == "Ramp") and C.asphaltHighway or C.asphalt
	Kit.part(m, "Asphalt", Vector3.new(aw, 2, length), at(0, -1, 0), asphaltCol, M.Asphalt)

	if o.deck then
		Kit.part(m, "Deck", Vector3.new(aw + 2 * sw + 2, o.deck, length), at(0, -2 - o.deck / 2, 0), C.concrete, M.Concrete)
	end

	-- Gehwege mit Bordstein
	local swLen = o.swLen or length
	local swOff = o.swOff or 0
	if sw > 0 and swLen > 0.5 then
		for _, sg in ipairs({ -1, 1 }) do
			Kit.part(m, "Sidewalk", Vector3.new(sw, 2.6, swLen), at(sg * (aw / 2 + sw / 2), -0.7, swOff), C.sidewalk, M.Pavement)
			Kit.part(m, "Curb", Vector3.new(1, 0.06, swLen), at(sg * (aw / 2 + 0.5), 0.63, swOff), C.curb, M.Concrete, { decor = true })
		end
	end

	-- Markierungen
	local function line(x, w, z, len, col)
		Kit.part(m, "Line", Vector3.new(w, 0.06, len), at(x, 0.03, z), col, M.SmoothPlastic, { decor = true })
	end
	local function dashed(x)
		local period = 40
		local n = math.floor((length - 40) / period) + 1
		if length < 30 then
			return
		end
		local start = -((n - 1) * period) / 2
		for i = 0, n - 1 do
			line(x, 0.5, start + i * period, 10, C.white)
		end
	end

	if s.oneWay then
		local sh = s.shoulder or 0
		line(-aw / 2 + sh, 0.5, 0, length, C.yellow)
		line(aw / 2 - sh, 0.5, 0, length, C.white)
		for i = 1, s.lanes - 1 do
			dashed(-aw / 2 + sh + i * s.laneW)
		end
	else
		if med > 0 then
			local mi0, mi1 = o.mi0 or 2, o.mi1 or 2
			local mlen = length - mi0 - mi1
			local moff = (mi0 - mi1) / 2
			if s.planted and mlen > 4 then
				Kit.part(m, "Median", Vector3.new(med, 2.4, mlen), at(0, -0.7, moff), C.curb, M.Concrete)
				Kit.part(m, "MedianGrass", Vector3.new(med - 1.6, 0.2, mlen - 1.6), at(0, 0.5, moff), C.grass, M.Grass)
				if o.palms then
					local n = math.floor((mlen - 20) / o.palms)
					for i = 0, n do
						local z = moff - (n * o.palms) / 2 + i * o.palms
						local p = at(0, 0.6, z).Position
						Kit.palm(m, p, nil, math.floor(p.X * 3 + p.Z * 11))
					end
				end
			elseif not s.planted then
				Kit.part(m, "MedianBarrier", Vector3.new(2, 3.2, length), at(0, 1.6, 0), C.barrier, M.Concrete)
				line(-med / 2 + 0.4, 0.4, 0, length, C.yellow)
				line(med / 2 - 0.4, 0.4, 0, length, C.yellow)
			end
		else
			line(-0.45, 0.35, 0, length, C.yellow)
			line(0.45, 0.35, 0, length, C.yellow)
		end
		for _, sg in ipairs({ -1, 1 }) do
			local b = med / 2
			for i = 1, s.lanes - 1 do
				dashed(sg * (b + i * s.laneW))
			end
			if (s.parking or 0) > 0 or (s.shoulder or 0) > 0 then
				line(sg * (b + s.lanes * s.laneW), 0.45, 0, length, C.white)
			end
		end
	end

	-- Leitplanken / Gelaender
	if s.barrier then
		if not o.noBarrierL then
			Kit.part(m, "Barrier", Vector3.new(2, 3.4, length), at(-aw / 2 + 1, 1.7, 0), C.barrier, M.Concrete)
		end
		if not o.noBarrierR then
			Kit.part(m, "Barrier", Vector3.new(2, 3.4, length), at(aw / 2 - 1, 1.7, 0), C.barrier, M.Concrete)
		end
	end
	if o.railings then
		for _, sg in ipairs({ -1, 1 }) do
			Kit.part(m, "Railing", Vector3.new(1.2, 3.6, length), at(sg * (aw / 2 + sw - 0.6), 2.4, 0), C.barrier, M.Concrete)
		end
	end

	-- Strassenlaternen (abwechselnd links/rechts)
	if o.lights then
		local span = (sw > 0) and swLen or length
		local off = (sw > 0) and swOff or 0
		local n = math.floor((span - 20) / o.lights)
		if n >= 0 and span > 30 then
			for i = 0, n do
				local z = off - (n * o.lights) / 2 + i * o.lights
				local sg = (i % 2 == 0) and 1 or -1
				local x = (sw > 0) and sg * (aw / 2 + 2) or sg * (aw / 2 - 1)
				local y = (sw > 0) and 0.6 or 3.4
				local base = at(x, y, z)
				local inward = (base.Position - at(0, y, z).Position).Unit * -1
				Kit.streetLight(m, CFrame.lookAt(base.Position, base.Position + inward))
			end
		end
	end
	return m
end

-- Kreuzung (achsparallel). v = Nord-Sued-Strasse, h = Ost-West-Strasse
local function intersection(folder, c, y)
	local v, h = c.v, c.h
	local vs, hs = v.spec, h.spec
	local awV, awH = Kit.asphaltWidth(vs), Kit.asphaltWidth(hs)
	local swV, swH = vs.sidewalk or 0, hs.sidewalk or 0
	local medV, medH = vs.median or 0, hs.median or 0
	local x, z = c.x, c.z
	local m = Kit.model(folder, "X_" .. v.name .. "_" .. h.name)
	Kit.part(m, "Asphalt", Vector3.new(awV, 2, awH), CFrame.new(x, y - 1, z), C.asphalt, M.Asphalt)

	local N, S = v.z0 < z - 0.5, v.z1 > z + 0.5
	local W, E = h.x0 < x - 0.5, h.x1 > x + 0.5
	local twH = awH / 2 + swH

	-- Gehweg-Lueckenschluss bei fehlenden Armen (T-Kreuzung, Ecke)
	if swV > 0 then
		if not W then
			Kit.part(m, "Sidewalk", Vector3.new(swV, 2.6, 2 * twH), CFrame.new(x - awV / 2 - swV / 2, y - 0.7, z), C.sidewalk, M.Pavement)
		end
		if not E then
			Kit.part(m, "Sidewalk", Vector3.new(swV, 2.6, 2 * twH), CFrame.new(x + awV / 2 + swV / 2, y - 0.7, z), C.sidewalk, M.Pavement)
		end
	end
	if swH > 0 then
		if not N then
			Kit.part(m, "Sidewalk", Vector3.new(awV, 2.6, swH), CFrame.new(x, y - 0.7, z - awH / 2 - swH / 2), C.sidewalk, M.Pavement)
		end
		if not S then
			Kit.part(m, "Sidewalk", Vector3.new(awV, 2.6, swH), CFrame.new(x, y - 0.7, z + awH / 2 + swH / 2), C.sidewalk, M.Pavement)
		end
	end

	if swV == 0 or swH == 0 then
		return m
	end

	-- Zebrastreifen (Leiterform) + Haltelinien (Rechtsverkehr)
	local function mark(sx, sz, px, pz)
		Kit.part(m, "Line", Vector3.new(sx, 0.06, sz), CFrame.new(px, y + 0.03, pz), C.white, M.SmoothPlastic, { decor = true })
	end
	local halfV = awV / 2 - medV / 2
	local halfH = awH / 2 - medH / 2
	if N then
		local e = z - awH / 2
		mark(awV, 1, x, e - 2)
		mark(awV, 1, x, e - 12)
		mark(halfV, 1.2, x - medV / 2 - halfV / 2, e - 16)
	end
	if S then
		local e = z + awH / 2
		mark(awV, 1, x, e + 2)
		mark(awV, 1, x, e + 12)
		mark(halfV, 1.2, x + medV / 2 + halfV / 2, e + 16)
	end
	if E then
		local e = x + awV / 2
		mark(1, awH, e + 2, z)
		mark(1, awH, e + 12, z)
		mark(1.2, halfH, e + 16, z - medH / 2 - halfH / 2)
	end
	if W then
		local e = x - awV / 2
		mark(1, awH, e - 2, z)
		mark(1, awH, e - 12, z)
		mark(1.2, halfH, e - 16, z + medH / 2 + halfH / 2)
	end

	-- Ampeln an Kreuzungen mit Boulevard, sonst Stoppschilder
	local signalized = vs.kind == "Boulevard" or hs.kind == "Boulevard"
	local gy = y + 0.6
	if signalized then
		if N then
			Kit.signal(m, Vector3.new(x - awV / 2 - 2, gy, z - awH / 2 - 2), Vector3.xAxis, -Vector3.zAxis, halfV, "N")
		end
		if S then
			Kit.signal(m, Vector3.new(x + awV / 2 + 2, gy, z + awH / 2 + 2), -Vector3.xAxis, Vector3.zAxis, halfV, "S")
		end
		if E then
			Kit.signal(m, Vector3.new(x + awV / 2 + 2, gy, z - awH / 2 - 2), Vector3.zAxis, Vector3.xAxis, halfH, "E")
		end
		if W then
			Kit.signal(m, Vector3.new(x - awV / 2 - 2, gy, z + awH / 2 + 2), -Vector3.zAxis, -Vector3.xAxis, halfH, "W")
		end
	else
		if N then
			Kit.stopSign(m, Vector3.new(x - awV / 2 - 3, gy, z - awH / 2 - 16), -Vector3.zAxis)
		end
		if S then
			Kit.stopSign(m, Vector3.new(x + awV / 2 + 3, gy, z + awH / 2 + 16), Vector3.zAxis)
		end
		if E then
			Kit.stopSign(m, Vector3.new(x + awV / 2 + 16, gy, z - awH / 2 - 3), Vector3.xAxis)
		end
		if W then
			Kit.stopSign(m, Vector3.new(x - awV / 2 - 16, gy, z + awH / 2 + 3), -Vector3.xAxis)
		end
	end
	return m
end

-- Achsparalleles Strassennetz.
-- verticals:   { {name, x, z0, z1, spec}, ... }   (Nord-Sued)
-- horizontals: { {name, z, x0, x1, spec}, ... }   (Ost-West)
-- Kreuzungen, T-Kreuzungen und Gehweg-Ecken werden automatisch erzeugt.
function Kit.network(folder, verticals, horizontals, o)
	o = o or {}
	local y = o.y or Kit.SURFACE_Y
	local segFolder = Kit.folder(folder, "Segments")
	local xFolder = Kit.folder(folder, "Intersections")
	local vCuts, hCuts, crossings = {}, {}, {}
	for i in ipairs(verticals) do
		vCuts[i] = {}
	end
	for i in ipairs(horizontals) do
		hCuts[i] = {}
	end
	for vi, v in ipairs(verticals) do
		for hi, h in ipairs(horizontals) do
			if v.x >= h.x0 - 0.5 and v.x <= h.x1 + 0.5 and h.z >= v.z0 - 0.5 and h.z <= v.z1 + 0.5 then
				local c = { v = v, h = h, x = v.x, z = h.z }
				table.insert(crossings, c)
				table.insert(vCuts[vi], c)
				table.insert(hCuts[hi], c)
			end
		end
	end

	local function buildRoad(r, cuts, isV)
		local s = r.spec
		local p0 = isV and r.z0 or r.x0
		local p1 = isV and r.z1 or r.x1
		local function cpos(c)
			return isV and c.z or c.x
		end
		table.sort(cuts, function(a, b)
			return cpos(a) < cpos(b)
		end)
		local st = {}
		if #cuts == 0 or math.abs(cpos(cuts[1]) - p0) > 0.5 then
			table.insert(st, { pos = p0 })
		end
		for _, c in ipairs(cuts) do
			table.insert(st, { pos = cpos(c), c = c })
		end
		if #cuts == 0 or math.abs(cpos(cuts[#cuts]) - p1) > 0.5 then
			table.insert(st, { pos = p1 })
		end
		for i = 1, #st - 1 do
			local A, B = st[i], st[i + 1]
			local function cut(station, sign)
				if not station.c then
					return station.pos, station.pos
				end
				local other = isV and station.c.h.spec or station.c.v.spec
				local aw = Kit.asphaltWidth(other)
				-- Nord-Sued-Gehwege enden an der Gehweg-Aussenkante der Querstrasse,
				-- Ost-West-Gehwege laufen bis zur Fahrbahnkante und bilden so die Ecken.
				local swStop = isV and (aw / 2 + (other.sidewalk or 0)) or aw / 2
				return station.pos + sign * aw / 2, station.pos + sign * swStop
			end
			local a0, s0 = cut(A, 1)
			local a1, s1 = cut(B, -1)
			if a1 - a0 > 1 then
				local mid = (a0 + a1) / 2
				local cf
				if isV then
					cf = CFrame.lookAt(Vector3.new(r.x, y, mid), Vector3.new(r.x, y, mid + 1))
				else
					cf = CFrame.lookAt(Vector3.new(mid, y, r.z), Vector3.new(mid + 1, y, r.z))
				end
				Kit.roadStrip(segFolder, cf, a1 - a0, s, {
					name = "Road_" .. r.name .. "_" .. i,
					swLen = math.max(0, s1 - s0),
					swOff = (s0 + s1) / 2 - mid,
					mi0 = A.c and 20 or 2,
					mi1 = B.c and 20 or 2,
					lights = r.lights or o.lights,
					palms = r.palms or o.palms,
				})
			end
		end
	end

	for i, v in ipairs(verticals) do
		buildRoad(v, vCuts[i], true)
	end
	for i, h in ipairs(horizontals) do
		buildRoad(h, hCuts[i], false)
	end
	for _, c in ipairs(crossings) do
		intersection(xFolder, c, y)
	end
	return crossings
end

-- Grundstuecke ---------------------------------------------------------------

function Kit.plaza(parent, name, x0, z0, x1, z1, color, material)
	local y = Kit.SURFACE_Y
	return Kit.part(parent, name, Vector3.new(x1 - x0, 2.4, z1 - z0), CFrame.new((x0 + x1) / 2, y - 0.7 - 0.1, (z0 + z1) / 2), color or C.plaza, material or M.Pavement)
end

function Kit.parkingLot(parent, name, x0, z0, x1, z1, top)
	local m = Kit.model(parent, name)
	m:SetAttribute("Parking", true)
	local y = top or Kit.SURFACE_Y
	Kit.part(m, "Asphalt", Vector3.new(x1 - x0, 2, z1 - z0), CFrame.new((x0 + x1) / 2, y - 1 + 0.05, (z0 + z1) / 2), C.asphalt, M.Asphalt)
	-- Stellplatzreihen entlang X, Fahrgassen 28, Stellplatz 12 x 22
	local zRow = z0 + 4
	while zRow + 22 <= z1 - 4 do
		for xs = x0 + 6, x1 - 6, 12 do
			Kit.part(m, "Stall", Vector3.new(0.4, 0.06, 20), CFrame.new(xs, y + 0.08, zRow + 11), C.white, M.SmoothPlastic, { decor = true })
		end
		zRow += 22 + ((math.floor((zRow - z0) / 50) % 2 == 0) and 0 or 28)
	end
	return m
end

-- Gebaeude ---------------------------------------------------------------------

-- Glas-Hochhaus. pos = Fusspunkt (Bodenmitte)
function Kit.tower(parent, name, pos, w, d, h, st)
	st = st or {}
	local m = Kit.model(parent, name)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local glass = st.glass or Color3.fromRGB(70, 120, 135)
	local frame = st.frame or Color3.fromRGB(226, 226, 220)
	local base = CFrame.new(pos) * CFrame.Angles(0, st.rot or 0, 0)
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local podH = st.podium or 22
	Kit.part(m, "Lobby", Vector3.new(w + 4, podH - 4, d + 4), at(0, (podH - 4) / 2, 0), Color3.fromRGB(38, 50, 56), M.Glass, { refl = 0.15 })
	Kit.part(m, "Canopy", Vector3.new(w + 12, 4, d + 12), at(0, podH - 2, 0), frame, M.Concrete)

	local sections
	if h > 240 and st.setback ~= false then
		local h1 = math.floor((h - podH) * 0.62)
		sections = {
			{ w = w, d = d, y0 = podH, y1 = podH + h1 },
			{ w = w * 0.72, d = d * 0.72, y0 = podH + h1 + 2, y1 = h },
		}
	else
		sections = { { w = w, d = d, y0 = podH, y1 = h } }
	end
	local band = st.band or 14
	for i, s in ipairs(sections) do
		local sh = s.y1 - s.y0
		Kit.part(m, "Shaft" .. i, Vector3.new(s.w, sh, s.d), at(0, s.y0 + sh / 2, 0), glass, M.Glass, { refl = st.refl or 0.22 })
		for yb = s.y0 + band, s.y1 - 4, band do
			Kit.part(m, "Band", Vector3.new(s.w + 0.8, 1, s.d + 0.8), at(0, yb, 0), frame, M.Concrete, { decor = true })
		end
		for _, cx in ipairs({ -1, 1 }) do
			for _, cz in ipairs({ -1, 1 }) do
				Kit.part(m, "Column", Vector3.new(2.2, sh, 2.2), at(cx * s.w / 2, s.y0 + sh / 2, cz * s.d / 2), frame, M.Concrete, { decor = true })
			end
		end
		Kit.part(m, "Roof" .. i, Vector3.new(s.w + 1.6, 2, s.d + 1.6), at(0, s.y1 + 1, 0), frame, M.Concrete)
	end

	local top = sections[#sections]
	local crown = st.crown or Color3.fromRGB(80, 220, 255)
	local cw, cd = top.w + 1.8, top.d + 1.8
	local cy = h + 2.4
	Kit.part(m, "Crown", Vector3.new(cw, 0.8, 0.5), at(0, cy, -cd / 2), crown, M.Neon, { decor = true })
	Kit.part(m, "Crown", Vector3.new(cw, 0.8, 0.5), at(0, cy, cd / 2), crown, M.Neon, { decor = true })
	Kit.part(m, "Crown", Vector3.new(0.5, 0.8, cd), at(-cw / 2, cy, 0), crown, M.Neon, { decor = true })
	Kit.part(m, "Crown", Vector3.new(0.5, 0.8, cd), at(cw / 2, cy, 0), crown, M.Neon, { decor = true })
	Kit.part(m, "Mechanical", Vector3.new(top.w * 0.5, 10, top.d * 0.5), at(0, h + 7, 0), Color3.fromRGB(150, 150, 148), M.Concrete)
	if st.spire then
		Kit.part(m, "Spire", Vector3.new(st.spire, 1.4, 1.4), at(0, h + 12 + st.spire / 2, 0) * UPRIGHT, C.metal, M.Metal, { shape = CYL })
		Kit.part(m, "Beacon", Vector3.new(1.6, 1.6, 1.6), at(0, h + 12 + st.spire, 0), Color3.fromRGB(255, 40, 40), M.Neon, { decor = true, shape = Enum.PartType.Ball })
	end
	return m
end

-- Leuchtschrift auf einer Tafel. cf: Mitte der Tafel, Schrift auf der Vorderseite (-Z)
function Kit.sign(parent, cf, size, text, color, bg)
	local sg = Kit.part(parent, "Sign", size, cf, bg or Color3.fromRGB(30, 30, 34), M.SmoothPlastic, { decor = true })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 2.5
	gui.PixelsPerStud = 8 -- TextScaled ist auf 100 px begrenzt -> niedrige Dichte = grosse Schrift
	gui.Parent = sg
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = color
	t.Parent = gui
	return sg
end

-- Mittelhohes Gebaeude mit umlaufenden Fensterbaendern (1 Part pro Etage). Vorderseite = lokales -Z
function Kit.midrise(parent, name, pos, w, d, floors, st)
	st = st or {}
	local m = Kit.model(parent, name)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local base = CFrame.new(pos) * CFrame.Angles(0, st.rot or 0, 0)
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local fh = st.floorH or 13
	local H = floors * fh
	local body = st.color or Color3.fromRGB(232, 228, 220)
	local win = st.glass or Color3.fromRGB(48, 70, 82)
	Kit.part(m, "Body", Vector3.new(w, H, d), at(0, H / 2, 0), body, st.material or M.Concrete)
	for f = 0, floors - 1 do
		Kit.part(m, "Ribbon", Vector3.new(w + 0.4, fh * 0.42, d + 0.4), at(0, f * fh + fh * 0.55, 0), win, M.Glass, { decor = true, refl = 0.2 })
	end
	Kit.part(m, "Roof", Vector3.new(w + 1.2, 1.6, d + 1.2), at(0, H + 0.8, 0), st.trim or body, M.Concrete)
	if st.sign then
		Kit.sign(m, at(0, H - fh * 0.5, -d / 2 - 0.8), Vector3.new(math.min(w * 0.8, 120), fh * 0.6, 1), st.sign, st.signColor or Color3.new(1, 1, 1))
	end
	return m, H
end

-- Art-Deco-Gebaeude (Hotels, Strandbebauung). Vorderseite = lokales -Z (st.rot dreht)
function Kit.decoBuilding(parent, name, pos, w, d, floors, st)
	st = st or {}
	local m = Kit.model(parent, name)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local base = CFrame.new(pos) * CFrame.Angles(0, st.rot or 0, 0)
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local fh = 12
	local H = floors * fh + 4
	local body = st.color or Color3.fromRGB(246, 240, 228)
	local accent = st.accent or Color3.fromRGB(110, 205, 200)
	local neon = st.neon or Color3.fromRGB(255, 80, 180)
	local win = Color3.fromRGB(46, 70, 84)
	Kit.part(m, "Body", Vector3.new(w, H, d), at(0, H / 2, 0), body, M.Plaster)
	Kit.part(m, "Storefront", Vector3.new(w * 0.9, 9, 0.6), at(0, 5, -d / 2 - 0.2), win, M.Glass, { refl = 0.2, decor = true })
	Kit.part(m, "Awning", Vector3.new(w * 0.92, 0.6, 5), at(0, 10.5, -d / 2 - 2.5), accent, M.Fabric, { decor = true })
	for f = 1, floors - 1 do
		local y = f * fh + 6
		Kit.part(m, "Windows", Vector3.new(w * 0.84, 5, 0.6), at(0, y, -d / 2 - 0.2), win, M.Glass, { refl = 0.2, decor = true })
		Kit.part(m, "Ledge", Vector3.new(w * 0.88, 0.5, 2.4), at(0, y + 3, -d / 2 - 1.2), body, M.Plaster, { decor = true })
		Kit.part(m, "Windows", Vector3.new(w * 0.84, 5, 0.6), at(0, y, d / 2 + 0.2), win, M.Glass, { refl = 0.2, decor = true })
	end
	Kit.part(m, "Fin", Vector3.new(7, H + 16, 3.2), at(0, (H + 16) / 2, -d / 2 - 1.6), accent, M.Plaster)
	Kit.part(m, "FinNeon", Vector3.new(0.5, H + 8, 0.5), at(0, (H + 8) / 2 + 6, -d / 2 - 3.3), neon, M.Neon, { decor = true })
	Kit.part(m, "Parapet", Vector3.new(w + 1, 3, d + 1), at(0, H + 1.5, 0), accent, M.Plaster)
	Kit.part(m, "RoofNeon", Vector3.new(w + 1.2, 0.5, 0.5), at(0, H + 3.2, -d / 2 - 0.6), neon, M.Neon, { decor = true })
	if st.sign then
		Kit.sign(m, at(0, H + 8, -d / 2 + 2), Vector3.new(w * 0.5, 7, 1), st.sign, neon)
	end
	return m
end

-- Einfamilienhaus / Villa. cf = Grundstuecksmitte am Boden, LookVector zeigt zur Strasse
function Kit.house(parent, name, cf, st)
	st = st or {}
	local rng = Random.new(st.seed or 1)
	local m = Kit.model(parent, name)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local lotW, lotD = st.lotW or 70, st.lotD or 90
	local villa = st.villa
	local w = villa and lotW * 0.7 or lotW * 0.6
	local d = villa and lotD * 0.42 or lotD * 0.38
	local hh = villa and 24 or 13
	local zH = lotD * 0.06 -- Hausmitte leicht hinter Grundstuecksmitte
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	local pastel = {
		Color3.fromRGB(246, 236, 214), Color3.fromRGB(250, 214, 196), Color3.fromRGB(206, 232, 222),
		Color3.fromRGB(236, 226, 246), Color3.fromRGB(252, 244, 206), Color3.fromRGB(240, 240, 236),
	}
	local col = villa and Color3.fromRGB(244, 244, 240) or pastel[rng:NextInteger(1, #pastel)]
	local front = zH - d / 2
	Kit.part(m, "Body", Vector3.new(w, hh, d), at(0, hh / 2, zH), col, M.Plaster)
	if villa then
		-- moderne Villa: Flachdach mit Auskragung, Glasfront, Pool
		Kit.part(m, "Roof", Vector3.new(w + 6, 1.6, d + 6), at(0, hh + 0.8, zH), Color3.fromRGB(235, 235, 230), M.Concrete)
		Kit.part(m, "GlassFront", Vector3.new(w * 0.6, hh - 4, 0.5), at(-w * 0.12, hh / 2, front - 0.2), Color3.fromRGB(50, 74, 86), M.Glass, { refl = 0.25, decor = true })
		local back = zH + d / 2
		Kit.part(m, "PoolDeck", Vector3.new(w * 0.9, 0.4, 26), at(0, 0.2, back + 14), Color3.fromRGB(226, 220, 206), M.Limestone)
		Kit.part(m, "Pool", Vector3.new(w * 0.5, 0.3, 14), at(0, 0.45, back + 14), Color3.fromRGB(70, 200, 230), M.Glass, { transp = 0.15, refl = 0.3, decor = true })
	else
		local rh = 7
		local rd = d / 2 + 1.5
		local roofCol = Color3.fromRGB(176, 92, 64)
		Kit.wedge(m, "Roof", Vector3.new(w + 3, rh, rd), at(0, hh + rh / 2, zH - rd / 2), roofCol, M.ClayRoofTiles)
		Kit.wedge(m, "Roof", Vector3.new(w + 3, rh, rd), at(0, hh + rh / 2, zH + rd / 2) * CFrame.Angles(0, math.pi, 0), roofCol, M.ClayRoofTiles)
		Kit.part(m, "Window", Vector3.new(7, 5, 0.4), at(-w / 2 + 7, hh * 0.55, front - 0.2), Color3.fromRGB(50, 74, 86), M.Glass, { decor = true })
		Kit.part(m, "Window", Vector3.new(7, 5, 0.4), at(-w / 2 + 17, hh * 0.55, front - 0.2), Color3.fromRGB(50, 74, 86), M.Glass, { decor = true })
	end
	-- Garage + Einfahrt
	local gx = w / 2 - 9
	Kit.part(m, "GarageDoor", Vector3.new(13, 9, 0.4), at(gx, 4.5, front - 0.2), Color3.fromRGB(236, 236, 232), M.Metal, { decor = true })
	Kit.part(m, "Door", Vector3.new(4, 8, 0.4), at(-2, 4, front - 0.2), Color3.fromRGB(110, 72, 46), M.Wood, { decor = true })
	local drive = lotD / 2 + front -- Abstand Hausfront -> Grundstuecksvorderkante (front ist negativ)
	local driveLen = math.abs(-lotD / 2 - front)
	Kit.part(m, "Driveway", Vector3.new(14, 0.3, driveLen), at(gx, 0.15, front - driveLen / 2), C.concrete, M.Concrete)
	Kit.part(m, "Walkway", Vector3.new(4, 0.3, driveLen), at(-2, 0.15, front - driveLen / 2), C.concrete, M.Pavement)
	local _ = drive
	-- Hecke an der Grundstuecksseite
	Kit.part(m, "Hedge", Vector3.new(2.5, 4, lotD * 0.7), at(-lotW / 2 + 1.5, 2, lotD * 0.1), Color3.fromRGB(62, 100, 46), M.LeafyGrass)
	if st.palm then
		Kit.palm(m, at(-w / 2 + 2, 0, -lotD / 2 + 10).Position, nil, st.seed)
	end
	return m
end

-- =====================================================================================
-- Erweiterung Phase 2: Architekturvielfalt, Nachtleben, Hafen, Marina
-- =====================================================================================

-- Balken zwischen zwei Punkten
function Kit.beam(parent, name, p0, p1, t, color, material, o)
	local mid = (p0 + p1) / 2
	return Kit.part(parent, name, Vector3.new(t, t, (p1 - p0).Magnitude), CFrame.lookAt(mid, p1), color, material or M.Metal, o)
end

local WARM_WINDOWS = { Color3.fromRGB(255, 214, 150), Color3.fromRGB(255, 236, 200), Color3.fromRGB(205, 230, 255) }

-- Nachts leuchtende Fensterfelder (unsichtbar bis der DayNight-Controller sie einschaltet)
function Kit.litWindows(m, at, w, d, y0, y1, rng, density, maxFrac)
	maxFrac = maxFrac or 0.7
	for y = y0 + 6, y1 - 6, 12 do
		for _ = 1, 2 do -- bis zu zwei Fensterfelder pro Etage
		if rng:NextNumber() < density then
			local face = rng:NextInteger(1, 4)
			local frac = rng:NextNumber(0.2, maxFrac)
			local col = WARM_WINDOWS[rng:NextInteger(1, #WARM_WINDOWS)]
			local p
			if face <= 2 then
				local s = (face == 1) and -1 or 1
				local len = w * frac
				local off = rng:NextNumber(-(w - len) / 2, (w - len) / 2)
				p = Kit.part(m, "LitWindow", Vector3.new(len, 4, 0.3), at(off, y, s * (d / 2 + 0.3)), col, M.Neon, { decor = true })
			else
				local s = (face == 3) and -1 or 1
				local len = d * frac
				local off = rng:NextNumber(-(d - len) / 2, (d - len) / 2)
				p = Kit.part(m, "LitWindow", Vector3.new(0.3, 4, len), at(s * (w / 2 + 0.3), y, off), col, M.Neon, { decor = true })
			end
			p.Transparency = 1
			CollectionService:AddTag(p, "NightWindow")
		end
		end
	end
end

-- Dachterrasse. top: CFrame auf der Dachoberflaeche. kind: "pool" | "garden" | "bar"
function Kit.rooftop(m, top, w, d, kind, rng)
	local function at(x, y, z)
		return top * CFrame.new(x, y, z)
	end
	local glassC = Color3.fromRGB(180, 220, 230)
	for _, s in ipairs({ -1, 1 }) do
		Kit.part(m, "Railing", Vector3.new(w, 3.5, 0.3), at(0, 1.75, s * (d / 2 - 0.3)), glassC, M.Glass, { transp = 0.6 })
		Kit.part(m, "Railing", Vector3.new(0.3, 3.5, d), at(s * (w / 2 - 0.3), 1.75, 0), glassC, M.Glass, { transp = 0.6 })
	end
	if kind == "pool" then
		Kit.part(m, "Deck", Vector3.new(w - 2, 0.4, d - 2), at(0, 0.2, 0), Color3.fromRGB(230, 222, 204), M.Limestone)
		Kit.part(m, "Pool", Vector3.new(w * 0.55, 0.3, d * 0.32), at(0, 0.45, -d * 0.15), Color3.fromRGB(70, 205, 235), M.Glass, { transp = 0.15, refl = 0.3, decor = true })
		for i = -1, 1 do
			Kit.part(m, "Lounger", Vector3.new(3, 0.8, 8), at(i * 8, 0.8, d * 0.25), Color3.new(1, 1, 1), M.Plastic, { decor = true })
		end
	elseif kind == "garden" then
		Kit.part(m, "Lawn", Vector3.new(w - 2, 0.4, d - 2), at(0, 0.2, 0), Kit.C.grass, M.Grass)
		Kit.palm(m, at(-w * 0.25, 0.4, -d * 0.2).Position, 14)
		Kit.palm(m, at(w * 0.25, 0.4, d * 0.2).Position, 12)
		Kit.part(m, "Bench", Vector3.new(8, 1.6, 2.4), at(0, 1.2, 0), Color3.fromRGB(150, 110, 76), M.WoodPlanks, { decor = true })
	else -- bar
		local neonA = ({ Color3.fromRGB(255, 70, 170), Color3.fromRGB(60, 230, 255), Color3.fromRGB(180, 110, 255) })[rng and rng:NextInteger(1, 3) or 1]
		Kit.part(m, "Deck", Vector3.new(w - 2, 0.4, d - 2), at(0, 0.2, 0), Color3.fromRGB(120, 92, 70), M.WoodPlanks)
		Kit.part(m, "BarCounter", Vector3.new(w * 0.4, 4, 3), at(0, 2.4, -d * 0.3), Color3.fromRGB(30, 30, 34), M.Marble)
		Kit.part(m, "BarNeon", Vector3.new(w * 0.4, 0.3, 0.3), at(0, 4.5, -d * 0.3 - 1.6), neonA, M.Neon, { decor = true })
		for _, s in ipairs({ -1, 1 }) do
			Kit.part(m, "EdgeNeon", Vector3.new(w - 1, 0.3, 0.3), at(0, 3.6, s * (d / 2 - 0.4)), neonA, M.Neon, { decor = true })
		end
		for i = -1, 1 do
			Kit.part(m, "LoungeSofa", Vector3.new(10, 2, 4), at(i * 14, 1.4, d * 0.2), Color3.fromRGB(240, 236, 228), M.Fabric, { decor = true })
		end
	end
end

local function podiumLobby(m, at, w, d, podH, frame)
	Kit.part(m, "Lobby", Vector3.new(w + 4, podH - 4, d + 4), at(0, (podH - 4) / 2, 0), Color3.fromRGB(38, 50, 56), M.Glass, { refl = 0.15 })
	Kit.part(m, "Canopy", Vector3.new(w + 12, 4, d + 12), at(0, podH - 2, 0), frame, M.Concrete)
end

-- Gestaffeltes Hochhaus mit versetzten Ruecksprungen und Dachterrasse
function Kit.towerStepped(parent, name, pos, w, d, h, st)
	st = st or {}
	local rng = Random.new(st.seed or 1)
	local m = Kit.model(parent, name)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local glass = st.glass or Color3.fromRGB(46, 80, 104)
	local frame = st.frame or Color3.fromRGB(230, 230, 226)
	local base = CFrame.new(pos) * CFrame.Angles(0, st.rot or 0, 0)
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local podH = 20
	podiumLobby(m, at, w, d, podH, frame)
	local fr = { 0.5, 0.3, 0.2 }
	local sc = { 1, 0.78, 0.56 }
	local y = podH
	local shiftX = rng:NextInteger(-1, 1)
	local last
	for i = 1, 3 do
		local th = math.floor((h - podH) * fr[i])
		local sw, sd = w * sc[i], d * sc[i]
		local ox = shiftX * (w - sw) / 2
		local function atT(x, yy, z)
			return at(x + ox, yy, z)
		end
		Kit.part(m, "Shaft" .. i, Vector3.new(sw, th, sd), atT(0, y + th / 2, 0), glass, M.Glass, { refl = 0.18 })
		for yb = y + 16, y + th - 4, 16 do
			Kit.part(m, "Band", Vector3.new(sw + 0.8, 1.2, sd + 0.8), atT(0, yb, 0), frame, M.Concrete, { decor = true })
		end
		Kit.part(m, "Roof" .. i, Vector3.new(sw + 1.4, 1.6, sd + 1.4), atT(0, y + th + 0.8, 0), frame, M.Concrete)
		Kit.litWindows(m, atT, sw, sd, y, y + th, rng, 0.45)
		y = y + th + 1.6
		last = { sw = sw, sd = sd, ox = ox }
	end
	Kit.rooftop(m, at(last.ox, y, 0), last.sw, last.sd, st.roof or ({ "pool", "garden", "bar" })[rng:NextInteger(1, 3)], rng)
	return m
end

-- Runder Glasturm
function Kit.towerRound(parent, name, pos, dia, h, st)
	st = st or {}
	local rng = Random.new(st.seed or 1)
	local m = Kit.model(parent, name)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local glass = st.glass or Color3.fromRGB(60, 96, 104)
	local frame = st.frame or Color3.fromRGB(232, 232, 228)
	local base = CFrame.new(pos)
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local podH = 20
	podiumLobby(m, at, dia * 0.9, dia * 0.9, podH, frame)
	local sh = h - podH
	Kit.part(m, "Shaft", Vector3.new(sh, dia, dia), at(0, podH + sh / 2, 0) * UPRIGHT, glass, M.Glass, { shape = CYL, refl = 0.2 })
	for yb = podH + 14, h - 4, 14 do
		Kit.part(m, "Ring", Vector3.new(1, dia + 1, dia + 1), at(0, yb, 0) * UPRIGHT, frame, M.Concrete, { shape = CYL, decor = true })
	end
	Kit.part(m, "CrownNeon", Vector3.new(1.2, dia + 1.6, dia + 1.6), at(0, h - 2, 0) * UPRIGHT, st.crown or Color3.fromRGB(255, 80, 180), M.Neon, { shape = CYL, decor = true })
	Kit.part(m, "Roof", Vector3.new(2, dia + 2, dia + 2), at(0, h + 1, 0) * UPRIGHT, frame, M.Concrete, { shape = CYL })
	Kit.part(m, "Mechanical", Vector3.new(dia * 0.4, 8, dia * 0.4), at(0, h + 6, 0), Color3.fromRGB(150, 150, 148), M.Concrete)
	if st.spire then
		Kit.part(m, "Spire", Vector3.new(st.spire, 1.2, 1.2), at(0, h + 10 + st.spire / 2, 0) * UPRIGHT, Kit.C.metal, M.Metal, { shape = CYL })
	end
	Kit.litWindows(m, at, dia * 0.72, dia * 0.72, podH, h, rng, 0.4, 0.4)
	return m
end

-- Wohnturm mit umlaufenden Balkonplatten (deutlich anderer Look als Buerotuerme)
function Kit.towerResidential(parent, name, pos, w, d, h, st)
	st = st or {}
	local rng = Random.new(st.seed or 1)
	local m = Kit.model(parent, name)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local glass = st.glass or Color3.fromRGB(40, 70, 80)
	local slab = st.frame or Color3.fromRGB(246, 246, 242)
	local base = CFrame.new(pos) * CFrame.Angles(0, st.rot or 0, 0)
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local podH = 16
	podiumLobby(m, at, w, d, podH, slab)
	local sh = h - podH
	Kit.part(m, "Shaft", Vector3.new(w, sh, d), at(0, podH + sh / 2, 0), glass, M.Glass, { refl = 0.15 })
	for yb = podH + 11, h - 2, 11 do
		Kit.part(m, "Balcony", Vector3.new(w + 6, 0.9, d + 6), at(0, yb, 0), slab, M.Concrete, { decor = true })
	end
	for _, cx in ipairs({ -1, 1 }) do
		Kit.part(m, "Fin", Vector3.new(1.6, sh, d + 6.4), at(cx * (w / 2 + 2.2), podH + sh / 2, 0), slab, M.Concrete, { decor = true })
	end
	Kit.part(m, "Roof", Vector3.new(w + 6, 1.6, d + 6), at(0, h + 0.8, 0), slab, M.Concrete)
	Kit.rooftop(m, at(0, h + 1.6, 0), w + 4, d + 4, st.roof or "pool", rng)
	Kit.litWindows(m, at, w, d, podH, h, rng, 0.55)
	return m
end

-- Lagerhalle mit Laderampen. Vorderseite = lokales -Z
function Kit.warehouse(parent, name, pos, w, d, h, st)
	st = st or {}
	local m = Kit.model(parent, name)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local base = CFrame.new(pos) * CFrame.Angles(0, st.rot or 0, 0)
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local col = st.color or Color3.fromRGB(196, 192, 182)
	Kit.part(m, "Body", Vector3.new(w, h, d), at(0, h / 2, 0), col, M.Metal)
	Kit.part(m, "Plinth", Vector3.new(w + 0.4, 4, d + 0.4), at(0, 2, 0), Color3.fromRGB(150, 146, 138), M.Concrete)
	Kit.part(m, "Roof", Vector3.new(w + 2, 1.4, d + 2), at(0, h + 0.7, 0), Color3.fromRGB(120, 124, 128), M.Metal)
	Kit.part(m, "Stripe", Vector3.new(w + 0.3, 2, d + 0.3), at(0, h - 4, 0), st.accent or Color3.fromRGB(30, 90, 160), M.Metal, { decor = true })
	local n = math.max(1, math.floor(w / 24))
	for i = 0, n - 1 do
		local x = -w / 2 + 12 + i * ((w - 24) / math.max(1, n - 1))
		Kit.part(m, "DockDoor", Vector3.new(12, 13, 0.4), at(x, 6.5 + 4, -d / 2 - 0.2), Color3.fromRGB(226, 226, 222), M.Metal, { decor = true })
		Kit.part(m, "DockBumper", Vector3.new(12, 4, 3), at(x, 2, -d / 2 - 1.5), Color3.fromRGB(40, 40, 42), M.Rubber)
	end
	if st.sign then
		Kit.sign(m, at(0, h - 12, -d / 2 - 0.6), Vector3.new(math.min(w * 0.6, 90), 8, 0.6), st.sign, Color3.new(1, 1, 1), st.accent or Color3.fromRGB(30, 90, 160))
	end
	return m
end

local CONTAINER_COLORS = {
	Color3.fromRGB(180, 50, 40), Color3.fromRGB(30, 80, 150), Color3.fromRGB(40, 120, 70), Color3.fromRGB(210, 130, 40),
	Color3.fromRGB(110, 110, 116), Color3.fromRGB(230, 230, 226), Color3.fromRGB(140, 40, 90), Color3.fromRGB(60, 160, 170),
}
Kit.CONTAINER_COLORS = CONTAINER_COLORS

-- Containerblock: nx Container hintereinander (lokales X), nz nebeneinander (lokales Z)
function Kit.containerBlock(parent, name, origin, nx, nz, maxTier, rng)
	local m = Kit.model(parent, name)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	for ix = 0, nx - 1 do
		for iz = 0, nz - 1 do
			local tiers = rng:NextInteger(1, maxTier)
			for t = 1, tiers do
				Kit.part(m, "Container", Vector3.new(20.4, 8.8, 8.4), origin * CFrame.new(ix * 21, 4.4 + (t - 1) * 9, iz * 8.8),
					CONTAINER_COLORS[rng:NextInteger(1, #CONTAINER_COLORS)], M.Metal, { noShadow = t > 1 })
			end
		end
	end
	return m
end

-- Containerbruecke (Ship-to-Shore). base: Kaikante am Boden, LookVector zeigt aufs Wasser
function Kit.stsCrane(parent, name, base, st)
	st = st or {}
	local m = Kit.model(parent, name)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local col = st.color or Color3.fromRGB(200, 40, 36)
	local white = Color3.fromRGB(236, 236, 232)
	local function p(x, y, z)
		return (base * CFrame.new(x, y, z)).Position
	end
	local H = 80
	for _, x in ipairs({ -18, 18 }) do
		for _, z in ipairs({ 30, -10 }) do
			Kit.beam(m, "Leg", p(x, 0, z), p(x, H, z), 4, col)
		end
		Kit.beam(m, "Sill", p(x, H, 30), p(x, H, -10), 4, col)
		Kit.beam(m, "Wheels", p(x, 1.5, 34), p(x, 1.5, -14), 3, Color3.fromRGB(50, 50, 54))
	end
	Kit.beam(m, "Portal", p(-18, H, 30), p(18, H, 30), 4, col)
	Kit.beam(m, "Portal", p(-18, H, -10), p(18, H, -10), 4, col)
	Kit.beam(m, "Portal", p(-18, H * 0.45, 30), p(18, H * 0.45, 30), 3, col)
	for _, x in ipairs({ -6, 6 }) do
		Kit.beam(m, "Boom", p(x, H + 14, 60), p(x, H + 14, -150), 5, col)
		Kit.beam(m, "Apex", p(x, H, 18), p(x, H + 48, 10), 3, col)
		Kit.beam(m, "Apex", p(x, H, -6), p(x, H + 48, 10), 3, col)
		Kit.beam(m, "Stay", p(x, H + 48, 10), p(x, H + 14, -150), 1, white, M.Metal, { decor = true })
		Kit.beam(m, "Stay", p(x, H + 48, 10), p(x, H + 14, 60), 1, white, M.Metal, { decor = true })
	end
	Kit.part(m, "MachineHouse", Vector3.new(18, 10, 22), base * CFrame.new(0, H + 22, 44), white, M.Metal)
	Kit.part(m, "Trolley", Vector3.new(16, 5, 10), base * CFrame.new(0, H + 9, -70), white, M.Metal)
	Kit.part(m, "Cabin", Vector3.new(6, 5, 6), base * CFrame.new(0, H + 4.5, -64), Color3.fromRGB(40, 60, 70), M.Glass, { decor = true })
	Kit.beam(m, "Cable", p(0, H + 7, -70), p(0, 30, -70), 0.4, Color3.fromRGB(30, 30, 30), M.Metal, { decor = true })
	Kit.part(m, "Spreader", Vector3.new(4, 2, 21), base * CFrame.new(0, 29, -70) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(240, 190, 40), M.Metal, { decor = true })
	local lamp = Kit.part(m, "WarnLight", Vector3.new(1.5, 1.5, 1.5), base * CFrame.new(0, H + 50, 10), Color3.fromRGB(255, 40, 30), M.Neon, { decor = true, shape = Enum.PartType.Ball })
	local _ = lamp
	return m
end

-- Portalkran im Containerlager (RTG). base: Mitte am Boden, Spannweite entlang lokalem X
function Kit.rtgCrane(parent, name, base, span)
	local m = Kit.model(parent, name)
	local col = Color3.fromRGB(240, 190, 40)
	local function p(x, y, z)
		return (base * CFrame.new(x, y, z)).Position
	end
	local H = 42
	for _, x in ipairs({ -span / 2, span / 2 }) do
		for _, z in ipairs({ -10, 10 }) do
			Kit.beam(m, "Leg", p(x, 0, z), p(x, H, z), 2.4, col)
		end
		Kit.beam(m, "Sill", p(x, 2, -12), p(x, 2, 12), 2.4, Color3.fromRGB(50, 50, 54))
	end
	Kit.beam(m, "Girder", p(-span / 2, H, -10), p(span / 2, H, -10), 3, col)
	Kit.beam(m, "Girder", p(-span / 2, H, 10), p(span / 2, H, 10), 3, col)
	Kit.part(m, "Cabin", Vector3.new(6, 5, 8), base * CFrame.new(span / 2 - 6, H - 5, 0), Color3.fromRGB(236, 236, 232), M.Metal)
	return m
end

-- Spitzer Bug aus zwei Keilen (Draufsicht). cf: Mitte des Bugs, LookVector = Fahrtrichtung
local function pointedBow(m, cf, width, height, length, color, material)
	Kit.wedge(m, "Bow", Vector3.new(height, width / 2, length), cf * CFrame.new(-width / 4, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	Kit.wedge(m, "Bow", Vector3.new(height, width / 2, length), cf * CFrame.new(width / 4, 0, 0) * CFrame.Angles(0, 0, math.rad(-90)), color, material)
end

-- Containerschiff. cf: Mitte auf Wasserlinie, LookVector = Bug
function Kit.cargoShip(parent, name, cf, L, B, st)
	st = st or {}
	local rng = Random.new(st.seed or 3)
	local m = Kit.model(parent, name)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local hullC = st.hull or Color3.fromRGB(30, 40, 60)
	local hl = L * 0.82
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	Kit.part(m, "Hull", Vector3.new(B, 34, hl), at(0, -7, L * 0.09), hullC, M.Metal)
	Kit.part(m, "Boot", Vector3.new(B + 0.4, 6, hl + 0.2), at(0, -9, L * 0.09), Color3.fromRGB(160, 40, 36), M.Metal, { decor = true })
	pointedBow(m, at(0, -7, L * 0.09 - hl / 2 - L * 0.09), B, 34, L * 0.18, hullC, M.Metal)
	local deckY = 10
	local stern = L * 0.09 + hl / 2
	Kit.part(m, "Superstructure", Vector3.new(B * 0.8, 44, 24), at(0, deckY + 22, stern - 24), Color3.fromRGB(240, 240, 236), M.Metal)
	Kit.part(m, "BridgeWindows", Vector3.new(B * 0.82, 4, 24.4), at(0, deckY + 40, stern - 24), Color3.fromRGB(40, 60, 70), M.Glass, { decor = true })
	Kit.part(m, "BridgeWings", Vector3.new(B + 4, 2, 10), at(0, deckY + 38, stern - 34), Color3.fromRGB(240, 240, 236), M.Metal)
	Kit.part(m, "Funnel", Vector3.new(10, 18, 12), at(0, deckY + 53, stern - 14), st.funnel or Color3.fromRGB(230, 120, 30), M.Metal)
	local z = -L / 2 + L * 0.2
	while z < stern - 44 do
		local tiers = rng:NextInteger(2, 5)
		for t = 1, tiers do
			Kit.part(m, "ContainerRow", Vector3.new(B - 6, 8.8, 20.4), at(0, deckY + 4.4 + (t - 1) * 9, z),
				CONTAINER_COLORS[rng:NextInteger(1, #CONTAINER_COLORS)], M.Metal, { noShadow = t > 1 })
		end
		z += 22
	end
	if st.name then
		Kit.sign(m, at(B / 2 + 0.6, 2, stern - 8) * CFrame.Angles(0, -math.pi / 2, 0), Vector3.new(40, 5, 0.4), st.name, Color3.new(1, 1, 1), hullC)
	end
	return m
end

-- Luxusyacht. cf: Mitte auf Wasserlinie, LookVector = Bug
function Kit.yacht(parent, name, cf, L, st)
	st = st or {}
	local m = Kit.model(parent, name)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local B = L * 0.22
	local white = Color3.fromRGB(248, 248, 246)
	local win = Color3.fromRGB(30, 40, 50)
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	local hl = L * 0.75
	Kit.part(m, "Hull", Vector3.new(B, 8, hl), at(0, 1, L * 0.125), st.hull or white, M.SmoothPlastic)
	pointedBow(m, at(0, 1, L * 0.125 - hl / 2 - L * 0.125), B, 8, L * 0.25, st.hull or white, M.SmoothPlastic)
	Kit.part(m, "HullStripe", Vector3.new(B + 0.2, 1.2, hl + 0.1), at(0, 3, L * 0.125), st.stripe or Color3.fromRGB(30, 50, 90), M.SmoothPlastic, { decor = true })
	Kit.part(m, "Cabin1", Vector3.new(B * 0.86, 6, L * 0.5), at(0, 8, L * 0.12), white, M.SmoothPlastic)
	Kit.part(m, "Windows1", Vector3.new(B * 0.88, 2.4, L * 0.46), at(0, 8.5, L * 0.12), win, M.Glass, { decor = true, refl = 0.3 })
	Kit.part(m, "Cabin2", Vector3.new(B * 0.7, 5, L * 0.3), at(0, 13.5, L * 0.16), white, M.SmoothPlastic)
	Kit.part(m, "Windows2", Vector3.new(B * 0.72, 2.2, L * 0.28), at(0, 14, L * 0.16), win, M.Glass, { decor = true, refl = 0.3 })
	Kit.part(m, "SwimPlatform", Vector3.new(B, 0.6, 4), at(0, -1.5, L * 0.125 + hl / 2 + 2), Color3.fromRGB(170, 132, 96), M.WoodPlanks)
	if L >= 60 then
		Kit.part(m, "Flybridge", Vector3.new(B * 0.6, 3.5, L * 0.16), at(0, 17.8, L * 0.2), white, M.SmoothPlastic)
		Kit.part(m, "Radar", Vector3.new(0.8, 6, 0.8), at(0, 22, L * 0.2), white, M.Metal, { decor = true })
	end
	return m
end

function Kit.motorboat(parent, name, cf, L, color)
	local m = Kit.model(parent, name)
	local B = L * 0.32
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	Kit.part(m, "Hull", Vector3.new(B, 4, L * 0.7), at(0, 0.5, L * 0.15), Color3.new(1, 1, 1), M.SmoothPlastic)
	pointedBow(m, at(0, 0.5, L * 0.15 - L * 0.35 - L * 0.15), B, 4, L * 0.3, Color3.new(1, 1, 1), M.SmoothPlastic)
	Kit.part(m, "Stripe", Vector3.new(B + 0.2, 0.8, L * 0.7), at(0, 1.6, L * 0.15), color, M.SmoothPlastic, { decor = true })
	Kit.part(m, "Windscreen", Vector3.new(B * 0.8, 1.6, 0.3), at(0, 3.4, -L * 0.05) * CFrame.Angles(math.rad(-30), 0, 0), Color3.fromRGB(40, 60, 70), M.Glass, { decor = true, transp = 0.3 })
	Kit.part(m, "Seats", Vector3.new(B * 0.6, 1.4, L * 0.25), at(0, 3, L * 0.2), Color3.fromRGB(236, 230, 214), M.Fabric, { decor = true })
	return m
end

-- Absperrkordel (Club-Eingang). Von p0 nach p1, Pfosten im Abstand ~4
function Kit.velvetRope(parent, p0, p1, ropeColor)
	local m = Kit.model(parent, "VelvetRope")
	local n = math.max(1, math.floor((p1 - p0).Magnitude / 4))
	local gold = Color3.fromRGB(212, 170, 70)
	local prev
	for i = 0, n do
		local p = p0:Lerp(p1, i / n)
		Kit.part(m, "Post", Vector3.new(3, 0.5, 0.5), CFrame.new(p + Vector3.new(0, 1.5, 0)) * UPRIGHT, gold, M.Foil, { shape = CYL, decor = true })
		if prev then
			Kit.beam(m, "Rope", prev + Vector3.new(0, 2.6, 0), p + Vector3.new(0, 2.6, 0), 0.3, ropeColor or Color3.fromRGB(160, 20, 40), M.Fabric, { decor = true })
		end
		prev = p
	end
	return m
end

-- Aussenbestuhlung: Tische mit Schirmen. cf: Mitte, Reihen entlang lokalem X
function Kit.outdoorSeating(parent, cf, n, umbrellaColor)
	local m = Kit.model(parent, "OutdoorSeating")
	for i = 0, n - 1 do
		local p = (cf * CFrame.new((i - (n - 1) / 2) * 9, 0, 0)).Position
		Kit.part(m, "Table", Vector3.new(0.4, 4, 4), CFrame.new(p + Vector3.new(0, 2.6, 0)) * UPRIGHT, Color3.fromRGB(240, 240, 236), M.Metal, { shape = CYL })
		Kit.part(m, "Chair", Vector3.new(2, 2, 2), CFrame.new(p + Vector3.new(-3, 1, 0)), Color3.fromRGB(40, 40, 44), M.Metal, { decor = true })
		Kit.part(m, "Chair", Vector3.new(2, 2, 2), CFrame.new(p + Vector3.new(3, 1, 0)), Color3.fromRGB(40, 40, 44), M.Metal, { decor = true })
		if umbrellaColor then
			Kit.part(m, "Umbrella", Vector3.new(0.4, 9, 9), CFrame.new(p + Vector3.new(0, 8, 0)) * UPRIGHT, umbrellaColor, M.Fabric, { shape = CYL, decor = true })
			Kit.part(m, "UmbrellaPole", Vector3.new(8, 0.3, 0.3), CFrame.new(p + Vector3.new(0, 4, 0)) * UPRIGHT, Color3.new(1, 1, 1), M.Metal, { shape = CYL, decor = true })
		end
	end
	return m
end

-- Nachtclub. Vorderseite = lokales -Z
function Kit.nightclub(parent, name, pos, w, d, h, st)
	st = st or {}
	local rng = Random.new(st.seed or 5)
	local m = Kit.model(parent, name)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local base = CFrame.new(pos) * CFrame.Angles(0, st.rot or 0, 0)
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local neon = st.neon or Color3.fromRGB(255, 60, 180)
	local neon2 = st.neon2 or Color3.fromRGB(60, 230, 255)
	local body = st.color or Color3.fromRGB(26, 24, 32)
	local f = -d / 2
	Kit.part(m, "Body", Vector3.new(w, h, d), at(0, h / 2, 0), body, M.Slate)
	-- Neon-Rahmen der Fassade
	Kit.part(m, "NeonTop", Vector3.new(w, 0.8, 0.6), at(0, h - 1, f - 0.4), neon, M.Neon, { decor = true })
	Kit.part(m, "NeonL", Vector3.new(0.8, h - 2, 0.6), at(-w / 2 + 0.6, h / 2, f - 0.4), neon, M.Neon, { decor = true })
	Kit.part(m, "NeonR", Vector3.new(0.8, h - 2, 0.6), at(w / 2 - 0.6, h / 2, f - 0.4), neon, M.Neon, { decor = true })
	for i = 1, 3 do
		Kit.part(m, "NeonStripe", Vector3.new(w * 0.8, 0.4, 0.5), at(0, h * 0.45 + i * 3.2, f - 0.4), neon2, M.Neon, { decor = true })
	end
	-- Schild, Vordach, Tuer
	Kit.sign(m, at(0, h * 0.78, f - 0.8), Vector3.new(math.min(w * 0.7, 80), h * 0.22, 0.6), st.sign or "CLUB", neon, Color3.fromRGB(12, 12, 16))
	Kit.part(m, "Canopy", Vector3.new(w * 0.4, 1, 14), at(-w * 0.15, 15, f - 7), Color3.fromRGB(16, 16, 20), M.Metal)
	Kit.part(m, "CanopyNeon", Vector3.new(w * 0.4, 0.3, 14), at(-w * 0.15, 14.4, f - 7), neon2, M.Neon, { decor = true })
	Kit.part(m, "Doors", Vector3.new(12, 11, 0.4), at(-w * 0.15, 6, f - 0.2), Color3.fromRGB(20, 20, 24), M.Glass, { decor = true, refl = 0.3 })
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Front
	light.Color = neon
	light.Brightness = 3
	light.Range = 24
	light.Angle = 120
	light.Parent = m:FindFirstChild("NeonTop")
	-- Warteschlange + VIP-Eingang
	local q0 = at(-w * 0.15 - 8, 0.2, f - 4).Position
	Kit.velvetRope(m, q0, at(-w * 0.15 - 8, 0.2, f - 34).Position)
	Kit.velvetRope(m, at(-w * 0.15 - 2, 0.2, f - 4).Position, at(-w * 0.15 - 2, 0.2, f - 34).Position)
	local vipX = w * 0.32
	Kit.part(m, "VIPCanopy", Vector3.new(14, 1, 10), at(vipX, 13, f - 5), Color3.fromRGB(212, 170, 70), M.Foil)
	Kit.sign(m, at(vipX, 17, f - 0.8), Vector3.new(12, 4, 0.5), "VIP", Color3.fromRGB(255, 215, 110), Color3.fromRGB(12, 12, 16))
	Kit.velvetRope(m, at(vipX - 6, 0.2, f - 3).Position, at(vipX - 6, 0.2, f - 16).Position, Color3.fromRGB(212, 170, 70))
	Kit.part(m, "VIPCarpet", Vector3.new(8, 0.1, 18), at(vipX, 0.25, f - 9), Color3.fromRGB(150, 20, 40), M.Fabric, { decor = true })
	-- Aussenbereich
	Kit.outdoorSeating(m, at(-w * 0.15 - 30, 0.2, f - 22), 3, nil)
	if st.rooftop then
		Kit.rooftop(m, at(0, h, 0), w, d, "bar", rng)
		Kit.part(m, "DJBooth", Vector3.new(14, 4, 6), at(0, h + 2.2, d * 0.32), Color3.fromRGB(20, 20, 24), M.Metal)
		Kit.part(m, "DJNeon", Vector3.new(14, 0.4, 0.4), at(0, h + 4.4, d * 0.32 - 3.1), neon2, M.Neon, { decor = true })
	end
	return m
end

-- Casino-Resort (rein fiktives Spielweltgebaeude). Vorderseite = lokales -Z
function Kit.casino(parent, name, pos, w, d, h, st)
	st = st or {}
	local m = Kit.model(parent, name)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local base = CFrame.new(pos) * CFrame.Angles(0, st.rot or 0, 0)
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local gold = Color3.fromRGB(214, 172, 74)
	local cream = Color3.fromRGB(244, 236, 220)
	local f = -d / 2
	Kit.part(m, "Hall", Vector3.new(w, h, d), at(0, h / 2, 0), cream, M.Marble)
	Kit.part(m, "GoldBand", Vector3.new(w + 0.6, 3, d + 0.6), at(0, h - 2, 0), gold, M.Foil)
	Kit.part(m, "Entrance", Vector3.new(w * 0.4, h * 0.6, 0.6), at(0, h * 0.3, f - 0.2), Color3.fromRGB(30, 24, 20), M.Glass, { refl = 0.3, decor = true })
	Kit.part(m, "PorteCochere", Vector3.new(w * 0.5, 2.4, 36), at(0, 20, f - 18), cream, M.Marble)
	Kit.part(m, "PorteNeon", Vector3.new(w * 0.5, 0.4, 36), at(0, 18.6, f - 18), gold, M.Neon, { decor = true })
	for _, x in ipairs({ -w * 0.22, w * 0.22 }) do
		for _, z in ipairs({ f - 6, f - 32 }) do
			Kit.part(m, "Column", Vector3.new(19, 2.4, 2.4), at(x, 9.5, z) * UPRIGHT, gold, M.Foil, { shape = CYL })
		end
	end
	local pillarCols = { Color3.fromRGB(255, 60, 170), Color3.fromRGB(60, 230, 255), Color3.fromRGB(255, 200, 60), Color3.fromRGB(180, 100, 255) }
	for i = 1, 4 do
		local x = -w / 2 + i * w / 5
		Kit.part(m, "NeonPillar", Vector3.new(1.2, h - 6, 1.2), at(x, h / 2, f - 0.8), pillarCols[i], M.Neon, { decor = true })
	end
	Kit.sign(m, at(0, h + 9, f + 4), Vector3.new(math.min(w * 0.75, 140), 16, 1), st.sign or "CASINO", gold, Color3.fromRGB(14, 12, 10))
	-- Brunnen vor dem Eingang
	Kit.part(m, "Fountain", Vector3.new(2, 36, 36), at(0, 1, f - 62) * UPRIGHT, cream, M.Marble, { shape = CYL })
	Kit.part(m, "FountainWater", Vector3.new(0.4, 32, 32), at(0, 2.1, f - 62) * UPRIGHT, Color3.fromRGB(70, 180, 220), M.Glass, { shape = CYL, transp = 0.25, decor = true })
	Kit.part(m, "FountainJet", Vector3.new(14, 2, 2), at(0, 9, f - 62) * UPRIGHT, Color3.fromRGB(220, 245, 255), M.Glass, { shape = CYL, transp = 0.4, decor = true })
	return m
end

-- =====================================================================================
-- Erweiterung Phase 3: Vorort, Tankstellen, Shopping, Parkhaeuser
-- =====================================================================================

local function tagMarker(parent, name, cf, tag, attrs)
	local p = Kit.part(parent, name, Vector3.new(4, 1, 4), cf, Color3.new(1, 1, 1), M.SmoothPlastic, { ghost = true })
	p.Transparency = 1
	if tag then
		CollectionService:AddTag(p, tag)
	end
	for k, v in pairs(attrs or {}) do
		p:SetAttribute(k, v)
	end
	return p
end
Kit.tagMarker = tagMarker

-- Laubbaum (3 Parts)
function Kit.tree(parent, pos, seed)
	local rng = Random.new(seed or math.floor(pos.X * 3 + pos.Z * 5))
	local m = Kit.model(parent, "Tree")
	local h = rng:NextNumber(14, 22)
	Kit.part(m, "Trunk", Vector3.new(h, 1.6, 1.6), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * UPRIGHT, Color3.fromRGB(96, 74, 54), M.Wood, { shape = CYL })
	local g = rng:NextInteger(0, 25)
	local leaf = Color3.fromRGB(58 + g, 98 + g, 44 + g // 2)
	local s1 = rng:NextNumber(13, 18)
	Kit.part(m, "Crown", Vector3.new(s1, s1, s1), CFrame.new(pos + Vector3.new(0, h + s1 * 0.2, 0)), leaf, M.LeafyGrass, { shape = Enum.PartType.Ball, ghost = true })
	local s2 = s1 * 0.75
	Kit.part(m, "Crown", Vector3.new(s2, s2, s2), CFrame.new(pos + Vector3.new(rng:NextNumber(-4, 4), h + s1 * 0.45, rng:NextNumber(-4, 4))), leaf, M.LeafyGrass, { shape = Enum.PartType.Ball, ghost = true })
	return m
end

-- Mast mit Doppelleuchte fuer Parkplaetze
function Kit.lotLight(parent, pos)
	local m = Kit.model(parent, "LotLight")
	Kit.part(m, "Pole", Vector3.new(30, 1, 1), CFrame.new(pos + Vector3.new(0, 15, 0)) * UPRIGHT, C.metal, M.Metal, { shape = CYL, noShadow = true })
	for _, s in ipairs({ -1, 1 }) do
		local lamp = Kit.part(m, "Lamp", Vector3.new(4, 0.6, 2), CFrame.new(pos + Vector3.new(s * 3, 29.7, 0)), C.lamp, M.Neon, { decor = true })
		local l = Instance.new("SpotLight")
		l.Face = Enum.NormalId.Bottom
		l.Range = 60
		l.Angle = 120
		l.Brightness = 1.6
		l.Color = C.lamp
		l.Shadows = false
		l.Parent = lamp
		CollectionService:AddTag(lamp, "StreetLamp")
	end
	return m
end

function Kit.trashBin(parent, pos)
	return Kit.part(parent, "TrashBin", Vector3.new(3.4, 2.2, 2.2), CFrame.new(pos + Vector3.new(0, 1.7, 0)) * UPRIGHT, Color3.fromRGB(40, 70, 52), M.Metal, { shape = CYL })
end

-- Einkaufswagen-Sammelstelle. cf: Mitte, Reihe entlang lokalem X
function Kit.cartCorral(parent, cf, n)
	local m = Kit.model(parent, "CartCorral")
	local len = n * 3 + 4
	for _, s in ipairs({ -1, 1 }) do
		Kit.part(m, "Rail", Vector3.new(len, 0.4, 0.4), cf * CFrame.new(0, 3, s * 2.4), Color3.fromRGB(200, 200, 196), M.Metal)
	end
	for i = 0, n - 1 do
		local c = cf * CFrame.new(-len / 2 + 3 + i * 3, 0, 0)
		Kit.part(m, "Cart", Vector3.new(2.6, 2.6, 4), c * CFrame.new(0, 2.4, 0), Color3.fromRGB(180, 184, 188), M.DiamondPlate, { transp = 0.35, decor = true })
		Kit.part(m, "CartHandle", Vector3.new(2.6, 0.3, 0.3), c * CFrame.new(0, 3.9, 2.2), Color3.fromRGB(200, 40, 40), M.Plastic, { decor = true })
	end
	return m
end

-- Bordstein-Auffahrt in der Gosse. curbPoint: Bordsteinkante auf Fahrbahnhoehe, outward: Richtung Fahrbahn
function Kit.driveway(parent, curbPoint, outward, width)
	local center = curbPoint + outward * 2 + Vector3.new(0, 0.3, 0)
	return Kit.wedge(parent, "DrivewayRamp", Vector3.new(width, 0.6, 4), CFrame.lookAt(center, center + outward), C.concrete, M.Concrete)
end

-- Spielplatz (pos: Mitte am Boden)
function Kit.playground(parent, pos)
	local m = Kit.model(parent, "Playground")
	local function at(x, y, z)
		return CFrame.new(pos + Vector3.new(x, y, z))
	end
	Kit.part(m, "SafetyFloor", Vector3.new(60, 0.4, 44), at(0, 0.2, 0), Color3.fromRGB(196, 90, 70), M.Rubber)
	Kit.part(m, "Tower", Vector3.new(8, 10, 8), at(-16, 5, -8), Color3.fromRGB(70, 160, 220), M.Plastic)
	Kit.part(m, "TowerRoof", Vector3.new(10, 1, 10), at(-16, 12.5, -8), Color3.fromRGB(255, 200, 60), M.Plastic)
	Kit.part(m, "Slide", Vector3.new(4, 0.6, 16), at(-16, 5, 5) * CFrame.Angles(math.rad(32), 0, 0), Color3.fromRGB(255, 120, 60), M.Plastic)
	for _, x in ipairs({ 8, 24 }) do
		Kit.part(m, "SwingPost", Vector3.new(0.8, 12, 0.8), at(x, 6, -10), C.metal, M.Metal)
	end
	Kit.part(m, "SwingBeam", Vector3.new(17, 0.8, 0.8), at(16, 12, -10), C.metal, M.Metal)
	for _, x in ipairs({ 12, 20 }) do
		Kit.part(m, "SwingSeat", Vector3.new(3, 0.4, 1.4), at(x, 3, -10), Color3.fromRGB(30, 30, 30), M.Rubber, { decor = true })
		Kit.part(m, "SwingChain", Vector3.new(0.2, 9, 0.2), at(x, 7.5, -10), C.metal, M.Metal, { decor = true })
	end
	Kit.part(m, "SeesawBase", Vector3.new(1.4, 1.6, 1.4), at(14, 0.8, 10), C.metal, M.Metal)
	Kit.part(m, "Seesaw", Vector3.new(14, 0.5, 1.4), at(14, 1.8, 10) * CFrame.Angles(0, 0, math.rad(10)), Color3.fromRGB(120, 200, 90), M.Plastic)
	return m
end

-- Park mit Wegen, Baeumen, Palmen, Teich, Baenken, optional Spielplatz
function Kit.park(parent, name, x0, z0, x1, z1, rng, withPlayground)
	local m = Kit.model(parent, name)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local pathC = Color3.fromRGB(214, 204, 184)
	Kit.part(m, "Lawn", Vector3.new(x1 - x0, 0.4, z1 - z0), CFrame.new(cx, 0.2, cz), C.grass, M.Grass)
	Kit.part(m, "PathEW", Vector3.new(x1 - x0, 0.3, 8), CFrame.new(cx, 0.45, cz), pathC, M.Pavement)
	Kit.part(m, "PathNS", Vector3.new(8, 0.3, z1 - z0), CFrame.new(cx, 0.45, cz), pathC, M.Pavement)
	Kit.part(m, "Pond", Vector3.new(0.4, 50, 50), CFrame.new(cx + (x1 - x0) * 0.25, 0.45, cz - (z1 - z0) * 0.25) * UPRIGHT, Color3.fromRGB(50, 130, 150), M.Glass, { shape = CYL, transp = 0.2, refl = 0.3 })
	local nTrees = math.floor((x1 - x0) * (z1 - z0) / 5000)
	for _ = 1, nTrees do
		local x, z = rng:NextNumber(x0 + 12, x1 - 12), rng:NextNumber(z0 + 12, z1 - 12)
		if math.abs(x - cx) > 10 and math.abs(z - cz) > 10 then
			if rng:NextNumber() < 0.35 then
				Kit.palm(m, Vector3.new(x, 0.4, z))
			else
				Kit.tree(m, Vector3.new(x, 0.4, z))
			end
		end
	end
	for i = -2, 2 do
		if i ~= 0 then
			Kit.part(m, "Bench", Vector3.new(8, 1.6, 2.4), CFrame.new(cx + i * 30, 1.2, cz + 8), Color3.fromRGB(150, 110, 76), M.WoodPlanks)
		end
	end
	if withPlayground then
		Kit.playground(m, Vector3.new(cx - (x1 - x0) * 0.25, 0.4, cz + (z1 - z0) * 0.25))
	end
	return m
end

-- Flaches Apartmenthaus (2-4 Geschosse) mit Balkonen. Vorderseite = lokales -Z
function Kit.lowriseApartments(parent, name, pos, w, d, floors, st)
	st = st or {}
	local rng = Random.new(st.seed or 7)
	local m = Kit.model(parent, name)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local base = CFrame.new(pos) * CFrame.Angles(0, st.rot or 0, 0)
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local fh = 11
	local H = floors * fh
	local body = st.color or Color3.fromRGB(240, 228, 206)
	local trim = st.trim or Color3.fromRGB(250, 250, 248)
	local win = Color3.fromRGB(52, 74, 86)
	Kit.part(m, "Body", Vector3.new(w, H, d), at(0, H / 2, 0), body, M.Plaster)
	for f = 0, floors - 1 do
		local y = f * fh
		Kit.part(m, "Windows", Vector3.new(w * 0.86, 4.5, 0.4), at(0, y + 6, -d / 2 - 0.2), win, M.Glass, { decor = true, refl = 0.2 })
		Kit.part(m, "Windows", Vector3.new(w * 0.86, 4.5, 0.4), at(0, y + 6, d / 2 + 0.2), win, M.Glass, { decor = true, refl = 0.2 })
		if f > 0 then
			Kit.part(m, "Balcony", Vector3.new(w * 0.9, 0.6, 5), at(0, y + 0.3, -d / 2 - 2.5), trim, M.Concrete, { decor = true })
			Kit.part(m, "BalconyRail", Vector3.new(w * 0.9, 3, 0.3), at(0, y + 2, -d / 2 - 4.9), Color3.fromRGB(180, 210, 220), M.Glass, { decor = true, transp = 0.5 })
		end
	end
	Kit.part(m, "Parapet", Vector3.new(w + 1, 2.5, d + 1), at(0, H + 1.25, 0), trim, M.Plaster)
	Kit.part(m, "StairTower", Vector3.new(14, H + 8, 14), at(w / 2 - 4, (H + 8) / 2, d / 2 - 4), st.accent or Color3.fromRGB(200, 120, 90), M.Plaster)
	Kit.part(m, "EntranceCanopy", Vector3.new(16, 1, 8), at(0, 10, -d / 2 - 4), trim, M.Concrete)
	Kit.part(m, "Door", Vector3.new(8, 9, 0.4), at(0, 4.5, -d / 2 - 0.2), Color3.fromRGB(60, 50, 44), M.Wood, { decor = true })
	Kit.litWindows(m, at, w, d, 0, H, rng, 0.5)
	return m
end

-- Ladeneinheit. cf: Mitte der Frontlinie am Boden, Vorderseite = lokales -Z
function Kit.storefront(parent, cf, w, h, d, sign, facade, signColor)
	local m = Kit.model(parent, "Store_" .. sign:gsub("[^%w]", ""))
	m:SetAttribute("StoreName", sign)
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	Kit.part(m, "Body", Vector3.new(w, h, d), at(0, h / 2, d / 2), facade, M.Plaster)
	Kit.part(m, "Display", Vector3.new(w * 0.8, 10, 0.5), at(0, 6, -0.2), Color3.fromRGB(40, 56, 66), M.Glass, { refl = 0.25, decor = true })
	Kit.part(m, "Door", Vector3.new(7, 9, 0.6), at(-w * 0.25, 4.5, -0.3), Color3.fromRGB(70, 90, 100), M.Glass, { decor = true, transp = 0.2 })
	Kit.sign(m, at(0, h - 4, -0.6), Vector3.new(math.min(w * 0.85, 120), 6, 0.6), sign, signColor or Color3.new(1, 1, 1), Color3.fromRGB(20, 22, 26))
	tagMarker(m, "StoreEntrance", at(-w * 0.25, 1, -3), "StoreEntrance", { StoreName = sign })
	return m
end

-- Shopping Center. Ladenzeilen entlang Nordkante (Front nach Sueden) und Westkante (Front nach Osten),
-- ueberdachter Gang, grosser Parkplatz mit Lichtmasten und Einkaufswagen.
function Kit.shoppingCenter(parent, name, x0, z0, x1, z1, stores, st)
	st = st or {}
	local m = Kit.model(parent, name)
	m:SetAttribute("Interactable", "ShoppingCenter")
	local Y = st.y or 0.8
	local depth = 90
	local facades = {
		Color3.fromRGB(236, 228, 214), Color3.fromRGB(214, 222, 228), Color3.fromRGB(240, 220, 204), Color3.fromRGB(226, 226, 222),
	}
	-- Ladenzeile an der Nordkante, Schaufenster nach Sueden zum Parkplatz
	local zf = z0 + 10 + depth -- Frontlinie
	local x = x0 + 10
	local canopyStart = x
	for i, s in ipairs(stores) do
		local w = s.w or 80
		if x + w > x1 - 10 then
			break
		end
		local h = s.h or 26
		Kit.storefront(m, CFrame.new(x + w / 2, Y, zf) * CFrame.Angles(0, math.pi, 0), w, h, depth, s.name, s.facade or facades[(i - 1) % #facades + 1], s.color)
		x += w + 2
	end
	local canopyEnd = x
	-- ueberdachter Gang vor den Laeden
	local cz = zf + 9
	Kit.part(m, "Canopy", Vector3.new(canopyEnd - canopyStart, 1.2, 18), CFrame.new((canopyStart + canopyEnd) / 2, Y + 15, cz), Color3.fromRGB(250, 250, 248), M.Concrete)
	Kit.part(m, "CanopyLight", Vector3.new(canopyEnd - canopyStart, 0.2, 1), CFrame.new((canopyStart + canopyEnd) / 2, Y + 14.3, cz + 8.4), Color3.fromRGB(255, 236, 200), M.Neon, { decor = true })
	Kit.part(m, "Walkway", Vector3.new(canopyEnd - canopyStart, 0.4, 20), CFrame.new((canopyStart + canopyEnd) / 2, Y + 0.2, cz), Color3.fromRGB(220, 214, 200), M.Pavement)
	for xc = canopyStart + 10, canopyEnd - 10, 40 do
		Kit.part(m, "Column", Vector3.new(1.4, 15, 1.4), CFrame.new(xc, Y + 7.5, cz + 8), Color3.fromRGB(240, 240, 236), M.Metal)
	end
	-- Parkplatz
	local pz0 = zf + 30
	Kit.parkingLot(m, "Parking", x0 + 10, pz0, x1 - (st.garageW or 0) - 20, z1 - 10, Y)
	for lx = x0 + 60, x1 - (st.garageW or 0) - 60, 120 do
		for lz = pz0 + 50, z1 - 40, 120 do
			Kit.lotLight(m, Vector3.new(lx, Y, lz))
		end
	end
	Kit.cartCorral(m, CFrame.new(x0 + 120, Y, pz0 - 14), 8)
	Kit.cartCorral(m, CFrame.new(x0 + 320, Y, pz0 + 140), 6)
	for xc = canopyStart + 30, canopyEnd - 30, 80 do
		Kit.trashBin(m, Vector3.new(xc, Y + 0.4, cz + 8))
	end
	tagMarker(m, "MeetingPoint", CFrame.new((canopyStart + canopyEnd) / 2, Y + 1, cz), "MeetingPoint", { Location = name })
	if st.sign then
		Kit.part(m, "SignPylon", Vector3.new(6, 40, 3), CFrame.new(x1 - (st.garageW or 0) - 40, Y + 20, z1 - 20), Color3.fromRGB(30, 34, 40), M.Metal)
		Kit.sign(m, CFrame.new(x1 - (st.garageW or 0) - 40, Y + 36, z1 - 21.6) * CFrame.Angles(0, math.pi, 0), Vector3.new(36, 8, 0.6), st.sign, Color3.fromRGB(255, 200, 80))
	end
	return m
end

-- Befahrbares Parkhaus mit Scheren-Rampen. pos: Bodenmitte; Einfahrt an der lokalen +Z-Seite (st.rot dreht)
function Kit.parkingGarage(parent, name, pos, w, d, levels, st)
	st = st or {}
	local m = Kit.model(parent, name)
	m:SetAttribute("Parking", true)
	local base = CFrame.new(pos) * CFrame.Angles(0, st.rot or 0, 0)
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local H, LANE, T = 12, 22, 1.2
	local LAND = 44 -- Wendeflaeche an beiden Enden jeder Ebene (Wendekreis Pkw ~34 + Ueberhang)
	local concrete = Color3.fromRGB(196, 192, 184)
	local laneA, laneB = w / 2 - LANE / 2, w / 2 - LANE * 1.5
	local mainW = w - 2 * LANE
	local mainX = -w / 2 + mainW / 2
	-- Erdgeschoss buendig mit dem Grundstueck (keine Stufe an der Einfahrt)
	Kit.part(m, "GroundFloor", Vector3.new(w, T, d), at(0, -T / 2 + 0.05, 0), C.asphalt, M.Asphalt)
	for i = 1, levels do
		local y = i * H
		Kit.part(m, "Deck" .. i, Vector3.new(mainW, T, d), at(mainX, y - T / 2, 0), concrete, M.Concrete)
		-- Wendeflaechen ueber beide Rampenspuren an Nord- und Suedende
		for _, s in ipairs({ -1, 1 }) do
			Kit.part(m, "Landing" .. i, Vector3.new(2 * LANE, T, LAND), at((laneA + laneB) / 2, y - T / 2, s * (d / 2 - LAND / 2)), concrete, M.Concrete)
			-- Abschlusswand am Spurende (sonst haengt die Front beim Wenden ueber die Kante)
			Kit.part(m, "LaneEndWall", Vector3.new(2 * LANE, 3.5, 0.8), at((laneA + laneB) / 2, y + 1.75, s * (d / 2 - 0.4)), concrete, M.Concrete)
		end
		-- Rampe i (nur Mittelteil): ungerade in Spur A (von +Z nach -Z steigend), gerade in Spur B (von -Z nach +Z)
		local lx = (i % 2 == 1) and laneA or laneB
		local zA, zB = d / 2 - LAND, -(d / 2 - LAND)
		local zLow, zHigh = (i % 2 == 1) and zA or zB, (i % 2 == 1) and zB or zA
		local p0 = at(lx, (i - 1) * H, zLow).Position
		local p1 = at(lx, i * H, zHigh).Position
		local mid = (p0 + p1) / 2
		local cf = CFrame.lookAt(mid, p1)
		local rampLen = (p1 - p0).Magnitude
		Kit.part(m, "Ramp" .. i, Vector3.new(LANE, T, rampLen), cf * CFrame.new(0, -T / 2, 0), concrete, M.Concrete)
		-- seitliche Schrammborde: Fahrzeuge koennen nicht von der Rampe rutschen.
		-- Sie beginnen erst nach 24 Studs (dort ist die Rampe kaum hoeher als das Deck), damit man schraeg einbiegen kann.
		local curbLen = rampLen - 24
		for _, s in ipairs({ -1, 1 }) do
			Kit.part(m, "RampCurb", Vector3.new(1, 2.4, curbLen), cf * CFrame.new(s * (LANE / 2 - 0.5), 1.2, -12), Color3.fromRGB(240, 200, 40), M.Concrete)
		end
		-- Bruestungen
		local wallY = y + 1.75
		Kit.part(m, "Wall", Vector3.new(mainW, 3.5, 0.8), at(mainX, wallY, -d / 2 + 0.4), concrete, M.Concrete)
		Kit.part(m, "Wall", Vector3.new(mainW, 3.5, 0.8), at(mainX, wallY, d / 2 - 0.4), concrete, M.Concrete)
		Kit.part(m, "Wall", Vector3.new(0.8, 3.5, d), at(-w / 2 + 0.4, wallY, 0), concrete, M.Concrete)
		Kit.part(m, "Wall", Vector3.new(0.8, 3.5 + H, d), at(w / 2 - 0.4, y - H / 2 + 1.75, 0), concrete, M.Concrete)
		Kit.part(m, "LevelStripe", Vector3.new(mainW, 1.2, 0.2), at(mainX, y + 3, -d / 2 - 0.05), st.accent or Color3.fromRGB(30, 110, 190), M.SmoothPlastic, { decor = true })
	end
	for _, cx in ipairs({ -w / 2 + 1.5, mainX + mainW / 2 - 1.5 }) do
		for _, cz in ipairs({ -d / 2 + 1.5, 0, d / 2 - 1.5 }) do
			Kit.part(m, "Column", Vector3.new(3, levels * H, 3), at(cx, levels * H / 2, cz), concrete, M.Concrete)
		end
	end
	Kit.part(m, "StairTower", Vector3.new(16, levels * H + 10, 16), at(-w / 2 - 8, (levels * H + 10) / 2, -d / 2 + 8), Color3.fromRGB(70, 74, 80), M.Concrete)
	Kit.sign(m, at(-w / 2 - 8, levels * H + 4, -d / 2 - 0.6), Vector3.new(14, 8, 0.6), "P", Color3.fromRGB(80, 180, 255), Color3.fromRGB(10, 40, 90))
	if st.sign then
		Kit.sign(m, at(mainX, levels * H - 3, d / 2 + 0.6) * CFrame.Angles(0, math.pi, 0), Vector3.new(math.min(mainW * 0.7, 80), 6, 0.6), st.sign, Color3.new(1, 1, 1), Color3.fromRGB(10, 40, 90))
	end
	tagMarker(m, "GarageEntrance", at(laneA, 1, d / 2 + 6), "GarageEntrance", { Garage = name })
	return m
end

-- Amerikanische Tankstelle. cf: Mitte des Grundstuecks am Boden, LookVector zeigt zur Hauptstrasse.
-- st.large: 4 Zapfinseln + Waschstrasse. Pumpen sind fuer spaetere Interaktion getaggt ("FuelPump").
function Kit.gasStation(parent, name, cf, st)
	st = st or {}
	local m = Kit.model(parent, name)
	m:SetAttribute("Interactable", "GasStation")
	m:SetAttribute("StationId", name)
	local large = st.large
	local W, D = large and 240 or 170, large and 200 or 150
	local brand = st.brand or "SUNSHINE FUEL"
	local bc = st.brandColor or Color3.fromRGB(255, 140, 40)
	local Y = st.y or 0.8
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	Kit.part(m, "Forecourt", Vector3.new(W, 1, D), at(0, Y - 0.5, 0), Color3.fromRGB(176, 172, 164), M.Concrete)
	-- Dach mit Leuchtband
	local islands = large and 4 or 2
	local cw = islands * 30 + 20
	local cz = -D / 2 + 55
	Kit.part(m, "Canopy", Vector3.new(cw, 3, 64), at(-W * 0.1, Y + 19.5, cz), Color3.fromRGB(250, 250, 248), M.SmoothPlastic)
	Kit.part(m, "CanopyFascia", Vector3.new(cw + 0.6, 1.6, 64.6), at(-W * 0.1, Y + 18.6, cz), bc, M.Neon, { decor = true })
	local under = Kit.part(m, "CanopyLights", Vector3.new(cw - 10, 0.2, 54), at(-W * 0.1, Y + 17.9, cz), Color3.fromRGB(255, 250, 240), M.Neon, { decor = true })
	local sl = Instance.new("SurfaceLight")
	sl.Face = Enum.NormalId.Bottom
	sl.Range = 30
	sl.Brightness = 2
	sl.Angle = 90
	sl.Parent = under
	Kit.sign(m, at(-W * 0.1, Y + 19.5, cz - 32.6), Vector3.new(math.min(cw * 0.6, 70), 2.6, 0.4), brand, bc, Color3.fromRGB(250, 250, 248))
	-- Zapfinseln
	local pumpN = 0
	for i = 0, islands - 1 do
		local ix = -W * 0.1 - cw / 2 + 25 + i * 30
		Kit.part(m, "Island", Vector3.new(4, 0.6, 22), at(ix, Y + 0.3, cz), Color3.fromRGB(226, 222, 214), M.Concrete)
		Kit.part(m, "Pillar", Vector3.new(1.6, 18, 1.6), at(ix, Y + 9, cz), Color3.fromRGB(240, 240, 236), M.Metal)
		for _, s in ipairs({ -1, 1 }) do
			pumpN += 1
			local pump = Kit.part(m, "Pump", Vector3.new(2.6, 6.5, 3.6), at(ix, Y + 3.85, cz + s * 6), Color3.fromRGB(236, 236, 232), M.Metal)
			Kit.part(m, "PumpScreen", Vector3.new(2.7, 1.6, 2), at(ix, Y + 5.6, cz + s * 6), Color3.fromRGB(40, 220, 120), M.Neon, { decor = true })
			Kit.part(m, "PumpBrand", Vector3.new(2.7, 1, 3.7), at(ix, Y + 7.4, cz + s * 6), bc, M.SmoothPlastic, { decor = true })
			pump:SetAttribute("StationId", name)
			pump:SetAttribute("PumpNumber", pumpN)
			CollectionService:AddTag(pump, "FuelPump")
			local pp = Instance.new("ProximityPrompt")
			pp.ActionText = "Tanken"
			pp.ObjectText = "Zapfsaeule " .. pumpN
			pp.MaxActivationDistance = 12
			pp.Enabled = false -- wird mit dem Wirtschaftssystem aktiviert
			pp.Parent = pump
		end
		Kit.trashBin(m, at(ix + 1.6, Y + 0.6, cz + 10).Position)
	end
	-- Shop
	local sx, sz = -W * 0.1, D / 2 - 32
	local shopW, shopD = large and 90 or 70, 44
	Kit.part(m, "Shop", Vector3.new(shopW, 16, shopD), at(sx, Y + 8, sz), Color3.fromRGB(246, 244, 238), M.Plaster)
	Kit.part(m, "ShopGlass", Vector3.new(shopW * 0.75, 10, 0.5), at(sx, Y + 6, sz - shopD / 2 - 0.2), Color3.fromRGB(40, 56, 66), M.Glass, { refl = 0.25, decor = true })
	Kit.part(m, "ShopFascia", Vector3.new(shopW + 0.6, 2, shopD + 0.6), at(sx, Y + 15, sz), bc, M.SmoothPlastic, { decor = true })
	Kit.sign(m, at(sx, Y + 12.5, sz - shopD / 2 - 0.6), Vector3.new(shopW * 0.6, 3.5, 0.4), st.shopName or "MART", Color3.new(1, 1, 1), bc)
	Kit.sign(m, at(sx + shopW * 0.3, Y + 8, sz - shopD / 2 - 0.5), Vector3.new(6, 2.5, 0.3), "OPEN", Color3.fromRGB(255, 50, 60), Color3.fromRGB(10, 10, 12))
	Kit.part(m, "IceBox", Vector3.new(8, 5, 3), at(sx - shopW * 0.35, Y + 2.5, sz - shopD / 2 - 2), Color3.fromRGB(230, 240, 250), M.Plastic)
	tagMarker(m, "ShopEntrance", at(sx - shopW * 0.1, Y + 1, sz - shopD / 2 - 4), "ShopEntrance", { StationId = name, Shop = "GasStationShop" })
	for i = -2, 2 do
		Kit.part(m, "StallLine", Vector3.new(0.4, 0.06, 18), at(sx + i * 12, Y + 0.04, sz - shopD / 2 - 14), C.white, M.SmoothPlastic, { decor = true })
	end
	Kit.cartCorral(m, at(sx + shopW / 2 + 10, Y, sz - shopD / 2 - 6), 3)
	Kit.part(m, "AirPump", Vector3.new(2.4, 5, 2.4), at(sx - shopW / 2 - 8, Y + 2.5, sz - 10), Color3.fromRGB(40, 90, 180), M.Metal)
	-- Preis-Pylon an der Strasse
	local px, pz = W / 2 - 14, -D / 2 + 10
	Kit.part(m, "PricePylon", Vector3.new(14, 30, 3), at(px, Y + 15, pz), Color3.fromRGB(30, 32, 36), M.Metal)
	Kit.sign(m, at(px, Y + 26, pz - 1.6), Vector3.new(13, 5, 0.3), brand, bc, Color3.fromRGB(250, 250, 248))
	local prices = st.prices or { "UNLEADED 3.49", "PLUS 3.79", "PREMIUM 4.09", "DIESEL 3.99" }
	for i, ptxt in ipairs(prices) do
		Kit.sign(m, at(px, Y + 21 - (i - 1) * 4, pz - 1.6), Vector3.new(13, 3.4, 0.3), ptxt, Color3.fromRGB(255, 70, 60), Color3.fromRGB(8, 8, 10))
	end
	-- Waschstrasse
	if large then
		local wx, wz = W / 2 - 30, D / 2 - 50
		local wash = Kit.model(m, "CarWash")
		for _, s in ipairs({ -1, 1 }) do
			Kit.part(wash, "Wall", Vector3.new(2, 16, 70), at(wx + s * 14, Y + 8, wz), Color3.fromRGB(240, 240, 236), M.Plaster)
		end
		Kit.part(wash, "Roof", Vector3.new(30, 2, 72), at(wx, Y + 17, wz), Color3.fromRGB(40, 140, 220), M.SmoothPlastic)
		for i = -1, 1 do
			for _, s in ipairs({ -1, 1 }) do
				Kit.part(wash, "Brush", Vector3.new(12, 3, 3), at(wx + s * 9, Y + 7, wz + i * 20) * UPRIGHT, Color3.fromRGB(60, 120, 230), M.Fabric, { shape = CYL, decor = true })
			end
		end
		Kit.sign(wash, at(wx, Y + 13, wz - 35.6), Vector3.new(24, 4, 0.4), "CAR WASH", Color3.fromRGB(80, 200, 255), Color3.fromRGB(10, 30, 60))
		tagMarker(wash, "CarWashEntrance", at(wx, Y + 1, wz - 40), "CarWash", { StationId = name })
	end
	return m
end

-- Veranstaltungsarena (rund). pos = Bodenmitte
function Kit.arena(parent, name, pos, dia, h, st)
	st = st or {}
	local m = Kit.model(parent, name)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local base = CFrame.new(pos)
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	Kit.part(m, "Facade", Vector3.new(h, dia, dia), at(0, h / 2, 0) * UPRIGHT, Color3.fromRGB(36, 50, 62), M.Glass, { shape = CYL, refl = 0.2 })
	Kit.part(m, "Base", Vector3.new(8, dia + 8, dia + 8), at(0, 4, 0) * UPRIGHT, Color3.fromRGB(226, 222, 214), M.Concrete, { shape = CYL })
	Kit.part(m, "LEDRing", Vector3.new(4, dia + 1, dia + 1), at(0, h * 0.72, 0) * UPRIGHT, st.neon or Color3.fromRGB(60, 200, 255), M.Neon, { shape = CYL, decor = true })
	Kit.part(m, "RoofRing", Vector3.new(5, dia + 14, dia + 14), at(0, h + 2.5, 0) * UPRIGHT, Color3.fromRGB(240, 240, 236), M.Metal, { shape = CYL })
	Kit.part(m, "RoofDome", Vector3.new(6, dia * 0.86, dia * 0.86), at(0, h + 6, 0) * UPRIGHT, Color3.fromRGB(230, 230, 228), M.Metal, { shape = CYL })
	for i = 0, 3 do
		local a = i * math.pi / 2
		local cf = base * CFrame.Angles(0, a, 0) * CFrame.new(0, h * 0.86, -(dia / 2 + 1))
		Kit.sign(m, cf, Vector3.new(dia * 0.5, 10, 0.6), st.sign or "ARENA", Color3.new(1, 1, 1), Color3.fromRGB(16, 20, 28))
	end
	return m
end

-- Innenraum-Baukasten (Phase 7, gemeinsam fuer Wachen/Krankenhaus) --------------------------------------
-- o = { S = Model (Rohbau), I = Model (Einrichtung), G = Model (Spiel-Objekte), FL = Fussboden-Oberkante, H = Raumhoehe,
--       wall = Color3, faction = "Fire"|"EMS"|... (fuer verschlossene Tueren) }
function Kit.interior(o)
	local C = Enum.Material
	local IK = { S = o.S, I = o.I, G = o.G, FL = o.FL, H = o.H, WALL = o.wall or Color3.fromRGB(234, 234, 230) }
	local S, G, FL, H = o.S, o.G, o.FL, o.H
	function IK.P(parent, name, size, pos, color, mat, opts)
		return Kit.part(parent, name, size, typeof(pos) == "CFrame" and pos or CFrame.new(pos), color, mat, opts)
	end
	local P = IK.P
	function IK.interact(part, kind, text, objectText, range, extra)
		part:SetAttribute("InteractType", kind)
		part:SetAttribute("InteractText", text)
		part:SetAttribute("ObjectText", objectText)
		part:SetAttribute("Range", range or 10)
		for k, v in pairs(extra or {}) do
			part:SetAttribute(k, v)
		end
		CollectionService:AddTag(part, "Interactable")
		return part
	end
	function IK.marker(name, pos, tag, attrs)
		return tagMarker(G, name, typeof(pos) == "CFrame" and pos or CFrame.new(pos), tag, attrs)
	end
	local function segments(a, b, gaps)
		gaps = gaps or {}
		table.sort(gaps, function(p, q)
			return p[1] < q[1]
		end)
		local cur, segs = a, {}
		for _, g in ipairs(gaps) do
			table.insert(segs, { cur, g[1] - g[2] / 2 })
			cur = g[1] + g[2] / 2
		end
		table.insert(segs, { cur, b })
		return segs, gaps
	end
	-- Wand entlang X (feste z) bzw. entlang Z (feste x); gaps = { {Mitte, Breite[, Hoehe]} }
	function IK.wallX(z, a, b, gaps, color, thick, exterior)
		local segs, g2 = segments(a, b, gaps)
		for _, g in ipairs(g2) do
			local gh = g[3] or 14
			if gh < H then
				P(S, "Lintel", Vector3.new(g[2], H - gh, thick or 1), Vector3.new(g[1], FL + gh + (H - gh) / 2, z), color or IK.WALL, C.Plaster)
			end
		end
		for _, s in ipairs(segs) do
			if s[2] - s[1] > 0.2 then
				P(S, "Wall", Vector3.new(s[2] - s[1], H, thick or 1), Vector3.new((s[1] + s[2]) / 2, FL + H / 2, z), color or IK.WALL, exterior and C.Concrete or C.Plaster)
			end
		end
	end
	function IK.wallZ(x, a, b, gaps, color, thick, exterior)
		local segs, g2 = segments(a, b, gaps)
		for _, g in ipairs(g2) do
			local gh = g[3] or 14
			if gh < H then
				P(S, "Lintel", Vector3.new(thick or 1, H - gh, g[2]), Vector3.new(x, FL + gh + (H - gh) / 2, g[1]), color or IK.WALL, C.Plaster)
			end
		end
		for _, s in ipairs(segs) do
			if s[2] - s[1] > 0.2 then
				P(S, "Wall", Vector3.new(thick or 1, H, s[2] - s[1]), Vector3.new(x, FL + H / 2, (s[1] + s[2]) / 2), color or IK.WALL, exterior and C.Concrete or C.Plaster)
			end
		end
	end
	-- Tuer mit Interaktion "Door" (InteractionService); locked = nur fuer die Fraktion
	function IK.door(name, cf, width, locked, color)
		local m = Kit.model(G, name)
		local d = P(m, "Door", Vector3.new(width - 0.2, 13.8, 0.5), cf * CFrame.new(0, FL + 6.9, 0), color or Color3.fromRGB(200, 204, 210), C.Metal)
		local h = P(m, "Handle", Vector3.new(0.3, 0.3, 1.2), d.CFrame * CFrame.new(width / 2 - 1.2, 0, 0), Color3.fromRGB(180, 180, 186), C.Metal, { decor = true })
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = d, h
		weld.Parent = h
		h.Anchored = false
		m.PrimaryPart = d
		m:SetAttribute("InteractType", "Door")
		m:SetAttribute("InteractText", "Tuer oeffnen / schliessen")
		m:SetAttribute("ObjectText", name)
		m:SetAttribute("Range", 9)
		if locked and o.faction then
			m:SetAttribute("Locked", true)
			m:SetAttribute("RequiredFaction", o.faction)
		end
		CollectionService:AddTag(m, "Interactable")
		return m
	end
	function IK.doorX(name, x, z, w, locked, color)
		return IK.door(name, CFrame.new(x, 0, z), w, locked, color)
	end
	function IK.doorZ(name, x, z, w, locked, color)
		return IK.door(name, CFrame.new(x, 0, z) * CFrame.Angles(0, math.pi / 2, 0), w, locked, color)
	end
	-- Terminal (Saeule mit Bildschirm), Blickrichtung facing
	function IK.terminal(name, pos, facing, kind, text, objectText, screenColor)
		local cf = CFrame.lookAt(pos, pos + facing)
		local t = P(IK.I, name, Vector3.new(4, 7, 2), cf * CFrame.new(0, 3.5, 0), Color3.fromRGB(32, 34, 40), C.Metal)
		P(IK.I, name .. "Screen", Vector3.new(3.2, 2.4, 0.1), cf * CFrame.new(0, 5.5, -1.05), screenColor or Color3.fromRGB(64, 224, 255), C.Neon, { decor = true })
		IK.interact(t, kind, text, objectText, 10)
		return t
	end
	-- NPC (verankert) mit Dialog
	function IK.npc(name, pos, lookAt, torso, legs, dialog)
		local ok, npc = pcall(function()
			local desc = Instance.new("HumanoidDescription")
			local skin = Color3.fromRGB(198, 150, 112)
			desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, torso, torso
			desc.TorsoColor, desc.LeftLegColor, desc.RightLegColor = torso, legs, legs
			return game:GetService("Players"):CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		end)
		if not ok or not npc then
			return nil
		end
		npc.Name = name
		for _, p in ipairs(npc:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
			end
		end
		npc:FindFirstChildOfClass("Humanoid").DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		npc:PivotTo(CFrame.lookAt(pos, lookAt))
		npc.Parent = IK.I
		IK.interact(npc.PrimaryPart, "NPC", "Ansprechen", name, 12, { Dialog = dialog })
		return npc
	end
	-- Sitzbank mit Lehne
	function IK.bench(parent, cf, len, color)
		P(parent, "Bench", Vector3.new(len, 1.6, 3), cf * CFrame.new(0, FL + 1.6 - FL, 0), color, C.WoodPlanks)
		P(parent, "BenchBack", Vector3.new(len, 3, 0.6), cf * CFrame.new(0, 3.6, 1.4), color, C.WoodPlanks, { decor = true })
	end
	return IK
end

return Kit
