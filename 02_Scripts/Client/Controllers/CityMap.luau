-- Stadtkarte (Taste V / Handy-App "Karte") und Navigation.
-- Gemeinsame Datenquelle fuer Karte und Minimap: MapGeo (generiert aus der Welt, Schritt 22) + MapData.
-- Navigation: Routensuche (A*) im Strassengraph, Neuberechnung bei Abweichung, Zielmarker in der Welt.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local M = {}
local ctxRef
local screen, viewport, canvas, routeLayer, playerDot, info, scaleObj
local zoom, pan = 1, Vector2.zero
local BASE = 0.25 -- Pixel pro Stud im Kartenmassstab 1
local renderConn

-- Farben (Kartenstil, dunkel)
local COL = {
	Water = Color3.fromRGB(16, 38, 58), Land = Color3.fromRGB(30, 36, 44), Green = Color3.fromRGB(38, 70, 48),
	Lot = Color3.fromRGB(48, 52, 60), Street = Color3.fromRGB(150, 156, 170), Highway = Color3.fromRGB(240, 196, 90),
	Building = Color3.fromRGB(64, 72, 88), Tall = Color3.fromRGB(84, 96, 120), Route = Color3.fromRGB(80, 200, 255),
}

-- Geometrie ------------------------------------------------------------------------------------------
local function geo()
	return ctxRef.Config.MapGeo
end
local function bounds()
	return ctxRef.Config.MapData.Bounds
end
function M.ToMap(x, z, s)
	local B = bounds()
	return Vector2.new((x - B.X0) * s, (z - B.Z0) * s)
end

-- Rechteck (Weltmitte, Breite lokal X, Laenge lokal Z, Drehung um Y in Grad) als Frame
local function rect(parent, cx, cz, w, l, rot, color, s, z)
	local r = rot % 180
	local frameRot = 0
	if r < 4 or r > 176 then
		-- achsparallel
	elseif math.abs(r - 90) < 4 then
		w, l = l, w
	else
		frameRot = -rot
	end
	local p = M.ToMap(cx, cz, s)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(p.X, p.Y)
	f.Size = UDim2.fromOffset(math.max(1, w * s), math.max(1, l * s))
	f.Rotation = frameRot
	f.BackgroundColor3 = color
	f.ZIndex = z
	f.Parent = parent
	return f
end

-- Zeichnet die statischen Ebenen in einen Container (Massstab s). opts.minimal = Minimap (weniger Ebenen)
function M.Build(container, s, opts)
	opts = opts or {}
	local G, D = geo(), ctxRef.Config.MapData
	local B = bounds()
	container.Size = UDim2.fromOffset((B.X1 - B.X0) * s, (B.Z1 - B.Z0) * s)
	container.BackgroundColor3 = COL.Water
	container.BackgroundTransparency = 0
	-- Festland (alles westlich der Bucht) und Inseln als Landflaeche, Palmetto Bay bleibt Wasser
	local land = rect(container, (B.X0 + 1000) / 2, (B.Z0 + B.Z1) / 2, 1000 - B.X0, B.Z1 - B.Z0, 0, COL.Land, s, 1)
	land.Name = "Mainland"
	for _, d in ipairs(D.Districts) do
		if d.Name ~= "Palmetto Bay" and d.X0 >= 1000 then
			local f = rect(container, (d.X0 + d.X1) / 2, (d.Z0 + d.Z1) / 2, d.X1 - d.X0, d.Z1 - d.Z0, 0, COL.Land, s, 1)
			f.Name = "District"
		end
	end
	if not G then
		return
	end
	for _, g in ipairs(G.Green) do
		rect(container, g[1], g[2], g[3], g[4], g[5], COL.Green, s, 2)
	end
	for _, g in ipairs(G.Lots) do
		rect(container, g[1], g[2], g[3], g[4], g[5], COL.Lot, s, 2)
	end
	for _, g in ipairs(G.Roads) do
		local col = (g[6] == "Highway" or g[6] == "Ramp") and COL.Highway or COL.Street
		rect(container, g[1], g[2], g[3], g[4], g[5], col, s, (g[6] == "Highway" or g[6] == "Ramp") and 4 or 3)
	end
	for _, g in ipairs(G.Buildings) do
		if not opts.minimal or g[3] * g[4] > 900 then
			rect(container, g[1], g[2], g[3], g[4], g[5], (g[6] or 0) > 60 and COL.Tall or COL.Building, s, 5)
		end
	end
	if not opts.minimal then
		for _, d in ipairs(D.Districts) do
			local p = M.ToMap((d.X0 + d.X1) / 2, (d.Z0 + d.Z1) / 2, s)
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.AnchorPoint = Vector2.new(0.5, 0.5)
			t.Position = UDim2.fromOffset(p.X, p.Y)
			t.Size = UDim2.fromOffset(300, 30)
			t.Font = Enum.Font.GothamBlack
			t.TextSize = 22
			t.TextColor3 = d.Color
			t.TextTransparency = 0.35
			t.TextStrokeTransparency = 0.6
			t.Text = d.Name:upper()
			t.ZIndex = 6
			t.Name = "DistrictLabel"
			t.Parent = container
		end
	end
