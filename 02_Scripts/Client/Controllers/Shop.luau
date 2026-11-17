-- Ladenmenue (Prompt 08): EIN Menue fuer alle Geschaefte (Supermarkt, Werkzeug, Waffenladen, Langwaffenhaendler,
-- Kleidung, Juwelier ...). Aussehen je Laden ueber Katalogfelder (Icon, Farbe, Kind). Eigene ScreenGui "MiamiStore".
-- Preise/Sperren werden nur angezeigt - abgerechnet und geprueft wird ausschliesslich auf dem Server.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local S = {}
local screen, conn
local ctxRef, shop
local state = { Tab = "Shop", Cat = "Alle" }

local CAT_ICON = { Weapons = "🎯", Ammo = "📦", Gear = "🧰", Documents = "📄", Food = "🥪", Medical = "🩹", Tools = "🔧", Misc = "🛍", Valuables = "💎", Keys = "🔑" }
local SLOT_ICON = { Top = "👕", Bottom = "👖", Shoes = "👟", Hat = "🧢", Glasses = "🕶" }

function S.Close()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if screen then
		screen:Destroy()
		screen = nil
	end
	shop = nil
end

-- Knopf in Ladenfarbe (UI.button setzt beim Hover die Standardfarbe zurueck -> eigener Hover)
local function colorButton(parent, text, color, props)
	local UI, T = ctxRef.UI, ctxRef.UI.Theme
	local b = UI.new("TextButton", { AutoButtonColor = false, BackgroundColor3 = color, Text = text, TextColor3 = T.Bg, Font = T.FontBold, TextSize = 13, Size = UDim2.new(1, 0, 0, 36), Parent = parent })
	UI.corner(b, 8)
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.15) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = color }):Play()
	end)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	return b
end

local function isClothing()
	return shop and shop.Kind == "Clothing"
end

local function defOf(id)
	if isClothing() then
		return ctxRef.Config.Clothing.Defs[id]
	end
	return ctxRef.Config.Items.Defs[id]
end

local function catOf(id)
	local d = defOf(id)
	if not d then
		return "Misc"
	end
	return isClothing() and d.Slot or d.Category
end

local function catName(c)
	if isClothing() then
		for _, s in ipairs(ctxRef.Config.Clothing.Slots) do
			if s.Id == c then
				return s.Name
			end
		end
	end
	for _, x in ipairs(ctxRef.Config.Items.Categories) do
		if x.Id == c then
			return x.Name
		end
	end
	return c
end

local function refresh()
	if not shop then
		return
	end
	local r = ctxRef.Request("Shop.Info", { ShopId = shop.ShopId }, true)
	if r.ok and r.data then
		shop = r.data
		S.Render()
	end
end

