-- ActivityService (Prompt 10): einheitliche Grundlage fuer Downtown-Aktivitaeten.
-- Alles laeuft ueber den bestehenden InteractionService (Tag "Interactable", Taste E):
--   InteractType "VenueDoor"  Attribute Link, Side ("Out"|"In"), optional Requires (Item-Id), Consume (bool)
--                             -> Teleport zur Gegentuer (gleicher Link, andere Seite). Clubs, Kino, Restaurants, Rooftop.
--   InteractType "Activity"   Attribut ActivityId (siehe ACT) -> bezahlte/kostenlose Aktivitaet mit Fortschrittsanzeige
-- Bestehende Ladenmarker "FITNESS 24" / "YOGA STUDIO" werden automatisch zu Trainings-Punkten.
-- Freizeitwerte (Fitness, Bestwerte) liegen im Profil unter Leisure.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage:WaitForChild("MiamiShared").Config.Items)

local A = {}
local S
local busy = {} -- [player] = os.clock() Ende der laufenden Aktivitaet

-- Aktivitaeten: Fee (Bar oder Karte), Seconds (Dauer), Free = Item-Id, die die Gebuehr erspart
local ACT = {
	Gym = { Name = "Training", Fee = 15, Free = "GymPass", Seconds = 8, Anim = "Train" },
	Bowling = { Name = "Bowling", Fee = 20, Seconds = 9, Anim = "Bowl" },
	Arcade = { Name = "Arcade", Fee = 5, Seconds = 6, Anim = "Play" },
	Hoops = { Name = "Basketball", Fee = 0, Seconds = 7, Anim = "Shoot" },
	Dance = { Name = "Tanzen", Fee = 0, Seconds = 0, Anim = "Dance" },
	Cinema = { Name = "Film", Fee = 0, Seconds = 0, Anim = "Watch" },
	CarMeet = { Name = "Autotreffen", Fee = 0, Seconds = 0, Anim = "Meet" },
}
A.Activities = ACT

function A.Init(services)
	S = services
end

local function rpName(player)
	local d = S.DataService.Get(player)
	return d and d.Character.Created and (d.Character.FirstName .. " " .. d.Character.LastName) or player.Name
end

local function teleport(player, cf)
	local char = player.Character
	if not (char and char:FindFirstChild("HumanoidRootPart")) then
		return
	end
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 6)
	end)
	char:PivotTo(cf)
end

local function leisure(player, fn)
	return S.DataService.Mutate(player, "Leisure", function(d)
		d.Leisure = d.Leisure or {}
		fn(d.Leisure)
	end)
end

local function pay(player, fee, reason)
	if fee <= 0 then
		return true
	end
	local d = S.DataService.Get(player)
	local account = d.Money.Cash >= fee and "Cash" or "Bank"
	return S.EconomyService.Charge(player, account, fee, reason)
end

-- Venue-Tueren -------------------------------------------------------------------------------------
local function counterpart(door)
	local link, side = door:GetAttribute("Link"), door:GetAttribute("Side")
	for _, inst in ipairs(CollectionService:GetTagged("Interactable")) do
		if inst ~= door and inst:GetAttribute("InteractType") == "VenueDoor" and inst:GetAttribute("Link") == link and inst:GetAttribute("Side") ~= side then
			return inst
		end
	end
	return nil
end

local function useDoor(player, door)
	local target = counterpart(door)
	local part = target and S.InteractionService.RootOf(target)
	if not part then
		S.Push(player, "Notify", { Text = "Geschlossen", Kind = "error" })
		return
	end
	local req = door:GetAttribute("Requires")
	if req and req ~= "" then
		if S.InventoryService.Count(player, req) < 1 then
			local def = Items.Defs[req]
			S.Push(player, "Notify", { Text = "Zutritt nur mit " .. (def and def.Name or req), Kind = "error" })
			return
		end
		if door:GetAttribute("Consume") then
			S.InventoryService.Remove(player, req, 1, "Eintritt")
		end
	end
	-- Ankunft: 5 Studs vor der Zieltuer (Blickrichtung der Tuer = in den Raum hinein)
	teleport(player, part.CFrame * CFrame.new(0, 0, -5) + Vector3.new(0, 2.5, 0))
	local msg = target:GetAttribute("Welcome")
	if msg and msg ~= "" then
		S.Push(player, "Notify", { Text = msg, Kind = "info" })
	end
