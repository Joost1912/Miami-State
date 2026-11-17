-- GateService (Prompt 14): automatische Schranken (Modelle mit Tag "BoomGate", gebaut in Schritt 33_Harbor).
-- Aufbau: Model { Arm (Model, PrimaryPart = Hinge), Zone (unsichtbarer Bereich), LightRed, LightGreen }.
-- Oeffnet, sobald ein Spieler (zu Fuss oder im Fahrzeug) in der Zone ist; schliesst 2,5 s nachdem die Zone leer ist.
-- Pruefung 4x pro Sekunde, Bewegung nur beim Oeffnen/Schliessen (keine Dauerlast).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local G = {}
local gates = {}

function G.Init() end

local OFF_RED, OFF_GREEN = Color3.fromRGB(70, 20, 20), Color3.fromRGB(30, 60, 30)
local ON_RED, ON_GREEN = Color3.fromRGB(255, 40, 40), Color3.fromRGB(40, 255, 90)

local function setLights(m, open)
	for _, p in ipairs(m:GetChildren()) do
		if p.Name == "LightRed" then
			p.Material = open and Enum.Material.SmoothPlastic or Enum.Material.Neon
			p.Color = open and OFF_RED or ON_RED
		elseif p.Name == "LightGreen" then
			p.Material = open and Enum.Material.Neon or Enum.Material.SmoothPlastic
			p.Color = open and ON_GREEN or OFF_GREEN
		end
	end
end

local function animate(g, target)
	g.Target = target
	if g.Moving then
		return
	end
	g.Moving = true
	task.spawn(function()
		while g.Angle ~= g.Target do
			local step = 4 -- Grad pro Schritt (~1 s fuer 82 Grad)
			if g.Angle < g.Target then
				g.Angle = math.min(g.Target, g.Angle + step)
			else
				g.Angle = math.max(g.Target, g.Angle - step)
			end
			g.Arm:PivotTo(g.Closed * CFrame.Angles(0, 0, math.rad(g.Angle)))
			task.wait(0.05)
		end
		g.Moving = false
	end)
end

local function register(m)
	local arm, zone = m:FindFirstChild("Arm"), m:FindFirstChild("Zone")
	if gates[m] or not (arm and arm.PrimaryPart and zone) then
		return
	end
	gates[m] = { Model = m, Arm = arm, Zone = zone, Closed = arm:GetPivot(), Angle = 0, Target = 0, Open = false, LastSeen = 0, OpenAngle = m:GetAttribute("OpenAngle") or 82 }
	setLights(m, false)
end

local function occupied(zone)
	local cf, half = zone.CFrame, zone.Size / 2
	for _, p in ipairs(Players:GetPlayers()) do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r then
			local rel = cf:PointToObjectSpace(r.Position)
			if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y + 6 and math.abs(rel.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

function G.Start()
	for _, m in ipairs(CollectionService:GetTagged("BoomGate")) do
		register(m)
	end
	CollectionService:GetInstanceAddedSignal("BoomGate"):Connect(register)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for m, g in pairs(gates) do
				if not m.Parent then
					gates[m] = nil
				else
					if occupied(g.Zone) then
						g.LastSeen = now
						if not g.Open then
							g.Open = true
							setLights(m, true)
							animate(g, g.OpenAngle)
						end
					elseif g.Open and now - g.LastSeen > 2.5 then
						g.Open = false
						setLights(m, false)
						animate(g, 0)
					end
				end
			end
		end
	end)
end

return G
