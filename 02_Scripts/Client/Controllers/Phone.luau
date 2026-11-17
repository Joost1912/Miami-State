-- Smartphone (Taste U oder HUD-Knopf): erscheint links am Bildschirmrand, auf Mobilgeraeten skaliert.
-- Apps sind in Phone.Apps registriert ({Id, Name, Icon, Color, Open = function(ctx, page) ... end});
-- neue Apps einfach dort ergaenzen. Alle Aktionen laufen ueber den Server (ctx.Request).
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Phone = {}
local ctxRef
local screen, body, page, statusTime, statusMoney, scaleObj
local isOpen = false
local W, H = 320, 640

local WALLPAPERS = {
	{ Color3.fromRGB(255, 72, 168), Color3.fromRGB(64, 120, 255) }, -- Miami Sunset
	{ Color3.fromRGB(20, 160, 170), Color3.fromRGB(10, 30, 70) }, -- Ocean Drive
	{ Color3.fromRGB(255, 140, 60), Color3.fromRGB(120, 30, 90) }, -- Coral Key
	{ Color3.fromRGB(40, 44, 56), Color3.fromRGB(12, 14, 20) }, -- Midnight
}

local function T()
	return ctxRef.UI.Theme
end
local function settings()
	local p = ctxRef.Profile
	return p and p.Phone and p.Phone.Settings or {}
end

-- Seitenaufbau -------------------------------------------------------------------------------------------
local function clearPage()
	if page then
		page:Destroy()
	end
	page = ctxRef.UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 1, -58), Parent = body })
	return page
end

local function appHeader(title, color)
	local UI = ctxRef.UI
	local p = clearPage()
	p.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
	p.BackgroundTransparency = 0
	UI.corner(p, 24)
	local head = UI.new("Frame", { BackgroundColor3 = color or T().Panel2, Size = UDim2.new(1, 0, 0, 46), Parent = p })
	UI.corner(head, 24)
	UI.new("Frame", { BorderSizePixel = 0, BackgroundColor3 = color or T().Panel2, Position = UDim2.new(0, 0, 1, -24), Size = UDim2.new(1, 0, 0, 24), Parent = head })
	local back = UI.new("TextButton", { BackgroundTransparency = 1, Size = UDim2.fromOffset(46, 46), Font = T().FontBlack, TextSize = 26, TextColor3 = Color3.new(1, 1, 1), Text = "‹", Parent = head })
	back.MouseButton1Click:Connect(function()
		Phone.Home()
	end)
	UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -56, 1, 0), Font = T().FontBlack, TextSize = 17, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, Text = title, Parent = head })
	local content = UI.scroll(p, { Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -24, 1, -60), ScrollBarThickness = 3 })
	UI.list(content, 8)
	return content
end

local function card(parent, h)
	local UI = ctxRef.UI
	local f = UI.new("Frame", { BackgroundColor3 = T().Panel2, Size = UDim2.new(1, -4, 0, h or 60), Parent = parent })
	UI.corner(f, 12)
	UI.pad(f, 10)
	return f
end

local function small(parent, text, size, color, props)
	local p = { TextColor3 = color or T().Muted, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true }
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return ctxRef.UI.label(parent, text, size or 12, p)
end

local function gameClock()
	local m = Lighting:GetMinutesAfterMidnight()
	return string.format("%02d:%02d", math.floor(m / 60) % 24, math.floor(m % 60))
end

-- Apps ----------------------------------------------------------------------------------------------------
local Apps = {}
Phone.Apps = Apps

local function comingSoon(name, text)
	return function()
		local c = appHeader(name)
		small(c, "Diese App ist vorbereitet und wird mit einer spaeteren Erweiterung freigeschaltet.", 13, T().Text)
		small(c, text, 12)
	end
end

