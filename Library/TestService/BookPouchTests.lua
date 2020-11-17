local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BookPouch = require(ReplicatedStorage.BookPouch)
return function(tests, t)

tests["Serialize/Deserialize works"] = {
	setup = function() return BookPouch.new() end,
	cleanup = function(b) b:Destroy() end,
	test = function(b)
		b:CreateNewPlaylist("a", {123, 456})
		b:SetEnabled(false)
		local b2 = BookPouch.Deserialize(b:Serialize())
		t.equals(b2:GetEnabled(), b:GetEnabled())
		t.equals(b2:GetActivePlaylist().Id, b:GetActivePlaylist().Id)
		t.equals(b2:GetCustomPlaylists()[1].Name, b:GetCustomPlaylists()[1].Name)
	end,
	skip = true
}

end