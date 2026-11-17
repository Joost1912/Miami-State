-- Arbeits-Dashboard (Prompt 11): JOBS, KARRIERE, UNTERNEHMEN, MITARBEITER, FINANZEN in einem Fenster
-- (Handy-Apps oeffnen den passenden Reiter). Dazu: Auftragskarte unter dem Geld-Block (HUD bleibt unveraendert),
-- lokale Zielmarkierung + Halte-Prompt (nur fuer den eigenen Auftrag sichtbar), Rechnungsdialog.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local W = {}
local ctxRef, gui, closeFn
local state = { Tab = "Jobs" }
local hudGui, taskCard, taskTitle, taskStep, taskInfo, beacon, currentTask

local function UI()
	return ctxRef.UI
end
local function T()
	return ctxRef.UI.Theme
end
local function money(n)
	return ctxRef.Format.money(n or 0)
end

function W.Close()
	if closeFn then
		closeFn()
	end
end

local function clear(f)
	for _, c in ipairs(f:GetChildren()) do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

local function section(parent, text, order)
	return UI().label(parent, string.upper(text), 11, { LayoutOrder = order, Font = T().FontBold, TextColor3 = T().Accent })
end
local function card(parent, order, h)
	local c = UI().new("Frame", { LayoutOrder = order, Size = UDim2.new(1, -6, 0, h or 60), BackgroundColor3 = T().Panel2, Parent = parent })
	UI().corner(c, 10)
	UI().pad(c, 12)
	return c
end
local function text(parent, t, size, color, props)
	local p = { TextColor3 = color or T().Muted, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true }
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return UI().label(parent, t, size or 12, p)
end
local function row(parent, order, h)
	local f = UI().new("Frame", { LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, h or 32), Parent = parent })
	UI().list(f, 6, true)
	return f
end
local function btn(parent, label, style, fn, w)
	local b = UI().button(parent, label, style, { Size = UDim2.fromOffset(w or 0, 30), AutomaticSize = w and Enum.AutomaticSize.None or Enum.AutomaticSize.X, TextSize = 12 })
	UI().new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = b })
	b.MouseButton1Click:Connect(fn)
	return b
end
local function bar(parent, order, frac, color)
	local bg = UI().new("Frame", { LayoutOrder = order, BorderSizePixel = 0, Size = UDim2.new(1, -6, 0, 8), BackgroundColor3 = T().Panel2, Parent = parent })
	UI().corner(bg, 4)
	local f = UI().new("Frame", { BorderSizePixel = 0, Size = UDim2.fromScale(math.clamp(frac, 0.02, 1), 1), BackgroundColor3 = color or T().Accent, Parent = bg })
	UI().corner(f, 4)
	UI().new("UIGradient", { Color = ColorSequence.new(T().Accent, T().Accent2), Parent = f })
end
local function nav(x, z, label, y)
	ctxRef.Controllers.CityMap.Nav.SetTarget(x, z, label, y)
end

