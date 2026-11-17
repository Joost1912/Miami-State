-- MedicalService: Verletzungen und Rettungsdienst.
-- Zustaende (Attribut "Injury"): nil (gesund) | "Minor" | "Severe" | "Unconscious"
-- * Schaden nur ueber MedicalService.Damage (Sturz, Fahrzeugunfall, Feuer, ...): faellt die Gesundheit auf 0,
--   wird die Person bewusstlos statt zu sterben. Keine automatische Regeneration (Standard-Health-Skript entfernt).
-- * Rettungsdienst: Untersuchen, Stabilisieren, Medikamente, Wiederbeleben, Tragen, Transport, Behandlung im Krankenhaus.
-- * Alle Massnahmen serverseitig geprueft (Dienst, Recht, Abstand, Ausruestung, Zustand).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local Rescue = require(Shared.Config.Rescue)
local Items = require(Shared.Config.Items)

local MedicalService = {}
local S
local CFG = Rescue.Medical
local carries = {} -- [patient] = { Medic, Weld }
local loaded = {} -- [patient] = Seat
local lastAction = {}
local lastHit = {} -- [player] = os.clock() (Fahrzeugtreffer)
local causes = {} -- [player] = letzte Verletzungsursache
local restored = {} -- [player] = true nach Wiederherstellung beim Beitritt

function MedicalService.Init(services)
	S = services
end

local function hum(p)
	return p.Character and p.Character:FindFirstChildOfClass("Humanoid")
end
local function root(p)
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end
local function rpName(p)
	local d = S.DataService.Get(p)
	return d and d.Character.Created and (d.Character.FirstName .. " " .. d.Character.LastName) or p.Name
end

local function stateFor(health)
	if health <= 0.5 then
		return "Unconscious"
	elseif health < CFG.SevereBelow then
		return "Severe"
	elseif health < CFG.MinorBelow then
		return "Minor"
	end
	return nil
end

local function persist(player)
	if typeof(player) ~= "Instance" then
		return
	end
	local h = hum(player)
	S.DataService.Mutate(player, "Medical", function(d)
		d.Medical.State = player:GetAttribute("Injury") or "Healthy"
		d.Medical.Health = h and math.floor(h.Health) or 100
		d.Medical.DownSince = player:GetAttribute("DownSince") or 0
	end)
end

-- Bewegung je nach Zustand (gefesselte Personen behalten ihre Einschraenkung)
local function applyMobility(player)
	local h = hum(player)
	if not h then
		return
	end
	local st = player:GetAttribute("Injury")
	if player:GetAttribute("Cuffed") then
		return
	end
	if st == "Unconscious" then
		h.WalkSpeed = 0
		h.UseJumpPower = false
		h.JumpHeight = 0
	elseif st == "Severe" then
		h.WalkSpeed = CFG.SevereWalkSpeed
		h.UseJumpPower = false
		h.JumpHeight = 2
	else
		h.WalkSpeed = 16
		h.UseJumpPower = false
		h.JumpHeight = 7.2
	end
end

local function setState(player, st, why)
	local old = player:GetAttribute("Injury")
	if old == st then
		return
	end
	player:SetAttribute("Injury", st)
	if st == "Unconscious" then
		player:SetAttribute("DownSince", os.time())
		player:SetAttribute("Stabilized", nil)
		local h = hum(player)
		if h and h.SeatPart and h.SeatPart:IsA("VehicleSeat") then
			local w = h.SeatPart:FindFirstChild("SeatWeld")
			if w then
				w:Destroy()
			end
			h.Sit = false
		end
		S.Push(player, "Notify", { Text = "Du bist bewusstlos. Rufe ueber das Handy Hilfe oder warte auf den Rettungsdienst.", Kind = "error" })
		S.Log("Injury", nil, player, "bewusstlos (" .. tostring(why or causes[player] or "?") .. ")")
	elseif old == "Unconscious" then
		player:SetAttribute("DownSince", nil)
		player:SetAttribute("Stabilized", nil)
	end
	applyMobility(player)
	persist(player)
end

local function refresh(player)
	local h = hum(player)
	if not h then
		return
	end
	if player:GetAttribute("Injury") == "Unconscious" then
		return -- nur Wiederbelebung/Krankenhaus beenden die Bewusstlosigkeit
	end
	setState(player, stateFor(h.Health))