end

-- Marker-Symbol (Emoji im farbigen Kreis)
function M.Icon(parent, cat, size, z)
	local f = Instance.new("TextButton")
	f.AutoButtonColor = false
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundColor3 = cat.Color
	f.Text = cat.Icon
	f.TextSize = math.floor(size * 0.62)
	f.Font = Enum.Font.GothamBold
	f.TextColor3 = Color3.new(1, 1, 1)
	f.ZIndex = z or 20
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
	local st = Instance.new("UIStroke")
	st.Color = Color3.new(1, 1, 1)
	st.Thickness = 1.5
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = f
	f.Parent = parent
	return f
end

-- Linienzug (Route) als duenne gedrehte Frames
function M.DrawPolyline(layer, points, s, color, width, z)
	layer:ClearAllChildren()
	for i = 1, #points - 1 do
		local a, b = M.ToMap(points[i].X, points[i].Z, s), M.ToMap(points[i + 1].X, points[i + 1].Z, s)
		local d = b - a
		local len = d.Magnitude
		if len > 0.5 then
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
			f.Size = UDim2.fromOffset(len + width, width)
			f.Rotation = math.deg(math.atan2(d.Y, d.X))
			f.BackgroundColor3 = color
			f.ZIndex = z or 15
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(1, 0)
			c.Parent = f
			f.Parent = layer
		end
	end
end

-- Navigation -------------------------------------------------------------------------------------------
local Nav = { Target = nil, Label = nil, Route = {}, Changed = Instance.new("BindableEvent") }
M.Nav = Nav
local adj, comp, mainComp
local worldMarker

local function buildGraph()
	if adj then
		return
	end
	local G = geo()
	adj, comp = {}, {}
	if not G then
		return
	end
	for i = 1, #G.Nodes do
		adj[i] = {}
	end
	for _, e in ipairs(G.Edges) do
		local a, b = G.Nodes[e[1]], G.Nodes[e[2]]
		local w = math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
		table.insert(adj[e[1]], { e[2], w })
		table.insert(adj[e[2]], { e[1], w })
	end
	-- Zusammenhangskomponenten (Routen nur innerhalb einer Komponente)
	local sizes, id = {}, 0
	for i = 1, #G.Nodes do
		if not comp[i] then
			id += 1
			local stack, n = { i }, 0
			comp[i] = id
			while #stack > 0 do
				local v = table.remove(stack)
				n += 1
				for _, e in ipairs(adj[v]) do
					if not comp[e[1]] then
						comp[e[1]] = id
						table.insert(stack, e[1])
					end
				end
			end
			sizes[id] = n
		end
	end
	local best = 0
	for cid, n in pairs(sizes) do
		if n > best then
			best, mainComp = n, cid
		end
	end
end

local function nearestNode(x, z, wantComp)
	local G = geo()
	local best, bd
	for i, n in ipairs(G.Nodes) do
		if not wantComp or comp[i] == wantComp then
			local d = (n[1] - x) ^ 2 + (n[2] - z) ^ 2
			if not bd or d < bd then
				best, bd = i, d
			end
		end
	end
	return best, bd and math.sqrt(bd) or math.huge
