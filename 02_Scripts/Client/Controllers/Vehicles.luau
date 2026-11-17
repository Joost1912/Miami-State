-- Fahrzeug-Menue (Prompt 10): Autohaus (Katalog, Details, Lack, Probefahrt, Kauf), Garage (aus-/einparken,
-- orten, abschleppen, verkaufen) und Tuning. Alle Werte kommen vom Server; der Client zeigt nur an.
local TweenService = game:GetService("TweenService")
local V = {}
local gui, closeFn, ctxRef
local state = {}

local function money(n)
	return ctxRef.Format.money(n)
end

function V.Close()
	if V.EndPreview then
		V.EndPreview()
	end
	if closeFn then
		closeFn()
	end
end

local function clear(f)
	for _, c in ipairs(f:GetChildren()) do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") and not c:IsA("UIGridLayout") then
			c:Destroy()
		end
	end
end

local function statBar(parent, label, value, max, order)
	local UI, T = ctxRef.UI, ctxRef.UI.Theme
	local row = UI.new("Frame", { LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Parent = parent })
	UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.5, 0, 0, 14), Font = T.FontBold, TextSize = 11, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = string.upper(label), Parent = row })
	UI.new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.5, 0, 0, 14), Font = T.FontBold, TextSize = 11, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Right, Text = tostring(value), Parent = row })
	local bg = UI.new("Frame", { BorderSizePixel = 0, Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = T.Panel2, Parent = row })
	UI.corner(bg, 3)
	local fill = UI.new("Frame", { BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, Parent = bg })
	UI.corner(fill, 3)
	UI.new("UIGradient", { Color = ColorSequence.new(T.Accent, T.Accent2), Parent = fill })
	TweenService:Create(fill, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(math.clamp(tonumber(max) and value / max or 0, 0.04, 1), 1) }):Play()
end

-- AUTOHAUS (Prompt 12: Werte, 360-Grad-Vorschau mit Lack, Zahlart, Bestaetigung, Kaufbeleg) -----------
local preview -- { Model, Colors = {[part]=Color3}, Conn, Angle }
local function endPreview()
	if not preview then
		return
	end
	for part, c in pairs(preview.Colors) do
		if part.Parent then
			part.Color = c
		end
	end
	if preview.Conn then
		preview.Conn:Disconnect()
	end
	if preview.Gui then
		preview.Gui:Destroy()
	end
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	preview = nil
	if gui then
		gui.Enabled = true
	end
end
V.EndPreview = endPreview

local function displayFor(modelId)
	local root = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local best, bd
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d.Name == "Display_" .. modelId then
			local dist = root and (d:GetPivot().Position - root.Position).Magnitude or 0
			if dist < 400 and (not bd or dist < bd) then
				best, bd = d, dist
			end
		end
	end
	return best
end

local function paintPreview(colorIdx, paints)
	if not preview then
		return
	end
	local p = paints[colorIdx]
	local base = preview.Base
	for part in pairs(preview.Colors) do
		if part.Parent and preview.Colors[part] == base then
			part.Color = Color3.fromRGB(p.R, p.G, p.B)
		end
	end
end