-- JOBS ----------------------------------------------------------------------------------------------
local function renderJobs(body)
	local res = ctxRef.Request("Work.Info", nil, true)
	if not res.ok then
		return
	end
	local d = res.data
	state.Info = d
	local list = UI().scroll(body)
	UI().list(list, 8)
	local o = 0
	local function nx()
		o += 1
		return o
	end
	-- aktueller Status
	local cur = card(list, nx(), 96)
	local job = d.Current ~= "" and ctxRef.Config.Work.Jobs[d.Current]
	UI().new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Font = T().FontBlack, TextSize = 18, TextColor3 = T().Text, TextXAlignment = Enum.TextXAlignment.Left, Text = job and (job.Icon .. "  " .. job.Name .. " · " .. job.Company) or "Kein ziviler Beruf", Parent = cur })
	UI().new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 16), Font = T().Font, TextSize = 12, TextColor3 = d.OnShift and T().Success or T().Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = d.OnShift and ("IM DIENST" .. (d.Task and ("  ·  " .. d.Task.Label) or "")) or (job and "Nicht im Dienst - Schicht am Depot beginnen" or "Waehle unten einen Beruf"), Parent = cur })
	UI().new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 16), Font = T().Font, TextSize = 12, TextColor3 = T().Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("Stufe %d  ·  Lohnbonus +%d%%  ·  diese Stunde %s / %s", d.Level, math.floor(d.PayBonus * 100), money(d.HourEarned), money(d.HourlyCap)), Parent = cur })
	local r = UI().new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 30), Parent = cur })
	UI().list(r, 6, true)
	if d.OnShift then
		btn(r, "Schicht beenden", "danger", function()
			ctxRef.Request("Work.EndShift")
			W.Render()
		end)
		btn(r, "Neuer Auftrag", "secondary", function()
			ctxRef.Request("Work.Skip")
		end)
		if d.Current == "Mechanic" then
			btn(r, "Fahrzeug warten", "secondary", function()
				ctxRef.Request("Work.Service")
			end)
			btn(r, "Rechnung stellen", "primary", function()
				state.Tab = "Invoice"
				W.Render()
			end)
		end
	elseif job then
		btn(r, "Depot markieren", "primary", function()
			ctxRef.Request("Work.Select", { Job = d.Current })
		end)
		btn(r, "Beruf aufgeben", "secondary", function()
			ctxRef.Request("Work.Quit")
			W.Render()
		end)
	end
	btn(r, "Fraktionen & Rollen", "secondary", function()
		W.Close()
		ctxRef.Open("Jobs")
	end)
	section(list, "Berufe", nx())
	for _, j in ipairs(d.Jobs) do
		local c = card(list, nx(), 0)
		c.AutomaticSize = Enum.AutomaticSize.Y
		UI().list(c, 3)
		local head = UI().new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Parent = c })
		UI().new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.7, 0, 1, 0), Font = T().FontBold, TextSize = 15, TextColor3 = j.Unlocked and T().Text or T().Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = j.Icon .. "  " .. j.Name .. "  ·  " .. j.Company, Parent = head })
		UI().new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.3, 0, 1, 0), Font = T().FontBold, TextSize = 12, TextColor3 = j.Unlocked and T().Success or T().Warning, TextXAlignment = Enum.TextXAlignment.Right, Text = j.Unlocked and j.Hourly or ("ab Stufe " .. j.Level), Parent = head })
		text(c, j.Desc, 12, T().Text)
		text(c, "Voraussetzung: " .. j.Requires .. "   ·   Ort: " .. j.Location, 11)
		text(c, "Aufgaben: " .. table.concat(j.Tasks, " → ") .. (j.Uniform and "   ·   Arbeitskleidung wird gestellt" or ""), 11)
		text(c, string.format("Fortschritt: %d Auftraege, %s verdient", j.Done, money(j.Earned)), 11, T().Accent)
		if j.Unlocked and j.Id ~= d.Current then
			local rr = UI().new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), Parent = c })
			UI().list(rr, 6, true)
			btn(rr, "Diesen Beruf waehlen", "primary", function()
				ctxRef.Request("Work.Select", { Job = j.Id })
				W.Render()
			end)
		end
	end
end

-- RECHNUNG (Mechaniker) -----------------------------------------------------------------------------
local function renderInvoice(body)
	local list = UI().scroll(body)
	UI().list(list, 8)
	section(list, "Kunde abrechnen (Spieler in der Naehe)", 1)
	local me = Players.LocalPlayer
	local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	local amountBox = UI().input(list, "Betrag in $ (10 - 5000)", { LayoutOrder = 2 })
	local reasonBox = UI().input(list, "Leistung (z.B. Reparatur, Wartung)", { LayoutOrder = 3 })
	local o = 3
	for _, p in ipairs(Players:GetPlayers()) do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if p ~= me and r and root and (r.Position - root.Position).Magnitude < 20 then
			o += 1
			local c = card(list, o, 50)
			UI().new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 1, 0), Font = T().FontBold, TextSize = 14, TextColor3 = T().Text, TextXAlignment = Enum.TextXAlignment.Left, Text = p:GetAttribute("RPName") ~= "" and p:GetAttribute("RPName") or p.Name, Parent = c })
			local b = btn(c, "Rechnung senden", "primary", function()
				ctxRef.Request("Work.Invoice", { Target = p.UserId, Amount = tonumber(amountBox.Text), Reason = reasonBox.Text })
			end)
			b.AnchorPoint = Vector2.new(1, 0.5)
			b.Position = UDim2.new(1, 0, 0.5, 0)
		end
	end
	if o == 3 then
		text(list, "Kein Kunde in der Naehe (20 Studs).", 12, T().Muted, { LayoutOrder = 4 })
	end
	local back = row(list, 99)
	btn(back, "Zurueck", "secondary", function()
		state.Tab = "Jobs"
		W.Render()
	end)
end

