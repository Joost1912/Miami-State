-- PropertyService (Prompt 10): Apartments kaufen/mieten, betreten, abschliessen, Schluessel, Gaeste, Moebel.
-- * Besitz liegt im Spielerprofil (Properties.Owned) -> wird mit dem Profil gespeichert (DataService).
-- * Instanzierte Innenraeume: Vorlage ServerStorage.ApartmentInteriors.<Tier> (Teile Origin, Spawn, ExitDoor,
--   ManagePanel, Attribut HalfSize = Vector3) wird pro Wohnung ueber der Palmetto Bay platziert.
-- * Zutritt nur: Eigentuemer/Mieter, Schluesselinhaber, eingeladene Gaeste (nicht bei abgeschlossener Wohnung).
-- * Welt: Eingang = Tag "Interactable", InteractType "Property", BuildingId; Ausgang = Tag "PropertyExit", BuildingId.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cfg = require(ReplicatedStorage:WaitForChild("MiamiShared").Config.Properties)

local P = {}
local S
local instances = {} -- [key] = { Model, OwnerId, PropId, Origin = CFrame, Slot, EmptySince }
local slots = {} -- [slotIndex] = key
local invites = {} -- [ownerId] = { [guestId] = expiry }
local lastRing = {}
local folder

local BASE = CFrame.new(5200, 600, -2300) -- weit ausserhalb des Streaming-Radius der Stadt; Fenster zeigen ein Skyline-Panorama
local SLOT_GAP = 170
local SLOTS_PER_ROW = 4

function P.Init(services)
	S = services
end

local function keyOf(ownerId, propId)
	return tostring(ownerId) .. ":" .. tostring(propId)
end

local function propsOf(player)
	local d = S.DataService.Get(player)
	return d and d.Properties.Owned or {}
end

local function findProp(player, propId)
	for _, p in ipairs(propsOf(player)) do
		if p.Id == propId then
			return p
		end
	end
	return nil
end

local function entranceOf(buildingId)
	for _, inst in ipairs(CollectionService:GetTagged("Interactable")) do
		if inst:GetAttribute("InteractType") == "Property" and inst:GetAttribute("BuildingId") == buildingId and inst:IsDescendantOf(workspace) then
			return inst
		end
	end
	return nil
end

local function exitCFrame(buildingId)
	for _, p in ipairs(CollectionService:GetTagged("PropertyExit")) do
		if p:GetAttribute("BuildingId") == buildingId and p:IsDescendantOf(workspace) then
			return p.CFrame * CFrame.new(0, 3, 0)
		end
	end
	local e = entranceOf(buildingId)
	local r = e and S.InteractionService.RootOf(e)
	return r and (r.CFrame * CFrame.new(0, 2, -6)) or nil
end

local function nearBuilding(player, buildingId)
	local e = entranceOf(buildingId)
	return e ~= nil and S.InteractionService.Near(player, e, 22)
end

local function teleport(player, cf)
	local char = player.Character
	if not (char and char:FindFirstChild("HumanoidRootPart")) then
		return false
	end
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 6)
	end)
	char:PivotTo(cf)
	return true
end

local function rpName(player)
	local d = S.DataService.Get(player)
	return d and d.Character.Created and (d.Character.FirstName .. " " .. d.Character.LastName) or player.Name
end

local function unitNumber(player, buildingId, tier, idx)
	local b = Cfg.Buildings[buildingId]
	local ranges = { Standard = { 2, 8 }, City = { 9, 20 }, Luxury = { 21, 40 }, Penthouse = { 50, 54 } }
	local r = ranges[tier]
	local h = (math.abs(player.UserId) * 7919 + idx * 104729) % 100000
	local floor = r[1] + h % (r[2] - r[1] + 1)
	local unit = (math.floor(h / 13) % 12) + 1
	if tier == "Penthouse" then
		unit = 1 + (h % 2)
	end
	return string.format("%s-%d%02d", b.Prefix, floor, unit)
end

