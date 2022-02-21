local Board = {}
Board.__index = Board
--[[
Roblox cannot send tables with numeric keys unless there are no holes in the array (and no string keys).
Board maintains state in a way that can be sent over the network efficiently.
Possible values:
	false: no piece
	r: red piece
	b: black piece
	R: kinged red piece
	B: kinged black piece
]]
local pawnToKing = {
	r = "R",
	b = "B",
}
local pieceToTeam = {
	r = "Red",
	R = "Red",
	b = "Black",
	B = "Black",
}
Board.PieceToTeam = pieceToTeam
local oppositeTeam = {
	Red = "Black",
	Black = "Red",
}
local isPawn = {r = true, b = true}
Board.IsPawn = isPawn

local function Assert(value, _typeof)
	return if typeof(value) == _typeof then value else error("Value must be " .. _typeof, 3)
end
local function posOnBoard(pos)
	return pos.X >= 1 and pos.X <= 8 and pos.Y >= 1 and pos.Y <= 8
end
local function AssertPos(pos)
	if typeof(pos) ~= "Vector2" then error("pos must be Vector2", 3) end
	if not posOnBoard(pos) then
		error("Invalid board position: " .. tostring(pos), 3)
	end
	return pos
end
local function validate(var, type)
	return typeof(var) == type and var
end
local function validateListContents(list, func, ...)
	for _, v in ipairs(list) do
		if not func(v, ...) then return false end
	end
	return list
end
local function validateList(list, func, ...)
	return validate(list, "table") and validateListContents(list, func, ...)
end
local function AssertList(list, func, ...)
	Assert(list, "table")
	for _, obj in ipairs(list) do func(obj, ...) end
	return list
end

local Events = {}
function Events.Move(pos1, pos2) -- Note: pos1 -> pos2 is a single move/jump
	return {Type = "Move", Pos1 = pos1, Pos2 = pos2}
end
function Events.Capture(pos)
	return {Type = "Capture", Pos = pos}
end
function Events.Promotion(pos)
	return {Type = "Promote", Pos = pos}
end
function Events.Draw()
	return {Type = "Draw"}
end
function Events.Victory(team)
	return {Type = "Victory", Team = team}
end
Board.Events = Events

local Move = {}
Move.__index = Move
Board.Move = Move
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

