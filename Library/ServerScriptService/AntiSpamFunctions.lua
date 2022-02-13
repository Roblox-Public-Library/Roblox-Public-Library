local module = {}

local pointThreshold = 10
local concerningPhrases = {
	--[list of synonyms] = points to give a phrase that contains any of those synonyms
	-- The following are whole word searches; non-whole-word-searches are added below
	[{"reward", "prize"}] = 3,
	[{"blox.page", "blox.chat", "blox.group"}] = 10,
	[{"%a*%.%a*"}] = 1, -- to catch other websites (but only 1 point because it's also a common typo)
	[{"go to", "visit"}] = 2,
	[{"get", "receive", "claim"}] = 2,
	[{"free"}] = 3,
	[{"browser", "website"}] = 4,
	[{"robux", "roux", "rebex", "r", "rs"}] = 4,
}
-- convert concerningPhrases to use whole word
for synonyms, points in pairs(concerningPhrases) do
	for i, word in ipairs(synonyms) do
		synonyms[i] = "%f[%a]" .. word .. "%f[%A]" 
	end
end
-- add non-whole-word-searches:
concerningPhrases[{"[{%[]system[%]}]", "[{%[]roblox[%]}]"}] = 4

function module.GetPointValue(msg)
	--	Returns the number of "suspiciousness" points - a message that is likely from a scammer has more points
	msg = msg:lower()
	local total = 0 -- total points found
	for synonyms, points in pairs(concerningPhrases) do
		for _, pattern in ipairs(synonyms) do
			if string.find(msg, pattern) then
				total += points
				break
			end
		end
	end
	return total
end

function module.MsgIsSuspicious(msg)
	--	Returns true if the message is suspicious (likely from a scammer)
	return module.GetPointValue(msg) >= pointThreshold
end

return module