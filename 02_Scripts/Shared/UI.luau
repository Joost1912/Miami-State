-- MIAMI STATE UI-Bibliothek: einheitliches, dunkles, minimalistisches Design mit dezenten Akzenten.
-- Alle Menues bauen auf diesen Bausteinen auf (Fenster, Text, Buttons, Eingabefelder, Listen, Toasts).
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local UI = {}

UI.Theme = {
	Bg = Color3.fromRGB(10, 12, 18),
	Panel = Color3.fromRGB(18, 21, 30),
	Panel2 = Color3.fromRGB(26, 30, 42),
	Stroke = Color3.fromRGB(46, 52, 70),
	Text = Color3.fromRGB(236, 239, 246),
	Muted = Color3.fromRGB(146, 153, 172),
	Accent = Color3.fromRGB(64, 224, 255), -- Miami-Tuerkis
	Accent2 = Color3.fromRGB(255, 72, 168), -- Neon-Pink
	Success = Color3.fromRGB(80, 220, 140),
	Danger = Color3.fromRGB(255, 86, 96),
	Warning = Color3.fromRGB(255, 196, 80),
	Font = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,
	FontBlack = Enum.Font.GothamBlack,
}
local T = UI.Theme

local function corner(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = obj
	return c
end
local function stroke(obj, color, thickness, transp)
	local s = Instance.new("UIStroke")
	s.Color = color or T.Stroke
	s.Thickness = thickness or 1
	s.Transparency = transp or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = obj
	return s
end
local function pad(obj, p)
	local u = Instance.new("UIPadding")
	u.PaddingTop = UDim.new(0, p)
	u.PaddingBottom = UDim.new(0, p)
	u.PaddingLeft = UDim.new(0, p)
	u.PaddingRight = UDim.new(0, p)
	u.Parent = obj
	return u
end
UI.corner, UI.stroke, UI.pad = corner, stroke, pad

function UI.new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			o[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = o
	end
	if props and props.Parent then
		o.Parent = props.Parent
	end
	return o
end

function UI.screen(name, order)
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	return UI.new("ScreenGui", {
		Name = name, ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order or 10, Parent = pg,
	})
end

function UI.label(parent, text, size, props)
	local l = UI.new("TextLabel", {
		BackgroundTransparency = 1, Text = text or "", TextColor3 = T.Text, Font = T.Font, TextSize = size or 16,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Size = UDim2.new(1, 0, 0, (size or 16) + 6),
		Parent = parent,
	})
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end

-- Button-Stile: "primary" (Akzent), "secondary" (Panel), "danger"
function UI.button(parent, text, style, props)
	local bg = (style == "primary" and T.Accent) or (style == "danger" and T.Danger) or T.Panel2
	local fg = (style == "primary") and T.Bg or T.Text
	local b = UI.new("TextButton", {
		AutoButtonColor = false, BackgroundColor3 = bg, Text = text, TextColor3 = fg, Font = T.FontBold, TextSize = 15,
		Size = UDim2.new(1, 0, 0, 40), Parent = parent,
	})
	corner(b, 8)
	if style ~= "primary" and style ~= "danger" then
		stroke(b, T.Stroke)
	end
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = bg:Lerp(Color3.new(1, 1, 1), 0.12) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = bg }):Play()
	end)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	return b
end

function UI.input(parent, placeholder, props)
	local box = UI.new("TextBox", {
		BackgroundColor3 = T.Bg, PlaceholderText = placeholder or "", PlaceholderColor3 = T.Muted, Text = "",
		TextColor3 = T.Text, Font = T.Font, TextSize = 16, ClearTextOnFocus = false, Size = UDim2.new(1, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
	})
	corner(box, 8)
	local s = stroke(box, T.Stroke)
	pad(box, 10)
	box.Focused:Connect(function()
		s.Color = T.Accent
	end)
	box.FocusLost:Connect(function()
		s.Color = T.Stroke
	end)
	for k, v in pairs(props or {}) do
		box[k] = v
	end
	return box
end

function UI.list(parent, spacing, horizontal)
	return UI.new("UIListLayout", {
		Padding = UDim.new(0, spacing or 8), SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical, Parent = parent,
	})
end

function UI.scroll(parent, props)
	local s = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = T.Stroke,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Size = UDim2.fromScale(1, 1), Parent = parent,
	})
	for k, v in pairs(props or {}) do
		s[k] = v
	end
	return s
end

