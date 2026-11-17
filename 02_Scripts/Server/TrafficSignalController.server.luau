-- TrafficSignalController (Server)
-- Schaltet alle Ampeln (CollectionService-Tag "TrafficSignal") im festen Zyklus:
-- Nord/Sued gruen -> gelb -> alle rot -> Ost/West gruen -> gelb -> alle rot.
-- Spaeter erweiterbar um Verkehrsabhaengigkeit, Fussgaengerphasen und Einsatzfahrzeug-Vorrang.
local CollectionService = game:GetService("CollectionService")

local GREEN_TIME, YELLOW_TIME, ALL_RED_TIME = 18, 4, 2
local ON, OFF = 0, 0.85

local AXIS = { N = "NS", S = "NS", E = "EW", W = "EW" }

local function setLamps(signal, state)
	for _, lamp in ipairs(signal:GetChildren()) do
		if lamp.Name == "Red" or lamp.Name == "Yellow" or lamp.Name == "Green" then
			lamp.Transparency = (lamp.Name == state) and ON or OFF
		end
	end
end

local function apply(axisGreen, state)
	for _, signal in ipairs(CollectionService:GetTagged("TrafficSignal")) do
		local axis = AXIS[signal:GetAttribute("Approach")]
		if axis == axisGreen then
			setLamps(signal, state)
		else
			setLamps(signal, "Red")
		end
	end
end

while true do
	for _, axis in ipairs({ "NS", "EW" }) do
		apply(axis, "Green")
		task.wait(GREEN_TIME)
		apply(axis, "Yellow")
		task.wait(YELLOW_TIME)
		apply(nil, "Red")
		task.wait(ALL_RED_TIME)
	end
end