end

-- Aktivitaeten -------------------------------------------------------------------------------------
local function bowlingRoll(inst)
	-- Kugel rollt die Bahn hinunter, Kegel kippen (rein optisch, serverseitig fuer alle sichtbar)
	local lane = inst.Parent
	local ball = lane and lane:FindFirstChild("BallStart")
	local pins = lane and lane:FindFirstChild("Pins")
	if not (ball and pins) then
		return
	end
	local b = Instance.new("Part")
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.new(1.4, 1.4, 1.4)
	b.Color = Color3.fromRGB(math.random(40, 220), 40, math.random(80, 255))
	b.Material = Enum.Material.Glass
	b.Anchored, b.CanCollide = true, false
	b.CFrame = ball.CFrame
	b.Parent = lane
	local sum, cnt = Vector3.zero, 0
	for _, pin in ipairs(pins:GetChildren()) do
		if pin:IsA("BasePart") then
			sum += pin.Position
			cnt += 1
		end
	end
	local target = cnt > 0 and sum / cnt or ball.Position
	local tw = TweenService:Create(b, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(target) })
	tw:Play()
	tw.Completed:Wait()
	local knocked = 0
	for _, pin in ipairs(pins:GetChildren()) do
		if pin:IsA("BasePart") and math.random() < 0.75 then
			knocked += 1
			pin:SetAttribute("Home", pin:GetAttribute("Home") or pin.CFrame)
			TweenService:Create(pin, TweenInfo.new(0.3), { CFrame = pin.CFrame * CFrame.Angles(math.rad(math.random(70, 90)), 0, math.rad(math.random(-40, 40))) }):Play()
		end
	end
	task.wait(1.6)
	b:Destroy()
	for _, pin in ipairs(pins:GetChildren()) do
		if pin:IsA("BasePart") and pin:GetAttribute("Home") then
			pin.CFrame = pin:GetAttribute("Home")
		end
	end
	return knocked
end

local function finish(player, id, inst)
	if id == "Gym" then
		local lvl
		leisure(player, function(l)
			l.Fitness = math.min(100, (l.Fitness or 0) + 1)
			lvl = l.Fitness
		end)
		return string.format("Training abgeschlossen - Fitness %d/100", lvl or 0)
	elseif id == "Bowling" then
		local score = math.clamp(math.floor(60 + math.random() * 140 + math.random() * 100), 30, 300)
		local best
		leisure(player, function(l)
			l.Bowling = math.max(l.Bowling or 0, score)
			best = l.Bowling
		end)
		return string.format("Bowling: %d Punkte (Bestwert %d)%s", score, best, score >= 250 and " - Profi!" or "")
	elseif id == "Arcade" then
		local score = math.floor(math.random() ^ 2 * 98000 + 2000)
		local best
		leisure(player, function(l)
			l.Arcade = math.max(l.Arcade or 0, score)
			best = l.Arcade
		end)
		return string.format("Arcade: %d Punkte (Highscore %d)", score, best)
	elseif id == "Hoops" then
		local fit = (S.DataService.Get(player).Leisure or {}).Fitness or 0
		local hits = 0
		for _ = 1, 10 do
			if math.random() < 0.35 + fit / 250 then
				hits += 1
			end
		end
		local best
		leisure(player, function(l)
			l.Hoops = math.max(l.Hoops or 0, hits)
			best = l.Hoops
		end)
		return string.format("Basketball: %d/10 Treffer (Bestwert %d)", hits, best)
	end
	return nil
end

