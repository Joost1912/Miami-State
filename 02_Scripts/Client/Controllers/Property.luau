-- Immobilien-Menue (Prompt 10)
--   Am Eingang eines Apartmenthauses: eigene Wohnungen betreten, Nachbarn besuchen/klingeln, kaufen oder mieten.
--   Verwaltung (Handy-App "Immobilien" oder Panel in der Wohnung): Abschliessen, Schluessel, Gaeste, Moebel.
local P = {}
local gui, closeFn, ctxRef
local state = {}

local function money(n)
	return ctxRef.Format.money(n)
end

function P.Close()
	if closeFn then
		closeFn()
	end
end

local function section(parent, text, order)
	local UI, T = ctxRef.UI, ctxRef.UI.Theme
	return UI.label(parent, string.upper(text), 11, { LayoutOrder = order, Font = T.FontBold, TextColor3 = T.Accent })
end

local function card(parent, order, h)
	local UI, T = ctxRef.UI, ctxRef.UI.Theme
	local c = UI.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, -6, 0, h or 64), BackgroundColor3 = T.Panel2, Parent = parent })
	UI.corner(c, 10)
	UI.pad(c, 12)
	return c
end

local function buttons(parent)
	local UI = ctxRef.UI
	local f = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0.6, 0, 0, 30), BackgroundTransparency = 1, Parent = parent })
	local l = UI.list(f, 6, true)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Right
	return function(text, style, fn)
		local b = UI.button(f, text, style, { Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, TextSize = 12 })
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = b })
		b.MouseButton1Click:Connect(fn)
		return b
	end
end

local function title(parent, a, b)
	local UI, T = ctxRef.UI, ctxRef.UI.Theme
	UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.45, 0, 0, 20), Font = T.FontBold, TextSize = 15, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = a, Parent = parent })
	UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(0.45, 0, 0, 16), Font = T.Font, TextSize = 12, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = b, Parent = parent })
end

local function rentText(p)
	if p.Mode ~= "Rent" then
		return "Eigentum"
	end
	local days = math.max(0, math.floor((p.RentUntil - os.time()) / 86400))
	return string.format("Miete %s / Woche  ·  noch %d Tage", money(p.Rent), days)
end

