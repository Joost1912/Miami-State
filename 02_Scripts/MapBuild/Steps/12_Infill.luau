-- Schritt 12: Verdichtung. Fuellt freie Flaechen in bestehenden Downtown-Bloecken und in den neuen
-- Bloecken (Midtown, Ufer-Condos) mit unterschiedlichen Gebaeudetypen. Bestehende Gebaeude bleiben erhalten:
-- jeder Block wird in 4 x 4 Zellen geteilt, nur Zellen ohne vorhandene Bebauung werden genutzt.
-- Ergebnis liegt in BayfrontDowntown.Buildings.Infill (bei erneutem Lauf wird nur dieser Ordner neu gebaut).
return function(Kit)
	local M = Enum.Material
	local districts = workspace.Map.Districts
	local dt = districts.BayfrontDowntown
	local B = Kit.folder(dt.Buildings, "Infill")
	B:ClearAllChildren()
	local rng = Random.new(4242)
	local Y = 0.6

	-- Vorhandene Belegung sammeln (Gebaeude-Models und groessere Requisiten, keine Palmen)
	local rects = {}
	local function addModel(m)
		local cf, size = m:GetBoundingBox()
		local r = cf.Rotation
		local hx = math.abs(r.RightVector.X) * size.X / 2 + math.abs(r.UpVector.X) * size.Y / 2 + math.abs(r.LookVector.X) * size.Z / 2
		local hz = math.abs(r.RightVector.Z) * size.X / 2 + math.abs(r.UpVector.Z) * size.Y / 2 + math.abs(r.LookVector.Z) * size.Z / 2
		table.insert(rects, { cf.X - hx, cf.Z - hz, cf.X + hx, cf.Z + hz })
	end
	for _, d in ipairs(districts:GetChildren()) do
		local b = d:FindFirstChild("Buildings")
		if b then
			for _, m in ipairs(b:GetChildren()) do
				if m:IsA("Model") then
					addModel(m)
				end
			end
		end
		local p = d:FindFirstChild("Props")
		if p then
			for _, m in ipairs(p:GetChildren()) do
				if m:IsA("Model") and m.Name ~= "Palm" and m.Name ~= "BayfrontPromenade" then
					addModel(m)
				end
			end
		end
	end
	local function free(r)
		for _, o in ipairs(rects) do
			if r[1] < o[3] + 6 and r[3] > o[1] - 6 and r[2] < o[4] + 6 and r[4] > o[2] - 6 then
				return false
			end
		end
		return true
	end
	local function removePalms(r)
		for _, d in ipairs(districts:GetChildren()) do
			local p = d:FindFirstChild("Props")
			if p then
				for _, m in ipairs(p:GetChildren()) do
					if m.Name == "Palm" then
						local pos = m:GetPivot().Position
						if pos.X > r[1] - 4 and pos.X < r[3] + 4 and pos.Z > r[2] - 4 and pos.Z < r[4] + 4 then
							m:Destroy()
						end
					end
				end
			end
		end
	end

	local cols = { { -284, 31 }, { 129, 444 }, { 516, 831 } }
	local DT = { { -951, -636 }, { -564, -249 }, { -151, 164 }, { 236, 551 }, { 649, 964 } }
	local MID, E2, E3 = { -1364, -1049 }, { -1751, -1436 }, { -2164, -1849 }
	local blocks = {
		{ 3, DT[1], "bay" }, { 3, DT[2], "bay" }, { 3, DT[3], "bay" }, { 3, DT[4], "bay" }, { 3, DT[5], "bay" },
		{ 2, DT[1], "mid" }, { 2, DT[2], "mid" }, { 2, DT[4], "mid" },
		{ 1, DT[2], "west" },
		{ 1, MID, "midtown" }, { 2, MID, "midtown" }, { 3, MID, "midtown" },
		{ 3, E2, "condo" }, { 3, E3, "condo" },
	}
	local HEIGHTS = { bay = { 180, 360 }, mid = { 130, 260 }, west = { 90, 180 }, midtown = { 120, 300 }, condo = { 150, 300 } }
	local GLASS = {
		Color3.fromRGB(34, 62, 78), Color3.fromRGB(46, 80, 104), Color3.fromRGB(60, 96, 104), Color3.fromRGB(28, 40, 52),
		Color3.fromRGB(84, 98, 104), Color3.fromRGB(70, 60, 52), Color3.fromRGB(52, 70, 60),
	}
	local FRAME = { Color3.fromRGB(230, 230, 226), Color3.fromRGB(60, 62, 66), Color3.fromRGB(200, 190, 170), Color3.fromRGB(246, 246, 242) }
	local CROWN = { Color3.fromRGB(80, 220, 255), Color3.fromRGB(255, 80, 180), Color3.fromRGB(170, 110, 255), Color3.fromRGB(255, 215, 110) }
	local OFFICE = { Color3.fromRGB(226, 220, 208), Color3.fromRGB(200, 204, 210), Color3.fromRGB(236, 230, 220), Color3.fromRGB(150, 150, 154) }
	local function pick(t)
		return t[rng:NextInteger(1, #t)]
	end

	local count, plazas = { round = 0, stepped = 0, residential = 0, office = 0 }, 0
	local function place(r, tier)
		local rw, rd = r[3] - r[1], r[4] - r[2]
		local cx, cz = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
		removePalms(r)
		if rng:NextNumber() < 0.1 then
			-- kleiner Platz zwischen den Gebaeuden
			plazas += 1
			local pz = Kit.model(B, "PocketPlaza_" .. plazas)
			Kit.part(pz, "Planter", Vector3.new(rw * 0.5, 2, rd * 0.5), CFrame.new(cx, Y + 1, cz), Color3.fromRGB(214, 206, 190), M.Limestone)
			Kit.part(pz, "PlanterGrass", Vector3.new(rw * 0.5 - 2, 0.2, rd * 0.5 - 2), CFrame.new(cx, Y + 2.1, cz), Kit.C.grass, M.Grass)
			Kit.palm(pz, Vector3.new(cx, Y + 2, cz))
			for _, o in ipairs({ { -1, 0 }, { 1, 0 } }) do
				Kit.part(pz, "Bench", Vector3.new(8, 1.6, 2.4), CFrame.new(cx + o[1] * (rw * 0.25 + 6), Y + 0.8, cz), Color3.fromRGB(150, 110, 76), M.WoodPlanks)
			end
			return
		end
		local w, d = rw - 20, rd - 20
		if w < 40 or d < 40 then
			return
		end
		local hr = HEIGHTS[tier]
		local h = rng:NextInteger(hr[1], hr[2])
		local pos = Vector3.new(cx, Y, cz)
		local seed = rng:NextInteger(1, 1e6)
		local name = string.format("Infill_%s_%03d", tier, #B:GetChildren() + 1)
		local roll = rng:NextNumber()
		if roll < 0.22 and math.abs(w - d) < 30 then
			count.round += 1
			Kit.towerRound(B, name, pos, math.min(w, d), h, { seed = seed, glass = pick(GLASS), crown = pick(CROWN), spire = (h > 280) and 30 or nil })
		elseif roll < 0.55 then
			count.stepped += 1
			Kit.towerStepped(B, name, pos, w, d, h, { seed = seed, glass = pick(GLASS), frame = pick(FRAME) })
		elseif roll < 0.8 or tier == "condo" then
			count.residential += 1
			Kit.towerResidential(B, name, pos, w, d, math.floor(h * 0.8), { seed = seed, glass = pick(GLASS) })
		else
			count.office += 1
			local floors = math.clamp(h // 14, 5, 14)
			local m, H = Kit.midrise(B, name, pos, w, d, floors, { color = pick(OFFICE), glass = pick(GLASS), floorH = 14 })
			local srng = Random.new(seed)
			Kit.rooftop(m, CFrame.new(cx, Y + H + 1.6, cz), w, d, ({ "garden", "bar", "pool" })[srng:NextInteger(1, 3)], srng)
			Kit.litWindows(m, function(x, y, z)
				return CFrame.new(cx + x, Y + y, cz + z)
			end, w, d, 0, H, srng, 0.5)
		end
	end

	for bi, b in ipairs(blocks) do
		local x0, x1 = cols[b[1]][1], cols[b[1]][2]
		local z0, z1 = b[2][1], b[2][2]
		if b[3] == "midtown" or b[3] == "condo" then
			Kit.plaza(B, "Lot_" .. b[3] .. "_" .. bi, x0, z0, x1, z1)
		end
		local cw, ch = (x1 - x0) / 4, (z1 - z0) / 4
		local used = {}
		local function rect(i, j, si, sj)
			return { x0 + (i - 1) * cw, z0 + (j - 1) * ch, x0 + (i - 1 + si) * cw, z0 + (j - 1 + sj) * ch }
		end
		for j = 1, 4 do
			for i = 1, 4 do
				if not used[i .. "," .. j] then
					local options = {}
					if rng:NextNumber() < 0.55 then
						table.insert(options, { 2, 2 })
					end
					table.insert(options, (rng:NextNumber() < 0.5) and { 2, 1 } or { 1, 2 })
					table.insert(options, { 1, 1 })
					for _, o in ipairs(options) do
						local si, sj = o[1], o[2]
						if i + si - 1 <= 4 and j + sj - 1 <= 4 then
							local ok = true
							for a = i, i + si - 1 do
								for c = j, j + sj - 1 do
									if used[a .. "," .. c] then
										ok = false
									end
								end
							end
							local r = rect(i, j, si, sj)
							if ok and free(r) then
								for a = i, i + si - 1 do
									for c = j, j + sj - 1 do
										used[a .. "," .. c] = true
									end
								end
								place(r, b[3])
								table.insert(rects, r)
								break
							end
						end
					end
				end
			end
		end
		task.wait()
	end

	local n = 0
	for _, d in ipairs(B:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return string.format("Neu: %d rund, %d gestaffelt, %d Wohntuerme, %d Buerohaeuser, %d Plaetze, %d Parts",
		count.round, count.stepped, count.residential, count.office, plazas, n)
end
