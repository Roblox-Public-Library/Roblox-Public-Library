local debugging = false -- if false, tutorial will be disabled in studio

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Class = require(ReplicatedStorage.Utilities.Class)

local Tutorial = Class.New("Tutorial")

if debugging or not game:GetService("RunService"):IsStudio() then
	function Tutorial.new()
		return setmetatable({
			firstTimeFaq = false,
		}, Tutorial)
	end
else
	function Tutorial.new()
		return setmetatable({
			firstTimeFaq = true,
		}, Tutorial)
	end
end

function Tutorial:Serialize()
	return self
end
function Tutorial.Deserialize(data)
	return setmetatable(data, Tutorial)
end

return Tutorial