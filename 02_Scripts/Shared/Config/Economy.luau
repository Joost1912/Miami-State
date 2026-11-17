-- Wirtschafts-Konstanten (Server und Client lesen, nur der Server entscheidet)
return {
	StartCash = 500,
	StartBank = 2500,
	MaxBalance = 1_000_000_000, -- Obergrenze pro Konto
	MaxTransaction = 10_000_000, -- Obergrenze pro Einzeltransaktion
	ATMRange = 14, -- Studs: Bankaktionen nur in der Naehe eines Geldautomaten
	GiveRange = 12, -- Studs: Bargeld nur an Spieler in der Naehe
	ShopRange = 16,
	PayInterval = 600, -- Sekunden zwischen Gehaltszahlungen
	AutosaveInterval = 120, -- Sekunden zwischen automatischen Speicherungen
	HistoryLength = 25, -- gespeicherte Kontobewegungen pro Spieler
	Currency = "$",
}
