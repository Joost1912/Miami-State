-- Aktivitaeten-Anzeige (Prompt 10): Fortschrittsbalken (Training, Bowling, Arcade, Basketball), Tanzen (Emote),
-- lokale Effekte: Tanzflaechen (Tag "DanceTile") und Kinoleinwaende (Tag "CinemaScreen") nur in der Naehe animiert.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Act = {}
local gui, box, label, fill
local FILMS = { "MIAMI NIGHTS", "OCEAN DRIVE 2", "THE HEIST", "BAYFRONT STORY", "NEON SUMMER" }

local function hum()
	local c = Players.LocalPlayer.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

function Act.Push(ctx, data)
	local UI, T = ctx.UI, ctx.UI.Theme
	if data.Kind == "Dance" then
		local h = hum()
		if h then
			local ok = pcall(function()
				h:PlayEmote(({ "dance", "dance2", "dance3" })[math.random(1, 3)])
			end)
			UI.toast(ok and "Tanzen! (Bewegen beendet den Tanz)" or "Tanzen nicht moeglich", ok and "success" or "error")
		end
		return
	elseif data.Kind == "Watch" then
		UI.toast("Film ab! Setz dich und geniess die Vorstellung.", "info")
		return
	elseif data.Kind == "Meet" then
		UI.toast("Autotreffen: Fahrzeug abstellen, Motorhaube auf, Leute treffen!", "info")
		return
	elseif data.Kind == "Eat" then
		return
	end
	if not data.Seconds then
		return
	end
	box.Visible = true
	label.Text = string.upper(data.Name) .. ((data.Fee and data.Fee > 0) and ("  ·  " .. ctx.Format.money(data.Fee)) or "")
	fill.Size = UDim2.fromScale(0, 1)
	TweenService:Create(fill, TweenInfo.new(data.Seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
	local h = hum()
	if h and data.Kind == "Shoot" then
		h.Jump = true
	end
	task.delay(data.Seconds + 0.2, function()
		box.Visible = false
	end)
end

function Act.Start(ctx)
	local UI, T = ctx.UI, ctx.UI.Theme
	gui = UI.screen("MiamiActivity", 9)
	box = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -120), Size = UDim2.fromOffset(320, 46), BackgroundColor3 = Color3.fromRGB(8, 10, 16), BackgroundTransparency = 0.25, Visible = false, Parent = gui })
	UI.corner(box, 10)
	label = UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 16), Font = T.FontBold, TextSize = 12, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = box })
	local bg = UI.new("Frame", { BorderSizePixel = 0, Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 6), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.85, Parent = box })
	UI.corner(bg, 3)
	fill = UI.new("Frame", { BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, Parent = bg })
	UI.corner(fill, 3)
	UI.new("UIGradient", { Color = ColorSequence.new(T.Accent, T.Accent2), Parent = fill })

	-- lokale Effekte (4 Hz, nur Objekte im Umkreis von 220 Studs)
	local acc, film, filmT = 0, 1, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local r = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		local t = os.clock()
		for _, tile in ipairs(CollectionService:GetTagged("DanceTile")) do
			if tile:IsA("BasePart") and (tile.Position - r.Position).Magnitude < 220 then
				local seed = (tile:GetAttribute("Seed") or 0)
				tile.Color = Color3.fromHSV(((t * 0.35 + seed * 0.13) % 1), 0.85, ((math.floor(t * 2 + seed) % 3 == 0) and 1 or 0.35))
			end
		end
		filmT += 0.25
		if filmT > 12 then
			filmT = 0
			film = film % #FILMS + 1
		end
		for _, scr in ipairs(CollectionService:GetTagged("CinemaScreen")) do
			if scr:IsA("BasePart") and (scr.Position - r.Position).Magnitude < 220 then
				local sg = scr:FindFirstChild("Film")
				local lbl = sg and sg:FindFirstChild("Title")
				if lbl then
					lbl.Text = FILMS[film]
					lbl.TextColor3 = Color3.fromHSV((t * 0.05) % 1, 0.4, 1)
					sg.Frame.BackgroundColor3 = Color3.fromHSV((t * 0.03 + 0.6) % 1, 0.7, 0.25 + 0.1 * math.sin(t))
				end
			end
		end
	end)
end

return Act