end

-- Schaden zufuegen (einzige Schadensquelle der Spielsysteme)
function MedicalService.Damage(player, amount, cause)
	local h = hum(player)
	if not h or h.Health <= 0 or typeof(amount) ~= "number" or amount <= 0 then
		return
	end
	if player:GetAttribute("Injury") == "Unconscious" or player:GetAttribute("Jailed") then
		return
	end
	causes[player] = cause
	local hp = h.Health - amount
	if hp <= 0.5 then
		h.Health = 1 -- nicht sterben: bewusstlos
		setState(player, "Unconscious", cause)
	else
		h.Health = hp
		refresh(player)
	end
end

function MedicalService.Heal(player, amount, maxTo)
	local h = hum(player)
	if not h then
		return
	end
	h.Health = math.min(maxTo or h.MaxHealth, h.Health + amount)
	refresh(player)
end

-- Ziel aufloesen (Spieler oder Studio-Testperson)
local function patient(medic, targetId, perm, range)
	if not S.RescueService.Member(medic, true) or not S.JobService.HasPermission(medic, perm) then
		return nil, "Keine Berechtigung (" .. perm .. ")"
	end
	if lastAction[medic] and os.clock() - lastAction[medic] < 1 then
		return nil, "Bitte kurz warten"
	end
	local target = S.JusticeService.Resolve(targetId)
	if not target or target == medic then
		return nil, "Person nicht gefunden"
	end
	local a, b = root(medic), root(target)
	if not a or not b or (a.Position - b.Position).Magnitude > (range or 8) then
		return nil, "Person ist zu weit entfernt"
	end
	lastAction[medic] = os.clock()
	return target
end

local function consume(medic, itemId)
	if S.InventoryService.Count(medic, itemId) < 1 then
		return false
	end
	S.InventoryService.Remove(medic, itemId, 1, "Behandlung")
	return true
end

function MedicalService.Examine(medic, targetId)
	local target, err = patient(medic, targetId, "EMS.Examine", 10)
	if not target then
		return false, err
	end
	local h = hum(target)
	local st = target:GetAttribute("Injury")
	local down = target:GetAttribute("DownSince")
	local left = down and math.max(0, CFG.BleedoutSeconds + (target:GetAttribute("Stabilized") and CFG.StabilizedBonus or 0) - (os.time() - down)) or nil
	local labels = { Minor = "Leicht verletzt", Severe = "Schwer verletzt", Unconscious = "Bewusstlos" }
	S.Log("Examine", medic, target, tostring(st or "gesund"))
	return true, nil, {
		Name = rpName(target), UserId = target.UserId, Health = h and math.floor(h.Health) or 0, State = st or "Healthy",
		StateName = labels[st] or "Keine Verletzungen", Stabilized = target:GetAttribute("Stabilized") == true,
		TimeLeft = left, Cause = causes[target] or "unbekannt", Carried = carries[target] ~= nil, Loaded = loaded[target] ~= nil,
		Pulse = (st == "Unconscious") and (target:GetAttribute("Stabilized") and 58 or 42) or (st == "Severe" and 118 or (st == "Minor" and 96 or 72)),
	}
end

function MedicalService.Stabilize(medic, targetId)
	local target, err = patient(medic, targetId, "EMS.Stabilize", 8)
	if not target then
		return false, err
	end
	local st = target:GetAttribute("Injury")
	if not st then
		return false, "Person ist unverletzt"
	end
	if not consume(medic, "Bandage") then
		return false, "Kein Verband im Inventar"
	end
	if st == "Unconscious" then
		if target:GetAttribute("Stabilized") then
			return false, "Patient ist bereits stabilisiert"
		end
		target:SetAttribute("Stabilized", true)
		S.Push(target, "Notify", { Text = "Du wurdest stabilisiert (" .. rpName(medic) .. ")", Kind = "info" })
	else
		local t = CFG.Treatments.Bandage
		MedicalService.Heal(target, t.Heal, t.MaxTo)
	end
	S.Log("Stabilize", medic, target, st)
	return true, rpName(target) .. " stabilisiert"
end

