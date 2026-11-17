-- Schritt 29 (Prompt 13): LOTT E-Scooter - Modellvorlage und Verteilung in der Stadt.
-- Vorlage: ServerStorage.LottScooterTemplate (fahrbar wie die anderen Fahrzeuge: Chassis, DriverSeat,
--   DriveMotor/SteerServo; zusaetzlich AlignOrientation haelt den Roller aufrecht).
-- Welt: workspace.LottScooters (eindeutige Ids LOTT-1001 ...), realistisch verteilt nach Kategorien,
--   mindestens 220 Studs Abstand, nur auf freien, flachen Gehwegstellen.
return function(Kit)
	local CollectionService = game:GetService("CollectionService")
	local ServerStorage = game:GetService("ServerStorage")
	local rgb = Color3.fromRGB
	local M = Enum.Material
	local MINT = rgb(0, 214, 160)

	local function part(parent, name, size, cf, color, mat, o)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat or M.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Anchored = false
		for k, v in pairs(o or {}) do
			p[k] = v
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
	local function upAxis(pos)
		return CFrame.fromMatrix(pos, Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0))
	end
	local function label(p, face, text, color, bg)
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.PixelsPerStud = 80
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.LightInfluence = 0
		sg.Parent = p
		local l = Instance.new("TextLabel")
		l.Name = "Text"
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = bg and 0 or 1
		l.BackgroundColor3 = bg or rgb(0, 0, 0)
		l.TextScaled = true
		l.Font = Enum.Font.GothamBlack
		l.TextColor3 = color
		l.Text = text
		l.Parent = sg
		return l
	end

	----------------------------------------------------------------------------------------------------
	-- 1) VORLAGE
	----------------------------------------------------------------------------------------------------
	local old = ServerStorage:FindFirstChild("LottScooterTemplate")
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = "LottScooterTemplate"
	local R = 0.42 -- Radradius
	local WB = 3.3 -- Radstand
	local DECK_Y = R + 0.25
	local chassis = part(m, "Chassis", Vector3.new(1, 0.28, 3.6), CFrame.new(0, DECK_Y, 0), rgb(30, 32, 36), M.SmoothPlastic)
	chassis.CustomPhysicalProperties = PhysicalProperties.new(2.2, 0.3, 0, 1, 1)
	chassis.CollisionGroup = "VehicleBody"
	m.PrimaryPart = chassis
	local body = Instance.new("Folder")
	body.Name = "Body"
	body.Parent = m
	-- Karosserie (massless, an das Chassis geschweisst)
	part(body, "Grip", Vector3.new(0.9, 0.05, 2.6), CFrame.new(0, DECK_Y + 0.165, 0.2), rgb(20, 20, 22), M.Fabric)
	part(body, "DeckTrim", Vector3.new(1.04, 0.12, 3.62), CFrame.new(0, DECK_Y - 0.12, 0), MINT, M.SmoothPlastic)
	local stem = part(body, "Stem", Vector3.new(0.32, 3.5, 0.32), CFrame.new(0, DECK_Y + 1.6, -1.55) * CFrame.Angles(math.rad(-12), 0, 0), MINT, M.SmoothPlastic)
	local logo = part(body, "Logo", Vector3.new(0.34, 1.2, 0.05), stem.CFrame * CFrame.new(0, -0.2, -0.18), rgb(255, 255, 255), M.SmoothPlastic)
	label(logo, Enum.NormalId.Front, "LOTT", rgb(0, 150, 110))
	local bar = part(body, "Handlebar", Vector3.new(2.2, 0.16, 0.16), stem.CFrame * CFrame.new(0, 1.75, 0), rgb(30, 32, 36), M.Metal)
	for _, x in ipairs({ -1.0, 1.0 }) do
		part(body, "HandGrip", Vector3.new(0.45, 0.22, 0.22), bar.CFrame * CFrame.new(x, 0, 0), rgb(15, 15, 16), M.Fabric)
	end
	local display = part(body, "Display", Vector3.new(0.6, 0.06, 0.38), bar.CFrame * CFrame.new(0, 0.12, 0.05) * CFrame.Angles(math.rad(-30), 0, 0), rgb(10, 12, 16), M.Glass)
	local dl = label(display, Enum.NormalId.Top, "LOTT  87%", MINT, rgb(10, 12, 16))
	dl.Name = "DisplayText"
	local front = part(body, "Headlight", Vector3.new(0.3, 0.2, 0.08), stem.CFrame * CFrame.new(0, 1.1, -0.2), rgb(255, 250, 230), M.Neon)
	local fl = Instance.new("SpotLight")
	fl.Range, fl.Brightness, fl.Angle, fl.Face = 18, 1.4, 50, Enum.NormalId.Front
	fl.Parent = front
	part(body, "Taillight", Vector3.new(0.5, 0.12, 0.06), CFrame.new(0, DECK_Y + 0.3, 1.95), rgb(220, 30, 40), M.Neon)
	part(body, "RearFender", Vector3.new(0.5, 0.08, 1.0), CFrame.new(0, DECK_Y + 0.5, 1.75) * CFrame.Angles(math.rad(-15), 0, 0), MINT, M.SmoothPlastic)
	part(body, "Kickstand", Vector3.new(0.08, 0.6, 0.08), CFrame.new(0.45, DECK_Y - 0.3, 0.6) * CFrame.Angles(0, 0, math.rad(25)), rgb(30, 32, 36), M.Metal)
	for _, p in ipairs(body:GetChildren()) do
		p.Massless, p.CanCollide, p.CanQuery = true, false, false
		p.CollisionGroup = "VehicleBody"
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = chassis, p
		w.Parent = p
	end
	-- Fahrersitz (unsichtbar auf dem Trittbrett) + Kollider
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(0.9, 0.2, 1.1)
	seat.CFrame = CFrame.new(0, DECK_Y + 0.25, 0.5)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Massless = true
	seat.MaxSpeed, seat.Torque, seat.TurnSpeed = 0, 0, 0
	seat.HeadsUpDisplay = false
	seat.Disabled = true -- nur waehrend einer Miete freigegeben (LottService)
	seat.Parent = m
	local ws = Instance.new("WeldConstraint")
	ws.Part0, ws.Part1 = chassis, seat
	ws.Parent = seat
	-- Raeder: je zwei schmale Raeder vorne/hinten (Stabilitaet), vorne gelenkt
	local function wheel(x, z, frontWheel)
		local pos = Vector3.new(x, R, z)
		local hub = chassis
		local hubAtt
		if frontWheel then
			local steer = part(m, "Steer", Vector3.new(0.3, 0.3, 0.3), CFrame.new(pos), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
			steer.CustomPhysicalProperties = PhysicalProperties.new(1, 0.3, 0, 1, 1)
			local a0 = att(chassis, "SteerBase", upAxis(chassis.CFrame:PointToObjectSpace(pos)))
			local a1 = att(steer, "SteerEnd", upAxis(Vector3.zero))
			local h = Instance.new("HingeConstraint")
			h.Name = "SteerServo"
			h.Attachment0, h.Attachment1 = a0, a1
			h.ActuatorType = Enum.ActuatorType.Servo
			h.ServoMaxTorque = 3000
			h.AngularSpeed = 5
			h.LimitsEnabled = true
			h.LowerAngle, h.UpperAngle = -28, 28
			h.Parent = steer
			hub = steer
			hubAtt = att(steer, "AxleBase", CFrame.new())
		else
			hubAtt = att(chassis, "AxleBase", CFrame.new(chassis.CFrame:PointToObjectSpace(pos)))
		end
		local w = part(m, "Wheel", Vector3.new(0.28, R * 2, R * 2), CFrame.new(pos), rgb(22, 22, 24), M.Rubber, { Shape = Enum.PartType.Cylinder })
		w.CustomPhysicalProperties = PhysicalProperties.new(1.2, 1.6, 0, 100, 1)
		w.CollisionGroup = "VehicleWheel"
		local rim = part(m, "Rim", Vector3.new(0.3, R * 1.1, R * 1.1), CFrame.new(pos), MINT, M.SmoothPlastic, { Shape = Enum.PartType.Cylinder, CanCollide = false, CanQuery = false, Massless = true })
		local rw = Instance.new("WeldConstraint")
		rw.Part0, rw.Part1 = w, rim
		rw.Parent = rim
		local a1 = att(w, "AxleEnd", CFrame.new())
		local motor = Instance.new("HingeConstraint")
		motor.Name = "DriveMotor"
		motor.Attachment0, motor.Attachment1 = hubAtt, a1
		motor.ActuatorType = Enum.ActuatorType.Motor
		motor.MotorMaxTorque = 0
		motor.AngularVelocity = 0
		motor.Parent = w
		local _ = hub
	end
	for _, z in ipairs({ -WB / 2, WB / 2 }) do
		for _, x in ipairs({ -0.27, 0.27 }) do
			wheel(x, z, z < 0)
		end
	end
	-- Aufrecht halten (keine Kippgefahr), Gieren bleibt frei
	local up = att(chassis, "UprightAttachment", upAxis(Vector3.zero))
	local align = Instance.new("AlignOrientation")
	align.Name = "Upright"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = up
	align.AlignType = Enum.AlignType.PrimaryAxisParallel
	align.PrimaryAxis = Vector3.new(0, 1, 0)
	align.MaxTorque = 6000
	align.Responsiveness = 25
	align.Parent = chassis
	m:SetAttribute("VehicleType", "LottScooter")
	m:SetAttribute("MaxSpeed", 34) -- ca. 34 km/h
	m:SetAttribute("Torque", 260)
	m:SetAttribute("BrakeTorque", 700)
	m:SetAttribute("MaxSteer", 28)
	m:SetAttribute("WheelRadius", R)
	m:SetAttribute("DriveSign", -1)
	m:SetAttribute("DisplayName", "LOTT E-Scooter")
	CollectionService:AddTag(m, "Vehicle") -- bestehendes Fahrzeugsystem: Einsteigen, Netzwerkeigentum, Steuerung, HUD
	m.Parent = ServerStorage

	----------------------------------------------------------------------------------------------------
	-- 2) VERTEILUNG IN DER STADT
	----------------------------------------------------------------------------------------------------
	local folder = workspace:FindFirstChild("LottScooters")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "LottScooters"
	folder.Parent = workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, workspace.Terrain }
	local function spotNear(p)
		-- freier, flacher Platz (kein Strassenbelag, nichts hoeher als 1 Stud) in 4-14 Studs Umkreis
		for r = 4, 14, 2 do
			for a = 0, 330, 30 do
				local x, z = p.X + math.cos(math.rad(a)) * r, p.Z + math.sin(math.rad(a)) * r
				local h = workspace:Raycast(Vector3.new(x, 30, z), Vector3.new(0, -60, 0), params)
				if h and h.Position.Y < 4 and not h.Instance:IsDescendantOf(workspace.Map.Roads) then
					local ok = true
					for _, o in ipairs({ { 2.5, 0 }, { -2.5, 0 }, { 0, 2.5 }, { 0, -2.5 } }) do
						local h2 = workspace:Raycast(Vector3.new(x + o[1], 30, z + o[2]), Vector3.new(0, -60, 0), params)
						if not h2 or math.abs(h2.Position.Y - h.Position.Y) > 0.6 or h2.Instance:IsDescendantOf(workspace.Map.Roads) then
							ok = false
							break
						end
					end
					if ok then
						return h.Position
					end
				end
			end
		end
		return nil
	end
	local placed = {}
	local function farEnough(p)
		for _, q in ipairs(placed) do
			if (q - p).Magnitude < 220 then
				return false
			end
		end
		return true
	end
	local function inBox(p, x0, x1, z0, z1)
		return p.X >= x0 and p.X <= x1 and p.Z >= z0 and p.Z <= z1
	end
	local function tagged(tag, filter)
		local out = {}
		for _, t in ipairs(CollectionService:GetTagged(tag)) do
			if t:IsA("BasePart") and t:IsDescendantOf(workspace) and t.Position.X < 4000 and (not filter or filter(t)) then
				table.insert(out, t.Position)
			end
		end
		return out
	end
	local rng = Random.new(1313)
	local function shuffle(t)
		for i = #t, 2, -1 do
			local j = rng:NextInteger(1, i)
			t[i], t[j] = t[j], t[i]
		end
		return t
	end
	local function interactPos(kind)
		local out = {}
		for _, t in ipairs(CollectionService:GetTagged("Interactable")) do
			if t:IsA("BasePart") and t:IsDescendantOf(workspace.Map) and t.Position.X < 4000 and t:GetAttribute("InteractType") == kind then
				table.insert(out, t.Position)
			end
		end
		return out
	end
	local categories = {
		{ "Downtown", 6, shuffle(tagged("StoreEntrance", function(t)
			return inBox(t.Position, -330, 1000, -1000, 1000)
		end)) },
		{ "Einkaufsstrasse", 3, shuffle(tagged("StoreEntrance", function(t)
			return inBox(t.Position, -4300, -700, -2600, 2300)
		end)) },
		{ "Park", 3, shuffle((function()
			local out = {}
			for _, d in ipairs(workspace.Map:GetDescendants()) do
				if d:IsA("BasePart") and d.Name == "Lawn" and d.Size.X > 40 and d.Position.X < 4000 then
					table.insert(out, d.Position + Vector3.new(d.Size.X / 2 + 3, 0, 0))
				end
			end
			return out
		end)()) },
		{ "Strandpromenade", 3, shuffle((function()
			local out = {}
			for z = -1800, 1800, 300 do
				table.insert(out, Vector3.new(2520, 0, z))
			end
			for z = -1600, 800, 400 do
				table.insert(out, Vector3.new(966, 0, z))
			end
			return out
		end)()) },
		{ "Wohngebiet", 3, shuffle(interactPos("Property")) },
		{ "Buero", 2, shuffle(interactPos("BusinessOffice")) },
		{ "Restaurant/Club", 2, shuffle((function()
			local out = interactPos("VenueDoor")
			for _, p in ipairs(tagged("StoreEntrance", function(t)
				return inBox(t.Position, -330, 1000, -2200, -1400)
			end)) do
				table.insert(out, p)
			end
			return out
		end)()) },
		{ "Verkehrsknoten", 2, shuffle(tagged("BusStop")) },
	}
	local id = 1000
	local summary = {}
	for _, cat in ipairs(categories) do
		local n = 0
		for _, p in ipairs(cat[3]) do
			if n >= cat[2] then
				break
			end
			local spot = spotNear(p)
			if spot and farEnough(spot) then
				id += 1
				local s = m:Clone()
				s.Name = "LOTT-" .. id
				s:SetAttribute("ScooterId", "LOTT-" .. id)
				s:SetAttribute("Plate", "LOTT-" .. id)
				s:SetAttribute("Category", cat[1])
				s:SetAttribute("Available", true)
				local yaw = rng:NextNumber(0, math.pi * 2)
				s:PivotTo(CFrame.new(spot + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, yaw, 0))
				s.Chassis.Anchored = true -- ruhend verankert (keine Physiklast), LottService loest bei Miete
				s.Parent = folder
				table.insert(placed, spot)
				n += 1
			end
		end
		table.insert(summary, cat[1] .. " " .. n)
	end
	local _ = Kit
	return string.format("Vorlage + %d Roller (%s)", #placed, table.concat(summary, ", "))
end
