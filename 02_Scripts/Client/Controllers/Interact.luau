-- Interaktionsmenue fuer Spieler (Taste X): naechsten Spieler ansehen, Bargeld uebergeben.
-- Polizeibeamte im Dienst erhalten zusaetzlich Einsatzmassnahmen (Fesseln, Durchsuchen, Abfuehren,
-- Fahrzeug, Festnahme/Haft, Strafzettel, Verwarnung). Jede Massnahme prueft der Server erneut.
-- Weltobjekte (Geldautomat, Laeden, Tueren, NPCs) laufen ueber ProximityPrompts des InteractionService.
local Players = game:GetService("Players")
local X = {}
local screen

function X.Close()
	if screen then
		screen:Destroy()
		screen = nil
	end
end

-- liefert { UserId, Name } des naechsten Spielers (oder Studio-Testperson)
local function nearestTarget(range)
	local me = Players.LocalPlayer
	local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local best, bestD
	local function consider(uid, r)
		local d = (r.Position - root.Position).Magnitude
		if d <= range and (not bestD or d < bestD) then
			best, bestD = uid, d
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		local r = p ~= me and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r then
			consider(p.UserId, r)
		end
	end
	local npc = workspace:FindFirstChild("Suspect_TestNPC")
	if npc and npc:GetAttribute("TestTargetId") and npc:FindFirstChild("HumanoidRootPart") then
		consider(npc:GetAttribute("TestTargetId"), npc.HumanoidRootPart)
	end
	return best
end

function X.TargetNearest(ctx)
	local uid = nearestTarget(12)
	if not uid then
		ctx.UI.toast("Kein Spieler in der Naehe", "warning")
		return
	end
	ctx.Open("Interact", uid)
end

local function policeSection(ctx, content, info, reopen)
	local UI, T = ctx.UI, ctx.UI.Theme
	local P = ctx.Config.Police
	local st = info.State or {}
	UI.label(content, "POLIZEI  -  " .. (st.Jailed and "IN HAFT" or st.Cuffed and "GEFESSELT" or "frei") .. (st.Escorted and ", wird gefuehrt" or "") .. (st.Detained and ", im Fahrzeug" or ""), 12, { TextColor3 = T.Accent, Font = T.FontBold })
	local grid = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = content })
	UI.new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0, 28), CellPadding = UDim2.fromOffset(8, 6), Parent = grid })
	local function act(label, action, style, payload)
		local b = UI.button(grid, label, style or "secondary", { TextSize = 12 })
		b.MouseButton1Click:Connect(function()
			local p = payload or {}
			p.Target = info.UserId
			local r = ctx.Request(action, p)
			if r.ok then
				if action == "Justice.Search" and r.data then
					X.ShowSearch(ctx, r.data)
				else
					reopen()
				end
			end
		end)
	end
	if st.Cuffed then
		act("Handschellen ab", "Justice.Uncuff")
		act("Durchsuchen", "Justice.Search")
		act(st.Escorted and "Loslassen" or "Abfuehren", "Justice.Escort")
		act("In Fahrzeug", "Justice.PutInVehicle")
		act("Aus Fahrzeug", "Justice.TakeOut")
	else
		act("Handschellen an", "Justice.Cuff", "danger")
	end
	if st.Jailed then
		act("Entlassen (Sup.)", "Justice.Release")
	end

	-- Festnahme / Haft (Booking an der Wache)
	UI.label(content, "TATBESTAENDE (Festnahme an der Wache, Booking)", 11, { TextColor3 = T.Muted, Font = T.FontBold })
	local picked = {}
	local pc = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = content })
	UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 22), CellPadding = UDim2.fromOffset(8, 4), Parent = pc })
	for _, c in ipairs(P.PenalCode) do
		local b = UI.button(pc, string.format("%s %s ($%d/%dm)", c.Id, c.Title, c.Fine, c.Jail), "secondary", { TextSize = 10, TextTruncate = Enum.TextTruncate.AtEnd })
		b.MouseButton1Click:Connect(function()
			local i = table.find(picked, c.Id)
			if i then
				table.remove(picked, i)
			else
				table.insert(picked, c.Id)
			end
			b.BackgroundColor3 = table.find(picked, c.Id) and T.Accent2 or T.Panel2
		end)
	end
	local jail = UI.button(content, "FESTNEHMEN & INHAFTIEREN", "danger")
	jail.MouseButton1Click:Connect(function()
		if #picked == 0 then
			UI.toast("Bitte Tatbestaende markieren", "warning")
			return
		end
		if ctx.Request("Justice.Jail", { Target = info.UserId, Charges = picked }).ok then
			X.Close()
			ctx.Closed("Interact")
		end
	end)

	-- Verkehr
	UI.label(content, "STRAFZETTEL / VERWARNUNG", 11, { TextColor3 = T.Muted, Font = T.FontBold })
	local tc = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = content })
	UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 22), CellPadding = UDim2.fromOffset(8, 4), Parent = tc })
	for _, c in ipairs(P.TrafficCode) do
		local b = UI.button(tc, string.format("%s %s $%d", c.Id, c.Title, c.Fine), "secondary", { TextSize = 10, TextTruncate = Enum.TextTruncate.AtEnd })
		b.MouseButton1Click:Connect(function()
			ctx.Request("Justice.Cite", { Target = info.UserId, Code = c.Id })
		end)
	end
	local warnText = UI.input(content, "Verwarnung (Text, max. 80 Zeichen)")
	local warn = UI.button(content, "MUENDLICH VERWARNEN", "secondary")
	warn.MouseButton1Click:Connect(function()
		if ctx.Request("Justice.Warn", { Target = info.UserId, Text = warnText.Text }).ok then
			warnText.Text = ""
		end
	end)
