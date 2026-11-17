-- Mobile Data Terminal (Taste M): Einsaetze, Karte, Personen, Fahrzeuge, Verkehrskontrolle.
-- Zugriff nur im Polizeifahrzeug oder an Terminals der Wache (Server prueft bei JEDER Anfrage).
local M = {}
local screen, mapLoop
local currentTab = "Calls"

function M.Close()
	mapLoop = nil
	if screen then
		screen:Destroy()
		screen = nil
	end
end

local function ago(t)
	local s = os.time() - (t or os.time())
	return s < 60 and (s .. " s") or (math.floor(s / 60) .. " min")
end

function M.Open(ctx, opts)
	local UI, T, F = ctx.UI, ctx.UI.Theme, ctx.Format
	local PoliceCfg, MapData = ctx.Config.Police, ctx.Config.MapData
	local acc = ctx.Request("MDT.Access", nil, true)
	if not (acc.ok and acc.data.Access) then
		UI.toast("MDT nur im Streifenwagen oder an der Wache (im Dienst)", "warning")
		ctx.Closed("MDT")
		return
	end
	currentTab = (opts and opts.Tab) or currentTab
	M.Close()
	screen = UI.screen("MiamiMDT", 20)
	local _, content = UI.window(screen, "MSP Mobile Data Terminal", UDim2.fromOffset(820, 600), function()
		M.Close()
		ctx.Closed("MDT")
	end)
	local tabs = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = content })
	UI.list(tabs, 8, true)
	local body = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 44), Size = UDim2.new(1, 0, 1, -44), Parent = content })
	local views = {}

	-- Einsaetze ----------------------------------------------------------------------------------
	views.Calls = function()
		body:ClearAllChildren()
		local r = ctx.Request("Dispatch.List", nil, true)
		local data = r.data or { Calls = {}, Units = {} }
		local list = UI.scroll(body)
		UI.list(list, 8)
		if #data.Calls == 0 then
			UI.label(list, "Keine offenen Einsaetze.", 14, { TextColor3 = T.Muted })
		end
		for _, c in ipairs(data.Calls) do
			local row = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, -6, 0, 92), Parent = list })
			UI.corner(row, 10)
			UI.pad(row, 10)
			UI.new("Frame", { BorderSizePixel = 0, BackgroundColor3 = PoliceCfg.PriorityColors[c.Priority], Position = UDim2.new(0, -6, 0, 0), Size = UDim2.new(0, 4, 1, 0), Parent = row })
			UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.7, 0, 0, 18), Font = T.FontBold, TextSize = 15, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("#%d  %s  -  %s", c.Id, c.Name, PoliceCfg.PriorityNames[c.Priority]), Parent = row })
			UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(0.75, 0, 0, 16), Font = T.Font, TextSize = 12, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("%s  (X %d / Z %d)  -  vor %s  -  Melder: %s", c.District, c.X, c.Z, ago(c.T), c.Caller), Parent = row })
			UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 38), Size = UDim2.new(0.75, 0, 0, 16), Font = T.Font, TextSize = 13, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = c.Desc, Parent = row })
			UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 56), Size = UDim2.new(0.75, 0, 0, 16), Font = T.FontBold, TextSize = 12, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Left, Text = "Status: " .. c.Status .. "   Einheiten: " .. (#c.Units > 0 and table.concat(c.Units, ", ") or "-"), Parent = row })
			local btns = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.22, 0, 1, 0), Parent = row })
			UI.list(btns, 4)
			for _, b in ipairs({ { "Uebernehmen", "Dispatch.Attach", "primary" }, { "Vor Ort", "Dispatch.OnScene", "secondary" }, { "Abschliessen", "Dispatch.Close", "secondary" } }) do
				local btn = UI.button(btns, b[1], b[3], { Size = UDim2.new(1, 0, 0, 22), TextSize = 11 })
				btn.MouseButton1Click:Connect(function()
					if ctx.Request(b[2], { Id = c.Id }).ok then
						views.Calls()
					end
				end)
			end
			if data.CanAssign then
				local idx = 0
				local assign = UI.button(row, "Zuweisen >", "secondary", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.77, 0, 1, 0), Size = UDim2.fromOffset(150, 20), TextSize = 11 })
				assign.MouseButton1Click:Connect(function()
					local units = data.Units
					if #units == 0 then
						return
					end
					idx = idx % #units + 1
					local u = units[idx]
					assign.Text = "-> " .. u.Callsign
					task.delay(1.2, function()
						if assign.Parent and assign.Text == "-> " .. u.Callsign then
							if ctx.Request("Dispatch.Assign", { Id = c.Id, Target = u.UserId }).ok then
								views.Calls()
							end
						end
					end)
				end)
			end
		end
	end

	-- Karte ------------------------------------------------------------------------------------------
	views.Map = function()
		body:ClearAllChildren()
		local B = MapData.Bounds
		local holder = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(8, 14, 22), Size = UDim2.new(1, 0, 1, 0), ClipsDescendants = true, Parent = body })
		UI.corner(holder, 10)
		local function pos(x, z)
			return UDim2.fromScale((x - B.X0) / (B.X1 - B.X0), (z - B.Z0) / (B.Z1 - B.Z0))
		end
		local function size(w, h)
			return UDim2.fromScale(w / (B.X1 - B.X0), h / (B.Z1 - B.Z0))
		end
		for _, dd in ipairs(MapData.Districts) do
			local f = UI.new("Frame", { BorderSizePixel = 0, BackgroundColor3 = dd.Color, BackgroundTransparency = 0.82, Position = pos(dd.X0, dd.Z0), Size = size(dd.X1 - dd.X0, dd.Z1 - dd.Z0), Parent = holder })
			UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = T.FontBold, TextSize = 11, TextColor3 = dd.Color, TextTransparency = 0.2, Text = dd.Name, Parent = f })
		end
		for _, r in ipairs(MapData.Roads) do
			local w = (r[5] == "Highway" and 3) or (r[5] == "Boulevard" and 2) or 1
			local col = (r[5] == "Highway" and Color3.fromRGB(255, 196, 80)) or Color3.fromRGB(150, 160, 180)
			local f = UI.new("Frame", { BorderSizePixel = 0, BackgroundColor3 = col, BackgroundTransparency = 0.25, Parent = holder })
			if r[1] == r[3] then
				f.Position = pos(r[1], r[2])
				f.Size = UDim2.new(0, w, (r[4] - r[2]) / (B.Z1 - B.Z0), 0)
			else
				f.Position = pos(r[1], r[2])
				f.Size = UDim2.new((r[3] - r[1]) / (B.X1 - B.X0), 0, 0, w)
			end
		end
		for _, l in ipairs(MapData.Landmarks) do
			local dot = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.Text, Position = pos(l.X, l.Z), Size = UDim2.fromOffset(6, 6), Parent = holder })
			UI.corner(dot, 3)
			UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, -6), Size = UDim2.fromOffset(120, 12), Font = T.Font, TextSize = 10, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = l.Name, Parent = dot })
		end
		local dyn = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = holder })
		local legend = UI.label(holder, "Einsaetze (farbig nach Prioritaet)  |  Einheiten (blau)  |  Du (weiss)", 11, { Position = UDim2.new(0, 8, 1, -18), TextColor3 = T.Muted })
		local _ = legend
		local token = {}
		mapLoop = token
		task.spawn(function()
			while mapLoop == token and screen do
				local r = ctx.Request("Dispatch.List", nil, true)
				if mapLoop ~= token then
					break
				end
				dyn:ClearAllChildren()
				for _, c in ipairs((r.data and r.data.Calls) or {}) do
					local m = UI.new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = PoliceCfg.PriorityColors[c.Priority], Position = pos(c.X, c.Z), Size = UDim2.fromOffset(46, 16), Font = T.FontBold, TextSize = 10, TextColor3 = T.Bg, Text = "#" .. c.Id, Parent = dyn })
					UI.corner(m, 4)
				end
				for _, u in ipairs((r.data and r.data.Units) or {}) do
					local isMe = u.UserId == game:GetService("Players").LocalPlayer.UserId
					local m = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = isMe and Color3.new(1, 1, 1) or Color3.fromRGB(70, 130, 255), Position = pos(u.X, u.Z), Size = UDim2.fromOffset(9, 9), Parent = dyn })
					UI.corner(m, 5)
					UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, -5), Size = UDim2.fromOffset(110, 12), Font = T.FontBold, TextSize = 10, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = u.Callsign .. " " .. u.Status, Parent = m })
				end
				task.wait(2)
			end
		end)
	end

	-- Personen ------------------------------------------------------------------------------------------
	views.People = function()
		body:ClearAllChildren()
		local left = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.38, -8, 1, 0), Parent = body })
		local right = UI.new("Frame", { BackgroundColor3 = T.Panel2, Position = UDim2.new(0.38, 8, 0, 0), Size = UDim2.new(0.62, -8, 1, 0), Parent = body })
		UI.corner(right, 10)
		local q = UI.input(left, "Name suchen (mind. 2 Zeichen)")
		local results = UI.scroll(left, { Position = UDim2.new(0, 0, 0, 50), Size = UDim2.new(1, 0, 1, -50) })
		UI.list(results, 6)
		local function detail(uid)
			right:ClearAllChildren()
			local r = ctx.Request("MDT.Person", { UserId = uid }, true)
			if not r.ok then
				UI.label(right, r.msg or "Fehler", 14, { TextColor3 = T.Danger, Position = UDim2.fromOffset(12, 12) })
				return
			end
			local p = r.data
			local s = UI.scroll(right, { Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 1, -24) })
			UI.list(s, 6)
			UI.label(s, p.Name, 22, { Font = T.FontBlack })
			UI.label(s, string.format("Jahrgang %s  -  Spieler %s  -  Fraktion %s", tostring(p.BirthYear), p.Username, p.Faction), 12, { TextColor3 = T.Muted })
			UI.label(s, string.format("Fuehrerschein: %s (%d Punkte)   Festnahmen: %d%s", p.License, p.Points, p.Arrests, p.Jailed and ("   IN HAFT (" .. p.JailRemaining .. " s)") or ""), 13, { TextColor3 = p.License == "Gueltig" and T.Text or T.Danger })
			UI.label(s, p.Wanted and ("GESUCHT: " .. p.WantedReason) or "Keine Fahndung", 15, { Font = T.FontBold, TextColor3 = p.Wanted and T.Danger or T.Success })
			local function section(title, rows, fmt)
				UI.label(s, string.upper(title) .. " (" .. #rows .. ")", 12, { TextColor3 = T.Muted, Font = T.FontBold })
				for i = 1, math.min(#rows, 6) do
					UI.label(s, fmt(rows[i]), 12, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
				end
			end
			section("Haftbefehle", p.WarrantList, function(w)
				return string.format("%s %s - %s (%s)", w.Active and "[AKTIV]" or "[erledigt]", F.time(w.T), table.concat(w.Titles, ", "), w.Officer)
			end)
			section("Straftaten", p.Charges, function(c)
				return string.format("%s - %s - $%d, %d Min. (%s)", F.time(c.T), table.concat(c.Titles, ", "), c.Fine, c.Jail, c.Officer)
			end)
			section("Strafzettel", p.Citations, function(c)
				return string.format("%s - %s $%d %s (%s)", F.time(c.T), c.Title, c.Fine, c.Paid and "bezahlt" or "OFFEN", c.Officer)
			end)
			section("Verwarnungen", p.Warnings, function(w)
				return string.format("%s - %s (%s)", F.time(w.T), w.Text, w.Officer)
			end)
			-- Aktionen
			UI.label(s, "MASSNAHMEN", 12, { TextColor3 = T.Muted, Font = T.FontBold })
			local reason = UI.input(s, "Grund der Fahndung (max. 80 Zeichen)")
			local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = s })
			UI.list(row, 6, true)
			local w1 = UI.button(row, p.Wanted and "FAHNDUNG AUFHEBEN" or "FAHNDUNG AUSSCHREIBEN", p.Wanted and "secondary" or "danger", { Size = UDim2.new(0.5, -3, 1, 0), TextSize = 11 })
			w1.MouseButton1Click:Connect(function()
				if ctx.Request("MDT.SetWanted", { UserId = uid, On = not p.Wanted, Reason = reason.Text }).ok then
					detail(uid)
				end
			end)
			local picked = {}
			local w2 = UI.button(row, "HAFTBEFEHL (Tatbestaende waehlen)", "secondary", { Size = UDim2.new(0.5, -3, 1, 0), TextSize = 11 })
			local grid = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 120), Parent = s })
			UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 22), CellPadding = UDim2.fromOffset(6, 4), Parent = grid })
			for _, pc in ipairs(PoliceCfg.PenalCode) do
				local b = UI.button(grid, pc.Id .. " " .. pc.Title, "secondary", { TextSize = 10, TextTruncate = Enum.TextTruncate.AtEnd })
				b.MouseButton1Click:Connect(function()
					local i = table.find(picked, pc.Id)
					if i then
						table.remove(picked, i)
					else
						table.insert(picked, pc.Id)
					end
					b.BackgroundColor3 = table.find(picked, pc.Id) and T.Accent2 or T.Panel2
				end)
			end
			w2.MouseButton1Click:Connect(function()
				if #picked == 0 then
					UI.toast("Bitte Tatbestaende markieren", "warning")
					return
				end
				if ctx.Request("MDT.Warrant", { UserId = uid, Charges = picked }).ok then
					detail(uid)
				end
			end)
		end
		local function search()
			results:ClearAllChildren()
			UI.list(results, 6)
			local r = ctx.Request("MDT.SearchPerson", { Query = q.Text })
			for _, p in ipairs(r.data or {}) do
				local b = UI.button(results, (p.Wanted and "[GESUCHT] " or "") .. p.Name .. (p.Warrants > 0 and ("  (" .. p.Warrants .. " HB)") or ""), p.Wanted and "danger" or "secondary", { Size = UDim2.new(1, -6, 0, 34), TextSize = 12 })
				b.MouseButton1Click:Connect(function()
					detail(p.UserId)
				end)
			end
		end
		q.FocusLost:Connect(function(enter)
			if enter then
				search()
			end
		end)
		local go = UI.button(left, "SUCHEN", "primary", { Position = UDim2.new(0, 0, 1, -40), Size = UDim2.new(1, 0, 0, 36), TextSize = 13 })
		go.MouseButton1Click:Connect(search)
		results.Size = UDim2.new(1, 0, 1, -100)
	end

	-- Fahrzeuge ------------------------------------------------------------------------------------------
	views.Vehicles = function()
		body:ClearAllChildren()
		UI.list(body, 10)
		UI.label(body, "KENNZEICHENABFRAGE", 12, { TextColor3 = T.Muted, Font = T.FontBold })
		local plate = UI.input(body, "Kennzeichen, z.B. MS-1234A")
		local out = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, 0, 0, 180), Parent = body })
		UI.corner(out, 10)
		UI.pad(out, 12)
		UI.list(out, 4)
		local go = UI.button(body, "ABFRAGEN", "primary")
		go.MouseButton1Click:Connect(function()
			out:ClearAllChildren()
			UI.pad(out, 12)
			UI.list(out, 4)
			local r = ctx.Request("MDT.Plate", { Plate = plate.Text:upper() })
			if r.ok then
				local v = r.data
				UI.label(out, v.Plate .. "  -  " .. v.Type, 20, { Font = T.FontBlack })
				UI.label(out, "Halter: " .. v.Owner .. "   (" .. v.Kind .. ")", 14)
				UI.label(out, "Zulassung: " .. v.Registered, 14)
				UI.label(out, "Fuehrerschein Halter: " .. v.OwnerLicense, 14, { TextColor3 = v.OwnerLicense == "Gueltig" and T.Text or T.Danger })
				UI.label(out, v.OwnerWanted and "HALTER WIRD GESUCHT" or "Keine Fahndung gegen den Halter", 14, { Font = T.FontBold, TextColor3 = v.OwnerWanted and T.Danger or T.Success })
			end
		end)
	end

	-- Verkehrskontrolle -------------------------------------------------------------------------------
	views.Traffic = function()
		body:ClearAllChildren()
		UI.list(body, 10)
		UI.label(body, "VERKEHRSKONTROLLE", 12, { TextColor3 = T.Muted, Font = T.FontBold })
		UI.label(body, "Aus dem Streifenwagen: Fahrzeug direkt vor dir zum Anhalten auffordern. Halter- und Fuehrerscheindaten werden automatisch abgefragt. Strafzettel/Verwarnung danach am Fahrer ueber das Interaktionsmenue (X).", 13, { Size = UDim2.new(1, 0, 0, 54) })
		local out = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, 0, 0, 170), Parent = body })
		UI.corner(out, 10)
		UI.pad(out, 12)
		UI.list(out, 4)
		local go = UI.button(body, "FAHRZEUG ANHALTEN", "danger")
		go.MouseButton1Click:Connect(function()
			local r = ctx.Request("Justice.TrafficStop")
			out:ClearAllChildren()
			UI.pad(out, 12)
			UI.list(out, 4)
			if r.ok and r.data then
				local v = r.data.Vehicle or {}
				UI.label(out, (v.Plate or "?") .. "  -  " .. (v.Type or "?"), 20, { Font = T.FontBlack })
				UI.label(out, "Fahrer: " .. r.data.DriverName .. "   Halter: " .. tostring(v.Owner), 14)
				UI.label(out, "Fuehrerschein Halter: " .. tostring(v.OwnerLicense), 14, { TextColor3 = v.OwnerLicense == "Gueltig" and T.Text or T.Danger })
				UI.label(out, v.OwnerWanted and "HALTER WIRD GESUCHT" or "Keine Fahndung", 14, { Font = T.FontBold, TextColor3 = v.OwnerWanted and T.Danger or T.Success })
			end
		end)
	end

	-- Fahndung (Prompt 09): aktive Ueberfaelle + gesuchte Personen (Fahndungsstufen) - nur Polizei mit MDT-Zugriff
	views.Wanted = function()
		body:ClearAllChildren()
		local r = ctx.Request("Crime.PoliceView", nil, true)
		local data = r.data or { Heists = {}, Wanted = {} }
		local list = UI.scroll(body)
		UI.list(list, 8)
		UI.label(list, "AKTIVE UEBERFAELLE", 12, { Font = T.FontBlack, TextColor3 = T.Danger })
		if #data.Heists == 0 then
			UI.label(list, "Keine laufenden Ueberfaelle.", 13, { TextColor3 = T.Muted })
		end
		for _, h in ipairs(data.Heists) do
			local row = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, -6, 0, 58), Parent = list })
			UI.corner(row, 10)
			UI.pad(row, 10)
			UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.7, 0, 0, 18), Font = T.FontBold, TextSize = 14, TextColor3 = T.Danger, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("%s  -  Einsatz #%s", h.Name, tostring(h.CallId)), Parent = row })
			UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(0.7, 0, 0, 16), Font = T.Font, TextSize = 12, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("%s  |  Taeter: %d  |  Fortschritt %d%%  |  seit %s", MapData.DistrictAt(h.X, h.Z), h.Crew, math.floor(h.Progress / math.max(1, h.Duration) * 100), ago(h.Since)), Parent = row })
			local b = UI.button(row, "UEBERNEHMEN", "danger", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(130, 30), TextSize = 12 })
			b.MouseButton1Click:Connect(function()
				ctx.Request("Dispatch.Attach", { Id = h.CallId })
			end)
		end
		UI.label(list, "GESUCHTE PERSONEN (ANWESEND)", 12, { Font = T.FontBlack, TextColor3 = T.Warning })
		if #data.Wanted == 0 then
			UI.label(list, "Niemand wird gesucht.", 13, { TextColor3 = T.Muted })
		end
		for _, w in ipairs(data.Wanted) do
			local lv = ctx.Config.Crime.WantedLevels[w.Level]
			local row = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, -6, 0, 58), Parent = list })
			UI.corner(row, 10)
			UI.pad(row, 10)
			UI.new("Frame", { BorderSizePixel = 0, BackgroundColor3 = lv.Color, Position = UDim2.new(0, -6, 0, 0), Size = UDim2.new(0, 4, 1, 0), Parent = row })
			UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.7, 0, 0, 18), Font = T.FontBold, TextSize = 14, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("%s  -  %s%s", w.Name, lv.Name, w.Warrant and "  (Haftbefehl)" or ""), Parent = row })
			UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(0.75, 0, 0, 16), Font = T.Font, TextSize = 12, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = string.format("%s  |  zuletzt: %s", w.Reason ~= "" and w.Reason or "ohne Angabe", w.District), Parent = row })
			local b = UI.button(row, "AKTE", "secondary", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(100, 30), TextSize = 12 })
			b.MouseButton1Click:Connect(function()
				M._personTarget = w.UserId
				currentTab = "People"
				M.Open(ctx, { Tab = "People" })
			end)
		end
	end

	local tabBtns = {}
	local TABS = { { "Calls", "Einsaetze" }, { "Wanted", "Fahndung" }, { "Map", "Karte" }, { "People", "Personen" }, { "Vehicles", "Fahrzeuge" }, { "Traffic", "Kontrolle" } }
	for _, t in ipairs(TABS) do
		local b = UI.button(tabs, t[2], "secondary", { Size = UDim2.new(1 / #TABS, -7, 1, 0), TextSize = 13 })
		tabBtns[t[1]] = b
		b.MouseButton1Click:Connect(function()
			mapLoop = nil
			currentTab = t[1]
			for k, bb in pairs(tabBtns) do
				bb.BackgroundColor3 = (k == currentTab) and T.Accent or T.Panel2
				bb.TextColor3 = (k == currentTab) and T.Bg or T.Text
			end
			views[currentTab]()
		end)
	end
	tabBtns[currentTab].BackgroundColor3, tabBtns[currentTab].TextColor3 = T.Accent, T.Bg
	views[currentTab]()
end

-- Live-Aktualisierung bei neuen Einsaetzen
function M.CallChanged(ctx)
	if screen and currentTab == "Calls" then
		M.Open(ctx, { Tab = "Calls" })
	end
end

return M
