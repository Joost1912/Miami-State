-- Schritt 3: Strassennetz Festland (Downtown, Bayshore Drive, Coconut Heights) und Coral Key.
-- Highway H1 und Bruecke folgen in 04_Highway.
return function(Kit)
	local S = Kit.SPECS
	local T = workspace.Terrain
	T:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(228, 210, 168))
	T:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(92, 134, 62))

	local roads = workspace.Map.Roads
	for _, n in ipairs({ "Downtown", "CoconutHeights" }) do
		local f = roads:FindFirstChild(n)
		if f then
			f:Destroy()
		end
	end
	local function fresh(name)
		local f = roads:FindFirstChild(name)
		if f then
			f:Destroy()
		end
		return Kit.folder(roads, name)
	end

	-- Festland ---------------------------------------------------------------
	local mainland = fresh("Mainland")
	local V = {
		-- Phase 2: Raster nach Norden (Midtown/Entertainment) und Sueden (Hafen) verlaengert
		{ name = "FrontageSt", x = -320, z0 = -2200, z1 = 2500, spec = S.Street },
		{ name = "MeridianAve", x = 80, z0 = -2200, z1 = 1000, spec = S.Boulevard },
		{ name = "PalmAve", x = 480, z0 = -2200, z1 = 1200, spec = S.Street }, -- endet am Hafentor
		{ name = "BayshoreDr", x = 880, z0 = -2600, z1 = 1000, spec = S.Boulevard }, -- endet am Hafen
		-- Coconut Heights
		{ name = "HeightsWest", x = -1900, z0 = -2400, z1 = 2200, spec = S.Residential },
		{ name = "HeightsAve", x = -1300, z0 = -2400, z1 = 2200, spec = S.Street },
		{ name = "HeightsEast", x = -700, z0 = -2400, z1 = 2200, spec = S.Residential },
		-- Phase 3: Sawgrass Park
		{ name = "MangroveAve", x = -2400, z0 = -2400, z1 = 2200, spec = S.Street },
		{ name = "SawgrassAve", x = -3000, z0 = -2400, z1 = 2200, spec = S.Boulevard },
		{ name = "CypressAve", x = -3600, z0 = -2400, z1 = 2200, spec = S.Street },
		{ name = "GladesRd", x = -4200, z0 = -2400, z1 = 2200, spec = S.Street },
		-- Rampen-Anschluesse Highway H1 (Bodenstuecke, Steigungen in 04_Highway)
		{ name = "RampE_Coconut", x = -451, z0 = -1060, z1 = -940, spec = S.Ramp },
		{ name = "RampW_Coconut", x = -589, z0 = -1060, z1 = -940, spec = S.Ramp },
		{ name = "RampE_Harbor", x = -451, z0 = 540, z1 = 660, spec = S.Ramp },
		{ name = "RampW_Harbor", x = -589, z0 = 540, z1 = 660, spec = S.Ramp },
	}
	local H = {
		{ name = "CoconutBlvd", z = -1000, x0 = -4200, x1 = 880, spec = S.Boulevard },
		-- Phase 3: Sawgrass Park
		{ name = "PalmettoLn", z = -600, x0 = -4200, x1 = -3600, spec = S.Residential },
		{ name = "BreezeLn", z = 200, x0 = -4200, x1 = -3600, spec = S.Residential },
		{ name = "CommerceSt", z = 1400, x0 = -4200, x1 = -700, spec = S.Street },
		{ name = "SunsetLn", z = 1800, x0 = -4200, x1 = -3000, spec = S.Residential },
		{ name = "IndustryRd", z = 2200, x0 = -4200, x1 = -700, spec = S.Street },
		-- Phase 2: Midtown + Entertainment District
		{ name = "MidtownSt", z = -1400, x0 = -320, x1 = 880, spec = S.Street },
		{ name = "StarlightBlvd", z = -1800, x0 = -320, x1 = 880, spec = S.Boulevard },
		{ name = "NorthGateSt", z = -2200, x0 = -320, x1 = 880, spec = S.Street },
		{ name = "SixthSt", z = -600, x0 = -320, x1 = 880, spec = S.Street },
		{ name = "CausewayBlvd", z = -200, x0 = -4200, x1 = 1000, spec = S.Boulevard },
		{ name = "SecondSt", z = 200, x0 = -320, x1 = 880, spec = S.Street },
		{ name = "HarborBlvd", z = 600, x0 = -4200, x1 = 880, spec = S.Boulevard },
		{ name = "PortSt", z = 1000, x0 = -320, x1 = 880, spec = S.Street },
		-- Coconut Heights Wohnstrassen
		{ name = "OrchidLn", z = -1350, x0 = -4200, x1 = -700, spec = S.Residential },
		{ name = "HibiscusLn", z = -1700, x0 = -4200, x1 = -700, spec = S.Residential },
		{ name = "MangoLn", z = -2050, x0 = -4200, x1 = -700, spec = S.Residential },
		{ name = "SeagrapeLn", z = -2400, x0 = -4200, x1 = -700, spec = S.Residential },
	}
	local c1 = Kit.network(mainland, V, H, { lights = 120, palms = 64 })
	task.wait()

	-- Coral Key ----------------------------------------------------------------
	local island = fresh("CoralKey")
	local IV = {
		{ name = "BayRd", x = 1960, z0 = -2500, z1 = 2500, spec = S.Street },
		{ name = "OceanAve", x = 2300, z0 = -2500, z1 = 2500, spec = S.Boulevard },
	}
	local IH = {
		{ name = "NorthSt", z = -2500, x0 = 1960, x1 = 2300, spec = S.Street },
		{ name = "LagoonSt", z = -1400, x0 = 1960, x1 = 2300, spec = S.Street },
		{ name = "CausewayBlvdKey", z = -200, x0 = 1800, x1 = 2300, spec = S.Boulevard },
		{ name = "CoralSt", z = 1000, x0 = 1960, x1 = 2300, spec = S.Street },
		{ name = "SouthSt", z = 2500, x0 = 1960, x1 = 2300, spec = S.Street },
	}
	local c2 = Kit.network(island, IV, IH, { lights = 120, palms = 64 })

	local n = 0
	for _, d in ipairs(roads:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return string.format("Kreuzungen Festland %d, Coral Key %d, Strassen-Parts %d", #c1, #c2, n)
end
