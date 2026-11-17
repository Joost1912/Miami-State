-- ClothingService (Prompt 08): Kleidung tragen, Outfits speichern/wechseln.
-- * Kauf laeuft ueber ShopService (Wardrobe.Owned). Anziehen/Outfits nur im Kleidungsgeschaeft (Abstand serverseitig).
-- * Darstellung ohne fremde Assets: Koerperfarben (Oberteil/Hose) + einfache Teile als Accessoires ("CL_*").
-- * Im Dienst (Polizei/Feuerwehr/EMS) hat die Uniform Vorrang; nach Dienstende wird das Outfit wieder angelegt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local Clothing = require(Shared.Config.Clothing)
local Shops = require(Shared.Config.Shops)
local EconomyConfig = require(Shared.Config.Economy)

local ClothingService = {}
local S
local PREFIX = "CL_"
local UNIFORM = { Police = true, Fire = true, EMS = true }
local SLOT_OK = {}
for _, s in ipairs(Clothing.Slots) do
	SLOT_OK[s.Id] = true
end
local lastAct = setmetatable({}, { __mode = "k" })

function ClothingService.Init(services)
	S = services
end

local function hum(p)
	return p.Character and p.Character:FindFirstChildOfClass("Humanoid")
end

-- Accessoire aus Teilen: erstes Teil = Handle mit passender Attachment; weitere Teile angeschweisst
local function accessory(name, attachName, attachCF, parts)
	local acc = Instance.new("Accessory")
	acc.Name = PREFIX .. name
	local handle
	for i, def in ipairs(parts) do
		local p = Instance.new("Part")
		p.Name = (i == 1) and "Handle" or def.Name or ("Part" .. i)
		p.Size = def.Size
		p.Color = def.Color
		p.Material = def.Material or Enum.Material.Fabric
		if def.Shape then
			p.Shape = def.Shape
		end
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if def.Transparency then
			p.Transparency = def.Transparency
		end
		if i == 1 then
			handle = p
			p.CFrame = CFrame.new(0, 100, 0)
			local a = Instance.new("Attachment")
			a.Name = attachName
			a.CFrame = attachCF
			a.Parent = p
		else
			p.CFrame = handle.CFrame * def.Offset
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = handle, p
			w.Parent = p
		end
		p.Parent = acc
	end
	return acc
end

local HATS = {
	Cap = function(c)
		return { { Size = Vector3.new(1.18, 0.42, 1.18), Color = c }, { Name = "Brim", Size = Vector3.new(1.0, 0.08, 0.62), Color = c, Offset = CFrame.new(0, -0.17, -0.82) } }, CFrame.new(0, -0.08, 0.02)
	end,
	Beanie = function(c)
		return { { Size = Vector3.new(1.22, 0.55, 1.22), Color = c, Material = Enum.Material.Fabric } }, CFrame.new(0, -0.14, 0)
	end,
	Fedora = function(c)
		return { { Size = Vector3.new(1.05, 0.5, 1.05), Color = c, Material = Enum.Material.Fabric }, { Name = "Brim", Size = Vector3.new(1.75, 0.07, 1.75), Color = c, Offset = CFrame.new(0, -0.22, 0) }, { Name = "Band", Size = Vector3.new(1.07, 0.1, 1.07), Color = Color3.fromRGB(40, 30, 24), Offset = CFrame.new(0, -0.12, 0) } }, CFrame.new(0, -0.12, 0)
	end,
	Bucket = function(c)
		return { { Size = Vector3.new(1.15, 0.45, 1.15), Color = c, Material = Enum.Material.Fabric }, { Name = "Brim", Size = Vector3.new(1.55, 0.07, 1.55), Color = c, Offset = CFrame.new(0, -0.24, 0) } }, CFrame.new(0, -0.1, 0)
	end,
}

local function glassesParts(def)
	local frame = def.Frame or def.Color
	local clear = def.Model == "Glasses"
	return {
		{ Size = Vector3.new(0.95, 0.06, 0.06), Color = frame, Material = Enum.Material.Metal },
		{ Name = "LensL", Size = Vector3.new(0.38, 0.24, 0.04), Color = def.Color, Material = Enum.Material.Glass, Transparency = clear and 0.6 or 0.05, Offset = CFrame.new(-0.22, -0.12, 0) },
		{ Name = "LensR", Size = Vector3.new(0.38, 0.24, 0.04), Color = def.Color, Material = Enum.Material.Glass, Transparency = clear and 0.6 or 0.05, Offset = CFrame.new(0.22, -0.12, 0) },
	}
