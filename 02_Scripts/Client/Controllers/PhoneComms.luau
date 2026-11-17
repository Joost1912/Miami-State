-- Smartphone-Apps NACHRICHTEN und TELEFON (Prompt 12) + Anruffenster.
-- Haengt sich in das bestehende Smartphone (Phone.Apps, Phone.Helpers) - das Handy selbst bleibt unveraendert.
-- Alle Daten kommen vom Server (CommsService); Texte sind dort bereits durch den Roblox-Textfilter gelaufen.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local PC = {}
local ctxRef, Phone
local openChat -- { With, List, Name }
local callGui, callState
local lastCallsSeen = 0
local thumbCache = {}

local function T()
	return ctxRef.UI.Theme
end
local function UI()
	return ctxRef.UI
end
local function clock(t)
	return os.date("%H:%M", t)
end
local function dateTime(t)
	return os.date("%d.%m. %H:%M", t)
end

local function avatar(parent, userId, size)
	local img = UI().new("ImageLabel", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = T().Panel2, Image = thumbCache[userId] or "", Parent = parent })
	UI().corner(img, size / 2)
	if not thumbCache[userId] and userId and userId > 0 then
		task.spawn(function()
			local ok, url = pcall(function()
				return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
			end)
			if ok then
				thumbCache[userId] = url
				if img.Parent then
					img.Image = url
				end
			end
		end)
	end
	return img
end

local function unreadTotal()
	local p = ctxRef and ctxRef.Profile
	local n = 0
	for _, c in pairs(p and p.Phone.Chats or {}) do
		if not c.Muted then
			n += c.Unread or 0
		end
	end
	return n
end
local function missedTotal()
	local p = ctxRef and ctxRef.Profile
	local n = 0
	for _, c in ipairs(p and p.Phone.Calls or {}) do
		if c.Dir == "Missed" and c.T > lastCallsSeen then
			n += 1
		end
	end
	return n
end

-- NACHRICHTEN -----------------------------------------------------------------------------------------
local renderChat
local function renderChats()
	local H = Phone.Helpers
	openChat = nil
	local c = H.appHeader("Nachrichten", Color3.fromRGB(80, 210, 110))
	local res = ctxRef.Request("Comms.Chats", nil, true)
	if not res.ok then
		return
	end
	H.small(c, "Deine Nummer: " .. res.data.Number, 11, T().Muted)
	local new = UI().button(c, "+  Neuer Chat", "primary", { Size = UDim2.new(1, -4, 0, 34), TextSize = 13 })
	new.MouseButton1Click:Connect(function()
		local cc = H.appHeader("Neuer Chat", Color3.fromRGB(80, 210, 110))
		H.small(cc, "Kontakt waehlen oder Nummer eingeben:", 12, T().Text)
		local box = UI().input(cc, "305-123-4567", { Size = UDim2.new(1, -4, 0, 34), TextSize = 13 })
		UI().button(cc, "Chat oeffnen", "secondary", { Size = UDim2.new(1, -4, 0, 32), TextSize = 12 }).MouseButton1Click:Connect(function()
			local r = ctxRef.Request("Comms.Lookup", { Number = box.Text })
			if r.ok then
				renderChat(r.data.UserId)
			end
		end)
		for _, ct in ipairs(ctxRef.Profile.Phone.Contacts) do
			local row = H.card(cc, 46)
			avatar(row, ct.UserId, 26).Position = UDim2.fromOffset(0, 0)
			local b = UI().new("TextButton", { BackgroundTransparency = 1, Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -34, 1, 0), Font = T().FontBold, TextSize = 13, TextColor3 = T().Text, TextXAlignment = Enum.TextXAlignment.Left, Text = ct.Name, Parent = row })
			b.MouseButton1Click:Connect(function()
				renderChat(ct.UserId)
			end)
		end
	end)
	if #res.data.Chats == 0 then
		H.small(c, "Noch keine Unterhaltungen.", 12)
	end
	for _, ch in ipairs(res.data.Chats) do
		local row = H.card(c, 58)
		local av = avatar(row, ch.With, 36)
		av.Position = UDim2.fromOffset(0, 1)
		UI().new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -90, 0, 18), Font = T().FontBold, TextSize = 13, TextColor3 = T().Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = ch.Name .. (ch.Muted and "  🔕" or ""), Parent = row })
		UI().new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(44, 19), Size = UDim2.new(1, -70, 0, 16), Font = T().Font, TextSize = 11, TextColor3 = T().Muted, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = ch.Preview, Parent = row })
		UI().new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(44, 14), Font = T().Font, TextSize = 10, TextColor3 = T().Muted, TextXAlignment = Enum.TextXAlignment.Right, Text = ch.Last and clock(ch.Last) or "", Parent = row })
		if ch.Unread > 0 then
			local b = UI().new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 18), Size = UDim2.fromOffset(20, 18), BackgroundColor3 = Color3.fromRGB(80, 210, 110), Font = T().FontBlack, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), Text = tostring(ch.Unread), Parent = row })
			UI().corner(b, 9)
		end
		local hit = UI().new("TextButton", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", Parent = row })
		hit.MouseButton1Click:Connect(function()
			renderChat(ch.With)
		end)
	end
end

local function bubble(list, msg)
	local f = UI().new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = list })
	local b = UI().new("TextLabel", {
		AnchorPoint = Vector2.new(msg.Me and 1 or 0, 0), Position = UDim2.new(msg.Me and 1 or 0, 0, 0, 0), Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = msg.Me and Color3.fromRGB(40, 140, 90) or T().Panel2, Font = T().Font, TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Text = msg.X, Parent = f,
	})
	UI().new("UISizeConstraint", { MaxSize = Vector2.new(200, 2000), Parent = b })
	UI().new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 16), Parent = b })
	UI().corner(b, 12)
	UI().new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 4, 1, 12), Size = UDim2.fromOffset(40, 12), Font = T().Font, TextSize = 9, TextColor3 = Color3.fromRGB(220, 230, 230), TextXAlignment = Enum.TextXAlignment.Right, Text = clock(msg.T), Parent = b })
	return f
