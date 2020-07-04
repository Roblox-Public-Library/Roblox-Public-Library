local Nexus = require("NexusUnitTesting")

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

Nexus:RegisterUnitTest("BoardParser", function(t)
	t:AssertEquals(s, BoardParser.ToString(BoardParser.Parse(s)), "ToString of Parse equals original")
end)
return true