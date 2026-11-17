-- Schritt 26 (Prompt 11): Berufe & Unternehmen in der Welt.
-- Dienstfahrzeuge (Varianten bestehender Vorlagen), Depots mit Terminals und Stellplaetzen, Ladestellen,
-- Frachtziele, Bushaltestellen (Linie 1), Baustelle, Unternehmensbueros; BusinessId an bestehenden Kassen/Tueren.
-- Idempotent (workspace.Map.Prompt11 wird neu gebaut). Positionen per Freiflaechensuche -> nichts in Gebaeuden.
return function(Kit)
	local CollectionService = game:GetService("CollectionService")
	local ServerStorage = game:GetService("ServerStorage")
	local rgb = Color3.fromRGB
	local M = Enum.Material

	local root = workspace.Map:FindFirstChild("Prompt11")
	if root then
		root:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "Prompt11"
	root.Parent = workspace.Map
	local log = {}

	local function folder(parent, name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
		return f
	end
	local function model(parent, name)
		local m = Instance.new("Model")
		m.Name = name
		m.Parent = parent
		return m
	end
	local function mk(parent, name, size, cf, color, mat, o)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color or rgb(200, 200, 200)
		p.Material = mat or M.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		for k, v in pairs(o or {}) do
			p[k] = v
		end
		p.Parent = parent
		return p
	end
	local function signText(part, face, text, color, bg)
		local sg = Instance.new("SurfaceGui")
		sg.Face = face or Enum.NormalId.Front
		sg.PixelsPerStud = 40
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.LightInfluence = 0
		sg.Parent = part
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = bg and 0 or 1
		l.BackgroundColor3 = bg or rgb(0, 0, 0)
		l.Text = text
		l.TextScaled = true
		l.Font = Enum.Font.GothamBlack
		l.TextColor3 = color or rgb(255, 255, 255)
		l.Parent = sg
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0.05, 0), UDim.new(0.05, 0)
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0.1, 0), UDim.new(0.1, 0)
		pad.Parent = l
		return l
	end
	local function interact(parent, name, cf, kind, text, objectText, attrs)
		local p = mk(parent, name, Vector3.new(3, 5, 1), cf, rgb(255, 255, 255), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		p:SetAttribute("InteractType", kind)
		p:SetAttribute("InteractText", text)
		p:SetAttribute("ObjectText", objectText)
		p:SetAttribute("Range", 10)
		for k, v in pairs(attrs or {}) do
			p:SetAttribute(k, v)
		end
		CollectionService:AddTag(p, "Interactable")
		return p
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root, workspace.Terrain, workspace:FindFirstChild("Vehicles") }
	local function hit(x, z)
		return workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -500, 0), params)
	end
	local function groundY(x, z)
		local r = workspace:Raycast(Vector3.new(x, 9, z), Vector3.new(0, -30, 0), params)
		return r and r.Position.Y or 0.6
	end
	local function isRoad(r)
		return r and r.Instance:IsDescendantOf(workspace.Map.Roads)
	end
	-- freie Flaeche (w x d) nahe center: kein Objekt hoeher als 2.5 ueber Grund, keine Strasse
	local function findFree(center, w, d, maxR, allowRoad)
		for r = 0, maxR or 200, 8 do
			for a = 0, 330, 30 do
				local cx = center.X + math.cos(math.rad(a)) * r
				local cz = center.Z + math.sin(math.rad(a)) * r
				local ok = true
				local gy
				for ix = -1, 1 do
					for iz = -1, 1 do
						local h = hit(cx + ix * w / 2, cz + iz * d / 2)
						if not h or (not allowRoad and isRoad(h)) then
							ok = false
						else
							gy = gy or h.Position.Y
							if math.abs(h.Position.Y - gy) > 2.5 or h.Position.Y > 4 then
								ok = false
							end
						end
					end
				end
				if ok then
					return Vector3.new(cx, gy, cz)
				end
				if r == 0 then
					break
				end
			end
		end
		return nil
	end
	-- Gehweg neben einem Strassenpunkt (perp = Einheitsvektor quer zur Strasse)
	local function sidewalk(x, z, perp)
		for off = 8, 70, 2 do
			local px, pz = x + perp.X * off, z + perp.Z * off
			local h = hit(px, pz)
			if h and not isRoad(h) and h.Position.Y < 4 then
				return Vector3.new(px + perp.X * 3, h.Position.Y, pz + perp.Z * 3)
			end
		end
		return nil
	end
	local function kiosk(parent, name, cf, color, label)
		local k = model(parent, name)
		mk(k, "Base", Vector3.new(2.4, 4.4, 1.2), cf * CFrame.new(0, 2.2, 0), rgb(26, 28, 34), M.Metal)
		local scr = mk(k, "Screen", Vector3.new(2, 1.6, 0.1), cf * CFrame.new(0, 3.4, -0.62), color, M.Neon)
		signText(scr, Enum.NormalId.Front, label, rgb(10, 12, 16))
		return k
	end
	local function sign(parent, cf, w, h, text, color)
		local s = mk(parent, "Sign", Vector3.new(w, h, 0.4), cf, rgb(14, 16, 22))
		signText(s, Enum.NormalId.Front, text, color)
		signText(s, Enum.NormalId.Back, text, color)
		return s
	end

	----------------------------------------------------------------------------------------------------
	-- 1) DIENSTFAHRZEUGE
	----------------------------------------------------------------------------------------------------
	local V = ServerStorage.Vehicles
	local function variant(baseName, newName, attrs, tweak)
		local old = V:FindFirstChild("Vehicle_" .. newName)
		if old then
			old:Destroy()
		end
		local m = V["Vehicle_" .. baseName]:Clone()
		m.Name = "Vehicle_" .. newName
		for k in pairs(m:GetAttributes()) do
			if k == "Emergency" or k == "LightsOn" then
				m:SetAttribute(k, nil)
			end
		end
		m:SetAttribute("VehicleType", newName)
		for k, v in pairs(attrs) do
			m:SetAttribute(k, v)
		end
		local ch = m:FindFirstChild("Chassis")
		local function add(name, size, offset, color, mat, o)
			local p = mk(m.Body, name, size, ch.CFrame * offset, color, mat, o)
			p.Anchored, p.Massless, p.CanCollide = false, true, false
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = p, ch
			w.Parent = p
			return p
		end
		local function paint(color)
			local base = m.Body:FindFirstChild("LowerBody")
			local bc = base and base.Color
			for _, p in ipairs(m.Body:GetChildren()) do
				if p:IsA("BasePart") and bc and p.Color == bc then
					p.Color = color
				end
			end
		end
		tweak(m, add, ch, paint)
		m.Parent = V
		return m
	end
	variant("Sedan", "Taxi", { MaxSpeed = 95, Torque = 2000 }, function(m, add, ch, paint)
		paint(rgb(250, 200, 40))
		local roof
		for _, p in ipairs(m.Body:GetChildren()) do
			if p.Name == "Roof" then
				roof = p
			end
		end
		local ry = roof and ch.CFrame:ToObjectSpace(roof.CFrame).Y + roof.Size.Y / 2 + 0.55 or 4.2
		local s = add("TaxiSign", Vector3.new(2.6, 0.9, 1), CFrame.new(0, ry, 0), rgb(255, 245, 200), M.Neon)
		signText(s, Enum.NormalId.Front, "TAXI", rgb(20, 20, 20))
		signText(s, Enum.NormalId.Back, "TAXI", rgb(20, 20, 20))
		add("Checker", Vector3.new(0.1, 0.4, 9), CFrame.new(-4.02, 1.2, 0), rgb(20, 20, 20))
		add("Checker", Vector3.new(0.1, 0.4, 9), CFrame.new(4.02, 1.2, 0), rgb(20, 20, 20))
	end)
	variant("SUV", "DeliveryVan", { MaxSpeed = 85, Torque = 2300 }, function(m, add, ch, paint)
		paint(rgb(245, 245, 242))
		for _, s in ipairs({ -1, 1 }) do
			local panel = add("Livery", Vector3.new(0.1, 1.8, 8), CFrame.new(s * 4.25, 2.4, 1), rgb(240, 140, 50))
			signText(panel, s < 0 and Enum.NormalId.Left or Enum.NormalId.Right, "GULF COAST PARCEL", rgb(255, 255, 255))
		end
	end)
	variant("Pickup", "BoxTruck", { MaxSpeed = 76, Torque = 2600, BrakeTorque = 7000 }, function(m, add, ch, paint)
		paint(rgb(70, 80, 100))
		local box = add("CargoBox", Vector3.new(8, 6.6, 9.5), CFrame.new(0, 4.4, 5.2), rgb(240, 240, 240), M.SmoothPlastic, { CanCollide = false })
		for _, s in ipairs({ -1, 1 }) do
			local panel = add("Livery", Vector3.new(0.1, 2.2, 8.4), CFrame.new(s * 4.06, 4.6, 5.2), rgb(170, 120, 255))
			signText(panel, s < 0 and Enum.NormalId.Left or Enum.NormalId.Right, "MERIDIAN FREIGHT", rgb(255, 255, 255))
		end
		local _ = box
	end)
	variant("AmbulanceHeavy", "CityBus", { MaxSpeed = 70, Torque = 4200, BrakeTorque = 10500 }, function(m, add, ch, paint)
		for _, p in ipairs(m.Body:GetChildren()) do
			if p:IsA("BasePart") then
				if table.find({ "LightBlue", "LightRed", "LightbarBase", "WarnLightRear", "SceneLight", "StarOfLife", "StretcherFrame" }, p.Name) then
					p.Transparency = 1
					p.CanCollide = false
				elseif p.Name == "Stripe" or p.Name == "StripeTop" then
					p.Color = rgb(40, 140, 230)
					p.Material = M.SmoothPlastic
				elseif p.Name == "Box" or p.Name == "Cabin" or p.Name == "LowerBody" or p.Name == "CabRoof" or p.Name == "Hood" or p.Name == "RearDoors" or p.Name == "SideDoor" then
					if p.Name ~= "Cabin" then
						p.Color = rgb(245, 245, 245)
					end
				end
			end
		end
		for _, l in ipairs(m:GetDescendants()) do
			if l:IsA("Light") and l.Parent and l.Parent:IsA("BasePart") and l.Parent.Transparency >= 1 then
				l.Enabled = false
			elseif l:IsA("SurfaceGui") or l:IsA("Decal") or l:IsA("Texture") then
				l:Destroy() -- Rettungsdienst-Beschriftung der Vorlage entfernen
			end
		end
		for _, s in ipairs({ -1, 1 }) do
			local panel = add("Livery", Vector3.new(0.1, 1.6, 12), CFrame.new(s * 4.75, 4.2, 2), rgb(40, 140, 230))
			signText(panel, s < 0 and Enum.NormalId.Left or Enum.NormalId.Right, "MIAMI STATE TRANSIT", rgb(255, 255, 255))
		end
		local s = add("RouteSign", Vector3.new(5, 0.9, 0.2), CFrame.new(0, 5.6, -11.2), rgb(10, 10, 12), M.SmoothPlastic)
		signText(s, Enum.NormalId.Front, "1  STADTRUNDKURS", rgb(255, 200, 60))
	end)
	variant("Pickup", "ServiceTruck", { MaxSpeed = 88, Torque = 2400 }, function(m, add, ch, paint)
		paint(rgb(255, 150, 40))
		local roof
		for _, p in ipairs(m.Body:GetChildren()) do
			if p.Name == "Roof" then
				roof = p
			end
		end
		local ry = roof and ch.CFrame:ToObjectSpace(roof.CFrame).Y + roof.Size.Y / 2 + 0.3 or 4.2
		add("AmberBar", Vector3.new(4, 0.5, 0.8), CFrame.new(0, ry, 0), rgb(255, 170, 30), M.Neon)
		for _, s in ipairs({ -1, 1 }) do
			local panel = add("Livery", Vector3.new(0.1, 1.2, 5), CFrame.new(s * 4.27, 1.6, -2), rgb(30, 50, 100))
			signText(panel, s < 0 and Enum.NormalId.Left or Enum.NormalId.Right, "MIAMI AUTO REPAIR", rgb(255, 255, 255))
		end
	end)
	table.insert(log, "Fahrzeuge: Taxi, DeliveryVan, BoxTruck, CityBus, ServiceTruck")

	----------------------------------------------------------------------------------------------------
	-- 2) DEPOTS (Terminal + Stellplaetze)
	----------------------------------------------------------------------------------------------------
	local depots = folder(root, "Depots")
	local function depot(jobId, title, sub, center, color, pads, padLen)
		local m = model(depots, "Depot_" .. jobId)
		local area = findFree(center, 20 + pads * 16, (padLen or 22) + 16, 220)
		if not area then
			table.insert(log, "WARN kein Platz fuer Depot " .. jobId)
			return nil
		end
		local base = CFrame.new(area)
		-- Ueberdachtes Terminal
		mk(m, "Floor", Vector3.new(14, 0.3, 8), base * CFrame.new(0, 0.15, -((padLen or 22) / 2 + 6)), rgb(60, 62, 70), M.Concrete)
		mk(m, "Roof", Vector3.new(16, 0.6, 10), base * CFrame.new(0, 10.3, -((padLen or 22) / 2 + 6)), rgb(30, 32, 38), M.Metal)
		for _, sx in ipairs({ -7, 7 }) do
			mk(m, "Post", Vector3.new(0.6, 10, 0.6), base * CFrame.new(sx, 5.2, -((padLen or 22) / 2 + 2)), rgb(30, 32, 38), M.Metal)
		end
		sign(m, base * CFrame.new(0, 12.4, -((padLen or 22) / 2 + 1.5)), 16, 3, title, color)
		local sub2 = mk(m, "SubSign", Vector3.new(10, 1, 0.2), base * CFrame.new(0, 9.2, -((padLen or 22) / 2 + 1.4)), rgb(14, 16, 22))
		signText(sub2, Enum.NormalId.Front, sub, rgb(230, 230, 230))
		local kcf = base * CFrame.new(0, 0.3, -((padLen or 22) / 2 + 5))
		kiosk(m, "Terminal", kcf, color, "DIENST")
		interact(m, "DepotInteract", kcf * CFrame.new(0, 2.6, -1.6), "WorkDepot", "Schicht beginnen / beenden", title, { JobId = jobId })
		-- Stellplaetze (Blick -Z = Ausfahrt Richtung Terminal-Seite)
		for i = 1, pads do
			local px = (i - (pads + 1) / 2) * 16
			local pad = mk(m, "VehiclePad", Vector3.new(11, 0.12, padLen or 22), base * CFrame.new(px, 0.08, 0), color, M.SmoothPlastic, { Transparency = 0.55, CanCollide = false })
			pad:SetAttribute("JobId", jobId)
			CollectionService:AddTag(pad, "WorkVehiclePad")
			for _, sx in ipairs({ -1, 1 }) do
				mk(m, "Line", Vector3.new(0.4, 0.14, padLen or 22), base * CFrame.new(px + sx * 6, 0.09, 0), rgb(240, 240, 240), M.SmoothPlastic, { CanCollide = false })
			end
		end
		table.insert(log, string.format("Depot %s @%d,%d", jobId, area.X, area.Z))
		return m, base, area
	end
	depot("Taxi", "MIAMI CAB CO.", "TAXIZENTRALE", Vector3.new(-993, 0, 270), rgb(250, 200, 40), 3)
	depot("Bus", "MIAMI STATE TRANSIT", "BUSDEPOT · LINIE 1", Vector3.new(-993, 0, -530), rgb(60, 160, 240), 2, 30)
	local _, dBase = depot("Delivery", "GULF COAST PARCEL", "PAKETDEPOT", Vector3.new(-1606, 0, 1076), rgb(240, 140, 50), 3)
	if dBase then
		-- Laderampe mit Paketstapeln
		local dock = model(depots, "DeliveryDock")
		local dcf = dBase * CFrame.new(40, 0, -8)
		mk(dock, "Ramp", Vector3.new(16, 3, 10), dcf * CFrame.new(0, 1.5, 0), rgb(150, 150, 155), M.Concrete)
		for i = 0, 5 do
			mk(dock, "Parcel", Vector3.new(2, 1.6, 2), dcf * CFrame.new(-6 + i * 2.4, 3.8 + (i % 2) * 1.6, -2), rgb(190, 150, 100), M.SmoothPlastic)
		end
		local p = mk(dock, "DockPoint", Vector3.new(4, 1, 4), dcf * CFrame.new(0, 3.5, 3), rgb(255, 255, 255), M.SmoothPlastic, { Transparency = 1, CanCollide = false })
		p:SetAttribute("Id", "DeliveryDock")
		CollectionService:AddTag(p, "WorkDock")
		sign(dock, dcf * CFrame.new(0, 8, -4), 10, 1.6, "PAKETAUSGABE", rgb(240, 140, 50))
	end
	local _, mBase = depot("Mechanic", "MIAMI AUTO REPAIR", "PANNENDIENST", Vector3.new(-3610, 0, -823), rgb(255, 160, 60), 2)
	local _, tBase = depot("Trucker", "MERIDIAN FREIGHT", "HAFEN · FRACHT", Vector3.new(330, 0, 1330), rgb(170, 120, 255), 3, 26)
	if tBase then
		local dock = model(depots, "TruckDock")
		local dcf = tBase * CFrame.new(-48, 0, 0)
		mk(dock, "Ramp", Vector3.new(12, 4, 14), dcf * CFrame.new(0, 2, 0), rgb(130, 132, 140), M.Concrete)
		for i = 0, 3 do
			mk(dock, "Pallet", Vector3.new(4, 3, 4), dcf * CFrame.new(-3 + (i % 2) * 5, 5.5, -4 + math.floor(i / 2) * 5), rgb(160, 120, 70), M.WoodPlanks)
		end
		local p = mk(dock, "DockPoint", Vector3.new(4, 1, 4), dcf * CFrame.new(8, 1, 0), rgb(255, 255, 255), M.SmoothPlastic, { Transparency = 1, CanCollide = false })
		p:SetAttribute("Id", "TruckDock")
		CollectionService:AddTag(p, "WorkDock")
		sign(dock, dcf * CFrame.new(0, 10, -7), 10, 1.6, "VERLADUNG", rgb(170, 120, 255))
	end
	local _ = mBase

	----------------------------------------------------------------------------------------------------
	-- 3) FRACHTZIELE (Lager, Maerkte, Tankstellen)
	----------------------------------------------------------------------------------------------------
	local drops = folder(root, "TruckDrops")
	local dropDefs = {
		{ "Lager 1 (Hafen)", Vector3.new(-199, 0, 1270) }, { "Lager 2 (Hafen)", Vector3.new(-199, 0, 1610) },
		{ "Lager 4 (Hafen)", Vector3.new(-199, 0, 2290) }, { "Self Storage Sawgrass", Vector3.new(-2143, 0, 1220) },
		{ "Sawgrass Center", Vector3.new(-2690, 0, -470) }, { "Freshway Market Lager", Vector3.new(-3300, 0, -300) },
		{ "Marina Versorgung", Vector3.new(1042, 0, -2400) }, { "Coral Key Hotels", Vector3.new(2300, 0, 300) },
	}
	for i, pump in ipairs(CollectionService:GetTagged("FuelPump")) do
		if i % 3 == 1 and pump:IsA("BasePart") then
			table.insert(dropDefs, { "Tankstelle " .. math.ceil(i / 3), pump.Position + Vector3.new(0, 0, 30) })
		end
	end
	local nDrop = 0
	for _, dd in ipairs(dropDefs) do
		local pos = findFree(dd[2], 16, 16, 120)
		if pos then
			nDrop += 1
			local p = mk(drops, "Drop", Vector3.new(14, 0.12, 14), CFrame.new(pos + Vector3.new(0, 0.07, 0)), rgb(170, 120, 255), M.SmoothPlastic, { Transparency = 0.7, CanCollide = false })
			p:SetAttribute("DropName", dd[1])
			CollectionService:AddTag(p, "TruckDrop")
			sign(drops, CFrame.new(pos + Vector3.new(0, 5, -8)), 7, 1.2, "ANLIEFERUNG", rgb(170, 120, 255))
			mk(drops, "SignPost", Vector3.new(0.4, 4.4, 0.4), CFrame.new(pos + Vector3.new(0, 2.2, -8.4)), rgb(40, 40, 44), M.Metal)
		else
			table.insert(log, "WARN kein Platz fuer Frachtziel " .. dd[1])
		end
	end
	table.insert(log, "Frachtziele: " .. nDrop)

	----------------------------------------------------------------------------------------------------
	-- 4) BUSHALTESTELLEN (Linie 1, Rundkurs)
	----------------------------------------------------------------------------------------------------
	local stops = folder(root, "BusStops")
	local stopDefs = {
		{ "Sawgrass Ost", -1100, -200, Vector3.new(0, 0, -1) }, { "Midtown West", -250, -200, Vector3.new(0, 0, -1) },
		{ "City Hall", 80, -500, Vector3.new(-1, 0, 0) }, { "Bayfront Mitte", 80, 300, Vector3.new(-1, 0, 0) },
		{ "Fire Station", -100, 600, Vector3.new(0, 0, 1) }, { "Sawgrass Sued", -1100, 600, Vector3.new(0, 0, 1) },
		{ "Parkway", -1300, 200, Vector3.new(1, 0, 0) }, { "Public Parking", -1300, -400, Vector3.new(1, 0, 0) },
	}
	local idx = 0
	for _, s in ipairs(stopDefs) do
		local pos = sidewalk(s[2], s[3], s[4])
		if pos then
			idx += 1
			local face = CFrame.lookAt(pos, pos - s[4]) -- Blick zur Strasse
			local m = model(stops, "BusStop_" .. idx)
			mk(m, "ShelterRoof", Vector3.new(10, 0.4, 4), face * CFrame.new(0, 8, 1.5), rgb(30, 32, 38), M.Metal)
			mk(m, "ShelterBack", Vector3.new(10, 6, 0.2), face * CFrame.new(0, 4, 3.4), rgb(180, 220, 240), M.Glass, { Transparency = 0.5 })
			for _, sx in ipairs({ -4.8, 4.8 }) do
				mk(m, "ShelterPost", Vector3.new(0.3, 8, 0.3), face * CFrame.new(sx, 4, 3.3), rgb(30, 32, 38), M.Metal)
			end
			mk(m, "Bench", Vector3.new(7, 0.4, 1.4), face * CFrame.new(0, 1.8, 2.4), rgb(120, 90, 60), M.WoodPlanks)
			local pole = mk(m, "StopPole", Vector3.new(0.3, 9, 0.3), face * CFrame.new(6, 4.5, 0), rgb(200, 200, 205), M.Metal)
			local _ = pole
			local plate = mk(m, "StopSign", Vector3.new(2, 2, 0.2), face * CFrame.new(6, 8.4, 0), rgb(40, 140, 230), M.SmoothPlastic)
			signText(plate, Enum.NormalId.Front, "H", rgb(255, 210, 0))
			signText(plate, Enum.NormalId.Back, "H", rgb(255, 210, 0))
			local nameSign = mk(m, "NameSign", Vector3.new(8, 1, 0.2), face * CFrame.new(0, 7.2, 3.25), rgb(14, 16, 22))
			signText(nameSign, Enum.NormalId.Front, "LINIE 1 · " .. string.upper(s[1]), rgb(255, 210, 0))
			-- Haltepunkt auf der Fahrbahn neben der Haltestelle
			local stopPt = mk(m, "StopPoint", Vector3.new(4, 0.2, 4), CFrame.new(pos - s[4] * 12), rgb(255, 255, 255), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
			stopPt:SetAttribute("Index", idx)
			stopPt:SetAttribute("StopName", s[1])
			CollectionService:AddTag(stopPt, "BusStop")
		else
			table.insert(log, "WARN Haltestelle " .. s[1] .. " nicht platziert")
		end
	end
	table.insert(log, "Haltestellen: " .. idx)

	----------------------------------------------------------------------------------------------------
	-- 5) BAUSTELLE (Sunstate Construction)
	----------------------------------------------------------------------------------------------------
	do
		local site = findFree(Vector3.new(-3306, 0, 1076), 120, 90, 220)
		if site then
			local m = model(root, "ConstructionSite")
			local o = CFrame.new(site)
			-- Bauzaun
			for _, s in ipairs({ { 0, -45, 120, 0 }, { 0, 45, 120, 0 }, { -60, 0, 90, 90 }, { 60, 0, 90, 90 } }) do
				local seg = s[3]
				local len = s[1] == 0 and seg or seg
				local f = mk(m, "Fence", Vector3.new(len, 6, 0.3), o * CFrame.new(s[1], 3, s[2]) * CFrame.Angles(0, math.rad(s[4]), 0), rgb(120, 125, 130), M.DiamondPlate, { Transparency = 0.35 })
				local _ = f
			end
			-- Tor-Oeffnung (Zaun Nordseite teilweise entfernen)
			for _, c in ipairs(m:GetChildren()) do
				if c.Name == "Fence" and math.abs(c.Position.Z - (site.Z - 45)) < 1 then
					c.Size = Vector3.new(90, 6, 0.3)
					c.CFrame = o * CFrame.new(15, 3, -45)
				end
			end
			sign(m, o * CFrame.new(-45, 9, -45.5), 22, 3.4, "SUNSTATE CONSTRUCTION", rgb(255, 200, 40))
			-- Baucontainer mit Dienst-Terminal
			mk(m, "SiteOffice", Vector3.new(20, 8, 8), o * CFrame.new(-45, 4, -36), rgb(240, 240, 235), M.Metal)
			kiosk(m, "Terminal", o * CFrame.new(-40, 0, -31), rgb(255, 200, 40), "DIENST")
			interact(m, "DepotInteract", o * CFrame.new(-40, 2.6, -32.6), "WorkDepot", "Schicht beginnen / beenden", "Sunstate Construction", { JobId = "Construction" })
			-- Rohbau: Fundament, Stahlskelett
			mk(m, "Foundation", Vector3.new(50, 1.6, 40), o * CFrame.new(20, 0.8, 10), rgb(170, 170, 168), M.Concrete)
			for ix = 0, 3 do
				for iz = 0, 2 do
					mk(m, "Column", Vector3.new(1.2, 30, 1.2), o * CFrame.new(-2 + ix * 15, 16.6, -6 + iz * 16), rgb(180, 60, 40), M.Metal)
				end
			end
			for lvl = 1, 2 do
				for iz = 0, 2 do
					mk(m, "Beam", Vector3.new(46, 1, 1), o * CFrame.new(20.5, 1.6 + lvl * 12, -6 + iz * 16), rgb(180, 60, 40), M.Metal)
				end
				mk(m, "Deck", Vector3.new(46, 0.6, 33), o * CFrame.new(20.5, 2.4 + lvl * 12, 10), rgb(160, 160, 158), M.Concrete, { Transparency = lvl == 2 and 0.4 or 0 })
			end
			-- Kran
			mk(m, "CraneTower", Vector3.new(3, 70, 3), o * CFrame.new(52, 35, -30), rgb(255, 200, 40), M.DiamondPlate)
			mk(m, "CraneJib", Vector3.new(70, 2.5, 2.5), o * CFrame.new(32, 70, -30), rgb(255, 200, 40), M.DiamondPlate)
			mk(m, "CraneWeight", Vector3.new(6, 4, 4), o * CFrame.new(64, 68, -30), rgb(80, 80, 84), M.Concrete)
			-- Arbeitspunkte
			local points = {
				{ "Pile", "Materiallager", -40, 25 }, { "Pile", "Stahllager", -50, 0 },
				{ "Drop", "Fundament Ost", 40, 30 }, { "Drop", "Geruest 1. Etage", 5, 28 }, { "Drop", "Rohbau Nord", 30, -10 },
				{ "Tool", "Presslufthammer", -10, 32 }, { "Tool", "Betonmischer bedienen", -25, -15 }, { "Tool", "Schweissarbeiten", 45, -2 }, { "Tool", "Kran steuern", 48, -24 },
			}
			for _, pt in ipairs(points) do
				local cf = o * CFrame.new(pt[3], 0, pt[4])
				if pt[1] == "Pile" then
					for i = 0, 5 do
						mk(m, "Material", Vector3.new(3, 1.2, 2), cf * CFrame.new(-3 + (i % 3) * 3.2, 0.6 + math.floor(i / 3) * 1.2, 0), rgb(170, 130, 80), M.WoodPlanks)
					end
				elseif pt[1] == "Tool" then
					mk(m, "Machine", Vector3.new(3, 3, 3), cf * CFrame.new(0, 1.5, 0), rgb(255, 170, 30), M.Metal)
				else
					mk(m, "DropMarker", Vector3.new(6, 0.12, 6), cf * CFrame.new(0, 0.07, 0), rgb(255, 200, 40), M.SmoothPlastic, { Transparency = 0.5, CanCollide = false })
				end
				local p = mk(m, "Point_" .. pt[2], Vector3.new(2, 2, 2), cf * CFrame.new(0, 2, (pt[1] == "Drop") and 0 or 3), rgb(255, 255, 255), M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
				p:SetAttribute("Kind", pt[1])
				p:SetAttribute("Label", pt[2])
				CollectionService:AddTag(p, "ConstructionPoint")
			end
			table.insert(log, string.format("Baustelle @%d,%d", site.X, site.Z))
		else
			table.insert(log, "WARN kein Platz fuer Baustelle")
		end
	end

	----------------------------------------------------------------------------------------------------
	-- 6) UNTERNEHMEN: BusinessId an bestehenden Kassen/Tueren + Bueros
	----------------------------------------------------------------------------------------------------
	local Work = require(game.ReplicatedStorage.MiamiShared.Config.Work:Clone())
	local byShop = { FineDining = "MaisonAzure", ModernKitchen = "BayfrontKitchen", Rooftop = "Skyline52" }
	local byClub = { Club_NEONROOM = "Neonroom", Club_ECLIPSE = "Eclipse", Club_PULSE = "Pulse" }
	local tagged = 0
	for _, inst in ipairs(CollectionService:GetTagged("Interactable")) do
		if inst:IsDescendantOf(workspace.Map) then
			local t = inst:GetAttribute("InteractType")
			local id
			if t == "Shop" and byShop[inst:GetAttribute("ShopId")] then
				id = byShop[inst:GetAttribute("ShopId")]
			elseif t == "Shop" and inst:GetAttribute("ShopId") == "ClubBar" then
				local mdl = inst:FindFirstAncestorWhichIsA("Model")
				id = mdl and byClub[mdl.Name]
			elseif t == "VenueDoor" and byClub[inst:GetAttribute("Link") or ""] and inst:GetAttribute("Side") == "Out" then
				id = byClub[inst:GetAttribute("Link")]
			elseif t == "Dealer" then
				id = inst:GetAttribute("DealerId") == "Luxury" and "BayfrontPrestige" or "SawgrassMotors"
			elseif t == "Tuning" then
				local anc = inst:FindFirstAncestorWhichIsA("Model")
				local n = anc and anc.Name or ""
				id = (n == "AutoRepairTuning" and "AutoRepair") or (n == "BayfrontPrestige" and "BayfrontPrestige") or (n == "SawgrassMotorsDealer" and "SawgrassMotors") or nil
			end
			if id then
				inst:SetAttribute("BusinessId", id)
				tagged += 1
			end
		end
	end
	table.insert(log, "BusinessId gesetzt: " .. tagged)
	-- Bueros (Kiosk "BUSINESS") am Standort: naechster passender Bestandspunkt
	local offices = folder(root, "BusinessOffices")
	local function anchorFor(def)
		local best, bd
		local target = Vector3.new(def.X, 0, def.Z)
		for _, inst in ipairs(CollectionService:GetTagged("Interactable")) do
			if inst:IsA("BasePart") and inst:IsDescendantOf(workspace.Map) and inst.Position.X < 4000 then
				local t = inst:GetAttribute("InteractType")
				local match = inst:GetAttribute("BusinessId") == def.Id
					or (def.Link.Property and t == "Property" and inst:GetAttribute("BuildingId") == "BayfrontOne")
					or (def.Link.Job and t == "WorkDepot" and inst:GetAttribute("JobId") == def.Link.Job)
					or (def.Link.ShopIds and t == "VenueDoor" and inst:GetAttribute("Side") == "Out" and (inst:GetAttribute("Link") == def.Id))
					or (def.Link.Dealer == "Luxury" and t == "VenueDoor" and inst:GetAttribute("Link") == "Prestige" and inst:GetAttribute("Side") == "Out")
				if match then
					local d = (inst.Position - target).Magnitude
					if not bd or d < bd then
						best, bd = inst, d
					end
				end
			end
		end
		if not best and def.Link.StoreNames then
			for _, mk2 in ipairs(CollectionService:GetTagged("StoreEntrance")) do
				if mk2:IsA("BasePart") and table.find(def.Link.StoreNames, mk2:GetAttribute("StoreName")) then
					local d = (mk2.Position - target).Magnitude
					if not bd or d < bd then
						best, bd = mk2, d
					end
				end
			end
		end
		return best
	end
	local placed = 0
	for _, def in ipairs(Work.Businesses) do
		local a = anchorFor(def)
		if a then
			local look = a.CFrame.LookVector
			look = Vector3.new(look.X, 0, look.Z)
			if look.Magnitude < 0.1 then
				look = Vector3.new(0, 0, 1)
			end
			look = look.Unit
			local right = look:Cross(Vector3.new(0, 1, 0))
			local pos = a.Position + right * 9 + look * 3
			local gy = groundY(pos.X, pos.Z)
			local cf = CFrame.lookAt(Vector3.new(pos.X, gy, pos.Z), Vector3.new(pos.X, gy, pos.Z) + look)
			kiosk(offices, "Office_" .. def.Id, cf, rgb(150, 110, 220), "BUSINESS")
			interact(offices, "OfficeInteract_" .. def.Id, cf * CFrame.new(0, 2.6, -1.6), "BusinessOffice", "Unternehmen", def.Name, { BusinessId = def.Id })
			placed += 1
		else
			table.insert(log, "WARN kein Standort fuer " .. def.Id)
		end
	end
	table.insert(log, "Bueros: " .. placed .. "/" .. #Work.Businesses)
	local _ = Kit
	return table.concat(log, " | ")
end
