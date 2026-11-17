-- LOTT E-Scooter (Prompt 13): Handy-App (Live-Karte, Details, aktive Miete, Verlauf), Miet-Dialog am Roller
-- und Mietanzeige ueber der Minimap. Reine Anzeige - Preise, Sperren und Abrechnung macht der Server (LottService).
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage:WaitForChild("MiamiShared").Config.Lott)
local MINT = Cfg.Color
local GREY = Color3.fromRGB(110, 116, 130)

local LT = {}
local ctxRef
local active -- { Id, Start, Minutes, Paid }
local pillGui, pill, pillText
local modalGui
local selectedId
local zoomIdx = 2
local ZOOMS = { 0.6, 1, 1.8 }
local BASE = 0.05 -- Pixel pro Stud (Kartenmassstab der App bei Zoom 1)

local function UI()
	return ctxRef.UI
end
local function T()
	return ctxRef.UI.Theme
end
local function money(n)
	return ctxRef.Format.money(n)
end
local function now()
	return Workspace:GetServerTimeNow()
end
local function clock(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end
local function district(x, z)
	local ok, d = pcall(ctxRef.Config.MapData.DistrictAt, x, z)
	return ok and d or "Miami"
end
local function navigate(s)
	ctxRef.Controllers.CityMap.Nav.SetTarget(s.X, s.Z, "LOTT " .. s.Id, s.Y)
	UI().toast("Navigation zu " .. s.Id .. " gestartet", "info")
end

-- Mietanzeige ueber der Minimap ------------------------------------------------------------------------
local function updatePill()
	if not pill then
		return
	end
	pill.Visible = active ~= nil
	if active then
		local el = now() - active.Start
		pillText.Text = string.format("%s  ·  %s  ·  %s  ·  laeuft", active.Id, clock(el), money(active.Paid))
	end
end

local function buildPill()
	pillGui = UI().screen("MiamiLottPill", 5)
	-- Minimap: 252x164 unten links (16 / -26) -> direkt darueber
	pill = UI().new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -198), Size = UDim2.fromOffset(252, 30), BackgroundColor3 = Color3.fromRGB(12, 16, 20), BackgroundTransparency = 0.1, Visible = false, Parent = pillGui })
	UI().corner(pill, 15)
	UI().stroke(pill, MINT, 1.5)
	local dot = UI().new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.fromRGB(255, 80, 90), Parent = pill })
	UI().corner(dot, 4)
	pillText = UI().new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -30, 1, 0), Font = T().FontBold, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = "", Parent = pill })
	task.spawn(function()
		local blink = false
		while pillGui and pillGui.Parent do
			blink = not blink
			dot.BackgroundTransparency = blink and 0 or 0.7
			updatePill()
			task.wait(0.5)
		end
	end)
end

-- Dialoge am Roller --------------------------------------------------------------------------------------
local function closeModal()
	if modalGui then
		modalGui:Destroy()
		modalGui = nil
	end
end

local function row(parent, a, b, color)
	local f = UI().new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Parent = parent })
	UI().label(f, a, 13, { TextColor3 = T().Muted, Size = UDim2.new(0.5, 0, 1, 0) })
	UI().label(f, b, 13, { Name = "V", Font = T().FontBold, TextColor3 = color or T().Text, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0.5, 0, 1, 0) })
	return f
end

