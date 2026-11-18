-- ShopKit (Prompt 08): macht aus einem massiven Ladenblock (Store_* mit Body/Door/Display/Sign) einen begehbaren Laden.
-- * Aussenansicht bleibt: Obergeschoss-Block, Schild, Markise bleiben; die Front wird zu echten Schaufenstern + Glastuer.
-- * Innen: Boden, Wandverkleidung, Decke mit Licht, Einrichtung je Ladentyp, Kasse (Interaktion), Verkaeufer-NPC.
-- * Nur zur Bearbeitungszeit benutzen (ServerStorage.MapBuildTools). Aufruf: ShopKit.convert(storeModel, spec)
--   spec = { Kind = "Supermarket"|"Hardware"|"Clothing"|"GunStore"|"LongGuns"|"Jeweler", ShopId, Name (neuer Schildtext) }
local CollectionService = game:GetService("CollectionService")
local ShopKit = {}
local M = Enum.Material
local rgb = Color3.fromRGB

local function mk(parent, name, size, cf, color, mat, o)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if o then
		if o.t then p.Transparency = o.t end
		if o.ghost then p.CanCollide = false end
		if o.decor then p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false end
		if o.refl then p.Reflectance = o.refl end
		if o.shape then p.Shape = o.shape end
	end
	p.Parent = parent
	return p
end

-- Innenraum-Farben je Typ
local STYLE = {
	Supermarket = { floor = rgb(226, 224, 216), fmat = M.Marble, wall = rgb(240, 240, 236), light = rgb(250, 252, 255) },
	Hardware = { floor = rgb(150, 150, 146), fmat = M.Concrete, wall = rgb(214, 210, 200), light = rgb(255, 248, 235) },
	Clothing = { floor = rgb(186, 160, 128), fmat = M.WoodPlanks, wall = rgb(244, 238, 230), light = rgb(255, 238, 214) },
	GunStore = { floor = rgb(70, 72, 76), fmat = M.Slate, wall = rgb(196, 192, 182), light = rgb(255, 244, 226) },
	LongGuns = { floor = rgb(120, 86, 58), fmat = M.WoodPlanks, wall = rgb(150, 112, 78), wmat = M.Wood, light = rgb(255, 226, 180) },
	Jeweler = { floor = rgb(226, 220, 210), fmat = M.Marble, wall = rgb(92, 66, 50), wmat = M.Wood, light = rgb(255, 240, 214) },
	Bank = { floor = rgb(214, 208, 196), fmat = M.Marble, wall = rgb(232, 226, 212), light = rgb(255, 246, 230) },
	-- Essen & Trinken
	Market = { floor = rgb(214, 212, 204), fmat = M.Marble, wall = rgb(236, 236, 230), light = rgb(250, 252, 255) },
	Cafe = { floor = rgb(150, 108, 74), fmat = M.WoodPlanks, wall = rgb(238, 226, 206), light = rgb(255, 226, 180) },
	Bakery = { floor = rgb(200, 170, 130), fmat = M.WoodPlanks, wall = rgb(246, 236, 218), light = rgb(255, 232, 196) },
	Diner = { floor = rgb(232, 232, 228), fmat = M.Marble, wall = rgb(214, 70, 64), light = rgb(255, 240, 220) },
}

-- Sicherung des Originalblocks (Body/Door/Display) -> ShopKit.revert(model) stellt den Ursprung wieder her
local function backupFolder()
	local ss = game:GetService("ServerStorage")
	local f = ss:FindFirstChild("ShopKitBackup")
	if not f then
		f = Instance.new("Folder")
		f.Name = "ShopKitBackup"
		f.Parent = ss
	end
	return f
end

function ShopKit.revert(model)
	local id = model:GetAttribute("ShopKitId")
	local bk = id and backupFolder():FindFirstChild(id)
	if not bk then
		return false, "keine Sicherung"
	end
	for _, n in ipairs({ "Shell", "Interior", "Gameplay" }) do
		local x = model:FindFirstChild(n)
		if x then x:Destroy() end
	end
	for _, c in ipairs(bk:GetChildren()) do
		if c:IsA("BasePart") then
			c:Clone().Parent = model
		end
	end
	for k, v in pairs(bk:GetAttributes()) do
		if k == "ModelName" then model.Name = v end
		if k == "StoreName" then
			local e = model:FindFirstChild("StoreEntrance")
			if e then e:SetAttribute("StoreName", v) end
			local sign = model:FindFirstChild("Sign")
			local lbl = sign and sign:FindFirstChildWhichIsA("TextLabel", true)
			if lbl then lbl.Text = v end
		end
	end
	for _, a in ipairs({ "WalkIn", "ShopId", "RobberyReady", "JewelCases", "ShopKitId" }) do
		model:SetAttribute(a, nil)
	end
	bk:Destroy()
	return true
end