-- Artikel-Karte
local function itemCard(grid, entry)
	local UI, T, F = ctxRef.UI, ctxRef.UI.Theme, ctxRef.Format
	local def = defOf(entry.Id)
	if not def then
		return
	end
	local accent = shop.Color or T.Accent
	local card = UI.new("Frame", { BackgroundColor3 = T.Panel2, Parent = grid })
	UI.corner(card, 12)
	UI.stroke(card, entry.Locked and T.Stroke or accent, 1, entry.Locked and 0 or 0.55)
	UI.pad(card, 10)
	-- Symbol / Farbmuster
	local swatch = UI.new("TextLabel", { Size = UDim2.fromOffset(40, 40), BackgroundColor3 = isClothing() and def.Color or accent, BackgroundTransparency = isClothing() and 0 or 0.75, Font = T.FontBold, TextSize = 22, Text = isClothing() and "" or (CAT_ICON[def.Category] or "🛍"), TextColor3 = T.Text, Parent = card })
	UI.corner(swatch, 10)
	if isClothing() then
		UI.stroke(swatch, Color3.new(1, 1, 1), 1, 0.7)
		UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = SLOT_ICON[def.Slot] or "", TextSize = 18, Font = T.FontBold, TextTransparency = 0.25, Parent = swatch })
	end
	UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -48, 0, 20), Font = T.FontBold, TextSize = 14, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = def.Name, Parent = card })
	local priceText = F.money(entry.Price) .. ((entry.Pack or 1) > 1 and ("  /  " .. entry.Pack .. " Stk.") or "")
	UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(48, 20), Size = UDim2.new(1, -48, 0, 18), Font = T.FontBlack, TextSize = 15, TextColor3 = T.Success, TextXAlignment = Enum.TextXAlignment.Left, Text = priceText, Parent = card })
	UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 30), Font = T.Font, TextSize = 11, TextColor3 = T.Muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = entry.Locked and "" or (def.Desc or catName(catOf(entry.Id))), Parent = card })
	if entry.Locked then
		local lock = UI.new("TextLabel", { BackgroundColor3 = T.Bg, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 30), Font = T.FontBold, TextSize = 11, TextColor3 = entry.Locked == "Bereits gekauft" and T.Success or T.Warning, TextWrapped = true, Text = (entry.Locked == "Bereits gekauft" and "✓ " or "🔒 ") .. entry.Locked, Parent = card })
		UI.corner(lock, 8)
		return
	end
	local stackOne = isClothing() or (def.Stack == 1)
	local row = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 30), Parent = card })
	UI.list(row, 5, true)
	local count = 1
	if not stackOne then
		local cnt = UI.button(row, "1x", "secondary", { Size = UDim2.new(0.22, -4, 1, 0), TextSize = 12 })
		cnt.MouseButton1Click:Connect(function()
			count = count % 5 + 1
			cnt.Text = count .. "x"
		end)
	end
	local w = stackOne and 0.5 or 0.39
	for i, m in ipairs({ { "Cash", "BAR" }, { "Bank", "KARTE" } }) do
		local b = (i == 1) and colorButton(row, m[2], accent, { Size = UDim2.new(w, -4, 1, 0), TextSize = 12 })
			or UI.button(row, m[2], "secondary", { Size = UDim2.new(w, -4, 1, 0), TextSize = 12 })
		b.Name = "Buy" .. m[1] .. "_" .. entry.Id
		b.MouseButton1Click:Connect(function()
			local res = ctxRef.Request("Shop.Buy", { ShopId = shop.ShopId, ItemId = entry.Id, Count = count, Method = m[1], TxId = ctxRef.TxId() })
			if res.ok then
				refresh()
			end
		end)
	end
end

-- Kleidung: Umkleide (gekaufte Teile an-/ablegen)
local function renderWardrobe(body)
	local UI, T = ctxRef.UI, ctxRef.UI.Theme
	local W = ctxRef.Profile.Wardrobe or { Owned = {}, Current = {} }
	local list = UI.scroll(body)
	UI.list(list, 10)
	UI.label(list, "Gekaufte Kleidung anziehen. Waehle ein Teil pro Bereich - Aenderungen gelten sofort.", 12, { TextColor3 = T.Muted })
	for _, slot in ipairs(ctxRef.Config.Clothing.Slots) do
		local owned = {}
		for _, id in ipairs(W.Owned) do
			local d = ctxRef.Config.Clothing.Defs[id]
			if d and d.Slot == slot.Id then
				table.insert(owned, id)
			end
		end
		local sec = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = list })
		UI.corner(sec, 10)
		UI.pad(sec, 10)
		UI.list(sec, 6)
		UI.label(sec, (SLOT_ICON[slot.Id] or "") .. "  " .. slot.Name:upper(), 12, { Font = T.FontBlack, TextColor3 = shop.Color or T.Accent })
		local chips = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = sec })
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(150, 30), CellPadding = UDim2.fromOffset(6, 6), Parent = chips })
		if #owned == 0 then
			UI.label(sec, "Noch nichts gekauft.", 12, { TextColor3 = T.Muted })
		end
		for _, id in ipairs(owned) do
			local d = ctxRef.Config.Clothing.Defs[id]
			local on = W.Current[slot.Id] == id
			local b = on and colorButton(chips, "✓ " .. d.Name, shop.Color or T.Accent, { TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd })
				or UI.button(chips, d.Name, "secondary", { TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd })
			b.Name = "Wear_" .. id
			local sw = UI.new("Frame", { Size = UDim2.fromOffset(6, 18), Position = UDim2.new(0, 4, 0.5, -9), BackgroundColor3 = d.Color, Parent = b })
			UI.corner(sw, 3)
			b.MouseButton1Click:Connect(function()
				local sel = { [slot.Id] = on and false or id }
				ctxRef.Request("Clothing.Wear", { Selection = sel })
			end)
		end
	end
	local reset = UI.button(list, "EIGENE KLEIDUNG (ROBLOX-AVATAR) ANZIEHEN", "secondary", { Size = UDim2.new(1, -6, 0, 36), TextSize = 12 })
	reset.MouseButton1Click:Connect(function()
		ctxRef.Request("Clothing.Reset")
	end)
