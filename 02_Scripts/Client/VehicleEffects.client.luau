-- VehicleEffects (StarterPlayerScripts): rein lokale Darstellung auf jedem Client.
-- Blaulicht (LightsOn), Sirene (Siren + SirenTone), Hupe (HornAt), Warnblinker (Hazard), Abblendlicht (Headlights).
local CollectionService = game:GetService("CollectionService")

local OFF = 0.6
local phase = 0
local lastHorn = setmetatable({}, { __mode = "k" })

local function setLamp(lamp, on)
	lamp.Transparency = on and 0 or OFF
	local l = lamp:FindFirstChildOfClass("PointLight")
	if l then
		l.Enabled = on
	end
end

local function update(model)
	local body = model:FindFirstChild("Body")
	local chassis = model:FindFirstChild("Chassis")
	if not body or not chassis then
		return
	end
	local fast = phase % 2 == 0
	-- Blaulicht
	if model:GetAttribute("Emergency") then
		local on = model:GetAttribute("LightsOn")
		for _, lamp in ipairs(body:GetChildren()) do
			if lamp.Name == "LightRed" then
				setLamp(lamp, on and fast)
			elseif lamp.Name == "LightBlue" then
				setLamp(lamp, on and not fast)
			end
		end
		-- Sirene
		local sirenOn = model:GetAttribute("Siren")
		local tone = model:GetAttribute("SirenTone") or 1
		local sfx = game:GetService("SoundService"):FindFirstChild("MiamiSFX")
		for _, snd in ipairs(chassis:GetChildren()) do
			if snd:IsA("Sound") and sfx and snd.SoundGroup ~= sfx then
				snd.SoundGroup = sfx -- Lautstaerke aus den Handy-Einstellungen
			end
			if snd:IsA("Sound") and snd.Name:match("^Siren") then
				local want = sirenOn and snd.Name == ("Siren" .. tone)
				if want and not snd.IsPlaying then
					snd:Play()
				elseif not want and snd.IsPlaying then
					snd:Stop()
				end
			end
		end
		local hornAt = model:GetAttribute("HornAt")
		if hornAt and lastHorn[model] ~= hornAt then
			lastHorn[model] = hornAt
			local h = chassis:FindFirstChild("Horn")
			if h then
				-- Asset ist ein sehr kurzer Ton: als Schleife ~0.7 s spielen, damit die Hupe hoerbar ist
				h.Looped = true
				h:Play()
				task.delay(0.7, function()
					if lastHorn[model] == hornAt then
						h:Stop()
					end
				end)
			end
		end
	end
	-- Warnblinker (langsamer Takt)
	local hazardOn = model:GetAttribute("Hazard") and (phase % 4 < 2)
	for _, p in ipairs(body:GetChildren()) do
		if p.Name == "Indicator" then
			p.Transparency = hazardOn and 0 or 0.75
		end
	end
	-- Scheinwerfer
	local lightsOn = model:GetAttribute("Headlights") == true
	for _, p in ipairs(body:GetChildren()) do
		if p.Name == "Headlight" then
			local spot = p:FindFirstChildOfClass("SpotLight")
			if spot then
				spot.Enabled = lightsOn
			end
			p.Transparency = lightsOn and 0 or 0.35
		end
	end
end

while true do
	task.wait(0.18)
	phase += 1
	for _, model in ipairs(CollectionService:GetTagged("Vehicle")) do
		if model:IsDescendantOf(workspace) then
			update(model)
		end
	end
end
