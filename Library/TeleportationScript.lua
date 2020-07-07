local TeleportRequester = require(game:GetService("ReplicatedStorage").TeleportRequester)

script.Parent.Parent.Touched:Connect(function(hit)
	TeleportRequester.TeleTouched(script.Parent.Parent.id.Value, script.Parent.Parent.placeName.Value, hit)
end)
