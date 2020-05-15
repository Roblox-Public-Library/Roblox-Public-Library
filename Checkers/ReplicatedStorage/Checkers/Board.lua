local Board = {}
Board.__index = Board
--[[
Roblox cannot send tables with numeric keys unless there are no holes in the array (and no string keys).
Board maintains state in a way that Roblox will serialize very efficiently.
It converts between the serialized values and the values used by the rest of the scripts with the dictionaries below.
]]
local valueToSerialized = {
	[false] = 0, -- no piece
	r = 1, -- red piece
	b = 2, -- black piece
	R = 3, -- kinged red piece
	B = 4, -- kinged black piece
}
local serializedToValue = {}
for k, v in pairs(valueToSerialized) do serializedToValue[v] = k end
local pawnToKing = {
	r = "R",
	b = "B",
}

local function Assert(value, _typeof)
	--	Note: do not use with _typeof == "boolean"
	return typeof(value) == _typeof and value or error("Value must be " .. _typeof, 3)
end
local function posOnBoard(pos)
	return pos.X >= 1 and pos.X <= 8 and pos.Y >= 1 and pos.Y <= 8
end
local function AssertPos(pos)
	Assert(pos, "Vector2")
	if not posOnBoard(pos) then
		error("Invalid board position: " .. tostring(pos), 3)
	end
	return pos
end

local v2 = Vector2.new
local pawnMovesUp = {v2(-1, -1), v2(1, -1)}  -- should these be redPawnMoves
local pawnMovesDown = {v2(-1, 1), v2(1, 1)}  -- and blackPawnMoves
local kingMoves = {v2(-1, -1), v2(1, -1), v2(-1, 1), v2(1, 1)}
local function setPawnMoves(self, redOnTop)
	self.pawnMoves = {
		Red = redOnTop and pawnMovesDown or pawnMovesUp,
		Black = redOnTop and pawnMovesUp or pawnMovesDown,
		King = kingMoves,
	}
	self.redOnTop = not not redOnTop -- ensure that it is a boolean (required by promotion code)
	return self
end
--[[Other elements of Board:
	.teamCanCapture = nil or [team] = true/false -- a cache of :IsCapturePossible(team)
]]
function Board.new(redOnTop)
	--	redOnTop: if true, put red on top instead of on bottom
	local grid = {}
	local top = valueToSerialized[redOnTop and "r" or "b"]
	local bottom = valueToSerialized[redOnTop and "b" or "r"]
	local empty = valueToSerialized[false]
	for x = 1, 8 do
		local column = {}
		grid[x] = column
		for y = 1, 8 do
			column[y] = ((x + y) % 2 == 1 and (y <= 3 and top or y >= 6 and bottom)) or empty
		end
	end
	return setPawnMoves(setmetatable({grid = grid}, Board), redOnTop)
end
function Board.blank(redOnTop)
	local grid = {}
	local empty = valueToSerialized[false]
	for x = 1, 8 do
		grid[x] = {}
		for y = 1, 8 do
			column[y] = empty
		end
	end
	return setPawnMoves(setmetatable({
		grid = grid
	}, Board), redOnTop)
end
function Board.fromGrid(grid, redOnTop)
	local board = {}
	for x = 1, 8 do
		local column = {}
		board[x] = column
		for y = 1, 8 do
			column[y] = valueToSerialized[grid[x][y]]
		end
	end
	return setPawnMoves(setmetatable({grid=board}, Board), redOnTop)
end
function Board.Deserialize(board)
	-- Server->client only
	return setmetatable(board, Board)
end
function Board:Get(pos)
	AssertPos(pos)
	return serializedToValue[self.grid[pos.X][pos.Y]]
end
function Board:Set(pos, value)
	AssertPos(pos)
	self.grid[pos.X][pos.Y] = valueToSerialized[value or false]
	self.teamCanCapture = nil
end
local pieceToTeam = {
	r = "Red",
	R = "Red",
	b = "Black",
	B = "Black",
}
local isPawn = {r = true, b = true}
function Board:GetPieceOwner(pos)
	return pieceToTeam[self:Get(pos)]
end
local function cloneTable(t)
	local new = {}
	for k, v in pairs(t) do
		new[k] = v
	end
	return new
end
local function deepClone(t)
	if type(t) ~= "table" then return t end
	local new = {}
	for k, v in pairs(t) do
		new[k] = deepClone(v)
	end
	return new