end

-- Rettungsdienst / Feuerwehr: Massnahmen am Patienten
local INJURY = { Minor = "leicht verletzt", Severe = "schwer verletzt", Unconscious = "BEWUSSTLOS" }
local function rescueSection(ctx, content, info, reopen)
	local UI, T = ctx.UI, ctx.UI.Theme
	UI.label(content, "PATIENT  -  " .. (info.Injury and INJURY[info.Injury] or "keine Verletzungen erkennbar") .. (info.Stabilized and " (stabilisiert)" or "") .. (info.Carried and ", wird getragen" or "") .. (info.Loaded and ", im Rettungswagen" or ""), 12, { TextColor3 = info.Injury and T.Danger or T.Success, Font = T.FontBold })
	local grid = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = content })
	UI.new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0, 30), CellPadding = UDim2.fromOffset(8, 6), Parent = grid })
	local function act(label, action, style)
		local b = UI.button(grid, label, style or "secondary", { TextSize = 12 })
		b.MouseButton1Click:Connect(function()
			local r = ctx.Request(action, { Target = info.UserId }, action == "Medical.Examine")
			if r.ok then
				if action == "Medical.Examine" and r.data then
					ctx.Controllers.Medical.ShowExam(ctx, r.data)
				else
					reopen()
				end
			elseif action == "Medical.Examine" and r.msg then
				UI.toast(r.msg, "error")
			end
		end)
	end
	act("Untersuchen", "Medical.Examine", "primary")
	act("Stabilisieren", "Medical.Stabilize")
	act("Versorgen", "Medical.Medicate")
	if info.Responder == "EMS" then
		act("Wiederbeleben", "Medical.Revive", "danger")
	end
	act(info.Carried and "Ablegen" or "Tragen", "Medical.Carry")
	if info.Responder == "EMS" then
		act(info.Loaded and "Aus dem RTW" or "In den RTW", info.Loaded and "Medical.Unload" or "Medical.Load")
		act("Klinikbehandlung", "Medical.Treat")
	end
end

function X.Open(ctx, targetId)
	local UI, T = ctx.UI, ctx.UI.Theme
	if typeof(targetId) == "Instance" then
		targetId = targetId.UserId
	end
	X.Close()
	local res = ctx.Request("Player.Inspect", { Target = targetId }, true)
	if not res.ok then
		UI.toast(res.msg or "Nicht moeglich", "error")
		ctx.Closed("Interact")
		return
	end
	local info = res.data
	screen = UI.screen("MiamiInteract", 20)
	local officer = info.IsOfficer
	local responder = info.Responder
	local tall = officer or responder
	local _, content = UI.window(screen, "Interaktion", UDim2.fromOffset(tall and 560 or 420, officer and 640 or (responder and 520 or 420)), function()
		X.Close()
		ctx.Closed("Interact")
	end)
	local body = tall and UI.scroll(content) or content
	UI.list(body, 8)
	UI.label(body, info.Name, 24, { Font = T.FontBlack })
	local f = ctx.Config.Factions[info.FactionId]
	UI.label(body, info.Rank .. "  -  " .. info.Faction .. (info.OnDuty and "  (im Dienst)" or ""), 14, { TextColor3 = (info.FactionId ~= "Civilian") and f.Color or T.Muted })
	if info.Injury and not responder then
		UI.label(body, "Die Person ist " .. INJURY[info.Injury] .. " - Notruf: N / Handy", 13, { TextColor3 = T.Danger })
	end
	if responder then
		rescueSection(ctx, body, info, function()
			X.Open(ctx, targetId)
		end)
	end
	UI.label(body, "BARGELD UEBERGEBEN", 12, { TextColor3 = T.Muted, Font = T.FontBold })
	local amount = UI.input(body, "Betrag in $")
	local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = body })
	UI.list(row, 8, true)
	local give = UI.button(row, "GELD GEBEN", "primary", { Size = UDim2.new(0.5, -4, 1, 0) })
	give.MouseButton1Click:Connect(function()
		local n = tonumber(amount.Text)
		if not n or n <= 0 or n % 1 ~= 0 then
			UI.toast("Bitte einen ganzen Betrag eingeben", "error")
			return
		end
		if ctx.Request("Cash.Give", { Target = info.UserId, Amount = n, TxId = ctx.TxId() }).ok then
			amount.Text = ""
		end
	end)
	if info.CanAddContact then
		local add = UI.button(row, "ALS KONTAKT SPEICHERN", "secondary", { Size = UDim2.new(0.5, -4, 1, 0), TextSize = 13 })
		add.MouseButton1Click:Connect(function()
			if ctx.Request("Phone.AddContact", { UserId = info.UserId }).ok then
				add.Visible = false
			end
		end)
	end
	if officer then
		policeSection(ctx, body, info, function()
			X.Open(ctx, targetId)
		end)
	end