-- KARRIERE ------------------------------------------------------------------------------------------
local function renderCareer(body)
	local res = ctxRef.Request("Work.Info", nil, true)
	if not res.ok then
		return
	end
	local d = res.data
	local list = UI().scroll(body)
	UI().list(list, 8)
	local c = card(list, 1, 110)
	UI().new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Font = T().FontBlack, TextSize = 30, TextColor3 = T().Text, TextXAlignment = Enum.TextXAlignment.Left, Text = "Stufe " .. d.Level, Parent = c })
	UI().new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 16), Font = T().Font, TextSize = 12, TextColor3 = T().Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("%d XP  ·  naechste Stufe bei %d XP  ·  Lohnbonus +%d%%  ·  gesamt verdient %s", d.XP, d.NextXP, math.floor(d.PayBonus * 100), money(d.Earned)), Parent = c })
	local inner = UI().new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 6, 0, 12), Parent = c })
	UI().list(inner, 0)
	bar(inner, 1, d.Level >= d.MaxLevel and 1 or (d.XP - d.LevelXP) / math.max(1, d.NextXP - d.LevelXP))
	section(list, "Freischaltungen", 2)
	for i, u in ipairs(d.Unlocks) do
		local uc = card(list, 2 + i, 40)
		UI().new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = T().FontBold, TextSize = 13, TextColor3 = d.Level >= u.Level and T().Success or T().Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = (d.Level >= u.Level and "✓  " or "🔒  ") .. "Stufe " .. u.Level .. ": " .. u.Text, Parent = uc })
	end
	section(list, "Jobfortschritt", 20)
	for i, j in ipairs(d.Jobs) do
		local jc = card(list, 20 + i, 40)
		UI().new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = T().Font, TextSize = 13, TextColor3 = T().Text, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("%s  %s:  %d Auftraege  ·  %s", j.Icon, j.Name, j.Done, money(j.Earned)), Parent = jc })
	end
	text(list, "XP gibt es fuer abgeschlossene Auftraege, Lieferungen, Dienstleistungen (Rechnungen), Arbeit in Unternehmen und Unternehmensfuehrung.", 11, T().Muted, { LayoutOrder = 40 })
end