end

local function clearAccessories(char)
	for _, c in ipairs(char and char:GetChildren() or {}) do
		if c:IsA("Accessory") and c.Name:sub(1, #PREFIX) == PREFIX then
			c:Destroy()
		end
	end
end

-- Aktuelle Kleidung anlegen (oder entfernen, wenn im Dienst)
function ClothingService.Apply(player)
	local d = S.DataService.Get(player)
	local h = hum(player)
	local char = player.Character
	if not d or not h or not char or not d.Character.Created then
		return
	end
	clearAccessories(char)
	if d.Job.OnDuty and UNIFORM[d.Job.Faction] then
		return -- Uniform hat Vorrang
	end
	local cur = d.Wardrobe.Current
	if next(cur) == nil then
		return -- nichts gekauft/gewaehlt: Roblox-Avatar bleibt unveraendert
	end
	local top, bottom = Clothing.Defs[cur.Top or ""], Clothing.Defs[cur.Bottom or ""]
	if top or bottom then
		local ok, desc = pcall(function()
			return h:GetAppliedDescription()
		end)
		if ok and desc then
			local skin = S.CharacterService.SkinTones[d.Character.Appearance.Skin] or desc.HeadColor
			if top then
				desc.Shirt, desc.GraphicTShirt = 0, 0
				desc.TorsoColor = top.Color
				desc.LeftArmColor = top.Sleeves and top.Color or skin
				desc.RightArmColor = top.Sleeves and top.Color or skin
			end
			if bottom then
				desc.Pants = 0
				desc.LeftLegColor, desc.RightLegColor = bottom.Color, bottom.Color
			end
			pcall(function()
				h:ApplyDescription(desc)
			end)
		end
	end
	-- Accessoires (nach ApplyDescription, das fremde Accessoires zuruecksetzen kann)
	local hat = Clothing.Defs[cur.Hat or ""]
	if hat and HATS[hat.Model] then
		local parts, cf = HATS[hat.Model](hat.Color)
		h:AddAccessory(accessory("Hat", "HatAttachment", cf, parts))
	end
	local gl = Clothing.Defs[cur.Glasses or ""]
	if gl then
		h:AddAccessory(accessory("Glasses", "FaceFrontAttachment", CFrame.new(0, -0.18, 0.02), glassesParts(gl)))
	end
	local shoes = Clothing.Defs[cur.Shoes or ""]
	if shoes and char:FindFirstChild("LeftFoot") then
		for _, side in ipairs({ "Left", "Right" }) do
			local foot = char:FindFirstChild(side .. "Foot")
			if foot then
				local sz = foot.Size
				local acc = accessory("Shoe" .. side, side .. "FootAttachment", CFrame.new(0, sz.Y * 0.1, -0.02), {
					{ Size = Vector3.new(sz.X + 0.08, sz.Y * 0.95, sz.Z + 0.14), Color = shoes.Color, Material = Enum.Material.SmoothPlastic },
					{ Name = "Sole", Size = Vector3.new(sz.X + 0.1, 0.08, sz.Z + 0.16), Color = Color3.fromRGB(235, 235, 230), Offset = CFrame.new(0, -sz.Y * 0.47, 0) },
				})
				h:AddAccessory(acc)
			end
		end
	end
end

-- Im Kleidungsgeschaeft?
local function atClothingStore(player)
	local shop = S.InteractionService.NearestOfType(player, "Shop", EconomyConfig.ShopRange)
	local cat = shop and Shops.Catalogs[shop:GetAttribute("ShopId") or ""]
	return cat ~= nil and cat.Kind == "Clothing"
end

local function guard(player)
	if lastAct[player] and os.clock() - lastAct[player] < 0.5 then
		return "Bitte kurz warten"
	end
	lastAct[player] = os.clock()
	if not atClothingStore(player) then
		return "Umziehen nur im Kleidungsgeschaeft"
	end
	return nil
end

-- Auswahl pruefen: nur bekannte Slots, nur gekaufte Teile, Teil passt zum Slot
local function cleanSelection(d, sel)
	if typeof(sel) ~= "table" then
		return nil, "Ungueltig"
	end
	local out = {}
	for slot, id in pairs(sel) do
		if typeof(slot) ~= "string" or not SLOT_OK[slot] then
			return nil, "Ungueltiger Bereich"
		end
		if id ~= false then
			local def = typeof(id) == "string" and Clothing.Defs[id]
			if not def or def.Slot ~= slot then
				return nil, "Ungueltiges Kleidungsstueck"
			end
			if not table.find(d.Wardrobe.Owned, id) then
				return nil, def.Name .. " gehoert dir nicht"
			end
			out[slot] = id
		end
	end
	return out
end

-- Einzelne Teile an-/ablegen. sel = { Top = "Tee_White", Hat = false, ... } (false = ausziehen)
function ClothingService.Wear(player, sel)
	local why = guard(player)
	if why then
		return false, why
	end
	local d = S.DataService.Get(player)
	local clean, err = cleanSelection(d, sel)
	if not clean then
		return false, err
	end
	local ok, e2 = S.DataService.Mutate(player, "ClothingWear", function(data)
		for slot, v in pairs(sel) do
			data.Wardrobe.Current[slot] = (v ~= false) and clean[slot] or nil
		end
	end)
	if not ok then
		return false, e2
	end
	task.spawn(ClothingService.Apply, player)
	return true, "Kleidung angepasst"
end

function ClothingService.SaveOutfit(player, index)
	if typeof(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > Clothing.MaxOutfits then
		return false, "Ungueltiger Platz"
	end
	local why = guard(player)
	if why then
		return false, why
	end
	local ok, err = S.DataService.Mutate(player, "OutfitSave", function(d)
		if next(d.Wardrobe.Current) == nil then
			return false, "Du traegst keine gekaufte Kleidung"
		end
		-- Luecken auffuellen (Liste bleibt fuer den Datenspeicher zusammenhaengend)
		for i = 1, index - 1 do
			d.Wardrobe.Outfits[i] = d.Wardrobe.Outfits[i] or {}
		end
		d.Wardrobe.Outfits[index] = table.clone(d.Wardrobe.Current)
	end)
	return ok, ok and ("Outfit " .. index .. " gespeichert") or err
end

function ClothingService.WearOutfit(player, index)
	local d = S.DataService.Get(player)
	local o = typeof(index) == "number" and d.Wardrobe.Outfits[index]
	if not o or next(o) == nil then
		return false, "Outfit-Platz ist leer"
	end
	local why = guard(player)
	if why then
		return false, why
	end
	local clean, err = cleanSelection(d, o)
	if not clean then
		return false, err
	end
	local ok, e2 = S.DataService.Mutate(player, "OutfitWear", function(data)
		data.Wardrobe.Current = clean
	end)
	if not ok then
		return false, e2
	end
	task.spawn(ClothingService.Apply, player)
	return true, "Outfit " .. index .. " angezogen"
end

function ClothingService.DeleteOutfit(player, index)
	if typeof(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > Clothing.MaxOutfits then
		return false, "Ungueltiger Platz"
	end
	local ok, err = S.DataService.Mutate(player, "OutfitDelete", function(d)
		if not d.Wardrobe.Outfits[index] or next(d.Wardrobe.Outfits[index]) == nil then
			return false, "Outfit-Platz ist leer"
		end
		d.Wardrobe.Outfits[index] = {}
	end)
	return ok, ok and ("Outfit " .. index .. " geloescht") or err
end

-- Zurueck zum eigenen Roblox-Avatar (alle gekauften Teile ablegen)
function ClothingService.Reset(player)
	local why = guard(player)
	if why then
		return false, why
	end
	local ok, err = S.DataService.Mutate(player, "ClothingReset", function(d)
		d.Wardrobe.Current = {}
	end)
	if not ok then
		return false, err
	end
	clearAccessories(player.Character)
	task.spawn(function()
		if S.CharacterService.ApplyBase then
			S.CharacterService.ApplyBase(player)
		end
	end)
	return true, "Eigene Kleidung angezogen"
end

function ClothingService.Start()
	S.CharacterService.AfterAppearance = ClothingService.Apply
	S.DataService.Changed:Connect(function(player, _, reason)
		if typeof(player) == "Instance" and (reason == "Duty" or reason == "SetJob" or reason == "Resign") then
			-- nach UniformService (anlegen/abnehmen) ausfuehren
			task.delay(0.8, ClothingService.Apply, player)
		end
	end)
end

return ClothingService
