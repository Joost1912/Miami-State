-- Schritt 32 (Prompt 14): NPC-Figuren entfernen.
-- Alle Humanoid-Modelle in der Welt (Verkaeufer, Empfang, Hehler, Jobcenter, Autohaus-Personal) werden NICHT geloescht,
-- sondern nach ServerStorage.Backup_NPCs verschoben (Attribut OrigPath = alter Ort) -> jederzeit wiederherstellbar.
-- Traegt eine Figur eine Interaktion (Tag "Interactable" am Modell oder am HumanoidRootPart), entsteht an ihrer Stelle
-- ein Objekt mit denselben Tags/Attributen: Theke mit Kasse (Laeden, Empfang), Info-Terminal (Jobcenter), Kisten (Hehler).
-- Ausnahme: Autohaus-Personal trug versehentlich die Jobcenter-Interaktion -> kein Ersatz.
-- Idempotent: bereits verschobene Figuren sind nicht mehr in der Welt; Ersatzobjekte heissen "NPCReplacement".
return function(Kit)
	local CollectionService = game:GetService("CollectionService")
	local ServerStorage = game:GetService("ServerStorage")
	local rgb = Color3.fromRGB
	local M = Enum.Material

	local backup = ServerStorage:FindFirstChild("Backup_NPCs") or Instance.new("Folder")
	backup.Name = "Backup_NPCs"
	backup.Parent = ServerStorage

	local function groundBelow(pos, ignore)
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = ignore
		local r = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -14, 0), rp)
		return r and r.Position.Y or (pos.Y - 3)
	end

	local function copyMeta(from, to)
		for k, v in pairs(from:GetAttributes()) do
			to:SetAttribute(k, v)
		end
		for _, t in ipairs(CollectionService:GetTags(from)) do
			CollectionService:AddTag(to, t)
		end
	end

	local function counter(parent, base)
		local m = Instance.new("Model")
		m.Name = "NPCReplacement"
		local main = Kit.part(m, "Counter", Vector3.new(6, 3.6, 2.4), base * CFrame.new(0, 1.8, 0), rgb(236, 234, 230), M.Marble)
		Kit.part(m, "CounterTop", Vector3.new(6.4, 0.3, 2.8), base * CFrame.new(0, 3.75, 0), rgb(40, 44, 50), M.SmoothPlastic, { decor = true })
		Kit.part(m, "Register", Vector3.new(1.6, 1, 1.2), base * CFrame.new(1.4, 4.4, 0), rgb(30, 32, 36), M.SmoothPlastic, { decor = true })
		Kit.part(m, "Screen", Vector3.new(1.4, 1, 0.15), base * CFrame.new(1.4, 5.3, 0.2) * CFrame.Angles(math.rad(-15), 0, 0), rgb(64, 224, 255), M.Neon, { decor = true })
		Kit.part(m, "Bell", Vector3.new(0.6, 0.4, 0.6), base * CFrame.new(-1.6, 4.1, -0.4), rgb(210, 180, 90), M.Metal, { decor = true, shape = Enum.PartType.Ball })
		m.PrimaryPart = main
		m.Parent = parent
		return m, main
	end

	local function terminal(parent, base)
		local m = Instance.new("Model")
		m.Name = "NPCReplacement"
		local main = Kit.part(m, "Kiosk", Vector3.new(2.4, 5, 1.4), base * CFrame.new(0, 2.5, 0), rgb(36, 40, 48), M.SmoothPlastic)
		Kit.part(m, "Display", Vector3.new(2, 2.6, 0.15), base * CFrame.new(0, 3.6, -0.75), rgb(64, 224, 255), M.Neon, { decor = true })
		Kit.part(m, "Plate", Vector3.new(3, 0.3, 2.2), base * CFrame.new(0, 0.15, 0), rgb(200, 200, 196), M.Metal, { decor = true })
		m.PrimaryPart = main
		m.Parent = parent
		return m, main
	end

	local function crates(parent, base)
		local m = Instance.new("Model")
		m.Name = "NPCReplacement"
		local main = Kit.part(m, "Crate", Vector3.new(3.4, 3, 3.4), base * CFrame.new(0, 1.5, 0), rgb(120, 90, 56), M.WoodPlanks)
		Kit.part(m, "Crate2", Vector3.new(2.6, 2.4, 2.6), base * CFrame.new(0.3, 4.2, 0.2) * CFrame.Angles(0, math.rad(20), 0), rgb(104, 78, 48), M.WoodPlanks, { decor = true })
		Kit.part(m, "Tarp", Vector3.new(3.8, 0.3, 2), base * CFrame.new(-0.2, 3.15, -0.6), rgb(40, 60, 46), M.Fabric, { decor = true })
		m.PrimaryPart = main
		m.Parent = parent
		return m, main
	end

	local moved, replaced = 0, 0
	local npcs = {}
	for _, h in ipairs(workspace:GetDescendants()) do
		if h:IsA("Humanoid") and h.Parent:IsA("Model") and not game:GetService("Players"):GetPlayerFromCharacter(h.Parent) then
			table.insert(npcs, h.Parent)
		end
	end
	for _, m in ipairs(npcs) do
		local hrp = m:FindFirstChild("HumanoidRootPart")
		-- Reihenfolge: erst HumanoidRootPart, dann Modell (die Modell-Interaktion gewinnt, z. B. Hehler "Fence" statt "NPC")
		local metaSrc = {}
		if hrp and CollectionService:HasTag(hrp, "Interactable") then
			table.insert(metaSrc, hrp)
		end
		if CollectionService:HasTag(m, "Interactable") then
			table.insert(metaSrc, m)
		end
		local inGallery = m:FindFirstAncestor("MiamiMotorGallery") ~= nil
		local cf = hrp and hrp.CFrame or m:GetPivot()
		local look = cf.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
		local gy = groundBelow(cf.Position, { m })
		local parent = m.Parent
		m:SetAttribute("OrigPath", m:GetFullName())
		m.Parent = backup
		moved += 1
		if #metaSrc > 0 and not inGallery then
			local kind = metaSrc[#metaSrc]:GetAttribute("InteractType")
			-- Ersatz steht dort, wo die Figur stand; Vorderseite zum Kunden (Blickrichtung der Figur)
			local base = CFrame.lookAt(Vector3.new(cf.X, gy, cf.Z), Vector3.new(cf.X, gy, cf.Z) + flat)
			local _, main
			if kind == "Fence" then
				_, main = crates(parent, base)
			elseif kind == "JobCenter" then
				_, main = terminal(parent, base)
			else
				_, main = counter(parent, base)
			end
			-- reine Gespraechs-NPCs ("NPC": Begruessungstext) -> Theke ohne Interaktion
			if kind ~= "NPC" then
				for _, src in ipairs(metaSrc) do
					copyMeta(src, main)
				end
			end
			main:SetAttribute("ReplacedNPC", m.Name)
			replaced += 1
		end
	end
	return string.format("%d NPC-Figuren nach ServerStorage.Backup_NPCs verschoben, %d durch Theke/Terminal/Kisten ersetzt", moved, replaced)
end
