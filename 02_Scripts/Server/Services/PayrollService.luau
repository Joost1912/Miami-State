-- PayrollService: zahlt regelmaessig Gehalt aufs Bankkonto.
-- Hoehe nach Fraktion + Dienstgrad (Config.Factions). Einsatzkraefte nur im Dienst, Zivilisten immer.
-- Zahlungen laufen ueber EconomyService.Credit -> Kontoverlauf + Server-Log.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local Factions = require(Shared.Config.Factions)
local Economy = require(Shared.Config.Economy)

local PayrollService = {}
local DataService, EconomyService, push

function PayrollService.Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	push = services.Push
end

function PayrollService.SalaryFor(data)
	local f = Factions[data.Job.Faction]
	local r = f and f.Ranks[data.Job.Rank]
	if not r then
		return 0
	end
	if f.DutyRequired and not data.Job.OnDuty then
		return 0
	end
	return r.Salary
end

-- Prompt 11: Anti-AFK - Gehalt/Grundsicherung nur bei Aktivitaet im Auszahlungszeitraum
-- (Bewegung von mind. ActiveMoveStuds oder ein abgeschlossener Arbeitsauftrag)
local WorkCfg = require(Shared.Config.Work)
local moved = {} -- [player] = zurueckgelegte Studs seit der letzten Auszahlung
local lastPos = {}
task.spawn(function()
	while true do
		task.wait(15)
		for _, player in ipairs(Players:GetPlayers()) do
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if r then
				if lastPos[player] then
					moved[player] = (moved[player] or 0) + math.min(200, (r.Position - lastPos[player]).Magnitude)
				end
				lastPos[player] = r.Position
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(p)
	moved[p], lastPos[p] = nil, nil
end)
function PayrollService.IsActive(player)
	return (moved[player] or 0) >= WorkCfg.ActiveMoveStuds
end

function PayrollService.PayOnce()
	local paid = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local d = DataService.Get(player)
		local active = PayrollService.IsActive(player) or typeof(player) ~= "Instance"
		moved[player] = 0
		if d and d.Character.Created and not active then
			push(player, "Notify", { Text = "Kein Gehalt: in den letzten 10 Minuten keine Aktivitaet (AFK)", Kind = "warning" })
		end
		if d and d.Character.Created and active then
			local amount = PayrollService.SalaryFor(d)
			if amount > 0 then
				local f = Factions[d.Job.Faction]
				local ok = EconomyService.Credit(player, "Bank", amount, "Gehalt " .. f.Ranks[d.Job.Rank].Name)
				if ok then
					paid += 1
					push(player, "Notify", { Text = string.format("Gehalt erhalten: $%d (%s)", amount, f.Ranks[d.Job.Rank].Name), Kind = "success" })
				end
			end
		end
	end
	return paid
end

function PayrollService.Start()
	task.spawn(function()
		while true do
			task.wait(Economy.PayInterval)
			PayrollService.PayOnce()
		end
	end)
end

return PayrollService
