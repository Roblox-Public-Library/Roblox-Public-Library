local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage.Remotes
local Profile = require(ReplicatedStorage.Library.Profile)
-- Require client versions so that they are used when constructing the profile
for module in Profile.moduleToKey do
	require(ReplicatedStorage.Library[module .. "Client"])
end
local profile = Profile.Deserialize(remotes.GetProfile:InvokeServer())
local reason = profile:IsTemporary()
if reason then
	local StarterGui = game:GetService("StarterGui")
	if reason == "error" then
		StarterGui:SetCore("SendNotification", {
			Title = "Profile Error",
			Text = "Your profile failed to load. Changes you make won't be saved! Please contact support to get this fixed.",
			Duration = 60,
		})
	elseif reason == "down" then
		StarterGui:SetCore("SendNotification", {
			Title = "Roblox Data Stores Down",
			Text = "Your profile could not be loaded. Changes you make won't be saved! Try again later.",
			Duration = 60,
		})
	else
		StarterGui:SetCore("SendNotification", {
			Title = "Profile Error",
			Text = "Your profile failed to load. Please contact support.",
			Duration = 60,
		})
	end
end

return profile