local function startPreview(m, paints, getPaint, setPaint)
	local UI, T = ctxRef.UI, ctxRef.UI.Theme
	local car = displayFor(m.Id)
	if not car then
		UI.toast("Vorschau: Das Modell steht im Showroom der Miami Motor Gallery (Sawgrass Motors)", "warning")
		return
	end
	endPreview()
	preview = { Model = car, Colors = {}, Angle = 0 }
	local body = car:FindFirstChild("Body")
	local lower = body and body:FindFirstChild("LowerBody")
	preview.Base = lower and lower.Color
	for _, part in ipairs(body and body:GetChildren() or {}) do
		if part:IsA("BasePart") then
			preview.Colors[part] = part.Color
		end
	end
	if gui then
		gui.Enabled = false
	end
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local _, size = car:GetBoundingBox()
	local dist = math.max(size.X, size.Z) * 1.25 + 6
	local center = car:GetPivot().Position
	local drag = 0
	preview.Conn = game:GetService("RunService").RenderStepped:Connect(function(dt)
		preview.Angle += dt * 0.35 + drag
		drag *= 0.85
		local a = preview.Angle
		cam.CFrame = CFrame.lookAt(center + Vector3.new(math.cos(a) * dist, size.Y * 0.6 + 2, math.sin(a) * dist), center + Vector3.new(0, 1, 0))
	end)
	-- Vorschau-Leiste
	local sg = UI.screen("MiamiCarPreview", 25)
	preview.Gui = sg
	local bar = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(560, 120), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.08, Parent = sg })
	UI.corner(bar, 14)
	UI.pad(bar, 12)
	UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Font = T.FontBlack, TextSize = 18, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = m.Name .. "  ·  " .. money(m.Price), Parent = bar })
	local sw = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, -150, 0, 50), Parent = bar })
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(22, 22), CellPadding = UDim2.fromOffset(6, 6), Parent = sw })
	for i, p in ipairs(paints) do
		local b = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(p.R, p.G, p.B), Parent = sw })
		UI.corner(b, 11)
		UI.stroke(b, Color3.new(1, 1, 1), i == getPaint() and 2 or 1, i == getPaint() and 0 or 0.7)
		b.MouseButton1Click:Connect(function()
			setPaint(i)
			paintPreview(i, paints)
			for _, c in ipairs(sw:GetChildren()) do
				local s = c:FindFirstChildOfClass("UIStroke")
				if s then
					s.Thickness, s.Transparency = 1, 0.7
				end
			end
			local s = b:FindFirstChildOfClass("UIStroke")
			s.Thickness, s.Transparency = 2, 0
		end)
	end
	local rot = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 30), Size = UDim2.fromOffset(140, 32), Parent = bar })
	UI.list(rot, 6, true)
	for _, d in ipairs({ { "◀", -0.06 }, { "▶", 0.06 } }) do
		UI.button(rot, d[1], "secondary", { Size = UDim2.fromOffset(40, 32), TextSize = 14 }).MouseButton1Click:Connect(function()
			drag += d[2]
		end)
	end
	UI.button(bar, "Zurueck zum Kaufmenue", "primary", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(200, 32), TextSize = 13 }).MouseButton1Click:Connect(function()
		endPreview()
		V.Render()
	end)
	paintPreview(getPaint(), paints)
end

-- Modales Fenster (Bestaetigung / Kaufbeleg) ueber dem Menue
local function modal(title, lines, buttons)
	local UI, T = ctxRef.UI, ctxRef.UI.Theme
	local cover = UI.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = gui })
	local box = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Panel, ZIndex = 51, Parent = cover })
	UI.corner(box, 14)
	UI.stroke(box, T.Accent, 1, 0.5)
	UI.pad(box, 18)
	UI.list(box, 8)
	UI.label(box, string.upper(title), 12, { Font = T.FontBold, TextColor3 = T.Accent, ZIndex = 52 })
	for _, l in ipairs(lines) do
		UI.label(box, l[1], l[2] or 14, { Font = l[3] or T.Font, TextColor3 = l[4] or T.Text, ZIndex = 52, AutomaticSize = Enum.AutomaticSize.Y })
	end
	local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), ZIndex = 52, Parent = box })
	UI.list(row, 8, true)
	for _, b in ipairs(buttons) do
		local btn = UI.button(row, b[1], b[2], { Size = UDim2.fromOffset(165, 36), TextSize = 13, ZIndex = 53 })
		btn.MouseButton1Click:Connect(function()
			cover:Destroy()
			if b[3] then
				b[3]()
			end
		end)
	end
	return cover
end