-- Zentriertes Fenster mit Titelzeile, Akzentlinie und Schliessen-Button. Liefert window, content.
function UI.window(screen, title, size, onClose)
	local overlay = UI.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Parent = screen })
	local win = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = size or UDim2.fromOffset(520, 560),
		BackgroundColor3 = T.Panel, Parent = overlay,
	})
	corner(win, 14)
	stroke(win, T.Stroke)
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(math.huge, math.huge), MinSize = Vector2.new(300, 200), Parent = win })
	-- Prompt 12: auf kleinen Bildschirmen (Laptop, Tablet, Handy) automatisch passend verkleinern
	local fit = UI.new("UIScale", { Name = "FitScale", Parent = win })
	local function refit()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		local w = (size and size.X.Offset > 0) and size.X.Offset or 520
		local h = (size and size.Y.Offset > 0) and size.Y.Offset or 560
		fit.Scale = math.clamp(math.min((vp.X - 24) / w, (vp.Y - 24) / h), 0.55, 1)
	end
	refit()
	local cam = workspace.CurrentCamera
	if cam then
		local conn
		conn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if not win.Parent then
				conn:Disconnect()
				return
			end
			refit()
		end)
	end
	local header = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), Parent = win })
	pad(header, 16)
	UI.new("TextLabel", {
		BackgroundTransparency = 1, Text = string.upper(title), TextColor3 = T.Text, Font = T.FontBlack, TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -40, 1, 0), Parent = header,
	})
	local close = UI.new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = T.Panel2, Text = "X", TextColor3 = T.Muted, Font = T.FontBold, TextSize = 14, Parent = header,
	})
	corner(close, 6)
	local bar = UI.new("Frame", { BorderSizePixel = 0, Position = UDim2.new(0, 16, 0, 55), Size = UDim2.new(0, 48, 0, 2), BackgroundColor3 = T.Accent, Parent = win })
	UI.new("UIGradient", { Color = ColorSequence.new(T.Accent, T.Accent2), Parent = bar })
	local content = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 64), Size = UDim2.new(1, 0, 1, -64), Parent = win })
	pad(content, 16)
	local function doClose()
		overlay:Destroy()
		if onClose then
			onClose()
		end
	end
	close.MouseButton1Click:Connect(doClose)
	win.Position = UDim2.new(0.5, 0, 0.5, 20)
	TweenService:Create(win, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	return win, content, doClose, overlay
end

-- Kleine Info-Karte (Titel + Wert)
function UI.stat(parent, title, value, accent)
	local f = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, 0, 0, 64), Parent = parent })
	corner(f, 10)
	pad(f, 12)
	UI.new("TextLabel", { BackgroundTransparency = 1, Text = string.upper(title), TextColor3 = T.Muted, Font = T.FontBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 14), Parent = f })
	local v = UI.new("TextLabel", { Name = "Value", BackgroundTransparency = 1, Text = value, TextColor3 = accent or T.Text, Font = T.FontBlack, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, 0, 0, 24), Parent = f })
	return f, v
end

-- Toast-Benachrichtigungen (oben mittig)
local toastHolder
function UI.toast(text, kind)
	if not toastHolder or not toastHolder.Parent then
		local scr = UI.screen("MiamiToasts", 100)
		-- Prompt 12: Breite passt sich schmalen Bildschirmen an
		toastHolder = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.new(0.9, 0, 1, -40), BackgroundTransparency = 1, Parent = scr })
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(420, math.huge), Parent = toastHolder })
		UI.list(toastHolder, 8)
	end
	local color = (kind == "error" and T.Danger) or (kind == "success" and T.Success) or (kind == "warning" and T.Warning) or T.Accent
	local f = UI.new("Frame", { BackgroundColor3 = T.Panel, Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 0.05, Parent = toastHolder })
	corner(f, 10)
	stroke(f, color, 1, 0.3)
	UI.new("Frame", { BorderSizePixel = 0, BackgroundColor3 = color, Size = UDim2.new(0, 4, 1, -16), Position = UDim2.new(0, 8, 0, 8), Parent = f })
	UI.new("TextLabel", { BackgroundTransparency = 1, Text = text, TextColor3 = T.Text, Font = T.Font, TextSize = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 22, 0, 0), Size = UDim2.new(1, -30, 1, 0), Parent = f })
	task.delay(4, function()
		if f.Parent then
			TweenService:Create(f, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			task.wait(0.3)
			f:Destroy()
		end
	end)
end

return UI
