-- Berufsuebersicht: aktueller Beruf + Dienst, zivile Rollen, alle Fraktionen mit Raengen und Gehalt,
-- Verwaltung (nur Admins / Fuehrungskraefte - der Server prueft jede Aenderung erneut).
local J = {}
local screen

function J.Close()
	if screen then
		screen:Destroy()
		screen = nil
	end
end

function J.Open(ctx)
	local UI, T, F = ctx.UI, ctx.UI.Theme, ctx.Format
	local Factions = ctx.Config.Factions
	local d = ctx.Profile
	if not d then
		return
	end
	J.Close()
	local info = ctx.Request("Job.Info", nil, true).data or {}
	screen = UI.screen("MiamiJobs", 20)
	local _, content = UI.window(screen, "Berufe & Fraktionen", UDim2.fromOffset(640, 580), function()
		J.Close()
		ctx.Closed("Jobs")
	end)
	local scroll = UI.scroll(content)
	UI.list(scroll, 10)
	local function reopen()
		task.wait(0.2)
		if screen then
			J.Open(ctx)
		end
	end

	-- Aktueller Beruf
	local f = Factions[d.Job.Faction]
	local cur = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, -6, 0, 120), Parent = scroll })
	UI.corner(cur, 10)
	UI.pad(cur, 14)
	UI.label(cur, "AKTUELLER BERUF", 11, { TextColor3 = T.Muted, Font = T.FontBold })
	UI.label(cur, f.Ranks[d.Job.Rank].Name .. "  -  " .. f.Name, 20, { Font = T.FontBlack, Position = UDim2.new(0, 0, 0, 18), TextColor3 = (d.Job.Faction ~= "Civilian") and f.Color or T.Text })
	UI.label(cur, string.format("Gehalt: %s alle %d Min.%s", F.money(f.Ranks[d.Job.Rank].Salary), (info.PayInterval or 600) // 60, f.DutyRequired and " (nur im Dienst)" or ""), 13, { TextColor3 = T.Muted, Position = UDim2.new(0, 0, 0, 46) })
	if d.Job.Faction ~= "Civilian" then
		local row = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 72), Size = UDim2.new(1, 0, 0, 36), Parent = cur })
		UI.list(row, 8, true)
		local duty = UI.button(row, d.Job.OnDuty and "DIENST BEENDEN" or "DIENST ANTRETEN", d.Job.OnDuty and "secondary" or "primary", { Size = UDim2.new(0.5, -4, 1, 0), TextSize = 13 })
		duty.MouseButton1Click:Connect(function()
			if ctx.Request("Job.SetDuty", { On = not ctx.Profile.Job.OnDuty }).ok then
				reopen()
			end
		end)
		local resign = UI.button(row, "FRAKTION VERLASSEN", "danger", { Size = UDim2.new(0.5, -4, 1, 0), TextSize = 13 })
		resign.MouseButton1Click:Connect(function()
			if ctx.Request("Job.Resign").ok then
				reopen()
			end
		end)
	end

	-- Zivile Rollen
	if d.Job.Faction == "Civilian" then
		UI.label(scroll, "ZIVILE ROLLE WAEHLEN", 12, { TextColor3 = T.Muted, Font = T.FontBold })
		local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 38), Parent = scroll })
		UI.list(row, 8, true)
		for i, r in ipairs(Factions.Civilian.Ranks) do
			local b = UI.button(row, r.Name, (i == d.Job.Rank) and "primary" or "secondary", { Size = UDim2.new(0.25, -6, 1, 0), TextSize = 12 })
			b.MouseButton1Click:Connect(function()
				if ctx.Request("Job.SelectCivilian", { Rank = i }).ok then
					reopen()
				end
			end)
		end
	end

	-- Fraktionsuebersicht
	UI.label(scroll, "FRAKTIONEN", 12, { TextColor3 = T.Muted, Font = T.FontBold })
	for _, id in ipairs(Factions.Order) do
		local fac = Factions[id]
		local card = UI.new("Frame", { BackgroundColor3 = T.Bg, Size = UDim2.new(1, -6, 0, 40 + #fac.Ranks * 20), Parent = scroll })
		UI.corner(card, 10)
		UI.stroke(card, T.Stroke)
		UI.pad(card, 12)
		UI.new("Frame", { BorderSizePixel = 0, BackgroundColor3 = fac.Color, Size = UDim2.new(0, 3, 1, 0), Position = UDim2.new(0, -6, 0, 0), Parent = card })
		UI.label(card, fac.Name .. (fac.Whitelisted and "   (Zuweisung durch Leitung)" or "   (frei waehlbar)"), 15, { Font = T.FontBold })
		for i, r in ipairs(fac.Ranks) do
			UI.label(card, string.format("%d. %s  -  %s", i, r.Name, F.money(r.Salary)), 13, { TextColor3 = T.Muted, Position = UDim2.new(0, 10, 0, 4 + i * 20) })
		end
	end

	-- Verwaltung
	if info.IsAdmin or info.CanManage then
		UI.label(scroll, info.IsAdmin and "VERWALTUNG (ADMIN)" or "VERWALTUNG (LEITUNG)", 12, { TextColor3 = T.Accent2, Font = T.FontBold })
		local box = UI.new("Frame", { BackgroundColor3 = T.Panel2, Size = UDim2.new(1, -6, 0, 200), Parent = scroll })
		UI.corner(box, 10)
		UI.pad(box, 12)
		UI.list(box, 8)
		local players = ctx.Request("Players.List", nil, true).data or {}
		local sel = { Target = nil, Faction = d.Job.Faction ~= "Civilian" and d.Job.Faction or "Police", Rank = 1 }
		local function cycleButton(parent, getText, onClick)
			local b = UI.button(parent, getText(), "secondary", { Size = UDim2.new(1 / 3, -6, 1, 0), TextSize = 12 })
			b.MouseButton1Click:Connect(function()
				onClick()
				b.Text = getText()
			end)
			return b
		end
		local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Parent = box })
		UI.list(row, 8, true)
		local pIdx, fIdx = 0, table.find(Factions.Order, sel.Faction) or 2
		cycleButton(row, function()
			local p = players[pIdx]
			return p and ("Spieler: " .. p.Name) or "Spieler waehlen >"
		end, function()
			pIdx = pIdx % math.max(#players, 1) + 1
			sel.Target = players[pIdx] and players[pIdx].UserId
		end)
		local rankBtn
		cycleButton(row, function()
			return "Fraktion: " .. Factions[Factions.Order[fIdx]].Short
		end, function()
			fIdx = fIdx % #Factions.Order + 1
			sel.Faction = Factions.Order[fIdx]
			sel.Rank = 1
			if rankBtn then
				rankBtn.Text = "Rang: " .. Factions[sel.Faction].Ranks[sel.Rank].Name
			end
		end)
		rankBtn = cycleButton(row, function()
			return "Rang: " .. Factions[sel.Faction].Ranks[sel.Rank].Name
		end, function()
			sel.Rank = sel.Rank % #Factions[sel.Faction].Ranks + 1
		end)
		local apply = UI.button(box, "ZUWEISEN", "primary")
		apply.MouseButton1Click:Connect(function()
			if not sel.Target then
				UI.toast("Bitte Spieler waehlen", "error")
				return
			end
			if ctx.Request("Job.Set", sel).ok then
				reopen()
			end
		end)
		UI.label(box, "Der Server prueft jede Zuweisung (Admin oder Leitung der Fraktion, nur unterhalb des eigenen Rangs).", 12, { TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 34) })
	end
end

return J