-- HILFE
table.insert(Apps, { Id = "Help", Name = "Hilfe", Icon = "❓", Color = Color3.fromRGB(64, 120, 255), Open = function()
	local c = appHeader("Hilfe", Color3.fromRGB(40, 80, 180))
	local sections = {
		{ "Steuerung", "W/A/S/D Laufen bzw. Fahren  |  Leertaste Springen/Aussteigen\nF Fahrer, G Mitfahrer, E Interagieren\nU Handy, V Stadtkarte, + / - Minimap-Zoom\nI Inventar, P Profil, J Berufe, X Interaktion, N Notruf\nIm Einsatzfahrzeug: Q Blaulicht, R Sirene, T Ton, Y Horn, H Warnblinker, L Licht\nIm Dienst: K Dashboard, B Funk, M MDT (Polizei)" },
		{ "Spielanleitung", "Erstelle deinen Charakter, waehle am Jobcenter oder in der City Hall einen Beruf und verdiene Gehalt. Dein Geld liegt bar oder auf dem Konto (Geldautomaten). Mit der Karte (V) findest du Geschaefte, Tankstellen, Wachen und mehr - setze Wegpunkte fuer die Navigation." },
		{ "Einsatzfraktionen", "Polizei, Feuerwehr und Rettungsdienst treten den Dienst an ihrer Wache an (Dienst-Terminal). Einsaetze laufen ueber die gemeinsame Leitstelle. Notrufe setzt jeder ueber N oder die Notruf-App ab." },
		{ "Spielregeln", "Respektvolles Roleplay, kein grundloses Toeten oder Rammen (RDM/VDM), kein Ausnutzen von Fehlern, keine Beleidigungen. Notrufe nur fuer echte Roleplay-Situationen. Anweisungen von Moderatoren sind zu befolgen." },
		{ "Verletzungen", "Stuerze, Unfaelle und Feuer verletzen dich. Leichte Verletzungen behandelst du mit Verbandszeug, schwere versorgt der Rettungsdienst. Bei Bewusstlosigkeit kannst du Hilfe rufen oder nach Ablauf der Zeit in die Notaufnahme gehen." },
	}
	for _, s in ipairs(sections) do
		local f = card(c, 0)
		f.AutomaticSize = Enum.AutomaticSize.Y
		ctxRef.UI.list(f, 4)
		ctxRef.UI.label(f, s[1]:upper(), 13, { Font = T().FontBlack, TextColor3 = T().Accent })
		small(f, s[2], 12, T().Text)
	end
end })

-- NOTRUF
local SERVICE_CATS = {
	Police = { "Robbery", "Assault", "Theft", "Accident", "Suspicious", "Other" },
	Fire = { "StructureFire", "VehicleFire", "DumpsterFire", "BrushFire", "TechRescue" },
	EMS = { "Medical", "Injured", "Unconscious", "Accident" },
}
local function categoryName(id)
	for _, list in ipairs({ ctxRef.Config.Police.CallCategories, ctxRef.Config.Rescue.CallCategories }) do
		for _, cat in ipairs(list) do
			if cat.Id == id then
				return cat.Name
			end
		end
	end
	return id
end
local function emergencyForm(service, label, color)
	local UI = ctxRef.UI
	local c = appHeader("Notruf - " .. label, color)
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local loc = card(c, 56)
	UI.list(loc, 2)
	small(loc, "DEIN STANDORT", 11, T().Muted)
	small(loc, root and string.format("%s  (X %d / Z %d)", ctxRef.Config.MapData.DistrictAt(root.Position.X, root.Position.Z), root.Position.X, root.Position.Z) or "unbekannt", 13, T().Text)
	small(c, "Was ist passiert?", 12, T().Text)
	local chosen
	local btns = {}
	for _, id in ipairs(SERVICE_CATS[service]) do
		local b = UI.button(c, categoryName(id), "secondary", { Size = UDim2.new(1, -4, 0, 34), TextSize = 13 })
		btns[id] = b
		b.MouseButton1Click:Connect(function()
			chosen = id
			for k, bb in pairs(btns) do
				bb.BackgroundColor3 = (k == chosen) and color or T().Panel2
			end
		end)
	end
	local desc = UI.input(c, "Beschreibung (3-140 Zeichen)", { Size = UDim2.new(1, -4, 0, 40), TextSize = 13 })
	local send = UI.button(c, "NOTRUF ABSETZEN", "danger", { Size = UDim2.new(1, -4, 0, 42) })
	send.MouseButton1Click:Connect(function()
		if not chosen then
			UI.toast("Bitte waehle aus, was passiert ist", "warning")
			return
		end
		if ctxRef.Request("Emergency.Call", { Category = chosen, Description = desc.Text }).ok then
			Phone.Home()
		end
	end)
