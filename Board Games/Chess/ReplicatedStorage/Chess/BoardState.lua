local v2 = Vector2.new
local PieceTypes = require(script.Parent.PieceTypes)
local BoardState = {
	WhiteKingSquare = v2(5, 1), -- todo remove the need for these
	BlackKingSquare = v2(5, 8),
}
BoardState.__index = BoardState
-- BoardState indexing constants
local lastMove = 9
local teamToRookMoved = {
	White = {
		[1] = 10,
		[8] = 11,
	},
	Black = {
		[1] = 12,
		[8] = 13,
	},
}

function BoardState.wrapNew(self)
	return setmetatable(self, BoardState)
end
function BoardState.Standard()
	-- Board instances are kept in a replicatable state
	-- board[y][x] = false or pieceTypeId
	--	Note that 'y=1' corresponds to the bottom of the board (white's home row)
	local function homeRow(team)
		local t = {"Rook", "Knight", "Bishop", "Queen", "King", "Bishop", "Knight", "Rook"}
		for i, type in ipairs(t) do
			t[i] = PieceTypes.GetId(team, type)
		end
		return t
	end
	local function pawnRow(team)
		return table.create(8, PieceTypes.GetId(team, "Pawn"))
	end
	local function emptyRow()
		return table.create(8, false)
	end
	local self = BoardState.wrapNew({
		-- White starts on row 1 in chess notation, so we'll store it to match the chess coordinates
		homeRow("White"),
		pawnRow("White"),
		emptyRow(),
		emptyRow(),
		emptyRow(),
		emptyRow(),
		pawnRow("Black"),
		homeRow("Black"),
		-- Extra data about the board state:
		-- [9] = last move in a special notation
		--	"1234" would mean "move piece (x=1,y=2) to (x=3,y=4)", where (1, 1) is where white's queen-side rook starts
		--	false means the start of the game
		--	This is needed for knowing if en-passent is legal and for knowing whose turn it is
		false,
		-- The next 4 indicate whether a rook is eligible for castling
		--	false if that rook or the king has been moved
		-- [10] is for black at x=1, [11] is for black at x=8
		-- [12] and [13] are for white at x=1 and x=8 respectively
		true, true, true, true,
		-- todo might want [14] to be whose turn it is (instead of recalculating from [9])
		-- todo might want [15] to represent "normal"/"check"/"checkmate"
		--	if it's black to move but "checkmate", that indicates white won the game
	})
end
function BoardState:GetLastMove() -- returns `from, to` or just `false` if at the beginning of the game
	local s = self[lastMove]
	if s then
		return v2(tonumber(s:sub(1, 1)), tonumber(s:sub(2, 2))),
			v2(tonumber(s:sub(3, 3)), tonumber(s:sub(4, 4)))
	else
		return false
	end
end
function BoardState:SetLastMove(from, to)
	if from then
		self[lastMove] = from.X .. from.Y .. to.X .. to.Y
	else
		self[lastMove] = false
	end
end
function BoardState:WhoseTurn()
	local from, to = self:GetLastMove()
	return to and self:Get(to).Team == "White" and "Black" or "White"
end
function BoardState:CanCastleWithRookAt(pos) -- ignoring whose turn it is
	local rook = self:Get(pos)
	if not self[teamToRookMoved[rook.Team][pos.X]] then return false end
	print("TODO look for check")
	return true
end
-- function BoardState:Clone() -- TODO delete if unneeded
-- 	local new = table.create(13)
-- 	for y = 1, 8 do
-- 		new[y] = table.move(self[y], 1, 8, 1, table.create(8))
-- 	end
-- 	for i = 9, 13 do
-- 		new[i] = self[i]
-- 	end
-- 	return setmetatable(new, BoardState)
-- end
function BoardState:Get(pos) -- returns piece at 'pos' with {.Id:number .Team:string .Type:string} or false
	return self[pos.Y][pos.X]
end
function BoardState:move(from, to)
	local fromY = self[from.Y]
	local toY = self[to.Y]
	fromY[from.X], toY[to.X] = false, fromY[from.X]
end
function BoardState:remove(pos)
	self[pos.Y][pos.X] = false
end

function BoardState:ForEachPiece(func)
	--	Run func(pos, pieceData) for each piece on the board until func returns a truthy value
	for y, row in ipairs(self) do
		for x, pieceData in ipairs(row) do
			if pieceData then
				local v = func(v2(x, y), pieceData)
				if v then return v end
			end
		end
	end
end
-- todo Write tests for BoardState to handle rules
--	everything from basic legal moves to whether castling is working
--	For ideas, should read the comments in the existing functions MoveIsLegal and determineCheckState
return BoardState