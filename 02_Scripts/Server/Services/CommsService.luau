-- CommsService (Prompt 12): Telefonnummern, Nachrichten, Anrufe - verbunden mit dem bestehenden Smartphone
-- (Kontakte bleiben im PhoneService/Profil Phone.Contacts).
-- Nachrichten: nur serverseitig erzeugt (Absender = echter Spieler), Laenge/Spam-Limit, Roblox-Textfilter
--   (TextService, Kontext PrivateChat). Gespeichert wird ausschliesslich die gefilterte Fassung, je Chat max. 50.
--   Zustellung an Spieler auf demselben Server (Profile anderer Server sind gesperrt - keine Offline-Post).
-- Anrufe: Klingeln (25 s), Annehmen, Ablehnen, Auflegen, Besetzt, verpasste Anrufe, Anrufverlauf.
--   Sprache: echte Verbindung nur ueber die Roblox Audio API (VoiceChatService.UseAudioApi aktiviert und
--   AudioDeviceInput je Spieler vorhanden) - sonst Anruf ohne Sprache (Status/Benachrichtigungen funktionieren).
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")

local C = {}
local S
local calls = {} -- [id] = { Id, From, To, State, Started, Wires = {} }
local inCall = {} -- [player] = id
local sendLog = {} -- [player] = { os.clock(), ... }
local MAX_LEN = 200
local MAX_MSGS = 50
local MAX_CHATS = 30
local RING_SECONDS = 25

function C.Init(services)
	S = services
end

local function rpName(player)
	local d = S.DataService.Get(player)
	return d and d.Character.Created and (d.Character.FirstName .. " " .. d.Character.LastName) or player.Name
end

-- Telefonnummer: dauerhaft aus der UserId abgeleitet (305 = Miami), im Profil gespeichert
local function numberFor(userId)
	local h = (math.abs(userId) * 2654435761) % 10000000
	return string.format("305-%03d-%04d", math.floor(h / 10000), h % 10000)
end
function C.NumberOf(player)
	local d = S.DataService.Get(player)
	return d and d.Phone.Number or numberFor(player.UserId)
end

local function byNumber(num)
	if typeof(num) ~= "string" then
		return nil
	end
	num = num:gsub("[^%d]", "")
	for _, p in ipairs(Players:GetPlayers()) do
		if C.NumberOf(p):gsub("[^%d]", "") == num then
			return p
		end
	end
	return nil
end

local function target(p)
	if typeof(p.To) == "number" then
		return Players:GetPlayerByUserId(p.To)
	end
	return byNumber(p.Number)
end

-- Chat im Profil anlegen/aktualisieren (Aufrufer: Mutate)
local function chatOf(d, other, otherName, otherNumber)
	d.Phone.Chats = d.Phone.Chats or {}
	local key = tostring(other)
	local c = d.Phone.Chats[key]
	if not c then
		local n = 0
		local oldestKey, oldestT
		for k, x in pairs(d.Phone.Chats) do
			n += 1
			if not oldestT or (x.Last or 0) < oldestT then
				oldestKey, oldestT = k, x.Last or 0
			end
		end
		if n >= MAX_CHATS and oldestKey then
			d.Phone.Chats[oldestKey] = nil
		end
		c = { Name = otherName, Number = otherNumber, Muted = false, Unread = 0, Msgs = {}, Last = 0 }
		d.Phone.Chats[key] = c
	end
	c.Name, c.Number = otherName or c.Name, otherNumber or c.Number
	return c
end

local function pushMsg(c, msg)
	table.insert(c.Msgs, msg)
	while #c.Msgs > MAX_MSGS do
		table.remove(c.Msgs, 1)
	end
	c.Last = msg.T
end