end
function Board:Clone()
	local new = cloneTable(self)
	new.grid = deepClone(new.grid)
	return setmetatable(new, Board)
end
function Board:IterPieces(team)
	--	iteration returns pos, piece
	local y, x = 1, 0
	return function()
		local pos, piece
		repeat
			x = x + 1
			if x > 8 then
				y = y + 1
				if y > 8 then return nil end
				x = 1
			end
			pos = v2(x, y)
			piece = self:Get(pos)
		until piece and pieceToTeam[piece] == team
		return pos, piece
	end
end
function Board:iterMoves(pos)
	--	Iterates over all valid coordinates that the piece on 'pos' might move (not jump) to
	--	Does not check to see if the move is available, but does perform bounds checking
	--	Iterator returns targetPos, dir
	local i = 0
	local piece = self:Get(pos)
	local t = isPawn[piece] and self.pawnMoves[pieceToTeam[piece]] or kingMoves
	return function()
		local v, dir
		repeat
			i = i + 1
			dir = t[i]
			v = dir and dir + pos
		until not dir or posOnBoard(v)
		return v, dir
	end
end

local Move = {}
Move.__index = Move
Board.Move = Move
local function AssertList(list, func, ...)
	Assert(list, "table")
	for _, obj in ipairs(list) do func(obj, ...) end
	return list
end

function Move.new(pieceCoord, coords)
	local self = setmetatable({
		pieceCoord = AssertPos(pieceCoord), --:Vector2 where the piece is located
		coords = AssertList(coords, AssertPos), --:List<Vector2> to move to
	}, Move)
	if #self.coords == 0 then error("Move must contain 1+ destination coords", 2) end
	return self
end
function Move.FromClient(move)
	if type(move) ~= "table"
			or typeof(move.pieceCoord) ~= "Vector2"
			or not validateList(move.coords, function(v) return typeof(v) == "Vector2" and v end)
			or #move.coords == 0 then
		return false
	end
	return setmetatable(move, Move)
end
local function coordListToKey(list)
	local t = {}
	for i, coord in ipairs(list) do
		t[i] = tostring(coord)
	end
	return table.concat(t, "; ")
end
function Move:ToKey()
	return ("%s -> %s"):format(tostring(self.pieceCoord), coordListToKey(self.coords))
end

function Board:move(from, to) -- returns true if a promotion occurred
	local piece = self:Get(from)
	self:Set(from, nil)
	local shouldPromote = self:ShouldPromotePawn(piece, to)
	self:Set(to, shouldPromote and pawnToKing[piece] or piece)
	return shouldPromote
end
-- todo perhaps :move should be undoableMove (or have both)
function Board:undoableJump(pos, captureCoord, targetCoord, prevUndo) -- returns true if a promotion occurred, followed by the undo function
	local origPiece = self:Get(pos)
	local enemyPiece = self:Get(captureCoord)
	local promoted = self:move(pos, targetCoord)
	self:Set(captureCoord, nil)
	local undo = function()
		self:Set(captureCoord, enemyPiece)
		self:Set(pos, origPiece)
		self:Set(targetCoord, nil)
		if prevUndo then prevUndo() end
	end
	return promoted, undo
