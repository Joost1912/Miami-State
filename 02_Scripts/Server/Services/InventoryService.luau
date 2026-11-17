-- InventoryService: zentrales Inventar. Alle Aenderungen serverseitig geprueft.
-- Neue Gegenstaende: Config.Items erweitern; neue Nutzungsarten: InventoryService.RegisterUse(name, fn).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local Items = require(Shared.Config.Items)

local InventoryService = {}
local DataService, push

local useHandlers = {}

function InventoryService.Init(services)
	DataService = services.DataService
	push = services.Push
end

local function slotCount(inv)
	local n = 0
	for _, c in pairs(inv.Items) do
		if c > 0 then
			n += 1
		end
	end
	return n
end

function InventoryService.Count(player, itemId)
	local d = DataService.Get(player)
	return d and (d.Inventory.Items[itemId] or 0) or 0
end

function InventoryService.Has(player, itemId, count)
	return InventoryService.Count(player, itemId) >= (count or 1)
end

function InventoryService.CanAdd(data, itemId, count)
	local def = Items.Defs[itemId]
	if not def then
		return false, "Unbekannter Gegenstand"
	end
	if typeof(count) ~= "number" or count < 1 or count % 1 ~= 0 then
		return false, "Ungueltige Anzahl"
	end
	local have = data.Inventory.Items[itemId] or 0
	if have + count > def.Stack then
		return false, string.format("Maximal %d x %s", def.Stack, def.Name)
	end
	if have == 0 and slotCount(data.Inventory) >= Items.MaxSlots then
		return false, "Inventar voll"
	end
	return true
end

function InventoryService.Add(player, itemId, count, reason)
	count = count or 1
	return DataService.Mutate(player, "ItemAdd:" .. tostring(reason), function(d)
		local ok, err = InventoryService.CanAdd(d, itemId, count)
		if not ok then
			return false, err
		end
		d.Inventory.Items[itemId] = (d.Inventory.Items[itemId] or 0) + count
	end)
end

function InventoryService.Remove(player, itemId, count, reason)
	count = count or 1
	if typeof(count) ~= "number" or count < 1 or count % 1 ~= 0 then
		return false, "Ungueltige Anzahl"
	end
	return DataService.Mutate(player, "ItemRemove:" .. tostring(reason), function(d)
		local have = d.Inventory.Items[itemId] or 0
		if have < count then
			return false, "Nicht genug Gegenstaende"
		end
		d.Inventory.Items[itemId] = (have - count > 0) and (have - count) or nil
	end)
end

function InventoryService.RegisterUse(name, fn)
	useHandlers[name] = fn
end

-- Benutzen: Handler entscheidet, ob ein Exemplar verbraucht wird (return true, msg)
function InventoryService.Use(player, itemId)
	if typeof(itemId) ~= "string" then
		return false, "Ungueltig"
	end
	local def = Items.Defs[itemId]
	if not def then
		return false, "Unbekannter Gegenstand"
	end
	if not InventoryService.Has(player, itemId) then
		return false, "Nicht im Inventar"
	end
	if def.Restricted then
		return false, def.Name .. " ist noch nicht verfuegbar"
	end
	local handler = def.Use and useHandlers[def.Use]
	if not handler then
		return false, def.Name .. " kann nicht benutzt werden"
	end
	local consume, msg = handler(player, def, itemId)
	if consume == nil then
		return false, msg
	end
	if consume then
		InventoryService.Remove(player, itemId, 1, "Use")
	end
	return true, msg
end

-- Standard-Nutzungen ----------------------------------------------------------------------
InventoryService.RegisterUse("Heal", function(player, def)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil, "Nicht moeglich"
	end
	if hum.Health >= hum.MaxHealth then
		return nil, "Du bist bereits voll geheilt"
	end
	hum.Health = math.min(hum.MaxHealth, hum.Health + def.Amount)
	return true, def.Name .. " benutzt (+" .. def.Amount .. " HP)"
end)

InventoryService.RegisterUse("Consume", function(player, def)
	return true, def.Name .. " verbraucht"
end)

InventoryService.RegisterUse("ShowID", function(player)
	local d = DataService.Get(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not d or not root then
		return nil, "Nicht moeglich"
	end
	local card = {
		Name = d.Character.FirstName .. " " .. d.Character.LastName,
		BirthYear = d.Character.BirthYear,
		Gender = d.Character.Gender,
		Faction = d.Job.Faction,
	}
	local shown = 0
	for _, other in ipairs(Players:GetPlayers()) do
		local r = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - root.Position).Magnitude <= 15 then
			push(other, "ShowID", card)
			shown += 1
		end
	end
	return false, string.format("Ausweis %d Person(en) gezeigt", shown) -- wird nicht verbraucht
end)

return InventoryService
