--[[Terminology:
Team: "White"/"Black"
PieceType: "King"/"Queen"/etc
Piece: {.Team, .Type:PieceType .Id (for Type and Team combination)}
XXXX Piece: PieceData with .Model{.Team .Type .Model .Id (same as in PieceData)}
PieceId: Integer that represents a piece (used for efficient network replication)
	> Most code won't have to know about this

Classes:
Chess: An entire chess game with state and model
BoardState: the state of the board, with knowledge of the rules (TODO not done)
BoardModel: the model of the board, with knowledge of positioning and animation (TODO not done)

]]

local Chess = {} -- todo if we want to support white being on top, just rotate the board 180 degrees (ie the model should take care of that)

script:WaitForChild("InstallComplete")
for _, name in ipairs({"Standard", "PieceTypes"}) do
	Chess[name] = require(script[name])
end

function Chess.InBounds(pos)
	return pos.X >= 1 and pos.X <= 8 and pos.Y >= 1 and pos.Y <= 8
end
local inBounds = Chess.InBounds
Chess.__index = Chess
function Chess.new(model)
	local self = setmetatable({
		BoardState = Chess.BoardState.Standard(),
		BoardModel = Chess.BoardModel.new(model),
	}, Chess)
	self.BoardModel:SetBoardState(self.BoardState)
	return self
end

return Chess