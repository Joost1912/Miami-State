-- WantedService (Prompt 09): Fahndungsstufen 0-3 - ausschliesslich serverseitig.
-- * Record.WantedLevel / Record.WantedUntil im Profil (gespeichert); Record.Wanted (bool) bleibt fuer bestehende Systeme synchron.
-- * Stufe steigt durch Straftaten (CrimeService, MDT-Fahndung, Haftbefehl), sinkt zeitlich (Config.Crime.WantedLevels.Decay)
--   und wird bei Festnahme (JusticeService.Jail) auf 0 gesetzt. Aktiver Haftbefehl haelt mindestens Stufe 1.
-- * Vertraulichkeit: Nur der Spieler selbst bekommt seine Stufe (privater Push), die Polizei sieht alle im MDT.
--   Es werden KEINE oeffentlichen Attribute gesetzt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local Crime = require(Shared.Config.Crime)

local WantedService = {}
local S

function WantedService.Init(services)
	S = services
end

local function decayFor(level)
	local l = Crime.WantedLevels[level]
	return (l and l.Decay or 10) * 60
end

local function hasActiveWarrant(d)
	for _, w in ipairs(d.Record.Warrants) do
		if w.Active then
			return true
		end
	end
	return false
end

function WantedService.Level(player)
	local d = S.DataService.Get(player)
	return d and (d.Record.WantedLevel or 0) or 0
end

-- Privater Status an den Spieler (Crime-HUD)
function WantedService.PushState(player)
	if typeof(player) ~= "Instance" then
		return
	end
	local d = S.DataService.Get(player)
	if not d then
		return
	end
	local lvl = d.Record.WantedLevel or 0
	S.Push(player, "Wanted", {
		Level = lvl, Name = Crime.WantedLevels[lvl].Name, Reason = d.Record.WantedReason,
		Until = (lvl > 0 and d.Record.WantedUntil > 0) and d.Record.WantedUntil or nil,
	})
end

-- Stufe setzen (intern). reason optional, Log ueber S.Log
function WantedService.Set(player, level, reason, actor)
	level = math.clamp(math.floor(level or 0), 0, Crime.MaxWantedLevel)
	local old
	local ok = S.DataService.Mutate(player, "WantedLevel", function(d)
		old = d.Record.WantedLevel or 0
		d.Record.WantedLevel = level
		d.Record.WantedUntil = level > 0 and (os.time() + decayFor(level)) or 0
		d.Record.Wanted = level > 0
		if level > 0 and reason and reason ~= "" then
			d.Record.WantedReason = reason
		elseif level == 0 then
			d.Record.WantedReason = ""
		end
	end)
	if ok then
		WantedService.PushState(player)
		if old ~= level and S.Log then
			S.Log("WantedLevel", actor, player, string.format("%d -> %d %s", old or 0, level, reason or ""))
		end
	end
	return ok
end

-- Stufe mindestens auf level anheben (Straftat). Gleiche Stufe erneuert die Ablaufzeit.
function WantedService.Raise(player, level, reason, actor)
	local cur = WantedService.Level(player)
	return WantedService.Set(player, math.max(cur, level), reason, actor)
end

function WantedService.Clear(player, actor)
	return WantedService.Set(player, 0, nil, actor)
end

-- Liste fuer das MDT (nur Polizei, Pruefung im Aufrufer)
function WantedService.List()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local d = S.DataService.Get(p)
		if d and (d.Record.WantedLevel or 0) > 0 then
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			table.insert(list, {
				UserId = p.UserId, Name = d.Character.FirstName .. " " .. d.Character.LastName, Level = d.Record.WantedLevel,
				LevelName = Crime.WantedLevels[d.Record.WantedLevel].Name, Reason = d.Record.WantedReason,
				Until = d.Record.WantedUntil, Warrant = hasActiveWarrant(d),
				District = root and require(Shared.Config.MapData).DistrictAt(root.Position.X, root.Position.Z) or "unbekannt",
			})
		end
	end
	table.sort(list, function(a, b)
		return a.Level > b.Level
	end)
	return list
end

function WantedService.Start()
	S.DataService.ProfileLoaded:Connect(function(player)
		task.delay(2, WantedService.PushState, player)
	end)
	-- Abklingen: alle 20 s pruefen (Haftbefehl haelt Stufe >= 1, in Haft keine Aenderung)
	task.spawn(function()
		while true do
			task.wait(20)
			local now = os.time()
			for _, p in ipairs(Players:GetPlayers()) do
				local d = S.DataService.Get(p)
				if d and (d.Record.WantedLevel or 0) > 0 and not p:GetAttribute("Jailed") and not (S.CrimeService and S.CrimeService.IsCrew(p)) then
					if d.Record.WantedUntil > 0 and now >= d.Record.WantedUntil then
						local nextLevel = d.Record.WantedLevel - 1
						if nextLevel == 0 and hasActiveWarrant(d) then
							nextLevel = 1
						end
						if nextLevel ~= d.Record.WantedLevel then
							WantedService.Set(p, nextLevel, nil)
							if nextLevel == 0 then
								S.Push(p, "Notify", { Text = "Die Fahndung nach dir wurde eingestellt.", Kind = "success" })
							end
						else
							S.DataService.Mutate(p, "WantedHold", function(dd)
								dd.Record.WantedUntil = now + decayFor(nextLevel)
							end)
						end
					end
				end
			end
		end
	end)
end

return WantedService