function LT.Offer(ctx, data)
	ctxRef = ctx
	closeModal()
	modalGui = UI().screen("MiamiLottModal", 25)
	local _, content, doClose = UI().window(modalGui, "LOTT · Roller mieten", UDim2.fromOffset(400, 470), function()
		modalGui = nil
	end)
	local list = UI().scroll(content, { ScrollBarThickness = 3 })
	UI().list(list, 6)
	UI().label(list, "🛴  " .. data.Id, 20, { Font = T().FontBlack, TextColor3 = MINT })
	row(list, "Standort", data.District or "-")
	row(list, "Preis", money(data.Price) .. " / angefangene Minute", MINT)
	row(list, "1 Minute", money(data.Price))
	row(list, "2 Min 10 s (3 angefangen)", money(data.Price * 3))
	row(list, "10 Minuten", money(data.Price * 10))
	for _, r in ipairs(data.Rules or {}) do
		UI().label(list, "•  " .. r, 12, { TextColor3 = T().Muted, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	end
	if data.HasRental then
		UI().label(list, "Du hast bereits " .. data.HasRental .. " gemietet. Beende zuerst diese Miete.", 13, { TextColor3 = T().Danger, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
		UI().button(list, "Schliessen", "secondary").MouseButton1Click:Connect(doClose)
		return
	end
	-- Zahlart
	local method = (data.Bank or 0) >= data.Price and "Bank" or "Cash"
	local pay = UI().new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Parent = list })
	UI().list(pay, 6, true)
	local btns = {}
	local function paint()
		for k, b in pairs(btns) do
			b.BackgroundColor3 = k == method and MINT or T().Panel2
			b.TextColor3 = k == method and Color3.fromRGB(10, 20, 18) or T().Text
		end
	end
	for _, k in ipairs({ "Bank", "Cash" }) do
		local b = UI().button(pay, (k == "Bank" and "Bank  " or "Bar  ") .. money(data[k] or 0), "secondary", { Size = UDim2.new(0.5, -3, 1, 0), TextSize = 13 })
		btns[k] = b
		b.MouseButton1Click:Connect(function()
			method = k
			paint()
		end)
	end
	paint()
	UI().label(list, "Reicht die gewaehlte Zahlart nicht, wird die andere genutzt.", 11, { TextColor3 = T().Muted })
	local ok = UI().button(list, "Jetzt mieten  ·  " .. money(data.Price) .. " fuer die erste Minute", "primary", { BackgroundColor3 = MINT, TextColor3 = Color3.fromRGB(10, 20, 18) })
	local busy = false
	ok.MouseButton1Click:Connect(function()
		if busy then
			return
		end
		busy = true
		local res = ctxRef.Request("Lott.Rent", { Id = data.Id, Method = method })
		busy = false
		if res.ok then
			doClose()
		end
	end)
	UI().button(list, "Abbrechen", "secondary").MouseButton1Click:Connect(doClose)
end

local function endRental(after)
	local res = ctxRef.Request("Lott.End")
	if res.ok and after then
		after()
	end
end

function LT.Manage(ctx, data)
	ctxRef = ctx
	closeModal()
	modalGui = UI().screen("MiamiLottModal", 25)
	local _, content, doClose = UI().window(modalGui, "LOTT · Deine Miete", UDim2.fromOffset(380, 320), function()
		modalGui = nil
	end)
	UI().list(content, 6)
	UI().label(content, "🛴  " .. data.Id .. "  ·  Abrechnung laeuft", 18, { Font = T().FontBlack, TextColor3 = MINT })
	local dur = row(content, "Dauer", clock(now() - data.Start))
	row(content, "Bezahlte Minuten", tostring(data.Minutes))
	row(content, "Kosten bisher", money(data.Paid), MINT)
	task.spawn(function()
		while dur.Parent do
			dur.V.Text = clock(now() - data.Start)
			task.wait(1)
		end
	end)
	UI().button(content, "Miete beenden", "danger").MouseButton1Click:Connect(function()
		endRental(doClose)
	end)
	UI().button(content, "Weiterfahren", "secondary").MouseButton1Click:Connect(doClose)
end

-- Handy-App ------------------------------------------------------------------------------------------
local renderApp

local function mapCard(parent, data, onSelect)
	local H = ctxRef.Controllers.Phone.Helpers
	local c = H.card(parent, 250)
	c.LayoutOrder = 1
	c:FindFirstChildOfClass("UIPadding"):Destroy()
	c.ClipsDescendants = true
	local view = UI().new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ClipsDescendants = true, Parent = c })
	UI().corner(view, 12)
	local canvas = UI().new("Frame", { BorderSizePixel = 0, Parent = view })
	ctxRef.Controllers.CityMap.Build(canvas, BASE, { minimal = true })
	local scale = UI().new("UIScale", { Scale = ZOOMS[zoomIdx], Parent = canvas })
	local markers = UI().new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = view })
	local me = UI().new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.fromRGB(80, 170, 255), ZIndex = 30, Parent = markers })
	UI().corner(me, 6)
	UI().stroke(me, Color3.new(1, 1, 1), 2)

	local focus -- Weltpunkt in der Kartenmitte
	local buttons = {}
	local function place()
		local w, h = view.AbsoluteSize.X, view.AbsoluteSize.Y
		if w < 2 then
			w, h = 276, 250
		end
		local z = ZOOMS[zoomIdx]
		local root = ctxRef.Controllers.CityMap and game:GetService("Players").LocalPlayer.Character
		local hrp = root and root:FindFirstChild("HumanoidRootPart")
		local f = focus or (hrp and Vector2.new(hrp.Position.X, hrp.Position.Z)) or Vector2.zero
		local fp = ctxRef.Controllers.CityMap.ToMap(f.X, f.Y, BASE) * z
		local origin = Vector2.new(w / 2, h / 2) - fp
		canvas.Position = UDim2.fromOffset(origin.X, origin.Y)
		local function toView(x, zz)
			return origin + ctxRef.Controllers.CityMap.ToMap(x, zz, BASE) * z
		end
		if hrp then
			local p = toView(hrp.Position.X, hrp.Position.Z)
			me.Position = UDim2.fromOffset(p.X, p.Y)
		end
		for _, s in ipairs(data.Scooters) do
			local b = buttons[s.Id]
			if b then
				local p = toView(s.X, s.Z)
				b.Position = UDim2.fromOffset(p.X, p.Y)
				b.Visible = p.X > -10 and p.Y > -10 and p.X < w + 10 and p.Y < h + 10
			end
		end
	end
	for _, s in ipairs(data.Scooters) do
		local sel = s.Id == selectedId
		local col = s.Mine and Color3.fromRGB(255, 200, 60) or (s.Available and MINT or GREY)
		local b = UI().new("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(sel and 22 or 16, sel and 22 or 16), BackgroundColor3 = col, Text = "", AutoButtonColor = true, ZIndex = sel and 26 or 25, Parent = markers })
		UI().corner(b, 11)
		UI().stroke(b, sel and Color3.new(1, 1, 1) or Color3.fromRGB(10, 14, 18), sel and 2.5 or 1.5)
		UI().new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "L", Font = T().FontBlack, TextSize = sel and 12 or 9, TextColor3 = Color3.fromRGB(10, 20, 18), ZIndex = 27, Parent = b })
		buttons[s.Id] = b
		b.MouseButton1Click:Connect(function()
			onSelect(s)
		end)
	end
	-- Zoom und Zentrieren
	local tools = UI().new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(28, 94), ZIndex = 40, Parent = c })
	UI().list(tools, 4)
	for _, t in ipairs({ { "+", 1 }, { "−", -1 }, { "◎", 0 } }) do
		local b = UI().new("TextButton", { Size = UDim2.fromOffset(28, 28), BackgroundColor3 = Color3.fromRGB(14, 18, 24), BackgroundTransparency = 0.1, Text = t[1], Font = T().FontBlack, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), ZIndex = 41, Parent = tools })
		UI().corner(b, 8)
		b.MouseButton1Click:Connect(function()
			if t[2] == 0 then
				focus = nil
			else
				zoomIdx = math.clamp(zoomIdx + t[2], 1, #ZOOMS)
				scale.Scale = ZOOMS[zoomIdx]
			end
			place()
		end)
	end
	local legend = UI().new("TextLabel", { BackgroundColor3 = Color3.fromRGB(14, 18, 24), BackgroundTransparency = 0.2, Position = UDim2.new(0, 6, 1, -24), Size = UDim2.fromOffset(200, 18), Font = T().FontBold, TextSize = 10, TextColor3 = Color3.new(1, 1, 1), Text = "  ● frei   ● vermietet   ● deiner   ● du", RichText = true, ZIndex = 40, TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
	legend.Text = string.format('  <font color="#%s">●</font> frei  <font color="#6e7482">●</font> vermietet  <font color="#ffc83c">●</font> deiner  <font color="#50aaff">●</font> du', MINT:ToHex())
	UI().corner(legend, 6)
	local api = {}
	function api.Focus(s)
		focus = s and Vector2.new(s.X, s.Z) or nil
		place()
	end
	function api.Update(newData)
		data = newData
		for _, s in ipairs(data.Scooters) do
			local b = buttons[s.Id]
			if b then
				b.BackgroundColor3 = s.Mine and Color3.fromRGB(255, 200, 60) or (s.Available and MINT or GREY)
			end
		end
		place()
	end
	api.Place = place
	place()
	return api
end

local function detailCard(parent, s)
	local H = ctxRef.Controllers.Phone.Helpers
	local c = H.card(parent, 0)
	c.AutomaticSize = Enum.AutomaticSize.Y
	UI().list(c, 4)
	UI().label(c, "🛴  " .. s.Id, 16, { Font = T().FontBlack, TextColor3 = MINT })
	row(c, "Status", s.Mine and "Von dir gemietet" or (s.Available and "Verfuegbar" or "Vermietet"), s.Available and MINT or (s.Mine and Color3.fromRGB(255, 200, 60) or T().Danger))
	row(c, "Entfernung", s.Dist and (s.Dist .. " m") or "-")
	row(c, "Standort", district(s.X, s.Z))
	row(c, "Preis", money(Cfg.PricePerMinute) .. " / Min")
	UI().button(c, "Navigieren", "primary", { Size = UDim2.new(1, 0, 0, 32), TextSize = 13, BackgroundColor3 = MINT, TextColor3 = Color3.fromRGB(10, 20, 18) }).MouseButton1Click:Connect(function()
		navigate(s)
	end)
	if s.Available then
		H.small(c, "Mieten direkt am Roller mit [E].", 11, T().Muted)
	end
	return c
end

local function activeCard(parent, a, data)
	local H = ctxRef.Controllers.Phone.Helpers
	local c = H.card(parent, 0)
	c.AutomaticSize = Enum.AutomaticSize.Y
	c.BackgroundColor3 = Color3.fromRGB(16, 44, 38)
	UI().stroke(c, MINT, 1.5)
	UI().list(c, 4)
	UI().label(c, "● ABRECHNUNG LAEUFT", 13, { Font = T().FontBlack, TextColor3 = Color3.fromRGB(255, 90, 100) })
	UI().label(c, "🛴  " .. a.Id, 16, { Font = T().FontBlack, TextColor3 = MINT })
	local dur = row(c, "Dauer", clock(now() - a.Start))
	local mins = row(c, "Angefangene Minuten", tostring(a.Minutes))
	local cost = row(c, "Aktuelle Kosten", money(a.Paid), MINT)
	local nextL = row(c, "Naechste Abbuchung", "-")
	task.spawn(function()
		while dur.Parent do
			local cur = active or a
			local el = now() - cur.Start
			dur.V.Text = clock(el)
			mins.V.Text = tostring(cur.Minutes)
			cost.V.Text = money(cur.Paid)
			nextL.V.Text = string.format("in %ds  (+%s)", math.max(0, 60 - math.floor(el) % 60), money(Cfg.PricePerMinute))
			task.wait(1)
		end
	end)
	local mine
	for _, s in ipairs(data.Scooters) do
		if s.Mine then
			mine = s
		end
	end
	local btns = UI().new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), Parent = c })
	UI().list(btns, 6, true)
	if mine then
		UI().button(btns, "Zum Roller", "secondary", { Size = UDim2.new(0.5, -3, 1, 0), TextSize = 12 }).MouseButton1Click:Connect(function()
			navigate(mine)
		end)
	end
	UI().button(btns, "Miete beenden", "danger", { Size = UDim2.new(mine and 0.5 or 1, mine and -3 or 0, 1, 0), TextSize = 12 }).MouseButton1Click:Connect(function()
		endRental(function()
			renderApp()
		end)
	end)
	return c
