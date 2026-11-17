-- Police Department: Dashboard (Dienst, Raenge, Personal, Protokoll) und Fuhrpark-Menue.
-- Alle Aenderungen laufen ueber den Server (Berechtigungen dort geprueft); der Client zeigt nur an.
local P = {}
local screen

function P.Close()
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
	["Police.Radio"] = "Funk", ["Police.MDT"] = "MDT", ["Police.Cuff"] = "Handschellen", ["Police.Search"] = "Durchsuchen",
	["Police.Escort"] = "Eskortieren", ["Police.Cite"] = "Strafzettel", ["Police.Arrest"] = "Festnahme", ["Police.Jail"] = "Inhaftierung",
	["Police.Wanted"] = "Fahndung", ["Police.TrafficStop"] = "Verkehrskontrolle", ["Police.Confiscate"] = "Beschlagnahme",
	["Police.Warrant"] = "Haftbefehl", ["Police.Supervisor"] = "Aufsicht", ["Dispatch.Assign"] = "Einsatzzuweisung",
	["Radio.Command"] = "Command-Kanal", ["Faction.ManageRanks"] = "Befoerdern", ["Faction.Hire"] = "Einstellen", ["Faction.Fire"] = "Entlassen",
}

function P.Open(ctx, opts)
	local UI, T, F = ctx.UI, ctx.UI.Theme, ctx.Format
	local Factions = ctx.Config.Factions
	if opts and opts.Garage then
		return P.OpenGarage(ctx)
	end
	local res = ctx.Request("Police.Dashboard", nil, true)
	if not res.ok then
		UI.toast(res.msg or "Kein Zugriff", "error")
		ctx.Closed("Police")
		return
	end
	local d = res.data
	P.Close()
	screen = UI.screen("MiamiPolice", 20)
	local win, content = UI.window(screen, "Miami State Police - Dashboard", UDim2.fromOffset(720, 580), function()
		P.Close()
		ctx.Closed("Police")
	end)
	local _ = win
	local function reopen()
		task.wait(0.25)
		if screen then
			P.Open(ctx)
		end
	end

	-- Kopfzeile: Dienstnummer, Rufzeichen, Status
	local head = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(16, 30, 62), Size = UDim2.new(1, 0, 0, 64), Parent = content })
	UI.corner(head, 10)
	UI.pad(head, 12)
	UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 0, 24), Font = T.FontBlack, TextSize = 20, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = d.RankName .. "  |  " .. d.Callsign, Parent = head })
	UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(0.6, 0, 0, 16), Font = T.Font, TextSize = 13, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = "Dienstnummer #" .. d.Badge .. "  -  Miami State Police", Parent = head })
	local chip = UI.new("TextLabel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(170, 34), BackgroundColor3 = d.OnDuty and T.Success or T.Panel2, Font = T.FontBold, TextSize = 14, TextColor3 = d.OnDuty and T.Bg or T.Muted, Text = d.OnDuty and ("IM DIENST  " .. d.Status) or "AUSSER DIENST", Parent = head })
	UI.corner(chip, 8)

	local tabs = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 74), Size = UDim2.new(1, 0, 0, 34), Parent = content })
	UI.list(tabs, 8, true)
	local body = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 118), Size = UDim2.new(1, 0, 1, -118), Parent = content })
	local views = {}

	views.Duty = function()
		body:ClearAllChildren()
		local grid = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 210), Parent = body })
		UI.new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -8, 0, 64), CellPadding = UDim2.fromOffset(12, 10), Parent = grid })
		UI.stat(grid, "Dienstzeit gesamt", fmtDuration(d.DutySeconds), T.Accent)
		UI.stat(grid, "Aktuelle Schicht", d.OnDuty and fmtDuration(d.CurrentShift) or "-")
		UI.stat(grid, "Festnahmen", tostring(d.Arrests))
		UI.stat(grid, "Strafzettel", tostring(d.Citations))
		UI.stat(grid, "Gehalt", F.money(Factions.Police.Ranks[d.Rank].Salary) .. " / 10 Min.", T.Success)
		UI.stat(grid, "Einheiten im Dienst", tostring((function()
			local n = 0
			for _, o in ipairs(d.Roster) do
				if o.OnDuty then
					n += 1
				end
			end
			return n
		end)()))
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
			if ctx.Request("Police.SetCallsign", { Callsign = cs.Text }).ok then
				reopen()
			end
		end)
		if not d.AtStation and not d.OnDuty then
			UI.label(body, "Dienstantritt nur am Dienst-Terminal in der Umkleide der Wache.", 13, { TextColor3 = T.Warning, Position = UDim2.new(0, 0, 0, 210) })
		end
		UI.label(body, "EINHEITENSTATUS", 12, { TextColor3 = T.Muted, Font = T.FontBold, Position = UDim2.new(0, 0, 0, 236) })
		local st = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 258), Size = UDim2.new(1, 0, 0, 40), Parent = body })
		UI.list(st, 8, true)
		for _, s in ipairs(ctx.Config.Police.Statuses) do
			local b = UI.button(st, s.Id .. "  " .. s.Name, d.Status == s.Id and "primary" or "secondary", { Size = UDim2.new(0.2, -7, 1, 0), TextSize = 11 })
			b.MouseButton1Click:Connect(function()
				if ctx.Request("Police.SetStatus", { Status = s.Id }).ok then
					reopen()
				end
			end)
		end
		UI.label(body, "Tasten: B Funk  |  M MDT (im Streifenwagen / an der Wache)  |  X Massnahmen an Personen  |  N Notruf", 12, { TextColor3 = T.Muted, Position = UDim2.new(0, 0, 0, 312) })
	end

	views.Ranks = function()
		body:ClearAllChildren()
		local list = UI.scroll(body)
		UI.list(list, 6)
		for i, r in ipairs(Factions.Police.Ranks) do
			local perms = {}
			for p in pairs(PERM_NAMES) do
				local has = table.find(Factions.Police.Permissions, p) ~= nil
				for minRank, ps in pairs(Factions.Police.RankPermissions) do
					if i >= minRank and table.find(ps, p) then
						has = true
					end
				end
				if has then
					table.insert(perms, PERM_NAMES[p])
				end
			end
			table.sort(perms)
			local row = UI.new("Frame", { BackgroundColor3 = (i == d.Rank) and Color3.fromRGB(16, 30, 62) or T.Panel2, Size = UDim2.new(1, -6, 0, 56), Parent = list })
			UI.corner(row, 8)
			UI.pad(row, 10)
			UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.5, 0, 0, 18), Font = T.FontBold, TextSize = 15, TextColor3 = (i == d.Rank) and T.Accent or T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = i .. ". " .. r.Name, Parent = row })
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
						if ctx.Request("Police.SetRank", { Target = o.UserId, Rank = o.Rank + delta }).ok then
							reopen()
						end
					end)
				end
			end
			if d.CanFire then
				local b = UI.button(btns, "Entlassen", "danger", { Size = UDim2.new(0.3, -4, 1, 0), TextSize = 10 })
				b.MouseButton1Click:Connect(function()
					if ctx.Request("Police.Dismiss", { Target = o.UserId }).ok then
						reopen()
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
				if p.Faction ~= "Police" then
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
			local hire = UI.button(row, "ALS CADET EINSTELLEN", "primary", { Size = UDim2.new(0.4, -8, 1, 0), TextSize = 12 })
			hire.MouseButton1Click:Connect(function()
				local c = candidates[idx]
				if c and ctx.Request("Police.SetRank", { Target = c.UserId, Rank = 1 }).ok then
					reopen()
				end
			end)
		end
	end

	views.Log = function()
		body:ClearAllChildren()
		local r = ctx.Request("Police.Log", nil, true)
		local list = UI.scroll(body)
		UI.list(list, 4)
		if not r.ok then
			UI.label(list, r.msg or "Kein Zugriff", 14, { TextColor3 = T.Muted })
			return
		end
		for _, e in ipairs(r.data) do
			UI.label(list, string.format("%s  %s  %s -> %s  %s", F.time(e.T), e.Kind, e.Actor, e.Target, e.Details), 12, { TextColor3 = T.Muted })
		end
	end

	local current = "Duty"
	local tabBtns = {}
	local tabDefs = { { "Duty", "Dienst" }, { "Ranks", "Raenge" }, { "Staff", "Personal" } }
	if table.find(d.Permissions, "Police.Supervisor") then
		table.insert(tabDefs, { "Log", "Protokoll" })
	end
	for _, t in ipairs(tabDefs) do
		local b = UI.button(tabs, t[2], "secondary", { Size = UDim2.new(1 / #tabDefs, -6, 1, 0), TextSize = 13 })
		tabBtns[t[1]] = b
		b.MouseButton1Click:Connect(function()
			current = t[1]
			for k, bb in pairs(tabBtns) do
				bb.BackgroundColor3 = (k == current) and T.Accent or T.Panel2
				bb.TextColor3 = (k == current) and T.Bg or T.Text
			end
			views[current]()
		end)
	end
	tabBtns.Duty.BackgroundColor3, tabBtns.Duty.TextColor3 = T.Accent, T.Bg
	views.Duty()
end

-- Fuhrpark (am Garagen-Terminal)
function P.OpenGarage(ctx)
	local UI, T = ctx.UI, ctx.UI.Theme
	local res = ctx.Request("Police.GarageList", nil, true)
	if not res.ok then
		UI.toast(res.msg or "Kein Zugriff", "error")
		ctx.Closed("Police")
		return
	end
	P.Close()
	screen = UI.screen("MiamiPolice", 20)
	local _, content = UI.window(screen, "Police Garage - Fuhrpark", UDim2.fromOffset(560, 520), function()
		P.Close()
		ctx.Closed("Police")
	end)
	local list = UI.scroll(content, { Size = UDim2.new(1, 0, 1, -54) })
	UI.list(list, 8)
	for _, v in ipairs(res.data) do
		local row = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, -6, 0, 62), Parent = list })
		UI.corner(row, 10)
		UI.pad(row, 12)
		UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 0, 20), Font = T.FontBold, TextSize = 16, TextColor3 = v.Allowed and T.Text or T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = v.Name, Parent = row })
		UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(0.65, 0, 0, 16), Font = T.Font, TextSize = 12, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = v.Desc .. "  -  ab " .. v.MinRankName, Parent = row })
		local b = UI.button(row, v.Allowed and "AUSPARKEN" or "GESPERRT", v.Allowed and "primary" or "secondary", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(130, 36), TextSize = 13 })
		b.MouseButton1Click:Connect(function()
			if v.Allowed and ctx.Request("Police.GarageSpawn", { Id = v.Id }).ok then
				P.Close()
				ctx.Closed("Police")
			end
		end)
	end
	local park = UI.button(content, "DIENSTFAHRZEUG EINPARKEN", "secondary", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 42) })
	park.MouseButton1Click:Connect(function()
		ctx.Request("Police.GaragePark")
	end)
end

return P
