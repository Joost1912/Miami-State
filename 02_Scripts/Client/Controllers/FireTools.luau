-- Loeschwerkzeuge der Feuerwehr (Tools "MSFD_Extinguisher" / "MSFD_Hose").
-- Maustaste halten: Spruehstrahl (lokale Partikel) und Treffermeldung an den Server (RemoteEvent "FireSpray").
-- Der Server prueft Dienst, Werkzeug, Reichweite, Takt, Wasserversorgung und Fuellstand.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FT = {}
local ctxRef
local spraying, tool, emitter, hud
local lastShot = 0

function FT.Close() end

local function cfgFor(kind)
	return ctxRef.Config.Rescue.Fires.Tools[kind]
end

local function makeEmitter(t)
	local handle = t:FindFirstChild("Handle")
	local nozzle = handle and handle:FindFirstChild("Nozzle")
	if not nozzle then
		return nil
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = "SprayFX"
	local hose = t:GetAttribute("FireTool") == "Hose"
	e.Color = ColorSequence.new(hose and Color3.fromRGB(190, 220, 255) or Color3.fromRGB(245, 245, 250))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, hose and 2.2 or 3) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(hose and 0.9 or 0.6)
	e.Speed = NumberRange.new(hose and 55 or 26)
	e.SpreadAngle = Vector2.new(hose and 4 or 14, hose and 4 or 14)
	e.Acceleration = Vector3.new(0, hose and -30 or -6, 0)
	e.Rate = 0
	e.EmissionDirection = Enum.NormalId.Front
	e.Parent = nozzle
	nozzle.CFrame = CFrame.new(nozzle.Position) * CFrame.Angles(0, 0, 0)
	return e
end

-- Ziel: Brandherd, auf den die Kamera/Maus zeigt (Winkel zum Blickstrahl), innerhalb der Reichweite
local function pickFlame(range)
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local mouse = Players.LocalPlayer:GetMouse()
	local cam = Workspace.CurrentCamera
	local ray = cam:ScreenPointToRay(mouse.X, mouse.Y)
	local best, bestScore
	for _, f in ipairs(CollectionService:GetTagged("Flame")) do
		local dist = (f.Position - root.Position).Magnitude
		local radius = f:GetAttribute("Radius") or 4
		if dist <= range + radius then
			local toF = (f.Position - ray.Origin)
			local along = toF:Dot(ray.Direction.Unit)
			if along > 0 then
				local perp = (toF - ray.Direction.Unit * along).Magnitude
				if perp <= radius + 4 then
					local score = perp + dist * 0.05
					if not bestScore or score < bestScore then
						best, bestScore = f, score
					end
				end
			end
		end
	end
	return best
end

local function setHud(text, warn)
	if hud then
		hud.Text = text
		hud.TextColor3 = warn and Color3.fromRGB(255, 196, 80) or Color3.fromRGB(230, 240, 255)
		hud.Visible = text ~= ""
	end
end

local function bindTool(t)
	tool = t
	emitter = makeEmitter(t)
	local def = cfgFor(t:GetAttribute("FireTool"))
	setHud(def.Name .. "  -  Maustaste halten" .. (def.Charges and string.format("  |  Fuellung %d", t:GetAttribute("Charges") or def.Charges) or "  |  Wasser vom Loeschfahrzeug"))
	t.Activated:Connect(function()
		spraying = true
	end)
	t.Deactivated:Connect(function()
		spraying = false
	end)
	t.Unequipped:Connect(function()
		spraying = false
		if emitter then
			emitter.Rate = 0
		end
		tool = nil
		setHud("")
	end)
	t:GetAttributeChangedSignal("Charges"):Connect(function()
		if tool == t then
			local left = t:GetAttribute("Charges") or 0
			setHud(string.format("%s  |  Fuellung %d%s", def.Name, left, left <= 0 and "  -  am Fahrzeug/Geraeteraum auffuellen" or ""), left <= 0)
		end
	end)
end

function FT.Start(ctx)
	ctxRef = ctx
	local UI, T = ctx.UI, ctx.UI.Theme
	local gui = UI.screen("MiamiFireTools", 6)
	hud = UI.new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -150), Size = UDim2.fromOffset(460, 28), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.25, Font = T.FontBold, TextSize = 13, Visible = false, Parent = gui })
	UI.corner(hud, 8)
	local remote = ReplicatedStorage:WaitForChild("MiamiRemotes"):WaitForChild("FireSpray")
	local function hookChar(char)
		char.ChildAdded:Connect(function(c)
			if c:IsA("Tool") and c:GetAttribute("FireTool") then
				bindTool(c)
			end
		end)
	end
	Players.LocalPlayer.CharacterAdded:Connect(hookChar)
	if Players.LocalPlayer.Character then
		hookChar(Players.LocalPlayer.Character)
	end
	RunService.Heartbeat:Connect(function()
		if not tool or not tool.Parent then
			return
		end
		local def = cfgFor(tool:GetAttribute("FireTool"))
		local empty = def.Charges and (tool:GetAttribute("Charges") or def.Charges) <= 0
		local particles = not (ctx.Controllers.Phone and ctx.Controllers.Phone.Particles == false)
		if emitter then
			emitter.Rate = (spraying and not empty and particles) and 120 or 0
			-- Strahl in Blickrichtung ausrichten
			local mouse = Players.LocalPlayer:GetMouse()
			local nozzle = emitter.Parent
			if nozzle and nozzle:IsA("Attachment") and spraying then
				nozzle.WorldCFrame = CFrame.lookAt(nozzle.WorldPosition, mouse.Hit.Position)
			end
		end
		if spraying and not empty and os.clock() - lastShot >= def.Interval then
			lastShot = os.clock()
			local f = pickFlame(def.Range)
			if f then
				remote:FireServer(f)
			end
		end
	end)
	-- Partikel-Einstellung auch fuer neue Brandherde
	local fires = Workspace:WaitForChild("ActiveFires", 30)
	if fires then
		fires.DescendantAdded:Connect(function(d)
			if (d:IsA("Fire") or d:IsA("Smoke")) and ctx.Controllers.Phone and ctx.Controllers.Phone.Particles == false then
				d.Enabled = false
			end
		end)
	end
end

return FT