-- Am Gebaeude ---------------------------------------------------------------------------------------
local function renderBuilding(body)
	local UI, T = ctxRef.UI, ctxRef.UI.Theme
	for _, c in ipairs(body:GetChildren()) do
		c:Destroy()
	end
	local res = ctxRef.Request("Property.Info", { Building = state.Building }, true)
	local list = UI.scroll(body)
	UI.list(list, 8)
	if not res.ok then
		UI.label(list, res.msg or "Nicht verfuegbar", 14, { TextColor3 = T.Muted })
		return
	end
	local d = res.data
	UI.label(list, d.District .. "  ·  " .. d.Desc, 13, { LayoutOrder = 1, TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 34) })
	local o = 2
	if #d.Mine > 0 then
		section(list, "Meine Wohnungen", o)
		for _, p in ipairs(d.Mine) do
			o += 1
			local c = card(list, o)
			title(c, p.Number .. "  ·  " .. p.TierName, rentText(p) .. (p.Locked and "  ·  abgeschlossen" or "  ·  offen"))
			local add = buttons(c)
			add("Betreten", "primary", function()
				if ctxRef.Request("Property.Enter", { Owner = game.Players.LocalPlayer.UserId, Prop = p.Id }).ok then
					P.Close()
				end
			end)
			add(p.Locked and "Aufschliessen" or "Abschliessen", "secondary", function()
				ctxRef.Request("Property.SetLock", { Prop = p.Id, Locked = not p.Locked })
				renderBuilding(body)
			end)
			local armed
			local sb
			sb = add(p.Mode == "Own" and "Verkaufen" or "Kuendigen", "danger", function()
				if not armed then
					armed = true
					sb.Text = p.Mode == "Own" and ("Fuer " .. money(p.SellValue) .. "?") or "Wirklich kuendigen?"
					return
				end
				ctxRef.Request(p.Mode == "Own" and "Property.Sell" or "Property.CancelRent", { Prop = p.Id, TxId = ctxRef.TxId() })
				renderBuilding(body)
			end)
		end
	end
	if #d.Visits > 0 then
		o += 1
		section(list, "Bewohner besuchen", o)
		for _, v in ipairs(d.Visits) do
			o += 1
			local c = card(list, o, 56)
			title(c, v.Number .. "  ·  " .. v.OwnerName, v.Home and (v.CanEnter and ("Zutritt: " .. tostring(v.How)) or "zu Hause") or "nicht zu Hause")
			local add = buttons(c)
			if v.CanEnter then
				add("Betreten", "primary", function()
					if ctxRef.Request("Property.Enter", { Owner = v.Owner, Prop = v.Prop }).ok then
						P.Close()
					end
				end)
			end
			add("🔔 Klingeln", "secondary", function()
				ctxRef.Request("Property.Ring", { Owner = v.Owner, Prop = v.Prop })
			end)
		end
	end
	o += 1
	section(list, string.format("Verfuegbare Wohnungen  ·  %d/%d Immobilien", d.Count, d.Max), o)
	for _, off in ipairs(d.Offers) do
		o += 1
		local c = card(list, o, 78)
		local tierCfg = ctxRef.Config.Properties.Tiers[off.Tier]
		UI.new("Frame", { BorderSizePixel = 0, Position = UDim2.fromOffset(-12, -12), Size = UDim2.new(0, 4, 1, 24), BackgroundColor3 = tierCfg and tierCfg.Color or T.Accent, Parent = c })
		title(c, off.Name, off.Rooms)
		UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(0.45, 0, 0, 14), Font = T.FontBold, TextSize = 12, TextColor3 = T.Success, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("%s  ·  Miete %s / %d Tage", money(off.Price), money(off.Rent), d.RentDays), Parent = c })
		local add = buttons(c)
		local ab, ar
		ab = add("Kaufen", "primary", function()
			if ab.Text == "Kaufen" then
				ab.Text = money(off.Price) .. " - sicher?"
				return
			end
			ctxRef.Request("Property.Buy", { Building = state.Building, Tier = off.Tier, TxId = ctxRef.TxId() })
			renderBuilding(body)
		end)
		ar = add("Mieten", "secondary", function()
			if ar.Text == "Mieten" then
				ar.Text = money(off.Rent) .. " - sicher?"
				return
			end
			ctxRef.Request("Property.Rent", { Building = state.Building, Tier = off.Tier, TxId = ctxRef.TxId() })
			renderBuilding(body)
		end)
	end
end