local function renderDealer(body)
	local UI, T = ctxRef.UI, ctxRef.UI.Theme
	clear(body)
	local res = ctxRef.Request("Dealer.Catalog", { Dealer = state.Dealer }, true)
	if not res.ok then
		UI.label(body, res.msg or "Katalog nicht verfuegbar", 14, { TextColor3 = T.Muted })
		return
	end
	local cat = res.data
	local list = UI.scroll(body, { Size = UDim2.new(0.36, -6, 1, 0) })
	UI.list(list, 6)
	local detail = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.64, -6, 1, 0), BackgroundColor3 = T.Panel2, Parent = body })
	UI.corner(detail, 12)
	UI.pad(detail, 14)
	local maxSpeed = 1
	for _, m in ipairs(cat.Models) do
		maxSpeed = math.max(maxSpeed, m.TopSpeed)
	end
	local selectedPaint = state.Paint or 1
	local method = state.Method or "Bank"
	local function showModel(m)
		clear(detail)
		state.Model = m.Id
		local col = UI.scroll(detail, { Size = UDim2.fromScale(1, 1) })
		UI.list(col, 7)
		local o = 0
		local function nx()
			o += 1
			return o
		end
		UI.label(col, string.upper(m.Class) .. "  ·  " .. string.upper(m.Drive or "-"), 11, { LayoutOrder = nx(), Font = T.FontBold, TextColor3 = T.Accent })
		UI.label(col, m.Name, 26, { LayoutOrder = nx(), Font = T.FontBlack })
		UI.label(col, m.Desc, 13, { LayoutOrder = nx(), TextColor3 = T.Muted, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
		statBar(col, "Hoechstgeschwindigkeit  " .. m.TopSpeed .. " km/h", "", nil, nx())
		local function setBar(order, frac)
			for _, c in ipairs(col:GetChildren()) do
				if c:IsA("Frame") and c.LayoutOrder == order then
					local bg = c:FindFirstChildWhichIsA("Frame")
					local fill = bg and bg:FindFirstChildWhichIsA("Frame")
					if fill then
						TweenService:Create(fill, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(math.clamp(frac, 0.04, 1), 1) }):Play()
					end
				end
			end
		end
		setBar(o, m.TopSpeed / maxSpeed)
		statBar(col, string.format("Beschleunigung 0-100  %.1f s", m.Accel or 10), "", nil, nx())
		setBar(o, 1 - ((m.Accel or 10) - 3) / 14)
		statBar(col, string.format("Handling  %.1f / 10", m.Handling or 5), "", nil, nx())
		setBar(o, (m.Handling or 5) / 10)
		statBar(col, string.format("Verbrauch  %.1f", m.Thirst), "", nil, nx())
		setBar(o, m.Thirst / 2)
		UI.label(col, string.format("%d Sitze  ·  Antrieb: %s  ·  voller Tank bei Uebergabe", m.Seats, m.Drive or "-"), 12, { LayoutOrder = nx(), TextColor3 = T.Muted })
		UI.label(col, "LACKIERUNG", 11, { LayoutOrder = nx(), Font = T.FontBold, TextColor3 = T.Muted })
		local sw = UI.new("Frame", { LayoutOrder = nx(), BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 52), Parent = col })
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(22, 22), CellPadding = UDim2.fromOffset(6, 6), Parent = sw })
		local paintName = UI.label(col, cat.Paints[selectedPaint].Name, 12, { LayoutOrder = nx() })
		local strokes = {}
		for i, p in ipairs(cat.Paints) do
			local b = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(p.R, p.G, p.B), Parent = sw })
			UI.corner(b, 11)
			strokes[i] = UI.stroke(b, T.Accent, 2, i == selectedPaint and 0 or 1)
			b.MouseButton1Click:Connect(function()
				strokes[selectedPaint].Transparency = 1
				selectedPaint = i
				state.Paint = i
				strokes[i].Transparency = 0
				paintName.Text = p.Name
			end)
		end
		-- Zahlart
		UI.label(col, "ZAHLUNG", 11, { LayoutOrder = nx(), Font = T.FontBold, TextColor3 = T.Muted })
		local pay = UI.new("Frame", { LayoutOrder = nx(), BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 34), Parent = col })
		UI.list(pay, 6, true)
		local payBtns = {}
		for _, pm in ipairs({ { "Bank", "Bankkonto  " .. money(cat.Bank) }, { "Cash", "Bargeld  " .. money(cat.Cash or 0) } }) do
			local b = UI.button(pay, pm[2], pm[1] == method and "primary" or "secondary", { Size = UDim2.new(0.5, -3, 1, 0), TextSize = 12 })
			payBtns[pm[1]] = b
			b.MouseButton1Click:Connect(function()
				method = pm[1]
				state.Method = method
				for k, x in pairs(payBtns) do
					x.BackgroundColor3 = k == method and T.Accent or T.Panel2
					x.TextColor3 = k == method and T.Bg or T.Text
				end
			end)
		end
		local row = UI.new("Frame", { LayoutOrder = nx(), BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 40), Parent = col })
		UI.list(row, 6, true)
		UI.button(row, "360° Vorschau", "secondary", { Size = UDim2.new(0.3, -4, 1, 0), TextSize = 12 }).MouseButton1Click:Connect(function()
			startPreview(m, cat.Paints, function()
				return selectedPaint
			end, function(i)
				selectedPaint = i
				state.Paint = i
			end)
		end)
		UI.button(row, "Probefahrt", "secondary", { Size = UDim2.new(0.25, -4, 1, 0), TextSize = 12 }).MouseButton1Click:Connect(function()
			if ctxRef.Request("Dealer.TestDrive", { Model = m.Id }).ok then
				V.Close()
			end
		end)
		local buy = UI.button(row, "Kaufen  " .. money(m.Price), "primary", { Size = UDim2.new(0.45, -4, 1, 0), TextSize = 13 })
		UI.label(col, string.format("Fahrzeuge %d/%d  ·  Kennzeichen wird bei Kauf vergeben", cat.Owned, cat.MaxOwned), 11, { LayoutOrder = nx(), TextColor3 = T.Muted })
		buy.MouseButton1Click:Connect(function()
			local p = cat.Paints[selectedPaint]
			modal("Kauf bestaetigen", {
				{ m.Name, 20, T.FontBlack },
				{ m.Class .. "  ·  " .. (m.Drive or "-") .. "  ·  Lack: " .. p.Name, 13, nil, T.Muted },
				{ "Kaufpreis: " .. money(m.Price), 16, T.FontBold, T.Success },
				{ "Zahlung: " .. (method == "Cash" and "Bargeld" or "Bankkonto"), 13 },
			}, {
				{ "Jetzt kaufen", "primary", function()
					local r = ctxRef.Request("Dealer.Buy", { Model = m.Id, Paint = selectedPaint, Method = method, TxId = ctxRef.TxId() }, true)
					if r.ok then
						modal("Kaufbestaetigung", {
							{ "Herzlichen Glueckwunsch!", 18, T.FontBlack },
							{ string.format("%s gehoert jetzt dir.", r.data.Name), 14 },
							{ "Kennzeichen: " .. r.data.Plate, 16, T.FontBold, T.Accent },
							{ string.format("Bezahlt: %s (%s)", money(r.data.Price), r.data.Method == "Cash" and "bar" or "Bankkonto"), 13, nil, T.Muted },
							{ "Das Fahrzeug steht in deiner Garage (Handy-App Garage oder Garagen-Terminal).", 12, nil, T.Muted },
						}, {
							{ "Zur Garage", "primary", function()
								state.Tab = "Garage"
								V.Render()
							end },
							{ "Weiter umsehen", "secondary", function()
								V.Render()
							end },
						})
					else
						ctxRef.UI.toast(r.msg or "Kauf fehlgeschlagen", "error")
					end
				end },
				{ "Abbrechen", "secondary", nil },
			})
		end)
	end
	local first
	for i, m in ipairs(cat.Models) do
		local card = UI.new("TextButton", { LayoutOrder = i, AutoButtonColor = false, Text = "", Size = UDim2.new(1, -6, 0, 58), BackgroundColor3 = T.Panel2, Parent = list })
		UI.corner(card, 10)
		local s = UI.stroke(card, T.Stroke, 1, 0)
		UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 20), Font = T.FontBold, TextSize = 15, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = m.Name, Parent = card })
		UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 16), Font = T.Font, TextSize = 12, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = m.Class, Parent = card })
		UI.new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 30), Size = UDim2.fromOffset(100, 16), Font = T.FontBold, TextSize = 13, TextColor3 = T.Success, TextXAlignment = Enum.TextXAlignment.Right, Text = money(m.Price), Parent = card })
		card.MouseButton1Click:Connect(function()
			for _, c in ipairs(list:GetChildren()) do
				local st = c:FindFirstChildOfClass("UIStroke")
				if st then
					st.Color = T.Stroke
				end
			end
			s.Color = T.Accent
			showModel(m)
		end)
		if (state.Model and m.Id == state.Model) or (not state.Model and i == 1) then
			first = { m, s }
		end
	end
	if first then
		first[2].Color = T.Accent
		showModel(first[1])
	end