-- UNTERNEHMEN ---------------------------------------------------------------------------------------
local function renderBusiness(body)
	local res = ctxRef.Request("Business.List", nil, true)
	if not res.ok then
		return
	end
	local d = res.data
	local left = UI().scroll(body, { Size = UDim2.new(0.42, -6, 1, 0) })
	UI().list(left, 6)
	local right = UI().scroll(body, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.58, -6, 1, 0) })
	UI().list(right, 8)
	local function detail(b)
		clear(right)
		state.Business = b.Id
		local o = 0
		local function nx()
			o += 1
			return o
		end
		text(right, b.TypeName, 11, T().Accent, { LayoutOrder = nx(), Font = T().FontBold })
		text(right, b.Name, 22, T().Text, { LayoutOrder = nx(), Font = T().FontBlack })
		text(right, string.format("Status: %s  ·  Inhaber: %s  ·  Mitarbeiter: %d  ·  %s", b.Status, b.Owned and b.Owner or "-", b.Employees, b.Hours), 12, T().Muted, { LayoutOrder = nx() })
		text(right, string.format("Kaufpreis %s  ·  Wert %s  ·  Betriebskosten %s / Tag", money(b.Price), money(b.Value), money(b.Upkeep)), 12, T().Text, { LayoutOrder = nx() })
		local r1 = row(right, nx())
		btn(r1, "Auf Karte zeigen", "secondary", function()
			nav(b.X, b.Z, b.Name, b.Y)
			W.Close()
		end)
		if not b.Owned then
			btn(r1, "Kaufen " .. money(b.Price), "primary", function()
				if ctxRef.Request("Business.Buy", { Id = b.Id, TxId = ctxRef.TxId() }).ok then
					W.Render()
				end
			end)
		elseif b.Role == 0 and not d.Employer then
			btn(r1, "Bewerben", "primary", function()
				ctxRef.Request("Business.Apply", { Id = b.Id })
			end)
		end
		if b.Role > 0 then
			local on = d.OnDuty == b.Id
			btn(r1, on and "Ausstempeln" or "Einstempeln", on and "danger" or "primary", function()
				ctxRef.Request("Business.Clock", { Id = b.Id, On = not on })
				W.Render()
			end)
		end
		if b.Account ~= nil then
			section(right, "Finanzen", nx())
			local f = card(right, nx(), 70)
			UI().new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), Font = T().FontBlack, TextSize = 22, TextColor3 = b.Account >= 0 and T().Success or T().Danger, TextXAlignment = Enum.TextXAlignment.Left, Text = money(b.Account), Parent = f })
			UI().new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 16), Font = T().Font, TextSize = 12, TextColor3 = T().Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("Einnahmen %s  ·  Ausgaben %s", money(b.Revenue), money(b.Expenses)), Parent = f })
			if b.Role >= 5 then
				local amt = UI().input(right, "Betrag in $", { LayoutOrder = nx() })
				local r2 = row(right, nx())
				btn(r2, "Einzahlen", "secondary", function()
					ctxRef.Request("Business.Deposit", { Id = b.Id, Amount = tonumber(amt.Text), TxId = ctxRef.TxId() })
					W.Render()
				end)
				if b.Role >= 6 then
					btn(r2, "Auszahlen", "secondary", function()
						ctxRef.Request("Business.Withdraw", { Id = b.Id, Amount = tonumber(amt.Text), TxId = ctxRef.TxId() })
						W.Render()
					end)
				end
				section(right, "Betrieb", nx())
				local r3 = row(right, nx())
				btn(r3, b.Open and "Geoeffnet" or "Geschlossen", b.Open and "primary" or "danger", function()
					ctxRef.Request("Business.Settings", { Id = b.Id, Open = not b.Open })
					W.Render()
				end)
				btn(r3, "Oeffnet " .. b.OpenHour .. ":00 ±", "secondary", function()
					ctxRef.Request("Business.Settings", { Id = b.Id, OpenHour = (b.OpenHour + 1) % 24 })
					W.Render()
				end)
				btn(r3, "Schliesst " .. b.CloseHour .. ":00 ±", "secondary", function()
					ctxRef.Request("Business.Settings", { Id = b.Id, CloseHour = (b.CloseHour + 1) % 24 })
					W.Render()
				end)
				if b.Prices then
					local r4 = row(right, nx())
					text(r4, string.format("Preise x%.2f", b.PriceFactor), 12, T().Text, { Size = UDim2.fromOffset(100, 30), AutomaticSize = Enum.AutomaticSize.None })
					for _, dlt in ipairs({ -0.05, 0.05 }) do
						btn(r4, dlt > 0 and "+5%" or "-5%", "secondary", function()
							ctxRef.Request("Business.Settings", { Id = b.Id, PriceFactor = b.PriceFactor + dlt })
							W.Render()
						end)
					end
				end
				if b.EntryFeeSupported then
					local r5 = row(right, nx())
					text(r5, "Eintritt " .. money(b.EntryFee), 12, T().Text, { Size = UDim2.fromOffset(100, 30), AutomaticSize = Enum.AutomaticSize.None })
					for _, dlt in ipairs({ -10, 10 }) do
						btn(r5, (dlt > 0 and "+" or "") .. dlt, "secondary", function()
							ctxRef.Request("Business.Settings", { Id = b.Id, EntryFee = math.max(0, b.EntryFee + dlt) })
							W.Render()
						end)
					end
				end
			end
			if b.Log and #b.Log > 0 then
				section(right, "Buchungen", nx())
				for i = 1, math.min(8, #b.Log) do
					local l = b.Log[i]
					text(right, string.format("%s  %s  %s", os.date("%d.%m %H:%M", l.T), l.X, l.A ~= 0 and money(l.A) or ""), 11, l.A < 0 and T().Danger or T().Muted, { LayoutOrder = nx() })
				end
			end
			if b.Role >= 6 then
				local r6 = row(right, nx())
				local sb
				sb = btn(r6, "Unternehmen verkaufen", "danger", function()
					if sb.Text ~= "Wirklich verkaufen?" then
						sb.Text = "Wirklich verkaufen?"
						return
					end
					ctxRef.Request("Business.Sell", { Id = b.Id })
					W.Render()
				end)
			end
		end
	end
	local selected
	for i, b in ipairs(d.Businesses) do
		local c = UI().new("TextButton", { LayoutOrder = i, AutoButtonColor = false, Text = "", Size = UDim2.new(1, -6, 0, 54), BackgroundColor3 = T().Panel2, Parent = left })
		UI().corner(c, 10)
		UI().new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 18), Font = T().FontBold, TextSize = 13, TextColor3 = T().Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = b.Name, Parent = c })
		UI().new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 16), Font = T().Font, TextSize = 11, TextColor3 = b.Role > 0 and T().Accent or (b.Owned and T().Muted or T().Success), TextXAlignment = Enum.TextXAlignment.Left, Text = b.Role >= 6 and "Dein Unternehmen" or (b.Role > 0 and "Arbeitgeber") or (b.Owned and (b.TypeName .. " · " .. b.Status)) or (b.TypeName .. " · zu verkaufen " .. money(b.Price)), Parent = c })
		c.MouseButton1Click:Connect(function()
			detail(b)
		end)
		if b.Id == state.Business or (not state.Business and i == 1) then
			selected = b
		end
	end
	if selected then
		detail(selected)
	end