end

-- Kleidung: Outfits speichern / anziehen / loeschen
local function renderOutfits(body)
	local UI, T = ctxRef.UI, ctxRef.UI.Theme
	local W = ctxRef.Profile.Wardrobe or { Outfits = {}, Current = {} }
	local list = UI.scroll(body)
	UI.list(list, 8)
	UI.label(list, "Speichere deine aktuelle Kleidung als Outfit und wechsle spaeter mit einem Klick.", 12, { TextColor3 = T.Muted })
	for i = 1, ctxRef.Config.Clothing.MaxOutfits do
		local o = W.Outfits[i]
		local filled = o and next(o) ~= nil
		local row = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, -6, 0, 58), Parent = list })
		UI.corner(row, 10)
		UI.pad(row, 10)
		UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.5, 0, 0, 18), Font = T.FontBlack, TextSize = 14, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = "OUTFIT " .. i, Parent = row })
		local parts = {}
		for _, slot in ipairs(ctxRef.Config.Clothing.Slots) do
			local d = filled and ctxRef.Config.Clothing.Defs[o[slot.Id] or ""]
			if d then
				table.insert(parts, d.Name)
			end
		end
		UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(0.55, 0, 0, 16), Font = T.Font, TextSize = 11, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = filled and table.concat(parts, ", ") or "leer", Parent = row })
		local btns = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0.44, 0, 0, 30), Parent = row })
		UI.list(btns, 5, true)
		local function btn(text, style, action)
			local b = UI.button(btns, text, style, { Size = UDim2.new(1 / 3, -4, 1, 0), TextSize = 11 })
			b.MouseButton1Click:Connect(function()
				ctxRef.Request(action, { Index = i })
			end)
			return b
		end
		btn("SPEICHERN", "secondary", "Clothing.SaveOutfit").Name = "Save_" .. i
		local wear = btn("ANZIEHEN", "primary", "Clothing.WearOutfit")
		wear.Name = "WearOutfit_" .. i
		local del = btn("LOESCHEN", "danger", "Clothing.DeleteOutfit")
		del.Name = "Delete_" .. i
		if not filled then
			-- leerer Platz: nur Speichern (Knoepfe bleiben an ihrer Position)
			for _, b in ipairs({ wear, del }) do
				b.Active, b.AutoButtonColor, b.BackgroundTransparency, b.TextTransparency = false, false, 1, 1
			end
		end
	end
end

