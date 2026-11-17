-- Schritt 4: Hochgelegter Meridian Expressway (H1) mit zwei Rauten-Anschlussstellen
-- und Bay Causeway (Bruecke Downtown -> Coral Key).
return function(Kit)
	local S = Kit.SPECS
	local C = Kit.C
	local M = Enum.Material
	local CYL = Enum.PartType.Cylinder
	local UP = CFrame.Angles(0, 0, math.rad(90))
	local roads = workspace.Map.Roads

	local function fresh(name)
		local f = roads:FindFirstChild(name)
		if f then
			f:Destroy()
		end
		return Kit.folder(roads, name)
	end
	local hw = fresh("Highways")
	local br = fresh("Bridges")

	-- Highway H1 ------------------------------------------------------------------
	local HX, HY = -520, 40 -- Achse, Fahrbahnhoehe
	local ZN, ZS = -2900, 2500
	local awH = Kit.asphaltWidth(S.Highway)
	local awR = Kit.asphaltWidth(S.Ramp)
	local DECK = 4
	local INTERCHANGES = { { z = -1000, name = "Coconut" }, { z = 600, name = "Harbor" } }
	local STUB, INCL, MERGE = 60, 400, 100
	local GROUND_ROADS = { -1000, -200, 600 } -- Querstrassen unter dem Highway (keine Pfeiler)

	local mergeZones = {}
	for _, ic in ipairs(INTERCHANGES) do
		table.insert(mergeZones, { ic.z - STUB - INCL - MERGE, ic.z - STUB - INCL })
		table.insert(mergeZones, { ic.z + STUB + INCL, ic.z + STUB + INCL + MERGE })
	end

	-- Abschnittsgrenzen: Enden, Einfaedelzonen, max. 400 Studs pro Abschnitt
	local cuts = { ZN, ZS }
	for _, mz in ipairs(mergeZones) do
		table.insert(cuts, mz[1])
		table.insert(cuts, mz[2])
	end
	table.sort(cuts)
	local main = Kit.folder(hw, "H1_Deck")
	local segN = 0
	for i = 1, #cuts - 1 do
		local a, b = cuts[i], cuts[i + 1]
		local pieces = math.max(1, math.ceil((b - a) / 400))
		local step = (b - a) / pieces
		for p = 0, pieces - 1 do
			local z0, z1 = a + p * step, a + (p + 1) * step
			local mid = (z0 + z1) / 2
			local inMerge = false
			for _, mz in ipairs(mergeZones) do
				if mid > mz[1] and mid < mz[2] then
					inMerge = true
				end
			end
			segN += 1
			Kit.roadStrip(main, CFrame.lookAt(Vector3.new(HX, HY, mid), Vector3.new(HX, HY, mid - 1)), z1 - z0, S.Highway, {
				name = "H1_" .. segN,
				deck = DECK,
				lights = 180,
				noBarrierL = inMerge,
				noBarrierR = inMerge,
			})
		end
		task.wait()
	end

	-- Pfeiler
	local piers = Kit.folder(hw, "H1_Piers")
	local capTop = HY - 2 - DECK
	for z = ZN + 40, ZS - 40, 100 do
		local blocked = false
		for _, rz in ipairs(GROUND_ROADS) do
			if math.abs(z - rz) < 66 then
				blocked = true
			end
		end
		if not blocked then
			local m = Kit.model(piers, "Pier")
			for _, sx in ipairs({ -32, 32 }) do
				Kit.part(m, "Column", Vector3.new(capTop - 5, 7, 7), CFrame.new(HX + sx, (capTop - 5) / 2, z) * UP, C.concrete, M.Concrete, { shape = CYL })
			end
			Kit.part(m, "Cap", Vector3.new(awH - 8, 5, 9), CFrame.new(HX, capTop - 2.5, z), C.concrete, M.Concrete)
		end
	end
	-- Widerlager an den (vorlaeufigen) Enden
	for _, z in ipairs({ ZN, ZS }) do
		local m = Kit.model(hw, "H1_EndAbutment")
		local dir = (z == ZN) and -1 or 1
		Kit.part(m, "Abutment", Vector3.new(awH + 4, HY - 2, 20), CFrame.new(HX, (HY - 2) / 2, z + dir * 10), C.concrete, M.Concrete)
		for i = 0, 5 do
			local col = (i % 2 == 0) and Color3.fromRGB(255, 120, 20) or Color3.fromRGB(240, 240, 240)
			Kit.part(m, "ClosedBarrier", Vector3.new(awH / 6, 4, 1.5), CFrame.new(HX - awH / 2 + awH / 12 + i * awH / 6, HY + 2, z - dir * 2), col, M.SmoothPlastic)
		end
	end
	task.wait()

	-- Rampen (Rechtsverkehr: Ostseite = Richtung Norden, Westseite = Richtung Sueden)
	local rampsF = Kit.folder(hw, "Ramps")
	local function ramp(side, ic, dir)
		local x = (side == "E") and (HX + awH / 2 + awR / 2) or (HX - awH / 2 - awR / 2)
		local travel = (side == "E") and Vector3.new(0, 0, -1) or Vector3.new(0, 0, 1)
		local m = Kit.model(rampsF, string.format("Ramp_%s_%s_%s", ic.name, side, dir < 0 and "N" or "S"))
		local zg = ic.z + dir * STUB
		local zh = ic.z + dir * (STUB + INCL)
		local zm = ic.z + dir * (STUB + INCL + MERGE)
		local p0 = Vector3.new(x, Kit.SURFACE_Y, zg)
		local p1 = Vector3.new(x, HY, zh)
		local mid = (p0 + p1) / 2
		local fwd = ((p1 - p0).Z * travel.Z > 0) and (p1 - p0) or (p0 - p1)
		Kit.roadStrip(m, CFrame.lookAt(mid, mid + fwd.Unit), (p1 - p0).Magnitude, S.Ramp, { name = "Incline", deck = 3 })
		local fm = Vector3.new(x, HY, (zh + zm) / 2)
		Kit.roadStrip(m, CFrame.lookAt(fm, fm + travel), MERGE, S.Ramp, { name = "Merge", deck = 3, noBarrierL = true })
		-- Stuetzen unter der Rampe
		for t = 0.25, 1.0, 0.25 do
			local z = zg + (zm - zg) * t
			local y = (t * (zm - zg)) / (zh - zg) >= 1 and HY or HY * ((z - zg) / (zh - zg))
			local h = y - 2 - 3
			if h > 6 then
				Kit.part(m, "Column", Vector3.new(h, 5, 5), CFrame.new(x, h / 2, z) * UP, C.concrete, M.Concrete, { shape = CYL })
			end
		end
	end
	for _, ic in ipairs(INTERCHANGES) do
		ramp("E", ic, -1) -- Auffahrt Richtung Norden
		ramp("E", ic, 1) -- Abfahrt aus Sueden kommend
		ramp("W", ic, -1) -- Abfahrt aus Norden kommend
		ramp("W", ic, 1) -- Auffahrt Richtung Sueden
		task.wait()
	end

	-- Bay Causeway (Bruecke) ----------------------------------------------------------
	local BZ, BY = -200, 26
	local prof = { { 1000, Kit.SURFACE_Y }, { 1200, BY }, { 1600, BY }, { 1800, Kit.SURFACE_Y } }
	local bridge = Kit.model(br, "BayCauseway")
	for i = 1, #prof - 1 do
		local p0 = Vector3.new(prof[i][1], prof[i][2], BZ)
		local p1 = Vector3.new(prof[i + 1][1], prof[i + 1][2], BZ)
		local mid = (p0 + p1) / 2
		Kit.roadStrip(bridge, CFrame.lookAt(mid, mid + (p1 - p0).Unit), (p1 - p0).Magnitude, S.Bridge, {
			name = "Span" .. i,
			deck = 5,
			railings = true,
			lights = 100,
		})
	end
	local function deckY(x)
		for i = 1, #prof - 1 do
			local a, b = prof[i], prof[i + 1]
			if x >= a[1] and x <= b[1] then
				return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1])
			end
		end
		return 0
	end
	local bw = Kit.totalWidth(S.Bridge)
	for x = 1060, 1740, 80 do
		local under = deckY(x) - 2 - 5
		local bottom = -30
		local h = under - bottom
		if h > 4 then
			local m = Kit.model(bridge, "Pier")
			for _, sz in ipairs({ -bw / 2 + 10, bw / 2 - 10 }) do
				Kit.part(m, "Column", Vector3.new(h - 4, 6, 6), CFrame.new(x, bottom + (h - 4) / 2, BZ + sz) * UP, C.concrete, M.Concrete, { shape = CYL })
			end
			Kit.part(m, "Cap", Vector3.new(8, 4, bw - 6), CFrame.new(x, under - 2, BZ), C.concrete, M.Concrete)
		end
	end

	local n = 0
	for _, d in ipairs(hw:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	for _, d in ipairs(br:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return string.format("H1-Abschnitte %d, Parts Highway+Bruecke %d", segN, n)
end