end

function renderChat(with)
	local H = Phone.Helpers
	local res = ctxRef.Request("Comms.Open", { With = with }, true)
	if not res.ok then
		ctxRef.UI.toast(res.msg or "Chat nicht verfuegbar", "error")
		return
	end
	local d = res.data
	local c = H.appHeader(d.Name, Color3.fromRGB(80, 210, 110))
	local head = UI().new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -4, 0, 28), Parent = c })
	UI().list(head, 6, true)
	UI().new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.5, 0, 1, 0), Font = T().Font, TextSize = 11, TextColor3 = d.Online and T().Success or T().Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = (d.Number or "") .. (d.Online and "  · online" or "  · nicht in der Stadt"), Parent = head })
	for _, a in ipairs({ { "📞", function()
		ctxRef.Request("Comms.Call", { To = with })
	end }, { d.Muted and "🔔" or "🔕", function()
		ctxRef.Request("Comms.Mute", { With = with })
		renderChat(with)
	end }, { "🗑", function()
		ctxRef.Request("Comms.Delete", { With = with })
		renderChats()
	end } }) do
		UI().button(head, a[1], "secondary", { Size = UDim2.fromOffset(34, 26), TextSize = 13 }).MouseButton1Click:Connect(a[2])
	end
	local list = UI().new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = c })
	UI().list(list, 6)
	for _, m in ipairs(d.Msgs) do
		bubble(list, m)
	end
	local box = UI().input(c, "Nachricht ...", { Size = UDim2.new(1, -4, 0, 34), TextSize = 13 })
	local function send()
		local txt = box.Text
		if txt == "" then
			return
		end
		local r = ctxRef.Request("Comms.Send", { To = with, Text = txt }, true)
		if r.ok then
			box.Text = ""
			bubble(list, { Me = true, X = r.data.Text, T = r.data.T })
		else
			ctxRef.UI.toast(r.msg or "Nicht gesendet", "error")
		end
	end
	box.FocusLost:Connect(function(enter)
		if enter then
			send()
		end
	end)
	UI().button(c, "Senden", "primary", { Size = UDim2.new(1, -4, 0, 32), TextSize = 13 }).MouseButton1Click:Connect(send)
	openChat = { With = with, List = list }
	task.defer(function()
		local scroll = c
		if scroll:IsA("ScrollingFrame") then
			scroll.CanvasPosition = Vector2.new(0, 1e6)
		end
	end)
