local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local remotes = ReplicatedStorage.Remotes
local Profile = require(ReplicatedStorage.Profile)
local profile = Profile.Deserialize(remotes.GetProfile:InvokeServer())
for _, setName in ipairs({"SetMusicEnabled", "SetActivePlaylistName", "SetCustomPlaylistTrack", "RemoveCustomPlaylistTrack"}) do
	local base = profile[setName]
	local remote = remotes[setName]
	profile[setName] = function(self, ...)
		if base(self, ...) then return true end -- no change
		remote:FireServer(...)
	end
end
function profile:InvokeRenameCustomPlaylist(oldName, newName)
	--	returns true if rename was successful (yields)
	local success, tryAgain = remotes.RenameCustomPlaylist:InvokeServer(oldName, newName)
	if not success then
		StarterGui:SetCore("SendNotification", {
			Title = ("'%s' Rename Failed"):format(oldName),
			Text = tryAgain
				and "Roblox encountered a problem; try the name again later"
				or "That name was filtered",
			Duration = 4,
		})
		return false
	else
		profile:RenameCustomPlaylist(oldName, newName)
		return true
	end
end
return profile