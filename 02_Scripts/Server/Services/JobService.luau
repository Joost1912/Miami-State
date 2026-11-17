-- JobService: Fraktionen, Dienstgrade, Dienststatus und Berechtigungen.
-- * Zivile Rollen sind frei waehlbar; Polizei/Feuerwehr/EMS werden von Admins oder Fuehrungskraeften
--   mit "Faction.ManageRanks" (nur innerhalb der eigenen Fraktion, nur unterhalb des eigenen Rangs) vergeben.
-- * Spieler koennen eigene Berechtigungen nie direkt setzen - alles laeuft ueber diese Pruefungen.
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local Factions = require(Shared.Config.Factions)

local JobService = {}
local DataService, S

-- Zusaetzliche Admin-UserIds (Projektinhaber ist automatisch Admin)
JobService.Admins = {}

local function isFaction(id)
	return typeof(id) == "string" and table.find(Factions.Order, id) ~= nil
end

function JobService.IsAdmin(player)
	if JobService._forceNonAdmin then
		return false -- nur fuer Sicherheitstests in Studio
	end
	if RunService:IsStudio() then
		return true -- Studio-Tests
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return table.find(JobService.Admins, player.UserId) ~= nil
end

function JobService.Get(player)
	local d = DataService.Get(player)
	if not d then
		return nil
	end
	local f = Factions[d.Job.Faction] or Factions.Civilian
	local rank = f.Ranks[d.Job.Rank] or f.Ranks[1]
	return d.Job.Faction, d.Job.Rank, rank, f
end

function JobService.HasPermission(player, perm)
	local d = DataService.Get(player)
	if not d then
		return false
	end
	local f = Factions[d.Job.Faction]
	if not f then
		return false
	end
	if table.find(f.Permissions, perm) then
		return true
	end
	for minRank, perms in pairs(f.RankPermissions) do
		if d.Job.Rank >= minRank and table.find(perms, perm) then
			return true
		end
	end
	return false
end

function JobService.IsInFaction(player, factionId, requireDuty)
	local d = DataService.Get(player)
	if not d or d.Job.Faction ~= factionId then
		return false
	end
	return not requireDuty or d.Job.OnDuty
end

local function applyTeam(player)
	local d = DataService.Get(player)
	if not d then
		return
	end
	local team = Teams:FindFirstChild(d.Job.Faction)
	if team then
		player.Team = team
	end
end

-- Zivile Rolle frei waehlen
function JobService.SelectCivilianRole(player, rankIndex)
	if typeof(rankIndex) ~= "number" or rankIndex % 1 ~= 0 or not Factions.Civilian.Ranks[rankIndex] then
		return false, "Ungueltige Rolle"
	end
	local ok, err = DataService.Mutate(player, "SelectCivilian", function(d)
		if d.Job.Faction ~= "Civilian" then
			return false, "Verlasse zuerst deine Fraktion"
		end
		d.Job.Rank = rankIndex
	end)
	return ok, ok and ("Neue Rolle: " .. Factions.Civilian.Ranks[rankIndex].Name) or err
end

-- Fraktion verlassen -> Zivilist
function JobService.Resign(player)
	JobService.EndDuty(player)
	local ok, err = DataService.Mutate(player, "Resign", function(d)
		if d.Job.Faction == "Civilian" then
			return false, "Du bist bereits Zivilist"
		end
		d.Job = { Faction = "Civilian", Rank = 1, OnDuty = false }
	end)
	applyTeam(player)
	return ok, ok and "Du hast deine Fraktion verlassen" or err
end

