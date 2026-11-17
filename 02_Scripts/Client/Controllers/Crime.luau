-- Crime-HUD (Prompt 09): eigene ScreenGui "MiamiCrimeHUD" oben links (bestehende Anzeigen bleiben unberuehrt).
-- * Fahndungsstatus (nur eigener, kommt per privatem Push \"Wanted\")
-- * Ueberfall-Panel fuer Beteiligte (Push \"Heist\"): Status, Countdown, Beute, Polizei, Abbrechen
-- * Alarm-Meldung fuer Polizei im Dienst (oeffentlicher Status ReplicatedStorage.MiamiCrime) mit \"Einsatz uebernehmen\"
-- * Alarmlampen am Tatort blinken lokal (Tag HeistAlarmLight), Hehler-Fenster (Push \"OpenFence\")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local C = {}
local ctxRef, scr, wantedBox, heistBox, policeBox, fenceWin
local heist -- letzter privater Ueberfallstatus
local wanted = { Level = 0 }

function C.Close() end

local function fmtTime(s)
	s = math.max(0, math.floor(s))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- Fahndung ---------------------------------------------------------------------------------------------------
local function renderWanted()
	local UI, T = ctxRef.UI, ctxRef.UI.Theme
	wantedBox:ClearAllChildren()
	local lvl = wanted.Level or 0
	wantedBox.Visible = lvl > 0
	if lvl == 0 then
		return
	end
	local cfg = ctxRef.Config.Crime.WantedLevels[lvl]
	UI.corner(wantedBox, 12)
	UI.stroke(wantedBox, cfg.Color, 1.5, 0.2)
	UI.pad(wantedBox, 10)
	local pips = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(66, 18), Parent = wantedBox })
	UI.list(pips, 4, true)
	for i = 1, 3 do
		local p = UI.new("Frame", { Size = UDim2.fromOffset(18, 18), BackgroundColor3 = (i <= lvl) and cfg.Color or T.Panel2, Parent = pips })
		UI.corner(p, 4)
		p.Rotation = 45
	end
	UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(78, -2), Size = UDim2.new(1, -78, 0, 18), Font = T.FontBlack, TextSize = 14, TextColor3 = cfg.Color, TextXAlignment = Enum.TextXAlignment.Left, Text = cfg.Name:upper(), Parent = wantedBox })
	local sub = UI.new("TextLabel", { Name = "Sub", BackgroundTransparency = 1, Position = UDim2.fromOffset(78, 16), Size = UDim2.new(1, -78, 0, 14), Font = T.Font, TextSize = 11, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = wanted.Reason or "", Parent = wantedBox })
	if wanted.Until then
		task.spawn(function()
			while sub.Parent and wanted.Until do
				local left = wanted.Until - os.time()
				sub.Text = (wanted.Reason ~= "" and (wanted.Reason .. "  |  ") or "") .. (left > 0 and ("Stufe sinkt in " .. fmtTime(left)) or "...")
				task.wait(1)
			end
		end)
	end
end

function C.Wanted(ctx, data)
	ctxRef = ctx
	local old = wanted.Level or 0
	wanted = data or { Level = 0 }
	renderWanted()
	if (wanted.Level or 0) > old then
		ctx.UI.toast("Fahndungsstufe: " .. ctx.Config.Crime.WantedLevels[wanted.Level].Name, "error")
	end
end

