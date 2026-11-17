-- Schritt 16: Ersetzt alte Einzelteil-Palmen durch optimierte Union-Palmen.
-- Bereich ueber Attribut "PalmScope" an ServerStorage.MapBuildTools (Pfad unter workspace.Map, z.B. "Districts/CoralKey").
-- Position, Hoehe und Ausrichtung werden aus der alten Palme uebernommen. Neue Palmen sind am Attribut "Optimized" erkennbar.
return function(Kit)
	local tools = game:GetService("ServerStorage").MapBuildTools
	local scope = tools:GetAttribute("PalmScope") or ""
	local root = workspace.Map
	for seg in scope:gmatch("[^/]+") do
		root = root:FindFirstChild(seg)
		assert(root, "PalmScope nicht gefunden: " .. scope)
	end
	local old = {}
	for _, m in ipairs(root:GetDescendants()) do
		if m:IsA("Model") and m.Name == "Palm" and not m:FindFirstChild("PalmMesh") then
			table.insert(old, m)
		end
	end
	local replaced, partsBefore, partsAfter = 0, 0, 0
	for i, m in ipairs(old) do
		local trunk = m:FindFirstChild("Trunk")
		if trunk then
			local base = (trunk.CFrame * CFrame.new(-trunk.Size.X / 2, 0, 0)).Position
			local h = 0
			for _, c in ipairs(m:GetChildren()) do
				if c.Name == "Trunk" then
					h += c.Size.X - 0.4
				end
				if c:IsA("BasePart") then
					partsBefore += 1
				end
			end
			local n = Kit.palm(m.Parent, base, h, math.floor(base.X * 7 + base.Z * 13))
			n:SetAttribute("Optimized", true)
			for _, c in ipairs(n:GetChildren()) do
				if c:IsA("BasePart") then
					partsAfter += 1
				end
			end
			m:Destroy()
			replaced += 1
		end
		if i % 50 == 0 then
			task.wait()
		end
	end
	return string.format("%s: %d Palmen ersetzt, Parts %d -> %d", scope, replaced, partsBefore, partsAfter)
end
