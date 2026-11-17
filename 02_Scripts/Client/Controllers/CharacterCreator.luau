-- Charaktererstellung: Vollbild, zweispaltig (Persoenliches | Aussehen). Validierung final auf dem Server.
local Lighting = game:GetService("Lighting")
local C = {}
local screen, blur

local SKINS = {
	Color3.fromRGB(255, 224, 196), Color3.fromRGB(241, 194, 160), Color3.fromRGB(224, 172, 128), Color3.fromRGB(198, 142, 98),
	Color3.fromRGB(160, 110, 74), Color3.fromRGB(124, 84, 56), Color3.fromRGB(94, 62, 42), Color3.fromRGB(66, 44, 30),
}

function C.Close()
	if screen then
		screen:Destroy()
		screen = nil
	end
	if blur then
		blur:Destroy()
		blur = nil
	end
end

function C.Open(ctx)
	local UI, T = ctx.UI, ctx.UI.Theme
	C.Close()
	blur = Instance.new("BlurEffect")
	blur.Size = 18
	blur.Parent = Lighting
	screen = UI.screen("MiamiCharacterCreator", 50)
	local bg = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.25, Parent = screen })
	UI.new("UIGradient", { Rotation = 35, Color = ColorSequence.new(Color3.fromRGB(40, 10, 50), Color3.fromRGB(5, 25, 40)), Transparency = NumberSequence.new(0.2), Parent = bg })

	-- Kopfzeile
	UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 60, 0, 50), Size = UDim2.fromOffset(700, 60), Font = T.FontBlack, TextSize = 52, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Text, Text = "MIAMI STATE", Parent = bg })
	local sub = UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 62, 0, 108), Size = UDim2.fromOffset(700, 24), Font = T.FontBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Accent, Text = "ERSTELLE DEINEN CHARAKTER", Parent = bg })
	UI.new("UIGradient", { Color = ColorSequence.new(T.Accent, T.Accent2), Parent = sub })

	local card = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.55, 0), Size = UDim2.fromOffset(820, 470), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.05, Parent = bg })
	UI.corner(card, 16)
	UI.stroke(card, T.Stroke)
	UI.pad(card, 24)
	local left = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.5, -12, 1, -60), Parent = card })
	local right = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.5, 12, 0, 0), Size = UDim2.new(0.5, -12, 1, -60), Parent = card })
	UI.list(left, 10)
	UI.list(right, 10)

	local state = { Gender = nil, Skin = 2, Height = 2, Build = 2 }
	local function section(parent, text)
		UI.label(parent, string.upper(text), 12, { TextColor3 = T.Muted, Font = T.FontBold })
	end

	section(left, "Vorname")
	local first = UI.input(left, "z.B. Alex")
	section(left, "Nachname")
	local last = UI.input(left, "z.B. Rivera")
	section(left, "Geschlecht")
	local gRow = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = left })
	UI.list(gRow, 8, true)
	local gBtns = {}
	for _, g in ipairs({ { "m", "Maennlich" }, { "w", "Weiblich" }, { "d", "Divers" } }) do
		local b = UI.button(gRow, g[2], "secondary", { Size = UDim2.new(1 / 3, -6, 1, 0), TextSize = 14 })
		gBtns[g[1]] = b
		b.MouseButton1Click:Connect(function()
			state.Gender = g[1]
			for k, bb in pairs(gBtns) do
				bb.BackgroundColor3 = (k == g[1]) and T.Accent or T.Panel2
				bb.TextColor3 = (k == g[1]) and T.Bg or T.Text
			end
		end)
	end
	section(left, "Geburtsjahr")
	local year = UI.input(left, "1940 - 2008", { Text = "1995" })

	section(right, "Hautton")
	local skinRow = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = right })
	UI.list(skinRow, 8, true)
	local swatches = {}
	for i, col in ipairs(SKINS) do
		local s = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = col, Size = UDim2.fromOffset(40, 40), Parent = skinRow })
		UI.corner(s, 20)
		local st = UI.stroke(s, T.Accent, 3, i == state.Skin and 0 or 1)
		swatches[i] = st
		s.MouseButton1Click:Connect(function()
			state.Skin = i
			for j, x in ipairs(swatches) do
				x.Transparency = (j == i) and 0 or 1
			end
		end)
	end
	local function choice(parent, title, key, options)
		section(parent, title)
		local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = parent })
		UI.list(row, 8, true)
		local btns = {}
		for i, text in ipairs(options) do
			local b = UI.button(row, text, "secondary", { Size = UDim2.new(1 / #options, -6, 1, 0), TextSize = 14 })
			btns[i] = b
			local function paint()
				for j, bb in ipairs(btns) do
					bb.BackgroundColor3 = (j == state[key]) and T.Accent or T.Panel2
					bb.TextColor3 = (j == state[key]) and T.Bg or T.Text
				end
			end
			b.MouseButton1Click:Connect(function()
				state[key] = i
				paint()
			end)
			task.defer(paint)
		end
	end
	choice(right, "Groesse", "Height", { "Klein", "Mittel", "Gross" })
	choice(right, "Statur", "Build", { "Schlank", "Normal", "Kraeftig" })
	UI.label(right, "Deine Kleidung uebernimmst du von deinem Roblox-Avatar.", 13, { TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 40) })

	local create = UI.button(card, "CHARAKTER ERSTELLEN", "primary", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(260, 46), TextSize = 16 })
	local busy = false
	create.MouseButton1Click:Connect(function()
		if busy then
			return
		end
		busy = true
		create.Text = "WIRD ERSTELLT ..."
		local res = ctx.Request("Character.Create", {
			FirstName = first.Text, LastName = last.Text, Gender = state.Gender,
			BirthYear = tonumber(year.Text), Skin = state.Skin, Height = state.Height, Build = state.Build,
		})
		busy = false
		create.Text = "CHARAKTER ERSTELLEN"
		if res.ok then
			C.Close()
			ctx.Closed("CharacterCreator")
		end
	end)
end

return C