end

local function astar(s, t)
	local G = geo()
	local nodes = G.Nodes
	local function h(i)
		return math.sqrt((nodes[i][1] - nodes[t][1]) ^ 2 + (nodes[i][2] - nodes[t][2]) ^ 2)
	end
	local open, g, came, closed = { s }, { [s] = 0 }, {}, {}
	local f = { [s] = h(s) }
	local guard = 0
	while #open > 0 and guard < 20000 do
		guard += 1
		local bi, bv = 1, f[open[1]]
		for i = 2, #open do
			if f[open[i]] < bv then
				bi, bv = i, f[open[i]]
			end
		end
		local v = table.remove(open, bi)
		if v == t then
			local path = { t }
			while came[path[1]] do
				table.insert(path, 1, came[path[1]])
			end
			return path
		end
		closed[v] = true
		for _, e in ipairs(adj[v]) do
			local w = e[1]
			if not closed[w] then
				local ng = g[v] + e[2]
				if not g[w] or ng < g[w] then
					if not g[w] then
						table.insert(open, w)
					end
					g[w], came[w], f[w] = ng, v, ng + h(w)
				end
			end
		end
	end
	return nil
end

local function rootPos()
	local c = Players.LocalPlayer.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return r and r.Position
end

local function computeRoute()
	local from = rootPos()
	if not from or not Nav.Target then
		Nav.Route = {}
		return
	end
	buildGraph()
	local G = geo()
	local route = { Vector3.new(from.X, 0, from.Z) }
	if G and #G.Nodes > 0 then
		local tNode = nearestNode(Nav.Target.X, Nav.Target.Z, nil)
		local sNode = nearestNode(from.X, from.Z, comp[tNode])
		local path = (sNode and tNode) and astar(sNode, tNode)
		if path then
			for _, i in ipairs(path) do
				table.insert(route, Vector3.new(G.Nodes[i][1], 0, G.Nodes[i][2]))
			end
		end
	end
	table.insert(route, Vector3.new(Nav.Target.X, 0, Nav.Target.Z))
	Nav.Route = route
	Nav.Changed:Fire()
end

local function placeWorldMarker()
	if worldMarker then
		worldMarker:Destroy()
		worldMarker = nil
	end
	if not Nav.Target then
		return
	end
	local p = Instance.new("Part")
	p.Name = "MiamiNavTarget"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = Vector3.new(Nav.Target.X, (Nav.Target.Y or 0) + 8, Nav.Target.Z)
	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(140, 40)
	bb.Parent = p
	local t = Instance.new("TextLabel")
	t.Name = "Label"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = COL.Route
	t.BackgroundTransparency = 0.1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 13
	t.TextColor3 = Color3.fromRGB(10, 12, 18)
	t.Text = Nav.Label or "Ziel"
	t.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = t
	p.Parent = Workspace
	worldMarker = p
end

function Nav.SetTarget(x, z, label, y)
	Nav.Target = { X = x, Y = y, Z = z }
	Nav.Label = label
	computeRoute()
	placeWorldMarker()
	Nav.Changed:Fire()
	if ctxRef then
		ctxRef.UI.toast("Navigation: " .. tostring(label or "Wegpunkt"), "info")
	end
end

function Nav.Clear(silent)
	Nav.Target, Nav.Label, Nav.Route = nil, nil, {}
	placeWorldMarker()
	Nav.Changed:Fire()
	if ctxRef and not silent then
		ctxRef.UI.toast("Navigation beendet", "info")
	end
end

function Nav.Distance()
	local p = rootPos()
	if not p or not Nav.Target then
		return nil
	end
	return (Vector3.new(Nav.Target.X, p.Y, Nav.Target.Z) - p).Magnitude
end

