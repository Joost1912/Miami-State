-- Formatierungs-Helfer (Geld, Zeit)
local Format = {}

function Format.money(n)
	n = math.floor(tonumber(n) or 0)
	local s = tostring(math.abs(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if out:sub(1, 1) == "." then
		out = out:sub(2)
	end
	return (n < 0 and "-$" or "$") .. out
end

function Format.time(ts)
	return os.date("!%d.%m.%Y %H:%M", ts or os.time())
end

return Format
