-- Schritt 8: Feinschliff – Wasserfarbe, Abendlicht, Glasvielfalt, Spielskripte installieren.
return function(Kit)
	local Lighting = game:GetService("Lighting")
	local HttpService = game:GetService("HttpService")

	-- Wasser: tieferes Tuerkis statt Neon-Cyan
	local T = workspace.Terrain
	T.WaterColor = Color3.fromRGB(18, 98, 112)
	T.WaterTransparency = 0.6
	T.WaterReflectance = 0.7

	-- Goldene Stunde
	Lighting.ClockTime = 17.4
	Lighting.Brightness = 3.2
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 120, 132)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		atm.Density = 0.26
		atm.Offset = 0.08
		atm.Color = Color3.fromRGB(222, 184, 168)
		atm.Decay = Color3.fromRGB(120, 104, 150)
		atm.Glare = 0.45
		atm.Haze = 1.1
	end

	-- Glas der Hochhaeuser: dunkler, spiegelnder, mehr Variation
	local rng = Random.new(9)
	local glassSet = {
		Color3.fromRGB(34, 62, 78), Color3.fromRGB(46, 80, 104), Color3.fromRGB(60, 96, 104),
		Color3.fromRGB(28, 40, 52), Color3.fromRGB(84, 98, 104), Color3.fromRGB(70, 60, 52),
	}
	local n = 0
	for _, m in ipairs(workspace.Map.Districts:GetDescendants()) do
		if m:IsA("Model") and (m.Name:find("Tower")) then
			local col = glassSet[rng:NextInteger(1, #glassSet)]
			for _, p in ipairs(m:GetChildren()) do
				if p:IsA("BasePart") and p.Name:match("^Shaft") then
					p.Color = col
					p.Reflectance = 0.18
					n += 1
				end
			end
		end
	end

	-- Spielskripte aus dem Repo installieren (Server)
	local SSS = game:GetService("ServerScriptService")
	local src = HttpService:GetAsync("http://localhost:34872/Server/TrafficSignalController.server.luau", true)
	local s = SSS:FindFirstChild("TrafficSignalController") or Instance.new("Script")
	s.Name = "TrafficSignalController"
	s.Source = src
	s.Parent = SSS

	return string.format("Glasflaechen angepasst: %d, Ampelsteuerung installiert", n)
end
