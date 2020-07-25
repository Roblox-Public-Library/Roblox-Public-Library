local Nexus = require("NexusUnitTesting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BookPouch = require(ReplicatedStorage.BookPouch)

local BookPouchTest = Nexus.UnitTest:Extend()
function BookPouchTest:__new(nabe, func)
	self:InitializeSuper(nabe)
	self:SetRun(function(t)
		func(t, self.b)
	end)
	Nexus:RegisterUnitTest(self)
end
function BookPouchTest:Setup()
	self.b = BookPouch.new()
end
function BookPouchTest:Teardown()
	self.b:Destroy()
end

BookPouchTest.new("Serialize/Deserialize works", function(t, b)
	b:CreateNewPlaylist("a", {123, 456})
	b:SetEnabled(false)
	local b2 = BookPouch.Deserialize(b:Serialize())
	t:AssertEquals(b2:GetEnabled(), b:GetEnabled())
	t:AssertEquals(b2:GetActivePlaylist().Id, b:GetActivePlaylist().Id)
	t:AssertEquals(b2:GetCustomPlaylists()[1].Nabe, b:GetCustomPlaylists()[1].Nabe)
end)

return true