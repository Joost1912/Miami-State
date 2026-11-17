-- Spielerprofil: Charakterdaten, Beruf, Finanzen, Statistik.
local P = {}
local screen

function P.Close()
	if screen then
		screen:Destroy()
		screen = nil
	end
end

function P.Open(ctx)
	local UI, T, F = ctx.UI, ctx.UI.Theme, ctx.Format
	local d = ctx.Profile
	if not d then
		return
	end
	P.Close()
	screen = UI.screen("MiamiProfile", 20)
	local _, content = UI.window(screen, "Profil", UDim2.fromOffset(520, 520), function()
		P.Close()
		ctx.Closed("Profile")
	end)
	local c = d.Character
	local f = ctx.Config.Factions[d.Job.Faction]
	UI.label(content, c.FirstName .. " " .. c.LastName, 28, { Font = T.FontBlack, Size = UDim2.new(1, 0, 0, 34) })
	local genders = { m = "maennlich", w = "weiblich", d = "divers" }
	UI.label(content, string.format("Jahrgang %d  -  %s", c.BirthYear, genders[c.Gender] or ""), 14, { TextColor3 = T.Muted, Position = UDim2.new(0, 0, 0, 36) })
	local grid = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 72), Size = UDim2.new(1, 0, 1, -72), Parent = content })
	UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 64), CellPadding = UDim2.fromOffset(12, 12), Parent = grid })
	UI.stat(grid, "Fraktion", f.Name, f ~= ctx.Config.Factions.Civilian and f.Color or T.Text)
	UI.stat(grid, "Dienstgrad", f.Ranks[d.Job.Rank].Name .. (d.Job.OnDuty and " (Dienst)" or ""))
	UI.stat(grid, "Bargeld", F.money(d.Money.Cash), T.Success)
	UI.stat(grid, "Bankkonto", F.money(d.Money.Bank), T.Accent)
	UI.stat(grid, "Verdient gesamt", F.money(d.Stats.TotalEarned))
	UI.stat(grid, "Spielzeit", string.format("%d h %d min", d.Stats.PlayTime // 3600, (d.Stats.PlayTime % 3600) // 60))
	UI.stat(grid, "Besuche", tostring(d.Stats.Joins))
	UI.stat(grid, "Fahrzeuge / Immobilien", string.format("%d / %d", #d.Vehicles.Owned, #d.Properties.Owned))
end

return P
