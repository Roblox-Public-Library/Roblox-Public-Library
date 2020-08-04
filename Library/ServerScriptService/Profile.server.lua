--[[TODO
Player needs to be able to do the following to a book (ignoring the gui/input):
	-Favourite
	-Like
	-Dislike
	-Mark as read
	-Mark as unread
	-Add to book pouch
	To support that functionality, we need client side functions that signal remotes that the server side is listening to.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Profile = require(ReplicatedStorage.Profile)
local remotes = ReplicatedStorage.Remotes
local AUTOSAVE_FREQ = 60

local ServerScriptService = game:GetService("ServerScriptService")
local DataStores = require(ServerScriptService.DataStores)
local profileStore = DataStores:GetDataStore("Profiles")
local oldPlaylistStore = DataStores:GetDataStore("Playlists")
local Music = require(ServerScriptService.MusicServer)
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
			local success, songs = oldPlaylistStore:Get("user_" .. player.UserId, function() return not player.Parent end, true)
			if success then
				if songs then
					profile.Music:CreateNewPlaylist(nil, Music.FilterSongs(songs))
				end
			else
				warn("Data store failed to load old profile for", player.Name .. ":", songs)
			end
		end
	else
		warn("Data store failed to load profile for", player.Name .. ":", profileData)
		profile = Profile.new()
	end
	local event = profiles[player]
	profiles[player] = profile
	if event then
		event:Fire()
		event:Destroy()
	end
	while true do
		wait(AUTOSAVE_FREQ)
		if not player.Parent then break end
		profileStore:SetFunc(player.UserId, function()
			return profile:Serialize()
		end, function() return not player.Parent end)
	end
end)
local function pcallLog(func)
	local success, msg = pcall(func)
	if not success then
		warn(debug.traceback(msg))
	end
	return success, msg
end
Players.PlayerRemoving:Connect(function(player)
	local profile = profiles[player]
	pcallLog(function()
		if typeof(profile) == "Instance" then -- it's an event; a thread is waiting on the profile loading
			profile:Fire(nil)
		else
			pcall(function()
				profileStore:Set(player.UserId, profile:Serialize())
			end)
		end
		profile:Destroy()
	end)
	profiles[player] = nil
end)

game:BindToClose(function()
	while next(profiles) do
		wait()
	end
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
		event.Event:Wait()
		profile = profiles[player]
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