-- VehicleKit: baut fahrbare Fahrzeugvorlagen aus Parts + Constraints (eigene Modelle, keine fremden Assets).
-- Aufbau je Rad:  Chassis --Prismatic+Spring--> Susp --(vorne: Servo-Lenkung)--> Steer --Motor--> Wheel
-- Koordinaten: Boden Y 0, Fahrtrichtung -Z, rechts +X. Masse sitzt im Chassis (Karosserie ist "Massless").
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")

local VK = {}
local M = Enum.Material
local CYL = Enum.PartType.Cylinder

VK.SPECS = {
	Sedan = { kind = "sedan", L = 17.5, W = 6.8, H = 5.2, r = 1.55, ww = 1.3, wb = 10.6, track = 6.0, clear = 1.0,
		color = Color3.fromRGB(30, 60, 110), maxSpeed = 95, torque = 1900, steer = 32, k = 12000, damp = 700, density = 1.8 },
	SUV = { kind = "suv", L = 18, W = 7.2, H = 6.6, r = 1.8, ww = 1.4, wb = 10.8, track = 6.3, clear = 1.4,
		color = Color3.fromRGB(28, 28, 32), maxSpeed = 88, torque = 2300, steer = 30, k = 14000, damp = 800, density = 2.0 },
	Pickup = { kind = "pickup", L = 20, W = 7.3, H = 6.6, r = 1.85, ww = 1.45, wb = 12.6, track = 6.4, clear = 1.5,
		color = Color3.fromRGB(150, 24, 28), maxSpeed = 85, torque = 2400, steer = 30, k = 14500, damp = 820, density = 2.0 },
	Sports = { kind = "sports", L = 16.5, W = 7.0, H = 4.3, r = 1.55, ww = 1.6, wb = 9.8, track = 6.2, clear = 0.7,
		color = Color3.fromRGB(255, 170, 20), maxSpeed = 140, torque = 2600, steer = 28, k = 16000, damp = 900, density = 1.8 },
	PoliceSedan = { kind = "sedan", L = 17.5, W = 6.8, H = 5.2, r = 1.6, ww = 1.35, wb = 10.6, track = 6.0, clear = 1.0,
		color = Color3.fromRGB(245, 245, 245), maxSpeed = 115, torque = 2400, steer = 32, k = 13000, damp = 750, density = 1.9,
		emergency = "Police", livery = "POLICE", pushbar = true, blackHood = true },
	PoliceSUV = { kind = "suv", L = 18.5, W = 7.4, H = 6.8, r = 1.85, ww = 1.45, wb = 11.2, track = 6.4, clear = 1.4,
		color = Color3.fromRGB(20, 20, 24), maxSpeed = 105, torque = 2800, steer = 30, k = 15500, damp = 860, density = 2.1,
		emergency = "Police", livery = "POLICE", pushbar = true, whiteDoors = true },
	PoliceInterceptor = { kind = "sports", L = 17, W = 7.0, H = 4.6, r = 1.6, ww = 1.6, wb = 10.2, track = 6.2, clear = 0.8,
		color = Color3.fromRGB(18, 18, 22), maxSpeed = 140, torque = 2900, steer = 28, k = 16500, damp = 920, density = 1.9,
		emergency = "Police", livery = "POLICE", pushbar = true },
	HighwayPatrol = { kind = "sedan", L = 17.8, W = 6.9, H = 5.2, r = 1.6, ww = 1.4, wb = 10.8, track = 6.0, clear = 1.0,
		color = Color3.fromRGB(236, 238, 242), maxSpeed = 128, torque = 2700, steer = 30, k = 13500, damp = 780, density = 1.9,
		emergency = "Police", livery = "HIGHWAY PATROL", stripe = Color3.fromRGB(30, 80, 190) },
	PoliceUnmarked = { kind = "sedan", L = 17.5, W = 6.8, H = 5.2, r = 1.6, ww = 1.35, wb = 10.6, track = 6.0, clear = 1.0,
		color = Color3.fromRGB(58, 62, 68), maxSpeed = 125, torque = 2600, steer = 32, k = 13000, damp = 750, density = 1.9,
		emergency = "Police", hiddenLights = true },
	Ambulance = { kind = "van", L = 22, W = 7.8, H = 9.6, r = 1.9, ww = 1.5, wb = 13, track = 6.6, clear = 1.4,
		color = Color3.fromRGB(250, 250, 248), maxSpeed = 88, torque = 3200, steer = 30, k = 20000, damp = 1100, density = 2.4,
		emergency = "EMS", livery = "AMBULANCE", stripeColor = Color3.fromRGB(210, 30, 36) },
	AmbulanceHeavy = { kind = "van", L = 25.5, W = 8.2, H = 10.6, r = 2.0, ww = 1.6, wb = 15, track = 6.9, clear = 1.5,
		color = Color3.fromRGB(250, 250, 248), maxSpeed = 82, torque = 3900, steer = 29, k = 24000, damp = 1300, density = 2.5,
		emergency = "EMS", livery = "MEDIC  RESCUE", stripeColor = Color3.fromRGB(230, 120, 20), cabColor = Color3.fromRGB(210, 30, 36) },
	EMSResponder = { kind = "suv", L = 18.5, W = 7.4, H = 6.8, r = 1.85, ww = 1.45, wb = 11.2, track = 6.4, clear = 1.4,
		color = Color3.fromRGB(246, 246, 244), maxSpeed = 108, torque = 2800, steer = 30, k = 15500, damp = 860, density = 2.1,
		emergency = "EMS", livery = "EMS SUPERVISOR", stripe = Color3.fromRGB(210, 30, 36) },
	-- Feuerwehr (truck: Fahrerhaus mit Mannschaftsraum + Aufbau; Varianten Pumpe / Drehleiter / Ruestwagen)
	FireEngine = { kind = "truck", L = 30, W = 8.6, H = 10.5, r = 2.3, ww = 1.9, wb = 16.5, track = 7.2, clear = 1.6,
		color = Color3.fromRGB(190, 20, 24), maxSpeed = 76, torque = 6200, steer = 31, k = 34000, damp = 1900, density = 2.8,
		emergency = "Fire", livery = "MSFD  ENGINE", pumper = true },
	LadderTruck = { kind = "truck", L = 36, W = 8.6, H = 11, r = 2.3, ww = 1.9, wb = 20.5, track = 7.2, clear = 1.6,
		color = Color3.fromRGB(190, 20, 24), maxSpeed = 68, torque = 7000, steer = 29, k = 38000, damp = 2100, density = 2.8,
		emergency = "Fire", livery = "MSFD  LADDER", ladder = true },
	FireRescue = { kind = "truck", L = 27, W = 8.4, H = 10, r = 2.2, ww = 1.8, wb = 15, track = 7.0, clear = 1.6,
		color = Color3.fromRGB(190, 20, 24), maxSpeed = 80, torque = 5600, steer = 31, k = 30000, damp = 1700, density = 2.7,
		emergency = "Fire", livery = "MSFD  RESCUE", rescueBox = true },
	FireCommand = { kind = "suv", L = 18.5, W = 7.4, H = 6.8, r = 1.85, ww = 1.45, wb = 11.2, track = 6.4, clear = 1.4,
		color = Color3.fromRGB(190, 20, 24), maxSpeed = 105, torque = 2800, steer = 30, k = 15500, damp = 860, density = 2.1,
		emergency = "Fire", livery = "FIRE COMMAND", whiteDoors = true },
}