function S.Render()
	if not screen or not shop then
		return
	end
	local UI, T, F = ctxRef.UI, ctxRef.UI.Theme, ctxRef.Format
	local content = screen:FindFirstChild("Body", true)
	content:ClearAllChildren()
	UI.pad(content, 16)
	local accent = shop.Color or T.Accent
	-- Kopf: Untertitel, Geldbeutel
	local head = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, 0, 0, 54), Parent = content })
	UI.corner(head, 12)
	UI.new("UIGradient", { Rotation = 0, Color = ColorSequence.new(accent:Lerp(T.Panel2, 0.55), T.Panel2), Parent = head })
	UI.pad(head, 10)
	local icon = UI.new("TextLabel", { Size = UDim2.fromOffset(34, 34), BackgroundColor3 = accent, Font = T.FontBold, TextSize = 20, Text = shop.Icon or "🛍", Parent = head })
	UI.corner(icon, 17)
	UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -230, 1, 0), Font = T.FontBold, TextSize = 13, TextColor3 = T.Text, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Text = shop.Subtitle or "", Parent = head })
	local p = ctxRef.Profile
	UI.new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(180, 18), Font = T.FontBlack, TextSize = 15, TextColor3 = T.Success, TextXAlignment = Enum.TextXAlignment.Right, Text = "Bar " .. F.money(p.Money.Cash), Parent = head })
	UI.new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 18), Size = UDim2.fromOffset(180, 16), Font = T.FontBold, TextSize = 12, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Right, Text = "Konto " .. F.money(p.Money.Bank), Parent = head })
	-- Reiter
	local tabs = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 30), Parent = content })
	UI.list(tabs, 6, true)
	local defs = {}
	if isClothing() then
		defs = { { "Shop", "KAUFEN" }, { "Wardrobe", "UMKLEIDE" }, { "Outfits", "OUTFITS" } }
	elseif shop.Info then
		defs = { { "Shop", shop.Kind == "Jeweler" and "AUSSTELLUNG" or "SORTIMENT" }, { "Info", "INFO" } }
	end
	for _, d in ipairs(defs) do
		local on = state.Tab == d[1]
		local b = on and colorButton(tabs, d[2], accent, { Size = UDim2.fromOffset(120, 30), TextSize = 12 })
			or UI.button(tabs, d[2], "secondary", { Size = UDim2.fromOffset(120, 30), TextSize = 12 })
		b.Name = "Tab_" .. d[1]
		b.MouseButton1Click:Connect(function()
			state.Tab = d[1]
			S.Render()
		end)
	end
	local topOff = (#defs > 0) and 100 or 62
	local body = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, topOff), Size = UDim2.new(1, 0, 1, -topOff), Parent = content })
	if state.Tab == "Wardrobe" then
		return renderWardrobe(body)
	elseif state.Tab == "Outfits" then
		return renderOutfits(body)
	elseif state.Tab == "Info" then
		local box = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = body })
		UI.corner(box, 12)
		UI.pad(box, 14)
		UI.list(box, 8)
		UI.label(box, (shop.Icon or "") .. "  " .. (shop.Title or ""):upper(), 16, { Font = T.FontBlack, TextColor3 = accent })
		UI.label(box, shop.Info or "", 13, { AutomaticSize = Enum.AutomaticSize.Y })
		return
	end
	-- Kategorie-Filter
	local cats, seen = { "Alle" }, {}
	for _, e in ipairs(shop.Items) do
		local c = catOf(e.Id)
		if not seen[c] then
			seen[c] = true
			table.insert(cats, c)
		end
	end
	if not seen[state.Cat] then
		state.Cat = "Alle"
	end
	local filter = UI.new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 28), ScrollBarThickness = 0, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.X, Parent = body })
	UI.list(filter, 6, true)
	if #cats > 2 then
		for _, c in ipairs(cats) do
			local on = state.Cat == c
			local b = UI.button(filter, c == "Alle" and "Alle" or catName(c), "secondary", { Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, TextSize = 11, BackgroundColor3 = on and accent:Lerp(T.Panel2, 0.4) or T.Panel2 })
			UI.pad(b, 8)
			b.MouseButton1Click:Connect(function()
				state.Cat = c
				S.Render()
			end)
		end
	end
	local gy = (#cats > 2) and 36 or 0
	local grid = UI.scroll(body, { Position = UDim2.fromOffset(0, gy), Size = UDim2.new(1, 0, 1, -gy) })
	local vp = Workspace.CurrentCamera.ViewportSize
	local cols = vp.X < 700 and 2 or 3
	UI.new("UIGridLayout", { CellSize = UDim2.new(1 / cols, -8, 0, 128), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for _, e in ipairs(shop.Items) do
		if state.Cat == "Alle" or catOf(e.Id) == state.Cat then
			itemCard(grid, e)
		end
	end
end

function S.Open(ctx, data)
	ctxRef = ctx
	S.Close()
	shop = data
	if not shop or not shop.ShopId then
		return
	end
	-- optional direkt mit Reiter oeffnen (z.B. "Wardrobe" / "Outfits" / "Info")
	state = { Tab = data.Tab or "Shop", Cat = "Alle" }
	local UI = ctx.UI
	screen = UI.screen("MiamiStore", 20)
	local vp = Workspace.CurrentCamera.ViewportSize
	local w = math.min(840, vp.X - 24)
	local h = math.min(580, vp.Y - 40)
	local _, content = UI.window(screen, shop.Title or "Laden", UDim2.fromOffset(w, h), function()
		S.Close()
		ctx.Closed("Shop")
	end)
	content.Name = "Body"
	S.Render()
	-- Geld/Kleidung aendern sich -> neu zeichnen (Sperren holt refresh() nach Kaeufen)
	conn = ctx.ProfileChanged:Connect(function()
		if screen then
			S.Render()
		end
	end)
	-- Laden verlassen -> Menue schliessen
	local token = {}
	S._token = token
	task.spawn(function()
		while screen and S._token == token do
			task.wait(1)
			local r = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if r and S._origin and (r.Position - S._origin).Magnitude > 30 then
				S.Close()
				ctx.Closed("Shop")
			end
		end
	end)
	local r = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	S._origin = r and r.Position
end

return S
