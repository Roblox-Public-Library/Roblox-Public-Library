local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Class = require(ReplicatedStorage.Utilities.Class)
local Assert = require(ReplicatedStorage.Utilities.Assert)

local BookPouch = Class.New("BookPouch")

function BookPouch.new(bookId) -- TODO arguments are allowed but must be optional
    return setmetatable({
        bookId = Assert.Integer(bookId)
    })
end

function BookPouch:Serialize()
    return {bookId = self.bookId}
end

function BookPouch.Deserialize(data)
    return BookPouch.new()
end

--[[Profile expects:
.new():instance
:Serialize():serializedValue -- can return self if desired
.Deserialize(serializedValue):instance
Optionally can have .DeserializeDataStore(serializedValue)
]]

return BookPouch