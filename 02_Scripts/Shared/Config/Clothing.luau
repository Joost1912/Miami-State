-- Kleidung (Kleidungsgeschaeft). Eigene Inhalte ohne fremde Assets: Farben am Koerper + einfache Teile als Accessoires.
-- Slot: Top (Oberteil), Bottom (Hose), Hat (Kopf), Glasses (Brille), Shoes (Schuhe)
-- Top.Sleeves = true -> Arme in Stofffarbe (lange Aermel), sonst Hautfarbe.
-- Neue Kleidung: Eintrag in Defs + Preis im Katalog "Clothing" (Config.Shops).
local C = {}

C.Slots = {
	{ Id = "Top", Name = "Oberteile" },
	{ Id = "Bottom", Name = "Hosen" },
	{ Id = "Shoes", Name = "Schuhe" },
	{ Id = "Hat", Name = "Kopfbedeckung" },
	{ Id = "Glasses", Name = "Brillen" },
}

local rgb = Color3.fromRGB
C.Defs = {
	-- Oberteile
	Tee_White = { Slot = "Top", Name = "T-Shirt Weiss", Color = rgb(238, 238, 234) },
	Tee_Black = { Slot = "Top", Name = "T-Shirt Schwarz", Color = rgb(30, 31, 36) },
	Tee_Coral = { Slot = "Top", Name = "T-Shirt Koralle", Color = rgb(232, 120, 104) },
	Tee_Teal = { Slot = "Top", Name = "T-Shirt Petrol", Color = rgb(28, 128, 136) },
	Polo_Navy = { Slot = "Top", Name = "Polo Navy", Color = rgb(34, 48, 86) },
	Polo_Mint = { Slot = "Top", Name = "Polo Mint", Color = rgb(150, 210, 186) },
	Shirt_Linen = { Slot = "Top", Name = "Leinenhemd Sand", Color = rgb(220, 204, 170), Sleeves = true },
	Shirt_Hawaii = { Slot = "Top", Name = "Hawaiihemd Blau", Color = rgb(52, 120, 200), Accent = rgb(250, 210, 90) },
	Hoodie_Grey = { Slot = "Top", Name = "Hoodie Grau", Color = rgb(120, 124, 132), Sleeves = true },
	Hoodie_Black = { Slot = "Top", Name = "Hoodie Schwarz", Color = rgb(26, 27, 32), Sleeves = true },
	Jacket_Denim = { Slot = "Top", Name = "Jeansjacke", Color = rgb(70, 100, 150), Sleeves = true },
	Blazer_Navy = { Slot = "Top", Name = "Blazer Navy", Color = rgb(28, 36, 64), Sleeves = true, Accent = rgb(240, 240, 240) },
	Blazer_White = { Slot = "Top", Name = "Blazer Weiss (Miami Vice)", Color = rgb(236, 232, 222), Sleeves = true, Accent = rgb(240, 150, 170) },
	-- Hosen
	Jeans_Blue = { Slot = "Bottom", Name = "Jeans Blau", Color = rgb(52, 74, 112) },
	Jeans_Black = { Slot = "Bottom", Name = "Jeans Schwarz", Color = rgb(28, 29, 34) },
	Chinos_Beige = { Slot = "Bottom", Name = "Chino Beige", Color = rgb(196, 176, 140) },
	Chinos_Olive = { Slot = "Bottom", Name = "Chino Oliv", Color = rgb(96, 100, 70) },
	Shorts_Khaki = { Slot = "Bottom", Name = "Shorts Khaki", Color = rgb(176, 160, 120), Short = true },
	Shorts_Navy = { Slot = "Bottom", Name = "Shorts Navy", Color = rgb(40, 52, 88), Short = true },
	Suit_Navy = { Slot = "Bottom", Name = "Anzughose Navy", Color = rgb(28, 36, 64) },
	Joggers_Grey = { Slot = "Bottom", Name = "Jogginghose Grau", Color = rgb(110, 114, 122) },
	-- Schuhe
	Sneakers_White = { Slot = "Shoes", Name = "Sneaker Weiss", Color = rgb(240, 240, 240) },
	Sneakers_Black = { Slot = "Shoes", Name = "Sneaker Schwarz", Color = rgb(26, 26, 30) },
	Loafers_Brown = { Slot = "Shoes", Name = "Loafer Braun", Color = rgb(96, 62, 40) },
	Boots_Tan = { Slot = "Shoes", Name = "Boots Hellbraun", Color = rgb(160, 112, 70) },
	-- Kopfbedeckung
	Cap_Black = { Slot = "Hat", Name = "Basecap Schwarz", Color = rgb(28, 28, 32), Model = "Cap" },
	Cap_Teal = { Slot = "Hat", Name = "Basecap Tuerkis", Color = rgb(30, 170, 180), Model = "Cap" },
	Cap_Red = { Slot = "Hat", Name = "Basecap Rot", Color = rgb(190, 40, 46), Model = "Cap" },
	Beanie_Grey = { Slot = "Hat", Name = "Muetze Grau", Color = rgb(118, 120, 128), Model = "Beanie" },
	Fedora_Straw = { Slot = "Hat", Name = "Strohhut", Color = rgb(214, 190, 130), Model = "Fedora" },
	Bucket_White = { Slot = "Hat", Name = "Fischerhut Weiss", Color = rgb(236, 234, 228), Model = "Bucket" },
	-- Brillen
	Shades_Black = { Slot = "Glasses", Name = "Sonnenbrille Schwarz", Color = rgb(20, 20, 24), Model = "Shades" },
	Shades_Gold = { Slot = "Glasses", Name = "Pilotenbrille Gold", Color = rgb(60, 50, 30), Frame = rgb(212, 175, 90), Model = "Shades" },
	Glasses_Clear = { Slot = "Glasses", Name = "Lesebrille", Color = rgb(200, 220, 230), Frame = rgb(40, 40, 44), Model = "Glasses" },
}

C.MaxOutfits = 6

return C