-- Moebel (einfache Grundmodelle, platzierbar) ---------------------------------------------------------
local function part(parent, size, cf, color, mat, o)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(o or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function makeFurniture(id, cf)
	local f = Cfg.FurnitureById[id]
	local m = Instance.new("Model")
	m.Name = "Furniture_" .. id
	local sz, c = f.Size, f.Color
	local base = cf * CFrame.new(0, 0, 0) -- cf = Boden-Mittelpunkt, Blick -Z
	local F = Enum.Material.Fabric
	if id == "Sofa" or id == "Armchair" then
		part(m, Vector3.new(sz.X, 1.2, sz.Z), base * CFrame.new(0, 0.9, 0), c, F)
		part(m, Vector3.new(sz.X, 1.6, 0.8), base * CFrame.new(0, 2.1, sz.Z / 2 - 0.4), c, F)
		part(m, Vector3.new(0.7, 1, sz.Z), base * CFrame.new(-sz.X / 2 + 0.35, 1.9, 0), c, F)
		part(m, Vector3.new(0.7, 1, sz.Z), base * CFrame.new(sz.X / 2 - 0.35, 1.9, 0), c, F)
		part(m, Vector3.new(sz.X - 1.6, 0.5, sz.Z - 1), base * CFrame.new(0, 1.7, -0.3), c:Lerp(Color3.new(1, 1, 1), 0.12), F)
		local seat = Instance.new("Seat")
		seat.Anchored, seat.Transparency, seat.CanCollide = true, 1, false
		seat.Size = Vector3.new(2, 0.4, 2)
		seat.CFrame = base * CFrame.new(0, 1.8, -0.2) * CFrame.Angles(0, math.pi, 0)
		seat.Parent = m
	elseif id == "CoffeeTable" or id == "DiningTable" then
		part(m, Vector3.new(sz.X, 0.3, sz.Z), base * CFrame.new(0, sz.Y - 0.15, 0), c, Enum.Material.Wood)
		for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			part(m, Vector3.new(0.3, sz.Y - 0.3, 0.3), base * CFrame.new(s[1] * (sz.X / 2 - 0.4), (sz.Y - 0.3) / 2, s[2] * (sz.Z / 2 - 0.4)), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
		end
		if id == "DiningTable" then
			for _, s in ipairs({ -1.6, 1.6 }) do
				for _, side in ipairs({ -1, 1 }) do
					part(m, Vector3.new(1.4, 0.2, 1.4), base * CFrame.new(s, 1.6, side * (sz.Z / 2 + 0.9)), Color3.fromRGB(40, 40, 44))
					part(m, Vector3.new(1.4, 1.6, 0.2), base * CFrame.new(s, 2.5, side * (sz.Z / 2 + 1.5)), Color3.fromRGB(40, 40, 44))
				end
			end
		end
	elseif id == "TV" then
		part(m, Vector3.new(sz.X, 1.6, sz.Z), base * CFrame.new(0, 0.8, 0), Color3.fromRGB(235, 235, 232), Enum.Material.Wood)
		part(m, Vector3.new(5.4, 3, 0.25), base * CFrame.new(0, 3.2, 0.2), Color3.fromRGB(12, 12, 14), Enum.Material.Glass, { Reflectance = 0.2 })
	elseif id == "Bookshelf" then
		part(m, Vector3.new(sz.X, sz.Y, 0.2), base * CFrame.new(0, sz.Y / 2, sz.Z / 2 - 0.1), c, Enum.Material.Wood)
		for i = 0, 4 do
			part(m, Vector3.new(sz.X, 0.2, sz.Z), base * CFrame.new(0, 0.1 + i * 1.7, 0), c, Enum.Material.Wood)
			if i < 4 then
				for b = -3, 3 do
					part(m, Vector3.new(0.4, 1.2, 1), base * CFrame.new(b * 0.5, 0.8 + i * 1.7, 0), Color3.fromHSV((b + i * 3) % 7 / 7, 0.5, 0.6))
				end
			end
		end
	elseif id == "Plant" then
		part(m, Vector3.new(1.6, 1.6, 1.6), base * CFrame.new(0, 0.8, 0), Color3.fromRGB(230, 225, 215), Enum.Material.Concrete)
		part(m, Vector3.new(0.25, 3.5, 0.25), base * CFrame.new(0, 3, 0), Color3.fromRGB(110, 80, 50), Enum.Material.Wood)
		for i = 0, 5 do
			part(m, Vector3.new(0.3, 0.15, 2.4), base * CFrame.new(0, 4.6, 0) * CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.new(0, 0, -1) * CFrame.Angles(math.rad(-25), 0, 0), c, Enum.Material.Grass, { CanCollide = false })
		end
	elseif id == "FloorLamp" then
		part(m, Vector3.new(1.2, 0.2, 1.2), base * CFrame.new(0, 0.1, 0), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
		part(m, Vector3.new(0.2, 5.4, 0.2), base * CFrame.new(0, 2.8, 0), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
		local shade = part(m, Vector3.new(1.4, 1, 1.4), base * CFrame.new(0, 5.9, 0), c, Enum.Material.Fabric, { CanCollide = false })
		local l = Instance.new("PointLight")
		l.Range, l.Brightness, l.Color = 16, 1.2, Color3.fromRGB(255, 220, 170)
		l.Parent = shade
	elseif id == "Rug" then
		part(m, Vector3.new(sz.X, 0.1, sz.Z), base * CFrame.new(0, 0.05, 0), c, Enum.Material.Fabric, { CanCollide = false })
		part(m, Vector3.new(sz.X - 1, 0.11, sz.Z - 1), base * CFrame.new(0, 0.06, 0), c:Lerp(Color3.fromRGB(40, 60, 90), 0.4), Enum.Material.Fabric, { CanCollide = false })
	elseif id == "Bed" then
		part(m, Vector3.new(sz.X, 1.2, sz.Z), base * CFrame.new(0, 0.6, 0), Color3.fromRGB(90, 70, 55), Enum.Material.Wood)
		part(m, Vector3.new(sz.X - 0.3, 0.8, sz.Z - 0.6), base * CFrame.new(0, 1.6, -0.2), c, Enum.Material.Fabric)
		part(m, Vector3.new(sz.X, 3.4, 0.5), base * CFrame.new(0, 1.7, sz.Z / 2 - 0.25), Color3.fromRGB(90, 70, 55), Enum.Material.Wood)
		part(m, Vector3.new(2.2, 0.5, 1.2), base * CFrame.new(-1.4, 2.2, sz.Z / 2 - 1.4), Color3.new(1, 1, 1), Enum.Material.Fabric)
		part(m, Vector3.new(2.2, 0.5, 1.2), base * CFrame.new(1.4, 2.2, sz.Z / 2 - 1.4), Color3.new(1, 1, 1), Enum.Material.Fabric)
		part(m, Vector3.new(sz.X - 0.2, 0.2, sz.Z * 0.5), base * CFrame.new(0, 2.05, -sz.Z * 0.2), Color3.fromRGB(60, 90, 140), Enum.Material.Fabric)
	end
	return m
end

-- Innenraum ------------------------------------------------------------------------------------------
local function floorY(inst, x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { inst.Model:FindFirstChild("Shell") or inst.Model }
	local r = workspace:Raycast(Vector3.new(x, inst.Origin.Position.Y + 4, z), Vector3.new(0, -10, 0), params) -- unter der Decke starten
	return r and r.Position.Y or inst.Origin.Position.Y
end

local function spawnFurniture(inst, prop)
	local holder = inst.Model:FindFirstChild("Furniture")
	if holder then
		holder:ClearAllChildren()
	else
		holder = Instance.new("Folder")
		holder.Name = "Furniture"
		holder.Parent = inst.Model
	end
	for i, f in ipairs(prop.Furniture or {}) do
		if Cfg.FurnitureById[f.Id] then
			local world = inst.Origin * CFrame.new(f.X, 0, f.Z)
			local y = floorY(inst, world.X, world.Z)
			local m = makeFurniture(f.Id, CFrame.new(world.X, y, world.Z) * CFrame.Angles(0, math.rad(f.R or 0), 0) * (inst.Origin - inst.Origin.Position))
			m:SetAttribute("Index", i)
			m.Parent = holder
		end
	end
end

local function freeSlot(key)
	for i = 1, 24 do -- 6 Reihen: z -2300 .. -1450 (Venues liegen ab z 0)
		if not slots[i] then
			slots[i] = key
			return i
		end
	end
	return nil
end

local function ensureInstance(owner, prop)
	local key = keyOf(owner.UserId, prop.Id)
	local inst = instances[key]
	if inst and inst.Model.Parent then
		return inst
	end
	local tmplFolder = ServerStorage:FindFirstChild("ApartmentInteriors")
	local tmpl = tmplFolder and tmplFolder:FindFirstChild(prop.Tier)
	if not tmpl then
		return nil, "Innenraum-Vorlage fehlt (" .. tostring(prop.Tier) .. ")"
	end
	local slot = freeSlot(key)
	if not slot then
		return nil, "Alle Wohnungsinstanzen belegt - bitte spaeter erneut"
	end
	local m = tmpl:Clone()
	m.Name = "Apt_" .. prop.Number
	local cf = BASE * CFrame.new(((slot - 1) % SLOTS_PER_ROW) * SLOT_GAP, 0, math.floor((slot - 1) / SLOTS_PER_ROW) * SLOT_GAP)
	m:PivotTo(cf)
	m.Parent = folder
	local origin = m:FindFirstChild("Origin", true)
	inst = { Model = m, OwnerId = owner.UserId, PropId = prop.Id, Origin = origin and origin.CFrame or cf, Slot = slot, Building = prop.Building, Number = prop.Number }
	instances[key] = inst
	-- Wohnungsnummer an der Tuer
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("TextLabel") and d.Name == "AptNumber" then
			d.Text = prop.Number
		end
	end
	local exitDoor = m:FindFirstChild("ExitDoor", true)
	if exitDoor then
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = "Wohnung verlassen"
		pr.ObjectText = prop.Number
		pr.KeyboardKeyCode = Enum.KeyCode.E
		pr.MaxActivationDistance = 9
		pr.RequiresLineOfSight = false
		pr.Parent = exitDoor
		pr.Triggered:Connect(function(player)
			P.Exit(player)
		end)
	end
	local panel = m:FindFirstChild("ManagePanel", true)
	if panel then
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = "Wohnung verwalten"
		pr.ObjectText = "Einrichtung, Schluessel, Gaeste"
		pr.KeyboardKeyCode = Enum.KeyCode.E
		pr.MaxActivationDistance = 9
		pr.RequiresLineOfSight = false
		pr.Parent = panel
		pr.Triggered:Connect(function(player)
			S.Push(player, "OpenProperty", { Manage = true })
		end)
	end
	spawnFurniture(inst, prop)
	return inst
end

local function destroyInstance(key)
	local inst = instances[key]
	if not inst then
		return
	end
	instances[key] = nil
	slots[inst.Slot] = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("InApartment") == key then
			local cf = exitCFrame(inst.Building)
			if cf then
				teleport(p, cf)
			end
			p:SetAttribute("InApartment", nil)
		end
	end
	inst.Model:Destroy()
end

local function occupants(key)
	local n = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("InApartment") == key then
			n += 1
		end
	end
	return n
end

-- Zugriff -------------------------------------------------------------------------------------------
local function canEnter(guest, owner, prop)
	if guest == owner then
		return true
	end
	for _, k in ipairs(prop.Keys or {}) do
		if k.UserId == guest.UserId then
			return true, "Schluessel"
		end
	end
	-- Einladung (5 Minuten) gilt immer; aufgeschlossen = offene Tuer, solange der Bewohner zu Hause ist (Party)
	local inv = invites[owner.UserId] and invites[owner.UserId][guest.UserId]
	if inv and inv.Prop == prop.Id and inv.Until > os.time() then
		return true, "Einladung"
	end
	if prop.Locked == false then
		return true, "Offen"
	end
	return false, "Abgeschlossen - klingeln und auf eine Einladung warten"
end

local function summary(prop)
	local t = Cfg.Tiers[prop.Tier]
	return {
		Id = prop.Id, Building = prop.Building, BuildingName = Cfg.Buildings[prop.Building] and Cfg.Buildings[prop.Building].Name or prop.Building,
		Tier = prop.Tier, TierName = t and t.Name or prop.Tier, Number = prop.Number, Mode = prop.Mode, Price = prop.Price,
		Rent = t and t.Rent or 0, RentUntil = prop.RentUntil or 0, Locked = prop.Locked ~= false, Keys = prop.Keys or {},
		Furniture = #(prop.Furniture or {}), Storage = prop.Storage or {},
		SellValue = prop.Mode == "Own" and math.floor((prop.Price or 0) * Cfg.SellFactor) or 0,
	}
end

-- Aktionen ------------------------------------------------------------------------------------------
function P.Info(player, buildingId)
	local b = Cfg.Buildings[buildingId]
	if not b then
		return false, "Unbekanntes Gebaeude"
	end
	if not nearBuilding(player, buildingId) then
		return false, "Du bist nicht am Eingang"
	end
	local offers = {}
	for _, tier in ipairs(b.Tiers) do
		local t = Cfg.Tiers[tier]
		table.insert(offers, { Tier = tier, Name = t.Name, Price = t.Price, Rent = t.Rent, Rooms = t.Rooms })
	end
	local mine = {}
	for _, prop in ipairs(propsOf(player)) do
		if prop.Building == buildingId then
			table.insert(mine, summary(prop))
		end
	end
	-- Wohnungen anderer (online) Bewohner in diesem Haus, fuer die ich Schluessel/Einladung habe oder klingeln kann
	local visits = {}
	for _, owner in ipairs(Players:GetPlayers()) do
		if owner ~= player then
			for _, prop in ipairs(propsOf(owner)) do
				if prop.Building == buildingId then
					local ok, how = canEnter(player, owner, prop)
					table.insert(visits, { Owner = owner.UserId, OwnerName = rpName(owner), Prop = prop.Id, Number = prop.Number, CanEnter = ok, How = how, Home = occupants(keyOf(owner.UserId, prop.Id)) > 0 })
				end
			end
		end
	end
	return true, nil, { Building = buildingId, Name = b.Name, District = b.District, Desc = b.Desc, Offers = offers, Mine = mine, Visits = visits, Count = #propsOf(player), Max = Cfg.MaxProperties, RentDays = Cfg.RentDays }
end

local function acquire(player, p, mode)
	local b = Cfg.Buildings[p.Building]
	local tier = Cfg.Tiers[p.Tier]
	if not (b and tier and table.find(b.Tiers, p.Tier)) then
		return false, "Angebot nicht verfuegbar"
	end
	if not nearBuilding(player, p.Building) then
		return false, "Nur am Eingang des Gebaeudes moeglich"
	end
	if #propsOf(player) >= Cfg.MaxProperties then
		return false, "Maximal " .. Cfg.MaxProperties .. " Immobilien"
	end
	if not S.EconomyService.ClaimTx(player, p.TxId) then
		return false, "Vorgang bereits ausgefuehrt"
	end
	local cost = mode == "Own" and tier.Price or tier.Rent
	local ok, err = S.EconomyService.Charge(player, "Bank", cost, (mode == "Own" and "Kauf " or "Miete ") .. b.Name)
	if not ok then
		return false, err
	end
	local number
	S.DataService.Mutate(player, "PropertyAcquire", function(data)
		local maxId = 0
		for _, x in ipairs(data.Properties.Owned) do
			maxId = math.max(maxId, x.Id or 0)
		end
		number = unitNumber(player, p.Building, p.Tier, maxId + 1)
		table.insert(data.Properties.Owned, {
			Id = maxId + 1, Building = p.Building, Tier = p.Tier, Number = number, Mode = mode, Price = mode == "Own" and tier.Price or 0,
			RentUntil = mode == "Rent" and (os.time() + Cfg.RentDays * 86400) or 0, Since = os.time(), Locked = true, Keys = {}, Furniture = {}, Storage = {},
		})
	end)
	S.Log("Property", player, nil, string.format("%s %s %s ($%d)", mode == "Own" and "Kauf" or "Miete", b.Name, tostring(number), cost))
	if S.BusinessService then
		S.BusinessService.OnProperty(cost) -- Prompt 11: Provision Immobilienunternehmen
	end
	return true, mode == "Own" and string.format("Wohnung %s gekauft - willkommen zu Hause!", number) or string.format("Mietvertrag fuer %s unterschrieben (%d Tage, %s)", number, Cfg.RentDays, S.Format.money(cost))
end

local function removeProp(player, propId)
	destroyInstance(keyOf(player.UserId, propId))
	local removed
	S.DataService.Mutate(player, "PropertyRemove", function(data)
		for i, x in ipairs(data.Properties.Owned) do
			if x.Id == propId then
				removed = table.remove(data.Properties.Owned, i)
				return
			end
		end
	end)
	return removed
end

function P.Sell(player, propId)
	local prop = findProp(player, propId)
	if not prop then
		return false, "Immobilie nicht gefunden"
	end
	if prop.Mode ~= "Own" then
		return false, "Mietwohnungen werden gekuendigt, nicht verkauft"
	end
	if not nearBuilding(player, prop.Building) then
		return false, "Verkauf nur am Eingang des Gebaeudes"
	end
	local value = math.floor((prop.Price or 0) * Cfg.SellFactor)
	if removeProp(player, propId) then
		if value > 0 then
			S.EconomyService.Credit(player, "Bank", value, "Verkauf Wohnung " .. prop.Number)
		end
		return true, string.format("Wohnung %s verkauft - %s gutgeschrieben", prop.Number, S.Format.money(value))
	end
	return false, "Immobilie nicht gefunden"
end

function P.CancelRent(player, propId)
	local prop = findProp(player, propId)
	if not prop or prop.Mode ~= "Rent" then
		return false, "Kein Mietvertrag gefunden"
	end
	removeProp(player, propId)
	return true, "Mietvertrag fuer " .. prop.Number .. " gekuendigt"
end

function P.Enter(player, p)
	local owner = Players:GetPlayerByUserId(typeof(p.Owner) == "number" and p.Owner or player.UserId)
	if not owner then
		return false, "Bewohner ist nicht in der Stadt"
	end
	local prop = findProp(owner, p.Prop)
	if not prop then
		return false, "Wohnung nicht gefunden"
	end
	if not nearBuilding(player, prop.Building) then
		return false, "Du bist nicht am Eingang von " .. (Cfg.Buildings[prop.Building] and Cfg.Buildings[prop.Building].Name or "")
	end
	local ok, why = canEnter(player, owner, prop)
	if not ok then
		return false, why
	end
	if player ~= owner and occupants(keyOf(owner.UserId, prop.Id)) == 0 and (why == "Einladung" or why == "Offen") then
		return false, "Der Bewohner ist nicht zu Hause"
	end
	local inst, err = ensureInstance(owner, prop)
	if not inst then
		return false, err
	end
	local spawn = inst.Model:FindFirstChild("Spawn", true)
	player:SetAttribute("InApartment", keyOf(owner.UserId, prop.Id))
	teleport(player, spawn and (spawn.CFrame * CFrame.new(0, 3, 0)) or (inst.Origin * CFrame.new(0, 4, 0)))
	if player ~= owner then
		S.Push(owner, "Notify", { Text = rpName(player) .. " hat deine Wohnung betreten", Kind = "info" })
	end
	return true, player == owner and ("Willkommen zu Hause - " .. prop.Number) or ("Wohnung " .. prop.Number .. " betreten")
end

function P.Exit(player)
	local key = player:GetAttribute("InApartment")
	local inst = key and instances[key]
	player:SetAttribute("InApartment", nil)
	if not inst then
		return false, "Du bist in keiner Wohnung"
	end
	local cf = exitCFrame(inst.Building)
	if cf then
		teleport(player, cf)
	end
	return true
end

function P.SetLock(player, propId, locked)
	local ok = S.DataService.Mutate(player, "PropertyLock", function(data)
		for _, x in ipairs(data.Properties.Owned) do
			if x.Id == propId then
				x.Locked = locked == true
				return
			end
		end
		return false, "Wohnung nicht gefunden"
	end)
	if not ok then
		return false, "Wohnung nicht gefunden"
	end
	return true, locked and "Wohnung abgeschlossen (nur Schluessel und Einladungen)" or "Wohnung offen - Besucher koennen eintreten, solange du zu Hause bist"
end

function P.Invite(player, propId, targetId)
	local prop = findProp(player, propId)
	local target = typeof(targetId) == "number" and Players:GetPlayerByUserId(targetId)
	if not prop or not target or target == player then
		return false, "Einladung nicht moeglich"
	end
	invites[player.UserId] = invites[player.UserId] or {}
	invites[player.UserId][target.UserId] = { Prop = propId, Until = os.time() + Cfg.InviteSeconds }
	S.Push(target, "Notify", { Text = string.format("%s laedt dich in Wohnung %s ein (%s) - am Eingang betreten", rpName(player), prop.Number, Cfg.Buildings[prop.Building].Name), Kind = "success" })
	return true, rpName(target) .. " eingeladen (5 Minuten gueltig)"
end

function P.Ring(player, ownerId, propId)
	local owner = typeof(ownerId) == "number" and Players:GetPlayerByUserId(ownerId)
	local prop = owner and findProp(owner, propId)
	if not prop or not nearBuilding(player, prop.Building) then
		return false, "Klingeln nicht moeglich"
	end
	if lastRing[player] and os.clock() - lastRing[player] < 10 then
		return false, "Bitte kurz warten"
	end
	lastRing[player] = os.clock()
	S.Push(owner, "Notify", { Text = string.format("🔔 %s klingelt an Wohnung %s - Einladen ueber Wohnung verwalten", rpName(player), prop.Number), Kind = "warning" })
	S.Push(owner, "PropertyRing", { From = player.UserId, Name = rpName(player), Prop = propId })
	return true, "Es klingelt bei " .. prop.Number
end

function P.Key(player, propId, targetId, give)
	local prop = findProp(player, propId)
	if not prop then
		return false, "Wohnung nicht gefunden"
	end
	if typeof(targetId) ~= "number" or targetId == player.UserId then
		return false, "Ungueltig"
	end
	local target = Players:GetPlayerByUserId(targetId)
	if give and not target then
		return false, "Spieler ist nicht online"
	end
	local ok, err = S.DataService.Mutate(player, "PropertyKey", function(data)
		for _, x in ipairs(data.Properties.Owned) do
			if x.Id == propId then
				x.Keys = x.Keys or {}
				for i, k in ipairs(x.Keys) do
					if k.UserId == targetId then
						if give then
							return false, "Hat bereits einen Schluessel"
						end
						table.remove(x.Keys, i)
						return
					end
				end
				if not give then
					return false, "Kein Schluessel vergeben"
				end
				if #x.Keys >= Cfg.MaxKeys then
					return false, "Maximal " .. Cfg.MaxKeys .. " Schluessel"
				end
				table.insert(x.Keys, { UserId = targetId, Name = rpName(target) })
				return
			end
		end
		return false, "Wohnung nicht gefunden"
	end)
	if not ok then
		return false, err
	end
	if give then
		S.Push(target, "Notify", { Text = string.format("%s hat dir einen Schluessel fuer Wohnung %s gegeben", rpName(player), prop.Number), Kind = "success" })
	end
	return true, give and "Schluessel uebergeben" or "Schluessel entzogen"
end

-- Moebel: nur der Eigentuemer/Mieter in der eigenen Wohnung
local function ownInstance(player)
	local key = player:GetAttribute("InApartment")
	local inst = key and instances[key]
	if not inst or inst.OwnerId ~= player.UserId then
		return nil
	end
	return inst, findProp(player, inst.PropId)
end

local function placementFor(player, inst)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local target = root.CFrame * CFrame.new(0, 0, -6)
	local rel = inst.Origin:ToObjectSpace(target)
	local half = inst.Model:GetAttribute("HalfSize") or Vector3.new(30, 0, 30)
	local x = math.clamp(math.floor(rel.X * 2 + 0.5) / 2, -half.X, half.X)
	local z = math.clamp(math.floor(rel.Z * 2 + 0.5) / 2, -half.Z, half.Z)
	local _, ry = rel:ToOrientation()
	local r = math.floor(math.deg(ry) / 45 + 0.5) * 45 + 180
	return x, z, r % 360
end

function P.Furniture(player, p)
	local action = p.Do
	if action == "Buy" then
		local f = Cfg.FurnitureById[p.Item]
		local prop = findProp(player, p.Prop)
		if not f or not prop then
			return false, "Ungueltig"
		end
		if not S.EconomyService.ClaimTx(player, p.TxId) then
			return false, "Vorgang bereits ausgefuehrt"
		end
		local ok, err = S.EconomyService.Charge(player, "Bank", f.Price, "Moebel " .. f.Name)
		if not ok then
			return false, err
		end
		S.DataService.Mutate(player, "FurnitureBuy", function(data)
			for _, x in ipairs(data.Properties.Owned) do
				if x.Id == prop.Id then
					x.Storage = x.Storage or {}
					x.Storage[f.Id] = (x.Storage[f.Id] or 0) + 1
				end
			end
		end)
		return true, f.Name .. " gekauft - im Lager der Wohnung " .. prop.Number
	end
	local inst, prop = ownInstance(player)
	if not inst or not prop then
		return false, "Nur in deiner eigenen Wohnung"
	end
	local msg
	local ok, err = S.DataService.Mutate(player, "Furniture" .. tostring(action), function(data)
		local x
		for _, e in ipairs(data.Properties.Owned) do
			if e.Id == prop.Id then
				x = e
			end
		end
		x.Furniture = x.Furniture or {}
		x.Storage = x.Storage or {}
		if action == "Place" then
			if (x.Storage[p.Item] or 0) < 1 then
				return false, "Nicht im Lager - zuerst kaufen"
			end
			if #x.Furniture >= Cfg.MaxFurniture then
				return false, "Maximal " .. Cfg.MaxFurniture .. " Moebel"
			end
			local fx, fz, fr = placementFor(player, inst)
			if not fx then
				return false, "Nicht moeglich"
			end
			x.Storage[p.Item] -= 1
			if x.Storage[p.Item] <= 0 then
				x.Storage[p.Item] = nil
			end
			table.insert(x.Furniture, { Id = p.Item, X = fx, Z = fz, R = fr })
			msg = Cfg.FurnitureById[p.Item].Name .. " platziert"
		elseif action == "Move" or action == "Rotate" or action == "Store" then
			local f = x.Furniture[p.Index]
			if not f then
				return false, "Moebelstueck nicht gefunden"
			end
			if action == "Move" then
				f.X, f.Z, f.R = placementFor(player, inst)
				msg = "Verschoben"
			elseif action == "Rotate" then
				f.R = ((f.R or 0) + 45) % 360
				msg = "Gedreht"
			else
				table.remove(x.Furniture, p.Index)
				x.Storage[f.Id] = (x.Storage[f.Id] or 0) + 1
				msg = "Ins Lager gestellt"
			end
		else
			return false, "Unbekannte Aktion"
		end
	end)
	if not ok then
		return false, err
	end
	spawnFurniture(inst, findProp(player, prop.Id))
	return true, msg
end

function P.Manage(player)
	local out = {}
	for _, prop in ipairs(propsOf(player)) do
		table.insert(out, summary(prop))
	end
	local key = player:GetAttribute("InApartment")
	local inst = key and instances[key]
	local placed = {}
	if inst and inst.OwnerId == player.UserId then
		local prop = findProp(player, inst.PropId)
		for i, f in ipairs(prop and prop.Furniture or {}) do
			table.insert(placed, { Index = i, Id = f.Id, Name = Cfg.FurnitureById[f.Id] and Cfg.FurnitureById[f.Id].Name or f.Id })
		end
	end
	local online = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p:GetAttribute("CharacterCreated") then
			table.insert(online, { UserId = p.UserId, Name = rpName(p) })
		end
	end
	return true, nil, { Props = out, InsideProp = (inst and inst.OwnerId == player.UserId) and inst.PropId or nil, Placed = placed, Online = online, MaxKeys = Cfg.MaxKeys }
end

-- Miete: automatische Verlaengerung vom Bankkonto, sonst endet der Vertrag
local function processRent(player)
	local d = S.DataService.Get(player)
	if not d then
		return
	end
	for _, prop in ipairs(table.clone(d.Properties.Owned)) do
		if prop.Mode == "Rent" and (prop.RentUntil or 0) < os.time() then
			local t = Cfg.Tiers[prop.Tier]
			local ok = t and S.EconomyService.Charge(player, "Bank", t.Rent, "Miete " .. prop.Number)
			if ok then
				S.DataService.Mutate(player, "RentRenew", function(data)
					for _, x in ipairs(data.Properties.Owned) do
						if x.Id == prop.Id then
							x.RentUntil = math.max(x.RentUntil or 0, os.time()) + Cfg.RentDays * 86400
						end
					end
				end)
				S.Push(player, "Notify", { Text = string.format("Miete fuer %s abgebucht (%s)", prop.Number, S.Format.money(t.Rent)), Kind = "info" })
			else
				removeProp(player, prop.Id)
				S.Push(player, "Notify", { Text = "Mietvertrag " .. prop.Number .. " beendet - Konto nicht gedeckt", Kind = "error" })
			end
		end
	end
end

local function tbl(p)
	return typeof(p) == "table" and p or {}
end
P.Actions = {
	["Property.Info"] = function(player, p)
		return P.Info(player, tbl(p).Building)
	end,
	["Property.Buy"] = function(player, p)
		return acquire(player, tbl(p), "Own")
	end,
	["Property.Rent"] = function(player, p)
		return acquire(player, tbl(p), "Rent")
	end,
	["Property.Sell"] = function(player, p)
		return P.Sell(player, tbl(p).Prop)
	end,
	["Property.CancelRent"] = function(player, p)
		return P.CancelRent(player, tbl(p).Prop)
	end,
	["Property.Enter"] = function(player, p)
		return P.Enter(player, tbl(p))
	end,
	["Property.Exit"] = function(player)
		return P.Exit(player)
	end,
	["Property.SetLock"] = function(player, p)
		return P.SetLock(player, tbl(p).Prop, tbl(p).Locked)
	end,
	["Property.Invite"] = function(player, p)
		return P.Invite(player, tbl(p).Prop, tbl(p).Target)
	end,
	["Property.Ring"] = function(player, p)
		return P.Ring(player, tbl(p).Owner, tbl(p).Prop)
	end,
	["Property.GiveKey"] = function(player, p)
		return P.Key(player, tbl(p).Prop, tbl(p).Target, true)
	end,
	["Property.RevokeKey"] = function(player, p)
		return P.Key(player, tbl(p).Prop, tbl(p).Target, false)
	end,
	["Property.Furniture"] = function(player, p)
		return P.Furniture(player, tbl(p))
	end,
	["Property.Manage"] = function(player)
		return P.Manage(player)
	end,
	["Property.FurnitureCatalog"] = function()
		local out = {}
		for _, f in ipairs(Cfg.Furniture) do
			table.insert(out, { Id = f.Id, Name = f.Name, Price = f.Price })
		end
		return true, nil, out
	end,
}

function P.Start()
	folder = workspace:FindFirstChild("ApartmentInstances") or Instance.new("Folder")
	folder.Name = "ApartmentInstances"
	folder.Parent = workspace
	S.InteractionService.Register("Property", function(player, inst)
		S.Push(player, "OpenProperty", { Building = inst:GetAttribute("BuildingId") })
	end)
	S.DataService.ProfileLoaded:Connect(function(player)
		task.delay(5, processRent, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		player:SetAttribute("InApartment", nil)
		for key, inst in pairs(instances) do
			if inst.OwnerId == player.UserId then
				destroyInstance(key)
			end
		end
		invites[player.UserId] = nil
		lastRing[player] = nil
	end)
	-- Respawn ausserhalb: Wohnungsstatus zuruecksetzen
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("InApartment", nil)
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function()
			player:SetAttribute("InApartment", nil)
		end)
	end
	-- Aufraeumen: leere Instanzen nach 60 s entfernen; Mieten stuendlich pruefen
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(15)
			tick += 1
			for key, inst in pairs(instances) do
				if occupants(key) == 0 then
					inst.EmptySince = inst.EmptySince or os.clock()
					if os.clock() - inst.EmptySince > 60 then
						destroyInstance(key)
					end
				else
					inst.EmptySince = nil
				end
			end
			if tick % 240 == 0 then
				for _, p in ipairs(Players:GetPlayers()) do
					processRent(p)
				end
			end
		end
	end)
end

return P