function VK.setupCollisionGroups()
	for _, g in ipairs({ "VehicleBody", "VehicleWheel" }) do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(g)
		end)
	end
	PhysicsService:CollisionGroupSetCollidable("VehicleBody", "VehicleWheel", false)
	PhysicsService:CollisionGroupSetCollidable("VehicleWheel", "VehicleWheel", false)
end

local function mk(class, parent, name, size, cf, color, material, o)
	local p = Instance.new(class)
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	if o then
		if o.shape then
			p.Shape = o.shape
		end
		if o.transp then
			p.Transparency = o.transp
		end
		if o.refl then
			p.Reflectance = o.refl
		end
	end
	p.Parent = parent
	return p
end

local function att(parent, name, cf)
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = cf
	a.Parent = parent
	return a
end
-- Attachment, dessen Achse (X) nach oben zeigt
local function upAxis(pos)
	return CFrame.fromMatrix(pos, Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0))
end

local function textPanel(part, face, text, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.PixelsPerStud = 12
	gui.LightInfluence = 0.6
	gui.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = color
	t.Parent = gui
	return t
end

-- Karosserie ---------------------------------------------------------------------------
local function buildBody(body, s)
	local L, W, H, cl = s.L, s.W, s.H, s.clear
	local paint, dark, chrome = s.color, Color3.fromRGB(26, 26, 28), Color3.fromRGB(200, 204, 210)
	local glass = Color3.fromRGB(28, 38, 46)
	local function B(name, size, pos, color, mat, o)
		return mk("Part", body, name, size, CFrame.new(pos), color, mat, o)
	end
	local function Wg(name, size, cf, color, mat, o)
		return mk("WedgePart", body, name, size, cf, color, mat, o)
	end
	local lowH = ({ sedan = 2.4, suv = 3.0, pickup = 3.0, sports = 1.9, van = 3.2, truck = 3.8 })[s.kind]
	local yLow = cl + lowH / 2
	local topLow = cl + lowH
	local paintO = { refl = 0.12 }

	-- Unterteil, Stossfaenger, Kuehlergrill, Lichter
	B("LowerBody", Vector3.new(W, lowH, L - 1.2), Vector3.new(0, yLow, 0), paint, M.SmoothPlastic, paintO)
	B("BumperF", Vector3.new(W - 0.2, 1.1, 0.8), Vector3.new(0, cl + 0.55, -L / 2 + 0.4), dark, M.SmoothPlastic)
	B("BumperR", Vector3.new(W - 0.2, 1.1, 0.8), Vector3.new(0, cl + 0.55, L / 2 - 0.4), dark, M.SmoothPlastic)
	B("Grille", Vector3.new(W * 0.45, lowH * 0.45, 0.2), Vector3.new(0, cl + lowH * 0.55, -L / 2 + 0.55), dark, M.DiamondPlate)
	for _, sx in ipairs({ -1, 1 }) do
		local hl = B("Headlight", Vector3.new(W * 0.2, 0.6, 0.2), Vector3.new(sx * W * 0.34, cl + lowH * 0.7, -L / 2 + 0.55), Color3.fromRGB(255, 252, 235), M.Neon)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Range = 60
		spot.Angle = 55
		spot.Brightness = 2.5
		spot.Shadows = false
		spot.Parent = hl
		B("Taillight", Vector3.new(W * 0.22, 0.6, 0.2), Vector3.new(sx * W * 0.34, cl + lowH * 0.72, L / 2 - 0.55), Color3.fromRGB(220, 20, 30), M.Neon)
		B("Mirror", Vector3.new(0.6, 0.5, 0.9), Vector3.new(sx * (W / 2 + 0.3), topLow + 0.6, -L * 0.12), dark, M.SmoothPlastic)
		B("DoorLine", Vector3.new(0.05, lowH * 0.8, 0.12), Vector3.new(sx * (W / 2 + 0.01), yLow + 0.1, -L * 0.03), dark, M.SmoothPlastic)
		B("Handle", Vector3.new(0.1, 0.2, 0.7), Vector3.new(sx * (W / 2 + 0.05), topLow - 0.5, -L * 0.1), chrome, M.Metal)
	end
	local plate = B("Plate", Vector3.new(2.2, 0.9, 0.1), Vector3.new(0, cl + 0.9, L / 2 + 0.02), Color3.fromRGB(245, 245, 240))
	textPanel(plate, Enum.NormalId.Back, "MIAMI STATE", Color3.fromRGB(30, 60, 140)).Name = "PlateText"
	-- Blinker (Warnblinkanlage), aus = halbtransparent
	for _, sx in ipairs({ -1, 1 }) do
		B("Indicator", Vector3.new(0.6, 0.45, 0.25), Vector3.new(sx * (W / 2 - 0.35), cl + lowH * 0.7, -L / 2 + 0.6), Color3.fromRGB(255, 150, 20), M.Neon, { transp = 0.75 })
		B("Indicator", Vector3.new(0.6, 0.45, 0.25), Vector3.new(sx * (W / 2 - 0.35), cl + lowH * 0.45, L / 2 - 0.6), Color3.fromRGB(255, 150, 20), M.Neon, { transp = 0.75 })
	end

	-- Innenraum (Fahrer links)
	local cabZ = ({ sedan = 0.6, suv = 1.2, pickup = -1.6, sports = 0.8, van = -L / 2 + 4.5, truck = -L / 2 + 4.5 })[s.kind]
	local seatY = topLow - 0.7
	B("Dashboard", Vector3.new(W - 1.2, 1.0, 1.2), Vector3.new(0, topLow + 0.4, cabZ - 2.6), dark, M.Fabric)
	mk("Part", body, "SteeringWheel", Vector3.new(0.25, 1.4, 1.4), CFrame.new(-W * 0.22, topLow + 0.9, cabZ - 1.9) * CFrame.Angles(0, math.rad(90), math.rad(-25)) * CFrame.Angles(0, 0, 0), dark, M.SmoothPlastic, { shape = CYL })
	B("BackrestDriver", Vector3.new(2, 2.4, 0.4), Vector3.new(-W * 0.22, seatY + 1.6, cabZ + 0.4), Color3.fromRGB(40, 40, 44), M.Fabric)
	B("BackrestPassenger", Vector3.new(2, 2.4, 0.4), Vector3.new(W * 0.22, seatY + 1.6, cabZ + 0.4), Color3.fromRGB(40, 40, 44), M.Fabric)

	-- Aufbau je Typ
	local roofY
	if s.kind == "sedan" or s.kind == "suv" or s.kind == "sports" then
		local cabH = ({ sedan = 2.3, suv = 3.0, sports = 1.9 })[s.kind]
		local cabL = ({ sedan = 7.0, suv = 10.0, sports = 5.6 })[s.kind]
		local cz = ({ sedan = 1.0, suv = 2.4, sports = 1.4 })[s.kind]
		local hoodL = L / 2 + cz - cabL / 2 - 2.6
		B("Hood", Vector3.new(W - 0.3, 0.4, hoodL), Vector3.new(0, topLow + 0.2, -L / 2 + 0.6 + hoodL / 2), paint, M.SmoothPlastic, paintO)
		mk("Part", body, "Cabin", Vector3.new(W - 0.8, cabH, cabL), CFrame.new(0, topLow + cabH / 2, cz), glass, M.Glass, { transp = 0.25, refl = 0.3 })
		Wg("Windshield", Vector3.new(W - 0.8, cabH, 2.6), CFrame.new(0, topLow + cabH / 2, cz - cabL / 2 - 1.3), glass, M.Glass, { transp = 0.25, refl = 0.3 })
		if s.kind ~= "suv" then
			Wg("RearWindow", Vector3.new(W - 0.8, cabH, 2.2), CFrame.new(0, topLow + cabH / 2, cz + cabL / 2 + 1.1) * CFrame.Angles(0, math.pi, 0), glass, M.Glass, { transp = 0.25, refl = 0.3 })
			local trunkL = L / 2 - cz - cabL / 2 - 2.2 - 0.6
			if trunkL > 0.5 then
				B("Trunk", Vector3.new(W - 0.3, 0.4, trunkL), Vector3.new(0, topLow + 0.2, L / 2 - 0.6 - trunkL / 2), paint, M.SmoothPlastic, paintO)
			end
		end
		roofY = topLow + cabH
		B("Roof", Vector3.new(W - 0.9, 0.35, cabL - 0.6), Vector3.new(0, roofY + 0.17, cz), paint, M.SmoothPlastic, paintO)
		for _, sx in ipairs({ -1, 1 }) do
			B("Pillar", Vector3.new(0.3, cabH, 0.5), Vector3.new(sx * (W / 2 - 0.45), topLow + cabH / 2, cz), paint, M.SmoothPlastic)
		end
		if s.kind == "suv" then
			for _, sx in ipairs({ -1, 1 }) do
				B("RoofRail", Vector3.new(0.3, 0.3, cabL - 1.5), Vector3.new(sx * (W / 2 - 1), roofY + 0.5, cz), chrome, M.Metal)
			end
		end
		if s.kind == "sports" then
			B("Spoiler", Vector3.new(W - 0.6, 0.25, 1.4), Vector3.new(0, topLow + 1.2, L / 2 - 1.0), dark, M.SmoothPlastic)
			for _, sx in ipairs({ -1, 1 }) do
				B("SpoilerPost", Vector3.new(0.3, 0.9, 0.5), Vector3.new(sx * (W / 2 - 1.2), topLow + 0.6, L / 2 - 1.0), dark, M.SmoothPlastic)
				B("SideIntake", Vector3.new(0.1, 0.9, 2.2), Vector3.new(sx * (W / 2 + 0.02), yLow + 0.2, L * 0.12), dark, M.SmoothPlastic)
			end
		end
		roofY += 0.35
		-- Ruecksitzbank
		B("RearBench", Vector3.new(W - 2, 2.2, 0.4), Vector3.new(0, seatY + 1.5, cz + cabL / 2 - 0.6), Color3.fromRGB(40, 40, 44), M.Fabric)
	elseif s.kind == "pickup" then
		local cabH, cabL, cz = 3.0, 6.2, -1.6
		local hoodL = L / 2 + cz - cabL / 2 - 2.4
		B("Hood", Vector3.new(W - 0.3, 0.5, hoodL), Vector3.new(0, topLow + 0.25, -L / 2 + 0.6 + hoodL / 2), paint, M.SmoothPlastic, paintO)
		mk("Part", body, "Cabin", Vector3.new(W - 0.6, cabH, cabL), CFrame.new(0, topLow + cabH / 2, cz), glass, M.Glass, { transp = 0.25, refl = 0.3 })
		Wg("Windshield", Vector3.new(W - 0.6, cabH, 2.4), CFrame.new(0, topLow + cabH / 2, cz - cabL / 2 - 1.2), glass, M.Glass, { transp = 0.25, refl = 0.3 })
		roofY = topLow + cabH
		B("Roof", Vector3.new(W - 0.6, 0.4, cabL), Vector3.new(0, roofY + 0.2, cz), paint, M.SmoothPlastic, paintO)
		B("CabBack", Vector3.new(W - 0.6, cabH, 0.3), Vector3.new(0, topLow + cabH / 2, cz + cabL / 2), paint, M.SmoothPlastic, paintO)
		local bedZ0, bedZ1 = cz + cabL / 2 + 0.6, L / 2 - 0.6
		local bedL = bedZ1 - bedZ0
		B("BedFloor", Vector3.new(W - 0.8, 0.3, bedL), Vector3.new(0, topLow - 0.6, (bedZ0 + bedZ1) / 2), Color3.fromRGB(40, 40, 42), M.DiamondPlate)
		for _, sx in ipairs({ -1, 1 }) do
			B("BedSide", Vector3.new(0.4, 1.6, bedL), Vector3.new(sx * (W / 2 - 0.2), topLow + 0.8, (bedZ0 + bedZ1) / 2), paint, M.SmoothPlastic, paintO)
		end
		B("Tailgate", Vector3.new(W - 0.4, 1.6, 0.4), Vector3.new(0, topLow + 0.8, bedZ1), paint, M.SmoothPlastic, paintO)
		roofY += 0.4
	elseif s.kind == "van" then
		-- Rettungswagen: Fahrerhaus + Kofferaufbau mit Warnstreifen, Star of Life und Heckbeleuchtung
		local cabL = 6.5
		local cz = -L / 2 + 0.6 + 2.2 + cabL / 2
		local cabCol = s.cabColor or paint
		local stripe = s.stripeColor or Color3.fromRGB(210, 30, 36)
		B("Hood", Vector3.new(W - 0.3, 0.6, 2.2), Vector3.new(0, topLow + 0.3, -L / 2 + 1.7), cabCol, M.SmoothPlastic, paintO)
		mk("Part", body, "Cabin", Vector3.new(W - 0.5, 3.4, cabL), CFrame.new(0, topLow + 1.7, cz), glass, M.Glass, { transp = 0.25, refl = 0.3 })
		B("CabRoof", Vector3.new(W - 0.4, 0.5, cabL), Vector3.new(0, topLow + 3.65, cz), cabCol, M.SmoothPlastic, paintO)
		local boxZ0 = cz + cabL / 2
		local boxL = L / 2 - 0.4 - boxZ0
		local boxH = H - topLow
		local box = B("Box", Vector3.new(W, boxH, boxL), Vector3.new(0, topLow + boxH / 2, boxZ0 + boxL / 2), paint, M.SmoothPlastic, paintO)
		for _, sx in ipairs({ -1, 1 }) do
			B("Stripe", Vector3.new(0.1, 0.9, boxL), Vector3.new(sx * (W / 2 + 0.02), topLow + 1.2, boxZ0 + boxL / 2), stripe, M.SmoothPlastic)
			B("StripeTop", Vector3.new(0.1, 0.35, boxL), Vector3.new(sx * (W / 2 + 0.02), topLow + boxH - 0.8, boxZ0 + boxL / 2), stripe, M.SmoothPlastic)
			B("SideDoor", Vector3.new(0.08, boxH - 2.4, 3.2), Vector3.new(sx * (W / 2 + 0.03), topLow + boxH / 2 + 0.3, boxZ0 + 2.4), Color3.fromRGB(232, 232, 230), M.SmoothPlastic)
			B("SceneLight", Vector3.new(0.12, 0.5, 1.6), Vector3.new(sx * (W / 2 + 0.05), topLow + boxH - 1.6, boxZ0 + boxL * 0.7), Color3.fromRGB(255, 250, 235), M.Neon)
			B("WarnLightRear", Vector3.new(0.6, 0.6, 0.15), Vector3.new(sx * (W / 2 - 0.6), topLow + boxH - 0.6, L / 2 - 0.3), Color3.fromRGB(255, 40, 40), M.Neon, { transp = 0.4 })
		end
		-- Star of Life auf dem Dach und am Heck
		local sol = Color3.fromRGB(40, 110, 230)
		B("StarOfLife", Vector3.new(2.6, 0.12, 0.7), Vector3.new(0, H + 0.06, boxZ0 + boxL / 2), sol, M.SmoothPlastic)
		B("StarOfLife", Vector3.new(0.7, 0.12, 2.6), Vector3.new(0, H + 0.06, boxZ0 + boxL / 2), sol, M.SmoothPlastic)
		textPanel(box, Enum.NormalId.Left, s.livery, stripe)
		textPanel(box, Enum.NormalId.Right, s.livery, stripe)
		local rear = B("RearDoors", Vector3.new(W - 1, boxH - 1.2, 0.2), Vector3.new(0, topLow + boxH / 2, L / 2 - 0.3), Color3.fromRGB(235, 235, 232), M.SmoothPlastic)
		textPanel(rear, Enum.NormalId.Back, "EMS", stripe)
		-- Trage im Innenraum (sichtbar durch die Heckscheibe)
		B("StretcherFrame", Vector3.new(2.2, 0.3, 6.5), Vector3.new(W * 0.18, topLow + 1.2, boxZ0 + boxL / 2), Color3.fromRGB(200, 204, 210), M.Metal)
		roofY = H
	else -- truck (Feuerwehr): Mannschaftskabine + Aufbau
		local cabL = 9
		local cz = -L / 2 + 0.6 + cabL / 2
		local cabH = 5.6
		mk("Part", body, "Cabin", Vector3.new(W - 0.3, cabH, cabL), CFrame.new(0, topLow + cabH / 2, cz), paint, M.SmoothPlastic, paintO)
		B("CabRoofWhite", Vector3.new(W - 0.2, 0.3, cabL), Vector3.new(0, topLow + cabH + 0.15, cz), Color3.fromRGB(240, 240, 238), M.SmoothPlastic)
		B("Windshield", Vector3.new(W - 0.8, 2.4, 0.2), Vector3.new(0, topLow + 3.3, cz - cabL / 2 - 0.05), glass, M.Glass, { transp = 0.2, refl = 0.3 })
		B("FrontBumperChrome", Vector3.new(W, 1.2, 0.5), Vector3.new(0, cl + 0.6, -L / 2 - 0.1), chrome, M.Metal)
		for _, sx in ipairs({ -1, 1 }) do
			B("SideWindow", Vector3.new(0.2, 2.2, 3), Vector3.new(sx * (W / 2 - 0.1), topLow + 3.3, cz - 2.2), glass, M.Glass, { transp = 0.2 })
			B("CrewWindow", Vector3.new(0.2, 2.0, 2.4), Vector3.new(sx * (W / 2 - 0.1), topLow + 3.4, cz + 2.4), glass, M.Glass, { transp = 0.2 })
			B("ReflectStripe", Vector3.new(0.08, 0.5, L - 2), Vector3.new(sx * (W / 2 + 0.03), cl + lowH * 0.35, 0), Color3.fromRGB(240, 240, 238), M.SmoothPlastic)
			B("Step", Vector3.new(0.8, 0.25, 2.4), Vector3.new(sx * (W / 2 + 0.3), cl + 0.4, cz), chrome, M.DiamondPlate)
		end
		textPanel(mk("Part", body, "LiveryPanel", Vector3.new(0.1, 1.4, cabL - 1), CFrame.new(-W / 2 - 0.02, topLow + 1.0, cz), paint, M.SmoothPlastic), Enum.NormalId.Left, s.livery, Color3.fromRGB(255, 220, 90))
		textPanel(mk("Part", body, "LiveryPanel", Vector3.new(0.1, 1.4, cabL - 1), CFrame.new(W / 2 + 0.02, topLow + 1.0, cz), paint, M.SmoothPlastic), Enum.NormalId.Right, s.livery, Color3.fromRGB(255, 220, 90))
		local boxZ0 = cz + cabL / 2 + 0.4
		local boxL = L / 2 - 0.5 - boxZ0
		local boxH = s.rescueBox and 6.4 or 5.2
		B("Body", Vector3.new(W, boxH, boxL), Vector3.new(0, topLow + boxH / 2, boxZ0 + boxL / 2), paint, M.SmoothPlastic, paintO)
		local nComp = s.rescueBox and 5 or 4
		for i = 0, nComp - 1 do
			for _, sx in ipairs({ -1, 1 }) do
				B("Compartment", Vector3.new(0.12, boxH - 1.2, boxL / nComp - 0.6), Vector3.new(sx * (W / 2 + 0.03), topLow + boxH / 2, boxZ0 + boxL / (2 * nComp) + i * boxL / nComp), chrome, M.DiamondPlate)
			end
		end
		if s.pumper then
			-- Pumpenstand, Schlauchhaspel und Querschlaeuche
			for _, sx in ipairs({ -1, 1 }) do
				B("PumpPanel", Vector3.new(0.15, 3.2, 2.6), Vector3.new(sx * (W / 2 + 0.06), topLow + 2.4, boxZ0 + 1.6), chrome, M.Metal)
				B("Gauge", Vector3.new(0.12, 0.6, 0.6), Vector3.new(sx * (W / 2 + 0.12), topLow + 3.3, boxZ0 + 1.2), Color3.fromRGB(245, 245, 240), M.SmoothPlastic)
			end
			B("HoseBed", Vector3.new(W - 1.6, 0.9, boxL - 4), Vector3.new(0, topLow + boxH + 0.45, boxZ0 + boxL / 2 + 1.5), Color3.fromRGB(210, 190, 140), M.Fabric)
			B("Crosslay", Vector3.new(W - 0.4, 0.8, 1.6), Vector3.new(0, topLow + boxH + 0.4, boxZ0 + 0.8), Color3.fromRGB(230, 60, 40), M.Fabric)
			mk("Part", body, "HoseReel", Vector3.new(1.4, 2.6, 2.6), CFrame.new(0, topLow + boxH + 1.3, boxZ0 + 0.8) * CFrame.Angles(0, 0, 0), chrome, M.Metal, { shape = CYL })
			B("SuctionHose", Vector3.new(0.9, 0.9, boxL - 2), Vector3.new(W / 2 - 0.4, topLow + boxH + 0.2, boxZ0 + boxL / 2), Color3.fromRGB(30, 30, 32), M.Rubber)
		end
		if s.ladder then
			-- Drehleiter (eingefahren) mit Leiterpark
			local ly = topLow + boxH + 0.9
			for _, sx in ipairs({ -1, 1 }) do
				B("LadderRail", Vector3.new(0.4, 0.6, boxL + 6), Vector3.new(sx * 1.6, ly, boxZ0 + boxL / 2 - 3), chrome, M.Metal)
				B("LadderRail2", Vector3.new(0.3, 0.4, boxL + 4), Vector3.new(sx * 1.2, ly + 0.55, boxZ0 + boxL / 2 - 2), chrome, M.Metal)
			end
			for i = 0, 9 do
				B("LadderRung", Vector3.new(3.2, 0.25, 0.25), Vector3.new(0, ly, boxZ0 - 2 + i * ((boxL + 4) / 10)), chrome, M.Metal)
			end
			B("Turntable", Vector3.new(4.4, 0.9, 4.4), Vector3.new(0, topLow + boxH + 0.45, L / 2 - 4), Color3.fromRGB(60, 60, 64), M.Metal)
			B("LadderRest", Vector3.new(3.6, 1.6, 0.6), Vector3.new(0, topLow + cabH + 0.8, cz - 1), Color3.fromRGB(60, 60, 64), M.Metal)
			for _, sx in ipairs({ -1, 1 }) do
				B("Outrigger", Vector3.new(1.2, 1.2, 1.6), Vector3.new(sx * (W / 2 - 0.4), cl + 0.8, L / 2 - 5), Color3.fromRGB(240, 200, 40), M.Metal)
			end
		end
		if s.rescueBox then
			B("LightTower", Vector3.new(1.2, 2.4, 1.2), Vector3.new(0, topLow + boxH + 1.2, L / 2 - 3), Color3.fromRGB(60, 60, 64), M.Metal)
			B("LightTowerHead", Vector3.new(3.6, 0.8, 0.8), Vector3.new(0, topLow + boxH + 2.8, L / 2 - 3), Color3.fromRGB(255, 252, 235), M.Neon)
			B("RoofRack", Vector3.new(W - 1.2, 0.3, boxL - 4), Vector3.new(0, topLow + boxH + 0.15, boxZ0 + boxL / 2 - 1), chrome, M.DiamondPlate)
		end
		roofY = topLow + cabH
	end

	-- Sondersignal (Lichtbalken) fuer Einsatzfahrzeuge
	if s.emergency then
		local function lamp(name, size, pos, col)
			local lp = B(name, size, pos, col, M.Neon, { transp = 0.6 })
			local pl = Instance.new("PointLight")
			pl.Color = col
			pl.Range = 22
			pl.Brightness = 4
			pl.Enabled = false
			pl.Parent = lp
			return lp
		end
		local red = Color3.fromRGB(255, 30, 40)
		local blue = (s.emergency == "Police") and Color3.fromRGB(40, 90, 255) or Color3.fromRGB(255, 244, 230) -- Feuerwehr/EMS: rot-weiss
		if s.hiddenLights then
			-- verdeckte Beleuchtung: im Kuehlergrill und hinter der Heckscheibe
			for _, sx in ipairs({ -1, 1 }) do
				local name, col = (sx < 0) and "LightRed" or "LightBlue", (sx < 0) and red or blue
				lamp(name, Vector3.new(0.9, 0.35, 0.15), Vector3.new(sx * W * 0.14, cl + lowH * 0.55, -L / 2 + 0.5), col)
				lamp(name, Vector3.new(1.2, 0.3, 0.15), Vector3.new(sx * W * 0.2, roofY - 0.5, 4.6), col)
			end
		else
			local by = roofY + 0.35
			local bz = ({ sedan = 1.0, suv = 0.6, sports = 1.4, van = -L / 2 + 0.6 + 2.2 + 3.25, truck = -L / 2 + 0.6 + 4 })[s.kind] or 0
			B("LightbarBase", Vector3.new(W - 1.6, 0.5, 1.2), Vector3.new(0, by, bz), dark, M.SmoothPlastic)
			for _, sx in ipairs({ -1, 1 }) do
				lamp((sx < 0) and "LightRed" or "LightBlue", Vector3.new((W - 1.8) / 2 - 0.2, 0.55, 1.0), Vector3.new(sx * (W - 1.8) / 4, by + 0.5, bz), (sx < 0) and red or blue)
			end
		end
		if s.livery and (s.kind == "sedan" or s.kind == "suv" or s.kind == "sports") then
			for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
				local sx = (face == Enum.NormalId.Left) and -1 or 1
				local panelCol = s.whiteDoors and Color3.fromRGB(245, 245, 245) or (s.stripe or Color3.fromRGB(20, 22, 30))
				local door = mk("Part", body, "LiveryPanel", Vector3.new(0.1, 1.2, 5.6), CFrame.new(sx * (W / 2 + 0.03), cl + lowH * 0.55, 0.4), panelCol, M.SmoothPlastic)
				textPanel(door, face, s.livery, s.whiteDoors and Color3.fromRGB(20, 22, 30) or Color3.new(1, 1, 1))
				if s.stripe then
					B("LiveryStripe", Vector3.new(0.08, 0.5, L - 2), Vector3.new(sx * (W / 2 + 0.02), cl + lowH * 0.2, 0), s.stripe, M.SmoothPlastic)
				end
			end
			if s.pushbar then
				B("PushBar", Vector3.new(W * 0.6, 1.6, 0.4), Vector3.new(0, cl + 1.2, -L / 2 - 0.2), dark, M.Metal)
			end
			if s.blackHood then
				B("HoodBlack", Vector3.new(W - 0.25, 0.42, 3.2), Vector3.new(0, topLow + 0.22, -L / 2 + 2.3), dark, M.SmoothPlastic)
			end
		end
	end
	return cabZ, seatY
end

-- Fahrwerk und Raeder --------------------------------------------------------------------
local function buildWheel(model, chassis, s, wx, wz, front)
	local r = s.r
	local wheelPos = Vector3.new(wx, r, wz)
	local chassisInv = chassis.CFrame:Inverse()
	-- Hilfsteile mit realistischer Masse (~3): zu leichte Glieder zwischen Feder und Rad machen den Solver instabil
	local HELPER_PHYS = PhysicalProperties.new(3, 0.3, 0, 1, 1)
	local susp = mk("Part", model, "Susp", Vector3.new(1, 1, 1), CFrame.new(wheelPos), Color3.new(), M.SmoothPlastic, { transp = 1 })
	susp.CanCollide = false
	susp.CanQuery = false
	susp.CustomPhysicalProperties = HELPER_PHYS
	-- Federbein: Prismatic (vertikal) + Feder
	local a0 = att(chassis, "StrutBase", upAxis(chassisInv * wheelPos))
	local a1 = att(susp, "StrutEnd", upAxis(Vector3.zero))
	local pr = Instance.new("PrismaticConstraint")
	pr.Name = "Suspension"
	pr.Attachment0, pr.Attachment1 = a0, a1
	pr.LimitsEnabled = true
	pr.LowerLimit = -0.9
	pr.UpperLimit = 0.7
	pr.Parent = susp
	local top = att(chassis, "SpringTop", CFrame.new(chassisInv * (wheelPos + Vector3.new(0, 2, 0))))
	local bot = att(susp, "SpringBottom", CFrame.new())
	local sp = Instance.new("SpringConstraint")
	sp.Name = "Spring"
	sp.Attachment0, sp.Attachment1 = top, bot
	sp.Stiffness = s.k
	sp.Damping = s.damp
	local weightPerWheel = 0 -- wird nach Massenberechnung gesetzt
	sp.FreeLength = 2.6
	sp.Visible = false
	sp.Parent = susp
	local hub = susp
	if front then
		local steer = mk("Part", model, "Steer", Vector3.new(1, 1, 1), CFrame.new(wheelPos), Color3.new(), M.SmoothPlastic, { transp = 1 })
		steer.CanCollide = false
		steer.CanQuery = false
		steer.CustomPhysicalProperties = HELPER_PHYS
		local sa0 = att(susp, "SteerBase", upAxis(Vector3.zero))
		local sa1 = att(steer, "SteerEnd", upAxis(Vector3.zero))
		local h = Instance.new("HingeConstraint")
		h.Name = "SteerServo"
		h.Attachment0, h.Attachment1 = sa0, sa1
		h.ActuatorType = Enum.ActuatorType.Servo
		h.ServoMaxTorque = s.torque * 20 -- an Fahrzeuggroesse angepasst (zu hoch -> Instabilitaet)
		h.AngularSpeed = 4
		h.LimitsEnabled = true
		h.LowerAngle = -s.steer
		h.UpperAngle = s.steer
		h.Parent = steer
		hub = steer
	end
	-- Rad
	local wheel = mk("Part", model, "Wheel", Vector3.new(s.ww, r * 2, r * 2), CFrame.new(wheelPos), Color3.fromRGB(22, 22, 24), M.Rubber, { shape = CYL })
	wheel.CustomPhysicalProperties = PhysicalProperties.new(0.9, 1.8, 0, 100, 1)
	wheel.CollisionGroup = "VehicleWheel"
	local side = (wx < 0) and -1 or 1
	local rim = mk("Part", model, "Rim", Vector3.new(s.ww + 0.06, r * 1.25, r * 1.25), CFrame.new(wheelPos), Color3.fromRGB(205, 208, 214), M.Metal, { shape = CYL, refl = 0.3 })
	local cap = mk("Part", model, "HubCap", Vector3.new(s.ww + 0.12, r * 0.4, r * 0.4), CFrame.new(wheelPos), Color3.fromRGB(60, 62, 66), M.Metal, { shape = CYL })
	local spokes = {}
	for i = 0, 2 do
		spokes[i + 1] = mk("Part", model, "Spoke", Vector3.new(0.15, r * 1.15, 0.3), CFrame.new(wheelPos + Vector3.new(side * (s.ww / 2 + 0.04), 0, 0)) * CFrame.Angles(math.rad(i * 60), 0, 0), Color3.fromRGB(150, 154, 160), M.Metal)
	end
	for _, p in ipairs({ rim, cap, table.unpack(spokes) }) do
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = wheel, p
		w.Parent = p
	end
	local ha0 = att(hub, "AxleBase", CFrame.new())
	local ha1 = att(wheel, "AxleEnd", CFrame.new())
	local motor = Instance.new("HingeConstraint")
	motor.Name = "DriveMotor"
	motor.Attachment0, motor.Attachment1 = ha0, ha1
	motor.ActuatorType = Enum.ActuatorType.Motor
	motor.MotorMaxTorque = s.torque * 0.08
	motor.AngularVelocity = 0
	motor.Parent = wheel
	local _ = weightPerWheel
	return sp
end

-- Fahrzeugvorlage bauen. Ergebnis: Model mit PrimaryPart "Chassis", unverankert, Tag "Vehicle".
function VK.build(typeName)
	local s = VK.SPECS[typeName]
	assert(s, "Unbekannter Fahrzeugtyp " .. tostring(typeName))
	local model = Instance.new("Model")
	model.Name = "Vehicle_" .. typeName
	local chassis = mk("Part", model, "Chassis", Vector3.new(s.W - 2 * s.ww - 0.6, 0.8, s.L - 1.6), CFrame.new(0, s.clear + 0.4, 0), Color3.fromRGB(20, 20, 22), M.SmoothPlastic)
	chassis.CustomPhysicalProperties = PhysicalProperties.new(s.density, 0.3, 0, 1, 1)
	chassis.CollisionGroup = "VehicleBody"
	model.PrimaryPart = chassis

	-- Sirenen (Einsatzfahrzeuge): werden von jedem Client lokal abgespielt (Attribut "Siren"/"SirenTone")
	if s.emergency then
		local PoliceCfg = require(game:GetService("ReplicatedStorage"):WaitForChild("MiamiShared").Config.Police)
		for i, tone in ipairs(PoliceCfg.SirenTones) do
			local snd = Instance.new("Sound")
			snd.Name = "Siren" .. i
			snd.SoundId = tone.SoundId
			snd.Looped = true
			snd.Volume = 1.1
			snd.RollOffMode = Enum.RollOffMode.InverseTapered
			snd.RollOffMinDistance = 25
			snd.RollOffMaxDistance = 450
			snd.Parent = chassis
		end
		local horn = Instance.new("Sound")
		horn.Name = "Horn"
		horn.SoundId = PoliceCfg.HornSoundId
		horn.Volume = 1.2
		horn.RollOffMaxDistance = 300
		horn.Parent = chassis
	end

	local body = Instance.new("Folder")
	body.Name = "Body"
	body.Parent = model
	local cabZ, seatY = buildBody(body, s)

	-- Sitze
	local seat = mk("VehicleSeat", model, "DriverSeat", Vector3.new(2, 0.8, 2), CFrame.new(-s.W * 0.22, seatY, cabZ - 0.6), Color3.fromRGB(40, 40, 44), M.Fabric)
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.HeadsUpDisplay = false
	local passengers = { { s.W * 0.22, seatY, cabZ - 0.6 } }
	if s.kind == "sedan" or s.kind == "suv" then
		table.insert(passengers, { -s.W * 0.2, seatY, cabZ + 3.0 })
		table.insert(passengers, { s.W * 0.2, seatY, cabZ + 3.0 })
	elseif s.kind == "truck" then
		-- Mannschaftsraum hinter dem Fahrerhaus
		table.insert(passengers, { -s.W * 0.22, seatY, cabZ + 3.4 })
		table.insert(passengers, { s.W * 0.22, seatY, cabZ + 3.4 })
	elseif s.kind == "van" then
		-- Patientenraum: Begleitsitz und Trage (Load nutzt die hoechste freie Nummer zuerst)
		local boxZ0 = -s.L / 2 + 9.3
		table.insert(passengers, { -s.W * 0.2, seatY, boxZ0 + 2.5 })
		table.insert(passengers, { s.W * 0.18, seatY, boxZ0 + 4.5 })
	end
	for i, p in ipairs(passengers) do
		mk("Seat", model, "PassengerSeat" .. i, Vector3.new(2, 0.8, 2), CFrame.new(p[1], p[2], p[3]), Color3.fromRGB(40, 40, 44), M.Fabric)
	end

	-- Karosserie, Sitze und Kollider ans Chassis schweissen
	local collider = mk("Part", model, "BodyCollider", Vector3.new(s.W, s.H - s.clear - 0.4, s.L), CFrame.new(0, s.clear + 0.2 + (s.H - s.clear - 0.4) / 2, 0), Color3.new(), M.SmoothPlastic, { transp = 1 })
	collider.CollisionGroup = "VehicleBody"
	for _, p in ipairs(body:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Massless = true
			p.CanCollide = false
			p.CanQuery = false
			p.CollisionGroup = "VehicleBody"
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = chassis, p
			w.Parent = p
		end
	end
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("Seat") or p:IsA("VehicleSeat") or p == collider then
			p.Massless = true
			if p ~= collider then
				p.CanCollide = false
			end
			p.CollisionGroup = "VehicleBody"
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = chassis, p
			w.Parent = p
		end
	end

	-- Raeder
	local springs = {}
	for _, wz in ipairs({ -s.wb / 2, s.wb / 2 }) do
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(springs, buildWheel(model, chassis, s, sx * s.track / 2, wz, wz < 0))
		end
	end

	-- Federvorspannung aus Gesamtmasse: Ruhelage = Prismatic-Position 0
	local mass = 0
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and not p.Massless then
			mass += p:GetMass()
		end
	end
	local perWheel = mass * workspace.Gravity / 4
	for _, sp in ipairs(springs) do
		sp.FreeLength = 2 + perWheel / s.k
	end

	model:SetAttribute("VehicleType", typeName)
	model:SetAttribute("MaxSpeed", s.maxSpeed)
	model:SetAttribute("Torque", s.torque)
	model:SetAttribute("BrakeTorque", s.torque * 2.5)
	model:SetAttribute("MaxSteer", s.steer)
	model:SetAttribute("WheelRadius", s.r)
	model:SetAttribute("DriveSign", -1)
	model:SetAttribute("Mass", math.floor(mass))
	if s.emergency then
		model:SetAttribute("Emergency", s.emergency)
		model:SetAttribute("LightsOn", false)
	end
	CollectionService:AddTag(model, "Vehicle")
	return model
end

-- Dekorative, verankerte Kopie (geparkte Autos)
function VK.parkedCopy(template, cf)
	local m = template:Clone()
	CollectionService:RemoveTag(m, "Vehicle")
	CollectionService:AddTag(m, "ParkedCar")
	m.Name = "Parked_" .. (template:GetAttribute("VehicleType") or "Car")
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Constraint") or d:IsA("Light") then
			d:Destroy()
		elseif d:IsA("Seat") or d:IsA("VehicleSeat") then
			d.Disabled = true
		end
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	m:PivotTo(cf)
	return m
end

return VK
