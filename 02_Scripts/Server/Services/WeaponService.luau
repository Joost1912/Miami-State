-- WeaponService (Prompt 08): Waffen als reine Roblox-Spielgegenstaende im bestehenden Inventar.
-- * Ausruesten / Verstauen / Laden / Entladen - alles serverseitig geprueft (Besitz, Zustand, Fahrzeug, Takt).
-- * Geladene Munition liegt im Profil (Weapons.Loaded[itemId]) und wird aus dem Inventar entnommen/zurueckgelegt.
-- * Modell aus einfachen Teilen (keine fremden Assets, keine Gewaltdarstellung). Ein Schusssystem ist NICHT Teil
--   dieser Phase; das Tool ist die Grundlage dafuer (Attribute MiamiWeapon / Loaded / Mag).
-- * Automatisch verstaut bei: Fesseln, Haft, Bewusstlosigkeit, Fahrersitz, Respawn, Verlust/Beschlagnahme der Waffe.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local Items = require(Shared.Config.Items)

local WeaponService = {}
local S
local equipped = {} -- [player] = { Id = itemId, Tool = Tool }
local lastAct = setmetatable({}, { __mode = "k" })

function WeaponService.Init(services)
	S = services
end

local function hum(p)
	return p.Character and p.Character:FindFirstChildOfClass("Humanoid")
end

local function weaponDef(itemId)
	local def = typeof(itemId) == "string" and Items.Defs[itemId]
	return (def and def.Weapon) and def or nil
end

local function throttle(player)
	if lastAct[player] and os.clock() - lastAct[player] < 0.35 then
		return false
	end
	lastAct[player] = os.clock()
	return true
end

