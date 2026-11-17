-- MIAMI STATE Client-Einstieg (StarterPlayerScripts).
-- Haelt den Profil-Zustand (vom Server gesendet, nur Anzeige), verbindet Push-Ereignisse, Tastenkuerzel und HUD.
-- Menues liegen als ModuleScripts unter diesem Skript (Controllers).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("MiamiShared")
local UI = require(Shared.UI)
local Format = require(Shared.Format)
local remotes = ReplicatedStorage:WaitForChild("MiamiRemotes")
local Request = remotes:WaitForChild("Request")
local Push = remotes:WaitForChild("Push")

local profileChanged = Instance.new("BindableEvent")
local ctx = {
	UI = UI,
	Format = Format,
	Config = {
		Economy = require(Shared.Config.Economy),
		Factions = require(Shared.Config.Factions),
		Items = require(Shared.Config.Items),
		Shops = require(Shared.Config.Shops),
		Police = require(Shared.Config.Police),
		MapData = require(Shared.Config.MapData),
		Rescue = require(Shared.Config.Rescue),
		Clothing = require(Shared.Config.Clothing),
		Crime = require(Shared.Config.Crime),
		-- Prompt 10
		Vehicles = require(Shared.Config.Vehicles),
		Properties = require(Shared.Config.Properties),
		-- generierte Kartendaten (Schritt 22_MapExport); fehlen sie, laufen Karte/Minimap nicht
		MapGeo = Shared.Config:FindFirstChild("MapGeo") and require(Shared.Config.MapGeo) or nil,
	},
	Profile = nil,
	ProfileChanged = profileChanged.Event,
	MapExtraApplied = false,
	OpenMenu = nil, -- Name des offenen Menues
}

function ctx.TxId()
	return HttpService:GenerateGUID(false)
end

-- Server-Anfrage mit einheitlicher Rueckmeldung (Toast bei Fehler/Erfolgsmeldung)
function ctx.Request(action, payload, silent)
	local ok, res = pcall(function()
		return Request:InvokeServer(action, payload)
	end)
	if not ok or type(res) ~= "table" then
		UI.toast("Verbindung zum Server fehlgeschlagen", "error")
		return { ok = false }
	end
	if not silent and res.msg then
		UI.toast(res.msg, res.ok and "success" or "error")
	end
	return res
end

-- Kartenergaenzungen (Config.MapExtra) in die generierten Kartendaten einmischen: neue Marker, umbenannte Laeden
do
	local geo = ctx.Config.MapGeo
	local extraMod = Shared.Config:FindFirstChild("MapExtra")
	if geo and geo.POI and extraMod then
		local extra = require(extraMod)
		for _, r in ipairs(extra.Remove or {}) do
			for i = #geo.POI, 1, -1 do
				local p = geo.POI[i]
				if p[2] == r[1] and math.abs(p[3] - r[2]) < 25 and math.abs(p[4] - r[3]) < 25 then
					table.remove(geo.POI, i)
				end
			end
		end
		for _, p in ipairs(extra.POI or {}) do
			table.insert(geo.POI, p)
		end
		for _, b in ipairs(extra.Buildings or {}) do
			table.insert(geo.Buildings, b)
		end
		for _, g in ipairs(extra.Green or {}) do
			table.insert(geo.Green, g)
		end
		ctx.MapExtraApplied = true
	end
end

-- Controller laden
local controllers = {}
for _, m in ipairs(script:WaitForChild("Controllers"):GetChildren()) do
	if m:IsA("ModuleScript") then
		controllers[m.Name] = require(m)
	end
end
ctx.Controllers = controllers

-- Ein Menue gleichzeitig
function ctx.Open(name, ...)
	-- Funkgeraet ist nicht-modal: laeuft neben anderen Menues, Taste/Knopf schaltet um
	if name == "Radio" then
		if controllers.Radio.IsOpen() then
			controllers.Radio.Close()
		else
			controllers.Radio.Open(ctx)
		end
		return
	end
	if ctx.OpenMenu and controllers[ctx.OpenMenu] and controllers[ctx.OpenMenu].Close then
		controllers[ctx.OpenMenu].Close()
	end
	if ctx.Profile and not ctx.Profile.Character.Created and name ~= "CharacterCreator" then
		return
	end
	ctx.OpenMenu = name
	controllers[name].Open(ctx, ...)
end
function ctx.Closed(name)
	if ctx.OpenMenu == name then
		ctx.OpenMenu = nil
	end
end

