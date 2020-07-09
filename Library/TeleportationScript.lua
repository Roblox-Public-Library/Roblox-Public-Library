local TeleportRequester = require(game:GetService("ReplicatedStorage").TeleportRequester)

script.Parent.Touched:Connect(function(hit)
	TeleportRequester.TeleTouched(script.Parent, hit)
end)
	
