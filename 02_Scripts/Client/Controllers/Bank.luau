-- Bankmenue (am Geldautomaten): Uebersicht + Kontoverlauf, Einzahlen, Abheben, Ueberweisen.
-- Jede Buchung bekommt eine eigene Transaktions-ID -> der Server verwirft Doppel-Anfragen.
local B = {}
local screen, conn

function B.Close()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if screen then
		screen:Destroy()
		screen = nil
	end
end

function B.Open(ctx)
	local UI, T, F = ctx.UI, ctx.UI.Theme, ctx.Format
	B.Close()
	screen = UI.screen("MiamiBank", 20)
	local _, content = UI.window(screen, "Bank of Miami State", UDim2.fromOffset(560, 560), function()
		B.Close()
		ctx.Closed("Bank")
	end)
	-- Kontostaende
	local top = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), Parent = content })
	UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 1, 0), CellPadding = UDim2.fromOffset(12, 0), Parent = top })
	local _, cashV = UI.stat(top, "Bargeld", "", T.Success)
	local _, bankV = UI.stat(top, "Kontostand", "", T.Accent)
	-- Tabs
	local tabs = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 76), Size = UDim2.new(1, 0, 0, 36), Parent = content })
	UI.list(tabs, 8, true)
	local body = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 124), Size = UDim2.new(1, 0, 1, -124), Parent = content })

	local function refreshBalances()
		local d = ctx.Profile
		if d then
			cashV.Text = F.money(d.Money.Cash)
			bankV.Text = F.money(d.Money.Bank)
		end
	end

	local views = {}
	local function amountForm(title, action, hint)
		body:ClearAllChildren()
		UI.list(body, 10)
		UI.label(body, string.upper(title), 12, { TextColor3 = T.Muted, Font = T.FontBold })
		local amount = UI.input(body, "Betrag in $")
		local quick = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = body })
		UI.list(quick, 8, true)
		for _, v in ipairs({ 50, 100, 500, 1000 }) do
			local q = UI.button(quick, "$" .. v, "secondary", { Size = UDim2.new(0.25, -6, 1, 0), TextSize = 13 })
			q.MouseButton1Click:Connect(function()
				amount.Text = tostring(v)
			end)
		end
		UI.label(body, hint, 13, { TextColor3 = T.Muted })
		local go = UI.button(body, string.upper(title), "primary")
		go.MouseButton1Click:Connect(function()
			local n = tonumber(amount.Text)
			if not n or n <= 0 or n % 1 ~= 0 then
				UI.toast("Bitte einen ganzen Betrag eingeben", "error")
				return
			end
			go.Active = false
			local res = ctx.Request(action, { Amount = n, TxId = ctx.TxId() })
			go.Active = true
			if res.ok then
				amount.Text = ""
			end
		end)
	end

	views.Overview = function()
		body:ClearAllChildren()
		UI.label(body, "KONTOVERLAUF", 12, { TextColor3 = T.Muted, Font = T.FontBold })
		local list = UI.scroll(body, { Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 1, -24) })
		UI.list(list, 6)
		local hist = ctx.Profile and ctx.Profile.Money.History or {}
		if #hist == 0 then
			UI.label(list, "Noch keine Buchungen.", 14, { TextColor3 = T.Muted })
		end
		for i, h in ipairs(hist) do
			local row = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, -6, 0, 44), LayoutOrder = i, Parent = list })
			UI.corner(row, 8)
			UI.pad(row, 10)
			UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.65, 0, 0, 16), Font = T.FontBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Text, Text = tostring(h.K), Parent = row })
			UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(0.65, 0, 0, 14), Font = T.Font, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Muted, Text = F.time(h.T) .. (h.N ~= "" and ("  -  " .. h.N) or ""), Parent = row })
			local positive = (h.A or 0) > 0
			UI.new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.new(0.35, 0, 0, 18), Font = T.FontBlack, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = positive and T.Success or T.Text, Text = F.money(h.A), Parent = row })
		end
	end
	views.Deposit = function()
		amountForm("Einzahlen", "Bank.Deposit", "Bargeld auf dein Konto einzahlen.")
	end
	views.Withdraw = function()
		amountForm("Abheben", "Bank.Withdraw", "Geld vom Konto als Bargeld abheben.")
	end
	views.Transfer = function()
		body:ClearAllChildren()
		UI.list(body, 10)
		UI.label(body, "EMPFAENGER (ONLINE)", 12, { TextColor3 = T.Muted, Font = T.FontBold })
		local selected
		local pick = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 120), Parent = body })
		local plist = UI.scroll(pick)
		UI.list(plist, 6)
		local res = ctx.Request("Players.List", nil, true)
		local btns = {}
		for _, p in ipairs(res.data or {}) do
			if not p.Self then
				local b = UI.button(plist, p.Name, "secondary", { Size = UDim2.new(1, -6, 0, 34), TextSize = 14 })
				btns[p.UserId] = b
				b.MouseButton1Click:Connect(function()
					selected = p.UserId
					for id, bb in pairs(btns) do
						bb.BackgroundColor3 = (id == selected) and T.Accent or T.Panel2
						bb.TextColor3 = (id == selected) and T.Bg or T.Text
					end
				end)
			end
		end
		if next(btns) == nil then
			UI.label(plist, "Keine anderen Spieler online.", 14, { TextColor3 = T.Muted })
		end
		local amount = UI.input(body, "Betrag in $")
		local note = UI.input(body, "Verwendungszweck (optional, max. 40 Zeichen)")
		local go = UI.button(body, "UEBERWEISEN", "primary")
		go.MouseButton1Click:Connect(function()
			local n = tonumber(amount.Text)
			if not selected then
				UI.toast("Bitte Empfaenger waehlen", "error")
				return
			end
			if not n or n <= 0 or n % 1 ~= 0 then
				UI.toast("Bitte einen ganzen Betrag eingeben", "error")
				return
			end
			local r = ctx.Request("Bank.Transfer", { Target = selected, Amount = n, Note = note.Text, TxId = ctx.TxId() })
			if r.ok then
				amount.Text, note.Text = "", ""
			end
		end)
	end

	local current = "Overview"
	local tabBtns = {}
	for _, t in ipairs({ { "Overview", "Uebersicht" }, { "Deposit", "Einzahlen" }, { "Withdraw", "Abheben" }, { "Transfer", "Ueberweisen" } }) do
		local b = UI.button(tabs, t[2], "secondary", { Size = UDim2.new(0.25, -6, 1, 0), TextSize = 13 })
		tabBtns[t[1]] = b
		b.MouseButton1Click:Connect(function()
			current = t[1]
			for k, bb in pairs(tabBtns) do
				bb.BackgroundColor3 = (k == current) and T.Accent or T.Panel2
				bb.TextColor3 = (k == current) and T.Bg or T.Text
			end
			views[current]()
		end)
	end
	tabBtns.Overview.BackgroundColor3, tabBtns.Overview.TextColor3 = T.Accent, T.Bg
	refreshBalances()
	views.Overview()
	conn = ctx.ProfileChanged:Connect(function()
		refreshBalances()
		if current == "Overview" then
			views.Overview()
		end
	end)
end

return B
