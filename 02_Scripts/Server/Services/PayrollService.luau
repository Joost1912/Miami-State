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

function PayrollService.PayOnce()
	local paid = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local d = DataService.Get(player)
		if d and d.Character.Created then
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