end

local function historyCard(parent, data)
	local H = ctxRef.Controllers.Phone.Helpers
	local c = H.card(parent, 0)
	c.AutomaticSize = Enum.AutomaticSize.Y
	UI().list(c, 4)
	UI().label(c, "Letzte Fahrten", 14, { Font = T().FontBlack })
	row(c, "Fahrten gesamt", tostring(data.Rides or 0))
	row(c, "Ausgegeben gesamt", money(data.Total or 0), MINT)
	if #data.History == 0 then
		H.small(c, "Noch keine Fahrten.", 12)
	end
	for i, e in ipairs(data.History) do
		if i > 6 then
			break
		end
		local when = os.date("!%d.%m. %H:%M", e.Start)
		row(c, string.format("%s  ·  %s", e.Id, when), string.format("%s  ·  %s", clock(e.Duration), money(e.Cost)))
	end
	return c
end

renderApp = function()
	local Phone = ctxRef.Controllers.Phone
	local H = Phone.Helpers
	local content = H.appHeader("LOTT", MINT)
	local res = ctxRef.Request("Lott.List", nil, true)
	if not res.ok then
		H.small(content, "LOTT ist gerade nicht erreichbar.", 13)
		return
	end
	local data = res.data
	active = data.Active
	updatePill()
	local avail = 0
	for _, s in ipairs(data.Scooters) do
		if s.Available then
			avail += 1
		end
	end
	H.small(content, string.format("%d von %d Rollern frei  ·  %s / angefangene Minute", avail, #data.Scooters, money(data.Price)), 12, T().Muted)
	local detailHolder = UI().new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = content })
	UI().list(detailHolder, 0)
	local map
	local function select(s)
		selectedId = s and s.Id
		for _, ch in ipairs(detailHolder:GetChildren()) do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		if s then
			detailCard(detailHolder, s)
			map.Focus(s)
		end
	end
	map = mapCard(content, data, select)
	if data.Active then
		activeCard(content, data.Active, data).LayoutOrder = 2
	end
	-- naechste Roller
	local near = H.card(content, 0)
	near.AutomaticSize = Enum.AutomaticSize.Y
	near.LayoutOrder = 4
	UI().list(near, 4)
	UI().label(near, "In deiner Naehe", 14, { Font = T().FontBlack })
	local shown = 0
	for _, s in ipairs(data.Scooters) do
		if s.Available and shown < 5 then
			shown += 1
			local b = UI().button(near, string.format("%s   ·   %s m   ·   %s", s.Id, s.Dist or "?", district(s.X, s.Z)), "secondary", { Size = UDim2.new(1, 0, 0, 30), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left })
			UI().pad(b, 8)
			b.MouseButton1Click:Connect(function()
				select(s)
			end)
		end
	end
	if shown == 0 then
		H.small(near, "Gerade sind alle Roller vermietet.", 12)
	end
	historyCard(content, data).LayoutOrder = 5
	local rules = H.card(content, 0)
	rules.AutomaticSize = Enum.AutomaticSize.Y
	rules.LayoutOrder = 6
	UI().list(rules, 3)
	UI().label(rules, "So funktioniert's", 14, { Font = T().FontBlack })
	for _, r in ipairs(data.Rules or {}) do
		H.small(rules, "•  " .. r, 11)
	end
	if selectedId then
		for _, s in ipairs(data.Scooters) do
			if s.Id == selectedId then
				select(s)
			end
		end
	end
	-- Live-Aktualisierung nur solange die App sichtbar ist: Positionen alle 4 s, eigener Punkt jede halbe Sekunde
	task.spawn(function()
		local t = 0
		while content.Parent and Phone.IsOpen() do
			task.wait(0.5)
			t += 0.5
			if not content.Parent then
				break
			end
			if t >= Cfg.ListRefresh then
				t = 0
				local r = ctxRef.Request("Lott.List", nil, true)
				if r.ok and content.Parent then
					local wasActive = active ~= nil
					active = r.data.Active
					if wasActive ~= (active ~= nil) then
						renderApp()
						return
					end
					data = r.data
					map.Update(data)
				end
			else
				map.Place()
			end
		end
	end)
