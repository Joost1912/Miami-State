-- CharacterService: Charaktererstellung und Aussehen.
-- Ueber Spielerkoepfen wird KEIN Text angezeigt (Prompt 08): keine Namen, Berufe, Raenge oder Fraktionen.
-- Name/Beruf sind nur in Menues sichtbar (Smartphone, Profil, Fraktionsmenues).
-- Namen werden validiert und ueber den Roblox-Textfilter geprueft (Pflicht fuer sichtbare Spielertexte).
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local CharacterService = {}
local DataService

-- Hauttoene (Index wird gespeichert)
CharacterService.SkinTones = {
	Color3.fromRGB(255, 224, 196), Color3.fromRGB(241, 194, 160), Color3.fromRGB(224, 172, 128), Color3.fromRGB(198, 142, 98),
	Color3.fromRGB(160, 110, 74), Color3.fromRGB(124, 84, 56), Color3.fromRGB(94, 62, 42), Color3.fromRGB(66, 44, 30),
}
local HEIGHTS = { 0.94, 1.0, 1.06 }
local BUILDS = { 0.92, 1.0, 1.1 }
local GENDERS = { m = true, w = true, d = true }

local function cleanName(s)
	if typeof(s) ~= "string" then
		return nil
	end
	s = s:gsub("^%s+", ""):gsub("%s+$", "")
	if #s < 2 or #s > 16 then
		return nil
	end
	if not s:match("^[%a][%a%-' ]*$") then
		return nil
	end
	return s:sub(1, 1):upper() .. s:sub(2)
end

local function filtered(text, userId)
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, userId):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return nil
	end
	return result
end

-- Keine Kopfanzeigen: Standard-Namensanzeige des Humanoids aus, alte/neue BillboardGuis am Charakter entfernen.
local guarded = setmetatable({}, { __mode = "k" })
local function hideOverhead(char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.NameDisplayDistance = 0
		hum.HealthDisplayDistance = 0
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.DisplayName = ""
	end
	if not char or guarded[char] then
		return
	end
	guarded[char] = true
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	-- Schutz: auch spaeter erzeugte Schilder (alte Skripte, Ausruestung) sofort entfernen
	char.DescendantAdded:Connect(function(d)
		if d:IsA("BillboardGui") then
			task.defer(function()
				if d.Parent then
					d:Destroy()
				end
			end)
		end
	end)
end
CharacterService.HideOverhead = hideOverhead

-- frueher: Namensschild. Bleibt als leere Funktion, damit bestehende Aufrufe nichts anzeigen.
function CharacterService.UpdateTag(player)
	hideOverhead(player.Character)
end

local function applyAppearance(player)
	local d = DataService.Get(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not d or not hum or not d.Character.Created then
		return
	end
	local a = d.Character.Appearance
	local ok, desc = pcall(function()
		return hum:GetAppliedDescription()
	end)
	if not ok or not desc then
		return
	end
	local skin = CharacterService.SkinTones[a.Skin] or CharacterService.SkinTones[1]
	desc.HeadColor, desc.TorsoColor = skin, skin
	desc.LeftArmColor, desc.RightArmColor, desc.LeftLegColor, desc.RightLegColor = skin, skin, skin, skin
	desc.HeightScale = HEIGHTS[a.Height] or 1
	desc.WidthScale = BUILDS[a.Build] or 1
	desc.DepthScale = BUILDS[a.Build] or 1
	pcall(function()
		hum:ApplyDescription(desc)
	end)
end

-- Eigenen Roblox-Avatar neu laden (z.B. nach "eigene Kleidung" im Kleidungsgeschaeft), dann Hautton/Masse anwenden
function CharacterService.ApplyBase(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or player.UserId <= 0 then
		return
	end
	local ok, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(player.UserId)
	end)
	if ok and desc then
		pcall(function()
			hum:ApplyDescription(desc)
		end)
	end
	applyAppearance(player)
end

local function onCharacter(player)
	hideOverhead(player.Character)
	task.wait(0.5)
	applyAppearance(player)
	hideOverhead(player.Character)
	-- Kleidung (Kleidungsgeschaeft) nach dem Grundaussehen anlegen
	if CharacterService.AfterAppearance then
		pcall(CharacterService.AfterAppearance, player)
	end
end

-- payload: { FirstName, LastName, Gender, BirthYear, Skin, Height, Build }
function CharacterService.Create(player, payload)
	if typeof(payload) ~= "table" then
		return false, "Ungueltige Daten"
	end
	local d = DataService.Get(player)
	if not d then
		return false, "Profil nicht geladen"
	end
	if d.Character.Created then
		return false, "Charakter existiert bereits"
	end
	local first, last = cleanName(payload.FirstName), cleanName(payload.LastName)
	if not first or not last then
		return false, "Namen: 2-16 Buchstaben, nur Buchstaben, Leerzeichen, - und '"
	end
	local gender = payload.Gender
	if typeof(gender) ~= "string" or not GENDERS[gender] then
		return false, "Bitte Geschlecht waehlen"
	end
	local by = payload.BirthYear
	if typeof(by) ~= "number" or by % 1 ~= 0 or by < 1940 or by > 2008 then
		return false, "Geburtsjahr 1940-2008"
	end
	local skin, height, build = payload.Skin, payload.Height, payload.Build
	local function idx(v, max)
		return typeof(v) == "number" and v % 1 == 0 and v >= 1 and v <= max
	end
	if not idx(skin, #CharacterService.SkinTones) or not idx(height, 3) or not idx(build, 3) then
		return false, "Ungueltiges Aussehen"
	end
	local f1, f2 = filtered(first, player.UserId), filtered(last, player.UserId)
	if not f1 or not f2 then
		return false, "Namenspruefung nicht erreichbar, bitte erneut versuchen"
	end
	if f1 ~= first or f2 ~= last then
		return false, "Dieser Name ist nicht erlaubt"
	end
	local ok, err = DataService.Mutate(player, "CharacterCreate", function(data)
		if data.Character.Created then
			return false, "Charakter existiert bereits"
		end
		data.Character = {
			Created = true, FirstName = first, LastName = last, Gender = gender, BirthYear = by,
			Appearance = { Skin = skin, Height = height, Build = build }, CreatedAt = os.time(),
		}
	end)
	if ok then
		task.spawn(onCharacter, player)
		print(string.format("[Character] %s hat Charakter %s %s erstellt", player.Name, first, last))
	end
	return ok, ok and ("Willkommen in Miami State, " .. first .. "!") or err
end

function CharacterService.Init(services)
	DataService = services.DataService
end

function CharacterService.Start()
	local function hook(player)
		player.CharacterAdded:Connect(function(char)
			hideOverhead(char)
			if DataService.Get(player) then
				onCharacter(player)
			end
		end)
		if player.Character then
			hideOverhead(player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	DataService.ProfileLoaded:Connect(function(player)
		if player.Character then
			task.spawn(onCharacter, player)
		end
	end)
	DataService.Changed:Connect(function(player, _, reason)
		if reason == "SetJob" or reason == "Duty" or reason == "Resign" then
			CharacterService.UpdateTag(player)
		end
	end)
end

return CharacterService
