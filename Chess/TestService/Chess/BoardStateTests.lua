return function(tests, t)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Chess = ReplicatedStorage.Chess

function tests.Fail()
	print("ChessHandler", require(game.ServerScriptService.Chess.ChessHandler))
	error("stop")
end
--[[
newBoard = BoardState.Standard()
print(newBoard:GetLastMove())


]]

end