-- Ueberfall (Taeter) -------------------------------------------------------------------------------------------
local function renderHeist()
	local UI, T, F = ctxRef.UI, ctxRef.UI.Theme, ctxRef.Format
	heistBox:ClearAllChildren()
	local h = heist
	heistBox.Visible = h ~= nil and (h.State == "Active" or h.Text ~= nil)
	if not heistBox.Visible then
		return
	end
	UI.corner(heistBox, 12)
	local active = h.State == "Active"
	UI.stroke(heistBox, active and T.Danger or T.Stroke, 1.5, 0.15)
	UI.pad(heistBox, 12)
	UI.list(heistBox, 6)
	UI.label(heistBox, (active and "UEBERFALL LAEUFT  -  " or "UEBERFALL  -  ") .. (h.Name or ""):upper(), 13, { Font = T.FontBlack, TextColor3 = active and T.Danger or T.Text })
	if active then
		local remaining = (h.Duration or 0) - (h.Progress or 0)
		local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Parent = heistBox })
		UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.5, 0, 1, 0), Font = T.FontBlack, TextSize = 28, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = fmtTime(remaining), Parent = row })
		UI.new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.5, 0, 1, 0), Font = T.FontBold, TextSize = 12, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Right, Text = "Stufe: " .. (h.Tier or ""), Parent = row })
		local bar = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, 0, 0, 8), Parent = heistBox })
		UI.corner(bar, 4)
		local fill = UI.new("Frame", { BackgroundColor3 = T.Danger, Size = UDim2.new(math.clamp((h.Progress or 0) / math.max(1, h.Duration or 1), 0, 1), 0, 1, 0), Parent = bar })
		UI.corner(fill, 4)
		local hint
		if h.CasesLeft and h.CasesLeft > 0 and (h.Id == "Jeweler") then
			hint = string.format("Vitrinen uebrig: %d  -  Prompt an der Vitrine halten", h.CasesLeft)
		elseif h.Inside then
			hint = "Im Tresorbereich - Fortschritt laeuft"
		else
			hint = "Zurueck in den Tresorbereich! Fortschritt pausiert"
		end
		UI.label(heistBox, hint, 12, { TextColor3 = (h.Inside or h.Id == "Jeweler") and T.Success or T.Warning, Font = T.FontBold })
	elseif h.Text then
		UI.label(heistBox, h.Text, 12, { TextColor3 = T.Text, AutomaticSize = Enum.AutomaticSize.Y })
	end
	UI.label(heistBox, "Deine Beute: " .. F.money(h.Loot or 0) .. "   |   Polizei: " .. ((h.Units or 0) > 0 and (h.Units .. " Einheit(en) auf Anfahrt") or "alarmiert") .. (h.CallId and ("  (#" .. h.CallId .. ")") or ""), 11, { TextColor3 = T.Muted })
	if active then
		local b = UI.button(heistBox, h.Starter and "UEBERFALL ABBRECHEN" or "AUSSTEIGEN", "secondary", { Size = UDim2.new(1, 0, 0, 28), TextSize = 12 })
		b.MouseButton1Click:Connect(function()
			ctxRef.Request("Crime.Cancel", {})
		end)
	end
end

function C.Heist(ctx, data)
	ctxRef = ctx
	if data and data.State == "Left" then
		heist = nil
	else
		heist = data
	end
	renderHeist()
	if heist and heist.State ~= "Active" and heist.Text then
		local snapshot = heist
		task.delay(12, function()
			if heist == snapshot then
				heist = nil
				renderHeist()
			end
		end)
	end
end

-- Polizei-Alarm -----------------------------------------------------------------------------------------------------
local function renderPolice()
	local UI, T = ctxRef.UI, ctxRef.UI.Theme
	local player = Players.LocalPlayer
	policeBox:ClearAllChildren()
	local isCop = player:GetAttribute("Faction") == "Police" and player:GetAttribute("OnDuty") == true
	local folder = ReplicatedStorage:FindFirstChild("MiamiCrime")
	local active = {}
	if isCop and folder then
		for _, f in ipairs(folder:GetChildren()) do
			if f:GetAttribute("State") == "Active" then
				table.insert(active, f)
			end
		end
	end
	policeBox.Visible = #active > 0
	if #active == 0 then
		return
	end
	UI.corner(policeBox, 12)
	UI.stroke(policeBox, T.Danger, 1.5, 0.1)
	UI.pad(policeBox, 10)
	UI.list(policeBox, 6)
	for _, f in ipairs(active) do
		UI.label(policeBox, "ALARM  -  " .. tostring(f:GetAttribute("Name")):upper(), 13, { Font = T.FontBlack, TextColor3 = T.Danger })
		UI.label(policeBox, string.format("Einsatz #%d  |  Taeter: %d  |  Einheiten: %d  |  %s", f:GetAttribute("CallId") or 0, f:GetAttribute("CrewCount") or 0, f:GetAttribute("Units") or 0, ctxRef.Config.MapData.DistrictAt(f:GetAttribute("X") or 0, f:GetAttribute("Z") or 0)), 11, { TextColor3 = T.Text })
		local b = UI.button(policeBox, "EINSATZ UEBERNEHMEN", "danger", { Size = UDim2.new(1, 0, 0, 26), TextSize = 12 })
		b.MouseButton1Click:Connect(function()
			ctxRef.Request("Dispatch.Attach", { Id = f:GetAttribute("CallId") })
		end)
	end
end

