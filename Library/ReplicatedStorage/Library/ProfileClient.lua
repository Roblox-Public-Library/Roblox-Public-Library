local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage.Remotes
local Profile = require(ReplicatedStorage.Library.Profile)
local profile = Profile.Deserialize(remotes.GetProfile:InvokeServer())
return profile