end
table.insert(Apps, { Id = "Emergency", Name = "Notruf", Icon = "🚨", Color = Color3.fromRGB(230, 50, 60), Open = function()
	local UI = ctxRef.UI
	if Players.LocalPlayer:GetAttribute("Injury") == "Unconscious" then
		local c = appHeader("Notruf", Color3.fromRGB(180, 30, 40))
		local b = UI.button(c, "RETTUNGSDIENST RUFEN (BEWUSSTLOS)", "danger", { Size = UDim2.new(1, -4, 0, 48) })
		b.MouseButton1Click:Connect(function()
			ctxRef.Request("Medical.CallHelp")
		end)
		return
	end
	local c = appHeader("Notruf 911", Color3.fromRGB(180, 30, 40))
	small(c, "Wen moechtest du verstaendigen? Dein Standort wird automatisch uebermittelt.", 12, T().Text)
	for _, s in ipairs({ { "Police", "Polizei", "🚓", Color3.fromRGB(50, 100, 230) }, { "Fire", "Feuerwehr", "🚒", Color3.fromRGB(220, 70, 40) }, { "EMS", "Rettungsdienst", "🚑", Color3.fromRGB(230, 60, 80) } }) do
		local b = UI.button(c, s[3] .. "   " .. s[2], "secondary", { Size = UDim2.new(1, -4, 0, 64), TextSize = 18, BackgroundColor3 = s[4] })
		b.MouseButton1Click:Connect(function()
			emergencyForm(s[1], s[2], s[4])
		end)
	end
	small(c, "Missbrauch des Notrufs wird verfolgt.", 11)
end })

-- BANK
table.insert(Apps, { Id = "Bank", Name = "Bank", Icon = "💳", Color = Color3.fromRGB(40, 170, 110), Open = function()
	local UI, F = ctxRef.UI, ctxRef.Format
	local c = appHeader("Miami State Bank", Color3.fromRGB(26, 120, 80))
	local p = ctxRef.Profile
	local bal = card(c, 92)
	UI.list(bal, 2)
	small(bal, "KONTOSTAND", 11)
	UI.label(bal, F.money(p.Money.Bank), 26, { Font = T().FontBlack, TextColor3 = T().Success })
	small(bal, "Bargeld: " .. F.money(p.Money.Cash), 13, T().Text)
	-- Ein-/Auszahlen nur am Geldautomaten (Bargeld)
	local atm = card(c, 0)
	atm.AutomaticSize = Enum.AutomaticSize.Y
	UI.list(atm, 6)
	small(atm, "EIN- / AUSZAHLEN", 11)
	small(atm, "Bargeld kannst du am Geldautomaten ein- und auszahlen. Ueberweisungen gehen ueberall per App.", 12, T().Text)
	local amount = UI.input(atm, "Betrag in $", { Size = UDim2.new(1, 0, 0, 36), TextSize = 13 })
	local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = atm })
	UI.list(row, 6, true)
	for _, a in ipairs({ { "Einzahlen", "Bank.Deposit" }, { "Abheben", "Bank.Withdraw" } }) do
		local b = UI.button(row, a[1], "secondary", { Size = UDim2.new(0.5, -3, 1, 0), TextSize = 13 })
		b.MouseButton1Click:Connect(function()
			local n = tonumber(amount.Text)
			if not n or n <= 0 or n % 1 ~= 0 then
				UI.toast("Bitte einen ganzen Betrag eingeben", "error")
				return
			end
			if ctxRef.Request(a[2], { Amount = n, TxId = ctxRef.TxId() }).ok then
				Apps[3].Open()
			end
		end)
	end
	local nav = UI.button(atm, "🏧  Route zum naechsten Geldautomaten", "secondary", { Size = UDim2.new(1, 0, 0, 34), TextSize = 12 })
	nav.MouseButton1Click:Connect(function()
		local r = ctxRef.Request("Map.NearestATM", nil, true)
		if r.ok then
			ctxRef.Controllers.CityMap.Nav.SetTarget(r.data.X, r.data.Z, "Geldautomat", r.data.Y)
		end
	end)
	-- Ueberweisung
	local tr = card(c, 0)
	tr.AutomaticSize = Enum.AutomaticSize.Y
	UI.list(tr, 6)
	small(tr, "UEBERWEISUNG", 11)
	local players = ctxRef.Request("Players.List", nil, true).data or {}
	local others = {}
	for _, pl in ipairs(players) do
		if not pl.Self then
			table.insert(others, pl)
		end
	end
	local idx = 0
	local pick = UI.button(tr, #others > 0 and "Empfaenger waehlen >" or "Keine Empfaenger online", "secondary", { Size = UDim2.new(1, 0, 0, 34), TextSize = 12 })
	pick.MouseButton1Click:Connect(function()
		if #others > 0 then
			idx = idx % #others + 1
			pick.Text = "An: " .. others[idx].Name
		end
	end)
	local tAmount = UI.input(tr, "Betrag in $", { Size = UDim2.new(1, 0, 0, 36), TextSize = 13 })
	local note = UI.input(tr, "Verwendungszweck (optional)", { Size = UDim2.new(1, 0, 0, 36), TextSize = 13 })
	local send = UI.button(tr, "UEBERWEISEN", "primary", { Size = UDim2.new(1, 0, 0, 36), TextSize = 13 })
	send.MouseButton1Click:Connect(function()
		local n = tonumber(tAmount.Text)
		if not others[idx] then
			UI.toast("Bitte Empfaenger waehlen", "warning")
			return
		end
		if not n or n <= 0 or n % 1 ~= 0 then
			UI.toast("Bitte einen ganzen Betrag eingeben", "error")
			return
		end
		if ctxRef.Request("Bank.Transfer", { Target = others[idx].UserId, Amount = n, Note = note.Text, TxId = ctxRef.TxId(), Mobile = true }).ok then
			Apps[3].Open()
		end
	end)
	-- Umsaetze
	small(c, "LETZTE UMSAETZE", 11)
	for i = 1, math.min(15, #p.Money.History) do
		local h = p.Money.History[i]
		local row2 = card(c, 44)
		UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.65, 0, 0, 16), Font = T().FontBold, TextSize = 12, TextColor3 = T().Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = h.K, Parent = row2 })
		UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(0.7, 0, 0, 14), Font = T().Font, TextSize = 10, TextColor3 = T().Muted, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = F.time(h.T) .. (h.N ~= "" and ("  " .. h.N) or ""), Parent = row2 })
		UI.new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.35, 0, 1, 0), Font = T().FontBlack, TextSize = 13, TextColor3 = h.A >= 0 and T().Success or T().Danger, TextXAlignment = Enum.TextXAlignment.Right, Text = (h.A >= 0 and "+" or "") .. F.money(h.A), Parent = row2 })
	end