end

-- GARAGE --------------------------------------------------------------------------------------------
local function renderGarage(body)
	local UI, T = ctxRef.UI, ctxRef.UI.Theme
	clear(body)
	local res = ctxRef.Request("Vehicle.Owned", nil, true)
	local list = UI.scroll(body)
	UI.list(list, 8)
	if not res.ok or #res.data == 0 then
		UI.label(list, "Keine Fahrzeuge. Autohaeuser: Sawgrass Motors (Sawgrass Park) und Bayfront Prestige (Downtown).", 14, { TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 40) })
		return
	end
	for i, v in ipairs(res.data) do
		local card = UI.new("Frame", { LayoutOrder = i, Size = UDim2.new(1, -6, 0, 86), BackgroundColor3 = T.Panel2, Parent = list })
		UI.corner(card, 12)
		UI.pad(card, 12)
		local c = v.Color or { 120, 120, 120 }
		local chip = UI.new("Frame", { Size = UDim2.fromOffset(8, 62), BackgroundColor3 = Color3.fromRGB(c[1], c[2], c[3]), Parent = card })
		UI.corner(chip, 4)
		UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(0.5, 0, 0, 20), Font = T.FontBlack, TextSize = 16, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = v.Name, Parent = card })
		local plate = UI.new("TextLabel", { Position = UDim2.fromOffset(18, 24), Size = UDim2.fromOffset(86, 18), BackgroundColor3 = Color3.fromRGB(236, 238, 242), Font = T.FontBold, TextSize = 11, TextColor3 = Color3.fromRGB(20, 30, 60), Text = v.Plate, Parent = card })
		UI.corner(plate, 4)
		local status = v.Out and (v.Driving and "UNTERWEGS" or "AUSGEPARKT") or "IN DER GARAGE"
		UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(112, 24), Size = UDim2.new(0.5, -100, 0, 18), Font = T.FontBold, TextSize = 11, TextColor3 = v.Out and T.Warning or T.Success, TextXAlignment = Enum.TextXAlignment.Left, Text = status .. "  ·  ⛽ " .. tostring(v.Fuel or 100) .. "%", Parent = card })
		UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 46), Size = UDim2.new(0.5, 0, 0, 16), Font = T.Font, TextSize = 11, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("%s  ·  Wiederverkauf %s", v.Class or v.Type, money(v.SellValue or 0)), Parent = card })
		local btns = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0.5, 0, 0, 30), BackgroundTransparency = 1, Parent = card })
		local l = UI.list(btns, 6, true)
		l.HorizontalAlignment = Enum.HorizontalAlignment.Right
		local function btn(text, style, fn)
			local b = UI.button(btns, text, style, { Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, TextSize = 12 })
			UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = b })
			b.MouseButton1Click:Connect(fn)
			return b
		end
		if v.Out then
			btn("Orten", "secondary", function()
				ctxRef.Request("Vehicle.Locate", { Id = v.Id })
			end)
			btn("Einparken", "secondary", function()
				ctxRef.Request("Vehicle.ParkOwned", { Id = v.Id })
				renderGarage(body)
			end)
			btn("Abschleppen", "danger", function()
				ctxRef.Request("Vehicle.Recall", { Id = v.Id, TxId = ctxRef.TxId() })
				renderGarage(body)
			end)
		else
			btn("Ausparken", "primary", function()
				local r = ctxRef.Request("Vehicle.SpawnOwned", { Id = v.Id })
				if r.ok and r.data then
					ctxRef.Controllers.CityMap.Nav.SetTarget(r.data.X, r.data.Z, r.data.Label, r.data.Y)
					V.Close()
				end
			end)
			local armed = false
			local sell
			sell = btn("Verkaufen", "secondary", function()
				if not armed then
					armed = true
					sell.Text = "Fuer " .. money(v.SellValue or 0) .. "?"
					return
				end
				ctxRef.Request("Vehicle.Sell", { Id = v.Id })
				renderGarage(body)
			end)
		end
		btn("Tuning", "secondary", function()
			state.Tab, state.TuneId = "Tuning", v.Id
			V.Render()
		end)
	end
