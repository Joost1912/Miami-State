-- Minimap oben rechts: gleiche Kartendaten wie die Stadtkarte (CityMap.Build), Norden oben, Spielerpfeil dreht mit.
-- Zeigt Strassen, Gebaeude, wichtige Orte, Navigationsziel (am Rand angeheftet) und die Route.
-- Leistung: Kartenebene wird einmal aufgebaut; pro Bild nur Position/Rotation weniger Objekte (Takt 30 Hz).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MM = {}
local ctxRef, gui, holder, group, canvas, routeLayer, arrow, targetPin, districtLbl, distLbl
local S = 0.5 -- Pixel pro Stud bei Zoomstufe 2
local ZOOMS = { 0.3, 0.5, 0.8, 1.2 }
local zoomIdx = 2
local SIZE = 230
local forceUpdate = true

function MM.Close() end

local function setVisible(on)
	if holder then
		holder.Visible = on
	end
end

function MM.ApplySettings(settings)
	if not settings then
		return
	end
	setVisible(settings.Minimap ~= false)
	if settings.MinimapZoom and ZOOMS[settings.MinimapZoom] then
		zoomIdx = settings.MinimapZoom
		if group then
			MM.SetZoom(zoomIdx, true)
		end
	end
end

function MM.SetZoom(idx, silent)
	zoomIdx = math.clamp(idx, 1, #ZOOMS)
	forceUpdate = true
	local sc = canvas and canvas:FindFirstChildOfClass("UIScale")
	if sc then
		sc.Scale = ZOOMS[zoomIdx] / S
	end
	-- Symbole behalten ihre Bildschirmgroesse
	for _, c in ipairs(canvas and canvas:GetChildren() or {}) do
		local k = c:FindFirstChild("Counter")
		if k then
			k.Scale = S / ZOOMS[zoomIdx]
		end
	end
	if not silent and ctxRef then
		ctxRef.Request("Phone.SaveSettings", { MinimapZoom = zoomIdx }, true)
	end
end

function MM.Toggle()
	if holder then
		holder.Visible = not holder.Visible
		ctxRef.Request("Phone.SaveSettings", { Minimap = holder.Visible }, true)
	end
end

function MM.Start(ctx)
	ctxRef = ctx
	local UI, T = ctx.UI, ctx.UI.Theme
	local D = ctx.Config.MapData
	local CityMap = ctx.Controllers.CityMap
	if not ctx.Config.MapGeo then
		return
	end
	gui = UI.screen("MiamiMinimap", 4)
	holder = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 124), Size = UDim2.fromOffset(SIZE, SIZE + 30), BackgroundTransparency = 1, Parent = gui })
	-- Kartenausschnitt mit runden Ecken (CanvasGroup schneidet auch gedrehte Teile sauber ab)
	group = UI.new("CanvasGroup", { Size = UDim2.fromOffset(SIZE, SIZE), BackgroundColor3 = Color3.fromRGB(16, 38, 58), Parent = holder })
	UI.corner(group, 18)
	canvas = UI.new("Frame", { BorderSizePixel = 0, Parent = group })
	UI.new("UIScale", { Scale = ZOOMS[zoomIdx] / S, Parent = canvas })
	CityMap.Build(canvas, S, { minimal = true })
	routeLayer = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 15, Parent = canvas })
	-- wichtige Orte
	for _, p in ipairs(ctx.Config.MapGeo.POI) do
		local cat = D.Category(p[1])
		if cat.Mini then
			local pos = CityMap.ToMap(p[3], p[4], S)
			local ic = CityMap.Icon(canvas, cat, 16, 20)
			ic.Position = UDim2.fromOffset(pos.X, pos.Y)
			ic.Active = false
			local sc = Instance.new("UIScale")
			sc.Name = "Counter"
			sc.Parent = ic
		end
	end
	MM.SetZoom(zoomIdx, true)
	-- Rahmen, Spielerpfeil, Norden
	local frame = UI.new("Frame", { Size = UDim2.fromOffset(SIZE, SIZE), BackgroundTransparency = 1, Parent = holder })
	UI.corner(frame, 18)
	UI.stroke(frame, Color3.fromRGB(230, 236, 246), 2, 0.35)
	arrow = UI.new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, Font = T.FontBlack, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.1, Text = "▲", ZIndex = 5, Parent = frame })
	local north = UI.new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = Color3.fromRGB(12, 14, 20), BackgroundTransparency = 0.2, Font = T.FontBlack, TextSize = 11, TextColor3 = Color3.fromRGB(255, 90, 90), Text = "N", ZIndex = 5, Parent = frame })
	UI.corner(north, 9)
	targetPin = UI.new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, Font = T.FontBlack, TextSize = 18, Text = "📍", ZIndex = 6, Visible = false, Parent = frame })
	-- Zoomknoepfe
	for i, z in ipairs({ { "+", 1 }, { "−", -1 } }) do
		local b = UI.button(frame, z[1], "secondary", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -6 - (2 - i) * 26), Size = UDim2.fromOffset(22, 22), TextSize = 14, ZIndex = 6, BackgroundTransparency = 0.2 })
		b.MouseButton1Click:Connect(function()
			MM.SetZoom(zoomIdx + z[2])
		end)
	end
	-- Infozeile: Stadtteil, Navigationsdistanz
	local bar = UI.new("Frame", { Position = UDim2.fromOffset(0, SIZE + 4), Size = UDim2.fromOffset(SIZE, 24), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.2, Parent = holder })
	UI.corner(bar, 8)
	districtLbl = UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.62, -8, 1, 0), Font = T.FontBold, TextSize = 12, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = "", Parent = bar })
	distLbl = UI.new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.new(0.38, 0, 1, 0), Font = T.FontBold, TextSize = 12, TextColor3 = Color3.fromRGB(80, 200, 255), TextXAlignment = Enum.TextXAlignment.Right, Text = "", Parent = bar })

	local Nav = CityMap.Nav
	local function redrawRoute()
		CityMap.DrawPolyline(routeLayer, Nav.Route, S, Color3.fromRGB(80, 200, 255), 6, 15)
	end
	Nav.Changed.Event:Connect(redrawRoute)

	-- Einstellungen aus dem Profil
	MM.ApplySettings(ctx.Profile and ctx.Profile.Phone and ctx.Profile.Phone.Settings)
	ctx.ProfileChanged:Connect(function(p)
		if p.Phone then
			setVisible(p.Phone.Settings.Minimap ~= false)
		end
	end)

	-- Tasten: + / - Zoom
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Equals or input.KeyCode == Enum.KeyCode.KeypadPlus then
			MM.SetZoom(zoomIdx + 1)
		elseif input.KeyCode == Enum.KeyCode.Minus or input.KeyCode == Enum.KeyCode.KeypadMinus then
			MM.SetZoom(zoomIdx - 1)
		end
	end)

	-- Aktualisierung (30 Hz, nur wenn sichtbar)
	local acc, lastDistrict, lastPos = 0, nil, nil
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < 1 / 30 or not holder.Visible then
			return
		end
		acc = 0
		local c = Players.LocalPlayer.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		local pos = r.Position
		local zs = ZOOMS[zoomIdx]
		local mp = CityMap.ToMap(pos.X, pos.Z, S) * (zs / S)
		if forceUpdate or not lastPos or (lastPos - pos).Magnitude > 0.3 then
			forceUpdate = false
			canvas.Position = UDim2.fromOffset(SIZE / 2 - mp.X, SIZE / 2 - mp.Y)
			lastPos = pos
		end
		local look = Workspace.CurrentCamera.CFrame.LookVector
		arrow.Rotation = math.deg(math.atan2(look.X, -look.Z))
		local dname = D.DistrictAt(pos.X, pos.Z)
		if dname ~= lastDistrict then
			districtLbl.Text = dname
			lastDistrict = dname
		end
		-- Ziel: innerhalb anzeigen, sonst am Rand anheften
		if Nav.Target then
			local tp = CityMap.ToMap(Nav.Target.X, Nav.Target.Z, S) * (zs / S)
			local rel = tp - mp
			local lim = SIZE / 2 - 12
			if math.abs(rel.X) > lim or math.abs(rel.Y) > lim then
				local k = lim / math.max(math.abs(rel.X), math.abs(rel.Y))
				rel *= k
			end
			targetPin.Position = UDim2.fromOffset(SIZE / 2 + rel.X, SIZE / 2 + rel.Y)
			targetPin.Visible = true
			local d = Nav.Distance()
			distLbl.Text = d and string.format("%d m", math.floor(d * 0.28)) or ""
		else
			targetPin.Visible = false
			distLbl.Text = ""
		end
	end)
end

return MM