end })

-- FAHRZEUG
table.insert(Apps, { Id = "Vehicles", Name = "Fahrzeug", Icon = "🚗", Color = Color3.fromRGB(255, 150, 40), Open = function()
	local UI = ctxRef.UI
	local c = appHeader("Meine Fahrzeuge", Color3.fromRGB(190, 100, 20))
	local r = ctxRef.Request("Vehicle.Owned", nil, true)
	local list = r.data or {}
	if #list == 0 then
		small(c, "Du besitzt noch kein Fahrzeug.", 13, T().Text)
	end
	for _, v in ipairs(list) do
		local f = card(c, 0)
		f.AutomaticSize = Enum.AutomaticSize.Y
		UI.list(f, 6)
		local top = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Parent = f })
		if v.Color then
			local sw = UI.new("Frame", { Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(0, 2), BackgroundColor3 = Color3.fromRGB(v.Color[1], v.Color[2], v.Color[3]), Parent = top })
			UI.corner(sw, 9)
		end
		UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -26, 1, 0), Font = T().FontBlack, TextSize = 16, TextColor3 = T().Text, TextXAlignment = Enum.TextXAlignment.Left, Text = v.Name, Parent = top })
		small(f, string.format("Kennzeichen %s  |  %s km/h  |  %s Sitze", v.Plate, tostring(math.floor((v.MaxSpeed or 0) * 1.008)), tostring(v.Seats or "-")), 12, T().Text)
		small(f, v.Out and ("Standort: " .. ctxRef.Config.MapData.DistrictAt(v.X, v.Z) .. string.format(" (X %d / Z %d)", v.X, v.Z)) or "Status: eingeparkt", 12, v.Out and T().Accent or T().Muted)
		local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), Parent = f })
		UI.list(row, 6, true)
		if v.Out then
			local loc = UI.button(row, "Orten", "secondary", { Size = UDim2.new(0.5, -3, 1, 0), TextSize = 12 })
			loc.MouseButton1Click:Connect(function()
				ctxRef.Controllers.CityMap.Nav.SetTarget(v.X, v.Z, v.Plate)
			end)
			local park = UI.button(row, "Einparken", "secondary", { Size = UDim2.new(0.5, -3, 1, 0), TextSize = 12 })
			park.MouseButton1Click:Connect(function()
				if ctxRef.Request("Vehicle.ParkOwned", { Id = v.Id }).ok then
					Apps[4].Open()
				end
			end)
		else
			local spawn = UI.button(row, "Ausparken (naechster Parkplatz)", "primary", { Size = UDim2.new(1, 0, 1, 0), TextSize = 12 })
			spawn.MouseButton1Click:Connect(function()
				local res = ctxRef.Request("Vehicle.SpawnOwned", { Id = v.Id })
				if res.ok and res.data then
					ctxRef.Controllers.CityMap.Nav.SetTarget(res.data.X, res.data.Z, res.data.Label, res.data.Y)
					Apps[4].Open()
				end
			end)
		end
	end
	small(c, "Ausparken nur, wenn ein freier Parkplatz (Spawnflaeche oder markierter Stellplatz) in der Naehe ist. Weitere Fahrzeuge folgen mit dem Fahrzeughandel.", 11)