end

-- TUNING --------------------------------------------------------------------------------------------
local function renderTuning(body)
	local UI, T = ctxRef.UI, ctxRef.UI.Theme
	clear(body)
	local owned = ctxRef.Request("Vehicle.Owned", nil, true)
	local info = ctxRef.Request("Vehicle.TuningInfo", nil, true)
	if not (owned.ok and info.ok) or #owned.data == 0 then
		UI.label(body, "Kein Fahrzeug vorhanden.", 14, { TextColor3 = T.Muted })
		return
	end
	local veh
	for _, v in ipairs(owned.data) do
		if v.Id == state.TuneId then
			veh = v
		end
	end
	veh = veh or owned.data[1]
	state.TuneId = veh.Id
	local left = UI.scroll(body, { Size = UDim2.new(0.3, -6, 1, 0) })
	UI.list(left, 6)
	for i, v in ipairs(owned.data) do
		local b = UI.button(left, v.Name .. "\n" .. v.Plate, v.Id == veh.Id and "primary" or "secondary", { LayoutOrder = i, Size = UDim2.new(1, -6, 0, 46), TextSize = 12 })
		b.MouseButton1Click:Connect(function()
			state.TuneId = v.Id
			renderTuning(body)
		end)
	end
	local right = UI.scroll(body, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.7, -6, 1, 0) })
	UI.list(right, 10)
	if not info.data.AtShop then
		UI.label(right, "Umbauten nur in der Werkstatt (Miami Auto Repair) oder im Autohaus moeglich - hier nur Vorschau.", 12, { LayoutOrder = 0, TextColor3 = T.Warning, Size = UDim2.new(1, 0, 0, 32) })
	end
	UI.label(right, "LACKIERUNG  ·  " .. money(info.data.PaintPrice), 11, { LayoutOrder = 1, Font = T.FontBold, TextColor3 = T.Muted })
	local sw = UI.new("Frame", { LayoutOrder = 2, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), Parent = right })
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(24, 24), CellPadding = UDim2.fromOffset(6, 6), Parent = sw })
	for i, p in ipairs(info.data.Paints) do
		local b = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(p.R, p.G, p.B), Parent = sw })
		UI.corner(b, 12)
		UI.stroke(b, Color3.new(1, 1, 1), 1, 0.7)
		b.MouseButton1Click:Connect(function()
			if ctxRef.Request("Vehicle.Tune", { Id = veh.Id, Paint = i, TxId = ctxRef.TxId() }).ok then
				renderTuning(body)
			end
		end)
	end
	for ci, c in ipairs(info.data.Categories) do
		UI.label(right, string.upper(c.Title), 11, { LayoutOrder = 2 + ci * 2, Font = T.FontBold, TextColor3 = T.Muted })
		local row = UI.new("Frame", { LayoutOrder = 3 + ci * 2, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = right })
		UI.list(row, 6, true)
		local current = (veh.Tuning and veh.Tuning[c.Id]) or 1
		for oi, o in ipairs(c.Options) do
			local b = UI.button(row, o.Name .. (o.Price > 0 and ("  " .. money(o.Price)) or ""), oi == current and "primary" or "secondary", { Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, TextSize = 12 })
			UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = b })
			b.MouseButton1Click:Connect(function()
				if oi ~= current and ctxRef.Request("Vehicle.Tune", { Id = veh.Id, Category = c.Id, Option = oi, TxId = ctxRef.TxId() }).ok then
					renderTuning(body)
				end
			end)
		end
	end