end

-- MITARBEITER ---------------------------------------------------------------------------------------
local function renderEmployees(body)
	local res = ctxRef.Request("Business.List", nil, true)
	if not res.ok then
		return
	end
	local d = res.data
	local list = UI().scroll(body)
	UI().list(list, 8)
	local o = 0
	local function nx()
		o += 1
		return o
	end
	section(list, "Meine Anstellung", nx())
	if d.Employer then
		local c = card(list, nx(), 70)
		UI().new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Font = T().FontBold, TextSize = 15, TextColor3 = T().Text, TextXAlignment = Enum.TextXAlignment.Left, Text = d.EmployerName .. "  ·  " .. d.Positions[d.Position].Name, Parent = c })
		local r = UI().new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 30), Parent = c })
		UI().list(r, 6, true)
		local on = d.OnDuty == d.Employer
		btn(r, on and "Ausstempeln" or "Einstempeln (vor Ort)", on and "danger" or "primary", function()
			ctxRef.Request("Business.Clock", { Id = d.Employer, On = not on })
			W.Render()
		end)
		local kb
		kb = btn(r, "Kuendigen", "secondary", function()
			if kb.Text ~= "Wirklich kuendigen?" then
				kb.Text = "Wirklich kuendigen?"
				return
			end
			ctxRef.Request("Business.Resign")
			W.Render()
		end)
	else
		text(list, "Keine Anstellung. Bewerben: Reiter UNTERNEHMEN → Unternehmen waehlen → Bewerben.", 12, T().Muted, { LayoutOrder = nx() })
	end
	for _, b in ipairs(d.Businesses) do
		if b.Role >= d.Rights.Hire then
			local info = ctxRef.Request("Business.Info", { Id = b.Id }, true)
			local x = info.ok and info.data
			if x then
				section(list, x.Name .. "  ·  Personal", nx())
				for _, e in ipairs(x.Staff or {}) do
					local c = card(list, nx(), 76)
					UI().new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Font = T().FontBold, TextSize = 14, TextColor3 = T().Text, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("%s  ·  %s", e.Name, e.PositionName), Parent = c })
					UI().new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 14), Font = T().Font, TextSize = 11, TextColor3 = e.OnDuty and T().Success or T().Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("Gehalt %s / 10 Min  ·  %s  ·  seit %s", money(e.Salary), e.OnDuty and "im Dienst" or (e.Online and "online" or "offline"), os.date("%d.%m.%Y", e.Hired)), Parent = c })
					local r = UI().new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 30), Parent = c })
					UI().list(r, 6, true)
					if b.Role >= d.Rights.Promote then
						if e.Position < #d.Positions and e.Position + 1 < b.Role then
							btn(r, "Befoerdern", "primary", function()
								ctxRef.Request("Business.Staff", { Id = b.Id, Do = "Promote", Target = e.UserId, Position = e.Position + 1 })
								W.Render()
							end)
						end
						if e.Position > 1 then
							btn(r, "Zurueckstufen", "secondary", function()
								ctxRef.Request("Business.Staff", { Id = b.Id, Do = "Promote", Target = e.UserId, Position = e.Position - 1 })
								W.Render()
							end)
						end
						for _, dlt in ipairs({ -20, 20 }) do
							btn(r, "Gehalt " .. (dlt > 0 and "+" or "") .. dlt, "secondary", function()
								ctxRef.Request("Business.Staff", { Id = b.Id, Do = "Salary", Target = e.UserId, Salary = math.max(0, e.Salary + dlt) })
								W.Render()
							end)
						end
						btn(r, "Entlassen", "danger", function()
							ctxRef.Request("Business.Staff", { Id = b.Id, Do = "Fire", Target = e.UserId })
							W.Render()
						end)
					end
				end
				if #(x.Staff or {}) == 0 then
					text(list, "Noch keine Mitarbeiter.", 12, T().Muted, { LayoutOrder = nx() })
				end
				if x.Applications and #x.Applications > 0 then
					section(list, "Bewerbungen", nx())
					for _, a in ipairs(x.Applications) do
						local c = card(list, nx(), 50)
						UI().new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.5, 0, 1, 0), Font = T().FontBold, TextSize = 13, TextColor3 = T().Text, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("%s (Stufe %d)", a.Name, a.Level or 1), Parent = c })
						local r = UI().new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0.5, 0, 0, 30), Parent = c })
						local l = UI().list(r, 6, true)
						l.HorizontalAlignment = Enum.HorizontalAlignment.Right
						btn(r, "Als Praktikant", "secondary", function()
							ctxRef.Request("Business.Staff", { Id = b.Id, Do = "Hire", Target = a.UserId, Position = 1 })
							W.Render()
						end)
						btn(r, "Als Mitarbeiter", "primary", function()
							ctxRef.Request("Business.Staff", { Id = b.Id, Do = "Hire", Target = a.UserId, Position = 2 })
							W.Render()
						end)
						btn(r, "Ablehnen", "danger", function()
							ctxRef.Request("Business.Staff", { Id = b.Id, Do = "Reject", Target = a.UserId })
							W.Render()
						end)
					end
				end
			end
		end
	end
	section(list, "Positionen", 900)
	for i, p in ipairs(d.Positions) do
		text(list, string.format("%d. %s - bis %s / 10 Min%s", i, p.Name, money(p.MaxSalary), p.MinLevel and (" (ab Stufe " .. p.MinLevel .. ")") or ""), 11, T().Muted, { LayoutOrder = 900 + i })
	end
	text(list, "Inhaber: alle Rechte · Manager: befoerdern, entlassen, Gehaelter, Preise · Supervisor: Bewerbungen annehmen, Finanzen einsehen.", 11, T().Muted, { LayoutOrder = 950 })
