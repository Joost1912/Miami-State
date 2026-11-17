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

-- AUTOHAUS ------------------------------------------------------------------------------------------
local function renderDealer(body)
	local UI, T = ctxRef.UI, ctxRef.UI.Theme
	clear(body)
	local res = ctxRef.Request("Dealer.Catalog", { Dealer = state.Dealer }, true)
	if not res.ok then
		UI.label(body, res.msg or "Katalog nicht verfuegbar", 14, { TextColor3 = T.Muted })
		return
	end
	local cat = res.data
	local list = UI.scroll(body, { Size = UDim2.new(0.38, -6, 1, 0) })
	UI.list(list, 6)
	local detail = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.62, -6, 1, 0), BackgroundColor3 = T.Panel2, Parent = body })
	UI.corner(detail, 12)
	UI.pad(detail, 16)
	local maxSpeed, maxPower = 1, 1
	for _, m in ipairs(cat.Models) do
		maxSpeed, maxPower = math.max(maxSpeed, m.TopSpeed), math.max(maxPower, m.Power)
	end
	local selectedPaint = 1
	local function showModel(m)
		clear(detail)
		local col = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = detail })
		UI.list(col, 8)
		UI.label(col, string.upper(m.Class), 11, { LayoutOrder = 1, Font = T.FontBold, TextColor3 = T.Accent })
		UI.label(col, m.Name, 26, { LayoutOrder = 2, Font = T.FontBlack })
		UI.label(col, m.Desc, 13, { LayoutOrder = 3, TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 34) })
		statBar(col, "Hoechstgeschwindigkeit", m.TopSpeed, maxSpeed, 4)
		statBar(col, "Leistung", m.Power, maxPower, 5)
		statBar(col, "Verbrauch", m.Thirst, 2, 6)
		UI.label(col, string.format("%d Sitze  ·  Tank 100%%", m.Seats), 12, { LayoutOrder = 7, TextColor3 = T.Muted })
		UI.label(col, "LACKIERUNG", 11, { LayoutOrder = 8, Font = T.FontBold, TextColor3 = T.Muted })
		local sw = UI.new("Frame", { LayoutOrder = 9, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), Parent = col })
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(22, 22), CellPadding = UDim2.fromOffset(6, 6), Parent = sw })
		local paintName = UI.label(col, cat.Paints[selectedPaint].Name, 12, { LayoutOrder = 10 })
		local strokes = {}
		for i, p in ipairs(cat.Paints) do
			local b = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(p.R, p.G, p.B), Parent = sw })
			UI.corner(b, 11)
			strokes[i] = UI.stroke(b, T.Accent, 2, i == selectedPaint and 0 or 1)
			b.MouseButton1Click:Connect(function()
				strokes[selectedPaint].Transparency = 1
				selectedPaint = i
				strokes[i].Transparency = 0
				paintName.Text = p.Name
			end)
		end
		local row = UI.new("Frame", { LayoutOrder = 11, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = col })
		local test = UI.button(row, "Probefahrt (" .. cat.TestDrive .. " s)", "secondary", { Size = UDim2.new(0.42, -4, 1, 0), TextSize = 13 })
		local buy = UI.button(row, "Kaufen  " .. money(m.Price), "primary", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.58, -4, 1, 0), TextSize = 14 })
		UI.label(col, string.format("Bankkonto: %s  ·  Fahrzeuge %d/%d", money(cat.Bank), cat.Owned, cat.MaxOwned), 11, { LayoutOrder = 12, TextColor3 = T.Muted })
		test.MouseButton1Click:Connect(function()
			if ctxRef.Request("Dealer.TestDrive", { Model = m.Id }).ok then
				V.Close()
			end
		end)
		local armed = false
		buy.MouseButton1Click:Connect(function()
			if not armed then
				armed = true
				buy.Text = "Kauf bestaetigen?"
				task.delay(3, function()
					if armed and buy.Parent then
						armed = false
						buy.Text = "Kaufen  " .. money(m.Price)
					end
				end)
				return
			end
			armed = false
			local r = ctxRef.Request("Dealer.Buy", { Model = m.Id, Paint = selectedPaint, TxId = ctxRef.TxId() })
			if r.ok then
				state.Tab = "Garage"
				V.Render()
			end
		end)
	end
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
		if i == 1 then
			s.Color = T.Accent
			showModel(m)
		end
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
