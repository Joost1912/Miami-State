-- Schritt 1: Grundsetup (Ordnerstruktur, Licht, Atmosphaere, Streaming, Wasser)
return function(Kit)
	local Lighting = game:GetService("Lighting")
	local ws = workspace

	-- Vorlagenteile entfernen
	for _, n in ipairs({ "Baseplate" }) do
		local p = ws:FindFirstChild(n)
		if p then
			p:Destroy()
		end
	end

	-- Explorer-Struktur laut Masterplan
	local map = Kit.folder(ws, "Map")
	local districts = Kit.folder(map, "Districts")
	for _, d in ipairs({ "BayfrontDowntown", "CoralKey", "CoconutHeights", "PortMeridian", "SawgrassPark" }) do
		local f = Kit.folder(districts, d)
		Kit.folder(f, "Buildings")
		Kit.folder(f, "Props")
	end
	local roads = Kit.folder(map, "Roads")
	for _, r in ipairs({ "Downtown", "CoralKey", "CoconutHeights", "Highways", "Bridges" }) do
		Kit.folder(roads, r)
	end
	Kit.folder(map, "Vegetation")
	Kit.folder(map, "ServiceSites")
	Kit.folder(map, "SpawnPoints")

	-- Streaming fuer grosse Map
	ws.StreamingEnabled = true
	ws.StreamingTargetRadius = 1024
	ws.StreamingMinRadius = 256

	-- Licht: warme Floridasonne am spaeten Nachmittag
	-- Technology ist fuer MCP-Code gesperrt; wird manuell auf "Future" gestellt (siehe Doku)
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	Lighting.ClockTime = 16.8
	Lighting.GeographicLatitude = 26
	Lighting.Brightness = 3
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(0, 0, 0)
	Lighting.OutdoorAmbient = Color3.fromRGB(132, 120, 128)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ExposureCompensation = 0.15
	Lighting.ShadowSoftness = 0.15

	for _, ch in ipairs(Lighting:GetChildren()) do
		if ch:IsA("PostEffect") or ch:IsA("Atmosphere") or ch:IsA("Sky") then
			ch:Destroy()
		end
	end
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.3
	atm.Offset = 0.12
	atm.Color = Color3.fromRGB(214, 186, 176)
	atm.Decay = Color3.fromRGB(112, 108, 140)
	atm.Glare = 0.35
	atm.Haze = 1.4
	atm.Parent = Lighting

	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.55
	bloom.Size = 30
	bloom.Threshold = 1.4
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = 0.02
	cc.Contrast = 0.12
	cc.Saturation = 0.14
	cc.TintColor = Color3.fromRGB(255, 246, 238)
	cc.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.55
	rays.Parent = Lighting

	-- Wasser: tuerkis, klar
	local t = ws.Terrain
	t.WaterColor = Color3.fromRGB(22, 128, 138)
	t.WaterTransparency = 0.75
	t.WaterReflectance = 0.55
	t.WaterWaveSize = 0.12
	t.WaterWaveSpeed = 8
	t.Decoration = false -- keine 3D-Grashalme (wachsen sonst durch Strassen, kosten Leistung)
	if not t:FindFirstChildOfClass("Clouds") then
		local cl = Instance.new("Clouds")
		cl.Cover = 0.42
		cl.Density = 0.55
		cl.Color = Color3.fromRGB(255, 244, 236)
		cl.Parent = t
	end

	return "Setup ok"
end
