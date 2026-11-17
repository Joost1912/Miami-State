-- UniformService: Dienstkleidung aus Parts (ohne fremde Assets) fuer Polizei, Feuerwehr und Rettungsdienst.
-- Speichert das Aussehen vor dem Dienst und stellt es beim Dienstende wieder her.
-- spec = { Prefix = "FD_", Torso = Color3, Legs = Color3, Parts = { {Name, Attachment, Size, Color, Material, Offset}, ... } }
local Players = game:GetService("Players")

local UniformService = {}
local savedLook = {} -- [Player] = HumanoidDescription

function UniformService.Init() end

local function accessory(prefix, def)
	local acc = Instance.new("Accessory")
	acc.Name = prefix .. def[1]
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = def[3]
	h.Color = def[4]
	h.Material = Enum.Material[def[5]] or Enum.Material.SmoothPlastic
	h.CanCollide = false
	h.CanQuery = false
	h.CanTouch = false
	h.Massless = true
	h.Parent = acc
	local a = Instance.new("Attachment")
	a.Name = def[2]
	a.CFrame = def[6] or CFrame.new()
	a.Parent = h
	return acc
end

function UniformService.Apply(player, spec)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if not savedLook[player] then
		local ok, desc = pcall(function()
			return hum:GetAppliedDescription()
		end)
		if ok then
			savedLook[player] = desc:Clone()
		end
	end
	local ok, desc = pcall(function()
		return hum:GetAppliedDescription()
	end)
	if not ok then
		return
	end
	desc.Shirt, desc.Pants, desc.GraphicTShirt = 0, 0, 0
	-- alle Accessoires ausser Haaren entfernen
	pcall(function()
		local keep = {}
		for _, a in ipairs(desc:GetAccessories(true)) do
			if a.AccessoryType == Enum.AccessoryType.Hair then
				table.insert(keep, a)
			end
		end
		desc:SetAccessories(keep, true)
	end)
	desc.TorsoColor, desc.LeftArmColor, desc.RightArmColor = spec.Torso, spec.Torso, spec.Torso
	desc.LeftLegColor, desc.RightLegColor = spec.Legs, spec.Legs
	pcall(function()
		hum:ApplyDescription(desc)
	end)
	for _, def in ipairs(spec.Parts) do
		local a = accessory(spec.Prefix, def)
		local old = char:FindFirstChild(a.Name)
		if old then
			old:Destroy()
		end
		hum:AddAccessory(a)
	end
end

function UniformService.Remove(player, prefix)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if char then
		for _, c in ipairs(char:GetChildren()) do
			if c:IsA("Accessory") and c.Name:sub(1, #prefix) == prefix then
				c:Destroy()
			end
		end
	end
	if hum and savedLook[player] then
		pcall(function()
			hum:ApplyDescription(savedLook[player])
		end)
	end
	savedLook[player] = nil
end

-- Neuer Charakter (Respawn): gespeichertes Aussehen verwerfen, Uniform wird neu angelegt
function UniformService.Forget(player)
	savedLook[player] = nil
end

function UniformService.Start()
	Players.PlayerRemoving:Connect(function(player)
		savedLook[player] = nil
	end)
end

return UniformService
