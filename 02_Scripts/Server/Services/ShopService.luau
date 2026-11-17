-- ShopService: gemeinsames Shopsystem fuer alle Geschaefte (Supermarkt, Werkzeug, Waffen, Langwaffen, Kleidung, Juwelier ...).
-- * Preis, Packungsgroesse und Bedingungen kommen IMMER aus Config.Shops (Server), nie vom Client.
-- * Spieler muss an einer Kasse/einem Eingang dieses Ladens stehen (Abstand serverseitig).
-- * Bedingungen (Waffenschein, sauberes Register, Alter, Spielzeit) werden beim Anzeigen UND beim Kauf geprueft.
-- * Doppelkaeufe: Transaktions-ID (einmalig) + Kaufsperre 0.4 s; Geld wird erst nach erfolgreicher Inventarpruefung
--   abgebucht, bei unerwartetem Fehler sofort erstattet -> kein negativer Kontostand, kein Verlust.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local Shops = require(Shared.Config.Shops)
local Items = require(Shared.Config.Items)
local Clothing = require(Shared.Config.Clothing)
local EconomyConfig = require(Shared.Config.Economy)

local ShopService = {}
local S, DataService, EconomyService, InventoryService, InteractionService
local lastBuy = setmetatable({}, { __mode = "k" })

function ShopService.Init(s)
	S = s
	DataService, EconomyService, InventoryService, InteractionService = s.DataService, s.EconomyService, s.InventoryService, s.InteractionService
end

local function entryOf(cat, itemId)
	for _, e in ipairs(cat.Items) do
		if e.Id == itemId then
			return e
		end
	end
end

local function playHours(player, d)
	local session = 0
	if typeof(player) == "Instance" then
		session = player:GetAttribute("SessionStart") and (os.time() - player:GetAttribute("SessionStart")) or 0
	end
	return ((d.Stats.PlayTime or 0) + session) / 3600
end

local REQ_TEXT = {
	WeaponLicense = "Waffenschein erforderlich",
	NoLicense = "Du besitzt bereits einen Waffenschein",
	CleanRecord = "Nicht moeglich: offene Fahndung oder Haftbefehl",
	Age21 = "Mindestalter 21 Jahre",
}

-- Bedingung pruefen -> nil (ok) oder Grund
local function checkReq(player, d, req)
	local ok
	if req == "WeaponLicense" then
		ok = (d.Inventory.Items.WeaponLicense or 0) > 0
	elseif req == "NoLicense" then
		ok = (d.Inventory.Items.WeaponLicense or 0) == 0
	elseif req == "CleanRecord" then
		ok = not d.Record.Wanted and #d.Record.Warrants == 0
	elseif req == "Age21" then
		local year = tonumber(os.date("!%Y")) or 2026
		ok = d.Character.BirthYear > 0 and year - d.Character.BirthYear >= 21
	else
		return "Unbekannte Bedingung"
	end
	if ok then
		return nil
	end
	return REQ_TEXT[req]
end

-- Warum ist ein Artikel gesperrt? nil = kaufbar
function ShopService.LockReason(player, cat, entry)
	local d = DataService.Get(player)
	if not d then
		return "Profil nicht geladen"
	end
	for _, list in ipairs({ cat.Requires or {}, entry.Requires or {} }) do
		for _, req in ipairs(list) do
			local why = checkReq(player, d, req)
			if why then
				return why
			end
		end
	end
	local need = math.max(cat.MinPlayHours or 0, entry.MinPlayHours or 0)
	if need > 0 and playHours(player, d) < need then
		return string.format("Erst ab %d Stunden Spielzeit", need)
	end
	if cat.Kind == "Clothing" then
		if table.find(d.Wardrobe.Owned, entry.Id) then
			return "Bereits gekauft"
		end
	elseif Items.Defs[entry.Id] and Items.Defs[entry.Id].Stack == 1 and (d.Inventory.Items[entry.Id] or 0) > 0 then
		return "Bereits im Inventar"
	end
	return nil
end

