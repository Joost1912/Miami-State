-- Funkgeraet (Taste B): nicht-modales Panel unten rechts. Kanaele, Nachrichtenverlauf, Schnellcodes,
-- aktive Einheiten, Panikknopf. Zugriff und Kanalrechte prueft der Server.
local R = {}
local screen
local log = {} -- lokale Kopie eingehender Meldungen
local refresh

function R.Close()
	if screen then
		screen:Destroy()
		screen = nil
		refresh = nil
	end
end

function R.IsOpen()
	return screen ~= nil
end

local function time(t)
	return os.date("!%H:%M", t or os.time())
end

-- eingehende Funkmeldung (auch bei geschlossenem Geraet)
function R.Incoming(ctx, msg)
	table.insert(log, msg)
	if #log > 60 then
		table.remove(log, 1)
	end
	if refresh then
		refresh()
	elseif msg.Kind == "panic" then
		ctx.UI.toast("FUNK " .. msg.Ch .. " | " .. msg.From .. ": " .. msg.Text, "error")
	elseif msg.Kind == "dispatch" then
		ctx.UI.toast("DISPATCH: " .. msg.Text, "info")
	end
end

function R.Open(ctx)
	local UI, T = ctx.UI, ctx.UI.Theme
	local res = ctx.Request("Radio.State", nil, true)
	if not res.ok or #res.data.Channels == 0 then
		UI.toast("Funk nur im Dienst einer Einsatzfraktion", "warning")
		ctx.Closed("Radio")
		return
	end
	local state = res.data
	-- Verlauf mit Serverstand zusammenfuehren
	log = state.History
	R.Close()
	screen = UI.screen("MiamiRadio", 15)
	local dev = UI.new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -130), Size = UDim2.fromOffset(380, 470), BackgroundColor3 = Color3.fromRGB(14, 16, 20), Parent = screen })
	UI.corner(dev, 14)
	UI.stroke(dev, Color3.fromRGB(60, 66, 80))
	UI.pad(dev, 12)
	-- Kopf
	UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 0, 20), Font = T.FontBlack, TextSize = 16, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = "MSP RADIO  |  " .. (state.Callsign or "-"), Parent = dev })
	local close = UI.button(dev, "X", "secondary", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(26, 22), TextSize = 12 })
	close.MouseButton1Click:Connect(function()
		R.Close()
		ctx.Closed("Radio")
	end)
	local lcd = UI.new("TextLabel", { BackgroundColor3 = Color3.fromRGB(20, 40, 30), Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 0, 26), Font = Enum.Font.Code, TextSize = 15, TextColor3 = Color3.fromRGB(120, 255, 160), Text = "", Parent = dev })
	UI.corner(lcd, 6)
	-- Kanaele
	local chRow = UI.new("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 58), Size = UDim2.new(1, 0, 0, 30), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 2, ScrollingDirection = Enum.ScrollingDirection.X, Parent = dev })
	UI.list(chRow, 6, true)
	local chButtons = {}
	local function paintChannels()
		for id, b in pairs(chButtons) do
			b.BackgroundColor3 = (id == state.Channel) and T.Accent or T.Panel2
			b.TextColor3 = (id == state.Channel) and T.Bg or T.Text
		end
		lcd.Text = string.format("CH %s  |  STATUS %s", state.Channel or "--", state.Status or "--")
	end
	for _, ch in ipairs(state.Channels) do
		local b = UI.button(chRow, ch.Id, "secondary", { Size = UDim2.fromOffset(70, 28), TextSize = 12 })
		chButtons[ch.Id] = b
		b.MouseButton1Click:Connect(function()
			if ctx.Request("Radio.Join", { Channel = ch.Id }, true).ok then
				state.Channel = ch.Id
				paintChannels()
			end
		end)
	end
	-- Verlauf
	local feed = UI.scroll(dev, { Position = UDim2.new(0, 0, 0, 94), Size = UDim2.new(1, 0, 0, 190), BackgroundTransparency = 0.2, BackgroundColor3 = Color3.fromRGB(8, 10, 14) })
	UI.list(feed, 2)
	refresh = function()
		feed:ClearAllChildren()
		UI.list(feed, 2)
		for i = math.max(1, #log - 40), #log do
			local m = log[i]
			local col = (m.Kind == "panic" and T.Danger) or (m.Kind == "dispatch" and T.Warning) or T.Text
			UI.label(feed, string.format("[%s] %s %s: %s", time(m.T), m.Ch, m.From, m.Text), 12, { TextColor3 = col, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i })
		end
		feed.CanvasPosition = Vector2.new(0, 100000)
	end
	refresh()
	-- Schnellcodes
	local quick = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 290), Size = UDim2.new(1, 0, 0, 54), Parent = dev })
	UI.new("UIGridLayout", { CellSize = UDim2.new(0.25, -5, 0, 24), CellPadding = UDim2.fromOffset(6, 6), Parent = quick })
	for _, q in ipairs(ctx.Config.Police.QuickCodes) do
		local b = UI.button(quick, q.Code, "secondary", { TextSize = 11 })
		b.MouseButton1Click:Connect(function()
			ctx.Request("Radio.Send", { Text = q.Code .. " - " .. q.Text }, true)
		end)
	end
	-- Eingabe
	local input = UI.input(dev, "Funkspruch (Enter zum Senden)", { Position = UDim2.new(0, 0, 0, 350), Size = UDim2.new(0.72, -6, 0, 36), TextSize = 14 })
	local send = UI.button(dev, "SENDEN", "primary", { Position = UDim2.new(0.72, 0, 0, 350), Size = UDim2.new(0.28, 0, 0, 36), TextSize = 13 })
	local function doSend()
		if input.Text ~= "" then
			local r = ctx.Request("Radio.Send", { Text = input.Text }, true)
			if r.ok then
				input.Text = ""
			elseif r.msg then
				UI.toast(r.msg, "error")
			end
		end
	end
	send.MouseButton1Click:Connect(doSend)
	input.FocusLost:Connect(function(enter)
		if enter then
			doSend()
		end
	end)
	-- Einheiten + Panik
	local units = {}
	for _, o in ipairs(state.Officers) do
		if o.OnDuty then
			table.insert(units, o.Callsign .. " " .. o.Status)
		end
	end
	UI.label(dev, "AKTIV: " .. (#units > 0 and table.concat(units, "  |  ") or "-"), 11, { TextColor3 = T.Muted, Position = UDim2.new(0, 0, 0, 392), Size = UDim2.new(1, 0, 0, 28), TextTruncate = Enum.TextTruncate.AtEnd })
	local panic = UI.button(dev, "10-99  PANIK", "danger", { Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 30), TextSize = 14 })
	panic.MouseButton1Click:Connect(function()
		ctx.Request("Radio.Panic")
	end)
	paintChannels()
end

return R
