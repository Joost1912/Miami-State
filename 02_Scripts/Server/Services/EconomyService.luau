-- EconomyService: Bargeld und Bankkonto - ausschliesslich serverseitig.
-- * Betraege muessen ganze Zahlen > 0 und <= MaxTransaction sein.
-- * Doppelte Transaktionen: Client sendet eine Transaktions-ID; bereits gesehene IDs werden verworfen.
-- * Jede Bewegung landet im Kontoverlauf (Money.History) -> nachvollziehbar.
-- * Profil-Aenderungen laufen ueber DataService.Mutate (ohne Yield, also atomar auf diesem Server).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local Config = require(Shared.Config.Economy)

local EconomyService = {}
local DataService

function EconomyService.Init(services)
	DataService = services.DataService
end

local function validAmount(a)
	return typeof(a) == "number" and a == a and a % 1 == 0 and a > 0 and a <= Config.MaxTransaction
end
EconomyService.ValidAmount = validAmount

-- true, wenn die ID schon verarbeitet wurde (oder ungueltig ist)
local function seenTx(data, txId)
	if txId == nil then
		return false
	end
	if typeof(txId) ~= "string" or #txId < 8 or #txId > 64 then
		return true
	end
	for _, t in ipairs(data.Meta.RecentTx) do
		if t == txId then
			return true
		end
	end
	table.insert(data.Meta.RecentTx, txId)
	if #data.Meta.RecentTx > 60 then
		table.remove(data.Meta.RecentTx, 1)
	end
	return false
end

-- Transaktions-ID fuer andere Services (z.B. Shop) reservieren: false, wenn bereits verwendet/ungueltig
function EconomyService.ClaimTx(player, txId)
	local d = DataService.Get(player)
	if not d then
		return false
	end
	return not seenTx(d, txId)
end

local function record(data, kind, amount, note)
	table.insert(data.Money.History, 1, { T = os.time(), K = kind, A = amount, N = note or "", Cash = data.Money.Cash, Bank = data.Money.Bank })
	while #data.Money.History > Config.HistoryLength do
		table.remove(data.Money.History)
	end
end

local function log(fmt, ...)
	print("[Economy] " .. string.format(fmt, ...))
end

-- Interne Buchungen (Gehalt, Belohnungen, Kaeufe) -------------------------------------------
-- account: "Cash" | "Bank"
function EconomyService.Credit(player, account, amount, reason)
	if not validAmount(amount) or (account ~= "Cash" and account ~= "Bank") then
		return false, "Ungueltiger Betrag"
	end
	return DataService.Mutate(player, "Credit:" .. tostring(reason), function(d)
		if d.Money[account] + amount > Config.MaxBalance then
			return false, "Kontolimit erreicht"
		end
		d.Money[account] += amount
		d.Stats.TotalEarned += amount
		record(d, (account == "Bank") and "Gutschrift Konto" or "Bargeld erhalten", amount, reason)
		log("%s +%d %s (%s)", player.Name, amount, account, tostring(reason))
	end)
end

function EconomyService.Charge(player, account, amount, reason)
	if not validAmount(amount) or (account ~= "Cash" and account ~= "Bank") then
		return false, "Ungueltiger Betrag"
	end
	return DataService.Mutate(player, "Charge:" .. tostring(reason), function(d)
		if d.Money[account] < amount then
			return false, (account == "Cash") and "Nicht genug Bargeld" or "Kontostand nicht ausreichend"
		end
		d.Money[account] -= amount
		d.Stats.TotalSpent += amount
		record(d, (account == "Bank") and "Kartenzahlung" or "Barzahlung", -amount, reason)
		log("%s -%d %s (%s)", player.Name, amount, account, tostring(reason))
	end)
end

-- Spieleraktionen (vom Client angefragt, Validierung von Ort/Abstand erfolgt im Aufrufer) ---------------
function EconomyService.Deposit(player, amount, txId)
	if not validAmount(amount) then
		return false, "Ungueltiger Betrag"
	end
	return DataService.Mutate(player, "Deposit", function(d)
		if seenTx(d, txId) then
			return false, "Transaktion bereits verarbeitet"
		end
		if d.Money.Cash < amount then
			return false, "Nicht genug Bargeld"
		end
		if d.Money.Bank + amount > Config.MaxBalance then
			return false, "Kontolimit erreicht"
		end
		d.Money.Cash -= amount
		d.Money.Bank += amount
		record(d, "Einzahlung", amount)
		log("%s Einzahlung %d", player.Name, amount)
	end)
end

function EconomyService.Withdraw(player, amount, txId)
	if not validAmount(amount) then
		return false, "Ungueltiger Betrag"
	end
	return DataService.Mutate(player, "Withdraw", function(d)
		if seenTx(d, txId) then
			return false, "Transaktion bereits verarbeitet"
		end
		if d.Money.Bank < amount then
			return false, "Kontostand nicht ausreichend"
		end
		if d.Money.Cash + amount > Config.MaxBalance then
			return false, "Bargeldlimit erreicht"
		end
		d.Money.Bank -= amount
		d.Money.Cash += amount
		record(d, "Auszahlung", -amount)
		log("%s Auszahlung %d", player.Name, amount)
	end)
end

-- Zwischen zwei geladenen Profilen auf diesem Server. account: "Bank" (Ueberweisung) oder "Cash" (Uebergabe)
function EconomyService.Transfer(from, to, account, amount, txId, note)
	if from == to then
		return false, "Ueberweisung an dich selbst nicht moeglich"
	end
	if not validAmount(amount) then
		return false, "Ungueltiger Betrag"
	end
	local src, dst = DataService.Get(from), DataService.Get(to)
	if not src or not dst then
		return false, "Empfaenger nicht verfuegbar"
	end
	-- Pruefen + Buchen ohne Yield dazwischen: kein anderer Thread kann dazwischenfunken
	if seenTx(src, txId) then
		return false, "Transaktion bereits verarbeitet"
	end
	if src.Money[account] < amount then
		return false, (account == "Cash") and "Nicht genug Bargeld" or "Kontostand nicht ausreichend"
	end
	if dst.Money[account] + amount > Config.MaxBalance then
		return false, "Empfaenger hat das Kontolimit erreicht"
	end
	local toName = dst.Character.FirstName .. " " .. dst.Character.LastName
	local fromName = src.Character.FirstName .. " " .. src.Character.LastName
	local kindOut = (account == "Bank") and "Ueberweisung an" or "Bargeld an"
	local kindIn = (account == "Bank") and "Ueberweisung von" or "Bargeld von"
	DataService.Mutate(from, "TransferOut", function(d)
		d.Money[account] -= amount
		record(d, kindOut, -amount, toName .. (note and note ~= "" and (" - " .. note) or ""))
	end)
	DataService.Mutate(to, "TransferIn", function(d)
		d.Money[account] += amount
		record(d, kindIn, amount, fromName .. (note and note ~= "" and (" - " .. note) or ""))
	end)
	log("%s -> %s %d %s", from.Name, to.Name, amount, account)
	return true
end

return EconomyService
