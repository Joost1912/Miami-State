-- Schritt 2: Terrain. Festland, Palmetto Bay, Insel Coral Key mit Strand, Ozean.
-- Sichtbare Oberflaeche liegt 2 Studs ueber der Fuellhoehe -> Fuellung bis -2 ergibt Boden Y 0.
-- Land-Oberflaeche Y 0, Wasserspiegel Y -6.
return function(Kit)
	local T = workspace.Terrain
	local Mat = Enum.Material
	local TILE = 512

	local function fill(x0, x1, z0, z1, y0, y1, mat)
		for x = x0, x1 - 1, TILE do
			for z = z0, z1 - 1, TILE do
				local xe, ze = math.min(x + TILE, x1), math.min(z + TILE, z1)
				local size = Vector3.new(xe - x, y1 - y0, ze - z)
				T:FillBlock(CFrame.new((x + xe) / 2, (y0 + y1) / 2, (z + ze) / 2), size, mat)
				task.wait()
			end
		end
	end

	T:Clear()
	task.wait()

	local X0, X1, Z0, Z1 = -2400, 6000, -3200, 2800
	-- Meeresboden + Wasser ueberall
	fill(X0, X1, Z0, Z1, -56, -32, Mat.Sand)
	fill(X0, X1, Z0, Z1, -32, -8, Mat.Water)
	-- flachere Bucht (Palmetto Bay)
	fill(1000, 1800, Z0, Z1, -32, -20, Mat.Sand)

	-- Festland
	fill(X0, 1000, Z0, Z1, -56, -2, Mat.Grass)
	-- Insel Coral Key: Landkern + Strand
	fill(1800, 2520, -2700, 2700, -56, -2, Mat.Grass)
	fill(2520, 2640, -2700, 2700, -56, -2, Mat.Sand)
	fill(1800, 2640, -2780, -2700, -56, -4, Mat.Sand)
	fill(1800, 2640, 2700, 2780, -56, -4, Mat.Sand)
	-- Strand faellt flach ins Meer ab (X 2640 -> 2920, Oberflaeche Y 0 -> -16)
	for z = -2780, 2780 - 1, TILE do
		local ze = math.min(z + TILE, 2780)
		local len = ze - z
		T:FillWedge(
			CFrame.new(2780, -10, (z + ze) / 2) * CFrame.Angles(0, math.rad(-90), 0),
			Vector3.new(len, 16, 280),
			Mat.Sand
		)
		task.wait()
	end
	-- Uferboeschung an der Buchtseite der Insel
	fill(1780, 1800, -2700, 2700, -56, -4, Mat.Rock)

	return "Terrain ok"
end
