-- Notruf 911 (Taste N): Kategorie, Beschreibung. Standort setzt der Server aus der Spielerposition.
local E = {}
local screen

function E.Close()
	if screen then
		screen:Destroy()
		screen = nil
	end
end

function E.Open(ctx)
	local UI, T = ctx.UI, ctx.UI.Theme
	local P = ctx.Config.Police
	E.Close()
	screen = UI.screen("MiamiEmergency", 20)
	local _, content = UI.window(screen, "Notruf 911", UDim2.fromOffset(460, 470), function()
		E.Close()
		ctx.Closed("Emergency")
	end)
	UI.list(content, 8)
	UI.label(content, "Was ist passiert? Dein Standort wird automatisch uebermittelt.", 13, { TextColor3 = T.Muted })
	local chosen
	local grid = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = content })
	UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 36), CellPadding = UDim2.fromOffset(8, 6), Parent = grid })
	local btns = {}
	for _, c in ipairs(P.CallCategories) do
		local b = UI.button(grid, c.Name, "secondary", { TextSize = 12, TextWrapped = true })
		btns[c.Id] = b
		b.MouseButton1Click:Connect(function()
			chosen = c.Id
			for id, bb in pairs(btns) do
				bb.BackgroundColor3 = (id == chosen) and T.Danger or T.Panel2
			end
		end)
	end
	local desc = UI.input(content, "Kurze Beschreibung (3-140 Zeichen)")
	local send = UI.button(content, "NOTRUF ABSETZEN", "danger")
	send.MouseButton1Click:Connect(function()
		if not chosen then
			UI.toast("Bitte Kategorie waehlen", "warning")
			return
		end
		if ctx.Request("Emergency.Call", { Category = chosen, Description = desc.Text }).ok then
			E.Close()
			ctx.Closed("Emergency")
		end
	end)
	UI.label(content, "Missbrauch des Notrufs wird verfolgt.", 11, { TextColor3 = T.Muted })
end

return E
