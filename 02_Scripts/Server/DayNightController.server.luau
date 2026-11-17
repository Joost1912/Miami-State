-- DayNightController (Server)
-- Laesst die Uhrzeit laufen und schaltet nachts Strassenlaternen, Flutlicht, beleuchtete Fenster und Fassaden-Akzente ein.
-- Prompt 08: fliessende Lichtstimmung ueber den Tag (goldene Stunde, blaue Stunde, Nacht) per Keyframes.
-- Lighting-Eigenschaften und Part-Aenderungen werden automatisch an alle Clients repliziert.
-- Leistung: Uhrzeit 4x/s, Lichtstimmung alle 2 s (nur kleine Lerp-Rechnung), Teile nur beim Tag/Nacht-Wechsel.
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local MINUTES_PER_DAY = 24 -- Echtzeit-Minuten fuer einen kompletten Spieltag
local START_TIME = 17.0 -- Spielstart kurz vor Sonnenuntergang
local NIGHT_FROM, NIGHT_TO = 18.6, 6.2

local WINDOW_ON = 0.05
local isNight = nil

local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
local rgb = Color3.fromRGB

-- Tageswerte = aktuelle Einstellungen im Place
local DAY = {
	Ambient = Lighting.OutdoorAmbient,
	AtmoColor = atmo and atmo.Color or rgb(220, 200, 190), AtmoDecay = atmo and atmo.Decay or rgb(120, 104, 150),
	Haze = atmo and atmo.Haze or 1, Tint = cc and cc.TintColor or rgb(255, 255, 255), Bloom = bloom and bloom.Intensity or 0.45,
	Exposure = Lighting.ExposureCompensation,
}
-- Keyframes (Uhrzeit -> Stimmung). Zwischenwerte werden linear gemischt.
local KEYS = {
	{ T = 0.0, Ambient = rgb(44, 48, 78), AtmoColor = rgb(96, 104, 150), AtmoDecay = rgb(36, 40, 70), Haze = 1.4, Tint = rgb(214, 222, 255), Bloom = 0.75, Exposure = 0.05 },
	{ T = 5.0, Ambient = rgb(52, 54, 86), AtmoColor = rgb(110, 110, 150), AtmoDecay = rgb(46, 46, 80), Haze = 1.6, Tint = rgb(220, 224, 255), Bloom = 0.7, Exposure = 0.05 },
	{ T = 6.5, Ambient = rgb(150, 122, 130), AtmoColor = rgb(236, 190, 170), AtmoDecay = rgb(150, 110, 130), Haze = 1.8, Tint = rgb(255, 236, 222), Bloom = 0.55, Exposure = 0.1 },
	{ T = 9.0, Ambient = DAY.Ambient, AtmoColor = DAY.AtmoColor, AtmoDecay = DAY.AtmoDecay, Haze = DAY.Haze, Tint = DAY.Tint, Bloom = DAY.Bloom, Exposure = DAY.Exposure },
	{ T = 16.0, Ambient = DAY.Ambient, AtmoColor = DAY.AtmoColor, AtmoDecay = DAY.AtmoDecay, Haze = DAY.Haze, Tint = DAY.Tint, Bloom = DAY.Bloom, Exposure = DAY.Exposure },
	{ T = 17.8, Ambient = rgb(172, 124, 112), AtmoColor = rgb(250, 172, 124), AtmoDecay = rgb(160, 92, 112), Haze = 1.9, Tint = rgb(255, 226, 198), Bloom = 0.7, Exposure = 0.15 },
	{ T = 19.0, Ambient = rgb(110, 92, 120), AtmoColor = rgb(170, 120, 150), AtmoDecay = rgb(90, 70, 120), Haze = 1.7, Tint = rgb(236, 220, 244), Bloom = 0.75, Exposure = 0.1 },
	{ T = 20.3, Ambient = rgb(56, 58, 92), AtmoColor = rgb(104, 108, 156), AtmoDecay = rgb(40, 44, 78), Haze = 1.5, Tint = rgb(214, 222, 255), Bloom = 0.75, Exposure = 0.05 },
	{ T = 24.0, Ambient = rgb(44, 48, 78), AtmoColor = rgb(96, 104, 150), AtmoDecay = rgb(36, 40, 70), Haze = 1.4, Tint = rgb(214, 222, 255), Bloom = 0.75, Exposure = 0.05 },
}

local function lerp(a, b, k)
	if typeof(a) == "Color3" then
		return a:Lerp(b, k)
	end
	return a + (b - a) * k
end

local function applyMood(t)
	local a, b = KEYS[1], KEYS[#KEYS]
	for i = 1, #KEYS - 1 do
		if t >= KEYS[i].T and t <= KEYS[i + 1].T then
			a, b = KEYS[i], KEYS[i + 1]
			break
		end
	end
	local k = (b.T > a.T) and (t - a.T) / (b.T - a.T) or 0
	Lighting.OutdoorAmbient = lerp(a.Ambient, b.Ambient, k)
	Lighting.ExposureCompensation = lerp(a.Exposure, b.Exposure, k)
	if atmo then
		atmo.Color = lerp(a.AtmoColor, b.AtmoColor, k)
		atmo.Decay = lerp(a.AtmoDecay, b.AtmoDecay, k)
		atmo.Haze = lerp(a.Haze, b.Haze, k)
	end
	if cc then
		cc.TintColor = lerp(a.Tint, b.Tint, k)
	end
	if bloom then
		bloom.Intensity = lerp(a.Bloom, b.Bloom, k)
	end
end

local function setNight(night)
	isNight = night
	for _, p in ipairs(CollectionService:GetTagged("NightWindow")) do
		p.Transparency = night and WINDOW_ON or 1
	end
	for _, p in ipairs(CollectionService:GetTagged("StreetLamp")) do
		p.Material = night and Enum.Material.Neon or Enum.Material.SmoothPlastic
		for _, l in ipairs(p:GetChildren()) do
			if l:IsA("Light") then
				l.Enabled = night
			end
		end
	end
	-- Fassaden-Akzente (Hochhauskanten, Clubs): nur nachts leuchtend, Farben dezent
	for _, p in ipairs(CollectionService:GetTagged("NightAccent")) do
		p.Material = night and Enum.Material.Neon or Enum.Material.SmoothPlastic
	end
end

Lighting.ClockTime = START_TIME
-- Prompt 10: spaeter erzeugte Fenster (Wohnungs-Panoramen) sofort an Tag/Nacht anpassen
CollectionService:GetInstanceAddedSignal("NightWindow"):Connect(function(p)
	if isNight ~= nil and p:IsA("BasePart") then
		p.Transparency = isNight and WINDOW_ON or 1
	end
end)
local last = os.clock()
local moodAcc = 99
while true do
	task.wait(0.25)
	local now = os.clock()
	local dt = now - last
	last = now
	local before = Lighting.ClockTime
	Lighting.ClockTime = (Lighting.ClockTime + dt * 24 / (MINUTES_PER_DAY * 60)) % 24
	local t = Lighting.ClockTime
	-- Prompt 10: Wochentag fuer die HUD-Uhr (0 = Montag); Mitternacht -> naechster Tag
	if t < before then
		Lighting:SetAttribute("GameDay", ((Lighting:GetAttribute("GameDay") or 4) + 1) % 7)
	end
	moodAcc += dt
	if moodAcc >= 2 then
		moodAcc = 0
		applyMood(t)
	end
	local night = (t >= NIGHT_FROM) or (t < NIGHT_TO)
	if night ~= isNight then
		setNight(night)
	end
end