-- Verwaltung ----------------------------------------------------------------------------------------
local function renderManage(body)
	local UI, T = ctxRef.UI, ctxRef.UI.Theme
	for _, c in ipairs(body:GetChildren()) do
		c:Destroy()
	end
	local res = ctxRef.Request("Property.Manage", nil, true)
	local list = UI.scroll(body)
	UI.list(list, 8)
	if not res.ok then
		return
	end
	local d = res.data
	if #d.Props == 0 then
		UI.label(list, "Du besitzt noch keine Wohnung. Apartmenthaeuser: Sawgrass Gardens, Brickell Heights (Midtown), Ocean Drive Residences (Coral Key), Bayfront One (Downtown) - siehe Stadtkarte.", 14, { TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 60) })
		return
	end
	local o = 0
	local selected = state.SelectedTarget
	-- Spielerauswahl fuer Schluessel/Einladungen
	o += 1
	section(list, "Spieler auswaehlen (Schluessel / Einladung)", o)
	o += 1
	local pick = UI.new("Frame", { LayoutOrder = o, BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 32), Parent = list })
	UI.list(pick, 6, true)
	if #d.Online == 0 then
		UI.label(pick, "Keine anderen Spieler online", 12, { TextColor3 = T.Muted, Size = UDim2.fromOffset(240, 30) })
	end
	for _, pl in ipairs(d.Online) do
		local b = UI.button(pick, pl.Name, pl.UserId == selected and "primary" or "secondary", { Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, TextSize = 12 })
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = b })
		b.MouseButton1Click:Connect(function()
			state.SelectedTarget = pl.UserId
			renderManage(body)
		end)
	end
	for _, p in ipairs(d.Props) do
		o += 1
		section(list, p.BuildingName .. "  ·  " .. p.Number, o)
		o += 1
		local c = card(list, o, 60)
		title(c, p.TierName, rentText(p) .. "  ·  Moebel " .. p.Furniture .. "  ·  Schluessel " .. #p.Keys)
		local add = buttons(c)
		add(p.Locked and "🔒 Abgeschlossen" or "🔓 Offen", "secondary", function()
			ctxRef.Request("Property.SetLock", { Prop = p.Id, Locked = not p.Locked })
			renderManage(body)
		end)
		if selected then
			add("Einladen", "primary", function()
				ctxRef.Request("Property.Invite", { Prop = p.Id, Target = selected })
			end)
			add("Schluessel geben", "secondary", function()
				ctxRef.Request("Property.GiveKey", { Prop = p.Id, Target = selected })
				renderManage(body)
			end)
		end
		for _, k in ipairs(p.Keys) do
			o += 1
			local kc = card(list, o, 44)
			title(kc, "🔑 " .. k.Name, "")
			buttons(kc)("Entziehen", "danger", function()
				ctxRef.Request("Property.RevokeKey", { Prop = p.Id, Target = k.UserId })
				renderManage(body)
			end)
		end
		-- Einrichtung (nur in der eigenen Wohnung platzierbar, kaufen ueberall)
		if d.InsideProp == p.Id or state.ShowShop then
			o += 1
			section(list, "Einrichtung", o)
			local cat = ctxRef.Request("Property.FurnitureCatalog", nil, true)
			for _, f in ipairs(cat.ok and cat.data or {}) do
				o += 1
				local fc = card(list, o, 44)
				local have = p.Storage[f.Id] or 0
				title(fc, f.Name, (have > 0 and ("Im Lager: " .. have .. "  ·  ") or "") .. money(f.Price))
				local add2 = buttons(fc)
				add2("Kaufen", "secondary", function()
					ctxRef.Request("Property.Furniture", { Do = "Buy", Prop = p.Id, Item = f.Id, TxId = ctxRef.TxId() })
					renderManage(body)
				end)
				if have > 0 and d.InsideProp == p.Id then
					add2("Platzieren", "primary", function()
						ctxRef.Request("Property.Furniture", { Do = "Place", Item = f.Id })
						renderManage(body)
					end)
				end
			end
			if d.InsideProp == p.Id and #d.Placed > 0 then
				o += 1
				section(list, "Platzierte Moebel (vor dir neu platzieren)", o)
				for _, f in ipairs(d.Placed) do
					o += 1
					local fc = card(list, o, 44)
					title(fc, f.Name, "#" .. f.Index)
					local add3 = buttons(fc)
					add3("Hierher", "secondary", function()
						ctxRef.Request("Property.Furniture", { Do = "Move", Index = f.Index })
					end)
					add3("Drehen", "secondary", function()
						ctxRef.Request("Property.Furniture", { Do = "Rotate", Index = f.Index })
					end)
					add3("Einlagern", "danger", function()
						ctxRef.Request("Property.Furniture", { Do = "Store", Index = f.Index })
						renderManage(body)
					end)
				end
			end
		end
	end
end

function P.Open(ctx, data)
	ctxRef = ctx
	data = data or {}
	local UI = ctx.UI
	gui = UI.screen("MiamiProperty", 20)
	state = { Building = data.Building, Manage = data.Manage or not data.Building, SelectedTarget = data.Target }
	local b = data.Building and ctx.Config.Properties.Buildings[data.Building]
	local _, content, doClose = UI.window(gui, b and b.Name or "Meine Immobilien", UDim2.fromOffset(700, 560), function()
		gui:Destroy()
		gui, closeFn = nil, nil
		ctx.Closed("Property")
	end)
	closeFn = doClose
	if state.Manage then
		renderManage(content)
	else
		renderBuilding(content)
	end
end

-- Klingeln: Bewohner bekommt das Verwaltungsmenue mit vorausgewaehltem Besucher
function P.Ring(ctx, data)
	ctx.UI.toast("🔔 " .. tostring(data.Name) .. " klingelt - Verwaltung oeffnen zum Einladen", "warning")
	P.LastRing = data
end

return P