-- Katalog fuer die Anzeige (mit Sperrgruenden je Artikel)
function ShopService.Describe(player, shopId, inst)
	-- Prompt 11: Preisfaktor des Unternehmensinhabers (nur Kassen mit BusinessId)
	local factor = (S and S.BusinessService and inst) and S.BusinessService.PriceFactor(inst) or 1
	local cat = Shops.Catalogs[shopId]
	if not cat then
		return nil
	end
	local items = {}
	for _, e in ipairs(cat.Items) do
		table.insert(items, { Id = e.Id, Price = math.floor(e.Price * factor + 0.5), Pack = e.Pack or 1, Locked = ShopService.LockReason(player, cat, e) })
	end
	return {
		ShopId = shopId, Title = cat.Title, Subtitle = cat.Subtitle, Kind = cat.Kind or "Retail", Icon = cat.Icon,
		Color = cat.Color, Info = cat.Info, Items = items,
	}
end

function ShopService.AtShop(player, shopId)
	local shop = InteractionService.NearestOfType(player, "Shop", EconomyConfig.ShopRange)
	return shop ~= nil and shop:GetAttribute("ShopId") == shopId
end

-- payload: { ShopId, ItemId, Count, Method = "Cash" | "Bank", TxId }
function ShopService.Buy(player, p)
	if typeof(p) ~= "table" or typeof(p.ShopId) ~= "string" or typeof(p.ItemId) ~= "string" then
		return false, "Ungueltige Anfrage"
	end
	local cat = Shops.Catalogs[p.ShopId]
	if not cat then
		return false, "Unbekannter Laden"
	end
	local entry = entryOf(cat, p.ItemId)
	if not entry then
		return false, "Artikel nicht im Sortiment"
	end
	local count = p.Count
	if typeof(count) ~= "number" or count % 1 ~= 0 or count < 1 or count > 10 then
		return false, "Ungueltige Anzahl"
	end
	if p.Method ~= "Cash" and p.Method ~= "Bank" then
		return false, "Ungueltige Zahlungsart"
	end
	if lastBuy[player] and os.clock() - lastBuy[player] < 0.4 then
		return false, "Bitte kurz warten"
	end
	lastBuy[player] = os.clock()
	-- in der Naehe eines Ladens mit diesem Sortiment?
	if not ShopService.AtShop(player, p.ShopId) then
		return false, "Du bist nicht im Laden"
	end
	local why = ShopService.LockReason(player, cat, entry)
	if why then
		return false, why
	end
	local data = DataService.Get(player)
	local isClothing = cat.Kind == "Clothing"
	local def = isClothing and Clothing.Defs[p.ItemId] or Items.Defs[p.ItemId]
	if not def then
		return false, "Unbekannter Artikel"
	end
	local units
	if isClothing then
		count, units = 1, 1
	else
		if def.Stack == 1 then
			count = 1
		end
		units = count * (entry.Pack or 1)
		local ok, err = InventoryService.CanAdd(data, p.ItemId, units)
		if not ok then
			return false, err
		end
	end
	-- Transaktions-ID erst nach allen Pruefungen verbrauchen (Wiederholung nach Ablehnung bleibt moeglich)
	if p.TxId ~= nil and not EconomyService.ClaimTx(player, p.TxId) then
		return false, "Kauf bereits verarbeitet"
	end
	local shopInst = InteractionService.NearestOfType(player, "Shop", EconomyConfig.ShopRange)
	local factor = (S and S.BusinessService) and S.BusinessService.PriceFactor(shopInst) or 1
	local total = math.floor(entry.Price * factor + 0.5) * count
	local ok, err = EconomyService.Charge(player, p.Method, total, cat.Title .. ": " .. (units > 1 and (units .. "x ") or "") .. def.Name)
	if not ok then
		return false, err
	end
	if isClothing then
		ok, err = DataService.Mutate(player, "ClothingBuy", function(d)
			if table.find(d.Wardrobe.Owned, p.ItemId) then
				return false, "Bereits gekauft"
			end
			table.insert(d.Wardrobe.Owned, p.ItemId)
		end)
	else
		ok, err = InventoryService.Add(player, p.ItemId, units, "Shop")
	end
	if not ok then
		EconomyService.Credit(player, p.Method, total, "Erstattung " .. cat.Title)
		return false, err
	end
	if S and S.Log and (def.Weapon or p.ItemId == "WeaponLicense" or cat.Kind == "Weapons") then
		S.Log("WeaponShop", player, nil, string.format("%s: %dx %s ($%d, %s)", cat.Title, units, def.Name, total, p.Method))
	end
	if S and S.BusinessService then
		S.BusinessService.OnSale(shopInst, total, cat.Title)
	end
	return true, string.format("%s%s gekauft ($%d)", units > 1 and (units .. "x ") or "", def.Name, total)
end

return ShopService
