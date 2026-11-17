-- Schritt 15: Optimierte Palmen-Vorlagen.
-- Baut 4 Palmenvarianten aus Einzelteilen und verschmilzt jede per GeometryService zu EINER Union
-- (Farben bleiben erhalten). Dazu ein unsichtbarer Stamm-Kollider. Ergebnis: ServerStorage.MapAssets.Palms.
-- Identische Union-Geometrie wird von der Engine instanziert gerendert -> weniger Draw Calls.
return function(Kit)
	local GS = game:GetService("GeometryService")
	local SS = game:GetService("ServerStorage")
	local assets = Kit.folder(SS, "MapAssets")
	local old = assets:FindFirstChild("Palms")
	if old then
		old:Destroy()
	end
	local palms = Kit.folder(assets, "Palms")

	local VARIANTS = {
		{ h = 26, seed = 11 },
		{ h = 31, seed = 23 },
		{ h = 36, seed = 37 },
		{ h = 40, seed = 53 },
	}
	local origin = Vector3.new(0, 2000, 0) -- weit weg bauen, damit nichts stoert
	local report = {}
	for i, v in ipairs(VARIANTS) do
		local tmp = Instance.new("Model")
		tmp.Parent = workspace
		local src = Kit.palmParts(tmp, origin, v.h, v.seed)
		local parts = {}
		for _, c in ipairs(src:GetChildren()) do
			if c:IsA("BasePart") then
				table.insert(parts, c)
			end
		end
		local base = table.remove(parts, 1)
		local results = GS:UnionAsync(base, parts, {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
			SplitApart = false,
		})
		local union = results[1]
		union.Name = "PalmMesh"
		union.UsePartColor = false
		union.Anchored = true
		union.CanCollide = false
		union.CanQuery = false
		union.CanTouch = false
		union.CastShadow = true

		local m = Instance.new("Model")
		m.Name = string.format("Palm_%d", i)
		union.Parent = m
		local col = Instance.new("Part")
		col.Name = "TrunkCollider"
		col.Shape = Enum.PartType.Cylinder
		col.Size = Vector3.new(v.h * 0.85, 1.6, 1.6)
		col.CFrame = CFrame.new(origin + Vector3.new(0, v.h * 0.425, 0)) * CFrame.Angles(0, 0, math.rad(90))
		col.Anchored = true
		col.Transparency = 1
		col.CastShadow = false
		col.CanTouch = false
		col.Parent = m
		m.WorldPivot = CFrame.new(origin)
		m:SetAttribute("Height", v.h)
		m.Parent = palms
		tmp:Destroy()
		table.insert(report, string.format("%s: %d Teile -> 1 Union (%s)", m.Name, #parts + 1, tostring(union.Material)))
		task.wait()
	end
	return table.concat(report, ", ")
end
