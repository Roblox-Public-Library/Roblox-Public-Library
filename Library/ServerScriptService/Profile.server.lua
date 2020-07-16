--[[TODO
Player needs to be able to do the following to a book (ignoring the gui/input):
	-Favourite
	-Like
	-Dislike
	-Mark as read
	-Mark as unread
	-Add to a custom list (in the future if not now)
	To support that functionality, we need client side functions that signal remotes that the server side is listening to.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Profile = require(ReplicatedStorage.Profile)
local Utilities = ReplicatedStorage.Utilities
local String = require(Utilities.String)
local remotes = ReplicatedStorage.Remotes

local ServerScriptService = game:GetService("ServerScriptService")
local DataStores = require(ServerScriptService.DataStores)
local profileStore = DataStores:GetDataStore("Profiles")
local oldPlaylistStore = DataStores:GetDataStore("Playlists")
local Music = require(ServerScriptService.Music)
local NewRemote = require(ServerScriptService.NewRemote)

local Players = game:GetService("Players")

local profiles = {} -- Player->Profile
Players.PlayerAdded:Connect(function(player)
	local profile
	local success, profileData = profileStore:Get(player.UserId, function() return not player.Parent end, true)
	if not player.Parent then return end
	if success then
		if profileData then
			profile = Profile.Deserialize(profileData)
		else
			profile = Profile.new()
			-- todo look up oldPlaylistStore; add to profile if it exists
		end
	else
		warn("Data store failed to load profile for", player.Name .. ":", profileData)
		profile = Profile.new()
	end
	local event = profiles[player]
	profiles[player] = profile
	if event then
		event:Fire(profile)
		event:Destroy()
	end
end)
Players.PlayerRemoving:Connect(function(player)
	local value = profiles[player]
	if typeof(value) == "Instance" then -- it's an event; a thread is waiting on the profile loading
		value:Fire(nil)
	end
	value:Destroy()
	profiles[player] = nil
end)

local function new(type, name)
	local r = Instance.new(type)
	r.Name = name
	r.Parent = remotes
	return r
end
local function getProfile(player) -- note: can return nil if the player leaves before their profile loads
	local profile = profiles[player]
	if not profile then
		local event = Instance.new("BindableEvent")
		profiles[player] = event
		profile = event.Event:Wait()
	end
	return profile
end
new("RemoteFunction", "GetProfile").OnServerInvoke = function(player)
	return getProfile(player):Serialize()
end
local function getMusic(player)
	local profile = getProfile(player)
	return profile and profile.Music
end
Music.InitRemotes(NewRemote.newFolder(remotes, "Music", getMusic))