-- Abweichung von der Route / Ankunft (alle 1.2 s)
local function navTick()
	if not Nav.Target then
		return
	end
	local p = rootPos()
	if not p then
		return
	end
	local dist = Nav.Distance()
	if dist and dist < 25 then
		Nav.Clear(true)
		ctxRef.UI.toast("Ziel erreicht", "success")
		return
	end
	-- vorderste Routenpunkte, die erreicht sind, entfernen
	local r = Nav.Route
	local flat = Vector3.new(p.X, 0, p.Z)
	local changed = false
	while #r > 2 and (r[2] - flat).Magnitude < 35 do
		table.remove(r, 1)
		changed = true
	end
	if #r >= 2 then
		r[1] = flat
		-- Abstand zum naechsten Segment
		local a, b = r[1], r[2]
		local off = (b - a).Magnitude
		if off > 160 and #r > 2 then
			-- deutlich vom Weg abgekommen: neu berechnen
			computeRoute()
			return
		end
	end
	if changed then
		Nav.Changed:Fire()
	end
	if worldMarker then
		worldMarker.BillboardGui.Label.Text = string.format("%s  %d m", Nav.Label or "Ziel", math.floor(dist * 0.28))
	end
end

-- Grosse Karte -------------------------------------------------------------------------------------------
function M.Close()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	if screen then
		screen.Enabled = false
	end
end

local function applyView()
	if not canvas then
		return
	end
	scaleObj.Scale = zoom
	local vs = viewport.AbsoluteSize
	local B = bounds()
	local w, h = (B.X1 - B.X0) * BASE * zoom, (B.Z1 - B.Z0) * BASE * zoom
	-- Verschieben begrenzen
	pan = Vector2.new(math.clamp(pan.X, math.min(0, vs.X - w), 0), math.clamp(pan.Y, math.min(0, vs.Y - h), 0))
	canvas.Position = UDim2.fromOffset(pan.X, pan.Y)
end

local function centerOn(x, z)
	local p = M.ToMap(x, z, BASE) * zoom
	local vs = viewport.AbsoluteSize
	pan = Vector2.new(vs.X / 2 - p.X, vs.Y / 2 - p.Y)
	applyView()
end

local function setZoom(nz, focus)
	local old = zoom
	zoom = math.clamp(nz, 0.35, 5)
	focus = focus or viewport.AbsoluteSize / 2
	-- Punkt unter dem Mauszeiger bleibt stehen
	pan = focus - (focus - pan) * (zoom / old)
	applyView()
end

local function showInfo(title, sub, x, z, y)
	local UI, T = ctxRef.UI, ctxRef.UI.Theme
	info:ClearAllChildren()
	info.Visible = true
	UI.pad(info, 12)
	UI.list(info, 6)
	UI.label(info, title, 17, { Font = T.FontBlack })
	local p = rootPos()
	local dist = p and (Vector3.new(x, p.Y, z) - p).Magnitude or 0
	UI.label(info, string.format("%s  -  %s  -  %d m", sub, ctxRef.Config.MapData.DistrictAt(x, z), math.floor(dist * 0.28)), 12, { TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 30), TextWrapped = true })
	local go = UI.button(info, "NAVIGATION STARTEN", "primary", { Size = UDim2.new(1, 0, 0, 34), TextSize = 13 })
	go.MouseButton1Click:Connect(function()
		Nav.SetTarget(x, z, title, y)
		info.Visible = false
	end)
	local close = UI.button(info, "Schliessen", "secondary", { Size = UDim2.new(1, 0, 0, 28), TextSize = 12 })
	close.MouseButton1Click:Connect(function()
		info.Visible = false
	end)
end