end

-- TELEFON ---------------------------------------------------------------------------------------------
local function renderPhone()
	local H = Phone.Helpers
	local c = H.appHeader("Telefon", Color3.fromRGB(60, 190, 120))
	local res = ctxRef.Request("Comms.Log", nil, true)
	if not res.ok then
		return
	end
	local d = res.data
	lastCallsSeen = os.time()
	H.small(c, "Meine Nummer: " .. d.Number .. (d.Voice and "  ·  Sprache aktiv" or "  ·  Anrufe ohne Sprachuebertragung (Voice Chat/Audio API nicht aktiv)"), 11, T().Muted)
	local box = UI().input(c, "Nummer waehlen: 305-...", { Size = UDim2.new(1, -4, 0, 34), TextSize = 13 })
	UI().button(c, "📞  Anrufen", "primary", { Size = UDim2.new(1, -4, 0, 32), TextSize = 13 }).MouseButton1Click:Connect(function()
		ctxRef.Request("Comms.Call", { Number = box.Text })
	end)
	H.small(c, "KONTAKTE & FAVORITEN", 11, T().Accent)
	if #d.Contacts == 0 then
		H.small(c, "Keine Kontakte - Kontakte tauschen ueber das Interaktionsmenue (X).", 11)
	end
	for _, ct in ipairs(d.Contacts) do
		local row = H.card(c, 50)
		avatar(row, ct.UserId, 30)
		UI().new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -150, 0, 16), Font = T().FontBold, TextSize = 13, TextColor3 = T().Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = (ct.Favorite and "★ " or "") .. ct.Name, Parent = row })
		UI().new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(38, 16), Size = UDim2.new(1, -150, 0, 14), Font = T().Font, TextSize = 10, TextColor3 = ct.Online and T().Success or T().Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = (ct.Number or "-") .. (ct.Online and " · online" or ""), Parent = row })
		local btns = UI().new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(108, 28), Parent = row })
		UI().list(btns, 4, true)
		UI().button(btns, ct.Favorite and "★" or "☆", "secondary", { Size = UDim2.fromOffset(32, 28), TextSize = 13 }).MouseButton1Click:Connect(function()
			ctxRef.Request("Comms.Favorite", { UserId = ct.UserId }, true)
			renderPhone()
		end)
		UI().button(btns, "💬", "secondary", { Size = UDim2.fromOffset(32, 28), TextSize = 13 }).MouseButton1Click:Connect(function()
			renderChat(ct.UserId)
		end)
		UI().button(btns, "📞", "primary", { Size = UDim2.fromOffset(32, 28), TextSize = 13 }).MouseButton1Click:Connect(function()
			ctxRef.Request("Comms.Call", { To = ct.UserId })
		end)
	end
	H.small(c, "ANRUFVERLAUF", 11, T().Accent)
	if #d.Calls == 0 then
		H.small(c, "Noch keine Anrufe.", 11)
	end
	for i = 1, math.min(15, #d.Calls) do
		local e = d.Calls[i]
		local icon = (e.Dir == "Missed" and "↙ verpasst") or (e.Dir == "In" and "↙ eingehend") or "↗ ausgehend"
		H.small(c, string.format("%s  %s  ·  %s%s", e.Name, icon, dateTime(e.T), e.Dur > 0 and string.format(" · %d:%02d", e.Dur // 60, e.Dur % 60) or ""), 11, e.Dir == "Missed" and T().Danger or T().Text)
	end
end

-- Anruffenster (eigene ScreenGui, auch bei geschlossenem Handy) ---------------------------------------
local function closeCallGui()
	if callGui then
		callGui:Destroy()
		callGui = nil
	end
end
local function showCall(title, sub, buttons, timerFrom)
	closeCallGui()
	local UI_, T_ = UI(), T()
	callGui = UI_.screen("MiamiCall", 60)
	local f = UI_.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -140), Size = UDim2.fromOffset(340, 120), BackgroundColor3 = Color3.fromRGB(14, 16, 22), BackgroundTransparency = 0.05, Parent = callGui })
	UI_.corner(f, 18)
	UI_.stroke(f, Color3.fromRGB(60, 190, 120), 1, 0.4)
	UI_.pad(f, 14)
	UI_.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Font = T_.FontBlack, TextSize = 18, TextColor3 = T_.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = title, Parent = f })
	local subL = UI_.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 16), Font = T_.Font, TextSize = 12, TextColor3 = T_.Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = sub, Parent = f })
	local row = UI_.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 36), Parent = f })
	UI_.list(row, 8, true)
	for _, b in ipairs(buttons) do
		UI_.button(row, b[1], b[2], { Size = UDim2.new(1 / #buttons, -6, 1, 0), TextSize = 13 }).MouseButton1Click:Connect(b[3])
	end
	TweenService:Create(f, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { Position = UDim2.new(0.5, 0, 0, 70) }):Play()
	if timerFrom then
		task.spawn(function()
			while callGui and subL.Parent do
				local s = os.time() - timerFrom
				subL.Text = string.format("Verbunden  ·  %d:%02d%s", s // 60, s % 60, callState and callState.Voice and "  ·  🎙 Sprache" or "  ·  ohne Sprache")
				task.wait(1)
			end
		end)
	end
end

function PC.Incoming(ctx, data)
	callState = { Id = data.Id, State = "Ringing", Incoming = true }
	showCall("📞 " .. data.Name, "ruft an  ·  " .. data.Number, {
		{ "Annehmen", "primary", function()
			ctx.Request("Comms.Answer", { Id = data.Id, Accept = true }, true)
		end },
		{ "Ablehnen", "danger", function()
			ctx.Request("Comms.Answer", { Id = data.Id, Accept = false }, true)
		end },
	})
end

function PC.State(ctx, data)
	if data.State == "Ringing" then
		callState = { Id = data.Id, State = "Ringing" }
		showCall("📞 " .. data.Name, "Klingelt ...  ·  " .. (data.Number or ""), {
			{ "Auflegen", "danger", function()
				ctx.Request("Comms.Hangup", nil, true)
			end },
		})
	elseif data.State == "Active" then
		callState = { Id = data.Id, State = "Active", Voice = data.Voice }
		showCall("📞 " .. data.Name, "Verbunden", {
			{ "Auflegen", "danger", function()
				ctx.Request("Comms.Hangup", nil, true)
			end },
		}, data.Started)
	elseif data.State == "Ended" then
		callState = nil
		closeCallGui()
		local reasons = { Declined = "Anruf abgelehnt", Timeout = "Keine Antwort", Cancel = "Anruf beendet", Hangup = "Anruf beendet", Offline = "Verbindung getrennt" }
		ctx.UI.toast((reasons[data.Reason] or "Anruf beendet") .. (data.Duration and data.Duration > 0 and string.format(" (%d:%02d)", data.Duration // 60, data.Duration % 60) or ""), "info")
	end
end

function PC.Message(ctx, data)
	if openChat and openChat.With == data.From and openChat.List.Parent then
		bubble(openChat.List, { Me = false, X = data.Text, T = data.T })
		ctx.Request("Comms.Open", { With = data.From }, true)
		return
	end
	if not data.Muted then
		ctx.UI.toast("💬 " .. data.Name .. ": " .. (#data.Text > 60 and (data.Text:sub(1, 57) .. "...") or data.Text), "info")
	end
end

-- von aussen (Interaktionsmenue): Chat mit einem Spieler oeffnen (Handy muss offen sein)
function PC.OpenChat(with)
	if Phone and Phone.IsOpen and Phone.IsOpen() then
		renderChat(with)
	end
end

function PC.Start(ctx)
	ctxRef = ctx
	Phone = ctx.Controllers.Phone
	for i, app in ipairs(Phone.Apps) do
		if app.Id == "Messages" then
			app.Open = renderChats
			app.Badge = unreadTotal
			table.insert(Phone.Apps, i + 1, { Id = "Calls", Name = "Telefon", Icon = "📞", Color = Color3.fromRGB(60, 190, 120), Open = renderPhone, Badge = missedTotal })
			break
		end
	end
end

return PC