end

-- FINANZEN ------------------------------------------------------------------------------------------
local function renderFinances(body)
	local p = ctxRef.Profile
	if not p then
		return
	end
	local list = UI().scroll(body)
	UI().list(list, 8)
	local top = UI().new("Frame", { LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 64), Parent = list })
	local g = UI().new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0, 64), CellPadding = UDim2.fromOffset(8, 0), Parent = top })
	local _ = g
	local info = ctxRef.Request("Work.Info", nil, true)
	UI().stat(top, "Bargeld", money(p.Money.Cash), T().Success)
	UI().stat(top, "Bankkonto", money(p.Money.Bank), T().Accent)
	UI().stat(top, "Verdienst Arbeit", money(info.ok and info.data.Earned or 0))
	section(list, "Laufende Kosten", 2)
	local o = 2
	for _, prop in ipairs(p.Properties.Owned or {}) do
		o += 1
		local tier = ctxRef.Config.Properties.Tiers[prop.Tier]
		text(list, string.format("🏠 %s (%s): %s", prop.Number, prop.Mode == "Rent" and "Miete" or "Eigentum", prop.Mode == "Rent" and (money(tier and tier.Rent or 0) .. " / Woche") or "keine Miete"), 12, T().Text, { LayoutOrder = o })
	end
	o += 1
	text(list, string.format("🚗 %d Fahrzeug(e) - Kosten: Tanken, Tuning, Abschleppen", #(p.Vehicles.Owned or {})), 12, T().Text, { LayoutOrder = o })
	local biz = ctxRef.Request("Business.List", nil, true)
	if biz.ok then
		for _, b in ipairs(biz.data.Businesses) do
			if b.Role >= 6 then
				o += 1
				text(list, string.format("🏢 %s: Konto %s · Betriebskosten %s / Tag · %s", b.Name, money(b.Account), money(b.Upkeep), b.Status), 12, T().Text, { LayoutOrder = o })
			end
		end
	end
	o += 1
	section(list, "Preisuebersicht", o)
	for _, h in ipairs(ctxRef.Config.Work.CostHints) do
		o += 1
		text(list, h[1] .. ": " .. h[2], 11, T().Muted, { LayoutOrder = o })
	end
	o += 1
	section(list, "Letzte Kontobewegungen", o)
	for i = 1, math.min(15, #p.Money.History) do
		local h = p.Money.History[i]
		o += 1
		text(list, string.format("%s  %s  %s%s", os.date("%d.%m %H:%M", h.T), h.K .. (h.N ~= "" and (" · " .. h.N) or ""), h.A >= 0 and "+" or "", money(h.A)), 11, h.A >= 0 and T().Success or T().Danger, { LayoutOrder = o })
	end
end

-- Fenster -------------------------------------------------------------------------------------------
local TABS = { { "Jobs", "JOBS" }, { "Career", "KARRIERE" }, { "Business", "UNTERNEHMEN" }, { "Employees", "MITARBEITER" }, { "Finances", "FINANZEN" } }
function W.Render()
	if not gui or not state.Body then
		return
	end
	for id, b in pairs(state.TabButtons) do
		local on = id == state.Tab or (state.Tab == "Invoice" and id == "Jobs")
		b.BackgroundColor3 = on and T().Accent or T().Panel2
		b.TextColor3 = on and T().Bg or T().Text
	end
	clear(state.Body)
	local fn = ({ Jobs = renderJobs, Career = renderCareer, Business = renderBusiness, Employees = renderEmployees, Finances = renderFinances, Invoice = renderInvoice })[state.Tab]
	if fn then
		fn(state.Body)
	end
end

function W.Open(ctx, data)
	ctxRef = ctx
	data = data or {}
	gui = UI().screen("MiamiWork", 20)
	state = { Tab = data.Tab or "Jobs", Business = data.Business, TabButtons = {} }
	local _, content, doClose = UI().window(gui, "Arbeit & Wirtschaft", UDim2.fromOffset(800, 560), function()
		gui:Destroy()
		gui, closeFn = nil, nil
		ctx.Closed("Work")
	end)
	closeFn = doClose
	local tabs = UI().new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), Parent = content })
	UI().list(tabs, 6, true)
	for _, t in ipairs(TABS) do
		local b = UI().button(tabs, t[2], "secondary", { Size = UDim2.fromOffset(148, 32), TextSize = 12 })
		state.TabButtons[t[1]] = b
		b.MouseButton1Click:Connect(function()
			state.Tab = t[1]
			W.Render()
		end)
	end
	state.Body = UI().new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), Parent = content })
	W.Render()
