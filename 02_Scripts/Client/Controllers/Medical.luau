-- Verletzungsanzeige (lokal): Hinweis bei leichter/schwerer Verletzung, Bewusstlosigkeit mit Liegeposition,
-- Abdunklung, Restzeit und Knoepfen (Hilfe rufen, Notaufnahme). Zustand kommt vom Server (Attribut "Injury").
-- Ausserdem: Untersuchungsbericht fuer Rettungskraefte.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Med = {}
local ctxRef, gui, badge, down, timerLbl, respawnBtn, poseConn
local report

function Med.Close() end

local LABELS = { Minor = { "LEICHT VERLETZT", Color3.fromRGB(255, 196, 80) }, Severe = { "SCHWER VERLETZT", Color3.fromRGB(255, 110, 60) } }

local function setPose(lying)
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if poseConn then
		poseConn:Disconnect()
		poseConn = nil
	end
	if not hum or not root then
		return
	end
	if lying then
		hum.PlatformStand = true
		local base = root.CFrame
		local flat = CFrame.new(base.Position.X, base.Position.Y - 1.6, base.Position.Z) * CFrame.Angles(0, select(2, base:ToOrientation()), 0) * CFrame.Angles(math.rad(-90), 0, 0)
		root.CFrame = flat
		-- liegen bleiben (nicht, wenn getragen oder im Fahrzeug)
		poseConn = RunService.Heartbeat:Connect(function()
			local p = Players.LocalPlayer
			if p:GetAttribute("Carried") or p:GetAttribute("Loaded") or hum.SeatPart then
				return
			end
			hum.PlatformStand = true
			root.AssemblyLinearVelocity = Vector3.new(0, math.min(root.AssemblyLinearVelocity.Y, 0), 0)
			root.AssemblyAngularVelocity = Vector3.zero
		end)
	else
		hum.PlatformStand = false
		local _, y = root.CFrame:ToOrientation()
		root.CFrame = CFrame.new(root.Position + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, y, 0)
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

local function refresh()
	local p = Players.LocalPlayer
	local st = p:GetAttribute("Injury")
	local lbl = LABELS[st]
	badge.Visible = lbl ~= nil
	if lbl then
		badge.Text = "✚  " .. lbl[1]
		badge.BackgroundColor3 = lbl[2]
	end
	local wasDown = down.Visible
	down.Visible = st == "Unconscious"
	if down.Visible and not wasDown then
		down.BackgroundTransparency = 1
		TweenService:Create(down, TweenInfo.new(1.2), { BackgroundTransparency = 0.35 }):Play()
		setPose(true)
	elseif wasDown and not down.Visible then
		setPose(false)
	end
end