-- Fraktion/Rang setzen (actor = ausfuehrender Spieler)
function JobService.SetJob(actor, target, factionId, rankIndex)
	if typeof(target) ~= "Instance" or not target:IsA("Player") or not target.Parent then
		return false, "Spieler nicht gefunden"
	end
	if not isFaction(factionId) then
		return false, "Unbekannte Fraktion"
	end
	local f = Factions[factionId]
	if typeof(rankIndex) ~= "number" or rankIndex % 1 ~= 0 or not f.Ranks[rankIndex] then
		return false, "Unbekannter Dienstgrad"
	end
	if not JobService.IsAdmin(actor) then
		local aFaction, aRank = JobService.Get(actor)
		local tFaction, tRank = JobService.Get(target)
		if aFaction ~= factionId or actor == target then
			return false, "Keine Berechtigung"
		end
		-- Einstellung (von aussen) braucht Faction.Hire, Befoerderung/Rueckstufung Faction.ManageRanks
		local perm = (tFaction == factionId) and "Faction.ManageRanks" or "Faction.Hire"
		if not JobService.HasPermission(actor, perm) then
			return false, "Keine Berechtigung (" .. perm .. ")"
		end
		if rankIndex >= aRank or (tFaction == factionId and tRank >= aRank) then
			return false, "Nur Raenge unterhalb deines eigenen"
		end
	end
	if JobService.Get(target) ~= factionId then
		JobService.EndDuty(target)
	end
	local ok, err = DataService.Mutate(target, "SetJob", function(d)
		d.Job.Faction = factionId
		d.Job.Rank = rankIndex
		d.Job.OnDuty = false
	end)
	applyTeam(target)
	print(string.format("[Jobs] %s setzt %s auf %s/%s", actor.Name, target.Name, factionId, f.Ranks[rankIndex].Name))
	return ok, ok and string.format("%s ist jetzt %s (%s)", target.Name, f.Ranks[rankIndex].Name, f.Short) or err
end

-- Dienstzeit verbuchen (Attribut DutySince wird beim Dienstantritt gesetzt)
function JobService.EndDuty(player)
	local since = player:GetAttribute("DutySince")
	local d = DataService.Get(player)
	if not d or not d.Job.OnDuty then
		return
	end
	DataService.Mutate(player, "Duty", function(data)
		data.Job.OnDuty = false
		if since and data.FactionData[data.Job.Faction] then
			data.FactionData[data.Job.Faction].DutySeconds += math.max(0, os.time() - since)
		end
	end)
	player:SetAttribute("DutySince", nil)
end

function JobService.SetDuty(player, on)
	if typeof(on) ~= "boolean" then
		return false, "Ungueltig"
	end
	local d = DataService.Get(player)
	local f = d and Factions[d.Job.Faction]
	if not f or d.Job.Faction == "Civilian" then
		return false, "Zivilisten haben keinen Dienststatus"
	end
	if on == d.Job.OnDuty then
		return false, on and "Du bist bereits im Dienst" or "Du bist nicht im Dienst"
	end
	if not on then
		JobService.EndDuty(player)
		return true, "Dienst beendet"
	end
	-- Dienstantritt nur am vorgesehenen Ort (z.B. Dienst-Terminal der Polizeiwache)
	if f.DutyLocation and not S.InteractionService.NearestOfType(player, f.DutyLocation, 20) then
		return false, "Dienstantritt nur am Dienst-Terminal der Wache"
	end
	local ok, err = DataService.Mutate(player, "Duty", function(data)
		data.Job.OnDuty = true
	end)
	if ok then
		player:SetAttribute("DutySince", os.time())
	end
	return ok, ok and "Dienst angetreten" or err
end

-- Entlassung (Faction.Fire, nur niedrigere Raenge der eigenen Fraktion)
function JobService.Dismiss(actor, target)
	if typeof(target) ~= "Instance" or not target:IsA("Player") or not target.Parent or actor == target then
		return false, "Ungueltiges Ziel"
	end
	local aF, aR = JobService.Get(actor)
	local tF, tR = JobService.Get(target)
	if tF == "Civilian" then
		return false, "Spieler gehoert keiner Fraktion an"
	end
	if not JobService.IsAdmin(actor) and (aF ~= tF or not JobService.HasPermission(actor, "Faction.Fire") or tR >= aR) then
		return false, "Keine Berechtigung"
	end
	JobService.EndDuty(target)
	local ok, err = DataService.Mutate(target, "Dismiss", function(d)
		d.Job = { Faction = "Civilian", Rank = 1, OnDuty = false }
	end)
	applyTeam(target)
	print(string.format("[Jobs] %s entlaesst %s aus %s", actor.Name, target.Name, tF))
	return ok, ok and (target.Name .. " wurde entlassen") or err
end

function JobService.Init(services)
	S = services
	DataService = services.DataService
end

function JobService.Start()
	for i, id in ipairs(Factions.Order) do
		local team = Teams:FindFirstChild(id) or Instance.new("Team")
		team.Name = id
		team.TeamColor = BrickColor.new(Factions[id].Color)
		team.AutoAssignable = (id == "Civilian")
		team.Parent = Teams
		local _ = i
	end
	DataService.ProfileLoaded:Connect(function(player)
		applyTeam(player)
	end)
end

return JobService