end
function Board:TryMove(team, move)
	--	team: "Red" or "Black"
	--	returns legalMove, List<game events>
	Assert(team, "string")
	Assert(move, "table")
	local pos = move.pieceCoord
	if team ~= self:GetPieceOwner(pos) then return false end
	local piece = self:Get(pos)
	if #move.coords == 1 then -- Check non-jumping moves
		local targetCoord = move.coords[1]
		if self:Get(targetCoord) then return false end -- can't move onto a piece
		for targetPos in self:iterMoves(pos) do
			if targetPos == targetCoord then -- Valid target
				if self:IsCapturePossible(team) then return false end -- can't move when capture possible
				self:move(pos, targetCoord)
				return true -- todo return list of events
			end
		end
		-- Don't return false because it may have been a single jump
	end
	-- Check for 1+ jumps
	local promoted
	local prevTCC = self.teamCanCapture
	local undo = function() self.teamCanCapture = prevTCC end
	for _, nextCoord in ipairs(move.coords) do
		-- ex, pos might be 1,1; first coord might be 3,3
		if promoted then undo(); return false end -- cannot jump further after receiving a promotion
		if self:Get(nextCoord) then undo(); return false end -- cannot land on another piece
		local diff = nextCoord - pos
		if math.abs(diff.X) ~= 2 or math.abs(diff.Y) ~= 2 then undo(); return false end
		local captureCoord = (pos + nextCoord) / 2
		if not self:Get(captureCoord) or self:GetPieceOwner(captureCoord) == team then undo(); return false end -- must jump over an enemy piece
		-- Make sure the jump is in a valid direction for the pawn
		local found = false
		for targetPos in self:iterMoves(pos) do
			if targetPos == captureCoord then
				found = true
				break
			end
		end
		if not found then undo(); return false end
		promoted, undo = self:undoableJump(pos, captureCoord, nextCoord, undo)
		pos = nextCoord
	end
	if not promoted and self:canPieceCapture(move.coords[#move.coords]) then -- can't stop capturing
		undo()
		return false
	end
	return true -- todo return list of events
end

function Board:ShouldPromotePawn(piece, targetCoord)
	local team = pieceToTeam[piece]
	return pawnToKing[piece] -- must be a pawn
		and targetCoord.Y == (self.redOnTop == (team == "Red") and 8 or 1)
end

function Board:GetValidMoves(team, pieceCoord)
	AssertPos(pieceCoord)
	Assert(self:Get(pieceCoord), "string") -- otherwise nothing there
	local team = self:GetPieceOwner(pieceCoord)
	local validMoves = {}
	if self:IsCapturePossible(team) then
		local function searchForJumps(pos, getTable)
			--	extends validMoves with each move found
			for targetPos, dir in self:iterMoves(pos) do
				if self:canPieceCaptureInDir(pos, dir) then
					local capturePos = targetPos
					targetPos = targetPos + dir
					local function newGetTable()
						local t = getTable()
						t[#t + 1] = targetPos
						return t
					end
					-- make the move, search for jumps, then undo the move
					local promote, undo = self:undoableJump(pos, capturePos, targetPos)
					if not promote and self:canPieceCapture(targetPos) then -- recurse
						searchForJumps(targetPos, newGetTable)
					else -- can stop here; record move
						validMoves[#validMoves + 1] = Move.new(pieceCoord, newGetTable())
					end
					undo()
				end
			end
		end
		searchForJumps(pieceCoord, function() return {} end)
	else -- check non-jumping moves
		for targetPos, dir in self:iterMoves(pieceCoord) do
			if not self:Get(targetPos) then
				validMoves[#validMoves + 1] = Move.new(pieceCoord, {targetPos})
			end
		end
	end
	return validMoves
end

function Board:GetAllValidMoves(team)
	--	Returns Dictionary<"x y", List<Move>>
	Assert(team, "string")
	local allMoves = {}
	for pos, piece in self:IterPieces(team) do
		allMoves[("%d %d"):format(x, y)] = self:GetValidMoves(pos)
	end
	return allMoves
end
function Board:canPieceCaptureInDir(pos, dir)
	local team = pieceToTeam[self:Get(pos)]
	local midPos = pos + dir
	local otherPiece = self:Get(midPos)
	if otherPiece and team ~= pieceToTeam[otherPiece] then
		local jumpPos = midPos + dir
		if posOnBoard(jumpPos) and not self:Get(jumpPos) then
			return true
		end
	end
	return false
end
function Board:canPieceCapture(pos)
	--	Assumes there is a piece at pos; returns true if it can capture an enemy piece
	local piece = self:Get(pos)
	local team = pieceToTeam[piece]
	for targetPos, dir in self:iterMoves(pos) do
		if self:canPieceCaptureInDir(pos, dir) then
			return true
		end
	end
	return false
end
local function isCapturePossible(self, team)
	--	Call :IsCapturePossible to get the cached version
	-- For each piece on team, return true if it could jump over a piece
	for y = 1, 8 do
		for x = 1, 8 do
			local pos = v2(x, y)
			if self:GetPieceOwner(pos) == team and self:canPieceCapture(pos) then
				return true
			end
		end
	end
	return false
end
function Board:IsCapturePossible(team)
	local teamCanCapture = self.teamCanCapture
	if not teamCanCapture then
		teamCanCapture = {}
		self.teamCanCapture = teamCanCapture
	end
	if teamCanCapture[team] == nil then
		teamCanCapture[team] = isCapturePossible(self, team) or false
	end
	return teamCanCapture[team]
end

return Board