end })

-- SERVER
table.insert(Apps, { Id = "Server", Name = "Server", Icon = "🌐", Color = Color3.fromRGB(110, 90, 255), Open = function()
	local UI = ctxRef.UI
	local c = appHeader("Server", Color3.fromRGB(70, 56, 190))
	local r = ctxRef.Request("Phone.Server", nil, true)
	if not r.ok then
		return
	end
	local d = r.data
	local me = card(c, 0)
	me.AutomaticSize = Enum.AutomaticSize.Y
	UI.list(me, 4)
	small(me, "MEIN CHARAKTER", 11)
	UI.label(me, d.Me.Name, 18, { Font = T().FontBlack })
	small(me, string.format("Jahrgang %s  |  %s", tostring(d.Me.BirthYear), d.Me.Faction), 12, T().Text)
	small(me, string.format("Spielzeit %d h  |  Besuche %d  |  Fuehrerschein %s (%d Pkt.)  |  Fahrzeuge %d", math.floor(d.Me.PlayTime / 3600), d.Me.Joins, d.Me.License, d.Me.Points, d.Me.Vehicles), 11)
	small(c, string.format("SPIELER ONLINE: %d / %d   |   Server laeuft seit %d min", #d.Players, d.MaxPlayers, math.floor(d.ServerAge / 60)), 11)
	local contacts = {}
	for _, ct in ipairs((ctxRef.Profile.Phone or {}).Contacts or {}) do
		contacts[ct.UserId] = true
	end
	for _, p in ipairs(d.Players) do
		local f = card(c, 52)
		UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.7, 0, 0, 18), Font = T().FontBold, TextSize = 14, TextColor3 = p.Self and T().Accent or T().Text, TextXAlignment = Enum.TextXAlignment.Left, Text = p.Name .. (p.Self and "  (du)" or ""), Parent = f })
		UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 18), Size = UDim2.new(0.75, 0, 0, 14), Font = T().Font, TextSize = 11, TextColor3 = T().Muted, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = "● online  |  " .. p.Rank .. " - " .. p.Faction .. (p.OnDuty and " (im Dienst)" or ""), Parent = f })
		if not p.Self and not contacts[p.UserId] then
			local add = UI.button(f, "+", "primary", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(30, 30), TextSize = 18 })
			add.MouseButton1Click:Connect(function()
				if ctxRef.Request("Phone.AddContact", { UserId = p.UserId }).ok then
					add.Visible = false
				end
			end)
		end
	end
end })

-- KONTAKTE
table.insert(Apps, { Id = "Contacts", Name = "Kontakte", Icon = "👥", Color = Color3.fromRGB(60, 190, 230), Open = function()
	local UI = ctxRef.UI
	local c = appHeader("Kontakte", Color3.fromRGB(30, 130, 170))
	local list = (ctxRef.Profile.Phone or {}).Contacts or {}
	if #list == 0 then
		small(c, "Noch keine Kontakte. Fuege Spieler in der Server-App (+) oder ueber das Interaktionsmenue (X) hinzu.", 12, T().Text)
	end
	for _, ct in ipairs(list) do
		local online = Players:GetPlayerByUserId(ct.UserId) ~= nil
		local f = card(c, 0)
		f.AutomaticSize = Enum.AutomaticSize.Y
		UI.list(f, 6)
		UI.label(f, ct.Name, 15, { Font = T().FontBold })
		small(f, (online and "● online" or "○ offline") .. "  |  gespeichert " .. ctxRef.Format.time(ct.Added), 11, online and T().Success or T().Muted)
		local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Parent = f })
		UI.list(row, 6, true)
		local msg = UI.button(row, "Nachricht", "secondary", { Size = UDim2.new(0.5, -3, 1, 0), TextSize = 12 })
		msg.MouseButton1Click:Connect(function()
			UI.toast("Nachrichten folgen mit der Messenger-App", "info")
		end)
		local del = UI.button(row, "Entfernen", "danger", { Size = UDim2.new(0.5, -3, 1, 0), TextSize = 12 })
		del.MouseButton1Click:Connect(function()
			if ctxRef.Request("Phone.RemoveContact", { UserId = ct.UserId }).ok then
				task.wait(0.2)
				Apps[6].Open()
			end
		end)
	end
end })

-- KARTE
table.insert(Apps, { Id = "Map", Name = "Karte", Icon = "🗺", Color = Color3.fromRGB(40, 200, 140), Open = function()
	Phone.Close()
	ctxRef.Open("CityMap")
end })

