-- SocialService (Prompt 12): Spieler-zu-Spieler-Interaktionen fuer das Interaktionsmenue (Taste X).
-- Gesten (Begruessen, Hilfe rufen) wirken sofort; Hand schuetteln, Geld anfordern und Kontakte tauschen sind
-- Anfragen, die der andere Spieler annehmen oder ablehnen muss. Alles serverseitig mit Abstands- und Spam-Pruefung.
-- Geld geben bleibt im bestehenden "Cash.Give" (Main), Einladungen in Wohnungen im PropertyService.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local SO = {}
local S
local requests = {} -- [target] = { [id] = { Kind, From, Amount, Until } }
local last = {} -- [player] = os.clock()
local RANGE = 14

function SO.Init(services)
	S = services
end

local function rpName(player)
	local d = S.DataService.Get(player)
	return d and d.Character.Created and (d.Character.FirstName .. " " .. d.Character.LastName) or player.Name
end

local function near(a, b, range)
	local ra = a.Character and a.Character:FindFirstChild("HumanoidRootPart")
	local rb = b.Character and b.Character:FindFirstChild("HumanoidRootPart")
	return ra and rb and (ra.Position - rb.Position).Magnitude <= (range or RANGE)
end

local function check(player, p)
	local target = typeof(p.Target) == "number" and Players:GetPlayerByUserId(p.Target)
	if not target or target == player or not S.DataService.Get(target) then
		return nil, "Spieler nicht gefunden"
	end
	if not near(player, target) then
		return nil, "Zu weit entfernt"
	end
	if last[player] and os.clock() - last[player] < 3 then
		return nil, "Bitte kurz warten"
	end
	last[player] = os.clock()
	return target
end

local function face(a, b)
	local ra = a.Character and a.Character:FindFirstChild("HumanoidRootPart")
	local rb = b.Character and b.Character:FindFirstChild("HumanoidRootPart")
	if ra and rb then
		ra.CFrame = CFrame.lookAt(ra.Position, Vector3.new(rb.Position.X, ra.Position.Y, rb.Position.Z))
	end
end

function SO.Gesture(player, p)
	local target, err = check(player, p)
	if not target then
		return false, err
	end
	local kind = p.Kind
	if kind == "Wave" then
		face(player, target)
		S.Push(player, "Activity", { Kind = "Emote", Emote = "wave" })
		S.Push(target, "Notify", { Text = "👋 " .. rpName(player) .. " gruesst dich", Kind = "info" })
		return true, "Du gruesst " .. rpName(target)
	elseif kind == "Help" then
		S.Push(target, "Notify", { Text = "🙋 " .. rpName(player) .. " bittet dich um Hilfe", Kind = "warning" })
		return true, "Du bittest " .. rpName(target) .. " um Hilfe"
	elseif kind == "Talk" then
		face(player, target)
		S.Push(target, "Notify", { Text = "💬 " .. rpName(player) .. " spricht dich an", Kind = "info" })
		return true, "Du sprichst " .. rpName(target) .. " an"
	end
	return false, "Unbekannte Geste"
end

function SO.Request(player, p)
	local target, err = check(player, p)
	if not target then
		return false, err
	end
	local kind = p.Kind
	local amount
	if kind == "Money" then
		amount = p.Amount
		if not S.EconomyService.ValidAmount(amount) or amount > 50000 then
			return false, "Betrag $1 - $50.000"
		end
	elseif kind ~= "Handshake" and kind ~= "Contacts" then
		return false, "Unbekannte Anfrage"
	end
	requests[target] = requests[target] or {}
	local n = 0
	for _ in pairs(requests[target]) do
		n += 1
	end
	if n >= 5 then
		return false, rpName(target) .. " hat zu viele offene Anfragen"
	end
	local id = HttpService:GenerateGUID(false)
	requests[target][id] = { Kind = kind, From = player, Amount = amount, Until = os.clock() + 45 }
	local text = (kind == "Handshake" and (rpName(player) .. " moechte dir die Hand schuetteln"))
		or (kind == "Contacts" and (rpName(player) .. " moechte Kontaktdaten austauschen"))
		or string.format("%s fordert %s von dir (bar)", rpName(player), S.Format.money(amount))
	S.Push(target, "SocialRequest", { Id = id, Kind = kind, Text = text, Amount = amount })
	return true, "Anfrage an " .. rpName(target) .. " gesendet"
end

function SO.Respond(player, p)
	local list = requests[player]
	local r = list and list[p.Id]
	if not r then
		return false, "Anfrage nicht gefunden"
	end
	list[p.Id] = nil
	local from = r.From
	if os.clock() > r.Until or not from.Parent then
		return false, "Anfrage abgelaufen"
	end
	if p.Accept ~= true then
		S.Push(from, "Notify", { Text = rpName(player) .. " hat abgelehnt", Kind = "warning" })
		return true, "Abgelehnt"
	end
	if not near(player, from, RANGE + 6) then
		return false, "Zu weit entfernt"
	end
	if r.Kind == "Handshake" then
		face(player, from)
		face(from, player)
		for _, x in ipairs({ player, from }) do
			S.Push(x, "Activity", { Kind = "Emote", Emote = "point" })
		end
		S.Push(from, "Notify", { Text = "🤝 Ihr schuettelt euch die Hand", Kind = "success" })
		return true, "🤝 Ihr schuettelt euch die Hand"
	elseif r.Kind == "Contacts" then
		S.PhoneService.AddContact(player, from.UserId)
		S.PhoneService.AddContact(from, player.UserId)
		S.Push(from, "Notify", { Text = "Kontakt mit " .. rpName(player) .. " ausgetauscht", Kind = "success" })
		return true, "Kontakt mit " .. rpName(from) .. " ausgetauscht"
	elseif r.Kind == "Money" then
		local ok, err = S.EconomyService.Transfer(player, from, "Cash", r.Amount, nil, "Angefordert")
		if not ok then
			return false, err
		end
		S.Push(from, "Notify", { Text = string.format("%s hat dir %s gegeben", rpName(player), S.Format.money(r.Amount)), Kind = "success" })
		return true, S.Format.money(r.Amount) .. " an " .. rpName(from) .. " gegeben"
	end
	return false, "Unbekannt"
end

local function tbl(p)
	return typeof(p) == "table" and p or {}
end
SO.Actions = {
	["Social.Gesture"] = function(player, p)
		return SO.Gesture(player, tbl(p))
	end,
	["Social.Request"] = function(player, p)
		return SO.Request(player, tbl(p))
	end,
	["Social.Respond"] = function(player, p)
		return SO.Respond(player, tbl(p))
	end,
}

function SO.Start()
	Players.PlayerRemoving:Connect(function(p)
		requests[p], last[p] = nil, nil
	end)
end

return SO
