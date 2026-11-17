-- InteractionService: einheitliche Interaktion mit der Spielwelt.
-- Jedes Objekt mit dem Tag "Interactable" bekommt automatisch einen ProximityPrompt.
-- Attribute: InteractType (ATM | Shop | Door | NPC | JobCenter | ...), InteractText, ObjectText, Range, ShopId, Dialog
-- Neue Interaktionsarten: InteractionService.Register(type, function(player, instance) ... end)
-- Bestehende Laden-Marker ("ShopEntrance"/"StoreEntrance") werden automatisch als Shop eingebunden.
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local Shops = require(Shared.Config.Shops)

local InteractionService = {}
local handlers = {}
local push, DataService, Services
local lastUse = {} -- [player] = { [instance] = os.clock() }

function InteractionService.Init(services)
	push = services.Push
	DataService = services.DataService
	Services = services
end

function InteractionService.Register(kind, fn)
	handlers[kind] = fn
end

local function rootOf(inst)
	if inst:IsA("BasePart") then
		return inst
	end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end
InteractionService.RootOf = rootOf

-- Abstand Spieler <-> Objekt (Server-Pruefung fuer alle ortsgebundenen Aktionen)
function InteractionService.Near(player, inst, range)
	local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local p = inst and rootOf(inst)
	return r ~= nil and p ~= nil and (r.Position - p.Position).Magnitude <= (range or 14)
end

-- naechstes getaggtes Objekt einer Art in Reichweite
function InteractionService.NearestOfType(player, kind, range)
	local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not r then
		return nil
	end
	local best, bestD
	for _, inst in ipairs(CollectionService:GetTagged("Interactable")) do
		if inst:GetAttribute("InteractType") == kind and inst:IsDescendantOf(workspace) then
			local p = rootOf(inst)
			local dist = p and (p.Position - r.Position).Magnitude
			if dist and dist <= range and (not bestD or dist < bestD) then
				best, bestD = inst, dist
			end
		end
	end
	return best
end

local function setupPrompt(inst, kind, text, objectText, range)
	local part = rootOf(inst)
	if not part then
		return
	end
	local prompt = part:FindFirstChild("InteractPrompt") or Instance.new("ProximityPrompt")
	prompt.Name = "InteractPrompt"
	prompt.ActionText = text or "Benutzen"
	prompt.ObjectText = objectText or ""
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = range or 10
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = inst:GetAttribute("HoldDuration") or 0 -- z.B. Ueberfall-Interaktionen (Prompt 09)
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		lastUse[player] = lastUse[player] or {}
		local t = lastUse[player][inst]
		if t and os.clock() - t < 0.5 then
			return -- Spam-Schutz
		end
		lastUse[player][inst] = os.clock()
		local h = handlers[kind]
		if h and DataService.Get(player) then
			local ok, err = pcall(h, player, inst)
			if not ok then
				warn("[Interaction] " .. kind .. ": " .. tostring(err))
			end
		end
	end)
end

local setupDone = setmetatable({}, { __mode = "k" })
local function setupTagged(inst)
	if not inst:IsDescendantOf(workspace) or setupDone[inst] then
		return
	end
	setupDone[inst] = true
	local kind = inst:GetAttribute("InteractType")
	if kind then
		setupPrompt(inst, kind, inst:GetAttribute("InteractText"), inst:GetAttribute("ObjectText"), inst:GetAttribute("Range"))
	end
end

-- Laden-Marker aus dem Kartenbau -> Shop-Interaktion
local function setupStoreMarker(inst)
	if not inst:IsDescendantOf(workspace) or inst:GetAttribute("InteractType") then
		return
	end
	local name = inst:GetAttribute("StoreName") or inst:GetAttribute("Shop")
	local catalog = name and Shops.ByName[name]
	if catalog then
		inst:SetAttribute("InteractType", "Shop")
		inst:SetAttribute("ShopId", catalog)
		inst:SetAttribute("InteractText", "Einkaufen")
		inst:SetAttribute("ObjectText", (name == "GasStationShop") and "Tankstellen-Shop" or Shops.Catalogs[catalog].Title or name)
		inst:SetAttribute("Range", 10)
		CollectionService:AddTag(inst, "Interactable") -- Prompt entsteht in setupTagged
		setupTagged(inst)
	end
end

-- Standard-Handler -----------------------------------------------------------------------
InteractionService.Register("ATM", function(player)
	push(player, "OpenBank", {})
end)

InteractionService.Register("Shop", function(player, inst)
	local id = inst:GetAttribute("ShopId")
	local cat = id and Shops.Catalogs[id]
	if cat then
		-- Katalog mit serverseitig berechneten Sperrgruenden (Waffenschein, Spielzeit, ...)
		local data = Services and Services.ShopService and Services.ShopService.Describe(player, id, inst)
		push(player, "OpenShop", data or { ShopId = id, Title = cat.Title, Kind = cat.Kind, Items = cat.Items })
	end
end)

InteractionService.Register("JobCenter", function(player)
	push(player, "OpenJobs", {})
end)

InteractionService.Register("NPC", function(player, inst)
	push(player, "Dialog", { Name = inst:GetAttribute("ObjectText") or inst.Name, Text = inst:GetAttribute("Dialog") or "Hallo!" })
end)

-- Tuer: Modell mit Part "Door" (+ optional Attribut Locked / RequiredFaction). Dreht 90 Grad um die Scharnierkante.
InteractionService.Register("Door", function(player, inst)
	local door = inst:IsA("Model") and inst:FindFirstChild("Door") or inst
	if inst:GetAttribute("Locked") then
		local req = inst:GetAttribute("RequiredFaction")
		local d = DataService.Get(player)
		if not (req and d and d.Job.Faction == req) then
			push(player, "Notify", { Text = "Abgeschlossen", Kind = "error" })
			return
		end
	end
	if inst:GetAttribute("Busy") then
		return
	end
	inst:SetAttribute("Busy", true)
	local closed = inst:GetAttribute("ClosedCFrame")
	if not closed then
		inst:SetAttribute("ClosedCFrame", door.CFrame)
		closed = door.CFrame
	end
	local open = not inst:GetAttribute("IsOpen")
	local hinge = closed * CFrame.new(-door.Size.X / 2, 0, 0)
	local target = open and (hinge * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(door.Size.X / 2, 0, 0)) or closed
	door.CanCollide = not open
	TweenService:Create(door, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { CFrame = target }):Play()
	task.wait(0.5)
	inst:SetAttribute("IsOpen", open)
	inst:SetAttribute("Busy", false)
end)

function InteractionService.Start()
	CollectionService:GetInstanceAddedSignal("Interactable"):Connect(setupTagged)
	for _, inst in ipairs(CollectionService:GetTagged("Interactable")) do
		setupTagged(inst)
	end
	for _, tag in ipairs({ "ShopEntrance", "StoreEntrance" }) do
		CollectionService:GetInstanceAddedSignal(tag):Connect(setupStoreMarker)
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			setupStoreMarker(inst)
		end
	end
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		lastUse[p] = nil
	end)
end

return InteractionService
