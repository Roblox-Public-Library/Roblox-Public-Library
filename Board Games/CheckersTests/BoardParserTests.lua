return function(tests, t)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Checkers = ReplicatedStorage.Checkers
local BoardParser = require(Checkers.BoardParser)
local Board = require(Checkers.Board)
local s = [[
.b.b.b.b
b.b.b.b.
.b.b.b.b
........
........
r.r.r.r.
.r.r.r.r
r.r.r.r.
]]

function tests.BoardParser()
	t.equals(BoardParser.ToString(BoardParser.Parse(s)), s, "ToString of Parse equals original")
end

end