end

function V.Render()
	if not gui or not state.Body then
		return
	end
	for name, b in pairs(state.TabButtons) do
		b.BackgroundColor3 = (name == state.Tab) and ctxRef.UI.Theme.Accent or ctxRef.UI.Theme.Panel2
		b.TextColor3 = (name == state.Tab) and ctxRef.UI.Theme.Bg or ctxRef.UI.Theme.Text
	end
	if state.Tab == "Dealer" then
		renderDealer(state.Body)
	elseif state.Tab == "Tuning" then
		renderTuning(state.Body)
	else
		renderGarage(state.Body)
	end
end

function V.Open(ctx, data)
	ctxRef = ctx
	data = data or {}
	local UI = ctx.UI
	gui = UI.screen("MiamiVehicles", 20)
	state = { Dealer = data.Dealer, Tab = data.Tab or (data.Dealer and "Dealer") or "Garage", TuneId = data.TuneId, TabButtons = {} }
	local title = data.Dealer and ((ctx.Config.Vehicles.Dealers[data.Dealer] or {}).Name or "Autohaus") or (data.GarageName or "Fahrzeuge")
	local _, content, doClose = UI.window(gui, title, UDim2.fromOffset(780, 540), function()
		gui:Destroy()
		gui, closeFn = nil, nil
		ctx.Closed("Vehicles")
	end)
	closeFn = doClose
	local tabs = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), Parent = content })
	UI.list(tabs, 8, true)
	local defs = { { "Garage", "MEINE FAHRZEUGE" }, { "Tuning", "TUNING" } }
	if data.Dealer then
		table.insert(defs, 1, { "Dealer", "KATALOG" })
	end
	for _, d in ipairs(defs) do
		local b = UI.button(tabs, d[2], "secondary", { Size = UDim2.fromOffset(150, 32), TextSize = 12 })
		state.TabButtons[d[1]] = b
		b.MouseButton1Click:Connect(function()
			state.Tab = d[1]
			V.Render()
		end)
	end
	state.Body = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), Parent = content })
	V.Render()
end

return V
