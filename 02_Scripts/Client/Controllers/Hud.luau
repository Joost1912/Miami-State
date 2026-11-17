-- HUD: Geldanzeige (Bargeld/Bank), Beruf, Menue-Schaltflaechen (auch fuer Touch).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Hud = {}

function Hud.Start(ctx)
	local UI, T = ctx.UI, ctx.UI.Theme
	local player = Players.LocalPlayer
	local scr = UI.screen("MiamiHUD", 5)

	-- Geldanzeige oben rechts
	local box = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 20), Size = UDim2.fromOffset(230, 92), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.15, Parent = scr })
	UI.corner(box, 12)
	UI.stroke(box, T.Stroke, 1, 0.3)
	UI.pad(box, 12)
	local cash = UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), Font = T.FontBlack, TextSize = 24, TextColor3 = T.Success, TextXAlignment = Enum.TextXAlignment.Right, Text = "$0", Parent = box })
	local bank = UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, 0, 0, 18), Font = T.FontBold, TextSize = 14, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Right, Text = "Bank $0", Parent = box })
	local job = UI.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 48), Size = UDim2.new(1, 0, 0, 18), Font = T.FontBold, TextSize = 13, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Right, Text = "", Parent = box })

	-- Menueleiste unten links
	local bar = UI.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -20), Size = UDim2.fromOffset(740, 40), BackgroundTransparency = 1, Parent = scr })
	UI.list(bar, 8, true)
	-- Einsatzleiste (nur Polizei im Dienst) ueber der Menueleiste
	local pbar = UI.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -66), Size = UDim2.fromOffset(420, 36), BackgroundTransparency = 1, Visible = false, Parent = scr })
	UI.list(pbar, 8, true)
	local mdtBtn
	local entries = {
		{ bar, "Profil", "P", "Profile" }, { bar, "Inventar", "I", "Inventory" }, { bar, "Berufe", "J", "Jobs" },
		{ bar, "Interaktion", "X", "Interact" }, { bar, "Notruf", "N", "Emergency" }, { bar, "Handy", "U", "Phone" }, { bar, "Karte", "V", "CityMap" },
		{ pbar, "Dienst", "K", "Duty" }, { pbar, "Funk", "B", "Radio" }, { pbar, "MDT", "M", "MDT" },
	}
	for _, e in ipairs(entries) do
		local parent, b = e[1], { e[2], e[3], e[4] }
		local btn = UI.button(parent, b[1] .. "  [" .. b[2] .. "]", parent == pbar and "primary" or "secondary", { Size = UDim2.fromOffset(98, parent == pbar and 32 or 36), TextSize = 13, BackgroundTransparency = 0.1 })
		if b[3] == "MDT" then
			mdtBtn = btn
		end
		btn.MouseButton1Click:Connect(function()
			local name = b[3]
			if name == "Duty" then
				local fac = player:GetAttribute("Faction")
				name = (fac == "Police") and "Police" or "Rescue"
			end
			if name == "Interact" then
				ctx.Controllers.Interact.TargetNearest(ctx)
			elseif ctx.OpenMenu == name then
				ctx.Controllers[name].Close()
				ctx.Closed(name)
			else
				ctx.Open(name)
			end
		end)
	end

	local lastCash
	local function refresh()
		local c = player:GetAttribute("Cash") or 0
		cash.Text = ctx.Format.money(c)
		bank.Text = "Bank " .. ctx.Format.money(player:GetAttribute("Bank") or 0)
		if lastCash and c ~= lastCash then
			cash.TextColor3 = (c > lastCash) and T.Success or T.Danger
			TweenService:Create(cash, TweenInfo.new(0.8), { TextColor3 = T.Success }):Play()
		end
		lastCash = c
		local f = ctx.Config.Factions[player:GetAttribute("Faction") or "Civilian"]
		local r = f and f.Ranks[player:GetAttribute("Rank") or 1]
		job.Text = r and (r.Name .. ((player:GetAttribute("OnDuty") and " - im Dienst") or "")) or ""
		job.TextColor3 = (f and f ~= ctx.Config.Factions.Civilian) and f.Color or T.Accent
		box.Visible = player:GetAttribute("CharacterCreated") == true
		bar.Visible = box.Visible
		local fac = player:GetAttribute("Faction")
		pbar.Visible = box.Visible and (fac == "Police" or fac == "Fire" or fac == "EMS") and player:GetAttribute("OnDuty") == true
		if mdtBtn then
			mdtBtn.Visible = fac == "Police"
		end
	end
	for _, a in ipairs({ "Cash", "Bank", "Faction", "Rank", "OnDuty", "CharacterCreated" }) do
		player:GetAttributeChangedSignal(a):Connect(refresh)
	end
	refresh()
end

return Hud
