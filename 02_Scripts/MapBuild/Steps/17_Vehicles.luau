-- Schritt 17: Fahrzeuge. Baut die Vorlagen (ServerStorage.Vehicles), installiert Fahrzeugskripte,
-- setzt Spawnpunkte (zivil + Einsatz) und platziert geparkte Deko-Fahrzeuge.
return function(Kit)
	local HttpService = game:GetService("HttpService")
	local CollectionService = game:GetService("CollectionService")
	local SS = game:GetService("ServerStorage")
	local Runner = require(SS.MapBuildTools.Runner:Clone())
	local VK = Runner.module("VehicleKit.luau", "VehicleKit")
	local M = Enum.Material

	VK.setupCollisionGroups()

	-- Vorlagen
	local templates = SS:FindFirstChild("Vehicles")
	if templates then
		templates:Destroy()
	end
	templates = Instance.new("Folder")
	templates.Name = "Vehicles"
	templates.Parent = SS
	local info = {}
	for _, t in ipairs({ "Sedan", "SUV", "Pickup", "Sports", "PoliceSedan", "PoliceSUV", "PoliceInterceptor", "HighwayPatrol", "PoliceUnmarked", "Ambulance", "AmbulanceHeavy", "EMSResponder", "FireEngine", "LadderTruck", "FireRescue", "FireCommand" }) do
		local m = VK.build(t)
		m.Parent = templates
		local n = 0
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		table.insert(info, string.format("%s(%d Parts, Masse %d)", t, n, m:GetAttribute("Mass")))
	end

	-- Skripte aus dem Repo installieren
	local function install(parent, name, class, path)
		local s = parent:FindFirstChild(name)
		if s then
			s:Destroy()
		end
		s = Instance.new(class)
		s.Name = name
		s.Source = HttpService:GetAsync("http://localhost:34872/" .. path, true)
		s.Parent = parent
	end
	local SPS = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
	-- Phase 6: VehicleService laeuft als Modul in MiamiServer (Schritt 18); altes Einzelskript entfernen
	local oldVS = game:GetService("ServerScriptService"):FindFirstChild("VehicleService")
	if oldVS and oldVS:IsA("Script") then
		oldVS:Destroy()
	end
	install(SPS, "VehicleClient", "LocalScript", "Client/VehicleClient.client.luau")
	install(SPS, "VehicleEffects", "LocalScript", "Client/VehicleEffects.client.luau")

	-- Spawnpunkte
	local spawnF = Kit.folder(workspace.Map.SpawnPoints, "VehicleSpawns")
	spawnF:ClearAllChildren()
	local PADCOL = { Civilian = Color3.fromRGB(80, 220, 255), Police = Color3.fromRGB(60, 110, 255), Fire = Color3.fromRGB(255, 70, 50), EMS = Color3.fromRGB(255, 255, 255) }
	local function pad(typeName, pos, facing, group)
		local m = Kit.model(spawnF, "SpawnPad_" .. typeName)
		local cf = CFrame.lookAt(pos, pos + facing)
		local p = Kit.part(m, "Pad", Vector3.new(14, 0.3, 24), cf * CFrame.new(0, 0.15, 0), Color3.fromRGB(30, 34, 42), M.SmoothPlastic, { noShadow = true })
		p.CanCollide = false
		p:SetAttribute("VehicleType", typeName)
		p:SetAttribute("Group", group)
		if group ~= "Civilian" then
			p:SetAttribute("RequiredJob", group) -- wird vom spaeteren Jobsystem geprueft
		end
		CollectionService:AddTag(p, "VehicleSpawnPad")
		local col = PADCOL[group]
		for _, s in ipairs({ -1, 1 }) do
			Kit.part(m, "Edge", Vector3.new(0.4, 0.1, 24), cf * CFrame.new(s * 6.8, 0.33, 0), col, M.Neon, { decor = true })
		end
		Kit.part(m, "SignPost", Vector3.new(0.5, 8, 0.5), cf * CFrame.new(-7.6, 4, 12), Kit.C.metal, M.Metal)
		Kit.sign(m, cf * CFrame.new(-7.6, 8.5, 11.6) * CFrame.Angles(0, math.pi, 0), Vector3.new(8, 2.4, 0.3), typeName:upper(), col)
		return p
	end
	local svc = workspace.Map.ServiceSites
	-- Downtown (Rathausplatz, Ausfahrt zur Second St)
	for i, t in ipairs({ "Sedan", "SUV", "Pickup" }) do
		pad(t, Vector3.new(125 + i * 25, 0.6, 145), Vector3.new(0, 0, 1), "Civilian")
	end
	pad("Sports", Vector3.new(400, 0.6, 145), Vector3.new(0, 0, 1), "Civilian")
	-- Sawgrass Center Parkplatz
	for i, t in ipairs({ "Sedan", "SUV", "Pickup", "Sports" }) do
		pad(t, Vector3.new(-2935 + i * 30, 0.6, -480), Vector3.new(0, 0, 1), "Civilian")
	end
	-- Einsatzfahrzeuge an den Wachen
	-- Polizei: Fahrzeuge kommen aus der Garage der Wache (PoliceService), keine Spawnflaechen mehr
	-- Phase 7: Feuerwehr und Rettungsdienst parken ueber die Garagen-Terminals von Feuerwache/Krankenhaus aus

	-- Geparkte Fahrzeuge (Deko, verankert)
	local parked = Kit.folder(workspace.Map, "ParkedVehicles")
	parked:ClearAllChildren()
	local rng = Random.new(66)
	local PAINT = {
		Color3.fromRGB(240, 240, 238), Color3.fromRGB(20, 20, 22), Color3.fromRGB(130, 134, 140), Color3.fromRGB(30, 60, 110),
		Color3.fromRGB(150, 24, 28), Color3.fromRGB(200, 196, 186), Color3.fromRGB(40, 90, 70), Color3.fromRGB(80, 160, 200),
	}
	local CIV = { "Sedan", "SUV", "Pickup", "Sedan", "SUV", "Sports" }
	local count = 0
	local function park(pos, facing)
		local t = templates["Vehicle_" .. CIV[rng:NextInteger(1, #CIV)]]
		local m = VK.parkedCopy(t, CFrame.lookAt(pos, pos + facing))
		local col = PAINT[rng:NextInteger(1, #PAINT)]
		for _, d in ipairs(m.Body:GetChildren()) do
			if d:IsA("BasePart") and (d.Color == t.Body.LowerBody.Color) then
				d.Color = col
			end
		end
		m.Parent = parked
		count += 1
	end
	-- Strassenparken Second St (Nordseite Richtung Westen, Suedseite Richtung Osten)
	for _, x in ipairs({ -240, -200, -160, 170, 210, 350, 390 }) do
		park(Vector3.new(x, 0.2, 181), Vector3.new(-1, 0, 0))
	end
	for _, x in ipairs({ -220, -180, 190, 370 }) do
		park(Vector3.new(x, 0.2, 219), Vector3.new(1, 0, 0))
	end
	-- Sawgrass Center
	for _, x in ipairs({ -2925, -2911, -2869, -2827, -2799, -2715, -2687, -2631 }) do
		park(Vector3.new(x, 0.65, -705), Vector3.new(0, 0, -1))
	end
	-- Autohaus-Ausstellung
	for i = 0, 7 do
		park(Vector3.new(-2900 + i * 26, 0.65, 860), Vector3.new(0, 0, 1))
	end

	return table.concat(info, ", ") .. string.format(" | %d Spawnpunkte, %d geparkte Fahrzeuge", #spawnF:GetChildren(), count)
end