end

-- Server-Ereignisse ---------------------------------------------------------------------------------------
function LT.State(ctx, data)
	ctxRef = ctx
	if data.Active then
		active = { Id = data.Id, Start = data.Start, Minutes = data.Minutes, Paid = data.Paid }
	else
		active = nil
		if data.Last then
			UI().toast(string.format("LOTT-Fahrt beendet: %s, %d Min., %s", clock(data.Last.Duration), data.Last.Minutes, money(data.Last.Cost)), "success")
		end
		if modalGui then
			closeModal()
		end
	end
	updatePill()
end

function LT.Start(ctx)
	ctxRef = ctx
	buildPill()
	local Phone = ctx.Controllers.Phone
	-- App nach "Karte" einsortieren (sonst ans Ende)
	local app = { Id = "Lott", Name = "LOTT", Icon = "🛴", Color = MINT, Open = function()
		renderApp()
	end, Badge = function()
		return active and 1 or 0
	end }
	local at = #Phone.Apps + 1
	for i, a in ipairs(Phone.Apps) do
		if a.Id == "Map" then
			at = i + 1
		end
	end
	table.insert(Phone.Apps, at, app)
	-- laufende Miete nach Neuladen der Oberflaeche wiederherstellen
	task.delay(3, function()
		local r = ctx.Request("Lott.List", nil, true)
		if r.ok and r.data.Active then
			active = r.data.Active
			updatePill()
		end
	end)
end

return LT
