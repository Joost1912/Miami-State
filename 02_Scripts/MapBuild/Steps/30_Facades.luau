-- Schritt 30 (Prompt 14): Fassaden beleben.
-- * Glastuerme (Shaft*): Fensterraster (Pfosten), leicht durchsichtiges Glas mit sichtbaren Buero-Etagen
--   (Geschossdecken, Kern, Deckenleuchten, Schreibtischreihen an den Fenstern).
-- * Buerobauten mit Fensterbaendern (Ribbon): Pfostenraster ueber die ganze Hoehe, Glas leicht durchsichtig,
--   dahinter beleuchtete Bueros (Deckenlicht + Arbeitsplaetze) auf einem Teil der Etagen.
-- * Wohnbauten (Windows): Fensterteilung.
-- * Lobbys der Tuerme: durchsichtig, mit Empfang, Arbeitsplaetzen, Pflanzen, Deckenlicht.
-- Alles reine Optik (keine Kollision/Raycasts/Schatten) in einem Ordner "Facade" je Gebaeude -> idempotent.
-- Geaenderte Originalteile merken ihre alte Transparenz im Attribut "OrigTransp" (Ruecknahme moeglich).
-- Aufruf: run("30_Facades") fuer alles; _G.FacadeOnly = <Model> fuer einen Probelauf an einem Gebaeude.
return function(Kit)
	local rgb = Color3.fromRGB
	local M = Enum.Material
	local DECOR = { decor = true }
	local rng = Random.new(1414)

	local FRAME_DARK = rgb(46, 52, 60)
	local FRAME_LIGHT = rgb(214, 218, 222)
	local SLAB = rgb(196, 198, 200)
	local CORE = rgb(150, 152, 156)
	local LIGHT = rgb(255, 250, 236)
	local DESK = rgb(232, 230, 226)
	local SCREEN = rgb(24, 28, 34)
	local CHAIR = rgb(40, 44, 52)
	local PLANT = rgb(70, 140, 80)

	local function setTransp(p, t)
		if p:GetAttribute("OrigTransp") == nil then
			p:SetAttribute("OrigTransp", p.Transparency)
		end
		p.Transparency = t
	end

	local function newFacade(model)
		local old = model:FindFirstChild("Facade")
		if old then
			old:Destroy()
		end
		local f = Instance.new("Folder")
		f.Name = "Facade"
		return f
	end

	-- 4 Seiten eines (um Y gedrehten) Quaders: { cf = Mitte der Flaeche, nach aussen zeigend (LookVector), w = Breite }
	local function faces(p)
		local sx, sz = p.Size.X, p.Size.Z
		local cf = p.CFrame
		return {
			{ cf = cf * CFrame.new(0, 0, -sz / 2) * CFrame.Angles(0, 0, 0), w = sx },
			{ cf = cf * CFrame.new(0, 0, sz / 2) * CFrame.Angles(0, math.pi, 0), w = sx },
			{ cf = cf * CFrame.new(sx / 2, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), w = sz },
			{ cf = cf * CFrame.new(-sx / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), w = sz },
		}
	end

	-- senkrechte Pfosten ueber eine Flaeche (Hoehe h, Mitte bei dy relativ zur Flaechenmitte)
	local function mullions(folder, face, h, dy, spacing, color, out, thick)
		local n = math.max(1, math.floor(face.w / spacing))
		local step = face.w / n
		thick = thick or 0.6
		for i = 1, n - 1 do
			local x = -face.w / 2 + i * step
			Kit.part(folder, "Mullion", Vector3.new(thick, h, thick), face.cf * CFrame.new(x, dy, -(out or 0.3)), color, M.SmoothPlastic, DECOR)
		end
	end

	-- Arbeitsplatzreihe innen entlang einer Fassade (auf Geschosshoehe yFloor relativ zur Flaechenmitte)
	local function deskRow(folder, face, yFloor, inset, maxN)
		local n = math.min(maxN or 8, math.floor((face.w - 8) / 9))
		for i = 1, n do
			if rng:NextNumber() < 0.8 then
				local x = -face.w / 2 + 4 + (i - 0.5) * ((face.w - 8) / n)
				local base = face.cf * CFrame.new(x, yFloor, inset)
				Kit.part(folder, "Desk", Vector3.new(5, 0.3, 2.4), base * CFrame.new(0, 2.6, 0), DESK, M.SmoothPlastic, DECOR)
				Kit.part(folder, "Screen", Vector3.new(2.2, 1.4, 0.2), base * CFrame.new(0, 3.5, 0.7), SCREEN, M.SmoothPlastic, DECOR)
			end
		end
	end

	----------------------------------------------------------------------------------------------------
	-- Glasturm-Schaft
	----------------------------------------------------------------------------------------------------
	local function doShaft(folder, shaft, bandStep)
		local s = shaft.Size
		setTransp(shaft, 0.32)
		shaft.Reflectance = math.max(shaft.Reflectance, 0.08)
		for _, f in ipairs(faces(shaft)) do
			mullions(folder, f, s.Y, 0, 8, FRAME_LIGHT, 0.25)
		end
		-- Kern
		Kit.part(folder, "Core", Vector3.new(s.X * 0.34, s.Y - 0.5, s.Z * 0.34), shaft.CFrame, CORE, M.Concrete, DECOR)
		-- Geschosse
		local fh = bandStep or 14
		local floors = math.floor(s.Y / fh)
		local y0 = -s.Y / 2
		for i = 1, floors do
			local y = y0 + (i - 1) * fh
			if i > 1 then
				Kit.part(folder, "Slab", Vector3.new(s.X - 1.2, 0.8, s.Z - 1.2), shaft.CFrame * CFrame.new(0, y, 0), SLAB, M.Concrete, DECOR)
			end
			-- Deckenleuchten (zwei Baender), auf 80 % der Etagen an
			if rng:NextNumber() < 0.8 then
				for _, dz in ipairs({ -s.Z * 0.3, s.Z * 0.3 }) do
					Kit.part(folder, "OfficeLight", Vector3.new(s.X - 6, 0.25, 1.6), shaft.CFrame * CFrame.new(0, y + fh - 0.7, dz), LIGHT, M.Neon, DECOR)
				end
			end
			-- Arbeitsplaetze nur im ersten Obergeschoss (von der Strasse sichtbar; mehr Etagen waeren zu viele Teile)
			if i == 2 then
				local fl = faces(shaft)
				for k = 1, 4 do
					deskRow(folder, { cf = fl[k].cf * CFrame.new(0, y, 0), w = fl[k].w }, 0, 4, 5)
				end
			end
		end
	end

	----------------------------------------------------------------------------------------------------
	-- Turm-Lobby
	----------------------------------------------------------------------------------------------------
	local function doLobby(folder, lobby)
		local s = lobby.Size
		setTransp(lobby, 0.62)
		lobby.Color = rgb(120, 150, 165)
		local base = lobby.CFrame * CFrame.new(0, -s.Y / 2, 0)
		for _, f in ipairs(faces(lobby)) do
			mullions(folder, f, s.Y, 0, 10, FRAME_DARK, 0.3, 0.8)
		end
		-- Boden, Empfang, Wartebereich, Deckenpaneele
		Kit.part(folder, "LobbyFloor", Vector3.new(s.X - 1, 0.3, s.Z - 1), base * CFrame.new(0, 0.3, 0), rgb(226, 222, 214), M.Marble, DECOR)
		Kit.part(folder, "Reception", Vector3.new(16, 3.6, 3), base * CFrame.new(0, 2.1, -s.Z * 0.18), rgb(240, 240, 238), M.Marble, DECOR)
		Kit.part(folder, "ReceptionTop", Vector3.new(16.6, 0.3, 3.4), base * CFrame.new(0, 4.05, -s.Z * 0.18), rgb(40, 44, 50), M.SmoothPlastic, DECOR)
		Kit.part(folder, "LogoWall", Vector3.new(22, 9, 0.6), base * CFrame.new(0, 5.5, -s.Z * 0.18 - 6), rgb(36, 40, 48), M.SmoothPlastic, DECOR)
		Kit.part(folder, "LogoLight", Vector3.new(14, 0.6, 0.3), base * CFrame.new(0, 7, -s.Z * 0.18 - 5.6), rgb(64, 224, 255), M.Neon, DECOR)
		for _, dx in ipairs({ -s.X * 0.3, s.X * 0.3 }) do
			Kit.part(folder, "Sofa", Vector3.new(8, 2, 3), base * CFrame.new(dx, 1.3, s.Z * 0.2), rgb(70, 74, 84), M.Fabric, DECOR)
			Kit.part(folder, "Planter", Vector3.new(2.4, 2.4, 2.4), base * CFrame.new(dx + 6, 1.5, s.Z * 0.2), rgb(60, 60, 64), M.Concrete, DECOR)
			Kit.part(folder, "Plant", Vector3.new(3.4, 4, 3.4), base * CFrame.new(dx + 6, 4.6, s.Z * 0.2), PLANT, M.Grass, { decor = true, shape = Enum.PartType.Ball })
		end
		for _, dx in ipairs({ -s.X * 0.25, 0, s.X * 0.25 }) do
			for _, dz in ipairs({ -s.Z * 0.25, s.Z * 0.25 }) do
				Kit.part(folder, "CeilingPanel", Vector3.new(10, 0.25, 4), base * CFrame.new(dx, s.Y - 0.8, dz), LIGHT, M.Neon, DECOR)
			end
		end
		-- Arbeitsplaetze an den Seitenfassaden
		local fl = faces(lobby)
		for k = 3, 4 do
			deskRow(folder, { cf = fl[k].cf * CFrame.new(0, -s.Y / 2 + 0.3, 0), w = fl[k].w }, 0, 5, 6)
		end
	end

	----------------------------------------------------------------------------------------------------
	-- Buerobau mit Fensterbaendern / Wohnbau mit Fensterstreifen
	----------------------------------------------------------------------------------------------------
	local function doRibbonBody(folder, body, ribbons)
		local s = body.Size
		local lo, hi = math.huge, -math.huge
		for _, r in ipairs(ribbons) do
			lo = math.min(lo, r.Position.Y - r.Size.Y / 2)
			hi = math.max(hi, r.Position.Y + r.Size.Y / 2)
			setTransp(r, 0.35)
		end
		local h = hi - lo
		local dy = (lo + hi) / 2 - body.Position.Y
		local dark = body.Color:Lerp(rgb(40, 44, 50), 0.35)
		for _, f in ipairs(faces(body)) do
			mullions(folder, f, h, dy, 9, dark, 0.75, 0.7)
		end
		-- beleuchtete Bueros hinter einem Teil der Fensterbaender
		for _, r in ipairs(ribbons) do
			if rng:NextNumber() < 0.6 then
				local ry = r.Position.Y - body.Position.Y
				for _, f in ipairs(faces(body)) do
					Kit.part(folder, "OfficeGlow", Vector3.new(f.w - 2, r.Size.Y - 1.2, 0.2), f.cf * CFrame.new(0, ry, -0.12), rgb(222, 214, 192), M.SmoothPlastic, DECOR)
					Kit.part(folder, "OfficeLight", Vector3.new(f.w - 2, 0.3, 0.2), f.cf * CFrame.new(0, ry + r.Size.Y / 2 - 0.9, -0.2), LIGHT, M.Neon, DECOR)
				end
			end
		end
	end

	local function doWindowStrips(folder, strips, color)
		for _, w in ipairs(strips) do
			local long = math.max(w.Size.X, w.Size.Z)
			local alongX = w.Size.X >= w.Size.Z
			local n = math.max(1, math.floor(long / 7))
			local step = long / n
			for i = 1, n - 1 do
				local off = -long / 2 + i * step
				local cf = w.CFrame * (alongX and CFrame.new(off, 0, 0) or CFrame.new(0, 0, off))
				Kit.part(folder, "Mullion", alongX and Vector3.new(0.5, w.Size.Y + 0.4, math.max(w.Size.Z, 0.2) + 0.4) or Vector3.new(math.max(w.Size.X, 0.2) + 0.4, w.Size.Y + 0.4, 0.5), cf, color, M.SmoothPlastic, DECOR)
			end
			-- Fenstersims
			Kit.part(folder, "Sill", alongX and Vector3.new(long + 0.6, 0.4, math.max(w.Size.Z, 0.2) + 0.8) or Vector3.new(math.max(w.Size.X, 0.2) + 0.8, 0.4, long + 0.6), w.CFrame * CFrame.new(0, -w.Size.Y / 2 - 0.2, 0), color, M.SmoothPlastic, DECOR)
		end
	end

	----------------------------------------------------------------------------------------------------
	-- Gebaeude finden und bearbeiten
	----------------------------------------------------------------------------------------------------
	local function process(model)
		local shafts, lobbies, bodies, ribbons, strips = {}, {}, {}, {}, {}
		for _, c in ipairs(model:GetChildren()) do
			if c:IsA("BasePart") then
				if c.Name:match("^Shaft") and c.Material == M.Glass and c.Shape == Enum.PartType.Block then
					table.insert(shafts, c)
				elseif c.Name:match("^Shaft") and c:GetAttribute("OrigTransp") ~= nil then
					-- runde Schaefte: kein Raster (Zylinder), fruehere Aenderung zuruecknehmen
					c.Transparency = c:GetAttribute("OrigTransp")
					c:SetAttribute("OrigTransp", nil)
				elseif c.Name == "Lobby" then
					table.insert(lobbies, c)
				elseif c.Name == "Body" and c.Size.Y >= 24 then
					table.insert(bodies, c)
				elseif c.Name == "Ribbon" then
					table.insert(ribbons, c)
				elseif c.Name == "Windows" and c.Material == M.Glass then
					table.insert(strips, c)
				end
			end
		end
		if #shafts + #lobbies + #ribbons + #strips == 0 then
			return 0
		end
		local folder = newFacade(model)
		-- Geschosshoehe aus den Baendern ableiten (Abstand zweier Baender), sonst 14
		local ys = {}
		for _, c in ipairs(model:GetChildren()) do
			if c:IsA("BasePart") and c.Name == "Band" then
				table.insert(ys, math.floor(c.Position.Y + 0.5))
			end
		end
		table.sort(ys)
		local step = 14
		for i = 2, #ys do
			local d = ys[i] - ys[i - 1]
			if d >= 10 and d <= 16 then
				step = d
				break
			end
		end
		for _, s in ipairs(shafts) do
			doShaft(folder, s, step)
		end
		for _, l in ipairs(lobbies) do
			doLobby(folder, l)
		end
		if #ribbons > 0 and #bodies > 0 then
			doRibbonBody(folder, bodies[1], ribbons)
		end
		if #strips > 0 then
			doWindowStrips(folder, strips, #bodies > 0 and bodies[1].Color:Lerp(rgb(255, 255, 255), 0.5) or FRAME_LIGHT)
		end
		local n = #folder:GetChildren()
		folder.Parent = model
		return n
	end

	if _G.FacadeOnly then
		local m = _G.FacadeOnly
		_G.FacadeOnly = nil
		return "Probelauf " .. m.Name .. ": " .. process(m) .. " Teile"
	end

	-- alle Gebaeude-Modelle (Modelle mit passenden direkten Kindern)
	local models, seen = {}, {}
	for _, p in ipairs(workspace.Map:GetDescendants()) do
		if p:IsA("BasePart") and (p.Name:match("^Shaft") or p.Name == "Lobby" or p.Name == "Ribbon" or p.Name == "Windows") then
			local m = p.Parent
			if m and m:IsA("Model") and not seen[m] then
				seen[m] = true
				table.insert(models, m)
			end
		end
	end
	local total, done = 0, 0
	for i, m in ipairs(models) do
		total += process(m)
		done += 1
		if i % 8 == 0 then
			game:GetService("ServerStorage"):SetAttribute("FacadeStatus", string.format("%d/%d Gebaeude, %d Teile", i, #models, total))
			task.wait()
		end
	end
	return string.format("%d Gebaeude, %d Fassadenteile", done, total)
end
