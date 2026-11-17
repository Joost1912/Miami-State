-- Schritt 13: Nachtbild. Ergaenzt beleuchtete Fenster an allen aelteren Gebaeuden (Hochhaeuser, Hotels,
-- Apartments, Buerohaeuser) und installiert den Tag-Nacht-Zyklus.
return function(Kit)
	local HttpService = game:GetService("HttpService")
	local rng = Random.new(1830)
	local added, models = 0, 0

	local function decorate(m, part, density)
		local at = function(x, y, z)
			return part.CFrame * CFrame.new(x, y - part.Size.Y / 2, z)
		end
		local before = #m:GetChildren()
		Kit.litWindows(m, at, part.Size.X, part.Size.Z, 0, part.Size.Y, rng, density)
		added += #m:GetChildren() - before
	end

	for _, d in ipairs(workspace.Map.Districts:GetChildren()) do
		local b = d:FindFirstChild("Buildings")
		if b then
			for _, m in ipairs(b:GetDescendants()) do
				-- Von diesem Schritt frueher ergaenzte Fenster entfernen, damit er wiederholbar bleibt
				if m:IsA("Model") and m:GetAttribute("NightAdded") then
					for _, c in ipairs(m:GetChildren()) do
						if c.Name == "LitWindow" then
							c:Destroy()
						end
					end
				end
				if m:IsA("Model") and not m:FindFirstChild("LitWindow") and not m.Name:match("^House_") then
					local did = false
					for _, p in ipairs(m:GetChildren()) do
						if p:IsA("Part") and p.Shape == Enum.PartType.Block then
							if p.Name:match("^Shaft") then
								decorate(m, p, 0.45)
								did = true
							elseif p.Name == "Body" and p.Size.Y > 30 then
								decorate(m, p, 0.35)
								did = true
							end
						end
					end
					if did then
						models += 1
						m:SetAttribute("NightAdded", true)
					end
				end
			end
		end
	end

	-- Tag-Nacht-Zyklus installieren
	local SSS = game:GetService("ServerScriptService")
	local s = SSS:FindFirstChild("DayNightController") or Instance.new("Script")
	s.Name = "DayNightController"
	s.Source = HttpService:GetAsync("http://localhost:34872/Server/DayNightController.server.luau", true)
	s.Parent = SSS

	-- Laternen tagsueber aus (Controller schaltet sie abends ein)
	for _, p in ipairs(game:GetService("CollectionService"):GetTagged("StreetLamp")) do
		p.Material = Enum.Material.SmoothPlastic
		for _, l in ipairs(p:GetChildren()) do
			if l:IsA("Light") then
				l.Enabled = false
			end
		end
	end
	return string.format("Fensterlicht an %d Gebaeuden ergaenzt (%d Felder), Tag-Nacht-Zyklus installiert", models, added)
end
