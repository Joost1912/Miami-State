-- Fire Department / EMS: Dashboard (Dienst, Einsaetze, Raenge, Personal) und Fahrzeuggarage.
-- Gleiche Bedienlogik wie das Police-Dashboard; alle Rechte prueft der Server.
local R = {}
local screen

function R.Close()
	if screen then
		screen:Destroy()
		screen = nil
	end
end

local function fmtDuration(s)
	s = math.floor(s or 0)
	return string.format("%d h %02d min", s // 3600, (s % 3600) // 60)
end

local PERM_NAMES = {
	["Fire.Radio"] = "Funk", ["Fire.Extinguish"] = "Loeschen", ["Fire.Equipment"] = "Ausruestung", ["Fire.Rescue"] = "Techn. Hilfe",
	["EMS.Examine"] = "Untersuchen", ["EMS.Stabilize"] = "Stabilisieren", ["Fire.IncidentCommand"] = "Einsatzleitung",
	["Fire.Supervisor"] = "Aufsicht", ["EMS.Radio"] = "Funk", ["EMS.Transport"] = "Transport", ["EMS.Revive"] = "Wiederbeleben",
	["EMS.Treat"] = "Klinikbehandlung", ["EMS.Medication"] = "Medikation", ["EMS.Supervisor"] = "Aufsicht",
	["Dispatch.Assign"] = "Einsatzzuweisung", ["Radio.Command"] = "Command-Kanal", ["Faction.ManageRanks"] = "Befoerdern",
	["Faction.Hire"] = "Einstellen", ["Faction.Fire"] = "Entlassen",
}
local HEAD = { Fire = Color3.fromRGB(70, 18, 16), EMS = Color3.fromRGB(14, 40, 66) }

function R.Open(ctx, opts)
	local UI, T, F = ctx.UI, ctx.UI.Theme, ctx.Format
	local Factions = ctx.Config.Factions
	if opts and opts.Garage then
		return R.OpenGarage(ctx)
	end
	local res = ctx.Request("Rescue.Dashboard", nil, true)
	if not res.ok then
		UI.toast(res.msg or "Kein Zugriff", "error")
		ctx.Closed("Rescue")
		return
	end
	local d = res.data
	local f = d.Faction
	local accent = ctx.Config.Rescue[f].Accent
	R.Close()
	screen = UI.screen("MiamiRescue", 20)
	local _, content = UI.window(screen, d.FactionName .. " - Dashboard", UDim2.fromOffset(740, 600), function()
		R.Close()
		ctx.Closed("Rescue")
	end)
	local function reopen(tab)
		task.wait(0.25)
		if screen then
			R.Open(ctx, { Tab = tab })
		end
	end

	local head = UI.new("Frame", { BackgroundColor3 = HEAD[f], Size = UDim2.new(1, 0, 0, 64), Parent = content })
	UI.corner(head, 10)
	UI.pad(head, 12)
	UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 0, 24), Font = T.FontBlack, TextSize = 20, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = d.RankName .. "  |  " .. d.Callsign, Parent = head })
	UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(0.6, 0, 0, 16), Font = T.Font, TextSize = 13, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = "Dienstnummer #" .. d.Badge .. "  -  " .. d.FactionName, Parent = head })
	local chip = UI.new("TextLabel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(170, 34), BackgroundColor3 = d.OnDuty and T.Success or T.Panel2, Font = T.FontBold, TextSize = 14, TextColor3 = d.OnDuty and T.Bg or T.Muted, Text = d.OnDuty and ("IM DIENST  " .. d.Status) or "AUSSER DIENST", Parent = head })
	UI.corner(chip, 8)

	local tabs = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 74), Size = UDim2.new(1, 0, 0, 34), Parent = content })
	UI.list(tabs, 8, true)
	local body = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 118), Size = UDim2.new(1, 0, 1, -118), Parent = content })
	local views = {}

	views.Duty = function()
		body:ClearAllChildren()
		local grid = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 150), Parent = body })
		UI.new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -8, 0, 64), CellPadding = UDim2.fromOffset(12, 10), Parent = grid })
		UI.stat(grid, "Dienstzeit gesamt", fmtDuration(d.DutySeconds), accent)
		UI.stat(grid, "Aktuelle Schicht", d.OnDuty and fmtDuration(d.CurrentShift) or "-")
		UI.stat(grid, d.StatALabel, tostring(d.StatA))
		UI.stat(grid, d.StatBLabel, tostring(d.StatB))
		UI.stat(grid, "Gehalt", F.money(Factions[f].Ranks[d.Rank].Salary) .. " / 10 Min.", T.Success)
		local onDuty = 0
		for _, o in ipairs(d.Roster) do
			if o.OnDuty then
				onDuty += 1
			end
		end
		UI.stat(grid, "Kraefte im Dienst", tostring(onDuty))
		local row = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 160), Size = UDim2.new(1, 0, 0, 42), Parent = body })
		UI.list(row, 10, true)
		local dutyBtn = UI.button(row, d.OnDuty and "DIENST BEENDEN" or "DIENST ANTRETEN", d.OnDuty and "danger" or "primary", { Size = UDim2.new(0.34, 0, 1, 0) })
		dutyBtn.MouseButton1Click:Connect(function()
			if ctx.Request("Job.SetDuty", { On = not d.OnDuty }).ok then
				reopen()
			end
		end)
		local cs = UI.input(row, "Rufzeichen", { Text = d.Callsign, Size = UDim2.new(0.33, 0, 1, 0) })
		local save = UI.button(row, "RUFZEICHEN SPEICHERN", "secondary", { Size = UDim2.new(0.3, -20, 1, 0), TextSize = 12 })
		save.MouseButton1Click:Connect(function()
			if ctx.Request("Rescue.SetCallsign", { Callsign = cs.Text }).ok then
				reopen()
			end
		end)
		if not d.AtStation and not d.OnDuty then
			UI.label(body, f == "Fire" and "Dienstantritt nur am Dienst-Terminal in der Umkleide der Feuerwache." or "Dienstantritt nur am Dienst-Terminal der Rettungswache im Krankenhaus.", 13, { TextColor3 = T.Warning, Position = UDim2.new(0, 0, 0, 210) })
		end
		UI.label(body, "EINHEITENSTATUS", 12, { TextColor3 = T.Muted, Font = T.FontBold, Position = UDim2.new(0, 0, 0, 236) })
		local st = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 258), Size = UDim2.new(1, 0, 0, 40), Parent = body })
		UI.list(st, 8, true)
		for _, s in ipairs(ctx.Config.Police.Statuses) do
			local b = UI.button(st, s.Id .. "  " .. s.Name, d.Status == s.Id and "primary" or "secondary", { Size = UDim2.new(0.2, -7, 1, 0), TextSize = 11 })
			b.MouseButton1Click:Connect(function()
				if ctx.Request("Rescue.SetStatus", { Status = s.Id }).ok then
					reopen()
				end
			end)
		end
		local hint = (f == "Fire") and "Werkzeuge: Feuerloescher und Strahlrohr (Inventar-Leiste, Maustaste halten). Strahlrohr braucht ein Loeschfahrzeug in der Naehe."
			or "Massnahmen am Patienten ueber X: Untersuchen, Stabilisieren, Versorgen, Wiederbeleben, Tragen, Transport, Klinikbehandlung."
		UI.label(body, hint, 12, { TextColor3 = T.Muted, Position = UDim2.new(0, 0, 0, 310), Size = UDim2.new(1, 0, 0, 34) })
		UI.label(body, "Tasten: K Dashboard  |  B Funk  |  X Interaktion  |  U Handy  |  V Karte", 12, { TextColor3 = T.Muted, Position = UDim2.new(0, 0, 0, 350) })
	end

	views.Calls = function()
		body:ClearAllChildren()
		local r = ctx.Request("Dispatch.List", nil, true)
		local data = r.data or { Calls = {}, Units = {} }
		local list = UI.scroll(body)
		UI.list(list, 8)
		if not d.OnDuty then
			UI.label(list, "Einsaetze sind nur im Dienst sichtbar.", 14, { TextColor3 = T.Muted })
			return
		end
		if #data.Calls == 0 then
			UI.label(list, "Keine offenen Einsaetze.", 14, { TextColor3 = T.Muted })
		end
		for _, c in ipairs(data.Calls) do
			local row = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, -6, 0, 96), Parent = list })
			UI.corner(row, 10)
			UI.pad(row, 10)
			UI.new("Frame", { BorderSizePixel = 0, BackgroundColor3 = ctx.Config.Police.PriorityColors[c.Priority], Position = UDim2.new(0, -6, 0, 0), Size = UDim2.new(0, 4, 1, 0), Parent = row })
			UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.72, 0, 0, 18), Font = T.FontBold, TextSize = 15, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("#%d  %s  -  %s", c.Id, c.Name, ctx.Config.Police.PriorityNames[c.Priority]), Parent = row })
			UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(0.74, 0, 0, 16), Font = T.Font, TextSize = 12, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("%s  -  Dienste: %s  -  Melder: %s", c.District, table.concat(c.Services, "/"), c.Caller), Parent = row })
			UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 38), Size = UDim2.new(0.74, 0, 0, 16), Font = T.Font, TextSize = 13, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = c.Desc, Parent = row })
			UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 56), Size = UDim2.new(0.74, 0, 0, 16), Font = T.FontBold, TextSize = 12, TextColor3 = accent, TextXAlignment = Enum.TextXAlignment.Left, Text = "Status: " .. c.Status .. "   Einheiten: " .. (#c.Units > 0 and table.concat(c.Units, ", ") or "-"), Parent = row })
			local btns = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.24, 0, 1, 0), Parent = row })
			UI.list(btns, 4)
			for _, b in ipairs({ { "Uebernehmen", "Dispatch.Attach", "primary" }, { "Vor Ort", "Dispatch.OnScene", "secondary" }, { "Abschliessen", "Dispatch.Close", "secondary" } }) do
				local btn = UI.button(btns, b[1], b[3], { Size = UDim2.new(1, 0, 0, 22), TextSize = 11 })
				btn.MouseButton1Click:Connect(function()
					if ctx.Request(b[2], { Id = c.Id }).ok then
						views.Calls()
					end
				end)
			end
			-- Nachalarmieren (z.B. Unfall -> Polizei/Rettungsdienst)
			local fw = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -20), Size = UDim2.new(0.74, 0, 0, 20), Parent = row })
			UI.list(fw, 6, true)
			for _, svc in ipairs({ { "Police", "+ Polizei" }, { "Fire", "+ Feuerwehr" }, { "EMS", "+ Rettungsdienst" } }) do
				if not table.find(c.Services, svc[1]) then
					local b = UI.button(fw, svc[2], "secondary", { Size = UDim2.fromOffset(110, 20), TextSize = 10 })
					b.MouseButton1Click:Connect(function()
						if ctx.Request("Dispatch.Forward", { Id = c.Id, Service = svc[1] }).ok then
							views.Calls()
						end
					end)
				end
			end
		end
	end

	views.Ranks = function()
		body:ClearAllChildren()
		local list = UI.scroll(body)
		UI.list(list, 6)
		local fac = Factions[f]
		for i, r in ipairs(fac.Ranks) do
			local perms = {}
			for p, name in pairs(PERM_NAMES) do
				local has = table.find(fac.Permissions, p) ~= nil
				for minRank, ps in pairs(fac.RankPermissions) do
					if i >= minRank and table.find(ps, p) then
						has = true
					end
				end
				if has and not table.find(perms, name) then
					table.insert(perms, name)
				end
			end
			table.sort(perms)
			local vehicles = {}
			for _, v in ipairs(ctx.Config.Rescue[f].Vehicles) do
				if v.MinRank == i then
					table.insert(vehicles, v.Name)
				end
			end
			local row = UI.new("Frame", { BackgroundColor3 = (i == d.Rank) and HEAD[f] or T.Panel2, Size = UDim2.new(1, -6, 0, 58), Parent = list })
			UI.corner(row, 8)
			UI.pad(row, 10)
			UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 0, 18), Font = T.FontBold, TextSize = 15, TextColor3 = (i == d.Rank) and accent or T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = i .. ". " .. r.Name .. (#vehicles > 0 and ("   (+ " .. table.concat(vehicles, ", ") .. ")") or ""), Parent = row })
			UI.new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.3, 0, 0, 18), Font = T.FontBold, TextSize = 14, TextColor3 = T.Success, TextXAlignment = Enum.TextXAlignment.Right, Text = F.money(r.Salary), Parent = row })
			UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 0, 16), Font = T.Font, TextSize = 11, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = table.concat(perms, ", "), Parent = row })
		end
	end

	views.Staff = function()
		body:ClearAllChildren()
		local list = UI.scroll(body, { Size = UDim2.new(1, 0, 1, -54) })
		UI.list(list, 6)
		for _, o in ipairs(d.Roster) do
			local row = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, -6, 0, 46), Parent = list })
			UI.corner(row, 8)
			UI.pad(row, 8)
			UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.5, 0, 1, 0), Font = T.FontBold, TextSize = 14, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = string.format("%s  (%s)  -  %s", o.Name, o.Callsign, o.RankName), Parent = row })
			UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.15, 0, 1, 0), Font = T.FontBold, TextSize = 12, TextColor3 = o.OnDuty and T.Success or T.Muted, Text = o.OnDuty and o.Status or "10-7", Parent = row })
			local btns = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.34, 0, 1, 0), Parent = row })
			UI.list(btns, 6, true)
			if d.CanManage then
				for _, delta in ipairs({ 1, -1 }) do
					local b = UI.button(btns, delta > 0 and "Befoerdern" or "Zurueckstufen", "secondary", { Size = UDim2.new(0.34, -4, 1, 0), TextSize = 10 })
					b.MouseButton1Click:Connect(function()
						if ctx.Request("Faction.SetRank", { Target = o.UserId, Rank = o.Rank + delta }).ok then
							reopen("Staff")
						end
					end)
				end
			end
			if d.CanFire then
				local b = UI.button(btns, "Entlassen", "danger", { Size = UDim2.new(0.3, -4, 1, 0), TextSize = 10 })
				b.MouseButton1Click:Connect(function()
					if ctx.Request("Faction.Dismiss", { Target = o.UserId }).ok then
						reopen("Staff")
					end
				end)
			end
		end
		if d.CanHire then
			local row = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -44), Size = UDim2.new(1, 0, 0, 40), Parent = body })
			UI.list(row, 8, true)
			local players = ctx.Request("Players.List", nil, true).data or {}
			local candidates = {}
			for _, p in ipairs(players) do
				if p.Faction ~= f then
					table.insert(candidates, p)
				end
			end
			local idx = 0
			local pick = UI.button(row, #candidates > 0 and "Bewerber waehlen >" or "Keine Bewerber online", "secondary", { Size = UDim2.new(0.6, 0, 1, 0), TextSize = 12 })
			pick.MouseButton1Click:Connect(function()
				if #candidates == 0 then
					return
				end
				idx = idx % #candidates + 1
				pick.Text = "Bewerber: " .. candidates[idx].Name
			end)
			local hire = UI.button(row, "ALS " .. Factions[f].Ranks[1].Name:upper() .. " EINSTELLEN", "primary", { Size = UDim2.new(0.4, -8, 1, 0), TextSize = 12 })
			hire.MouseButton1Click:Connect(function()
				local c = candidates[idx]
				if c and ctx.Request("Faction.SetRank", { Target = c.UserId, Rank = 1 }).ok then
					reopen("Staff")
				end
			end)
		end
	end

	local current = (opts and opts.Tab) or "Duty"
	local tabBtns = {}
	local tabDefs = { { "Duty", "Dienst" }, { "Calls", "Einsaetze" }, { "Ranks", "Raenge" }, { "Staff", "Personal" } }
	for _, t in ipairs(tabDefs) do
		local b = UI.button(tabs, t[2], "secondary", { Size = UDim2.new(1 / #tabDefs, -6, 1, 0), TextSize = 13 })
		tabBtns[t[1]] = b
		b.MouseButton1Click:Connect(function()
			current = t[1]
			for k, bb in pairs(tabBtns) do
				bb.BackgroundColor3 = (k == current) and accent or T.Panel2
				bb.TextColor3 = (k == current) and T.Bg or T.Text
			end
			views[current]()
		end)
	end
	tabBtns[current].BackgroundColor3, tabBtns[current].TextColor3 = accent, T.Bg
	views[current]()
end

-- Fahrzeughalle / Ambulanzgarage
function R.OpenGarage(ctx)
	local UI, T = ctx.UI, ctx.UI.Theme
	local res = ctx.Request("Rescue.GarageList", nil, true)
	if not res.ok then
		UI.toast(res.msg or "Kein Zugriff", "error")
		ctx.Closed("Rescue")
		return
	end
	local f = res.data.Faction
	R.Close()
	screen = UI.screen("MiamiRescue", 20)
	local _, content = UI.window(screen, f == "Fire" and "Fahrzeughalle - Fire Station 1" or "Ambulanzgarage - Bayfront Medical", UDim2.fromOffset(580, 500), function()
		R.Close()
		ctx.Closed("Rescue")
	end)
	local list = UI.scroll(content, { Size = UDim2.new(1, 0, 1, -54) })
	UI.list(list, 8)
	for _, v in ipairs(res.data.Vehicles) do
		local row = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, -6, 0, 62), Parent = list })
		UI.corner(row, 10)
		UI.pad(row, 12)
		UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 0, 20), Font = T.FontBold, TextSize = 16, TextColor3 = v.Allowed and T.Text or T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = v.Name, Parent = row })
		UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(0.68, 0, 0, 16), Font = T.Font, TextSize = 12, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = v.Desc .. "  -  ab " .. v.MinRankName, Parent = row })
		local b = UI.button(row, v.Allowed and "AUSPARKEN" or "GESPERRT", v.Allowed and "primary" or "secondary", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(130, 36), TextSize = 13 })
		b.MouseButton1Click:Connect(function()
			if v.Allowed and ctx.Request("Rescue.GarageSpawn", { Id = v.Id }).ok then
				R.Close()
				ctx.Closed("Rescue")
			end
		end)
	end
	local park = UI.button(content, "DIENSTFAHRZEUG EINPARKEN", "secondary", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 42) })
	park.MouseButton1Click:Connect(function()
		ctx.Request("Rescue.GaragePark")
	end)
end

return R