function Med.Start(ctx)
	ctxRef = ctx
	local UI, T = ctx.UI, ctx.UI.Theme
	gui = UI.screen("MiamiMedical", 9)
	badge = UI.new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(220, 30), Font = T.FontBlack, TextSize = 14, TextColor3 = Color3.fromRGB(20, 20, 24), Visible = false, Parent = gui })
	UI.corner(badge, 8)
	down = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(60, 0, 0), BackgroundTransparency = 0.35, Visible = false, Parent = gui })
	local box = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(440, 210), BackgroundColor3 = T.Panel, BackgroundTransparency = 0.05, Parent = down })
	UI.corner(box, 14)
	UI.pad(box, 16)
	UI.list(box, 8)
	UI.label(box, "DU BIST BEWUSSTLOS", 24, { Font = T.FontBlack, TextColor3 = T.Danger })
	timerLbl = UI.label(box, "", 14, { TextColor3 = T.Text, Size = UDim2.new(1, 0, 0, 36), TextWrapped = true })
	local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), Parent = box })
	UI.list(row, 10, true)
	local help = UI.button(row, "🚑  HILFE RUFEN", "danger", { Size = UDim2.new(0.5, -5, 1, 0), TextSize = 14 })
	help.MouseButton1Click:Connect(function()
		ctx.Request("Medical.CallHelp")
	end)
	respawnBtn = UI.button(row, "NOTAUFNAHME", "secondary", { Size = UDim2.new(0.5, -5, 1, 0), TextSize = 14 })
	respawnBtn.MouseButton1Click:Connect(function()
		ctx.Request("Medical.Respawn")
	end)
	UI.label(box, "Rettungskraefte koennen dich stabilisieren und wiederbeleben.", 12, { TextColor3 = T.Muted })

	local p = Players.LocalPlayer
	for _, a in ipairs({ "Injury", "Stabilized" }) do
		p:GetAttributeChangedSignal(a):Connect(refresh)
	end
	p.CharacterAdded:Connect(function()
		task.wait(0.5)
		if poseConn then
			poseConn:Disconnect()
			poseConn = nil
		end
		down.Visible = false
		refresh()
	end)
	refresh()
	-- Restzeit (nur bei Bewusstlosigkeit)
	task.spawn(function()
		local cfg = ctx.Config.Rescue.Medical
		while true do
			task.wait(1)
			if down.Visible then
				local since = p:GetAttribute("DownSince") or os.time()
				local need = cfg.BleedoutSeconds + (p:GetAttribute("Stabilized") and cfg.StabilizedBonus or 0)
				local left = need - (os.time() - since)
				if left > 0 then
					timerLbl.Text = string.format("%sNotaufnahme moeglich in %d:%02d (Kosten $%d)", p:GetAttribute("Stabilized") and "Stabilisiert. " or "", left // 60, left % 60, cfg.RespawnCost)
					respawnBtn.AutoButtonColor = false
					respawnBtn.TextTransparency = 0.5
				else
					timerLbl.Text = string.format("Du kannst dich jetzt selbst in die Notaufnahme bringen lassen (Kosten $%d).", cfg.RespawnCost)
					respawnBtn.TextTransparency = 0
				end
			end
		end
	end)
end

-- Untersuchungsbericht (Rettungsdienst/Feuerwehr)
function Med.ShowExam(ctx, d)
	local UI, T = ctx.UI, ctx.UI.Theme
	if report then
		report:Destroy()
	end
	report = UI.screen("MiamiExam", 22)
	local f = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromOffset(300, 250), BackgroundColor3 = T.Panel, Parent = report })
	UI.corner(f, 14)
	UI.stroke(f, T.Stroke)
	UI.pad(f, 14)
	UI.list(f, 6)
	UI.label(f, "UNTERSUCHUNG", 12, { TextColor3 = T.Muted, Font = T.FontBold })
	UI.label(f, d.Name, 20, { Font = T.FontBlack })
	local col = (d.State == "Unconscious" and T.Danger) or (d.State == "Severe" and Color3.fromRGB(255, 110, 60)) or (d.State == "Minor" and T.Warning) or T.Success
	UI.label(f, d.StateName .. (d.Stabilized and "  (stabilisiert)" or ""), 15, { Font = T.FontBold, TextColor3 = col })
	UI.label(f, string.format("Vitalwerte: %d %%  |  Puls %d/min", d.Health, d.Pulse), 13, { TextColor3 = T.Text })
	UI.label(f, "Ursache: " .. tostring(d.Cause), 13, { TextColor3 = T.Text })
	if d.TimeLeft then
		UI.label(f, string.format("Kritische Zeit: %d:%02d", d.TimeLeft // 60, d.TimeLeft % 60), 13, { TextColor3 = T.Warning })
	end
	local hint = (d.State == "Unconscious") and (d.Stabilized and "Naechster Schritt: Wiederbeleben (Defibrillator)" or "Naechster Schritt: Stabilisieren (Verband)")
		or (d.State ~= "Healthy" and "Versorgen (Erste-Hilfe-Set) oder in der Notaufnahme behandeln") or "Keine Behandlung noetig"
	UI.label(f, hint, 12, { TextColor3 = T.Accent, Size = UDim2.new(1, 0, 0, 30), TextWrapped = true })
	local close = UI.button(f, "Schliessen", "secondary", { Size = UDim2.new(1, 0, 0, 30), TextSize = 12 })
	close.MouseButton1Click:Connect(function()
		report:Destroy()
		report = nil
	end)
	task.delay(15, function()
		if report and report.Parent then
			report:Destroy()
			report = nil
		end
	end)
end

return Med
