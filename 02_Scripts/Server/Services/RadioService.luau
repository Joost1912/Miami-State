-- RadioService: Text-Funk mit Kanaelen, Rufzeichen, Status, Panikknopf.
-- Zugriff je Kanal ueber Fraktion + Mindestrang (Config.Police.Channels), nur im Dienst.
-- Hinweis: Sprachfunk (Voice) kann spaeter ueber die Roblox-Audio-API ergaenzt werden; Logik/Berechtigungen bleiben gleich.
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local PoliceCfg = require(Shared.Config.Police)

local RadioService = {}
local S
local current = {} -- [Player] = channelId
local history = {} -- [channelId] = { msg, ... }
local lastSend = {}
local HISTORY = 30

function RadioService.Init(services)
	S = services
end

local function channel(id)
	for _, c in ipairs(PoliceCfg.Channels) do
		if c.Id == id then
			return c
		end
	end
	return nil
end

function RadioService.CanUse(player, id)
	local ch = channel(id)
	local d = S.DataService.Get(player)
	if not ch or not d or not d.Job.OnDuty then
		return false
	end
	return table.find(ch.Factions, d.Job.Faction) ~= nil and d.Job.Rank >= ch.MinRank
end

function RadioService.Allowed(player)
	local list = {}
	for _, c in ipairs(PoliceCfg.Channels) do
		if RadioService.CanUse(player, c.Id) then
			table.insert(list, { Id = c.Id, Name = c.Name })
		end
	end
	return list
end

local function callsign(player)
	return player:GetAttribute("Callsign") or player.Name
end

local function deliver(chId, msg)
	history[chId] = history[chId] or {}
	table.insert(history[chId], msg)
	if #history[chId] > HISTORY then
		table.remove(history[chId], 1)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if RadioService.CanUse(p, chId) and (current[p] == chId or chId == "DISP" or msg.Kind == "panic") then
			S.Push(p, "Radio", msg)
		end
	end
end

function RadioService.Join(player, id)
	if not RadioService.CanUse(player, id) then
		return false, "Kein Zugriff auf diesen Kanal"
	end
	current[player] = id
	return true, "Kanal " .. channel(id).Name
end

function RadioService.Send(player, text)
	local ch = current[player]
	if not ch or not RadioService.CanUse(player, ch) then
		return false, "Kein Funkkanal aktiv (Dienst antreten)"
	end
	if typeof(text) ~= "string" or #text < 1 or #text > 120 then
		return false, "Nachricht: 1-120 Zeichen"
	end
	if lastSend[player] and os.clock() - lastSend[player] < 1.2 then
		return false, "Funk: bitte kurz warten"
	end
	lastSend[player] = os.clock()
	local ok, filtered = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return false, "Funk gestoert - erneut versuchen"
	end
	deliver(ch, { Ch = ch, From = callsign(player), Name = S.PoliceService.RpName(player), Text = filtered, T = os.time(), Kind = "msg" })
	S.Log("Radio", player, nil, ch .. ": " .. filtered)
	return true
end

-- Systemmeldung (Leitstelle)
function RadioService.Broadcast(chId, text, kind)
	deliver(chId, { Ch = chId, From = "DISPATCH", Name = "Leitstelle", Text = text, T = os.time(), Kind = kind or "dispatch" })
end

function RadioService.Panic(player)
	local d = S.DataService.Get(player)
	local faction = d and d.Job.OnDuty and d.Job.Faction
	if faction ~= "Police" and faction ~= "Fire" and faction ~= "EMS" then
		return false, "Nur im Dienst einer Einsatzfraktion"
	end
	if lastSend[player] and os.clock() - lastSend[player] < 3 then
		return false, "Bitte kurz warten"
	end
	lastSend[player] = os.clock()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local pos = root and root.Position or Vector3.zero
	local call = S.DispatchService.CreateSystemCall("Panic", pos, "10-99 " .. callsign(player) .. " benoetigt dringend Unterstuetzung", 1, faction == "Police" and { "Police" } or { "Police", faction })
	deliver("DISP", { Ch = "DISP", From = callsign(player), Name = S.PoliceService.RpName(player), Text = "10-99 PANIK - Einsatzkraft braucht sofort Hilfe! Einsatz #" .. call.Id, T = os.time(), Kind = "panic" })
	S.Log("Panic", player, nil, "10-99 ausgeloest")
	return true, "Panikalarm gesendet"
end

function RadioService.State(player)
	local ch = current[player]
	if ch and not RadioService.CanUse(player, ch) then
		ch = nil
	end
	local h = {}
	for _, id in ipairs({ ch, "DISP" }) do
		for _, m in ipairs(history[id or ""] or {}) do
			table.insert(h, m)
		end
	end
	table.sort(h, function(a, b)
		return a.T < b.T
	end)
	return {
		Channel = ch, Channels = RadioService.Allowed(player), History = h, Status = player:GetAttribute("UnitStatus"),
		Callsign = player:GetAttribute("Callsign"), Officers = S.PoliceService.Roster(),
	}
end

function RadioService.Start()
	Players.PlayerRemoving:Connect(function(p)
		current[p], lastSend[p] = nil, nil
	end)
end

return RadioService