end

-- Durchsuchungsergebnis mit Beschlagnahme
function X.ShowSearch(ctx, data)
	local UI, T = ctx.UI, ctx.UI.Theme
	X.Close()
	screen = UI.screen("MiamiInteract", 20)
	local _, content = UI.window(screen, "Durchsuchung: " .. data.Name, UDim2.fromOffset(440, 420), function()
		X.Close()
		ctx.Closed("Interact")
	end)
	local body = UI.scroll(content)
	UI.list(body, 6)
	UI.label(body, "Bargeld: $" .. data.Cash, 15, { Font = T.FontBold })
	if #data.Items == 0 then
		UI.label(body, "Keine Gegenstaende.", 13, { TextColor3 = T.Muted })
	end
	for _, it in ipairs(data.Items) do
		local row = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, -6, 0, 34), Parent = body })
		UI.corner(row, 8)
		UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.65, 0, 1, 0), Font = T.FontBold, TextSize = 13, TextColor3 = it.Illegal and T.Danger or T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("%dx %s%s", it.Count, it.Name, it.Illegal and "  (beschlagnahmbar)" or ""), Parent = row })
		if it.Illegal then
			local b = UI.button(row, "BESCHLAGNAHMEN", "danger", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(130, 26), TextSize = 11 })
			b.MouseButton1Click:Connect(function()
				if ctx.Request("Justice.Confiscate", { Target = data.UserId, ItemId = it.Id }).ok then
					b.Text, b.Active, b.AutoButtonColor = "ERLEDIGT", false, false
				end
			end)
		end
	end
	local back = UI.button(content, "< ZURUECK", "secondary", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.fromOffset(120, 30), TextSize = 12 })
	back.MouseButton1Click:Connect(function()
		X.Open(ctx, data.UserId)
	end)
end

-- Ausweis eines anderen Spielers anzeigen
function X.ShowID(ctx, card)
	local UI, T = ctx.UI, ctx.UI.Theme
	local scr = UI.screen("MiamiIDCard", 60)
	local f = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90), Size = UDim2.fromOffset(380, 170), BackgroundColor3 = Color3.fromRGB(235, 240, 248), Parent = scr })
	UI.corner(f, 14)
	UI.pad(f, 16)
	UI.new("UIGradient", { Rotation = 20, Color = ColorSequence.new(Color3.fromRGB(240, 248, 255), Color3.fromRGB(255, 225, 240)), Parent = f })
	UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Font = T.FontBlack, TextSize = 14, TextColor3 = Color3.fromRGB(30, 60, 140), TextXAlignment = Enum.TextXAlignment.Left, Text = "STATE OF MIAMI  -  IDENTIFICATION CARD", Parent = f })
	local genders = { m = "M", w = "F", d = "X" }
	local lines = { "NAME: " .. card.Name, "JAHRGANG: " .. tostring(card.BirthYear), "GESCHLECHT: " .. (genders[card.Gender] or "-") }
	for i, txt in ipairs(lines) do
		UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 20 + i * 28), Size = UDim2.new(1, 0, 0, 24), Font = T.FontBold, TextSize = 17, TextColor3 = Color3.fromRGB(20, 24, 34), TextXAlignment = Enum.TextXAlignment.Left, Text = txt, Parent = f })
	end
	task.delay(6, function()
		scr:Destroy()
	end)
end

return X