-- Push-Ereignisse vom Server
Push.OnClientEvent:Connect(function(kind, data)
	if kind == "Profile" then
		local first = ctx.Profile == nil
		ctx.Profile = data
		profileChanged:Fire(data)
		if first and not data.Character.Created then
			ctx.Open("CharacterCreator")
		elseif data.Character.Created and ctx.OpenMenu == "CharacterCreator" then
			controllers.CharacterCreator.Close()
			ctx.Closed("CharacterCreator")
		end
	elseif kind == "Notify" then
		UI.toast(data.Text, data.Kind)
	elseif kind == "OpenBank" then
		ctx.Open("Bank")
	elseif kind == "OpenShop" then
		ctx.Open("Shop", data)
	elseif kind == "OpenJobs" then
		ctx.Open("Jobs")
	elseif kind == "Dialog" then
		UI.toast(data.Name .. ": " .. data.Text, "info")
	elseif kind == "ShowID" then
		controllers.Interact.ShowID(ctx, data)
	-- Polizei / Leitstelle
	elseif kind == "OpenPolice" then
		ctx.Open("Police")
	elseif kind == "OpenGarage" then
		ctx.Open("Police", { Garage = true })
	elseif kind == "OpenMDT" then
		ctx.Open("MDT", data)
	elseif kind == "Radio" then
		controllers.Radio.Incoming(ctx, data)
	elseif kind == "CallNew" then
		UI.toast(string.format("NEUER EINSATZ #%d: %s - %s", data.Id, data.Name, data.District or ""), data.Priority == 1 and "error" or "warning")
		controllers.MDT.CallChanged(ctx)
	elseif kind == "CallUpdate" then
		controllers.MDT.CallChanged(ctx)
	elseif kind == "Waypoint" then
		-- Einsatz-Wegpunkt: Navigation mit Route (Karte, Minimap, Zielmarker)
		local Nav = controllers.CityMap.Nav
		Nav.SetTarget(data.X, data.Z, data.Label, data.Y)
		Nav.CallId = data.CallId
	elseif kind == "WaypointClear" then
		local Nav = controllers.CityMap.Nav
		if Nav.Target and (not data or not data.CallId or Nav.CallId == data.CallId) then
			Nav.CallId = nil
			Nav.Clear(true)
		end
	elseif kind == "OpenRescue" then
		ctx.Open("Rescue", data)
	elseif kind == "TrafficStop" then
		controllers.Overlays.TrafficStop(ctx, data)
	-- Kriminalitaet (Prompt 09)
	elseif kind == "Wanted" then
		controllers.Crime.Wanted(ctx, data)
	elseif kind == "Heist" then
		controllers.Crime.Heist(ctx, data)
	elseif kind == "OpenFence" then
		controllers.Crime.Fence(ctx, data)
	-- Prompt 10: Autohaus/Garage/Tuning, Immobilien, Aktivitaeten
	elseif kind == "OpenVehicles" then
		ctx.Open("Vehicles", data)
	elseif kind == "OpenProperty" then
		ctx.Open("Property", data)
	elseif kind == "PropertyRing" then
		controllers.Property.Ring(ctx, data)
	elseif kind == "Activity" then
		controllers.Activity.Push(ctx, data)
	end
end)

-- Tastenkuerzel
local KEYS = {
	[Enum.KeyCode.I] = "Inventory",
	[Enum.KeyCode.P] = "Profile",
	[Enum.KeyCode.J] = "Jobs",
	[Enum.KeyCode.K] = "Duty", -- Dashboard der eigenen Einsatzfraktion
	[Enum.KeyCode.U] = "Phone",
	[Enum.KeyCode.V] = "CityMap",
	[Enum.KeyCode.B] = "Radio",
	[Enum.KeyCode.M] = "MDT",
	[Enum.KeyCode.N] = "Emergency",
}
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local name = KEYS[input.KeyCode]
	if name == "Duty" then
		-- Dashboard der eigenen Einsatzfraktion (wie HUD-Knopf); nur fuer Polizei/Feuerwehr/EMS
		local fac = player:GetAttribute("Faction")
		name = (fac == "Police" and "Police") or ((fac == "Fire" or fac == "EMS") and "Rescue") or nil
	end
	if name then
		if ctx.OpenMenu == name then
			controllers[name].Close()
			ctx.Closed(name)
		else
			ctx.Open(name)
		end
	elseif input.KeyCode == Enum.KeyCode.X then
		controllers.Interact.TargetNearest(ctx)
	end
end)

controllers.Hud.Start(ctx)
controllers.Overlays.Start(ctx)
controllers.CityMap.Start(ctx)
controllers.Minimap.Start(ctx)
controllers.Medical.Start(ctx)
controllers.Phone.Start(ctx)
task.spawn(controllers.FireTools.Start, ctx)
controllers.WeaponHud.Start(ctx)
task.spawn(controllers.Crime.Start, ctx)
controllers.Activity.Start(ctx)

-- Profil anfordern (falls der erste Push vor dem Laden dieses Skripts kam)
task.spawn(function()
	for _ = 1, 20 do
		if ctx.Profile then
			return
		end
		ctx.Request("Profile.Get", nil, true)
		task.wait(1.5)
	end
end)