function ShopKit.convert(model, spec)
	local body, door = model:FindFirstChild("Body"), model:FindFirstChild("Door")
	assert(body and door, "Body/Door fehlt: " .. model:GetFullName())
	local st = STYLE[spec.Kind]
	-- Ausrichtung: Front = Seite der Tuer (Normalenrichtung der duennen Tuerachse)
	local n = door.CFrame.LookVector * Vector3.new(1, 0, 1)
	if n.Magnitude < 0.1 then n = Vector3.new(0, 0, -1) end
	n = n.Unit
	if n:Dot(door.Position - body.Position) < 0 then n = -n end
	-- auf Koerperachse runden
	local bx, bz = body.CFrame.RightVector, -body.CFrame.LookVector
	local function snap(v)
		local c = { bx, -bx, bz, -bz }
		local best, bd = c[1], -2
		for _, a in ipairs(c) do local d = a:Dot(v) if d > bd then best, bd = a, d end end
		return best
	end
	n = snap(n)
	local alongX = math.abs(n:Dot(bx)) > 0.9
	local W = alongX and body.Size.Z or body.Size.X
	local D = alongX and body.Size.X or body.Size.Z
	local H = body.Size.Y
	local ground = body.Position.Y - H / 2
	local back = -n
	local right = Vector3.yAxis:Cross(back)
	local cf = CFrame.fromMatrix(Vector3.new(body.Position.X, ground, body.Position.Z), right, Vector3.yAxis, back)
	local IH = math.min(H - 0.6, 13)
	local wallColor, wallMat = body.Color, body.Material
	local du = cf:PointToObjectSpace(door.Position).X -- Tuerposition quer zur Front

	local shell = Instance.new("Model") shell.Name = "Shell"
	local I = Instance.new("Model") I.Name = "Interior"
	local G = Instance.new("Model") G.Name = "Gameplay"
	local function P(parent, name, size, x, y, z, color, mat, o, rot)
		return mk(parent, name, size, cf * CFrame.new(x, y, z) * (rot or CFrame.new()), color, mat, o)
	end
	local FL = 0.4 -- Bodenoberkante (lokal)
	local zf, zb = -D / 2, D / 2 -- Front / Rueckwand (lokal)
	-- grosse Bloecke: Verkaufsraum nur vorn (max. 34 Studs tief), dahinter Lager (geschlossen)
	local Di = math.min(D, spec.MaxDepth or 34)
	local zIn = (Di < D - 1) and (zf + Di) or (zb - 0.8) -- Innenseite der (inneren) Rueckwand
	if Di < D - 1 then
		Di = zIn - zf
	end

	-- Rohbau
	if H - IH > 0.2 then
		P(shell, "UpperBlock", Vector3.new(W, H - IH, D), 0, IH + (H - IH) / 2, 0, wallColor, wallMat)
	end
	P(shell, "Floor", Vector3.new(W - 1.6, FL, D - 1.6), 0, FL / 2, 0, st.floor, st.fmat)
	P(shell, "BackWall", Vector3.new(W, IH, 0.8), 0, IH / 2, zb - 0.4, wallColor, wallMat)
	P(shell, "SideWallL", Vector3.new(0.8, IH, D), -W / 2 + 0.4, IH / 2, 0, wallColor, wallMat)
	P(shell, "SideWallR", Vector3.new(0.8, IH, D), W / 2 - 0.4, IH / 2, 0, wallColor, wallMat)
	-- Innenverkleidung + Decke
	local ic = st.wall
	if zIn < zb - 1 then
		P(shell, "InnerBackWall", Vector3.new(W - 1.6, IH, 0.8), 0, IH / 2, zIn + 0.4, wallColor, wallMat)
	end
	local liningLen = (zIn - 0.1) - (zf + 0.9)
	local liningMid = (zIn - 0.1 + zf + 0.9) / 2
	P(I, "LiningBack", Vector3.new(W - 1.8, IH - FL, 0.2), 0, FL + (IH - FL) / 2, zIn - 0.1, ic, st.wmat or M.SmoothPlastic)
	P(I, "LiningL", Vector3.new(0.2, IH - FL, liningLen), -W / 2 + 0.9, FL + (IH - FL) / 2, liningMid, ic, st.wmat or M.SmoothPlastic)
	P(I, "LiningR", Vector3.new(0.2, IH - FL, liningLen), W / 2 - 0.9, FL + (IH - FL) / 2, liningMid, ic, st.wmat or M.SmoothPlastic)
	P(I, "Ceiling", Vector3.new(W - 1.6, 0.2, D - 1.6), 0, IH - 0.1, 0, rgb(240, 238, 232), M.SmoothPlastic)
	-- Front: Pfeiler, Bruestung, Schaufenster, Tuer, Sturz
	local doorW, doorH, sill, winTop = 7.2, 9.2, 1.4, 9.2
	local d0, d1 = du - doorW / 2, du + doorW / 2
	local frame = rgb(40, 42, 46)
	P(shell, "FrontHeader", Vector3.new(W, IH - winTop, 0.8), 0, winTop + (IH - winTop) / 2, zf + 0.4, wallColor, wallMat)
	local function frontSegment(a, b)
		if b - a < 0.5 then return end
		local mid, len = (a + b) / 2, b - a
		P(shell, "Sill", Vector3.new(len, sill, 0.8), mid, sill / 2, zf + 0.4, wallColor, wallMat)
		P(shell, "ShopWindow", Vector3.new(len, winTop - sill, 0.3), mid, sill + (winTop - sill) / 2, zf + 0.4, rgb(170, 200, 215), M.Glass, { t = 0.55, refl = 0.15 })
		-- Sprossen
		local n2 = math.max(1, math.floor(len / 7))
		for i = 0, n2 do
			local x = a + len * i / n2
			P(shell, "Mullion", Vector3.new(0.35, winTop, 0.5), x, winTop / 2, zf + 0.4, frame, M.Metal)
		end
	end
	frontSegment(-W / 2, d0)
	frontSegment(d1, W / 2)
	-- Glas-Schiebetuer (offen begehbar)
	P(shell, "DoorFrameTop", Vector3.new(doorW, 0.4, 0.6), du, doorH, zf + 0.4, frame, M.Metal)
	P(shell, "SlidingDoorL", Vector3.new(doorW / 2, doorH - 0.2, 0.15), du - doorW / 2 - 0.6, (doorH - 0.2) / 2, zf + 0.75, rgb(180, 210, 220), M.Glass, { t = 0.6, ghost = true })
	P(shell, "SlidingDoorR", Vector3.new(doorW / 2, doorH - 0.2, 0.15), du + doorW / 2 + 0.6, (doorH - 0.2) / 2, zf + 0.75, rgb(180, 210, 220), M.Glass, { t = 0.6, ghost = true })
	P(shell, "Doormat", Vector3.new(doorW - 1, 0.05, 3), du, FL + 0.03, zf + 2.4, rgb(50, 52, 58), M.Fabric, { decor = true })
	-- Licht
	local rows = math.max(1, math.floor((Di - 4) / 12))
	local cols = math.max(1, math.floor(W / 24))
	for i = 1, rows * cols do
		local ri, ci = (i - 1) % rows, math.floor((i - 1) / rows)
		local z = zf + 2 + (Di - 4) * (ri + 0.5) / rows
		local lx = -W / 2 + W * (ci + 0.5) / cols
		local lamp = P(I, "CeilingLight", Vector3.new(math.min(W / cols - 6, 16), 0.15, 1.2), lx, IH - 0.28, z, st.light, M.Neon, { decor = true })
		local sl = Instance.new("SurfaceLight")
		sl.Face = Enum.NormalId.Bottom
		sl.Brightness = spec.Kind == "Jeweler" and 2 or 1.4
		sl.Range = 16
		sl.Angle = 110
		sl.Color = st.light
		sl.Shadows = false
		sl.Parent = lamp
	end
	-- alte Front/Block sichern und entfernen
	local id = game:GetService("HttpService"):GenerateGUID(false)
	local bk = Instance.new("Folder")
	bk.Name = id
	bk:SetAttribute("ModelName", model.Name)
	local entry0 = model:FindFirstChild("StoreEntrance")
	bk:SetAttribute("StoreName", entry0 and entry0:GetAttribute("StoreName") or "")
	for _, nme in ipairs({ "Body", "Door", "Display" }) do
		local x = model:FindFirstChild(nme)
		if x then
			x:Clone().Parent = bk
			x:Destroy()
		end
	end
	bk.Parent = backupFolder()
	model:SetAttribute("ShopKitId", id)

	-- Einrichtung
	local ctx = { cf = cf, W = W, D = Di, IH = IH, FL = FL, zf = zf, zb = zIn + 0.8, du = du, P = P, I = I, G = G, model = model, spec = spec }
	-- Theke + Kasse: auf der tuerabgewandten Seite nahe der Front
	local side = (du > 0) and -1 or 1
	ctx.side = side
	local cx = side * (W / 2 - 4.5)
	local cz = zf + 6
	ctx.counter = Vector3.new(cx, 0, cz)
	ShopKit.Fixtures[spec.Kind](ctx)
	if spec.NoRegister then
		shell.Parent, I.Parent, G.Parent = model, model, model
		model:SetAttribute("WalkIn", true)
		return model, cf
	end
	local counterColor = (spec.Kind == "Jeweler") and rgb(36, 32, 30) or (spec.Kind == "LongGuns" and rgb(96, 66, 42) or rgb(52, 56, 64))
	P(I, "Counter", Vector3.new(3, 3.6, 7), cx, FL + 1.8, cz, counterColor, spec.Kind == "LongGuns" and M.Wood or M.SmoothPlastic)
	P(I, "CounterTop", Vector3.new(3.4, 0.2, 7.4), cx, FL + 3.7, cz, spec.Kind == "Jeweler" and rgb(230, 225, 215) or rgb(200, 200, 196), M.Marble)
	local reg = P(G, "Register", Vector3.new(1.2, 0.9, 1.4), cx, FL + 4.25, cz - 1.8, rgb(30, 30, 34), M.SmoothPlastic)
	P(I, "RegisterScreen", Vector3.new(0.1, 0.8, 1.1), cx - side * 0.3, FL + 5.1, cz - 1.8, rgb(60, 200, 230), M.Neon, { decor = true })
	reg:SetAttribute("InteractType", "Shop")
	reg:SetAttribute("ShopId", spec.ShopId)
	reg:SetAttribute("InteractText", spec.InteractText or (spec.Kind == "Jeweler" and "Ausstellung ansehen" or "Einkaufen"))
	reg:SetAttribute("ObjectText", spec.Title or spec.Name or "Laden")
	reg:SetAttribute("Range", 9)
	CollectionService:AddTag(reg, "Interactable")
	-- Verkaeufer hinter der Theke
	local tpl = workspace.Map.Hospital.Interior:FindFirstChild("Hospital Receptionist")
	if tpl then
		local npc = tpl:Clone()
		npc.Name = "Verkaeufer"
		local pos = cf * Vector3.new(cx + side * 2.6, 0, cz)
		local look = cf * Vector3.new(cx - side * 10, 0, cz)
		local hrp = npc:FindFirstChild("HumanoidRootPart")
		local hip = hrp and (hrp.Size.Y / 2 + npc.Humanoid.HipHeight) or 3
		npc:PivotTo(CFrame.lookAt(pos + Vector3.new(0, FL + hip, 0), Vector3.new(look.X, pos.Y + FL + hip, look.Z)))
		npc.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		npc.Parent = G
	end
	shell.Parent, I.Parent, G.Parent = model, model, model
	-- Schild / Marker umbenennen
	if spec.Name then
		local sign = model:FindFirstChild("Sign")
		local lbl = sign and sign:FindFirstChildWhichIsA("TextLabel", true)
		if lbl then lbl.Text = spec.Name end
		local entry = model:FindFirstChild("StoreEntrance")
		if entry then entry:SetAttribute("StoreName", spec.Name) end
		local poi = model:FindFirstChild("MapPOI")
		if poi then poi:SetAttribute("Name", spec.Name) end
		model.Name = "Store_" .. spec.Name:gsub("[^%w]", "")
	end
	model:SetAttribute("WalkIn", true)
	model:SetAttribute("ShopId", spec.ShopId)
	return model, cf
