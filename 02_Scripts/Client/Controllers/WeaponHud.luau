-- Waffenanzeige (Prompt 08): erscheint nur mit ausgeruesteter Waffe unten rechts (eigene ScreenGui "MiamiWeaponHUD").
-- Zeigt Magazin / Reserve, Knoepfe fuer Touch. Tasten: Z = Nachladen, C = Verstauen. Alles laeuft ueber den Server.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local W = {}

function W.Close() end

function W.Start(ctx)
	local UI, T = ctx.UI, ctx.UI.Theme
	local player = Players.LocalPlayer
	local scr = UI.screen("MiamiWeaponHUD", 6)
	local box = UI.new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.fromOffset(250, 86), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.15, Visible = false, Parent = scr })
	UI.corner(box, 12)
	UI.stroke(box, T.Stroke, 1, 0.3)
	UI.pad(box, 10)
	local name = UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 0, 18), Font = T.FontBold, TextSize = 14, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = box })
	local ammo = UI.new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -2), Size = UDim2.new(0.4, 0, 0, 24), Font = T.FontBlack, TextSize = 22, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Right, Parent = box })
	local reserve = UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 14), Font = T.Font, TextSize = 11, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = box })
	local row = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 28), Parent = box })
	UI.list(row, 6, true)
	local reload = UI.button(row, "NACHLADEN [Z]", "primary", { Size = UDim2.new(0.5, -3, 1, 0), TextSize = 11 })
	local holster = UI.button(row, "VERSTAUEN [C]", "secondary", { Size = UDim2.new(0.5, -3, 1, 0), TextSize = 11 })

	local function refresh()
		local id = player:GetAttribute("EquippedWeapon")
		local def = id and ctx.Config.Items.Defs[id]
		box.Visible = def ~= nil and def.Weapon ~= nil
		if not box.Visible then
			return
		end
		local loaded = player:GetAttribute("WeaponLoaded") or 0
		name.Text = def.Name
		ammo.Text = string.format("%d / %d", loaded, def.Weapon.Mag)
		ammo.TextColor3 = loaded == 0 and T.Danger or T.Accent
		local inv = ctx.Profile and ctx.Profile.Inventory.Items[def.Weapon.Ammo] or 0
		reserve.Text = string.format("Reserve: %d  %s", inv, ctx.Config.Items.Defs[def.Weapon.Ammo].Name)
	end
	local function doReload()
		if box.Visible then
			ctx.Request("Weapon.Load", {})
		end
	end
	local function doHolster()
		if box.Visible then
			ctx.Request("Weapon.Holster", {})
		end
	end
	reload.MouseButton1Click:Connect(doReload)
	holster.MouseButton1Click:Connect(doHolster)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Z then
			doReload()
		elseif input.KeyCode == Enum.KeyCode.C then
			doHolster()
		end
	end)
	player:GetAttributeChangedSignal("EquippedWeapon"):Connect(refresh)
	player:GetAttributeChangedSignal("WeaponLoaded"):Connect(refresh)
	ctx.ProfileChanged:Connect(refresh)
	refresh()
end

return W
