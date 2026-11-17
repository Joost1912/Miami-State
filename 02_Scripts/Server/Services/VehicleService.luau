-- VehicleService (Modul, ersetzt das fruehere eigenstaendige VehicleService-Skript)
-- * Spawnen aus Vorlagen (ServerStorage.Vehicles), Kennzeichen + Fahrzeugregister (MDT-Abfrage)
-- * Netzwerkeigentum an den Fahrer, Einsteigen per Prompt (F Fahrer / G Mitfahrer)
-- * Spawnpunkte (Tag "VehicleSpawnPad"), Pflichtberuf ueber JobService
-- * Fahrzeugsteuerung (RemoteEvent "VehicleControl"): Blaulicht, Sirene, Sirenenton, Hupe, Warnblinker, Licht
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local Factions = require(Shared.Config.Factions)
local PoliceCfg = require(Shared.Config.Police)

local VehicleService = {}
local S
local folder
local registry = {} -- [Plate] = { Model, Type, OwnerUserId, OwnerName, Kind, Registered }
local owned = {} -- [Player] = { [slot] = Model }
local lastSpawn = {}
local lastControl = {}
local setupDone = setmetatable({}, { __mode = "k" })
local SPAWN_COOLDOWN = 4

function VehicleService.Init(services)
	S = services
end

local function playerFromHumanoid(hum)
	return hum and Players:GetPlayerFromCharacter(hum.Parent)
end

local function rpName(player)
	local d = S.DataService.Get(player)
	return d and d.Character.Created and (d.Character.FirstName .. " " .. d.Character.LastName) or player.Name
end

local function setBrake(model)
	local torque = model:GetAttribute("BrakeTorque") or 4000
	for _, c in ipairs(model:GetDescendants()) do
		if c:IsA("HingeConstraint") and c.Name == "DriveMotor" then
			c.AngularVelocity = 0
			c.MotorMaxTorque = torque
		elseif c:IsA("HingeConstraint") and c.Name == "SteerServo" then
			c.TargetAngle = 0
		end
	end
end

local PLATE_PREFIX = { Police = "MSP", Fire = "MSFD", EMS = "EMS" }
local function newPlate(kind, player)
	if PLATE_PREFIX[kind] then
		local d = S.DataService.Get(player)
		local fd = d and d.FactionData[kind]
		local badge = (fd and fd.Badge ~= 0) and fd.Badge or math.random(1000, 9999)
		return PLATE_PREFIX[kind] .. "-" .. badge
	end
	for _ = 1, 50 do
		local p = string.format("MS-%04d%s", math.random(0, 9999), string.char(math.random(65, 90)))
		if not registry[p] then
			return p
		end
	end
	return "MS-" .. tostring(os.clock()):gsub("%.", "")
end

-- Fahrer-/Mitfahrer-Prompts
local function addSeatPrompt(seat, text, key)
	local prompt = seat:FindFirstChild("EnterPrompt") or Instance.new("ProximityPrompt")
	prompt.Name = "EnterPrompt"
	prompt.ActionText = text
	prompt.ObjectText = seat.Parent:GetAttribute("Plate") or seat.Parent:GetAttribute("VehicleType") or "Fahrzeug"
	prompt.KeyboardKeyCode = key
	prompt.GamepadKeyCode = (key == Enum.KeyCode.F) and Enum.KeyCode.ButtonY or Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = seat
	prompt.Triggered:Connect(function(player)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if player:GetAttribute("Cuffed") or player:GetAttribute("Jailed") or player:GetAttribute("Injury") == "Unconscious" then
			return
		end
		if hum and hum.Health > 0 and not hum.SeatPart and not seat.Occupant then
			seat:Sit(hum)
		end
	end)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		prompt.Enabled = seat.Occupant == nil
	end)
end

local function setupVehicle(model)
	if setupDone[model] or not model:IsDescendantOf(workspace) then
		return
	end
	setupDone[model] = true
	local seat = model:FindFirstChild("DriverSeat")
	local chassis = model:FindFirstChild("Chassis")
	if not (seat and chassis) then
		return
	end
	addSeatPrompt(seat, "Einsteigen", Enum.KeyCode.F)
	for _, s in ipairs(model:GetChildren()) do
		if s:IsA("Seat") then
			addSeatPrompt(s, "Mitfahren", Enum.KeyCode.G)
		end
	end
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occ = seat.Occupant
		local player = playerFromHumanoid(occ)
		local char = occ and occ.Parent
		local restrained = (player and (player:GetAttribute("Cuffed") or player:GetAttribute("Jailed") or player:GetAttribute("Injury") == "Unconscious"))
			or (char and (char:GetAttribute("Cuffed") or char:GetAttribute("Jailed")))
		if restrained then
			-- gefesselte/inhaftierte Personen duerfen nicht fahren: Sitzverbindung serverseitig loesen
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
			occ.Sit = false
			return
		end
		if player then
			pcall(chassis.SetNetworkOwner, chassis, player)
		else
			pcall(chassis.SetNetworkOwner, chassis, nil)
			setBrake(model)
		end
	end)
	pcall(chassis.SetNetworkOwner, chassis, nil)
	setBrake(model)
