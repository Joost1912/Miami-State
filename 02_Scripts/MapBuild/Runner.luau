-- Runner: laedt MapKit und Bau-Schritte aus dem Repo (lokaler Server serve.ps1) und fuehrt sie in Studio aus.
-- Aufruf per MCP: require(ServerStorage.MapBuildTools.Runner:Clone()).run("01_Setup")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local BASE = "http://localhost:34872/MapBuild/"
local Runner = {}

function Runner.fetch(path)
	return HttpService:GetAsync(BASE .. path, true)
end

function Runner.module(path, name)
	local m = Instance.new("ModuleScript")
	m.Name = name or path
	m.Source = Runner.fetch(path)
	return require(m)
end

function Runner.run(step)
	local src = Runner.fetch("MapKit.luau")
	-- gespeicherte Kopie im Place aktuell halten (fuer spaetere Builds ohne Server)
	local tools = ServerStorage:FindFirstChild("MapBuildTools")
	local stored = tools and tools:FindFirstChild("MapKit")
	if stored then
		stored.Source = src
	end
	local Kit = Runner.module("MapKit.luau", "MapKit")
	local fn = Runner.module("Steps/" .. step .. ".luau", step)
	local t0 = os.clock()
	local res = fn(Kit)
	return string.format("%s: %s (%.1fs)", step, tostring(res), os.clock() - t0)
end

return Runner