end

-- Auftragskarte + lokale Markierung -----------------------------------------------------------------
local function clearBeacon()
	if beacon then
		beacon:Destroy()
		beacon = nil
	end
end

local function makeBeacon(data)
	clearBeacon()
	local m = Instance.new("Model")
	m.Name = "WorkBeacon"
	local pos = Vector3.new(data.X, data.Y, data.Z)
	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
	ring.Size = Vector3.new(0.3, data.Radius * 1.4, data.Radius * 1.4)
	ring.CFrame = CFrame.new(pos.X, pos.Y - 1.5, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Material = Enum.Material.Neon
	ring.Color = data.Kind == "Hold" and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(64, 224, 255)
	ring.Transparency = 0.55
	ring.Parent = m
	local beam = Instance.new("Part")
	beam.Name = "Beam"
	beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch = true, false, false, false
	beam.Size = Vector3.new(1, 60, 1)
	beam.CFrame = CFrame.new(pos.X, pos.Y + 28, pos.Z)
	beam.Material = Enum.Material.Neon
	beam.Color = ring.Color
	beam.Transparency = 0.6
	beam.Parent = m
	if data.Kind == "Hold" then
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = data.Action or "Ausfuehren"
		pr.ObjectText = "Auftrag"
		pr.HoldDuration = data.Hold or 1
		pr.MaxActivationDistance = math.max(8, data.Radius)
		pr.RequiresLineOfSight = false
		pr.KeyboardKeyCode = Enum.KeyCode.E
		pr.Parent = ring
		local id = data.Id
		pr.Triggered:Connect(function()
			ctxRef.Request("Work.Action", { Id = id }, true)
		end)
	end
	m.Parent = workspace
	beacon = m
end

function W.Task(ctx, data)
	ctxRef = ctx
	if data.Clear then
		clearBeacon()
		currentTask = nil
		taskCard.Visible = data.Between == true
		if data.Between then
			taskTitle.Text = "Auftrag erledigt"
			taskStep.Text = "Naechster Auftrag folgt ..."
			taskInfo.Text = ""
		end
		local Nav = ctx.Controllers.CityMap.Nav
		if Nav.Target and Nav.WorkTarget then
			Nav.WorkTarget = nil
			Nav.Clear(true)
		end
		return
	end
	currentTask = data
	taskCard.Visible = true
	taskTitle.Text = data.Title or ""
	taskStep.Text = string.format("%d/%d  ·  %s", data.Step, data.Steps, data.Label or "")
	taskInfo.Text = data.Info or ""
	makeBeacon(data)
	local Nav = ctx.Controllers.CityMap.Nav
	Nav.SetTarget(data.X, data.Z, data.Label, data.Y)
	Nav.WorkTarget = true
end

function W.Done(ctx, data)
	ctx.UI.toast(data.Text, "success")
end

function W.Invoice(ctx, data)
	local UI_, T_ = ctx.UI, ctx.UI.Theme
	local scr = UI_.screen("MiamiInvoice", 40)
	local f = UI_.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(360, 190), BackgroundColor3 = T_.Panel, Parent = scr })
	UI_.corner(f, 14)
	UI_.stroke(f, T_.Accent, 1, 0.4)
	UI_.pad(f, 16)
	UI_.list(f, 8)
	UI_.label(f, "RECHNUNG", 12, { Font = T_.FontBold, TextColor3 = T_.Accent })
	UI_.label(f, string.format("%s: %s", data.From, ctx.Format.money(data.Amount)), 18, { Font = T_.FontBlack })
	UI_.label(f, data.Reason, 13, { TextColor3 = T_.Muted })
	local r = UI_.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Parent = f })
	UI_.list(r, 6, true)
	local function answer(accept, method)
		scr:Destroy()
		ctx.Request("Work.PayInvoice", { Id = data.Id, Accept = accept, Method = method })
	end
	UI_.button(r, "Bar zahlen", "primary", { Size = UDim2.fromOffset(100, 34), TextSize = 12 }).MouseButton1Click:Connect(function()
		answer(true, "Cash")
	end)
	UI_.button(r, "Karte", "secondary", { Size = UDim2.fromOffset(90, 34), TextSize = 12 }).MouseButton1Click:Connect(function()
		answer(true, "Bank")
	end)
	UI_.button(r, "Ablehnen", "danger", { Size = UDim2.fromOffset(100, 34), TextSize = 12 }).MouseButton1Click:Connect(function()
		answer(false)
	end)
	task.delay(110, function()
		if scr.Parent then
			scr:Destroy()
		end
	end)