end

-- API --------------------------------------------------------------------------------------
-- slot: "Civil" | "Police" | "Service" (je Slot ein Fahrzeug pro Spieler)
function VehicleService.Spawn(player, typeName, cf, slot, kind, fixedPlate, color)
	local template = ServerStorage.Vehicles:FindFirstChild("Vehicle_" .. tostring(typeName))
	if not template then
		return nil, "Unbekannter Fahrzeugtyp"
	end
	if player:GetAttribute("Cuffed") or player:GetAttribute("Jailed") then
		return nil, "Nicht moeglich"
	end
	if lastSpawn[player] and os.clock() - lastSpawn[player] < SPAWN_COOLDOWN then
		return nil, "Bitte kurz warten"
	end
	lastSpawn[player] = os.clock()
	slot = slot or "Civil"
	owned[player] = owned[player] or {}
	VehicleService.Despawn(owned[player][slot])
	local m = template:Clone()
	local plate = fixedPlate or newPlate(kind, player)
	if color then
		local base = m.Body:FindFirstChild("LowerBody")
		local baseCol = base and base.Color
		for _, d in ipairs(m.Body:GetChildren()) do
			if d:IsA("BasePart") and baseCol and d.Color == baseCol then
				d.Color = color
			end
		end
	end
	m:SetAttribute("OwnerUserId", player.UserId)
	m:SetAttribute("Plate", plate)
	m:SetAttribute("Kind", kind or "Civilian")
	m:SetAttribute("Siren", false)
	m:SetAttribute("SirenTone", 1)
	m:SetAttribute("Hazard", false)
	m:SetAttribute("Headlights", false)
	local plateText = m:FindFirstChild("PlateText", true)
	if plateText then
		plateText.Text = plate
	end
	m:PivotTo(cf * CFrame.new(0, 2, 0))
	m.Parent = folder
	owned[player][slot] = m
	registry[plate] = { Model = m, Type = typeName, OwnerUserId = player.UserId, OwnerName = rpName(player), Kind = kind or "Civilian", Registered = true, Created = os.time() }
	setupVehicle(m)
	return m
end

function VehicleService.Despawn(model)
	if not model or not model.Parent then
		return
	end
	local seat = model:FindFirstChild("DriverSeat")
	for _, s in ipairs(model:GetChildren()) do
		if (s:IsA("Seat") or s:IsA("VehicleSeat")) and s.Occupant then
			s.Occupant.Sit = false
		end
	end
	local _ = seat
	local plate = model:GetAttribute("Plate")
	if plate and registry[plate] and registry[plate].Model == model then
		registry[plate] = nil
	end
	model:Destroy()
end

function VehicleService.GetOwned(player, slot)
	local t = owned[player]
	local m = t and t[slot or "Civil"]
	return (m and m.Parent) and m or nil
end

function VehicleService.Lookup(plate)
	if typeof(plate) ~= "string" then
		return nil
	end
	local r = registry[plate:upper()]
	if not r or not r.Model.Parent then
		return nil
	end
	return r
end