-- EINSTELLUNGEN
table.insert(Apps, { Id = "Settings", Name = "Einstellungen", Icon = "⚙", Color = Color3.fromRGB(120, 126, 140), Open = function()
	local UI = ctxRef.UI
	local c = appHeader("Einstellungen", Color3.fromRGB(70, 76, 90))
	local s = table.clone(settings())
	local function save(key, value)
		s[key] = value
		ctxRef.Request("Phone.SaveSettings", { [key] = value }, true)
		Phone.ApplySettings(s)
	end
	local function slider(label, key, steps)
		local f = card(c, 66)
		small(f, label:upper(), 11)
		local row = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 26), Parent = f })
		UI.list(row, 4, true)
		local cells = {}
		local function paint()
			for i, cell in ipairs(cells) do
				cell.BackgroundColor3 = (i / steps <= (s[key] or 0) + 0.001) and T().Accent or T().Bg
			end
		end
		for i = 0, steps do
			local cell = UI.new("TextButton", { AutoButtonColor = false, Text = "", Size = UDim2.new(1 / (steps + 1), -4, 1, 0), Parent = row })
			UI.corner(cell, 4)
			if i > 0 then
				table.insert(cells, cell)
			end
			cell.MouseButton1Click:Connect(function()
				save(key, i / steps)
				paint()
			end)
			if i == 0 then
				cell.BackgroundColor3 = T().Panel
				cell.Text = "0"
				cell.TextColor3 = T().Muted
				cell.Font = T().FontBold
				cell.TextSize = 11
			end
		end
		paint()
	end
	local function toggle(label, key)
		local f = card(c, 44)
		UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.7, 0, 1, 0), Font = T().FontBold, TextSize = 13, TextColor3 = T().Text, TextXAlignment = Enum.TextXAlignment.Left, Text = label, Parent = f })
		local b = UI.button(f, "", "secondary", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(64, 26), TextSize = 12 })
		local function paint()
			b.Text = s[key] and "AN" or "AUS"
			b.BackgroundColor3 = s[key] and T().Success or T().Panel
			b.TextColor3 = s[key] and T().Bg or T().Text
		end
		b.MouseButton1Click:Connect(function()
			save(key, not s[key])
			paint()
		end)
		paint()
	end
	slider("Soundeffekte (Sirenen, Fahrzeuge)", "SoundVolume", 5)
	slider("Musik", "MusicVolume", 5)
	toggle("Minimap anzeigen", "Minimap")
	toggle("Partikel (Feuer, Rauch, Spray)", "Particles")
	toggle("Steuerungshinweise", "ShowHints")
	-- UI-Groesse und Minimap-Zoom
	local f = card(c, 44)
	UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.5, 0, 1, 0), Font = T().FontBold, TextSize = 13, TextColor3 = T().Text, TextXAlignment = Enum.TextXAlignment.Left, Text = "Oberflaeche", Parent = f })
	local val = UI.new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -70, 0.5, 0), Size = UDim2.fromOffset(50, 26), Font = T().FontBlack, TextSize = 13, TextColor3 = T().Accent, Text = math.floor((s.UIScale or 1) * 100) .. "%", Parent = f })
	for i, d in ipairs({ { "−", -0.05 }, { "+", 0.05 } }) do
		local b = UI.button(f, d[1], "secondary", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(2 - i) * 34, 0.5, 0), Size = UDim2.fromOffset(30, 26), TextSize = 16 })
		b.MouseButton1Click:Connect(function()
			local v = math.clamp((s.UIScale or 1) + d[2], 0.8, 1.25)
			save("UIScale", math.floor(v * 100 + 0.5) / 100)
			val.Text = math.floor(s.UIScale * 100) .. "%"
		end)
	end
	-- Hintergrund
	local wp = card(c, 70)
	small(wp, "HINTERGRUNDBILD", 11)
	local row = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 34), Parent = wp })
	UI.list(row, 8, true)
	for i, colors in ipairs(WALLPAPERS) do
		local b = UI.new("TextButton", { AutoButtonColor = false, Text = (s.Wallpaper == i) and "✓" or "", TextColor3 = Color3.new(1, 1, 1), Font = T().FontBlack, TextSize = 16, Size = UDim2.fromOffset(52, 34), Parent = row })
		UI.corner(b, 8)
		UI.new("UIGradient", { Rotation = 45, Color = ColorSequence.new(colors[1], colors[2]), Parent = b })
		b.MouseButton1Click:Connect(function()
			save("Wallpaper", i)
			Apps[8].Open()
		end)
	end
	small(c, "Grafikqualitaet stellst du im Roblox-Menue (Esc > Einstellungen) ein. Steuerung: siehe Hilfe-App.", 11)