end

function W.Start(ctx)
	ctxRef = ctx
	hudGui = UI().screen("MiamiWorkHUD", 6)
	local top = math.max(GuiService:GetGuiInset().Y, 36) + 10 + 124
	taskCard = UI().new("Frame", { Name = "Task", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, top), Size = UDim2.fromOffset(260, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(8, 10, 16), BackgroundTransparency = 0.3, Visible = false, Parent = hudGui })
	UI().corner(taskCard, 10)
	UI().pad(taskCard, 10)
	UI().list(taskCard, 2)
	local accent = UI().new("Frame", { BorderSizePixel = 0, Size = UDim2.new(0, 36, 0, 2), BackgroundColor3 = T().Accent, Parent = taskCard })
	UI().new("UIGradient", { Color = ColorSequence.new(T().Accent, T().Accent2), Parent = accent })
	taskTitle = UI().label(taskCard, "", 13, { Font = T().FontBold, TextColor3 = T().Text, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	taskStep = UI().label(taskCard, "", 12, { TextColor3 = Color3.fromRGB(255, 210, 110), AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	taskInfo = UI().label(taskCard, "", 11, { TextColor3 = T().Muted, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	-- Tragen auf der Baustelle: Kiste in den Haenden (lokal + Attribut ist serverseitig)
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		local c = player.Character
		local old = c and c:FindFirstChild("WorkCrate")
		if old then
			old:Destroy()
		end
		local root = c and c:FindFirstChild("HumanoidRootPart")
		if player:GetAttribute("Carrying") and root then
			local p = Instance.new("Part")
			p.Name = "WorkCrate"
			p.Size = Vector3.new(2, 1.4, 1.6)
			p.Color = Color3.fromRGB(170, 130, 80)
			p.Material = Enum.Material.WoodPlanks
			p.CanCollide, p.Massless = false, true
			p.CFrame = root.CFrame * CFrame.new(0, 0.3, -1.6)
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = p, root
			w.Parent = p
			p.Parent = c
		end
	end)
	local _ = TweenService
end

return W