function C.Send(player, p)
	local to = target(p)
	if not to then
		return false, "Empfaenger nicht erreichbar (nicht in dieser Stadt)"
	end
	if to == player then
		return false, "Ungueltiger Empfaenger"
	end
	local text = p.Text
	if typeof(text) ~= "string" then
		return false, "Ungueltig"
	end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if #text == 0 or #text > MAX_LEN then
		return false, "Nachricht 1-" .. MAX_LEN .. " Zeichen"
	end
	-- Spam: max. 5 Nachrichten in 10 Sekunden
	local log = sendLog[player] or {}
	sendLog[player] = log
	local now = os.clock()
	while log[1] and now - log[1] > 10 do
		table.remove(log, 1)
	end
	if #log >= 5 then
		return false, "Zu viele Nachrichten - kurz warten"
	end
	table.insert(log, now)
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PrivateChat)
	end)
	if not ok then
		return false, "Nachricht konnte nicht geprueft werden - spaeter erneut"
	end
	local okTo, forTo = pcall(function()
		return result:GetChatForUserAsync(to.UserId)
	end)
	local okMe, forMe = pcall(function()
		return result:GetChatForUserAsync(player.UserId)
	end)
	if not (okTo and okMe) then
		return false, "Nachricht konnte nicht zugestellt werden"
	end
	local t = os.time()
	local myName, toName = rpName(player), rpName(to)
	S.DataService.Mutate(player, "MsgOut", function(d)
		local c = chatOf(d, to.UserId, toName, C.NumberOf(to))
		pushMsg(c, { T = t, Me = true, X = forMe })
	end)
	local muted
	S.DataService.Mutate(to, "MsgIn", function(d)
		local c = chatOf(d, player.UserId, myName, C.NumberOf(player))
		pushMsg(c, { T = t, Me = false, X = forTo })
		c.Unread = (c.Unread or 0) + 1
		muted = c.Muted
	end)
	S.Push(to, "Message", { From = player.UserId, Name = myName, Text = forTo, T = t, Muted = muted })
	return true, nil, { T = t, Text = forMe }
end