local v2 = Vector2.new
local pawnMovesUp = {v2(-1, -1), v2(1, -1)}
local pawnMovesDown = {v2(-1, 1), v2(1, 1)}
local kingMoves = {v2(-1, -1), v2(1, -1), v2(-1, 1), v2(1, 1)}
local function setPawnMoves(self, redOnTop)
	self.pawnMoves = {
		Red = if redOnTop then pawnMovesDown else pawnMovesUp,
		Black = if redOnTop then pawnMovesUp else pawnMovesDown,
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
	local top = if redOnTop then "r" else "b"
	local bottom = if redOnTop then "b" else "r"
	local empty = false
	for x = 1, 8 do
		local column = {}
		grid[x] = column
		for y = 1, 8 do
			column[y] = ((x + y) % 2 == 1 and (y <= 3 and top or y >= 6 and bottom)) or empty
		end
	end
	return setPawnMoves(setmetatable({grid = grid}, Board), redOnTop)
end
function Board.Blank(redOnTop)
	local grid = table.create(8)
	local empty = false
	for x = 1, 8 do
		local column = table.create(8)
		grid[x] = column
		for y = 1, 8 do
			column[y] = empty
		end
	end
	return setPawnMoves(setmetatable({grid = grid}, Board), redOnTop)
end
function Board.FromGrid(grid, redOnTop)
	local board = table.create(8)
	for x = 1, 8 do
		local column = table.create(8)
		board[x] = column
		for y = 1, 8 do
			column[y] = grid[x][y]
		end
	end
	return setPawnMoves(setmetatable({grid = board}, Board), redOnTop)
end
function Board.Deserialize(board, redOnTop)
	-- Server->client only
	local self = setmetatable(board, Board)
	setPawnMoves(self, redOnTop)
	return self
end
function Board:Get(pos)
	AssertPos(pos)
	return self.grid[pos.X][pos.Y]
end
function Board:Set(pos, value)
	AssertPos(pos)
	self.grid[pos.X][pos.Y] = value or false
	self.teamCanCapture = nil
end
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
function Board:ForEachPiece(fn)
	--	fn: function(pos, piece) to run for each piece (it can return true to end the loop early)
	local pos, piece
	for y = 1, 8 do
		for x = 1, 8 do
			pos = v2(x, y)
			piece = self:Get(pos)
			if piece then
				if fn(pos, piece) then
					return
				end
			end
		end
	end
end
function Board:ForEachPieceOnTeam(team, fn)
	--	team: "Red"/"Black"
	--	fn: function(pos, piece) to run for each piece (it can return true to end the loop early)
	local pos, piece
	for y = 1, 8 do
		for x = 1, 8 do
			pos = v2(x, y)
			piece = self:Get(pos)
			if piece and pieceToTeam[piece] == team then
				if fn(pos, piece) then
					return
				end
			end
		end
	end
end
function Board:forEachMove(pos, fn)
	--	Iterates over all valid coordinates that the piece on 'pos' might be allowed to move (not jump) to
	--	fn : function(destination, dir)
	local piece = self:Get(pos)
	local moves = if isPawn[piece] then self.pawnMoves[pieceToTeam[piece]] else kingMoves
	for i, dir in ipairs(moves) do
		local v = pos + dir
		if posOnBoard(v) then
			if fn(v, dir) then return end
		end
	end
end

function Board:move(from, to) -- returns true if a promotion occurred
	local piece = self:Get(from)
	self:Set(from, nil)
	local shouldPromote = self:ShouldPromotePawn(piece, to)
	self:Set(to, shouldPromote and pawnToKing[piece] or piece)
	return shouldPromote
end
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
function Board:MakeMove(move)
	--	returns List<game events>
	local team = self:GetPieceOwner(move.pieceCoord)
	local success, events = self:tryMove(team, move)
	if not success then error("Move unsuccessful: " .. move:ToKey(), 2) end
	return events
end
function Board:TryMove(team, move)
	--	team: "Red" or "Black"
	--	returns true, List<game events> OR false, reason
	Assert(team, "string")
	Assert(move, "table")
	local pos = move.pieceCoord
	if team ~= self:GetPieceOwner(pos) then return false, "You must move your own piece" end
	return self:tryMove(team, move)
end
function Board:tryMove(team, move)
	--	TryMove verifies that 'team' can move the piece at 'move' while this function does the rest of the verification and game-event generation
	local pos = move.pieceCoord
	local piece = self:Get(pos)
	if #move.coords == 1 then -- Check non-jumping moves
		local targetCoord = move.coords[1]
		if self:Get(targetCoord) then return false, "You can't move onto anoter piece" end
		local result
		local promoted
		self:forEachMove(pos, function(targetPos)
			if targetPos == targetCoord then -- The move's target coord is valid
				if self:IsCapturePossible(team) then -- can't move when capture possible
					result = false
					return true
				end
				promoted = self:move(pos, targetCoord)
				result = true
				return true
			end
		end)
		if result == true then
			local events = {Events.Move(pos, targetCoord)}
			if promoted then
				events[2] = Events.Promotion(targetCoord)
			end
			local event = self:AnalyzeEndGameConditions(oppositeTeam[team])
			if event then
				table.insert(events, event)
			end
			return true, events
		elseif result == false then
			return false, "You cannot ignore a capture"
		end
		-- Don't return false because it may have been a single jump
	end
	-- Check for 1+ jumps
	local promoted
	local prevTCC = self.teamCanCapture
	local undo = function() self.teamCanCapture = prevTCC end
	local events = {}
	for _, nextCoord in ipairs(move.coords) do
		-- ex, pos might be 1,1; first coord might be 3,3
		if promoted then undo(); return false, "Cannot continue capturing after being promoted" end -- cannot jump further after receiving a promotion
		if self:Get(nextCoord) then undo(); return false end -- cannot land on another piece
		local diff = nextCoord - pos
		if math.abs(diff.X) ~= 2 or math.abs(diff.Y) ~= 2 then undo(); return false, "You cannot jump like that" end
		local captureCoord = (pos + nextCoord) / 2
		if not self:Get(captureCoord) or self:GetPieceOwner(captureCoord) == team then undo(); return false end -- must jump over an enemy piece
		-- Make sure the jump is in a valid direction for the pawn
		local found = false
		self:forEachMove(pos, function(targetPos)
			if targetPos == captureCoord then
				found = true
				return true
			end
		end)
		if not found then undo(); return false, "Jumps are diagonal only" end
		table.insert(events, Events.Move(pos, nextCoord))
		table.insert(events, Events.Capture(captureCoord))
		promoted, undo = self:undoableJump(pos, captureCoord, nextCoord, undo)
		if promoted then
			table.insert(events, Events.Promotion(nextCoord))
		end
		pos = nextCoord
	end
	if not promoted and self:canPieceCapture(move.coords[#move.coords]) then -- can't stop capturing
		undo()
		return false, "Cannot stop capturing"
	end
	local event = self:AnalyzeEndGameConditions(oppositeTeam[team])
	if event then
		table.insert(events, event)
	end
	return true, events
end
function Board:AnalyzeEndGameConditions(teamToMove) -- returns an event or nil
	local grid = self.grid
	local redPieces, blackPieces, redKings, blackKings = 0, 0, 0, 0
	local validMoveFound = false
	self:ForEachPiece(function(pos, piece)
		local isKing = not isPawn[piece]
		if pieceToTeam[piece] == "Red" then
			redPieces += 1
			if isKing then
				redKings += 1
			end
		else
			blackPieces += 1
			if isKing then
				blackKings += 1
			end
		end
		if not validMoveFound and pieceToTeam[piece] == teamToMove then
			if self:GetValidMoves(teamToMove, pos)[1] then
				validMoveFound = true
			end
		end
		if validMoveFound and (redPieces > 1 and blackPieces > 1 or (redKings + blackKings < redPieces + blackPieces)) then return true end
	end)
	-- It's a loss if the player whose turn it is has no moves (or if they have no pieces)
	if not validMoveFound then
		return Events.Victory(oppositeTeam[teamToMove])
	elseif redPieces == 1 and blackPieces == 1 and redKings == 1 and blackKings == 1 then
		-- It's a draw if both sides have 1 king and neither is in a corner
		if self:Get(v2(1, 1)) or self:Get(v2(1, 8)) or self:Get(v2(8, 1)) or self:Get(v2(8, 8)) then return end -- not a draw just yet (one piece might be trapped in the corner)
		return Events.Draw()
	end
	-- Otherwise not a victory/draw yet
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
			self:forEachMove(pos, function(targetPos, dir)
				if self:canPieceCaptureInDir(pos, dir) then
					local capturePos = targetPos
					targetPos = targetPos + dir
					local function newGetTable()
						local t = getTable()
						table.insert(t, targetPos)
						return t
					end
					-- make the move, search for jumps, then undo the move
					local promote, undo = self:undoableJump(pos, capturePos, targetPos)
					if not promote and self:canPieceCapture(targetPos) then -- recurse
						searchForJumps(targetPos, newGetTable)
					else -- can stop here; record move
						table.insert(validMoves, Move.new(pieceCoord, newGetTable()))
					end
					undo()
				end
			end)
		end
		searchForJumps(pieceCoord, function() return {} end)
	else -- check non-jumping moves
		self:forEachMove(pieceCoord, function(targetPos, dir)
			if not self:Get(targetPos) then
				table.insert(validMoves, Move.new(pieceCoord, {targetPos}))
			end
		end)
	end
	return validMoves
end

function Board:GetAllValidMoves(team)
	--	Returns Dictionary<"x y", List<Move>>
	Assert(team, "string")
	local allMoves = {}
	self:ForEachPieceOnTeam(team, function(pos, piece)
		allMoves[("%d %d"):format(pos.X, pos.Y)] = self:GetValidMoves(pos)
	end)
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
	local found = false
	self:forEachMove(pos, function(targetPos, dir)
		if self:canPieceCaptureInDir(pos, dir) then
			found = true
			return true
		end
	end)
	return found
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