-- Inventar: Raster mit Gegenstaenden (Anzahl, Kategorie), Detailansicht mit Benutzen / Entfernen.
local I = {}
local screen, conn

function I.Close()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if screen then
		screen:Destroy()
		screen = nil
	end
end

function I.Open(ctx)
	local UI, T, F = ctx.UI, ctx.UI.Theme, ctx.Format
	local Items = ctx.Config.Items
	I.Close()
	screen = UI.screen("MiamiInventory", 20)
	local _, content = UI.window(screen, "Inventar", UDim2.fromOffset(640, 520), function()
		I.Close()
		ctx.Closed("Inventory")
	end)
	local catColor = {}
	for _, c in ipairs(Items.Categories) do
		catColor[c.Id] = c.Color
	end
	local gridHolder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.62, -8, 1, 0), Parent = content })
	local detail = UI.new("Frame", { BackgroundColor3 = T.Panel2, Position = UDim2.new(0.62, 8, 0, 0), Size = UDim2.new(0.38, -8, 1, 0), Parent = content })
	UI.corner(detail, 10)
	UI.pad(detail, 14)
	local selected

	local function showDetail(id)
		detail:ClearAllChildren()
		UI.pad(detail, 14)
		UI.list(detail, 8)
		local def = Items.Defs[id]
		if not def then
			UI.label(detail, "Waehle einen Gegenstand.", 14, { TextColor3 = T.Muted })
			return
		end
		local count = ctx.Profile.Inventory.Items[id] or 0
		UI.label(detail, def.Name, 20, { Font = T.FontBlack })
		UI.label(detail, string.format("Anzahl: %d / %d", count, def.Stack), 13, { TextColor3 = T.Muted })
		UI.label(detail, def.Desc or "", 14, { Size = UDim2.new(1, 0, 0, 60), TextYAlignment = Enum.TextYAlignment.Top })
		-- Waffen (Prompt 08): Magazin, Ausruesten/Verstauen, Laden/Entladen
		if def.Weapon then
			local player = game:GetService("Players").LocalPlayer
			local loaded = (ctx.Profile.Weapons and ctx.Profile.Weapons.Loaded[id]) or 0
			local reserve = ctx.Profile.Inventory.Items[def.Weapon.Ammo] or 0
			UI.label(detail, string.format("Magazin: %d / %d   |   Reserve: %d", loaded, def.Weapon.Mag, reserve), 13, { TextColor3 = T.Accent, Font = T.FontBold })
			local isOn = player:GetAttribute("EquippedWeapon") == id
			local eq = UI.button(detail, isOn and "VERSTAUEN" or "AUSRUESTEN", isOn and "secondary" or "primary")
			eq.MouseButton1Click:Connect(function()
				if player:GetAttribute("EquippedWeapon") == id then
					ctx.Request("Weapon.Holster", {})
				else
					ctx.Request("Weapon.Equip", { ItemId = id })
				end
				task.wait(0.2)
				showDetail(id)
			end)
			local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Parent = detail })
			UI.list(row, 6, true)
			for _, a in ipairs({ { "LADEN", "Weapon.Load" }, { "ENTLADEN", "Weapon.Unload" } }) do
				local b = UI.button(row, a[1], "secondary", { Size = UDim2.new(0.5, -3, 1, 0), TextSize = 13 })
				b.MouseButton1Click:Connect(function()
					ctx.Request(a[2], { ItemId = id })
				end)
			end
		end
		if def.Use and not def.Restricted then
			local use = UI.button(detail, "BENUTZEN", "primary")
			use.MouseButton1Click:Connect(function()
				ctx.Request("Inventory.Use", { ItemId = id })
			end)
		elseif def.Restricted then
			UI.label(detail, "Noch nicht verfuegbar", 13, { TextColor3 = T.Warning })
		end
		local drop = UI.button(detail, "1 ENTFERNEN", "danger")
		drop.MouseButton1Click:Connect(function()
			ctx.Request("Inventory.Drop", { ItemId = id, Count = 1 })
		end)
	end

	local function render()
		gridHolder:ClearAllChildren()
		local d = ctx.Profile
		if not d then
			return
		end
		local cashBar = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, 0, 0, 44), Parent = gridHolder })
		UI.corner(cashBar, 10)
		UI.pad(cashBar, 12)
		UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(0.5, 1), Font = T.FontBold, TextSize = 14, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = "BARGELD", Parent = cashBar })
		UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 1), Font = T.FontBlack, TextSize = 18, TextColor3 = T.Success, TextXAlignment = Enum.TextXAlignment.Right, Text = F.money(d.Money.Cash), Parent = cashBar })
		local grid = UI.scroll(gridHolder, { Position = UDim2.new(0, 0, 0, 56), Size = UDim2.new(1, 0, 1, -56) })
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(108, 96), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.Name, Parent = grid })
		local slots = 0
		for id, count in pairs(d.Inventory.Items) do
			local def = Items.Defs[id]
			if def and count > 0 then
				slots += 1
				local cell = UI.new("TextButton", { Name = def.Category .. id, Text = "", AutoButtonColor = false, BackgroundColor3 = T.Bg, Parent = grid })
				UI.corner(cell, 10)
				UI.stroke(cell, (id == selected) and T.Accent or T.Stroke)
				UI.new("Frame", { BorderSizePixel = 0, BackgroundColor3 = catColor[def.Category] or T.Muted, Size = UDim2.new(1, -20, 0, 3), Position = UDim2.new(0, 10, 0, 10), Parent = cell })
				UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 20), Size = UDim2.new(1, -20, 0, 40), Font = T.FontBold, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = T.Text, Text = def.Name, Parent = cell })
				UI.new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(60, 20), Font = T.FontBlack, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T.Accent, Text = "x" .. count, Parent = cell })
				cell.MouseButton1Click:Connect(function()
					selected = id
					render()
					showDetail(id)
				end)
			end
		end
		UI.label(gridHolder, string.format("%d / %d Plaetze", slots, Items.MaxSlots), 12, { TextColor3 = T.Muted, Position = UDim2.new(0, 0, 1, 2) })
		if selected then
			showDetail(selected)
		end
	end
	render()
	showDetail(nil)
	conn = ctx.ProfileChanged:Connect(render)
end

return I