end })

-- vorbereitete Apps (Erweiterungen)
table.insert(Apps, { Id = "PoliceApp", Name = "Polizei", Icon = "👮", Color = Color3.fromRGB(40, 70, 160), Open = function()
	if Players.LocalPlayer:GetAttribute("Faction") == "Police" then
		Phone.Close()
		ctxRef.Open("Police")
	else
		comingSoon("Polizei", "Buergerservice der Miami State Police (Anzeigen, Fahndungsaufrufe) folgt. Im Notfall: Notruf-App.")()
	end
end })
table.insert(Apps, { Id = "RescueApp", Name = "Fire / EMS", Icon = "🚑", Color = Color3.fromRGB(220, 60, 60), Open = function()
	local f = Players.LocalPlayer:GetAttribute("Faction")
	if f == "Fire" or f == "EMS" then
		Phone.Close()
		ctxRef.Open("Rescue")
	else
		comingSoon("Fire / EMS", "Informationen zu Feuerwehr und Rettungsdienst folgen. Im Notfall: Notruf-App.")()
	end
end })
table.insert(Apps, { Id = "Jobs", Name = "Jobs", Icon = "💼", Color = Color3.fromRGB(200, 150, 90), Open = function()
	Phone.Close()
	ctxRef.Open("Jobs")
end })
table.insert(Apps, { Id = "Estate", Name = "Immobilien", Icon = "🏠", Color = Color3.fromRGB(90, 170, 90), Open = comingSoon("Immobilien", "Wohnungen und Haeuser kaufen oder mieten.") })
table.insert(Apps, { Id = "CarTrade", Name = "Autohandel", Icon = "🏎", Color = Color3.fromRGB(240, 90, 60), Open = comingSoon("Fahrzeughandel", "Neu- und Gebrauchtwagen kaufen und verkaufen.") })
table.insert(Apps, { Id = "Messages", Name = "Nachrichten", Icon = "💬", Color = Color3.fromRGB(80, 210, 110), Open = comingSoon("Nachrichten", "Private Nachrichten an deine Kontakte.") })
table.insert(Apps, { Id = "Business", Name = "Firmen", Icon = "🏢", Color = Color3.fromRGB(150, 110, 220), Open = comingSoon("Unternehmen", "Eigene Firmen gruenden und verwalten.") })

-- Startbildschirm ---------------------------------------------------------------------------------------
function Phone.Home()
	local UI = ctxRef.UI
	local p = clearPage()
	local grid = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 70), Size = UDim2.new(1, -30, 1, -80), Parent = p })
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(58, 80), CellPadding = UDim2.fromOffset(8, 6), Parent = grid })
	UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 48), Font = T().FontBlack, TextSize = 46, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 0.05, Text = gameClock(), Parent = p })
	for _, app in ipairs(Apps) do
		local cell = UI.new("Frame", { BackgroundTransparency = 1, Parent = grid })
		local icon = UI.new("TextButton", { AutoButtonColor = true, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(54, 54), BackgroundColor3 = app.Color, Text = app.Icon, TextSize = 28, Font = T().FontBold, TextColor3 = Color3.new(1, 1, 1), Parent = cell })
		UI.corner(icon, 16)
		UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(-6, 60), Size = UDim2.new(1, 12, 0, 16), Font = T().FontBold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.6, Text = app.Name, Parent = cell })
		icon.MouseButton1Click:Connect(function()
			app.Open(ctxRef)
		end)
	end
end

