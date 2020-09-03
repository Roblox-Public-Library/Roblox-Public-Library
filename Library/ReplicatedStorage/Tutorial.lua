local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Class = require(ReplicatedStorage.Utilities.Class)

local Tutorial = Class.New("Tutorial")

function Tutorial.new()
	return setmetatable({
		firstTimeFaq = false,
	}, Tutorial)
end

function Tutorial:Serialize()
	return self
end
function Tutorial.Deserialize(data)
	return setmetatable(data, Tutorial)
end

return Tutorial