-- Alarmlampen ---------------------------------------------------------------------------------------------------------
local blinking = {}
local function setAlarm(heistId, on)
	if blinking[heistId] == on then
		return
	end
	blinking[heistId] = on
	if not on then
		return
	end
	task.spawn(function()
		local sound
		local lamps = {}
		for _, l in ipairs(CollectionService:GetTagged("HeistAlarmLight")) do
			if l:GetAttribute("HeistId") == heistId then
				table.insert(lamps, l)
			end
		end
		if lamps[1] then
			sound = Instance.new("Sound")
			sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
			sound.Volume = 0.6
			sound.RollOffMaxDistance = 120
			sound.Parent = lamps[1]
		end
		local phase = false
		while blinking[heistId] do
			phase = not phase
			for _, l in ipairs(lamps) do
				l.Material = phase and Enum.Material.Neon or Enum.Material.SmoothPlastic
				l.Color = phase and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(110, 20, 24)
				local pl = l:FindFirstChildOfClass("PointLight")
				if pl then
					pl.Enabled = phase
				end
			end
			if phase and sound then
				sound:Play()
			end
			task.wait(0.45)
		end
		for _, l in ipairs(lamps) do
			l.Material, l.Color = Enum.Material.SmoothPlastic, Color3.fromRGB(110, 20, 24)
			local pl = l:FindFirstChildOfClass("PointLight")
			if pl then
				pl.Enabled = false
			end
		end
		if sound then
			sound:Destroy()
		end
	end)
end

-- Hehler ----------------------------------------------------------------------------------------------------------------
function C.Fence(ctx, data)
	ctxRef = ctx
	local UI, T, F = ctx.UI, ctx.UI.Theme, ctx.Format
	if fenceWin then
		fenceWin:Destroy()
	end
	fenceWin = UI.screen("MiamiFence", 21)
	local _, content, close = UI.window(fenceWin, "Unbekannter", UDim2.fromOffset(420, 330), function()
		fenceWin:Destroy()
		fenceWin = nil
	end)
	UI.list(content, 8)
	UI.label(content, "\"Was hast du fuer mich? Ich zahle bar - mit Abschlag.\"", 13, { TextColor3 = T.Muted, Font = T.FontBold })
	local total, net = 0, 0
	for _, l in ipairs(data.Loot or {}) do
		total += l.Value
		net += l.Net
		UI.label(content, string.format("%dx %s  -  Wert %s", l.Count, l.Name, F.money(l.Value)), 13)
	end
	if #(data.Loot or {}) == 0 then
		UI.label(content, "Du hast nichts, was mich interessiert.", 13, { TextColor3 = T.Warning })
	end
	UI.label(content, string.format("Angebot: %s bar (%d %% Abschlag)  |  Limit diese Stunde: %s", F.money(math.min(net, data.CapLeft or 0)), (data.Cut or 0) * 100, F.money(math.max(0, data.CapLeft or 0))), 12, { TextColor3 = T.Success, Font = T.FontBold })
	local b = UI.button(content, "VERKAUFEN", "primary", { Size = UDim2.new(1, 0, 0, 38) })
	b.MouseButton1Click:Connect(function()
		if ctx.Request("Crime.Fence", {}).ok then
			close()
		end
	end)
end

function C.Start(ctx)
	ctxRef = ctx
	local UI, T = ctx.UI, ctx.UI.Theme
	scr = UI.screen("MiamiCrimeHUD", 7)
	-- Prompt 10: unter der Spieluhr (oben links) einreihen
	local top = math.max(game:GetService("GuiService"):GetGuiInset().Y, 36) + 72
	wantedBox = UI.new("Frame", { Name = "Wanted", Position = UDim2.fromOffset(16, top), Size = UDim2.fromOffset(260, 52), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.12, Visible = false, Parent = scr })
	heistBox = UI.new("Frame", { Name = "Heist", Position = UDim2.fromOffset(16, top + 62), Size = UDim2.fromOffset(320, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Bg, BackgroundTransparency = 0.08, Visible = false, Parent = scr })
	policeBox = UI.new("Frame", { Name = "PoliceAlert", Position = UDim2.fromOffset(16, top + 62), Size = UDim2.fromOffset(320, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Bg, BackgroundTransparency = 0.08, Visible = false, Parent = scr })
	-- oeffentlicher Status: Alarmlampen + Polizei-Meldung
	local folder = ReplicatedStorage:WaitForChild("MiamiCrime", 30)
	if folder then
		local function hook(f)
			local function update()
				setAlarm(f.Name, f:GetAttribute("Alarm") == true)
				renderPolice()
			end
			f.AttributeChanged:Connect(function(attr)
				if attr == "Alarm" or attr == "State" or attr == "Units" or attr == "CrewCount" or attr == "CallId" then
					update()
				end
			end)
			update()
		end
		for _, f in ipairs(folder:GetChildren()) do
			hook(f)
		end
		folder.ChildAdded:Connect(hook)
	end
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("OnDuty"):Connect(renderPolice)
	player:GetAttributeChangedSignal("Faction"):Connect(renderPolice)
	-- eigenen Status beim Start abfragen (Fahndung)
	task.delay(3, function()
		ctx.Request("Crime.State", nil, true)
	end)
end

return C