function MedicalService.Medicate(medic, targetId)
	local target, err = patient(medic, targetId, "EMS.Stabilize", 8)
	if not target then
		return false, err
	end
	local st = target:GetAttribute("Injury")
	if not st then
		return false, "Person ist unverletzt"
	end
	if st == "Unconscious" then
		return false, "Bewusstlose Patienten zuerst wiederbeleben"
	end
	if not consume(medic, "Medkit") then
		return false, "Kein Erste-Hilfe-Set im Inventar"
	end
	local t = CFG.Treatments.Medkit
	MedicalService.Heal(target, t.Heal, t.MaxTo)
	S.Log("Medicate", medic, target, "Erste-Hilfe-Set")
	return true, rpName(target) .. " versorgt"
end

function MedicalService.Revive(medic, targetId)
	local target, err = patient(medic, targetId, "EMS.Revive", 8)
	if not target then
		return false, err
	end
	if target:GetAttribute("Injury") ~= "Unconscious" then
		return false, "Person ist nicht bewusstlos"
	end
	if not target:GetAttribute("Stabilized") then
		return false, "Patient zuerst stabilisieren"
	end
	if S.InventoryService.Count(medic, "Defibrillator") < 1 then
		return false, "Defibrillator fehlt (Dienstausruestung)"
	end
	local h = hum(target)
	if h then
		h.Health = CFG.ReviveHealth
	end
	setState(target, stateFor(CFG.ReviveHealth), "Wiederbelebung")
	S.RescueService.AddStat(medic, "EMS", "Revives", 1)
	S.Push(target, "Notify", { Text = "Du wurdest wiederbelebt. Lass dich im Krankenhaus weiter behandeln.", Kind = "success" })
	S.Log("Revive", medic, target, "wiederbelebt")
	return true, rpName(target) .. " wiederbelebt"
end

-- Tragen / Transport ---------------------------------------------------------------------------------
local function stopCarry(target)
	local c = carries[target]
	if not c then
		return
	end
	if c.Weld then
		c.Weld:Destroy()
	end
	local h = hum(target)
	if h then
		h.PlatformStand = false
	end
	for _, p in ipairs(target.Character and target.Character:GetDescendants() or {}) do
		if p:IsA("BasePart") then
			p.Massless = false
		end
	end
	carries[target] = nil
	target:SetAttribute("Carried", nil)
end