local hidden = {}
local function buildScreen()
	local UI, T = ctxRef.UI, ctxRef.UI.Theme
	local D = ctxRef.Config.MapData
	screen = UI.screen("MiamiCityMap", 25)
	local win = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -60, 1, -60), BackgroundColor3 = T.Panel, Parent = screen })
	UI.corner(win, 16)
	UI.stroke(win, T.Stroke)
	-- Kopfzeile
	local head = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -36, 0, 40), Parent = win })
	UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.5, 0, 1, 0), Font = T.FontBlack, TextSize = 22, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = "MIAMI STATE  -  STADTKARTE", Parent = head })
	local closeBtn = UI.button(head, "X", "secondary", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(36, 32), TextSize = 14 })
	closeBtn.MouseButton1Click:Connect(function()
		M.Close()
		ctxRef.Closed("CityMap")
	end)
	local stopNav = UI.button(head, "NAVIGATION BEENDEN", "danger", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -46, 0.5, 0), Size = UDim2.fromOffset(180, 32), TextSize = 12 })
	stopNav.MouseButton1Click:Connect(function()
		Nav.Clear()
	end)
	local function syncNavBtn()
		stopNav.Visible = Nav.Target ~= nil
	end
	Nav.Changed.Event:Connect(syncNavBtn)
	syncNavBtn()
	-- Kartenfenster
	viewport = UI.new("Frame", { Position = UDim2.fromOffset(18, 58), Size = UDim2.new(1, -300, 1, -76), BackgroundColor3 = Color3.fromRGB(16, 38, 58), ClipsDescendants = true, Active = true, Parent = win })
	UI.corner(viewport, 12)
	canvas = UI.new("Frame", { BorderSizePixel = 0, Parent = viewport })
	scaleObj = UI.new("UIScale", { Parent = canvas })
	M.Build(canvas, BASE)
	routeLayer = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 15, Parent = canvas })
	local poiLayer = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = canvas })
	local G = ctxRef.Config.MapGeo
	local iconsByCat = {}
	for _, p in ipairs(G and G.POI or {}) do
		local cat = D.Category(p[1])
		local pos = M.ToMap(p[3], p[4], BASE)
		local ic = M.Icon(poiLayer, cat, 22, 20)
		ic.Position = UDim2.fromOffset(pos.X, pos.Y)
		ic.MouseButton1Click:Connect(function()
			showInfo(p[2], cat.Name, p[3], p[4])
		end)
		iconsByCat[cat.Id] = iconsByCat[cat.Id] or {}
		table.insert(iconsByCat[cat.Id], ic)
	end
	-- Spielerpfeil (Blickrichtung)
	playerDot = UI.new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Font = T.FontBlack, TextSize = 24, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.2, Text = "▲", ZIndex = 30, Parent = canvas })
	local targetIcon = UI.new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(26, 30), BackgroundTransparency = 1, Font = T.FontBlack, TextSize = 26, TextColor3 = COL.Route, TextStrokeTransparency = 0.2, Text = "📍", ZIndex = 29, Visible = false, Parent = canvas })
	local function redrawRoute()
		M.DrawPolyline(routeLayer, Nav.Route, BASE, COL.Route, 5, 15)
		targetIcon.Visible = Nav.Target ~= nil
		if Nav.Target then
			local p = M.ToMap(Nav.Target.X, Nav.Target.Z, BASE)
			targetIcon.Position = UDim2.fromOffset(p.X, p.Y)
		end
	end
	Nav.Changed.Event:Connect(redrawRoute)
	redrawRoute()

	-- Seitenleiste: Legende mit Filtern, Zoom, Hinweise
	local side = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 58), Size = UDim2.new(0, 262, 1, -76), BackgroundTransparency = 1, Parent = win })
	UI.label(side, "LEGENDE (anklicken = ein/aus)", 12, { TextColor3 = T.Muted, Font = T.FontBold })
	local legend = UI.scroll(side, { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 1, -230) })
	UI.list(legend, 4)
	for _, cat in ipairs(D.POICategories) do
		local row = UI.new("TextButton", { AutoButtonColor = true, BackgroundColor3 = T.Panel2, Size = UDim2.new(1, -6, 0, 30), Text = "", Parent = legend })
		UI.corner(row, 8)
		local ic = M.Icon(row, cat, 22, 2)
		ic.Position = UDim2.fromOffset(18, 15)
		ic.Active = false
		local n = iconsByCat[cat.Id] and #iconsByCat[cat.Id] or 0
		local lbl = UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -40, 1, 0), Font = T.FontBold, TextSize = 12, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = cat.Name .. "  (" .. n .. ")", Parent = row })
		row.MouseButton1Click:Connect(function()
			hidden[cat.Id] = not hidden[cat.Id]
			for _, i in ipairs(iconsByCat[cat.Id] or {}) do
				i.Visible = not hidden[cat.Id]
			end
			lbl.TextTransparency = hidden[cat.Id] and 0.6 or 0
		end)
	end
	local zrow = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -196), Size = UDim2.new(1, 0, 0, 36), Parent = side })
	UI.list(zrow, 6, true)
	for _, z in ipairs({ { "−", 1 / 1.4 }, { "+", 1.4 }, { "Mich zeigen", 0 } }) do
		local b = UI.button(zrow, z[1], "secondary", { Size = UDim2.new(z[2] == 0 and 0.5 or 0.25, -4, 1, 0), TextSize = z[2] == 0 and 12 or 18 })
		b.MouseButton1Click:Connect(function()
			if z[2] == 0 then
				local p = rootPos()
				if p then
					setZoom(2)
					centerOn(p.X, p.Z)
				end
			else
				setZoom(zoom * z[2])
			end
		end)
	end
	UI.label(side, "Mausrad: Zoom  |  Ziehen: Verschieben\nKlick auf Symbol: Ort anzeigen\nKlick auf die Karte: eigener Wegpunkt", 11, { TextColor3 = T.Muted, Position = UDim2.new(0, 0, 1, -150), Size = UDim2.new(1, 0, 0, 52), TextWrapped = true })
	info = UI.new("Frame", { BackgroundColor3 = T.Panel2, Position = UDim2.new(0, 0, 1, -94), Size = UDim2.new(1, 0, 0, 160), AnchorPoint = Vector2.new(0, 0.5), Visible = false, Parent = side })
	UI.corner(info, 10)
	info.Position = UDim2.new(0, 0, 1, -80)
	info.AnchorPoint = Vector2.new(0, 1)

	-- Eingabe: Zoom (Mausrad), Ziehen, Klick fuer Wegpunkt
	local dragging, dragStart, panStart, moved = false, nil, nil, false
	viewport.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, moved = true, false
			dragStart, panStart = Vector2.new(input.Position.X, input.Position.Y), pan
		end
	end)
	viewport.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local m = UserInputService:GetMouseLocation() - viewport.AbsolutePosition - Vector2.new(0, game:GetService("GuiService"):GetGuiInset().Y)
			setZoom(zoom * (input.Position.Z > 0 and 1.25 or 0.8), m)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
			if delta.Magnitude > 4 then
				moved = true
			end
			pan = panStart + delta
			applyView()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if not moved and screen and screen.Enabled then
				-- Klick ohne Ziehen: Wegpunkt an dieser Stelle
				local local2 = Vector2.new(input.Position.X, input.Position.Y) - viewport.AbsolutePosition - pan
				local B = bounds()
				local wx = local2.X / (BASE * zoom) + B.X0
				local wz = local2.Y / (BASE * zoom) + B.Z0
				showInfo("Markierung", "Eigener Wegpunkt", wx, wz)
			end
		end
	end)
