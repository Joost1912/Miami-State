-- Statusanzeigen ohne Menue: Handschellen/Haft-Banner, Verkehrskontrolle, Einsatz-Wegpunkt.
-- Rein lokale Darstellung; Zustand kommt aus Server-Attributen bzw. Push-Ereignissen.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local O = {}
local banner, bannerText, waypoint, wpLabel, wpCallId
local stopUntil = 0

function O.Close() end -- kein Menue

local function ensureBanner(ctx)
	if banner then
		return
	end
	local UI, T = ctx.UI, ctx.UI.Theme
	local scr = UI.screen("MiamiOverlays", 8)
	banner = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.fromOffset(460, 44), BackgroundColor3 = T.Danger, BackgroundTransparency = 0.1, Visible = false, Parent = scr })
	UI.corner(banner, 10)
	bannerText = UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = T.FontBlack, TextSize = 17, TextColor3 = Color3.new(1, 1, 1), Text = "", Parent = banner })
end

function O.Start(ctx)
	local player = Players.LocalPlayer
	ensureBanner(ctx)
	local function refresh()
		local text
		if player:GetAttribute("Jailed") then
			local s = player:GetAttribute("JailRemaining") or 0
			text = string.format("IN HAFT  -  noch %d:%02d", s // 60, s % 60)
		elseif os.clock() < stopUntil then
			text = O._stopText
		elseif player:GetAttribute("Cuffed") then
			text = "GEFESSELT" .. (player:GetAttribute("Escorted") and "  -  wirst abgefuehrt" or "") .. (player:GetAttribute("Detained") and "  -  im Polizeifahrzeug" or "")
		end
		banner.Visible = text ~= nil
		bannerText.Text = text or ""
	end
	for _, a in ipairs({ "Jailed", "JailRemaining", "Cuffed", "Escorted", "Detained" }) do
		player:GetAttributeChangedSignal(a):Connect(refresh)
	end
	O._refresh = refresh
	refresh()
	-- Wegpunkt-Distanz aktualisieren
	RunService.Heartbeat:Connect(function()
		if waypoint and wpLabel then
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if r then
				local d = (r.Position - waypoint.Position).Magnitude
				wpLabel.Text = string.format("%s\n%d m", O._wpName or "", math.floor(d * 0.28))
				if d < 30 then
					O.WaypointClear(ctx, { CallId = wpCallId })
				end
			end
		end
	end)
end

function O.TrafficStop(ctx, data)
	O._stopText = string.format("VERKEHRSKONTROLLE  -  %s: Bitte rechts anhalten!", data.Callsign or "Polizei")
	stopUntil = os.clock() + 20
	ctx.UI.toast("Polizei (" .. tostring(data.Callsign) .. "): Fahrzeug " .. tostring(data.Plate) .. " - rechts ranfahren!", "error")
	if O._refresh then
		O._refresh()
		task.delay(20.2, O._refresh)
	end
end

function O.Waypoint(ctx, data)
	O.WaypointClear(ctx)
	local T = ctx.UI.Theme
	local p = Instance.new("Part")
	p.Name = "MiamiWaypoint"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = Vector3.new(data.X, (data.Y or 0) + 6, data.Z)
	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(150, 46)
	bb.Parent = p
	wpLabel = Instance.new("TextLabel")
	wpLabel.BackgroundColor3 = T.Danger
	wpLabel.BackgroundTransparency = 0.15
	wpLabel.Size = UDim2.fromScale(1, 1)
	wpLabel.Font = T.FontBold
	wpLabel.TextSize = 13
	wpLabel.TextColor3 = Color3.new(1, 1, 1)
	wpLabel.Parent = bb
	Instance.new("UICorner", wpLabel).CornerRadius = UDim.new(0, 8)
	p.Parent = workspace
	waypoint, wpCallId, O._wpName = p, data.CallId, data.Label
	ctx.UI.toast("Wegpunkt gesetzt: " .. tostring(data.Label), "info")
end

function O.WaypointClear(_ctx, data)
	if data and data.CallId and wpCallId and data.CallId ~= wpCallId then
		return
	end
	if waypoint then
		waypoint:Destroy()
	end
	waypoint, wpLabel, wpCallId = nil, nil, nil
end

return O