-- Fahrzeug, in dem ein Spieler sitzt (und ob am Steuer)
function VehicleService.VehicleOf(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local m = seat and seat.Parent
	if m and CollectionService:HasTag(m, "Vehicle") then
		return m, seat:IsA("VehicleSeat")
	end
	return nil
end

function VehicleService.DriverOf(model)
	local seat = model and model:FindFirstChild("DriverSeat")
	return seat and playerFromHumanoid(seat.Occupant)
end

function VehicleService.All()
	return folder:GetChildren()
end

-- Eigene Fahrzeuge (Profil: Vehicles.Owned) --------------------------------------------------------
-- Jeder Charakter erhaelt ein Startfahrzeug; weitere kommen spaeter ueber den Fahrzeughandel.
local STARTER_COLORS = {
	{ 30, 60, 110 }, { 240, 240, 238 }, { 20, 20, 22 }, { 130, 134, 140 }, { 150, 24, 28 }, { 40, 90, 70 }, { 80, 160, 200 },
}
local SPAWN_SEARCH = 140 -- Studs: Parkplatz in dieser Entfernung zum Spieler

local function ownedEntry(player, id)
	local d = S.DataService.Get(player)
	if not d then
		return nil
	end
	for _, v in ipairs(d.Vehicles.Owned) do
		if v.Id == id then
			return v
		end
	end
	return nil
end

local function liveModel(player, entry)
	local m = VehicleService.GetOwned(player, "Civil")
	if m and m:GetAttribute("Plate") == entry.Plate then
		return m
	end
	return nil
end

local function ensureStarter(player)
	local d = S.DataService.Get(player)
	if not d or not d.Character.Created or #d.Vehicles.Owned > 0 then
		return
	end
	local plate = newPlate("Civilian", player)
	local col = STARTER_COLORS[(math.abs(player.UserId) % #STARTER_COLORS) + 1]
	S.DataService.Mutate(player, "StarterVehicle", function(data)
		if #data.Vehicles.Owned == 0 then
			table.insert(data.Vehicles.Owned, { Id = 1, Type = "Sedan", Plate = plate, Color = col, Bought = os.time(), Name = "Sedan" })
		end
	end)
end

function VehicleService.OwnedList(player)
	local d = S.DataService.Get(player)
	if not d then
		return {}
	end
	local out = {}
	for _, v in ipairs(d.Vehicles.Owned) do
		local m = liveModel(player, v)
		local ch = m and m:FindFirstChild("Chassis")
		local spec = ServerStorage.Vehicles:FindFirstChild("Vehicle_" .. v.Type)
		table.insert(out, {
			Id = v.Id, Type = v.Type, Name = v.Name or v.Type, Plate = v.Plate, Color = v.Color, Bought = v.Bought,
			Out = m ~= nil, X = ch and math.floor(ch.Position.X), Z = ch and math.floor(ch.Position.Z),
			MaxSpeed = spec and spec:GetAttribute("MaxSpeed"), Seats = spec and (#spec:GetChildren() > 0) and (function()
				local n = 0
				for _, c in ipairs(spec:GetChildren()) do
					if c:IsA("Seat") or c:IsA("VehicleSeat") then
						n += 1
					end
				end
				return n
			end)() or nil,
		})
	end
	return out
end

-- freier Stellplatz: zivile Spawnflaechen und Parkplatz-Marker (Tag "VehicleParkSpot")
local function freeSpotNear(pos)
	local best, bd
	local candidates = {}
	for _, p in ipairs(CollectionService:GetTagged("VehicleParkSpot")) do
		table.insert(candidates, p)
	end
	for _, p in ipairs(CollectionService:GetTagged("VehicleSpawnPad")) do
		if not p:GetAttribute("RequiredJob") then
			table.insert(candidates, p)
		end
	end
	for _, p in ipairs(candidates) do
		if p:IsDescendantOf(workspace) then
			local d = (p.Position - pos).Magnitude
			if d <= SPAWN_SEARCH and (not bd or d < bd) then
				local free = true
				for _, v in ipairs(folder:GetChildren()) do
					local ch = v:FindFirstChild("Chassis")
					if ch and (ch.Position - p.Position).Magnitude < 12 then
						free = false
						break
					end
				end
				if free then
					best, bd = p, d
				end
			end
		end
	end
	return best, bd
end

function VehicleService.SpawnOwned(player, id)
	local entry = ownedEntry(player, id)
	if not entry then
		return false, "Fahrzeug nicht gefunden"
	end
	if liveModel(player, entry) then
		return false, "Fahrzeug ist bereits ausgeparkt"
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "Nicht moeglich"
	end
	local spot, dist = freeSpotNear(root.Position)
	if not spot then
		return false, "Kein freier Parkplatz in der Naehe (" .. SPAWN_SEARCH .. " Studs)"
	end
	local c = entry.Color
	local m, err = VehicleService.Spawn(player, entry.Type, spot.CFrame, "Civil", "Civilian", entry.Plate, c and Color3.fromRGB(c[1], c[2], c[3]))
	if not m then
		return false, err
	end
	return true, string.format("%s steht bereit (%d m entfernt)", entry.Plate, math.floor(dist * 0.28)), { X = spot.Position.X, Y = spot.Position.Y, Z = spot.Position.Z, Label = entry.Plate }
end

function VehicleService.ParkOwned(player, id)
	local entry = ownedEntry(player, id)
	if not entry then
		return false, "Fahrzeug nicht gefunden"
	end
	local m = liveModel(player, entry)
	if not m then
		return false, "Fahrzeug ist bereits eingeparkt"
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local ch = m:FindFirstChild("Chassis")
	if not root or not ch or (ch.Position - root.Position).Magnitude > 40 then
		return false, "Du musst in der Naehe deines Fahrzeugs sein"
	end
	local driver = VehicleService.DriverOf(m)
	if driver and driver ~= player then
		return false, "Jemand anderes faehrt dein Fahrzeug"
	end
	VehicleService.Despawn(m)
	return true, entry.Plate .. " eingeparkt"
end

-- Spawnpunkte (zivil / Feuerwehr / EMS) -------------------------------------------------------
local function setupPad(pad)
	if setupDone[pad] or not pad:IsDescendantOf(workspace) then
		return
	end
	setupDone[pad] = true
	local holder = (pad.Parent and pad.Parent:FindFirstChild("SignPost")) or pad
	local prompt = holder:FindFirstChild("SpawnPrompt") or Instance.new("ProximityPrompt")
	prompt.Name = "SpawnPrompt"
	prompt.ActionText = "Fahrzeug holen"
	prompt.ObjectText = pad:GetAttribute("VehicleType") or "Fahrzeug"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = holder
	prompt.Triggered:Connect(function(player)
		if not S.DataService.Get(player) then
			return
		end
		local required = pad:GetAttribute("RequiredJob")
		local slot, kind = "Civil", "Civilian"
		if required then
			local faction = Factions.JobGroups[required]
			if not (faction and S.JobService.IsInFaction(player, faction, true)) then
				S.Push(player, "Notify", { Text = "Nur fuer " .. tostring(required) .. " im Dienst", Kind = "error" })
				return
			end
			slot, kind = "Service", faction
		end
		local _, err = VehicleService.Spawn(player, pad:GetAttribute("VehicleType"), pad.CFrame, slot, kind)
		if err then
			S.Push(player, "Notify", { Text = err, Kind = "error" })
		end
	end)
end

-- Fahrzeugsteuerung ------------------------------------------------------------------------------
local function onControl(player, model, action)
	if typeof(model) ~= "Instance" or not CollectionService:HasTag(model, "Vehicle") or typeof(action) ~= "string" then
		return
	end
	if lastControl[player] and os.clock() - lastControl[player] < 0.15 then
		return
	end
	lastControl[player] = os.clock()
	if VehicleService.DriverOf(model) ~= player then
		return -- nur der Fahrer
	end
	local emergency = model:GetAttribute("Emergency")
	if action == "Lights" and emergency then
		model:SetAttribute("LightsOn", not model:GetAttribute("LightsOn"))
	elseif action == "Siren" and emergency then
		local on = not model:GetAttribute("Siren")
		model:SetAttribute("Siren", on)
		if on then
			model:SetAttribute("LightsOn", true)
		end
	elseif action == "SirenTone" and emergency then
		model:SetAttribute("SirenTone", (model:GetAttribute("SirenTone") or 1) % #PoliceCfg.SirenTones + 1)
	elseif action == "Horn" and emergency then
		model:SetAttribute("HornAt", os.clock())
	elseif action == "Hazard" then
		model:SetAttribute("Hazard", not model:GetAttribute("Hazard"))
	elseif action == "Headlights" then
		model:SetAttribute("Headlights", not model:GetAttribute("Headlights"))
	end
end

function VehicleService.Start()
	folder = workspace:FindFirstChild("Vehicles") or Instance.new("Folder")
	folder.Name = "Vehicles"
	folder.Parent = workspace
	S.Remotes.VehicleControl.OnServerEvent:Connect(onControl)
	CollectionService:GetInstanceAddedSignal("Vehicle"):Connect(setupVehicle)
	for _, m in ipairs(CollectionService:GetTagged("Vehicle")) do
		setupVehicle(m)
	end
	CollectionService:GetInstanceAddedSignal("VehicleSpawnPad"):Connect(setupPad)
	for _, p in ipairs(CollectionService:GetTagged("VehicleSpawnPad")) do
		setupPad(p)
	end
	S.DataService.ProfileLoaded:Connect(ensureStarter)
	S.DataService.Changed:Connect(function(player, _, reason)
		if reason == "CharacterCreate" and typeof(player) == "Instance" then
			ensureStarter(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, m in pairs(owned[player] or {}) do
			VehicleService.Despawn(m)
		end
		owned[player], lastSpawn[player], lastControl[player] = nil, nil, nil
	end)
	task.spawn(function()
		while true do
			task.wait(5)
			for _, m in ipairs(folder:GetChildren()) do
				local ch = m:FindFirstChild("Chassis")
				if not ch or ch.Position.Y < -60 then
					VehicleService.Despawn(m)
				end
			end
		end
	end)
end

return VehicleService
