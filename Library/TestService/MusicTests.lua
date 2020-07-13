local Nexus = require("NexusUnitTesting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Music = require(ReplicatedStorage.Music)

local MusicTest = Nexus.UnitTest:Extend()
function MusicTest:__new(name, func)
	self:InitializeSuper(name)
	self:SetRun(function(t)
		func(t, self.p)
	end)
	Nexus:RegisterUnitTest(self)
end
function MusicTest:Setup()
	self.p = Music.new()
end
function MusicTest:Teardown()
	self.p:Destroy()
end

MusicTest.new("Create and rename custom playlists", function(t, p)
	t:AssertNil(next(p:GetCustomPlaylists()), "no custom playlists to start with")
	p:SetCustomPlaylistTrack("a", 1, 123)
	local playlist = p:GetCustomPlaylist("a")
	t:AssertNotNil(playlist, "custom playlist exists")
	t:AssertEquals(#playlist, 1, "custom playlist has 1 entry")
	t:AssertEquals(playlist[1], 123, "custom playlist has correct song")

	p:RenameCustomPlaylist("a", "b")
	t:AssertNil(p:GetCustomPlaylist("a"), "renamed playlist's old name no longer exists")
	t:AssertEquals(p:GetCustomPlaylist("b"), playlist)

	-- Test adding a 2nd custom playlist
	p:SetCustomPlaylistTrack("c", 1, 234)
	p:SetCustomPlaylistTrack("c", 2, 235)
	local c = p:GetCustomPlaylist("c")
	t:AssertEquals(#c, 2)
	t:AssertEquals(c[1], 234)
	t:AssertEquals(c[2], 235)

	-- Make sure overwriting a track works
	p:SetCustomPlaylistTrack("c", 1, 236)
	t:AssertEquals(#c, 2)
	t:AssertEquals(c[1], 236)
	t:AssertEquals(c[2], 235)
end)

return true