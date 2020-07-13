local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Utilities = ReplicatedStorage.Utilities
local Assert = require(Utilities.Assert)
local String = require(Utilities.String)

--todo for profile: NewRemote.newFolder(remotes, "Music", getMusic)

local Music = require(ReplicatedStorage.Music)
-- function Music:assertId(id, allowPlusOne)
-- 	Assert.Integer(id, 1, #self.customPlaylists + (allowPlusOne and 1 or 0)) -- todo fix
-- end
-- function Music:assertTrack(id, index)

-- end
local remoteEvents = {

}
function Music.InitRemotes(newRemote)
	newRemote:Event("SetEnabled", function(player, music, value)
		return music:SetEnabled(value)
	end)
	newRemote:Event("SetActivePlaylist", function(player, music, id)
		return music:SetActivePlaylistName(id)
	end)
	newRemote:Event("SetCustomPlaylistTrack", function(player, music, id, index, songId)
		return music:SetCustomPlaylistTrack(id, index, songId)
	end)
	newRemote:Event("RemoveCustomPlaylistTrack", function(player, music, id, index)
		return music:RemoveCustomPlaylistTrack(id, index)
	end)
	newRemote:Function("RenameCustomPlaylist", function(player, music, oldName, newName)
		--[[First value returned is 'changed' (for newFunction code)
		Remote returns: success, tryAgain
			tryAgain only returned if not success. If true, the user can try the same string again later.
		]]
		assert(type(oldName) == "string" and type(newName) == "string")
		if oldName == newName then error("Can't rename to same name") end
		-- Note: we don't care if the playlist actually exists as the client may be trying to rename a
		--if not music:GetCustomPlaylist(name) then error("No playlist with name " .. oldName) end
		if newName ~= String.Trim(newName) then error("newName is not trimmed") end
		if #newName > music.MAX_PLAYLIST_NAME_LENGTH then
			error("newName is too long")
		end
		-- We need to filter the new name unless it is like "Custom #1"
		local success, result
		if newName:match("Custom #%d+") == newName then
			success, result = true, true
		end
		local success, result = pcall(function()
			local result = TextService:FilterStringAsync(newName, player.UserId, Enum.TextFilterContext.PrivateChat)
			return result:GetNonChatStringForUserAsync(player.UserId)
		end)
		if not success then
			return false, false, true
		elseif result ~= newName then
			return false, false, false
		end
		local changed = not music:RenameCustomPlaylist(oldName, newName)
		return changed, true
	end)
end
return Music