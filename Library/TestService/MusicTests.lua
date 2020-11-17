local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Music = require(ReplicatedStorage.Music)
return function(tests, t)

local function addMusic(t)
	t.setup = function() return Music.new() end
	t.cleanup = function(m) m:Destroy() end
	return t
end
local function musicTest(name, test)
	if type(test) == "function" then
		test = {test = test}
	end
	tests[name] = addMusic(test)
end

-- musicTest("NewPlaylistId returns same ID until in use", function(m)
-- 	local id = m:NewPlaylistId()
-- 	t.equals(m:NewPlaylistId(), id)
-- 	t.equals(m:GetPlaylistName(id), "Custom #1")
-- 	m:SetCustomPlaylistTrack(id, 1, 123)
-- 	t.equals(m:NewPlaylistId(), id + 1)
-- end)

-- musicTest("Create and rename custom playlists", function(m)
-- 	t.equals(next(m:GetCustomPlaylists()), nil, "no custom playlists to start with")

-- 	m:SetCustomPlaylistTrack("a", 1, 123)
-- 	local playlist = m:GetCustomPlaylist("a")
-- 	t.truthy(playlist, "custom playlist exists")
-- 	t.equals(#playlist, 1, "custom playlist has 1 entry")
-- 	t.equals(playlist[1], 123, "custom playlist has correct song")

-- 	m:RenameCustomPlaylist("a", "b")
-- 	t.equals(m:GetCustomPlaylist("a"), nil, "renamed playlist's old name no longer exists")
-- 	t.equals(m:GetCustomPlaylist("b"), playlist)

-- 	-- Test adding a 2nd custom playlist
-- 	m:SetCustomPlaylistTrack("c", 1, 234)
-- 	m:SetCustomPlaylistTrack("c", 2, 235)
-- 	local c = m:GetCustomPlaylist("c")
-- 	t.equals(#c, 2)
-- 	t.equals(c[1], 234)
-- 	t.equals(c[2], 235)

-- 	-- Make sure overwriting a track works
-- 	m:SetCustomPlaylistTrack("c", 1, 236)
-- 	t.equals(#c, 2)
-- 	t.equals(c[1], 236)
-- 	t.equals(c[2], 235)
-- end)

musicTest("Serialize/Deserialize works", function(m)
	m:CreateNewPlaylist("a", {123, 456})
	m:SetEnabled(false)
	local m2 = Music.Deserialize(m:Serialize())
	t.equals(m2:GetEnabled(), m:GetEnabled())
	t.equals(m2:GetActivePlaylist().Id, m:GetActivePlaylist().Id)
	t.equals(m2:GetCustomPlaylists()[1].Name, m:GetCustomPlaylists()[1].Name)
end)

end