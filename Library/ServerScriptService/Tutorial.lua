local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tutorial = require(ReplicatedStorage.Tutorial)

function Tutorial.InitRemotes(newRemote)
	newRemote:Event("Tutorial", function(player, tutorial, action)
		if action and tutorial[action] ~= nil then
			tutorial[action] = true
		end
	end)
end

return Tutorial