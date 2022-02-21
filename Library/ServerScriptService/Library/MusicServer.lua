local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Utilities = ReplicatedStorage.Utilities
local Assert = require(Utilities.Assert)
local String = require(Utilities.String)

local Music = require(ReplicatedStorage.Library.Music)

local function validatePlaylistName(player, name)
	--	returns isValid, couldTryAgain (only if not valid)
	if name ~= String.Trim(name) then error("name is not trimmed") end
	if #name > Music.MAX_PLAYLIST_NAME_LENGTH then
		error("name is too long")
	end
	-- We need to filter the new name unless it is like "Custom #1"
	if name:match("Custom #%d+") == name then
		return true
	end
	local success, result = pcall(function()
		local result = TextService:FilterStringAsync(name, player.UserId, Enum.TextFilterContext.PrivateChat)
		return result:GetNonChatStringForUserAsync(player.UserId)
	end)
	if not success then
		return false, true
	end
	return result == name, false
end

function Music.InitRemotes(newRemote)
	newRemote:Event("SetEnabled", function(player, music, value)
		music:SetEnabled(value)
	end)
	newRemote:Event("SetActivePlaylist", function(player, music, id)
		music:SetActivePlaylist(music:GetPlaylist(id))
	end)
	newRemote:Function("SetCustomPlaylistTrack", function(player, music, id, index, songId)
		local problem = Music.AnyProblemWithSongId(songId)
		if problem then
			return problem
		else
			local playlist = music:GetCustomPlaylist(id)
			if #playlist.Songs >= Music.MAX_SONGS_PER_PLAYLIST then
				return "You're at the limit for songs in a single playlist"
			end
			playlist:SetSong(index, songId)
		end
	end)
	newRemote:Event("RemoveCustomPlaylistTrack", function(player, music, id, index)
		music:RemoveCustomPlaylistTrack(music:GetCustomPlaylist(id), index)
	end)
	newRemote:Function("CreateCustomPlaylist", function(player, music, data)
		--	data can have .Name and/or .Songs
		--	returns successful, playlist/problem
		data = data or {}
		local success, playlistOrProblem = music:CreateNewPlaylist(data.Name and validatePlaylistName(player, data.Name), Music.FilterSongs(data.Songs or {}))
		if success then
			return true, playlistOrProblem:Serialize()
		else
			return false, playlistOrProblem
		end
	end)
	newRemote:Function("RenameCustomPlaylist", function(player, music, id, newName)
		--	Returns filteredName on success, otherwise returns false, couldTryAgain
		--	If couldTryAgain, Roblox's service may be down; the user could try the same string again later
		local playlist = music:GetCustomPlaylist(id)
		if playlist.Name == newName then error("Can't rename to same name") end
		if newName ~= String.Trim(newName) then error("newName is not trimmed") end
		if #newName > music.MAX_PLAYLIST_NAME_LENGTH then
			error("newName is too long")
		end
		if music:GetCustomPlaylistByName(newName) then
			error("newName already in use")
		end
		-- We need to filter the new name unless it is like "Custom #1"
		local valid, couldTryAgain = validatePlaylistName(player, newName)
		if not valid then
			return valid, couldTryAgain
		end
		playlist:SetName(newName)
		return newName
	end)
	newRemote:Event("RemoveCustomPlaylist", function(player, music, id)
		music:RemoveCustomPlaylist(music:GetCustomPlaylist(id))
	end)
end
return Music