function MedicalService.Carry(medic, targetId)
	local target, err = patient(medic, targetId, "EMS.Stabilize", 8)
	if not target then
		return false, err
	end
	if carries[target] then
		stopCarry(target)
		return true, "Patient abgelegt"
	end
	local st = target:GetAttribute("Injury")
	if st ~= "Unconscious" and st ~= "Severe" then
		return false, "Nur bewusstlose oder schwer verletzte Personen tragen"
	end
	if loaded[target] then
		return false, "Patient liegt im Fahrzeug"
	end
	local rm, rt, h = root(medic), root(target), hum(target)
	if not (rm and rt and h) then
		return false, "Nicht moeglich"
	end
	for _, p in ipairs(target.Character:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Massless = true
		end
	end
	h.PlatformStand = true
	rt.CFrame = rm.CFrame * CFrame.new(0, 1.2, 1.4) * CFrame.Angles(0, math.rad(90), math.rad(90))
	local w = Instance.new("WeldConstraint")
	w.Name = "CarryWeld"
	w.Part0, w.Part1 = rm, rt
	w.Parent = rt
	carries[target] = { Medic = medic, Weld = w }
	target:SetAttribute("Carried", true)
	S.Log("Carry", medic, target, "getragen")
	return true, "Du traegst " .. rpName(target)
end

local function nearestRescueVehicle(medic, range)
	local r = root(medic)
	local best, bd
	for _, m in ipairs(S.VehicleService.All()) do
		local ch = m:FindFirstChild("Chassis")
		local kind = m:GetAttribute("Kind")
		if ch and r and (kind == "EMS" or kind == "Fire") then
			local d = (ch.Position - r.Position).Magnitude
			if d <= range and (not bd or d < bd) then
				best, bd = m, d
			end
		end
	end
	return best
end

function MedicalService.Load(medic, targetId)
	local target, err = patient(medic, targetId, "EMS.Transport", 14)
	if not target then
		return false, err
	end
	if not target:GetAttribute("Injury") then
		return false, "Person ist unverletzt"
	end
	local v = nearestRescueVehicle(medic, 20)
	if not v or v:GetAttribute("Kind") ~= "EMS" then
		return false, "Kein Rettungswagen in der Naehe"
	end
	local seat
	for i = 3, 1, -1 do
		local s = v:FindFirstChild("PassengerSeat" .. i) or v:FindFirstChild("Stretcher" .. i)
		if s and not s.Occupant then
			seat = s
			break
		end
	end
	if not seat then
		return false, "Keine freie Trage"
	end
	stopCarry(target)
	local h = hum(target)
	if h then
		h.PlatformStand = false
		seat:Sit(h)
	end
	loaded[target] = seat
	target:SetAttribute("Loaded", true)
	S.Log("Transport", medic, target, "in " .. tostring(v:GetAttribute("Plate")))
	return true, rpName(target) .. " in den Rettungswagen gebracht"
end

function MedicalService.Unload(medic, targetId)
	local target = S.JusticeService.Resolve(targetId)
	if not target or not S.RescueService.Member(medic, true) then
		return false, "Nicht moeglich"
	end
	local seat = loaded[target]
	if not seat then
		return false, "Patient liegt nicht im Fahrzeug"
	end
	local rm = root(medic)
	if not rm or (seat.Position - rm.Position).Magnitude > 26 then
		return false, "Zu weit vom Fahrzeug entfernt"
	end
	loaded[target] = nil
	target:SetAttribute("Loaded", nil)
	local w = seat:FindFirstChild("SeatWeld")
	if w then
		w:Destroy()
	end
	local h = hum(target)
	if h then
		h.Sit = false
	end
	task.wait(0.1)
	local rt = root(target)
	if rt then
		rt.CFrame = rm.CFrame * CFrame.new(0, 0, 4)
	end
	return true, "Patient ausgeladen"
end

-- Behandlung im Krankenhaus ------------------------------------------------------------------------
local function nearTag(pos, tag, range)
	for _, p in ipairs(CollectionService:GetTagged(tag)) do
		if p:IsDescendantOf(workspace) and (p.Position - pos).Magnitude <= range then
			return p
		end
	end
	return nil
end

local function bill(target, amount, reason)
	local d = S.DataService.Get(target)
	if not d then
		return 0
	end
	local fromBank = math.min(d.Money.Bank, amount)
	if fromBank > 0 then
		S.EconomyService.Charge(target, "Bank", fromBank, reason)
	end
	local rest = amount - fromBank
	local fromCash = math.min(d.Money.Cash, rest)
	if fromCash > 0 then
		S.EconomyService.Charge(target, "Cash", fromCash, reason)
	end
	return fromBank + fromCash
end

function MedicalService.Treat(medic, targetId)
	local target, err = patient(medic, targetId, "EMS.Treat", 12)
	if not target then
		return false, err
	end
	if not target:GetAttribute("Injury") then
		return false, "Person ist unverletzt"
	end
	local rt = root(target)
	if not rt or not nearTag(rt.Position, "HospitalBed", 9) then
		return false, "Behandlung nur auf einem Krankenhausbett (Notaufnahme/Behandlungsraum)"
	end
	stopCarry(target)
	local h = hum(target)
	if h then
		h.Health = h.MaxHealth
	end
	setState(target, nil, "Behandlung")
	local paid = bill(target, CFG.TreatCost, "Krankenhausbehandlung")
	S.RescueService.AddStat(medic, "EMS", "Patients", 1)
	S.EconomyService.Credit(medic, "Bank", 120, "Behandlungspraemie")
	S.Push(target, "Notify", { Text = string.format("Behandlung abgeschlossen - Kosten $%d", paid), Kind = "success" })
	S.Log("Treat", medic, target, "Krankenhausbehandlung")
	return true, rpName(target) .. " vollstaendig behandelt"
end

-- Patient: nach Ablauf der Zeit selbst ins Krankenhaus (Kosten)
function MedicalService.Respawn(player)
	if player:GetAttribute("Injury") ~= "Unconscious" then
		return false, "Nicht bewusstlos"
	end
	local down = player:GetAttribute("DownSince") or os.time()
	local need = CFG.BleedoutSeconds + (player:GetAttribute("Stabilized") and CFG.StabilizedBonus or 0)
	if os.time() - down < need then
		return false, string.format("Noch %d s - der Rettungsdienst kann dich versorgen", need - (os.time() - down))
	end
	stopCarry(player)
	loaded[player] = nil
	player:SetAttribute("Loaded", nil)
	local spot = CollectionService:GetTagged("HospitalRespawn")[1]
	local r = root(player)
	if spot and r then
		r.CFrame = spot.CFrame * CFrame.new(0, 3, 0)
	end
	local h = hum(player)
	if h then
		h.Health = 60
	end
	setState(player, stateFor(60), "Selbsteinweisung")
	local paid = bill(player, CFG.RespawnCost, "Notaufnahme")
	return true, string.format("Du wurdest in der Notaufnahme versorgt - Kosten $%d", paid)
end

-- Patient: Notruf aus der Bewusstlosigkeit
function MedicalService.CallHelp(player)
	if player:GetAttribute("Injury") ~= "Unconscious" then
		return false, "Nur bei Bewusstlosigkeit"
	end
	if player:GetAttribute("HelpCalled") and os.time() - player:GetAttribute("HelpCalled") < 90 then
		return false, "Hilfe ist bereits alarmiert"
	end
	player:SetAttribute("HelpCalled", os.time())
	local r = root(player)
	local call = S.DispatchService.CreateSystemCall("Unconscious", r and r.Position or Vector3.zero, "Notruf-Automatik: " .. rpName(player) .. " ist bewusstlos (" .. tostring(causes[player] or "unbekannt") .. ")")
	return true, "Rettungsdienst alarmiert (Einsatz #" .. tostring(call and call.Id) .. ")"
end

function MedicalService.ReleaseAllBy(medic)
	for target, c in pairs(carries) do
		if c.Medic == medic then
			stopCarry(target)
		end
	end
end

-- Selbstbehandlung mit Verband/Erste-Hilfe-Set (ersetzt den einfachen Heal-Handler)
local function registerSelfHeal()
	S.InventoryService.RegisterUse("Heal", function(player, def, itemId)
		local h = hum(player)
		if not h or h.Health <= 0 then
			return nil, "Nicht moeglich"
		end
		if player:GetAttribute("Injury") == "Unconscious" then
			return nil, "Du bist bewusstlos"
		end
		local t = CFG.Treatments[itemId or ""] or { Heal = def.Amount, MaxTo = 80 }
		if h.Health >= t.MaxTo then
			return nil, "Weitere Heilung nur durch den Rettungsdienst/Krankenhaus"
		end
		MedicalService.Heal(player, t.Heal, t.MaxTo)
		return true, def.Name .. " benutzt"
	end)
end

-- Schadensquellen: Sturz, Fahrzeugtreffer, Unfall --------------------------------------------------
local lastVy = {}
local lastVehVel = setmetatable({}, { __mode = "k" })

local function scanFalls()
	for _, p in ipairs(Players:GetPlayers()) do
		local r, h = root(p), hum(p)
		if r and h and h.Health > 0 and not h.SeatPart and not carries[p] then
			local vy = r.AssemblyLinearVelocity.Y
			local prev = lastVy[p]
			if prev and prev < -CFG.FallDamageSpeed and vy > -12 then
				MedicalService.Damage(p, (-prev - CFG.FallDamageSpeed) * CFG.FallDamageFactor, "Sturz")
			end
			lastVy[p] = vy
		else
			lastVy[p] = nil
		end
	end
end

local function scanVehicles()
	for _, m in ipairs(S.VehicleService.All()) do
		local ch = m:FindFirstChild("Chassis")
		if ch then
			local vel = ch.AssemblyLinearVelocity
			local speed = vel.Magnitude
			-- Unfall: starker Geschwindigkeitsverlust -> Insassen verletzt
			local prev = lastVehVel[m]
			if prev and prev - speed > CFG.CrashDecel then
				for _, s in ipairs(m:GetChildren()) do
					if (s:IsA("Seat") or s:IsA("VehicleSeat")) and s.Occupant then
						local p = Players:GetPlayerFromCharacter(s.Occupant.Parent)
						if p then
							MedicalService.Damage(p, (prev - speed) * 0.6, "Verkehrsunfall")
						end
					end
				end
			end
			lastVehVel[m] = speed
			-- Fussgaenger angefahren
			if speed >= CFG.VehicleHitSpeed then
				local size = m:GetExtentsSize()
				local cf = ch.CFrame
				for _, p in ipairs(Players:GetPlayers()) do
					local r, h = root(p), hum(p)
					if r and h and not h.SeatPart and (not lastHit[p] or os.clock() - lastHit[p] > 1.5) then
						local rel = cf:PointToObjectSpace(r.Position)
						if math.abs(rel.X) < size.X / 2 + 1.5 and math.abs(rel.Z) < size.Z / 2 + 1.5 and rel.Y > -2 and rel.Y < size.Y + 2 then
							lastHit[p] = os.clock()
							MedicalService.Damage(p, math.min(95, (speed - CFG.VehicleHitSpeed) * 1.4 + 15), "Von Fahrzeug erfasst")
						end
					end
				end
			end
		end
	end
end

function MedicalService.Start()
	registerSelfHeal()
	-- Heilung nur ueber das Spiel, keine Regeneration; Zustand an Gesundheit koppeln
	local function hook(player)
		player.CharacterAdded:Connect(function(char)
			local h = char:WaitForChild("Humanoid", 10)
			if not h then
				return
			end
			h.BreakJointsOnDeath = false
			carries[player], loaded[player] = nil, nil
			-- Beim ersten Charakter nach Beitritt: gespeicherten Zustand wiederherstellen
			local d = S.DataService.Get(player)
			if not restored[player] and d then
				restored[player] = true
				if d.Medical.State ~= "Healthy" then
					task.wait(0.5)
					h.Health = math.clamp(d.Medical.Health, 1, 100)
					if d.Medical.State == "Unconscious" then
						h.Health = 1
						player:SetAttribute("Injury", nil)
						setState(player, "Unconscious", "fortgesetzt")
						if d.Medical.DownSince > 0 then
							player:SetAttribute("DownSince", d.Medical.DownSince)
						end
					else
						refresh(player)
					end
				end
			elseif restored[player] then
				-- echter Respawn (z.B. aus der Welt gefallen): gesund
				player:SetAttribute("Injury", nil)
				player:SetAttribute("DownSince", nil)
				player:SetAttribute("Stabilized", nil)
				applyMobility(player)
				persist(player)
			end
			-- (Profil noch nicht geladen: Wiederherstellung uebernimmt ProfileLoaded)
			h.HealthChanged:Connect(function()
				if restored[player] and player:GetAttribute("Injury") ~= "Unconscious" then
					refresh(player)
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	-- Profil kann nach dem ersten Charakter laden: dann jetzt wiederherstellen
	S.DataService.ProfileLoaded:Connect(function(player)
		if player.Character and not restored[player] then
			restored[player] = true
			local d = S.DataService.Get(player)
			local h = hum(player)
			if h and d.Medical.State ~= "Healthy" then
				h.Health = math.clamp(d.Medical.Health, 1, 100)
				if d.Medical.State == "Unconscious" then
					h.Health = 1
					setState(player, "Unconscious", "fortgesetzt")
				else
					refresh(player)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		MedicalService.ReleaseAllBy(p)
		stopCarry(p)
		loaded[p], lastAction[p], lastHit[p], causes[p], restored[p], lastVy[p] = nil, nil, nil, nil, nil, nil
	end)
	table.insert(S.DataService.BeforeRelease, function(p)
		if typeof(p) == "Instance" and p:GetAttribute("Injury") then
			persist(p)
		end
	end)
	-- Patienten bleiben auf der Trage
	RunService.Heartbeat:Connect(function()
		for target, seat in pairs(loaded) do
			local h = hum(target)
			if not seat.Parent or not h then
				loaded[target] = nil
			elseif h.SeatPart ~= seat and not seat.Occupant then
				seat:Sit(h)
			end
		end
	end)
	-- Abtastung 10 Hz (Stuerze), 5 Hz (Fahrzeuge)
	task.spawn(function()
		local n = 0
		while true do
			task.wait(0.1)
			n += 1
			scanFalls()
			if n % 2 == 0 then
				scanVehicles()
			end
		end
	end)
end

-- Studio-Tests
function MedicalService._setHealth(player, hp, cause)
	local h = hum(player)
	if h then
		if hp <= 0 then
			MedicalService.Damage(player, h.Health + 5, cause or "Test")
		else
			h.Health = hp
			refresh(player)
		end
	end
end

return MedicalService
