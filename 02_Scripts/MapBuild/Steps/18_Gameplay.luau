-- Schritt 18: Gameplay-Kernsystem installieren (Phase 5).
-- Installiert Module/Skripte aus dem Repo und setzt Weltobjekte: Geldautomaten, Jobcenter am Rathaus.
-- Ziel-Struktur:
--   ReplicatedStorage.MiamiShared            (Config, Format, UI)
--   ServerScriptService.MiamiServer          (Main + Services)
--   StarterPlayerScripts.MainClient          (+ Controllers)
return function(Kit)
	local HttpService = game:GetService("HttpService")
	local CollectionService = game:GetService("CollectionService")
	local RS, SSS = game:GetService("ReplicatedStorage"), game:GetService("ServerScriptService")
	local SPS = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
	local M = Enum.Material
	local BASE = "http://localhost:34872/"

	local function src(path)
		return HttpService:GetAsync(BASE .. path, true)
	end
	local function folder(parent, name)
		local f = parent:FindFirstChild(name)
		if f and not f:IsA("Folder") then
			f:Destroy()
			f = nil
		end
		if not f then
			f = Instance.new("Folder")
			f.Name = name
			f.Parent = parent
		end
		return f
	end
	local function install(parent, name, class, path)
		local old = parent:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local s = Instance.new(class)
		s.Name = name
		s.Source = src(path)
		s.Parent = parent
		return s
	end
	local n = 0
	-- Shared
	local shared = folder(RS, "MiamiShared")
	local cfg = folder(shared, "Config")
	for _, m in ipairs({ "Economy", "Factions", "Items", "Shops", "Police", "MapData", "Rescue", "Clothing", "Crime", "MapExtra", "Vehicles", "Properties", "Work" }) do -- Prompt 08-10 ergaenzt
		install(cfg, m, "ModuleScript", "Shared/Config/" .. m .. ".luau")
		n += 1
	end
	install(shared, "Format", "ModuleScript", "Shared/Format.luau")
	install(shared, "UI", "ModuleScript", "Shared/UI.luau")
	n += 2
	-- Server
	local server = folder(SSS, "MiamiServer")
	local services = folder(server, "Services")
	for _, m in ipairs({ "DataService", "EconomyService", "InventoryService", "JobService", "PayrollService", "CharacterService", "InteractionService", "ShopService", "VehicleService", "PoliceService", "RadioService", "DispatchService", "JusticeService", "UniformService", "RescueService", "FireService", "MedicalService", "PhoneService", "WeaponService", "ClothingService", "WantedService", "CrimeService", "DealershipService", "PropertyService", "ActivityService", "WorkService", "BusinessService" }) do -- Prompt 08-11 ergaenzt
		install(services, m, "ModuleScript", "Server/Services/" .. m .. ".luau")
		n += 1
	end
	install(server, "Main", "Script", "Server/Main.server.luau")
	-- alter eigenstaendiger VehicleService-Script ersetzt durch Services.VehicleService (Phase 6)
	if SSS:FindFirstChild("VehicleService") then
		SSS.VehicleService:Destroy()
	end
	n += 2
	-- Client
	local main = install(SPS, "MainClient", "LocalScript", "Client/MainClient.client.luau")
	local ctrl = folder(main, "Controllers")
	for _, m in ipairs({ "Hud", "CharacterCreator", "Profile", "Bank", "Inventory", "Jobs", "Shop", "Interact", "Police", "Radio", "MDT", "Emergency", "Overlays", "Rescue", "Phone", "CityMap", "Minimap", "Medical", "FireTools", "WeaponHud", "Crime", "Vehicles", "Property", "Activity", "Work" }) do -- Prompt 08-10 ergaenzt
		install(ctrl, m, "ModuleScript", "Client/Controllers/" .. m .. ".luau")
		n += 1
	end
	n += 1
	-- Phase 7: Standard-Regeneration abschalten (leeres "Health"-Skript ersetzt das Roblox-Standardskript);
	-- Heilung nur ueber Verbandszeug, Rettungsdienst und Krankenhaus (MedicalService)
	local SCS = game:GetService("StarterPlayer"):WaitForChild("StarterCharacterScripts")
	local hs = SCS:FindFirstChild("Health")
	if hs then
		hs:Destroy()
	end
	hs = Instance.new("Script")
	hs.Name = "Health"
	hs.Source = "-- MIAMI STATE: ersetzt die automatische Regeneration (Heilung ueber MedicalService)\n"
	hs.Parent = SCS

	-- Weltobjekte -----------------------------------------------------------------------------
	local world = Kit.folder(workspace.Map, "Gameplay")
	world:ClearAllChildren()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { world }
	local function ground(x, z)
		local r = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -200, 0), params)
		return r and r.Position.Y or 0.6
	end

	-- Geldautomat: Vorderseite zeigt in Richtung face
	local atmN = 0
	local function atm(x, z, face, label)
		atmN += 1
		local y = ground(x, z)
		local pos = Vector3.new(x, y, z)
		local cf = CFrame.lookAt(pos, pos + face)
		local m = Kit.model(world, "ATM_" .. atmN)
		local body = Kit.part(m, "Body", Vector3.new(4, 7.5, 2.6), cf * CFrame.new(0, 3.75, 0), Color3.fromRGB(28, 32, 40), M.Metal)
		Kit.part(m, "Screen", Vector3.new(2.6, 1.7, 0.12), cf * CFrame.new(0, 5.2, -1.33), Color3.fromRGB(64, 224, 255), M.Neon, { decor = true })
		Kit.part(m, "Keypad", Vector3.new(2.2, 0.2, 1.1), cf * CFrame.new(0, 3.9, -1.7) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(180, 186, 196), M.Metal, { decor = true })
		Kit.part(m, "CardSlot", Vector3.new(1.2, 0.2, 0.15), cf * CFrame.new(0.9, 4.5, -1.36), Color3.fromRGB(40, 255, 140), M.Neon, { decor = true })
		Kit.sign(m, cf * CFrame.new(0, 7.0, -1.36), Vector3.new(3.6, 0.9, 0.1), "ATM", Color3.fromRGB(64, 224, 255), Color3.fromRGB(14, 16, 22))
		m.PrimaryPart = body
		m:SetAttribute("Location", label)
		body:SetAttribute("InteractType", "ATM")
		body:SetAttribute("InteractText", "Geldautomat benutzen")
		body:SetAttribute("ObjectText", "Bank of Miami State")
		body:SetAttribute("Range", 8)
		CollectionService:AddTag(body, "Interactable")
	end
	local N, S, E, W = Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0)
	atm(335, 152, N, "Rathausplatz")
	atm(-60, 893, S, "Bayside Market")
	atm(-2600, -846, S, "Sawgrass Center")
	atm(-2127, -804, N, "Sunshine Fuel Sawgrass")
	atm(-2117, -54, N, "Bay Fuel")
	atm(-1640, -1076, S, "Sunshine Fuel Coconut Heights")
	atm(2512, -150, E, "Coral Key Promenade Nord")
	atm(2512, 900, E, "Coral Key Promenade Sued")
	atm(-150, 1160, S, "Port Meridian")
	atm(180, -1744, N, "Starlight District")
	-- Bank of Sawgrass: Automat neben dem Eingang (aus dem Laden-Marker bestimmt)
	for _, mk in ipairs(CollectionService:GetTagged("StoreEntrance")) do
		if mk:GetAttribute("StoreName") == "BANK OF SAWGRASS" then
			atm(mk.Position.X + 10, mk.Position.Z, S, "Bank of Sawgrass")
		end
	end

	-- Jobcenter am Rathaus: NPC + Schild
	local entrance = workspace.Map.ServiceSites:FindFirstChild("CityHall_Entrance")
	local jcPos = entrance and entrance.Position or Vector3.new(286, 1.6, -26)
	local jc = Kit.model(world, "JobCenter")
	local okNpc, npc = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor, desc.TorsoColor = Color3.fromRGB(198, 142, 98), Color3.fromRGB(30, 60, 110)
		desc.LeftArmColor, desc.RightArmColor = Color3.fromRGB(198, 142, 98), Color3.fromRGB(198, 142, 98)
		desc.LeftLegColor, desc.RightLegColor = Color3.fromRGB(40, 40, 46), Color3.fromRGB(40, 40, 46)
		return game:GetService("Players"):CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	local target
	if okNpc and npc then
		npc.Name = "Jobcenter-Mitarbeiterin"
		for _, p in ipairs(npc:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
			end
		end
		local hum = npc:FindFirstChildOfClass("Humanoid")
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		npc:PivotTo(CFrame.lookAt(jcPos + Vector3.new(0, 2.6, 6), jcPos + Vector3.new(0, 2.6, 20)))
		npc.Parent = jc
		target = npc
	else
		target = Kit.part(jc, "Kiosk", Vector3.new(4, 6, 2), CFrame.new(jcPos + Vector3.new(0, 3, 6)), Color3.fromRGB(30, 60, 110), M.Metal)
	end
	Kit.part(jc, "Desk", Vector3.new(10, 3.6, 3), CFrame.new(jcPos + Vector3.new(0, 1.8, 9)), Color3.fromRGB(236, 232, 224), M.Marble)
	Kit.sign(jc, CFrame.lookAt(jcPos + Vector3.new(0, 11, 4), jcPos + Vector3.new(0, 11, 20)), Vector3.new(14, 2.6, 0.3), "JOBCENTER", Color3.fromRGB(64, 224, 255), Color3.fromRGB(14, 16, 22))
	target:SetAttribute("InteractType", "JobCenter")
	target:SetAttribute("InteractText", "Berufe ansehen")
	target:SetAttribute("ObjectText", "Jobcenter Miami State")
	target:SetAttribute("Range", 12)
	CollectionService:AddTag(target, "Interactable")

	return string.format("%d Skripte/Module installiert, %d Geldautomaten, Jobcenter %s", n, atmN, okNpc and "mit NPC" or "mit Kiosk")
end