end

function M.Open(ctx)
	ctxRef = ctx
	if not ctx.Config.MapGeo then
		ctx.UI.toast("Kartendaten fehlen (Schritt 22_MapExport ausfuehren)", "error")
		ctx.Closed("CityMap")
		return
	end
	if not screen then
		buildScreen()
		task.defer(function()
			local p = rootPos()
			setZoom(1.6)
			if p then
				centerOn(p.X, p.Z)
			end
		end)
	end
	screen.Enabled = true
	info.Visible = false
	applyView()
	renderConn = RunService.RenderStepped:Connect(function()
		local c = Players.LocalPlayer.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r then
			local p = M.ToMap(r.Position.X, r.Position.Z, BASE)
			playerDot.Position = UDim2.fromOffset(p.X, p.Y)
			local look = Workspace.CurrentCamera.CFrame.LookVector
			playerDot.Rotation = math.deg(math.atan2(look.X, -look.Z))
		end
	end)
end

-- Navigation laeuft auch bei geschlossener Karte (z.B. waehrend der Fahrt)
function M.Start(ctx)
	ctxRef = ctx
	task.spawn(function()
		while true do
			task.wait(1.2)
			local ok, err = pcall(navTick)
			if not ok then
				warn("[Navigation] " .. tostring(err))
			end
		end
	end)
end

return M
