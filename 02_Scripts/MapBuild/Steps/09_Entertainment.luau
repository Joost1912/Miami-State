-- Schritt 9: Starlight Entertainment District (noerdlich Coconut Blvd).
-- Nachtclubs, Casino-Resort (rein fiktiv, kein Echtgeld), Arena, Restaurants, Bars, Lounges, Luxushotel.
-- Bloecke: Reihe E2 (Z -1751..-1436) und E3 (Z -2164..-1849) zwischen Frontage St und Bayshore Dr.
return function(Kit)
	local C, M = Kit.C, Enum.Material
	local dist = Kit.folder(workspace.Map.Districts, "Entertainment")
	local B = Kit.folder(dist, "Buildings")
	local P = Kit.folder(dist, "Props")
	B:ClearAllChildren()
	P:ClearAllChildren()
	local Y = 0.6
	local rng = Random.new(1800)

	local cols = { { -284, 31 }, { 129, 444 }, { 516, 831 } }
	local E2, E3 = { -1751, -1436 }, { -2164, -1849 }
	local function lot(name, c, r, color)
		Kit.plaza(B, "Lot_" .. name, c[1], r[1], c[2], r[2], color or Color3.fromRGB(70, 66, 74), M.Pavement)
	end
	local NEON = {
		Color3.fromRGB(255, 60, 180), Color3.fromRGB(60, 230, 255), Color3.fromRGB(180, 100, 255),
		Color3.fromRGB(255, 150, 50), Color3.fromRGB(80, 255, 160),
	}

	-- E2 / West: Meridian Arena (grosse Veranstaltungshalle)
	do
		local c, r = cols[1], E2
		lot("Arena", c, r, Color3.fromRGB(196, 190, 180))
		local cx, cz = (c[1] + c[2]) / 2, (r[1] + r[2]) / 2
		Kit.arena(B, "MeridianArena", Vector3.new(cx, Y, cz), 230, 64, { sign = "MERIDIAN ARENA", neon = Color3.fromRGB(60, 200, 255) })
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			Kit.palm(P, Vector3.new(cx + math.cos(a) * 140, Y, cz + math.sin(a) * 140))
		end
	end

	-- E2 / Mitte: Golden Palm Casino Resort (Front nach Norden zum Starlight Blvd)
	do
		local c, r = cols[2], E2
		lot("Casino", c, r, Color3.fromRGB(222, 212, 192))
		local cx = (c[1] + c[2]) / 2
		Kit.casino(B, "GoldenPalmCasino", Vector3.new(cx, Y, r[1] + 135), 210, 110, 52, { sign = "GOLDEN PALM CASINO" })
		Kit.towerStepped(B, "GoldenPalmHotel", Vector3.new(cx, Y, r[2] - 50), 110, 66, 320, {
			seed = 77, glass = Color3.fromRGB(70, 58, 40), frame = Color3.fromRGB(214, 172, 74), roof = "bar",
		})
		for _, x in ipairs({ c[1] + 18, c[2] - 18 }) do
			for z = r[1] + 20, r[1] + 200, 45 do
				Kit.palm(P, Vector3.new(x, Y, z))
			end
		end
	end

	-- E2 / Ost: Luxushotel am Wasser mit Rooftop-Bar
	do
		local c, r = cols[3], E2
		Kit.towerRound(B, "MeridianGrandHotel", Vector3.new(c[2] - 80, Y, r[1] + 85), 110, 360, {
			seed = 9, glass = Color3.fromRGB(40, 70, 90), crown = Color3.fromRGB(255, 215, 110), spire = 40,
		})
		Kit.sign(B, CFrame.new(c[2] - 80, Y + 28, r[1] + 26) * CFrame.Angles(0, 0, 0), Vector3.new(70, 6, 0.6), "THE MERIDIAN GRAND", Color3.fromRGB(255, 215, 110))
	end

	-- E3 / Mitte: Club-Reihe am Starlight Blvd (Front nach Sueden)
	do
		local c, r = cols[2], E3
		lot("Clubs", c, r)
		local names = { "NEON ROOM", "ECLIPSE", "PULSE" }
		for i = 0, 2 do
			local x = c[1] + 52 + i * 105
			Kit.nightclub(B, "Club_" .. names[i + 1]:gsub(" ", ""), Vector3.new(x, Y, r[2] - 92), 94, 80, i == 1 and 46 or 36, {
				rot = math.pi, seed = i + 1, sign = names[i + 1],
				neon = NEON[i + 1], neon2 = NEON[(i + 2) % #NEON + 1], rooftop = (i == 1),
			})
		end
		-- Bars und Lounges an der Rueckseite (Front nach Norden zur North Gate St)
		local bars = { "VELVET LOUNGE", "TIKI BAR", "MIDNIGHT JAZZ" }
		for i = 0, 2 do
			local x = c[1] + 52 + i * 105
			Kit.decoBuilding(B, "Bar_" .. bars[i + 1]:gsub(" ", ""), Vector3.new(x, Y, r[1] + 60), 84, 56, 2, {
				color = Color3.fromRGB(40, 36, 46), accent = Color3.fromRGB(60, 54, 70), neon = NEON[(i + 3) % #NEON + 1], sign = bars[i + 1],
			})
			Kit.outdoorSeating(P, CFrame.new(x, Y, r[1] + 20), 4, NEON[(i + 1) % #NEON + 1])
		end
	end

	-- E3 / West: Restaurants + Boutique-Hotel mit Rooftop-Bar
	do
		local c, r = cols[1], E3
		lot("Dining", c, r)
		local rest = { "PRIME STEAKHOUSE", "OCEAN GRILL", "CAFE SOLEIL" }
		for i = 0, 2 do
			local x = c[1] + 52 + i * 105
			Kit.decoBuilding(B, "Restaurant_" .. rest[i + 1]:gsub(" ", ""), Vector3.new(x, Y, r[2] - 70), 88, 60, 2, {
				rot = math.pi, color = Color3.fromRGB(246, 238, 222), accent = Color3.fromRGB(30, 70, 60), neon = NEON[i + 1], sign = rest[i + 1],
			})
			Kit.outdoorSeating(P, CFrame.new(x, Y, r[2] - 22), 4, Color3.fromRGB(250, 248, 240))
		end
		Kit.towerStepped(B, "SkylineHotel", Vector3.new((c[1] + c[2]) / 2, Y, r[1] + 70), 160, 80, 230, {
			seed = 31, glass = Color3.fromRGB(30, 36, 48), frame = Color3.fromRGB(40, 40, 46), roof = "bar",
		})
	end

	-- Torbogen "STARLIGHT DISTRICT" ueber dem Boulevard
	do
		local arch = Kit.model(P, "StarlightArch")
		local ax = -230
		local z0 = -1800
		for _, s in ipairs({ -1, 1 }) do
			Kit.part(arch, "Pylon", Vector3.new(5, 34, 5), CFrame.new(ax, 17.6, z0 + s * 44), Color3.fromRGB(24, 22, 30), M.Metal)
			Kit.part(arch, "PylonNeon", Vector3.new(0.6, 32, 5.4), CFrame.new(ax - 2.8, 17.6, z0 + s * 44), Color3.fromRGB(255, 60, 180), M.Neon, { decor = true })
		end
		Kit.part(arch, "Beam", Vector3.new(5, 7, 94), CFrame.new(ax, 37, z0), Color3.fromRGB(24, 22, 30), M.Metal)
		Kit.sign(arch, CFrame.new(ax - 2.8, 37, z0) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(80, 6, 0.4), "STARLIGHT DISTRICT", Color3.fromRGB(60, 230, 255), Color3.fromRGB(12, 12, 16))
		Kit.sign(arch, CFrame.new(ax + 2.8, 37, z0) * CFrame.Angles(0, -math.pi / 2, 0), Vector3.new(80, 6, 0.4), "STARLIGHT DISTRICT", Color3.fromRGB(255, 60, 180), Color3.fromRGB(12, 12, 16))
	end

	local n = 0
	for _, d in ipairs(dist:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	local _ = rng
	return string.format("Entertainment District: %d Parts", n)
end