-- Rahmen ------------------------------------------------------------------------------------------------
local function build()
	local UI = ctxRef.UI
	screen = UI.screen("MiamiPhone", 30)
	local frame = UI.new("Frame", { Name = "Phone", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -W - 40, 0.5, 0), Size = UDim2.fromOffset(W, H), BackgroundColor3 = Color3.fromRGB(10, 10, 12), Parent = screen })
	UI.corner(frame, 42)
	UI.stroke(frame, Color3.fromRGB(70, 74, 86), 3)
	scaleObj = UI.new("UIScale", { Parent = frame })
	-- normaler Frame (Eingaben in CanvasGroups kommen nicht zuverlaessig an); Inhalte liegen innerhalb der Rundungen
	body = UI.new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16), BackgroundTransparency = 1, ClipsDescendants = true, Parent = frame })
	-- Hintergrundbild als eigene Ebene (ein Verlauf direkt an der CanvasGroup wuerde alle Inhalte einfaerben)
	local wall = UI.new("Frame", { Name = "Wallpaper", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 0, Parent = body })
	UI.corner(wall, 36)
	local grad = UI.new("UIGradient", { Rotation = 120, Parent = wall })
	-- Statusleiste: Uhrzeit, Geld, Empfang/Akku
	local status = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), ZIndex = 5, Parent = body })
	statusTime = UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(26, 8), Size = UDim2.fromOffset(60, 18), Font = T().FontBlack, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = status })
	local notch = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(92, 22), BackgroundColor3 = Color3.fromRGB(6, 6, 8), ZIndex = 6, Parent = status })
	UI.corner(notch, 11)
	statusMoney = UI.new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 8), Size = UDim2.fromOffset(90, 18), Font = T().FontBold, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5, Parent = status })
	-- Home-Leiste unten
	local homeBar = UI.new("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(120, 14), BackgroundTransparency = 1, Text = "", ZIndex = 8, Parent = body })
	local pill = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(110, 5), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.2, ZIndex = 8, Parent = homeBar })
	UI.corner(pill, 3)
	homeBar.MouseButton1Click:Connect(function()
		Phone.Home()
	end)
	local function refreshWallpaper()
		local colors = WALLPAPERS[settings().Wallpaper or 1] or WALLPAPERS[1]
		grad.Color = ColorSequence.new(colors[1], colors[2])
	end
	refreshWallpaper()
	ctxRef.ProfileChanged:Connect(function()
		refreshWallpaper()
		if statusMoney and ctxRef.Profile then
			statusMoney.Text = ctxRef.Format.money(ctxRef.Profile.Money.Cash)
		end
	end)
	task.spawn(function()
		while screen do
			statusTime.Text = gameClock()
			if ctxRef.Profile then
				statusMoney.Text = ctxRef.Format.money(ctxRef.Profile.Money.Cash)
			end
			task.wait(2)
		end
	end)
	Phone.Home()
end

local function fitScale()
	local vp = Workspace.CurrentCamera.ViewportSize
	local s = math.clamp((vp.Y - 70) / H, 0.55, 1) * (settings().UIScale or 1)
	scaleObj.Scale = s
	return s
end

function Phone.Open(ctx)
	ctxRef = ctx
	if not screen then
		build()
	end
	isOpen = true
	local s = fitScale()
	local frame = screen.Phone
	screen.Enabled = true
	TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0, 24 * s, 0.5, 0) }):Play()
	Phone.Home()
end

function Phone.Close()
	if not screen or not isOpen then
		return
	end
	isOpen = false
	local frame = screen.Phone
	local tw = TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = UDim2.new(0, -W - 60, 0.5, 0) })
	tw:Play()
	if ctxRef then
		ctxRef.Closed("Phone")
	end
end

function Phone.IsOpen()
	return isOpen
end

-- Einstellungen lokal anwenden (Lautstaerke, Oberflaeche, Minimap, Partikel)
function Phone.ApplySettings(s)
	if not s or not ctxRef then
		return
	end
	local SoundService = game:GetService("SoundService")
	for _, n in ipairs({ { "MiamiSFX", s.SoundVolume }, { "MiamiMusic", s.MusicVolume } }) do
		local g = SoundService:FindFirstChild(n[1]) or Instance.new("SoundGroup")
		g.Name = n[1]
		g.Volume = n[2] or 0.8
		g.Parent = SoundService
	end
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	for _, gui in ipairs(pg and pg:GetChildren() or {}) do
		if gui:IsA("ScreenGui") and gui.Name:match("^Miami") and gui.Name ~= "MiamiPhone" and gui.Name ~= "MiamiToasts" then
			local sc = gui:FindFirstChild("MiamiUIScale") or Instance.new("UIScale")
			sc.Name = "MiamiUIScale"
			sc.Scale = s.UIScale or 1
			sc.Parent = gui
		end
	end
	if scaleObj then
		fitScale()
	end
	if ctxRef.Controllers.Minimap then
		ctxRef.Controllers.Minimap.ApplySettings(s)
	end
	Phone.Particles = s.Particles ~= false
	for _, f in ipairs(Workspace:FindFirstChild("ActiveFires") and Workspace.ActiveFires:GetDescendants() or {}) do
		if f:IsA("Fire") or f:IsA("Smoke") then
			f.Enabled = Phone.Particles
		end
	end
	local hud = pg and pg:FindFirstChild("VehicleHUD")
	if hud and hud:FindFirstChild("Frame") then
		hud.Frame.Help.Visible = s.ShowHints ~= false
	end
end

function Phone.Start(ctx)
	ctxRef = ctx
	local function apply()
		Phone.ApplySettings(settings())
	end
	ctx.ProfileChanged:Connect(function()
		apply()
	end)
	task.delay(2, apply)
end

return Phone