function A.Begin(player, inst)
	local id = inst:GetAttribute("ActivityId")
	local act = ACT[id]
	if not act then
		return
	end
	if player:GetAttribute("Cuffed") or player:GetAttribute("Injury") == "Unconscious" then
		return
	end
	-- sofortige Aktivitaeten (Tanzen, Kino, Autotreffen): nur Client-Animation/Anzeige
	if act.Seconds <= 0 then
		S.Push(player, "Activity", { Kind = act.Anim, Name = act.Name, Text = inst:GetAttribute("ObjectText") })
		return
	end
	if busy[player] and os.clock() < busy[player] then
		S.Push(player, "Notify", { Text = "Du bist gerade beschaeftigt", Kind = "error" })
		return
	end
	if inst:GetAttribute("InUseBy") and inst:GetAttribute("InUseBy") ~= player.UserId and Players:GetPlayerByUserId(inst:GetAttribute("InUseBy")) then
		S.Push(player, "Notify", { Text = "Gerade belegt - kurz warten", Kind = "error" })
		return
	end
	local fee = act.Fee
	if act.Free and S.InventoryService.Count(player, act.Free) > 0 then
		fee = 0
	end
	local ok, err = pay(player, fee, act.Name)
	if not ok then
		S.Push(player, "Notify", { Text = err, Kind = "error" })
		return
	end
	busy[player] = os.clock() + act.Seconds
	inst:SetAttribute("InUseBy", player.UserId)
	S.Push(player, "Activity", { Kind = act.Anim, Name = act.Name, Seconds = act.Seconds, Fee = fee })
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local startPos = root and root.Position
	local knocked
	if id == "Bowling" then
		task.delay(act.Seconds - 4.2, function()
			knocked = bowlingRoll(inst)
		end)
	end
	task.delay(act.Seconds, function()
		inst:SetAttribute("InUseBy", nil)
		busy[player] = nil
		if not player.Parent then
			return
		end
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not r or not startPos or (r.Position - startPos).Magnitude > 14 then
			S.Push(player, "Notify", { Text = act.Name .. " abgebrochen", Kind = "warning" })
			return
		end
		local msg = finish(player, id, inst)
		if msg then
			if knocked == 10 then
				msg = "STRIKE! " .. msg
			end
			S.Push(player, "Notify", { Text = msg, Kind = "success" })
		end
	end)
end

-- Essen in Restaurants: heilt wenig (nicht bewusstlos), Profilwert "Meals"
local function registerMeal()
	S.InventoryService.RegisterUse("Meal", function(player, def)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 or player:GetAttribute("Injury") == "Unconscious" then
			return nil, "Nicht moeglich"
		end
		local amount = def.Amount or 2
		hum.Health = math.min(hum.MaxHealth, hum.Health + amount)
		S.Push(player, "Activity", { Kind = "Eat", Name = def.Name })
		return true, string.format("%s - lecker! (+%d)", def.Name, amount)
	end)
end

local function convertMarkers()
	for _, tag in ipairs({ "StoreEntrance", "ShopEntrance" }) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			local name = inst:GetAttribute("StoreName")
			if (name == "FITNESS 24" or name == "YOGA STUDIO") and not inst:GetAttribute("InteractType") and inst:IsDescendantOf(workspace) then
				inst:SetAttribute("InteractType", "Activity")
				inst:SetAttribute("ActivityId", "Gym")
				inst:SetAttribute("InteractText", "Training ($15)")
				inst:SetAttribute("ObjectText", name == "FITNESS 24" and "Fitness 24" or "Yoga Studio")
				inst:SetAttribute("Range", 10)
				CollectionService:AddTag(inst, "Interactable")
			end
		end
	end
end

A.Actions = {
	["Activity.Stats"] = function(player)
		local d = S.DataService.Get(player)
		return true, nil, d.Leisure or {}
	end,
}

function A.Start()
	S.InteractionService.Register("VenueDoor", useDoor)
	S.InteractionService.Register("Activity", A.Begin)
	registerMeal()
	convertMarkers()
	Players.PlayerRemoving:Connect(function(p)
		busy[p] = nil
	end)
end

return A
