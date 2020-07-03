local remotes = game.ReplicatedStorage.Remotes
local Profile = require(game.ReplicatedStorage.Profile)
local profile = Profile.Deserialize(remotes.GetProfile:InvokeServer())
for _, setName in ipairs({"SetMusicEnabled", "SetActivePlaylistName", "SetCustomPlaylistTrack"}) do
	local base = profile[setName]
	local remote = remotes[setName]
	profile[setName] = function(self, ...)
		if base(self, ...) then return end -- no change
		remote:FireServer(...)
	end
end
return profile