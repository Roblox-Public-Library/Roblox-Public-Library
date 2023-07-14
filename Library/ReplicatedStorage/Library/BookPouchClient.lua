local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BookPouch = require(ReplicatedStorage.Library.BookPouch)

local remotes = ReplicatedStorage.Remotes.BookPouch

local base = BookPouch.SetInPouch
function BookPouch:SetInPouch(id, value)
	if base(self, id, value) then return true end
	remotes.SetInPouch:FireServer(id, not not value)
end

return BookPouch