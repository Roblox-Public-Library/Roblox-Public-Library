local Nexus = require("NexusUnitTesting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Music = require(ReplicatedStorage.Music)

local MusicTest = Nexus.UnitTest:Extend()
function MusicTest:__new(name, func)
	self:InitializeSuper(name)
	self:SetRun(function(t)
		func(t, self.m)
	end)
	Nexus:RegisterUnitTest(self)
end
function MusicTest:Setup()
	self.m = Music.new()
end
function MusicTest:Teardown()
	self.m:Destroy()
end

-- MusicTest.new("NewPlaylistId returns same ID until in use", function(t, m)
-- 	local id = m:NewPlaylistId()
-- 	t:AssertEquals(m:NewPlaylistId(), id)
-- 	t:AssertEquals(m:GetPlaylistName(id), "Custom #1")
-- 	m:SetCustomPlaylistTrack(id, 1, 123)
-- 	t:AssertEquals(m:NewPlaylistId(), id + 1)
-- end)

-- MusicTest.new("Create and rename custom playlists", function(t, m)
-- 	t:AssertNil(next(m:GetCustomPlaylists()), "no custom playlists to start with")

-- 	m:SetCustomPlaylistTrack("a", 1, 123)
-- 	local playlist = m:GetCustomPlaylist("a")
-- 	t:AssertNotNil(playlist, "custom playlist exists")
-- 	t:AssertEquals(#playlist, 1, "custom playlist has 1 entry")
-- 	t:AssertEquals(playlist[1], 123, "custom playlist has correct song")

-- 	m:RenameCustomPlaylist("a", "b")
-- 	t:AssertNil(m:GetCustomPlaylist("a"), "renamed playlist's old name no longer exists")
-- 	t:AssertEquals(m:GetCustomPlaylist("b"), playlist)

-- 	-- Test adding a 2nd custom playlist
-- 	m:SetCustomPlaylistTrack("c", 1, 234)
-- 	m:SetCustomPlaylistTrack("c", 2, 235)
-- 	local c = m:GetCustomPlaylist("c")
-- 	t:AssertEquals(#c, 2)
-- 	t:AssertEquals(c[1], 234)
-- 	t:AssertEquals(c[2], 235)

-- 	-- Make sure overwriting a track works
-- 	m:SetCustomPlaylistTrack("c", 1, 236)
-- 	t:AssertEquals(#c, 2)
-- 	t:AssertEquals(c[1], 236)
-- 	t:AssertEquals(c[2], 235)
-- end)

MusicTest.new("Serialize/Deserialize works", function(t, m)
	m:CreateNewPlaylist("a", {123, 456})
	m:SetEnabled(false)
	local m2 = Music.Deserialize(m:Serialize())
	t:AssertEquals(m2:GetEnabled(), m:GetEnabled())
	t:AssertEquals(m2:GetActivePlaylist().Id, m:GetActivePlaylist().Id)
	t:AssertEquals(m2:GetCustomPlaylists()[1].Name, m:GetCustomPlaylists()[1].Name)
end)

return true