-- Modell ------------------------------------------------------------------------------------------
local function piece(tool, handle, name, size, offset, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if handle then
		p.CFrame = handle.CFrame * offset
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = handle, p
		w.Parent = p
	end
	p.Parent = tool
	return p
end

-- Lauf zeigt entlang -Z des Griffs
local function buildTool(itemId, def)
	local tool = Instance.new("Tool")
	tool.Name = def.Name
	tool.ToolTip = def.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("MiamiWeapon", itemId)
	tool:SetAttribute("Mag", def.Weapon.Mag)
	local dark, metal = Color3.fromRGB(34, 36, 40), Color3.fromRGB(78, 80, 86)
	local wood = Color3.fromRGB(110, 74, 46)
	local long = def.Weapon.Class == "Long"
	local h = piece(tool, nil, "Handle", Vector3.new(0.28, 0.75, 0.42), CFrame.new(), dark, Enum.Material.SmoothPlastic)
	h.CFrame = CFrame.new(0, 50, 0)
	if not long then
		local slideLen = (itemId == "Pistol45") and 1.35 or 1.15
		piece(tool, h, "Slide", Vector3.new(0.3, 0.32, slideLen), CFrame.new(0, 0.5, -slideLen / 2 + 0.25), itemId == "Revolver" and metal or dark, Enum.Material.Metal)
		piece(tool, h, "TriggerGuard", Vector3.new(0.12, 0.08, 0.36), CFrame.new(0, 0.18, -0.32), dark)
		if itemId == "Revolver" then
			piece(tool, h, "Cylinder", Vector3.new(0.42, 0.42, 0.42), CFrame.new(0, 0.48, -0.2) * CFrame.Angles(0, math.rad(90), 0), metal, Enum.Material.Metal, Enum.PartType.Cylinder)
			h.Color = wood
		end
	else
		local bodyLen = (itemId == "Carbine") and 1.6 or 1.9
		local stockColor = (itemId == "Carbine") and dark or wood
		piece(tool, h, "Receiver", Vector3.new(0.3, 0.42, bodyLen), CFrame.new(0, 0.45, -bodyLen / 2 + 0.1), itemId == "Carbine" and dark or metal, Enum.Material.Metal)
		piece(tool, h, "Barrel", Vector3.new(1.7, 0.14, 0.14), CFrame.new(0, 0.55, -bodyLen - 0.75) * CFrame.Angles(0, math.rad(90), 0), metal, Enum.Material.Metal, Enum.PartType.Cylinder)
		piece(tool, h, "Stock", Vector3.new(0.28, 0.5, 1.2), CFrame.new(0, 0.32, 0.75), stockColor, itemId == "Carbine" and Enum.Material.SmoothPlastic or Enum.Material.Wood)
		if itemId == "Shotgun" then
			piece(tool, h, "Pump", Vector3.new(0.34, 0.3, 0.7), CFrame.new(0, 0.32, -bodyLen - 0.2), wood, Enum.Material.Wood)
		elseif itemId == "HuntingRifle" then
			piece(tool, h, "Scope", Vector3.new(1.0, 0.18, 0.18), CFrame.new(0, 0.82, -0.55) * CFrame.Angles(0, math.rad(90), 0), dark, Enum.Material.Metal, Enum.PartType.Cylinder)
		else
			piece(tool, h, "Magazine", Vector3.new(0.22, 0.6, 0.32), CFrame.new(0, 0.05, -0.55), dark)
		end
	end
	-- Griff: Hand haelt den Griff, Lauf (-Z des Griffs) zeigt nach vorn (im Playtest gemessen)
	tool.Grip = long and CFrame.new(0, -0.15, 0.35) or CFrame.new(0, -0.15, 0.05)
	return tool
end

-- API ---------------------------------------------------------------------------------------------
function WeaponService.Equipped(player)
	return equipped[player] and equipped[player].Id or nil
end

function WeaponService.Holster(player, silent)
	local e = equipped[player]
	equipped[player] = nil
	if typeof(player) == "Instance" then
		player:SetAttribute("EquippedWeapon", nil)
		player:SetAttribute("WeaponLoaded", nil)
	end
	if e and e.Tool and e.Tool.Parent then
		e.Tool:Destroy()
	end
	if not e then
		return false, "Keine Waffe ausgeruestet"
	end
	if not silent and S.Log then
		S.Log("Weapon", player, nil, "verstaut: " .. tostring(e.Id))
	end
	return true, "Waffe verstaut"
end

local function blocked(player)
	if player:GetAttribute("Cuffed") then
		return "Nicht moeglich - du bist gefesselt"
	elseif player:GetAttribute("Jailed") then
		return "Nicht moeglich - du bist in Haft"
	elseif player:GetAttribute("Injury") == "Unconscious" then
		return "Nicht moeglich - du bist bewusstlos"
	end
	local h = hum(player)
	if not h or h.Health <= 0 then
		return "Nicht moeglich"
	end
	if h.SeatPart and h.SeatPart:IsA("VehicleSeat") then
		return "Nicht waehrend der Fahrt"
	end
	return nil
end

local function loadedOf(player, itemId)
	local d = S.DataService.Get(player)
	return d and (d.Weapons.Loaded[itemId] or 0) or 0
end

local function publish(player)
	local e = equipped[player]
	if e then
		local n = loadedOf(player, e.Id)
		player:SetAttribute("WeaponLoaded", n)
		if e.Tool then
			e.Tool:SetAttribute("Loaded", n)
		end
	end
end

function WeaponService.Equip(player, itemId)
	local def = weaponDef(itemId)
	if not def then
		return false, "Keine Waffe"
	end
	if not throttle(player) then
		return false, "Bitte kurz warten"
	end
	if S.InventoryService.Count(player, itemId) < 1 then
		return false, "Nicht im Inventar"
	end
	local why = blocked(player)
	if why then
		return false, why
	end
	if equipped[player] and equipped[player].Id == itemId then
		return true, def.Name .. " ist bereits ausgeruestet"
	end
	WeaponService.Holster(player, true)
	local char = player.Character
	local tool = buildTool(itemId, def)
	equipped[player] = { Id = itemId, Tool = tool }
	tool.Parent = char -- direkt in der Hand (kein Rucksack noetig)
	local h = hum(player)
	if h then
		pcall(function()
			h:EquipTool(tool)
		end)
	end
	-- Tool verlaesst die Hand (Rucksack-Taste, Tod, Entfernen) -> gilt als verstaut
	tool.AncestryChanged:Connect(function()
		if tool.Parent ~= player.Character and equipped[player] and equipped[player].Tool == tool then
			WeaponService.Holster(player, true)
		end
	end)
	player:SetAttribute("EquippedWeapon", itemId)
	publish(player)
	S.Log("Weapon", player, nil, "ausgeruestet: " .. def.Name)
	return true, def.Name .. " ausgeruestet"
end

-- Munition aus dem Inventar ins Magazin
function WeaponService.Load(player, itemId)
	itemId = itemId or WeaponService.Equipped(player)
	local def = weaponDef(itemId)
	if not def then
		return false, "Keine Waffe"
	end
	if not throttle(player) then
		return false, "Bitte kurz warten"
	end
	local ammo = def.Weapon.Ammo
	local moved = 0
	local ok, err = S.DataService.Mutate(player, "WeaponLoad", function(d)
		if (d.Inventory.Items[itemId] or 0) < 1 then
			return false, "Waffe nicht im Inventar"
		end
		local loaded = d.Weapons.Loaded[itemId] or 0
		local space = def.Weapon.Mag - loaded
		if space <= 0 then
			return false, "Magazin ist bereits voll"
		end
		local have = d.Inventory.Items[ammo] or 0
		if have <= 0 then
			return false, "Keine passende Munition (" .. Items.Defs[ammo].Name .. ")"
		end
		moved = math.min(space, have)
		d.Inventory.Items[ammo] = (have - moved > 0) and (have - moved) or nil
		d.Weapons.Loaded[itemId] = loaded + moved
	end)
	if not ok then
		return false, err
	end
	publish(player)
	return true, string.format("%s geladen (+%d, %d/%d)", def.Name, moved, loadedOf(player, itemId), def.Weapon.Mag)
end

-- Munition aus dem Magazin zurueck ins Inventar
function WeaponService.Unload(player, itemId)
	itemId = itemId or WeaponService.Equipped(player)
	local def = weaponDef(itemId)
	if not def then
		return false, "Keine Waffe"
	end
	if not throttle(player) then
		return false, "Bitte kurz warten"
	end
	local ammo = def.Weapon.Ammo
	local n = 0
	local ok, err = S.DataService.Mutate(player, "WeaponUnload", function(d)
		n = d.Weapons.Loaded[itemId] or 0
		if n <= 0 then
			return false, "Waffe ist nicht geladen"
		end
		local can, why = S.InventoryService.CanAdd(d, ammo, n)
		if not can then
			return false, why
		end
		d.Inventory.Items[ammo] = (d.Inventory.Items[ammo] or 0) + n
		d.Weapons.Loaded[itemId] = nil
	end)
	if not ok then
		return false, err
	end
	publish(player)
	return true, string.format("%s entladen (%d Schuss zurueck ins Inventar)", def.Name, n)
end

function WeaponService.Start()
	-- Waffe weg (abgelegt/beschlagnahmt) -> verstauen und Magazininhalt verwerfen
	S.DataService.Changed:Connect(function(player, data, reason)
		if typeof(player) ~= "Instance" then
			return
		end
		local e = equipped[player]
		if e and (data.Inventory.Items[e.Id] or 0) < 1 then
			WeaponService.Holster(player, true)
		end
		if reason ~= "WeaponCleanup" then
			for id, n in pairs(data.Weapons.Loaded) do
				if (data.Inventory.Items[id] or 0) < 1 and n then
					task.defer(function()
						S.DataService.Mutate(player, "WeaponCleanup", function(d)
							d.Weapons.Loaded[id] = nil
						end)
					end)
				end
			end
		end
	end)
	local function hook(player)
		for _, attr in ipairs({ "Cuffed", "Jailed", "Injury" }) do
			player:GetAttributeChangedSignal(attr):Connect(function()
				if equipped[player] and blocked(player) then
					WeaponService.Holster(player, true)
				end
			end)
		end
		local function onChar(char)
			local h = char:WaitForChild("Humanoid", 10)
			if h then
				h.Seated:Connect(function(active, seat)
					if active and seat and seat:IsA("VehicleSeat") and equipped[player] then
						WeaponService.Holster(player, true)
					end
				end)
			end
		end
		player.CharacterAdded:Connect(function(char)
			WeaponService.Holster(player, true)
			onChar(char)
		end)
		if player.Character then
			task.spawn(onChar, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		equipped[p] = nil
	end)
end

return WeaponService