function C.Chats(player)
	local d = S.DataService.Get(player)
	local out = {}
	for k, c in pairs(d.Phone.Chats or {}) do
		local last = c.Msgs[#c.Msgs]
		local p = Players:GetPlayerByUserId(tonumber(k))
		table.insert(out, { With = tonumber(k), Name = c.Name, Number = c.Number, Unread = c.Unread or 0, Muted = c.Muted, Last = c.Last, Preview = last and last.X or "", Online = p ~= nil })
	end
	table.sort(out, function(a, b)
		return (a.Last or 0) > (b.Last or 0)
	end)
	return true, nil, { Chats = out, Number = C.NumberOf(player) }
end

function C.Open(player, with)
	local d = S.DataService.Get(player)
	local c = d.Phone.Chats and d.Phone.Chats[tostring(with)]
	if not c then
		local other = Players:GetPlayerByUserId(typeof(with) == "number" and with or 0)
		if not other then
			return false, "Chat nicht gefunden"
		end
		return true, nil, { With = with, Name = rpName(other), Number = C.NumberOf(other), Msgs = {}, Online = true }
	end
	if (c.Unread or 0) > 0 then
		S.DataService.Mutate(player, "MsgRead", function(data)
			data.Phone.Chats[tostring(with)].Unread = 0
		end)
	end
	return true, nil, { With = with, Name = c.Name, Number = c.Number, Msgs = c.Msgs, Muted = c.Muted, Online = Players:GetPlayerByUserId(with) ~= nil }
end

function C.ChatAdmin(player, with, action)
	local key = tostring(with)
	local ok = S.DataService.Mutate(player, "ChatAdmin", function(d)
		local c = d.Phone.Chats and d.Phone.Chats[key]
		if not c then
			return false, "Chat nicht gefunden"
		end
		if action == "Delete" then
			d.Phone.Chats[key] = nil
		elseif action == "Mute" then
			c.Muted = not c.Muted
		end
	end)
	return ok, ok and (action == "Delete" and "Chat geloescht" or "Stummschaltung geaendert") or "Chat nicht gefunden"
end

-- Anrufe -----------------------------------------------------------------------------------------------
local function logCall(player, other, dir, dur)
	S.DataService.Mutate(player, "CallLog", function(d)
		d.Phone.Calls = d.Phone.Calls or {}
		table.insert(d.Phone.Calls, 1, { T = os.time(), With = other.UserId, Name = rpName(other), Number = C.NumberOf(other), Dir = dir, Dur = dur or 0 })
		while #d.Phone.Calls > 30 do
			table.remove(d.Phone.Calls)
		end
	end)
end

local function audioAvailable()
	local ok, enabled = pcall(function()
		return game:GetService("VoiceChatService").UseAudioApi == Enum.AudioApiRollout.Enabled
	end)
	return ok and enabled
end

-- Sprachverbindung ueber die Audio API: Mikrofon des einen -> Ausgabe nur beim anderen
local function connectVoice(call)
	if not audioAvailable() then
		return false
	end
	local function route(fromP, toP)
		local input = fromP:FindFirstChildOfClass("AudioDeviceInput")
		if not input then
			return nil
		end
		local out = Instance.new("AudioDeviceOutput")
		out.Name = "PhoneCall_" .. call.Id
		out.Player = toP
		out.Parent = toP
		local w = Instance.new("Wire")
		w.SourceInstance = input
		w.TargetInstance = out
		w.Parent = out
		return out
	end
	local a = route(call.From, call.To)
	local b = route(call.To, call.From)
	if a then
		table.insert(call.Wires, a)
	end
	if b then
		table.insert(call.Wires, b)
	end
	return a ~= nil and b ~= nil
end

local function endCall(id, reason)
	local call = calls[id]
	if not call then
		return
	end
	calls[id] = nil
	for _, w in ipairs(call.Wires) do
		w:Destroy()
	end
	local dur = call.State == "Active" and (os.time() - call.Started) or 0
	for _, p in ipairs({ call.From, call.To }) do
		if inCall[p] == id then
			inCall[p] = nil
		end
		if p.Parent then
			p:SetAttribute("InCall", nil)
			S.Push(p, "CallState", { Id = id, State = "Ended", Reason = reason, Duration = dur })
		end
	end
	if call.State == "Active" then
		if call.From.Parent then
			logCall(call.From, call.To, "Out", dur)
		end
		if call.To.Parent then
			logCall(call.To, call.From, "In", dur)
		end
	elseif call.State == "Ringing" then
		if call.From.Parent then
			logCall(call.From, call.To, "Out", 0)
		end
		if call.To.Parent then
			logCall(call.To, call.From, "Missed", 0)
			if reason == "Timeout" or reason == "Cancel" then
				S.Push(call.To, "Notify", { Text = "📞 Verpasster Anruf von " .. rpName(call.From), Kind = "warning" })
			end
		end
	end
end

function C.Call(player, p)
	local to = target(p)
	if not to or to == player then
		return false, "Teilnehmer nicht erreichbar"
	end
	if S.InventoryService.Count(player, "Phone") < 1 then
		return false, "Kein Smartphone"
	end
	if inCall[player] then
		return false, "Du telefonierst bereits"
	end
	if inCall[to] then
		logCall(to, player, "Missed", 0)
		return false, rpName(to) .. " ist besetzt"
	end
	if S.InventoryService.Count(to, "Phone") < 1 then
		return false, "Teilnehmer nicht erreichbar"
	end
	local id = HttpService:GenerateGUID(false)
	local call = { Id = id, From = player, To = to, State = "Ringing", Started = os.time(), Wires = {} }
	calls[id] = call
	inCall[player], inCall[to] = id, id
	S.Push(to, "CallIncoming", { Id = id, From = player.UserId, Name = rpName(player), Number = C.NumberOf(player) })
	S.Push(player, "CallState", { Id = id, State = "Ringing", Name = rpName(to), Number = C.NumberOf(to) })
	task.delay(RING_SECONDS, function()
		local c = calls[id]
		if c and c.State == "Ringing" then
			endCall(id, "Timeout")
		end
	end)
	return true, nil, { Id = id }
end

function C.Answer(player, id, accept)
	local call = calls[id]
	if not call or call.To ~= player or call.State ~= "Ringing" then
		return false, "Kein eingehender Anruf"
	end
	if not accept then
		endCall(id, "Declined")
		return true, "Anruf abgelehnt"
	end
	call.State = "Active"
	call.Started = os.time()
	local voice = connectVoice(call)
	for _, p in ipairs({ call.From, call.To }) do
		p:SetAttribute("InCall", id)
		S.Push(p, "CallState", { Id = id, State = "Active", Name = rpName(p == call.From and call.To or call.From), Voice = voice, Started = call.Started })
	end
	return true
end

function C.Hangup(player)
	local id = inCall[player]
	if not id then
		return false, "Kein Anruf"
	end
	local call = calls[id]
	endCall(id, call and call.State == "Ringing" and (call.From == player and "Cancel" or "Declined") or "Hangup")
	return true
end

function C.CallLog(player)
	local d = S.DataService.Get(player)
	local contacts = {}
	for _, c in ipairs(d.Phone.Contacts) do
		local p = Players:GetPlayerByUserId(c.UserId)
		table.insert(contacts, { UserId = c.UserId, Name = c.Name, Favorite = c.Favorite == true, Online = p ~= nil, Number = p and C.NumberOf(p) or c.Number or "-" })
	end
	table.sort(contacts, function(a, b)
		if a.Favorite ~= b.Favorite then
			return a.Favorite
		end
		return a.Name < b.Name
	end)
	return true, nil, { Number = C.NumberOf(player), Calls = d.Phone.Calls or {}, Contacts = contacts, Voice = audioAvailable() }
end

function C.Favorite(player, userId)
	local ok = S.DataService.Mutate(player, "Favorite", function(d)
		for _, c in ipairs(d.Phone.Contacts) do
			if c.UserId == userId then
				c.Favorite = not c.Favorite
				return
			end
		end
		return false, "Kontakt nicht gefunden"
	end)
	return ok, ok and "Favoriten aktualisiert" or "Kontakt nicht gefunden"
end

local function tbl(p)
	return typeof(p) == "table" and p or {}
end
C.Actions = {
	["Comms.Send"] = function(player, p)
		return C.Send(player, tbl(p))
	end,
	["Comms.Chats"] = function(player)
		return C.Chats(player)
	end,
	["Comms.Open"] = function(player, p)
		return C.Open(player, tbl(p).With)
	end,
	["Comms.Delete"] = function(player, p)
		return C.ChatAdmin(player, tbl(p).With, "Delete")
	end,
	["Comms.Mute"] = function(player, p)
		return C.ChatAdmin(player, tbl(p).With, "Mute")
	end,
	["Comms.Call"] = function(player, p)
		return C.Call(player, tbl(p))
	end,
	["Comms.Answer"] = function(player, p)
		return C.Answer(player, tbl(p).Id, tbl(p).Accept == true)
	end,
	["Comms.Hangup"] = function(player)
		return C.Hangup(player)
	end,
	["Comms.Log"] = function(player)
		return C.CallLog(player)
	end,
	["Comms.Favorite"] = function(player, p)
		return C.Favorite(player, tbl(p).UserId)
	end,
	["Comms.Lookup"] = function(player, p)
		local o = byNumber(tbl(p).Number)
		if not o then
			return false, "Nummer nicht vergeben oder nicht in dieser Stadt"
		end
		return true, nil, { UserId = o.UserId, Name = rpName(o) }
	end,
}

local function ensureNumber(player, data)
	if not data then
		return
	end
	if not data.Phone.Number or data.Phone.Number == "" then
		S.DataService.Mutate(player, "PhoneNumber", function(d)
			d.Phone.Number = numberFor(player.UserId)
		end)
	end
	player:SetAttribute("PhoneNumber", S.DataService.Get(player).Phone.Number)
end

function C.Start()
	S.DataService.ProfileLoaded:Connect(ensureNumber)
	-- Spieler, deren Profil vor dem Start dieses Dienstes geladen wurde
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(ensureNumber, p, S.DataService.Get(p))
	end
	Players.PlayerRemoving:Connect(function(player)
		if inCall[player] then
			endCall(inCall[player], "Offline")
		end
		sendLog[player] = nil
	end)
end

return C
