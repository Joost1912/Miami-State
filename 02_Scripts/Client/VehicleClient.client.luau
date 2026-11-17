-- VehicleClient (StarterPlayerScripts)
-- Steuert das Fahrzeug, in dem der lokale Spieler am Steuer sitzt. Der Fahrer besitzt die Physik
-- (Netzwerkeigentum vom Server), daher wirken Motor-/Lenkwerte sofort und ohne Latenz.
-- Steuerung: W/S Gas/Bremse/Rueckwaerts, A/D Lenken, Leertaste Aussteigen, Q Sondersignal.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local STUDS_TO_KMH = 0.28 * 3.6 -- 1 Stud ~ 0.28 m

local current = nil
local hud

local function makeHud()
	local gui = Instance.new("ScreenGui")
	gui.Name = "VehicleHUD"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.new(1, -24, 1, -24)
	frame.Size = UDim2.fromOffset(220, 86)
	frame.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
	frame.BackgroundTransparency = 0.25
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
	local speed = Instance.new("TextLabel")
	speed.Name = "Speed"
	speed.BackgroundTransparency = 1
	speed.Position = UDim2.fromOffset(14, 6)
	speed.Size = UDim2.new(1, -28, 0, 44)
	speed.Font = Enum.Font.GothamBlack
	speed.TextScaled = true
	speed.TextXAlignment = Enum.TextXAlignment.Left
	speed.TextColor3 = Color3.fromRGB(80, 230, 255)
	speed.Text = "0 km/h"
	speed.Parent = frame
	local help = Instance.new("TextLabel")
	help.Name = "Help"
	help.BackgroundTransparency = 1
	help.Position = UDim2.fromOffset(14, 52)
	help.Size = UDim2.new(1, -28, 0, 26)
	help.Font = Enum.Font.Gotham
	help.TextScaled = true
	help.TextXAlignment = Enum.TextXAlignment.Left
	help.TextColor3 = Color3.fromRGB(220, 220, 228)
	help.Text = "W/S Gas  A/D Lenken  Leertaste Aussteigen"
	help.Parent = frame
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

local function vehicleOf(seat)
	local m = seat.Parent
	if m and CollectionService:HasTag(m, "Vehicle") then
		return m
	end
	return nil
end

local function bind(seat)
	local model = vehicleOf(seat)
	if not model then
		return
	end
	local motors, steers = {}, {}
	for _, c in ipairs(model:GetDescendants()) do
		if c:IsA("HingeConstraint") then
			if c.Name == "DriveMotor" then
				table.insert(motors, c)
			elseif c.Name == "SteerServo" then
				table.insert(steers, c)
			end
		end
	end
	current = {
		model = model,
		seat = seat,
		chassis = model:FindFirstChild("Chassis"),
		motors = motors,
		steers = steers,
		maxSpeed = model:GetAttribute("MaxSpeed") or 90,
		torque = model:GetAttribute("Torque") or 2000,
		brake = model:GetAttribute("BrakeTorque") or 5000,
		maxSteer = model:GetAttribute("MaxSteer") or 30,
		radius = model:GetAttribute("WheelRadius") or 1.6,
		sign = model:GetAttribute("DriveSign") or -1,
	}
	hud = hud or makeHud()
	-- Prompt 10: Anzeige uebernimmt das Premium-HUD (MiamiHUD); diese ScreenGui bleibt nur fuer Kompatibilitaet (Handy-Einstellungen)
	hud.Enabled = false
	hud.Frame.Help.Text = model:GetAttribute("Emergency") and "Q Blaulicht  R Sirene  T Ton  Y Horn  H Warnbl.  L Licht" or "W/S Gas  A/D Lenken  H Warnblinker  L Licht"
end

local function unbind()
	current = nil
	if hud then
		hud.Enabled = false
	end
end

local function onCharacter(char)
	local hum = char:WaitForChild("Humanoid")
	hum.Seated:Connect(function(active, seatPart)
		if active and seatPart and seatPart:IsA("VehicleSeat") then
			bind(seatPart)
		else
			unbind()
		end
	end)
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end

RunService.Heartbeat:Connect(function()
	local c = current
	if not c or not c.chassis or not c.chassis.Parent then
		return
	end
	local throttle, steer = c.seat.ThrottleFloat, c.seat.SteerFloat
	-- Prompt 10: leerer Tank -> kein Antrieb mehr (Bremsen und Lenken bleiben)
	local fuel = c.model:GetAttribute("Fuel")
	if fuel and fuel <= 0 and throttle ~= 0 then
		local sp = c.chassis.AssemblyLinearVelocity:Dot(c.chassis.CFrame.LookVector)
		if (throttle > 0 and sp > -2) or (throttle < 0 and sp < 2) then
			throttle = 0
		end
	end
	local speed = c.chassis.AssemblyLinearVelocity:Dot(c.chassis.CFrame.LookVector)

	-- Lenkung: bei hoher Geschwindigkeit weniger Einschlag
	local steerFactor = 1 - math.clamp(math.abs(speed) / c.maxSpeed, 0, 1) * 0.65
	for _, s in ipairs(c.steers) do
		-- positiver Servowinkel = Rad nach links (Drehung um +Y); D (steer +1) muss nach rechts lenken
		s.TargetAngle = -steer * c.maxSteer * steerFactor
	end

	-- Antrieb / Bremse
	local target, torque
	if throttle > 0 then
		if speed < -2 then
			target, torque = 0, c.brake
		else
			target, torque = c.maxSpeed, c.torque
		end
	elseif throttle < 0 then
		if speed > 2 then
			target, torque = 0, c.brake
		else
			target, torque = -c.maxSpeed * 0.3, c.torque * 0.7
		end
	else
		target, torque = 0, c.torque * 0.06 -- Ausrollen
	end
	local av = target / c.radius * c.sign
	for _, m in ipairs(c.motors) do
		m.AngularVelocity = av
		m.MotorMaxTorque = torque
	end
	if hud then
		hud.Frame.Speed.Text = string.format("%d km/h", math.floor(math.abs(speed) * STUDS_TO_KMH + 0.5))
	end
end)

-- Fahrzeugfunktionen (Server prueft: nur Fahrer, Sondersignale nur Einsatzfahrzeuge)
local CONTROL_KEYS = {
	[Enum.KeyCode.Q] = "Lights", [Enum.KeyCode.R] = "Siren", [Enum.KeyCode.T] = "SirenTone",
	[Enum.KeyCode.Y] = "Horn", [Enum.KeyCode.H] = "Hazard", [Enum.KeyCode.L] = "Headlights",
}
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not current then
		return
	end
	local action = CONTROL_KEYS[input.KeyCode]
	if action then
		local remotes = ReplicatedStorage:FindFirstChild("MiamiRemotes")
		local ev = remotes and remotes:FindFirstChild("VehicleControl")
		if ev then
			ev:FireServer(current.model, action)
		end
	end
end)
