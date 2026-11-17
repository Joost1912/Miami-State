-- Premium-HUD (Prompt 10, ersetzt das bisherige HUD in derselben ScreenGui "MiamiHUD"):
--   (Spieluhr: seit Prompt 14 nur im Handy)
--   oben rechts : (bis in die Ecke) MIAMI STATE Schriftzug, darunter CASH / BANK (live ueber Spieler-Attribute) + Beruf
--   unten links : Minimap (Controller Minimap) + Lebensanzeige/Status direkt darunter (hier)
--   unten rechts: Fahrzeuganzeige (nur im Fahrzeug): Tempo, Tank, Gurt, Licht, Kennzeichen
--   rechts      : schmale Schnellzugriffsleiste (Maus/Touch), Tastenkuerzel bleiben unveraendert
-- Leistung: Fahrzeuganzeige 15 Hz und nur im Fahrzeug, alles andere ereignisgesteuert.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local Hud = {}
local STUDS_TO_KMH = 0.28 * 3.6

Hud.Seatbelt = false

local function font(weight, italic)
	local ok, f = pcall(Font.new, "rbxasset://fonts/families/Montserrat.json", weight or Enum.FontWeight.Bold, italic and Enum.FontStyle.Italic or Enum.FontStyle.Normal)
	return ok and f or Font.fromEnum(Enum.Font.GothamBold)
end