end

-- Einrichtung je Typ ------------------------------------------------------------------------------
ShopKit.Fixtures = {}
local F = ShopKit.Fixtures

local function rnd(seed)
	return Random.new(seed or 7)
end

-- Regal mit Ware (Laenge entlang lokal Z)
local function gondola(c, x, z0, z1, rng, palette)
	local P, I, FL = c.P, c.I, c.FL
	local len = z1 - z0
	local zc = (z0 + z1) / 2
	P(I, "Shelf", Vector3.new(1.8, 0.6, len), x, FL + 0.3, zc, rgb(210, 210, 206), M.Metal)
	P(I, "ShelfSpine", Vector3.new(0.3, 5.2, len), x, FL + 2.6, zc, rgb(200, 200, 196), M.Metal)
	-- Ware in einzelnen Produktbloecken (abwechslungsreich, gedaempfte Farben, ohne Kollision)
	local seg = 2.4
	local nseg = math.max(1, math.floor((len - 0.4) / seg))
	local sl = (len - 0.4) / nseg
	for lvl = 0, 3 do
		local y = FL + 0.6 + lvl * 1.45
		if lvl > 0 then
			P(I, "ShelfBoard", Vector3.new(1.8, 0.12, len), x, y, zc, rgb(220, 220, 216), M.Metal)
		end
		for sideX = -1, 1, 2 do
			for k = 0, nseg - 1 do
				local h = rng:NextNumber(0.55, 1.0)
				local col = palette[rng:NextInteger(1, #palette)]
				P(I, "Goods", Vector3.new(0.6, h, sl - 0.25), x + sideX * 0.55, y + 0.06 + h / 2, z0 + 0.2 + sl * (k + 0.5), col, M.SmoothPlastic, { decor = true })
			end
		end
	end
end

F.Supermarket = function(c)
	local P, I, FL, W, D, zf, zb = c.P, c.I, c.FL, c.W, c.D, c.zf, c.zb
	local rng = rnd(11)
	local pal = { rgb(196, 78, 66), rgb(222, 184, 92), rgb(84, 136, 186), rgb(108, 160, 104), rgb(214, 132, 72), rgb(232, 228, 214), rgb(136, 96, 140), rgb(180, 150, 110) }
	-- Kuehlregal an der Rueckwand
	P(I, "FridgeBody", Vector3.new(W - 4, 7, 2), 0, FL + 3.5, zb - 2, rgb(225, 228, 232), M.Metal)
	P(I, "FridgeGlass", Vector3.new(W - 4.4, 5.6, 0.15), 0, FL + 3.6, zb - 3.05, rgb(190, 225, 240), M.Glass, { t = 0.5 })
	P(I, "FridgeLight", Vector3.new(W - 4.6, 0.15, 0.3), 0, FL + 6.6, zb - 3.0, rgb(230, 245, 255), M.Neon, { decor = true })
	for i = 1, 3 do
		P(I, "FridgeGoods", Vector3.new(W - 5, 0.8, 1.2), 0, FL + 0.9 + i * 1.6, zb - 2.2, pal[rng:NextInteger(1, #pal)], M.SmoothPlastic, { decor = true })
	end
	-- Regalreihen
	local z0, z1 = zf + 11, zb - 5.5
	local x = -W / 2 + 4
	while x < W / 2 - 3 do
		if not (math.abs(x - c.counter.X) < 4 and z0 < c.counter.Z + 5) then
			gondola(c, x, z0, z1, rng, pal)
		end
		x += 6.5
	end
	-- Obst-/Aktionsstand vorn
	P(I, "PromoTable", Vector3.new(5, 2.6, 3), -c.side * 3, FL + 1.3, zf + 7, rgb(120, 80, 50), M.Wood)
	P(I, "PromoFruit", Vector3.new(4.6, 0.6, 2.6), -c.side * 3, FL + 2.9, zf + 7, rgb(250, 150, 40), M.SmoothPlastic, { decor = true })
	P(I, "BasketStack", Vector3.new(1.6, 1.6, 1.2), c.side * (c.W / 2 - 2), FL + 0.8, zf + 11.5, rgb(220, 40, 40), M.SmoothPlastic)
end

-- Kleiner Markt: wie Supermarkt (Regale, Kuehlregal, Obststand)
F.Market = function(c)
	F.Supermarket(c)
end

-- Bistrotisch mit zwei Stuehlen (Mitte x, z)
local function bistro(c, x, z, top, wood)
	local P, I, FL = c.P, c.I, c.FL
	P(I, "TableTop", Vector3.new(2.8, 0.2, 2.8), x, FL + 2.6, z, top or rgb(236, 232, 224), M.Marble)
	P(I, "TableLeg", Vector3.new(0.3, 2.4, 0.3), x, FL + 1.3, z, rgb(40, 40, 44), M.Metal)
	P(I, "TableFoot", Vector3.new(1.4, 0.15, 1.4), x, FL + 0.08, z, rgb(40, 40, 44), M.Metal)
	for s = -1, 1, 2 do
		P(I, "ChairSeat", Vector3.new(1.6, 0.25, 1.6), x + s * 2.3, FL + 1.6, z, wood or rgb(120, 84, 56), M.Wood)
		P(I, "ChairBack", Vector3.new(0.25, 1.9, 1.6), x + s * 3.05, FL + 2.6, z, wood or rgb(120, 84, 56), M.Wood)
		P(I, "ChairLegs", Vector3.new(0.3, 1.5, 0.3), x + s * 2.3, FL + 0.75, z, rgb(40, 40, 44), M.Metal)
	end
end

-- Tafel mit Text an der Rueckwand
local function menuBoard(c, x, y, z, w, text, bg, fg)
	local b = c.P(c.I, "MenuBoard", Vector3.new(w, 3, 0.2), x, y, z, bg or rgb(28, 30, 28), M.SmoothPlastic, { decor = true })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0.2
	sg.Parent = b
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = fg or rgb(245, 236, 210)
	t.Text = text
	t.Parent = sg
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.06, 0), UDim.new(0.06, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.18, 0), UDim.new(0.18, 0)
	pad.Parent = t
	return b
end

-- Tische im Gastraum verteilen (frei: Kasse vorn an der Seite, Weg von der Tuer)
local function seating(c, z0, z1, top, wood)
	local W = c.W
	local x = -W / 2 + 5
	while x <= W / 2 - 5 do
		local z = z0
		while z <= z1 do
			local nearCounter = math.abs(x - c.counter.X) < 6 and z < c.counter.Z + 6
			local inDoorPath = math.abs(x - c.du) < 3 and z < c.zf + 10
			if not nearCounter and not inDoorPath then
				bistro(c, x, z, top, wood)
			end
			z += 6.5
		end
		x += 8.5
	end
end

local function plant(c, x, z)
	local P, I, FL = c.P, c.I, c.FL
	P(I, "PlantPot", Vector3.new(1.6, 1.8, 1.6), x, FL + 0.9, z, rgb(190, 110, 70), M.SmoothPlastic)
	P(I, "PlantLeaves", Vector3.new(2.6, 2.6, 2.6), x, FL + 3, z, rgb(70, 140, 70), M.Grass, { decor = true, shape = Enum.PartType.Ball })
end

F.Cafe = function(c)
	local P, I, FL, W, zf, zb = c.P, c.I, c.FL, c.W, c.zf, c.zb
	local rng = rnd(31)
	-- Bar an der Rueckwand mit Siebtraeger-Maschine, Muehle, Kuchenvitrine
	P(I, "BackBar", Vector3.new(W - 4, 3.6, 2.2), 0, FL + 1.8, zb - 2.1, rgb(110, 74, 48), M.Wood)
	P(I, "BackBarTop", Vector3.new(W - 3.8, 0.2, 2.4), 0, FL + 3.7, zb - 2.1, rgb(232, 228, 220), M.Marble)
	P(I, "EspressoMachine", Vector3.new(2.8, 1.8, 1.4), -W / 4, FL + 4.7, zb - 2.2, rgb(196, 198, 204), M.Metal)
	P(I, "EspressoAccent", Vector3.new(2.9, 0.3, 1.5), -W / 4, FL + 5.5, zb - 2.2, rgb(180, 40, 40), M.SmoothPlastic, { decor = true })
	P(I, "Grinder", Vector3.new(0.8, 1.6, 0.8), -W / 4 + 2.4, FL + 4.6, zb - 2.2, rgb(40, 40, 44), M.Metal, { decor = true })
	P(I, "Vitrine", Vector3.new(4.2, 1.5, 1.7), W / 4, FL + 4.55, zb - 2.1, rgb(210, 235, 245), M.Glass, { t = 0.45 })
	local cake = { rgb(240, 200, 150), rgb(120, 70, 40), rgb(240, 150, 170), rgb(250, 240, 220), rgb(200, 140, 70) }
	for i = -2, 2 do
		P(I, "Pastry", Vector3.new(0.6, 0.35, 0.6), W / 4 + i * 0.75, FL + 4.1, zb - 2.1, cake[rng:NextInteger(1, #cake)], M.SmoothPlastic, { decor = true })
	end
	-- Regal mit Tassen und Kaffeebohnen ueber der Bar
	P(I, "CupShelf", Vector3.new(W - 6, 0.2, 1), 0, FL + 7.2, zb - 1.3, rgb(110, 74, 48), M.Wood)
	for i = 1, math.floor((W - 8) / 1.4) do
		P(I, "Cup", Vector3.new(0.5, 0.6, 0.5), -W / 2 + 4 + i * 1.4, FL + 7.6, zb - 1.3, (i % 3 == 0) and rgb(64, 160, 150) or rgb(245, 245, 240), M.SmoothPlastic, { decor = true })
	end
	menuBoard(c, 0, FL + 9.6, zb - 0.95, math.min(W - 8, 14), "ESPRESSO  \u{00B7}  CAPPUCCINO  \u{00B7}  ICED COFFEE\nCROISSANT  \u{00B7}  DONUT  \u{00B7}  SMOOTHIE")
	-- Gastraum
	seating(c, zf + 9, zb - 7.5)
	plant(c, -W / 2 + 2.2, zb - 5.5)
	plant(c, W / 2 - 2.2, zb - 5.5)
	-- warme Haengelampen
	for i = -1, 1 do
		local lamp = P(I, "PendantLamp", Vector3.new(1.2, 0.8, 1.2), i * W / 4, c.IH - 2.2, (zf + zb) / 2, rgb(255, 214, 150), M.Neon, { decor = true, shape = Enum.PartType.Ball })
		local pl = Instance.new("PointLight")
		pl.Range, pl.Brightness, pl.Color, pl.Shadows = 14, 0.8, rgb(255, 214, 160), false
		pl.Parent = lamp
		P(I, "PendantCord", Vector3.new(0.1, 1.8, 0.1), i * W / 4, c.IH - 1.1, (zf + zb) / 2, rgb(30, 30, 30), M.SmoothPlastic, { decor = true })
	end
end

F.Bakery = function(c)
	local P, I, FL, W, zf, zb = c.P, c.I, c.FL, c.W, c.zf, c.zb
	local rng = rnd(41)
	-- Brotregal an der Rueckwand
	P(I, "BreadShelf", Vector3.new(W - 4, 7, 1.6), 0, FL + 3.5, zb - 1.6, rgb(150, 104, 66), M.Wood)
	local bread = { rgb(196, 140, 74), rgb(170, 110, 56), rgb(220, 176, 110), rgb(140, 86, 44) }
	for lvl = 0, 3 do
		local y = FL + 1.2 + lvl * 1.6
		P(I, "BreadBoard", Vector3.new(W - 4.2, 0.15, 1.8), 0, y, zb - 2.2, rgb(170, 122, 80), M.Wood)
		for i = 1, math.floor((W - 6) / 1.6) do
			P(I, "Loaf", Vector3.new(1.2, 0.6, 0.8), -W / 2 + 3 + i * 1.6, y + 0.4, zb - 2.3, bread[rng:NextInteger(1, #bread)], M.SmoothPlastic, { decor = true })
		end
	end
	-- Theke mit Glasvitrine
	P(I, "PastryCounter", Vector3.new(W - 8, 3.4, 2), 0, FL + 1.7, zb - 6, rgb(240, 232, 216), M.SmoothPlastic)
	P(I, "PastryGlass", Vector3.new(W - 8, 1.6, 2), 0, FL + 4.2, zb - 6, rgb(210, 235, 245), M.Glass, { t = 0.45 })
	local cake = { rgb(240, 200, 150), rgb(240, 150, 170), rgb(250, 240, 220), rgb(200, 140, 70), rgb(120, 70, 40) }
	for i = 1, math.floor((W - 10) / 1.1) do
		P(I, "Pastry", Vector3.new(0.7, 0.4, 0.7), -W / 2 + 5 + i * 1.1, FL + 3.65, zb - 6, cake[rng:NextInteger(1, #cake)], M.SmoothPlastic, { decor = true })
	end
	menuBoard(c, 0, FL + 9.8, zb - 0.95, math.min(W - 8, 12), "FRISCHES BROT  \u{00B7}  CROISSANTS  \u{00B7}  DONUTS", rgb(60, 40, 28))
	seating(c, zf + 9, zb - 10, rgb(250, 248, 240), rgb(170, 120, 80))
	plant(c, -W / 2 + 2.2, zf + 9)
end

F.Diner = function(c)
	local P, I, FL, W, zf, zb = c.P, c.I, c.FL, c.W, c.zf, c.zb
	-- Bartresen mit Hockern an der Rueckwand
	P(I, "DinerBar", Vector3.new(W - 6, 3.6, 2.2), 0, FL + 1.8, zb - 4, rgb(200, 205, 210), M.Metal)
	P(I, "DinerBarTop", Vector3.new(W - 5.8, 0.25, 2.6), 0, FL + 3.7, zb - 4, rgb(214, 70, 64), M.SmoothPlastic)
	for i = 1, math.floor((W - 8) / 3) do
		local x = -W / 2 + 4 + i * 3
		P(I, "StoolSeat", Vector3.new(1.4, 0.4, 1.4), x, FL + 2.6, zb - 6.2, rgb(214, 70, 64), M.Fabric, { shape = Enum.PartType.Cylinder })
		P(I, "StoolPost", Vector3.new(0.3, 2.4, 0.3), x, FL + 1.2, zb - 6.2, rgb(200, 205, 210), M.Metal)
	end
	P(I, "Kitchen", Vector3.new(W - 4, 1, 1.4), 0, FL + 5, zb - 1.4, rgb(200, 205, 210), M.Metal)
	menuBoard(c, 0, FL + 9.4, zb - 0.95, math.min(W - 8, 14), "PANCAKES  \u{00B7}  BURGER  \u{00B7}  FRIES  \u{00B7}  MILKSHAKES", rgb(30, 34, 40), rgb(255, 220, 120))
	-- Sitznischen an der kassenabgewandten Seitenwand
	local sx = -c.side * (W / 2 - 3.2)
	local z = zf + 9
	while z < zb - 10 do
		P(I, "BoothTable", Vector3.new(3, 0.25, 2.6), sx, FL + 2.6, z, rgb(240, 240, 236), M.Marble)
		P(I, "BoothTableLeg", Vector3.new(0.4, 2.4, 0.4), sx, FL + 1.3, z, rgb(200, 205, 210), M.Metal)
		for s = -1, 1, 2 do
			P(I, "BoothSeat", Vector3.new(3.4, 1.6, 1.4), sx, FL + 0.8, z + s * 2.2, rgb(214, 70, 64), M.Fabric)
			P(I, "BoothBack", Vector3.new(3.4, 2.4, 0.5), sx, FL + 2.8, z + s * 2.75, rgb(214, 70, 64), M.Fabric)
		end
		z += 6.5
	end
	-- Tische in der Mitte
	local c2 = setmetatable({ W = W * 0.5 }, { __index = c })
	seating(c2, zf + 10, zb - 11, rgb(240, 240, 236), rgb(214, 70, 64))
end

F.Hardware = function(c)
	local P, I, FL, W, D, zf, zb = c.P, c.I, c.FL, c.W, c.D, c.zf, c.zb
	local rng = rnd(23)
	local pal = { rgb(206, 120, 48), rgb(70, 72, 78), rgb(170, 58, 52), rgb(214, 182, 64), rgb(72, 108, 160), rgb(140, 140, 136), rgb(96, 100, 92) }
	-- Lochwand mit Werkzeug an der Rueckwand
	P(I, "Pegboard", Vector3.new(W - 4, 6, 0.2), 0, FL + 4, zb - 1.15, rgb(170, 130, 90), M.Wood)
	for i = 1, math.floor((W - 6) / 2.2) do
		local x = -W / 2 + 3 + i * 2.2
		P(I, "HangingTool", Vector3.new(0.3, rng:NextNumber(1.2, 2.4), 0.2), x, FL + rng:NextNumber(3, 5.5), zb - 1.35, pal[rng:NextInteger(1, #pal)], M.Metal, { decor = true })
	end
	-- Regale mit Kisten
	local x = -W / 2 + 4
	while x < W / 2 - 3 do
		if not (math.abs(x - c.counter.X) < 4) then
			gondola(c, x, zf + 11, zb - 4, rng, pal)
		end
		x += 6.5
	end
	-- Werkzeugkasten-Tisch
	P(I, "DisplayTable", Vector3.new(4, 2.4, 3), -c.side * 3, FL + 1.2, zf + 7, rgb(80, 82, 88), M.Metal)
	for i = -1, 1 do
		P(I, "ToolboxDisplay", Vector3.new(1.1, 0.8, 1.6), -c.side * 3 + i * 1.3, FL + 2.8, zf + 7, rgb(200, 40, 40), M.Metal, { decor = true })
	end
	P(I, "LadderDisplay", Vector3.new(0.3, 6, 1.6), c.side * (c.W / 2 - 1.4), FL + 3, zf + 13, rgb(180, 180, 176), M.Metal)
end

F.Clothing = function(c)
	local P, I, FL, W, D, zf, zb = c.P, c.I, c.FL, c.W, c.D, c.zf, c.zb
	local rng = rnd(37)
	local pal = { rgb(238, 238, 234), rgb(30, 31, 36), rgb(232, 120, 104), rgb(28, 128, 136), rgb(34, 48, 86), rgb(150, 210, 186), rgb(220, 204, 170), rgb(196, 176, 140), rgb(230, 110, 150) }
	-- Kleiderstaender
	local function rack(x, z)
		P(I, "RackPost", Vector3.new(0.2, 5, 0.2), x - 2, FL + 2.5, z, rgb(180, 160, 120), M.Metal)
		P(I, "RackPost", Vector3.new(0.2, 5, 0.2), x + 2, FL + 2.5, z, rgb(180, 160, 120), M.Metal)
		P(I, "RackBar", Vector3.new(4.2, 0.15, 0.15), x, FL + 4.9, z, rgb(180, 160, 120), M.Metal)
		for i = 0, 4 do
			P(I, "Garment", Vector3.new(0.35, 2.4, 1.4), x - 1.6 + i * 0.8, FL + 3.6, z, pal[rng:NextInteger(1, #pal)], M.Fabric, { decor = true })
		end
	end
	local zs = zf + 10
	while zs < zb - 8 do
		for _, x in ipairs({ -W / 4, W / 4 }) do
			if not (math.abs(x - c.counter.X) < 5 and zs < c.counter.Z + 6) then
				rack(x, zs)
			end
		end
		zs += 6
	end
	-- Wandregal mit gefalteter Ware
	for i = 0, 3 do
		P(I, "WallShelf", Vector3.new(W - 6, 0.15, 1.4), 0, FL + 2 + i * 1.6, zb - 1.7, rgb(210, 190, 160), M.Wood)
		P(I, "FoldedStack", Vector3.new(W - 7, 0.6, 1.1), 0, FL + 2.4 + i * 1.6, zb - 1.7, pal[rng:NextInteger(1, #pal)], M.Fabric, { decor = true })
	end
	-- Schaufensterpuppen hinter dem Fenster
	for i, x in ipairs({ -W / 2 + 4, W / 2 - 4 }) do
		if math.abs(x - c.du) > 5 then
			P(I, "MannequinBase", Vector3.new(1.6, 0.3, 1.6), x, FL + 0.15, zf + 2.6, rgb(40, 40, 44), M.Metal)
			P(I, "MannequinLegs", Vector3.new(1.2, 2.6, 0.6), x, FL + 1.6, zf + 2.6, pal[i + 5], M.Fabric)
			P(I, "MannequinTorso", Vector3.new(1.8, 2.2, 0.9), x, FL + 4, zf + 2.6, pal[i + 2], M.Fabric)
			P(I, "MannequinHead", Vector3.new(0.9, 1, 0.9), x, FL + 5.6, zf + 2.6, rgb(235, 232, 226), M.SmoothPlastic)
		end
	end
	-- Umkleiden an der Rueckwand (Seite)
	for i = 0, 1 do
		local x = -c.side * (W / 2 - 3 - i * 4)
		P(I, "FittingWall", Vector3.new(0.2, 7, 3.6), x - 2, FL + 3.5, zb - 3.6, rgb(230, 225, 215), M.SmoothPlastic)
		P(I, "FittingCurtain", Vector3.new(3.6, 6.4, 0.1), x, FL + 3.4, zb - 5.4, rgb(120, 40, 60), M.Fabric, { ghost = true })
	end
	P(I, "Mirror", Vector3.new(3, 6, 0.1), c.side * (W / 2 - 1.05), FL + 3.5, zb - 10, rgb(220, 230, 235), M.Glass, { refl = 0.6 })
end

-- Lange \"Waffen-Silhouette\" (Dekoration, kein funktionsfaehiges Modell)
local function wallItem(c, x, y, z, long, color)
	local P, I = c.P, c.I
	if long then
		P(I, "DisplayItem", Vector3.new(4.2, 0.35, 0.2), x, y, z, color or rgb(40, 42, 46), M.Metal, { decor = true })
		P(I, "DisplayItemStock", Vector3.new(1.4, 0.6, 0.2), x + 2.2, y - 0.15, z, rgb(110, 74, 46), M.Wood, { decor = true })
	else
		P(I, "DisplayItem", Vector3.new(1.2, 0.35, 0.2), x, y, z, color or rgb(40, 42, 46), M.Metal, { decor = true })
		P(I, "DisplayItemGrip", Vector3.new(0.3, 0.6, 0.2), x + 0.4, y - 0.4, z, rgb(30, 30, 34), M.SmoothPlastic, { decor = true })
	end
end

F.GunStore = function(c)
	local P, I, FL, W, D, zf, zb = c.P, c.I, c.FL, c.W, c.D, c.zf, c.zb
	-- Rueckwand: Lamellenwand mit Ausstellungsstuecken, davor Glasvitrinen-Theke
	P(I, "SlatWall", Vector3.new(W - 4, 6.5, 0.2), 0, FL + 4.4, zb - 1.15, rgb(60, 62, 66), M.SmoothPlastic)
	for row = 0, 2 do
		for i = 0, math.floor((W - 8) / 3) do
			wallItem(c, -W / 2 + 4 + i * 3, FL + 2.6 + row * 1.9, zb - 1.35, false)
		end
	end
	local caseZ = zb - 5
	P(I, "CaseBase", Vector3.new(W - 8, 3, 2.4), 0, FL + 1.5, caseZ, rgb(46, 48, 54), M.SmoothPlastic)
	P(I, "CaseGlass", Vector3.new(W - 8, 1.2, 2.4), 0, FL + 3.6, caseZ, rgb(200, 220, 230), M.Glass, { t = 0.65 })
	for k = 0, math.max(1, math.floor((W - 8) / 7)) do
		local holder = P(I, "CaseSpot", Vector3.new(0.5, 0.1, 0.5), -W / 2 + 5 + k * 7, c.IH - 0.4, caseZ, rgb(240, 236, 228), M.Metal, { decor = true })
		local sp = Instance.new("SpotLight")
		sp.Face, sp.Color, sp.Brightness, sp.Range, sp.Angle, sp.Shadows = Enum.NormalId.Bottom, rgb(255, 244, 226), 1.6, 12, 60, false
		sp.Parent = holder
	end
	for i = 0, math.floor((W - 10) / 2.4) do
		P(I, "CaseItem", Vector3.new(1.1, 0.25, 0.6), -W / 2 + 5 + i * 2.4, FL + 3.15, caseZ, rgb(36, 38, 42), M.Metal, { decor = true })
	end
	-- Zubehoerregal an der Seitenwand
	local sx = -c.side * (W / 2 - 1.8)
	for i = 0, 3 do
		P(I, "AccessoryShelf", Vector3.new(1.8, 0.12, D - 14), sx, FL + 1 + i * 1.5, 1, rgb(80, 82, 88), M.Metal)
		P(I, "AccessoryBoxes", Vector3.new(1.4, 0.7, D - 15), sx, FL + 1.45 + i * 1.5, 1, ({ rgb(140, 120, 70), rgb(60, 70, 60), rgb(30, 30, 34), rgb(120, 40, 30) })[i + 1], M.SmoothPlastic, { decor = true })
	end
	-- Hinweisschild Waffenschein
	P(I, "LicenseSign", Vector3.new(4, 1.2, 0.15), c.counter.X, FL + 7, c.counter.Z + 3.6, rgb(200, 120, 60), M.SmoothPlastic, { decor = true })
end

F.LongGuns = function(c)
	local P, I, FL, W, D, zf, zb = c.P, c.I, c.FL, c.W, c.D, c.zf, c.zb
	-- Holzwand mit Langwaffen-Rack
	for row = 0, 3 do
		P(I, "RackRail", Vector3.new(W - 6, 0.25, 0.4), 0, FL + 2.2 + row * 1.6, zb - 1.3, rgb(90, 60, 38), M.Wood)
		for i = 0, math.floor((W - 10) / 5) do
			wallItem(c, -W / 2 + 6 + i * 5, FL + 2.6 + row * 1.6, zb - 1.55, true)
		end
	end
	-- Theke vor dem Rack
	P(I, "RackCounter", Vector3.new(W - 10, 3.4, 2.6), 0, FL + 1.7, zb - 6, rgb(110, 76, 48), M.Wood)
	P(I, "RackCounterTop", Vector3.new(W - 9.6, 0.25, 3), 0, FL + 3.5, zb - 6, rgb(70, 50, 34), M.Wood)
	-- Regale mit Outdoor-Ausruestung (Mitte)
	local rng = rnd(53)
	local earth = { rgb(84, 96, 62), rgb(120, 100, 70), rgb(60, 64, 52), rgb(150, 130, 96), rgb(96, 70, 48), rgb(176, 120, 60) }
	local gx = -W / 2 + 8
	while gx < W / 2 - 6 do
		if math.abs(gx - c.counter.X) > 6 and math.abs(gx - c.du) > 5 then
			gondola(c, gx, zf + 17, zb - 10, rng, earth)
		end
		gx += 9
	end
	-- Ausstellungstische mit Zubehoer (Taschen, Koffer)
	for i, x in ipairs({ -W / 4, 0, W / 4 }) do
		if math.abs(x - c.counter.X) > 6 then
			P(I, "Table", Vector3.new(5, 2.6, 3.4), x, FL + 1.3, zf + 13, rgb(96, 66, 42), M.Wood)
			P(I, "CaseDisplay", Vector3.new(3.6, 0.8, 1.6), x, FL + 3, zf + 13, ({ rgb(40, 50, 40), rgb(70, 60, 40), rgb(30, 30, 30) })[i], M.Fabric, { decor = true })
		end
	end
	-- Geweih-Trophaee + Tarnfarben-Banner
	P(I, "TrophyPlate", Vector3.new(2, 2, 0.3), -c.side * (W / 2 - 1.2), FL + 8.5, 0, rgb(80, 54, 34), M.Wood, nil, CFrame.Angles(0, math.rad(90), 0))
	for s = -1, 1, 2 do
		P(I, "Antler", Vector3.new(0.25, 1.8, 0.25), -c.side * (W / 2 - 1.5), FL + 9.6, s * 0.6, rgb(210, 196, 170), M.SmoothPlastic, { decor = true }, CFrame.Angles(s * 0.5, 0, 0))
	end
	P(I, "CamoBanner", Vector3.new(0.15, 3, 10), c.side * (W / 2 - 1.05), FL + 7.5, zb - 14, rgb(84, 96, 62), M.Fabric, { decor = true })
end

-- Alarmlampe (Ueberfall): aus = dunkelrot, Crime-Client schaltet sie bei Alarm blinkend
local function alarmLamp(c, heistId, x, y, z)
	local lamp = c.P(c.G, "AlarmLight", Vector3.new(1.2, 0.5, 1.2), x, y, z, rgb(110, 20, 24), M.SmoothPlastic, { decor = true })
	lamp:SetAttribute("HeistId", heistId)
	CollectionService:AddTag(lamp, "HeistAlarmLight")
	local pl = Instance.new("PointLight")
	pl.Color, pl.Range, pl.Brightness, pl.Shadows, pl.Enabled = rgb(255, 40, 40), 18, 2, false, false
	pl.Parent = lamp
	return lamp
end
ShopKit.AlarmLamp = alarmLamp

-- Ueberfallbereich (unsichtbar, keine Kollision)
local function heistZone(c, heistId, x, z, w, d)
	local zone = c.P(c.G, "HeistZone", Vector3.new(w, c.IH - c.FL, d), x, c.FL + (c.IH - c.FL) / 2, z, rgb(255, 0, 0), M.SmoothPlastic, { t = 1, decor = true })
	zone:SetAttribute("HeistId", heistId)
	CollectionService:AddTag(zone, "HeistZone")
	return zone
end

F.Bank = function(c)
	local P, I, G, FL, W, D, zf, zb = c.P, c.I, c.G, c.FL, c.W, c.D, c.zf, c.zb
	local gold, wood = rgb(212, 176, 96), rgb(96, 66, 44)
	-- Schalterhalle: durchgehender Schalter mit Glastrennwand und 3 Schaltern
	local cz = zf + 11
	-- Schalter mit Durchgang (Schwingtuer) auf der Seite gegenueber der Eingangstuer
	local passSide = (c.du > 0) and -1 or 1
	local cw = W - 11
	local cx = -passSide * 2.5
	P(I, "TellerCounter", Vector3.new(cw, 3.6, 2.4), cx, FL + 1.8, cz, wood, M.Wood)
	P(I, "TellerTop", Vector3.new(cw + 0.4, 0.2, 2.8), cx, FL + 3.7, cz, rgb(236, 230, 220), M.Marble)
	P(I, "TellerGlass", Vector3.new(cw, 3.6, 0.15), cx, FL + 5.6, cz + 0.6, rgb(200, 220, 230), M.Glass, { t = 0.65 })
	P(I, "SwingGate", Vector3.new(4.2, 3, 0.2), passSide * (W / 2 - 3.3), FL + 1.5, cz, wood, M.Wood, { ghost = true, t = 0.1 })
	for i = -1, 1 do
		local tx = cx + i * cw / 3
		P(I, "TellerSign", Vector3.new(2.2, 0.6, 0.1), tx, FL + 7.7, cz + 0.6, rgb(30, 50, 80), M.SmoothPlastic, { decor = true })
		P(I, "TellerMonitor", Vector3.new(1.4, 1, 0.15), tx, FL + 4.4, cz + 1.2, rgb(40, 60, 70), M.Glass, { decor = true })
	end
	P(I, "GoldTrim", Vector3.new(cw + 0.2, 0.15, 0.1), cx, FL + 3.4, cz - 1.25, gold, M.Metal, { decor = true })
	-- Wartebereich
	for _, x in ipairs({ -W / 2 + 4, W / 2 - 4 }) do
		if math.abs(x - c.du) > 5 then
			P(I, "Bench", Vector3.new(1.6, 1.6, 6), x, FL + 0.8, zf + 6, rgb(60, 50, 44), M.Leather)
			P(I, "Plant", Vector3.new(1.6, 3.4, 1.6), x, FL + 1.7, zf + 2.4, rgb(70, 130, 70), M.LeafyGrass)
		end
	end
	-- Geldautomat im Foyer
	local atmX = (c.du > 0) and (-W / 2 + 1.6) or (W / 2 - 1.6)
	local atm = P(G, "ATM", Vector3.new(1.4, 6, 2.6), atmX, FL + 3, zf + 8, rgb(60, 66, 76), M.Metal)
	atm:SetAttribute("InteractType", "ATM")
	atm:SetAttribute("InteractText", "Geldautomat")
	atm:SetAttribute("ObjectText", "Miami State Bank")
	CollectionService:AddTag(atm, "Interactable")
	-- Tresorraum hinten: Trennwand mit Oeffnung, runde Tresortuer (offen), Schliessfaecher, Geldwagen
	local vz = zb - 9 -- Trennwand
	local gap = 5
	local half = (W - 1.6) / 2
	local segW = half - gap / 2
	P(c.I, "VaultWall", Vector3.new(segW, c.IH - FL, 1.2), -(gap / 2 + segW / 2), FL + (c.IH - FL) / 2, vz, rgb(150, 150, 146), M.Concrete)
	P(c.I, "VaultWall", Vector3.new(segW, c.IH - FL, 1.2), (gap / 2 + segW / 2), FL + (c.IH - FL) / 2, vz, rgb(150, 150, 146), M.Concrete)
	P(c.I, "VaultLintel", Vector3.new(gap, c.IH - FL - 7.5, 1.2), 0, FL + 7.5 + (c.IH - FL - 7.5) / 2, vz, rgb(150, 150, 146), M.Concrete)
	P(c.I, "VaultDoor", Vector3.new(1.2, 8, 8), gap / 2 + 4.2, FL + 4, vz - 3.5, rgb(170, 172, 178), M.DiamondPlate, { shape = Enum.PartType.Cylinder }, CFrame.Angles(0, math.rad(65), 0))
	P(c.I, "VaultDoorWheel", Vector3.new(0.4, 3, 3), gap / 2 + 3.2, FL + 4, vz - 4.2, gold, M.Metal, { shape = Enum.PartType.Cylinder, decor = true }, CFrame.Angles(0, math.rad(65), 0))
	P(c.I, "DepositBoxes", Vector3.new(W - 4, 7, 0.8), 0, FL + 3.8, zb - 1.3, rgb(176, 178, 184), M.DiamondPlate)
	for i = 0, 5 do
		P(I, "BoxRow", Vector3.new(W - 4.2, 0.12, 0.1), 0, FL + 0.9 + i * 1.15, zb - 1.75, rgb(90, 92, 98), M.Metal, { decor = true })
	end
	for _, x in ipairs({ -W / 4, W / 4 }) do
		P(I, "MoneyCart", Vector3.new(3, 2, 2), x, FL + 1.4, zb - 4.5, rgb(80, 84, 90), M.Metal)
		P(I, "MoneyStacks", Vector3.new(2.6, 0.8, 1.6), x, FL + 2.8, zb - 4.5, rgb(96, 150, 96), M.SmoothPlastic, { decor = true })
	end
	P(I, "VaultSign", Vector3.new(4, 0.8, 0.1), 0, FL + 8.4, vz - 0.65, rgb(30, 40, 60), M.SmoothPlastic, { decor = true })
	-- Bedienfeld neben dem Tresor: startet den Ueberfall (abstrakte Haltezeit)
	local panel = P(G, "VaultPanel", Vector3.new(1.2, 1.8, 0.3), -(gap / 2 + 1.4), FL + 4.4, vz - 0.75, rgb(30, 32, 36), M.SmoothPlastic)
	P(I, "VaultPanelLed", Vector3.new(0.8, 0.3, 0.1), -(gap / 2 + 1.4), FL + 5, vz - 0.95, rgb(60, 220, 80), M.Neon, { decor = true })
	panel:SetAttribute("InteractType", "HeistStart")
	panel:SetAttribute("HeistId", "Bank")
	panel:SetAttribute("InteractText", "Tresor-Ueberfall starten")
	panel:SetAttribute("ObjectText", "Tresor Miami State Bank")
	panel:SetAttribute("HoldDuration", 3)
	panel:SetAttribute("Range", 8)
	CollectionService:AddTag(panel, "Interactable")
	heistZone(c, "Bank", 0, (vz + zb) / 2, W - 2.4, zb - vz - 1)
	for _, x in ipairs({ -W / 4, W / 4 }) do
		alarmLamp(c, "Bank", x, c.IH - 0.5, cz - 3)
	end
	alarmLamp(c, "Bank", 0, c.IH - 0.5, (vz + zb) / 2)
	for s = -1, 1, 2 do
		P(I, "SecurityCam", Vector3.new(0.6, 0.6, 1.2), s * (W / 2 - 2), c.IH - 0.9, zf + 2, rgb(230, 230, 230), M.SmoothPlastic, { decor = true })
	end
end

F.Jeweler = function(c)
	local P, I, G, FL, W, D, zf, zb = c.P, c.I, c.G, c.FL, c.W, c.D, c.zf, c.zb
	local gold, silver = rgb(222, 184, 92), rgb(214, 216, 222)
	local cases = 0
	-- frei stehende Vitrinen (Ziel fuer spaetere Raubueberfaelle: Tag "JewelCase")
	local function vitrine(x, z, w)
		cases += 1
		local base = P(I, "VitrineBase", Vector3.new(w, 3, 2.2), x, FL + 1.5, z, rgb(36, 32, 30), M.Wood)
		P(I, "VitrineTrim", Vector3.new(w + 0.1, 0.12, 2.3), x, FL + 3.0, z, rgb(212, 176, 96), M.Metal, { decor = true })
		local glass = P(G, "JewelCase", Vector3.new(w, 1.4, 2.2), x, FL + 3.7, z, rgb(210, 225, 235), M.Glass, { t = 0.7, refl = 0.1 })
		glass:SetAttribute("CaseId", cases)
		glass:SetAttribute("Value", 2500 + cases * 750)
		glass:SetAttribute("Robbable", true)
		glass:SetAttribute("Looted", false)
		CollectionService:AddTag(glass, "JewelCase")
		-- Ueberfall (Prompt 09): abstrakte Interaktion mit Haltezeit, Pruefung im CrimeService
		glass:SetAttribute("InteractType", "HeistLoot")
		glass:SetAttribute("HeistId", "Jeweler")
		glass:SetAttribute("InteractText", "Vitrine ausraeumen")
		glass:SetAttribute("ObjectText", "Vitrine")
		glass:SetAttribute("HoldDuration", 3.5)
		glass:SetAttribute("Range", 7)
		CollectionService:AddTag(glass, "Interactable")
		local spot = Instance.new("PointLight")
		spot.Color, spot.Brightness, spot.Range, spot.Shadows = rgb(255, 244, 222), 1.2, 7, false
		spot.Parent = glass
		for i = 0, math.floor(w / 1.1) - 1 do
			local col = (i % 2 == 0) and gold or silver
			P(I, "Jewel", Vector3.new(0.5, 0.25, 0.5), x - w / 2 + 0.7 + i * 1.1, FL + 3.15, z, col, M.Foil, { decor = true, refl = 0.3 })
		end
	end
	vitrine(-W / 4, zf + 11, 5)
	vitrine(W / 4, zf + 11, 5)
	vitrine(0, zf + 16, 6)
	-- Wandvitrinen
	for s = -1, 1, 2 do
		if math.abs(s * (W / 2 - 2) - c.counter.X) > 3 then
			P(I, "WallCase", Vector3.new(1.6, 5, D - 16), s * (W / 2 - 1.8), FL + 4, 2, rgb(24, 22, 28), M.SmoothPlastic)
			P(I, "WallCaseGlass", Vector3.new(0.1, 4, D - 16.4), s * (W / 2 - 2.65), FL + 4.2, 2, rgb(210, 225, 235), M.Glass, { t = 0.7 })
			for k = -1, 1 do
				local holder = P(I, "WallCaseSpot", Vector3.new(0.4, 0.1, 0.4), s * (W / 2 - 1.9), FL + 6.4, 2 + k * (D - 18) / 3, rgb(240, 236, 228), M.Metal, { decor = true })
				local pl = Instance.new("SpotLight")
				pl.Face, pl.Color, pl.Brightness, pl.Range, pl.Angle, pl.Shadows = Enum.NormalId.Bottom, rgb(255, 240, 214), 2, 8, 70, false
				pl.Parent = holder
			end
		end
	end
	-- Tresor und Alarmanlage (technische Vorbereitung Raubueberfall)
	local vault = P(G, "JewelerVault", Vector3.new(4, 5.6, 0.6), 0, FL + 2.8, zb - 1.3, rgb(120, 124, 130), M.DiamondPlate)
	P(I, "VaultWheel", Vector3.new(0.3, 1.6, 1.6), 0, FL + 3, zb - 1.7, silver, M.Metal, { shape = Enum.PartType.Cylinder, decor = true }, CFrame.Angles(0, math.rad(90), 0))
	vault:SetAttribute("Locked", true)
	CollectionService:AddTag(vault, "JewelerVault")
	local alarm = P(G, "JewelerAlarm", Vector3.new(1, 1.4, 0.2), c.side * (W / 2 - 1.05), FL + 6, zf + 3, rgb(40, 40, 44), M.SmoothPlastic)
	P(I, "AlarmLed", Vector3.new(0.25, 0.25, 0.1), c.side * (W / 2 - 1.15), FL + 6.4, zf + 3, rgb(60, 220, 80), M.Neon, { decor = true })
	alarm:SetAttribute("Armed", true)
	CollectionService:AddTag(alarm, "JewelerAlarm")
	for s = -1, 1, 2 do
		P(I, "SecurityCam", Vector3.new(0.6, 0.6, 1.2), s * (W / 2 - 2), c.IH - 0.9, zb - 2, rgb(230, 230, 230), M.SmoothPlastic, { decor = true })
	end
	-- Teppichlaeufer
	P(I, "Runner", Vector3.new(4, 0.05, D - 6), c.du, FL + 0.03, 0, rgb(110, 20, 34), M.Fabric, { decor = true })
	-- Schaufensterauslage hinter der Glasfront (Podeste mit Schmuck und Spots)
	for _, x in ipairs({ -W / 2 + 4, W / 2 - 4 }) do
		if math.abs(x - c.du) > 5 then
			P(I, "WindowPlinth", Vector3.new(3.2, 2.4, 2), x, FL + 1.2, zf + 2.2, rgb(240, 236, 228), M.Marble)
			P(I, "WindowBust", Vector3.new(1, 1.6, 0.6), x, FL + 3.2, zf + 2.2, rgb(36, 32, 30), M.Fabric, { decor = true })
			P(I, "WindowNecklace", Vector3.new(0.9, 0.15, 0.1), x, FL + 3.4, zf + 1.85, gold, M.Foil, { decor = true, refl = 0.3 })
			for k = -1, 1, 2 do
				P(I, "Jewel", Vector3.new(0.4, 0.2, 0.4), x + k * 1, FL + 2.5, zf + 2.2, (k > 0) and gold or silver, M.Foil, { decor = true, refl = 0.3 })
			end
			local spotH = P(I, "WindowSpot", Vector3.new(0.4, 0.1, 0.4), x, c.IH - 0.4, zf + 2.2, rgb(240, 236, 228), M.Metal, { decor = true })
			local sp = Instance.new("SpotLight")
			sp.Face, sp.Color, sp.Brightness, sp.Range, sp.Angle, sp.Shadows = Enum.NormalId.Bottom, rgb(255, 242, 220), 2.5, 14, 50, false
			sp.Parent = spotH
		end
	end
	-- Pflanzen + Ueberfallbereich + Alarmlampen
	P(I, "Plant", Vector3.new(1.4, 3.6, 1.4), -c.side * (W / 2 - 2), FL + 1.8, zb - 3, rgb(70, 130, 70), M.LeafyGrass)
	heistZone(c, "Jeweler", 0, 1, W - 3, D - 4)
	alarmLamp(c, "Jeweler", -W / 4, c.IH - 0.5, 0)
	alarmLamp(c, "Jeweler", W / 4, c.IH - 0.5, 0)
	c.model:SetAttribute("RobberyReady", true)
	c.model:SetAttribute("JewelCases", cases)
end

return ShopKit
