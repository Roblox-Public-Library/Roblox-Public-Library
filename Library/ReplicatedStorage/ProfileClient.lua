local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage.Remotes
local Profile = require(ReplicatedStorage.Profile)
local profile = Profile.Deserialize(remotes.GetProfile:InvokeServer())
return profile