function Hud.Start(ctx)
	local UI, T = ctx.UI, ctx.UI.Theme
	local player = Players.LocalPlayer
	local scr = UI.screen("MiamiHUD", 5)
	local inset = GuiService:GetGuiInset()
	local GLASS = Color3.fromRGB(8, 10, 16)
	local GREEN = Color3.fromRGB(114, 204, 114)

	local function txt(parent, props)
		local l = UI.new("TextLabel", { BackgroundTransparency = 1, TextColor3 = T.Text, TextSize = 14, FontFace = font(), Parent = parent })
		for k, v in pairs(props) do
			l[k] = v
		end
		return l
	end
	local function shadow(l)
		l.TextStrokeTransparency = 0.45
		l.TextStrokeColor3 = Color3.new(0, 0, 0)
		return l
	end

	-- Uhr: seit Prompt 14 nur noch im Handy (Statusleiste + Startbildschirm mit Wochentag)

	-- OBEN RECHTS: Logo + Geld ----------------------------------------------------------------------
	local brand = UI.new("Frame", { Name = "Brand", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 4), Size = UDim2.fromOffset(250, 120), BackgroundTransparency = 1, Parent = scr })
	local logo = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Parent = brand })
	local logoList = UI.list(logo, 6, true)
	logoList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	logoList.VerticalAlignment = Enum.VerticalAlignment.Center
	shadow(txt(logo, { LayoutOrder = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30), FontFace = font(Enum.FontWeight.Heavy, true), TextSize = 26, Text = "MIAMI" }))
	local stateLbl = shadow(txt(logo, { LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30), FontFace = font(Enum.FontWeight.Light, true), TextSize = 26, Text = "STATE" }))
	stateLbl.TextColor3 = Color3.new(1, 1, 1)
	UI.new("UIGradient", { Color = ColorSequence.new(T.Accent, T.Accent2), Parent = stateLbl })
	local rule = UI.new("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 33), Size = UDim2.fromOffset(150, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = brand })
	UI.new("UIGradient", { Transparency = NumberSequence.new(1, 0.35), Parent = rule })

	local function moneyRow(y, label, labelColor)
		local row = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, y), Size = UDim2.new(1, 0, 0, 26), Parent = brand })
		local value = shadow(txt(row, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(1, -60, 1, 0), FontFace = font(Enum.FontWeight.Bold), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Right, Text = "$0" }))
		local tag = shadow(txt(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -0, 0.5, 1), Size = UDim2.fromOffset(44, 16), FontFace = font(Enum.FontWeight.Bold), TextSize = 10, TextColor3 = labelColor, TextXAlignment = Enum.TextXAlignment.Right, Text = label }))
		value:GetPropertyChangedSignal("TextBounds"):Connect(function()
			tag.Position = UDim2.new(1, -value.TextBounds.X - 8, 0.5, 1)
		end)
		local delta = shadow(txt(row, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.new(1, 0, 0, 16), FontFace = font(Enum.FontWeight.Bold), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 1, Text = "" }))
		return value, delta
	end
	local cashLbl, cashDelta = moneyRow(40, "CASH", GREEN)
	local bankLbl, bankDelta = moneyRow(68, "BANK", Color3.fromRGB(120, 180, 255))
	local job = shadow(txt(brand, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 98), Size = UDim2.new(1, 0, 0, 14), FontFace = font(Enum.FontWeight.SemiBold), TextSize = 11, TextColor3 = Color3.fromRGB(190, 196, 210), TextXAlignment = Enum.TextXAlignment.Right, Text = "" }))

	local displayed = {}
	local function animateMoney(lbl, deltaLbl, key, target)
		local from = displayed[key]
		displayed[key] = target
		if from == nil or from == target then
			lbl.Text = ctx.Format.money(target)
			return
		end
		local diff = target - from
		deltaLbl.Text = (diff > 0 and "+" or "-") .. ctx.Format.money(math.abs(diff))
		deltaLbl.TextColor3 = diff > 0 and GREEN or T.Danger
		deltaLbl.TextTransparency = 0
		deltaLbl.Position = UDim2.new(1, 0, 1, 0)
		TweenService:Create(deltaLbl, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, Position = UDim2.new(1, 0, 1, 8) }):Play()
		local nv = Instance.new("NumberValue")
		nv.Value = from
		nv.Changed:Connect(function(v)
			lbl.Text = ctx.Format.money(math.floor(v + 0.5))
		end)
		local tw = TweenService:Create(nv, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Value = target })
		tw.Completed:Connect(function()
			lbl.Text = ctx.Format.money(target)
			nv:Destroy()
		end)
		tw:Play()
	end

	-- UNTEN LINKS: Lebensanzeige + Status unter der Minimap -------------------------------------------
	local status = UI.new("Frame", { Name = "Status", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -14), Size = UDim2.fromOffset(252, 8), BackgroundTransparency = 1, Parent = scr })
	local function bar(x, w, color)
		local bg = UI.new("Frame", { BorderSizePixel = 0, Position = UDim2.fromOffset(x, 0), Size = UDim2.new(0, w, 0, 6), BackgroundColor3 = GLASS, BackgroundTransparency = 0.35, Parent = status })
		UI.corner(bg, 3)
		local fill = UI.new("Frame", { BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, Parent = bg })
		UI.corner(fill, 3)
		return fill, bg
	end
	local hpFill = bar(0, 168, Color3.fromRGB(96, 196, 110))
	local stFill = bar(172, 80, T.Accent) -- Status: Ausdauer/Dienst (Akzent), zeigt Dienststatus farbig
	local function updateHealth()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local f = hum and math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1) or 0
		TweenService:Create(hpFill, TweenInfo.new(0.25), { Size = UDim2.fromScale(f, 1) }):Play()
		hpFill.BackgroundColor3 = (f < 0.25 and T.Danger) or (f < 0.5 and T.Warning) or Color3.fromRGB(96, 196, 110)
	end
	local function hookChar(char)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum then
			hum.HealthChanged:Connect(updateHealth)
			updateHealth()
		end
		Hud.Seatbelt = false
	end
	player.CharacterAdded:Connect(hookChar)
	if player.Character then
		task.spawn(hookChar, player.Character)
	end

	-- RECHTS: Schnellzugriff (Maus/Touch) -----------------------------------------------------------
	local dock = UI.new("Frame", { Name = "Dock", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 20), Size = UDim2.fromOffset(40, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = scr })
	UI.list(dock, 6)
	local tip = txt(scr, { AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = GLASS, BackgroundTransparency = 0.2, FontFace = font(Enum.FontWeight.SemiBold), TextSize = 12, Visible = false, ZIndex = 5 })
	UI.corner(tip, 6)
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = tip })
	local dockButtons = {}
	local entries = {
		{ "📱", "Handy", "U", "Phone" }, { "🗺", "Karte", "V", "CityMap" }, { "🎒", "Inventar", "I", "Inventory" },
		{ "👤", "Profil", "P", "Profile" }, { "💼", "Berufe", "J", "Jobs" }, { "🤝", "Interaktion", "X", "Interact" },
		{ "🚨", "Notruf", "N", "Emergency" }, { "🛡", "Dienst", "K", "Duty", true }, { "📻", "Funk", "B", "Radio", true }, { "💻", "MDT", "M", "MDT", true },
	}
	for i, e in ipairs(entries) do
		local b = UI.new("TextButton", { LayoutOrder = i, AutoButtonColor = false, Size = UDim2.fromOffset(40, 40), BackgroundColor3 = GLASS, BackgroundTransparency = 0.35, Text = e[1], TextSize = 18, Font = Enum.Font.GothamBold, TextColor3 = T.Text, Parent = dock })
		UI.corner(b, 10)
		local s = UI.stroke(b, Color3.new(1, 1, 1), 1, 0.88)
		txt(b, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -1), Size = UDim2.fromOffset(12, 11), FontFace = font(Enum.FontWeight.Bold), TextSize = 9, TextColor3 = Color3.fromRGB(170, 176, 190), Text = e[3] })
		b.MouseEnter:Connect(function()
			TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0.1 }):Play()
			s.Color = T.Accent
			s.Transparency = 0.3
			tip.Text = e[2] .. "  [" .. e[3] .. "]"
			tip.Position = UDim2.fromOffset(b.AbsolutePosition.X - 8, b.AbsolutePosition.Y + 20)
			tip.Visible = true
		end)
		b.MouseLeave:Connect(function()
			TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0.35 }):Play()
			s.Color = Color3.new(1, 1, 1)
			s.Transparency = 0.88
			tip.Visible = false
		end)
		b.MouseButton1Click:Connect(function()
			local name = e[4]
			if name == "Duty" then
				local fac = player:GetAttribute("Faction")
				name = (fac == "Police") and "Police" or "Rescue"
			end
			if name == "Interact" then
				ctx.Controllers.Interact.TargetNearest(ctx)
			elseif ctx.OpenMenu == name then
				ctx.Controllers[name].Close()
				ctx.Closed(name)
			else
				ctx.Open(name)
			end
		end)
		dockButtons[e[4]] = { b, e[5] }
	end

	-- UNTEN RECHTS: Fahrzeuganzeige -------------------------------------------------------------------
	local veh = UI.new("Frame", { Name = "Vehicle", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, 40), Size = UDim2.fromOffset(270, 112), BackgroundTransparency = 1, Visible = false, Parent = scr })
	local vGroup = UI.new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = GLASS, BackgroundTransparency = 0.3, GroupTransparency = 1, Parent = veh })
	UI.corner(vGroup, 14)
	UI.stroke(vGroup, Color3.new(1, 1, 1), 1, 0.9)
	local speedLbl = txt(vGroup, { Position = UDim2.fromOffset(16, 6), Size = UDim2.fromOffset(120, 54), FontFace = font(Enum.FontWeight.Heavy, true), TextSize = 50, TextXAlignment = Enum.TextXAlignment.Left, Text = "0" })
	txt(vGroup, { Position = UDim2.fromOffset(18, 56), Size = UDim2.fromOffset(60, 12), FontFace = font(Enum.FontWeight.Bold), TextSize = 10, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Left, Text = "KM/H" })
	local nameLbl = txt(vGroup, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(130, 16), FontFace = font(Enum.FontWeight.Bold), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Text = "" })
	local plate = UI.new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 32), Size = UDim2.fromOffset(84, 18), BackgroundColor3 = Color3.fromRGB(236, 238, 242), TextColor3 = Color3.fromRGB(20, 30, 60), FontFace = font(Enum.FontWeight.Bold), TextSize = 11, Text = "", Parent = vGroup })
	UI.corner(plate, 4)
	-- Statussymbole: Gurt, Licht, Warnblinker, Sondersignal
	local icons = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 56), Size = UDim2.fromOffset(130, 18), BackgroundTransparency = 1, Parent = vGroup })
	local il = UI.list(icons, 8, true)
	il.HorizontalAlignment = Enum.HorizontalAlignment.Right
	local function icon(t, order)
		return txt(icons, { LayoutOrder = order, Size = UDim2.fromOffset(18, 18), Text = t, TextSize = 14, TextTransparency = 0.7, Font = Enum.Font.GothamBold })
	end
	local beltIcon = icon("🔗", 1)
	local lightIcon = icon("💡", 2)
	local hazIcon = icon("⚠", 3)
	local sirenIcon = icon("🚨", 4)
	-- Tank
	local fuelIcon = txt(vGroup, { Position = UDim2.fromOffset(16, 80), Size = UDim2.fromOffset(16, 14), Text = "⛽", TextSize = 12, Font = Enum.Font.GothamBold })
	local fuelBg = UI.new("Frame", { BorderSizePixel = 0, Position = UDim2.fromOffset(36, 85), Size = UDim2.new(1, -100, 0, 5), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.85, Parent = vGroup })
	UI.corner(fuelBg, 3)
	local fuelFill = UI.new("Frame", { BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Warning, Parent = fuelBg })
	UI.corner(fuelFill, 3)
	local fuelPct = txt(vGroup, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 80), Size = UDim2.fromOffset(52, 14), FontFace = font(Enum.FontWeight.Bold), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, Text = "100%" })
	local hint = shadow(txt(veh, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 1, 4), Size = UDim2.new(1, 0, 0, 14), FontFace = font(Enum.FontWeight.SemiBold), TextSize = 11, TextColor3 = Color3.fromRGB(200, 206, 220), TextXAlignment = Enum.TextXAlignment.Right, Text = "" }))

	local current -- { model, seat, driver }
	local function showVehicle(on)
		if on then
			veh.Visible = true
			TweenService:Create(veh, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Position = UDim2.new(1, -24, 1, -24) }):Play()
			TweenService:Create(vGroup, TweenInfo.new(0.35), { GroupTransparency = 0 }):Play()
		else
			local tw = TweenService:Create(veh, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Position = UDim2.new(1, -24, 1, 40) })
			TweenService:Create(vGroup, TweenInfo.new(0.25), { GroupTransparency = 1 }):Play()
			tw.Completed:Connect(function()
				if not current then
					veh.Visible = false
				end
			end)
			tw:Play()
		end
	end
	local function onSeat(active, seatPart)
		if active and seatPart and seatPart.Parent and CollectionService:HasTag(seatPart.Parent, "Vehicle") then
			local m = seatPart.Parent
			current = { model = m, seat = seatPart, driver = seatPart:IsA("VehicleSeat") }
			Hud.Seatbelt = false
			nameLbl.Text = m:GetAttribute("DisplayName") or m:GetAttribute("VehicleType") or "Fahrzeug"
			plate.Text = m:GetAttribute("Plate") or ""
			plate.Visible = plate.Text ~= ""
			local settings = ctx.Profile and ctx.Profile.Phone and ctx.Profile.Phone.Settings
			local hints = not settings or settings.ShowHints ~= false
			hint.Text = hints and (current.driver and (m:GetAttribute("Emergency") and "C Gurt  ·  Q Licht  R Sirene  H Warnbl.  L Licht" or "C Gurt  ·  H Warnblinker  ·  L Licht  ·  Leertaste Aussteigen") or "C Gurt  ·  Leertaste Aussteigen") or ""
			sirenIcon.Visible = m:GetAttribute("Emergency") ~= nil
			showVehicle(true)
		else
			current = nil
			Hud.Seatbelt = false
			showVehicle(false)
		end
	end
	local function hookSeat(char)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum then
			hum.Seated:Connect(onSeat)
		end
	end
	player.CharacterAdded:Connect(hookSeat)
	if player.Character then
		task.spawn(hookSeat, player.Character)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not current then
			return
		end
		if input.KeyCode == Enum.KeyCode.C then
			Hud.Seatbelt = not Hud.Seatbelt
			UI.toast(Hud.Seatbelt and "Sicherheitsgurt angelegt" or "Sicherheitsgurt geloest", Hud.Seatbelt and "success" or "warning")
		end
	end)

	-- Sichtbarkeit (Charakter erstellt) und Beruf ----------------------------------------------------
	local function refresh()
		local created = player:GetAttribute("CharacterCreated") == true
		brand.Visible, status.Visible, dock.Visible = created, created, created
		animateMoney(cashLbl, cashDelta, "Cash", player:GetAttribute("Cash") or 0)
		animateMoney(bankLbl, bankDelta, "Bank", player:GetAttribute("Bank") or 0)
		local fac = player:GetAttribute("Faction") or "Civilian"
		local f = ctx.Config.Factions[fac]
		local r = f and f.Ranks[player:GetAttribute("Rank") or 1]
		local onDuty = player:GetAttribute("OnDuty") == true
		job.Text = r and string.upper(r.Name .. (onDuty and "  ·  IM DIENST" or "")) or ""
		job.TextColor3 = (f and fac ~= "Civilian") and f.Color or Color3.fromRGB(190, 196, 210)
		stFill.BackgroundColor3 = (onDuty and f and f.Color) or T.Accent
		local service = (fac == "Police" or fac == "Fire" or fac == "EMS") and onDuty
		for name, d in pairs(dockButtons) do
			if d[2] then
				d[1].Visible = service and (name ~= "MDT" or fac == "Police")
			end
		end
	end
	for _, a in ipairs({ "Cash", "Bank", "Faction", "Rank", "OnDuty", "CharacterCreated" }) do
		player:GetAttributeChangedSignal(a):Connect(refresh)
	end
	refresh()

	-- Takt: Fahrzeugdaten, Ausblenden bei grossen Menues (Handy/Karte) ---------------------------
	local accClock, accVeh, lastOpen = 1, 0, nil
	RunService.RenderStepped:Connect(function(dt)
		accClock += dt
		if accClock >= 0.5 then
			accClock = 0
			-- Handy und Stadtkarte haben Vorrang: HUD unten links dezent ausblenden
			local open = ctx.OpenMenu
			if open ~= lastOpen then
				lastOpen = open
				local hide = open == "Phone" or open == "CityMap"
				local mm = ctx.Controllers.Minimap
				if mm and mm.SetFaded then
					mm.SetFaded(hide)
				end
				status.Visible = not hide and player:GetAttribute("CharacterCreated") == true
			end
		end
		local c = current
		if not c then
			return
		end
		accVeh += dt
		if accVeh < 1 / 15 then
			return
		end
		accVeh = 0
		local m = c.model
		local ch = m and m.Parent and m:FindFirstChild("Chassis")
		if not ch then
			return
		end
		local kmh = math.floor(math.abs(ch.AssemblyLinearVelocity:Dot(ch.CFrame.LookVector)) * STUDS_TO_KMH + 0.5)
		speedLbl.Text = tostring(kmh)
		local fuel = m:GetAttribute("Fuel")
		if fuel then
			fuelBg.Visible, fuelPct.Visible, fuelIcon.Visible = true, true, true
			fuelFill.Size = UDim2.fromScale(math.clamp(fuel / 100, 0, 1), 1)
			fuelFill.BackgroundColor3 = fuel < 15 and T.Danger or T.Warning
			fuelPct.Text = math.floor(fuel) .. "%"
		else
			fuelBg.Visible, fuelPct.Visible, fuelIcon.Visible = false, false, false
		end
		-- Gurt: angelegt = hell, nicht angelegt und in Fahrt = rot blinkend
		if Hud.Seatbelt then
			beltIcon.TextTransparency, beltIcon.TextColor3 = 0, T.Success
		else
			beltIcon.TextColor3 = T.Danger
			beltIcon.TextTransparency = (kmh > 15 and (os.clock() % 0.8) < 0.4) and 0 or 0.55
		end
		lightIcon.TextTransparency = m:GetAttribute("Headlights") and 0 or 0.7
		hazIcon.TextTransparency = m:GetAttribute("Hazard") and ((os.clock() % 0.8) < 0.4 and 0 or 0.4) or 0.7
		sirenIcon.TextTransparency = (m:GetAttribute("LightsOn") or m:GetAttribute("Siren")) and 0 or 0.7
	end)
end

return Hud
