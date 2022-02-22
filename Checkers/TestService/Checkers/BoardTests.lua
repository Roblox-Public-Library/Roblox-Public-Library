return function(tests, t)


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Checkers = ReplicatedStorage.Checkers
local BoardParser = require(Checkers.BoardParser)
local Board = require(Checkers.Board)

local start = [[
.b.b.b.b
b.b.b.b.
.b.b.b.b
........
........
r.r.r.r.
.r.r.r.r
r.r.r.r.
]]
local startBoard = Board.new()
tests["Board.new"] = function()
	t.equals(BoardParser.ToString(startBoard), start, "ToString of Parse equals original")
end

local Move = Board.Move
local v2 = Vector2.new
local function listToString(list)
	local t = {}
	for i, coord in ipairs(list) do
		t[i] = tostring(coord)
	end
	return table.concat(t, "; ")
end
local coordListToKey = listToString

local tryMoveTest = {
	test = function(board, team, start, valid, invalid, validBoardResults)
		for name, pos in pairs(valid) do
			local board = board:Clone()
			local move = Move.new(start, typeof(pos) == "Vector2" and {pos} or pos)
			local result = board:TryMove(team, move)
			local success = t.equals(true, not not result, name .. " - should be legal")
			if success and validBoardResults and validBoardResults[name] then
				local expectedBoard = BoardParser.Parse(validBoardResults[name])
				local allSame = true
				for x = 1, 8 do
					for y = 1, 8 do
						local pos = v2(x, y)
						if board:Get(pos) ~= expectedBoard:Get(pos) then
							allSame = false
							break
						end
					end
					if not allSame then break end
				end
				if not t.equals(true, allSame, name .. " - expected board not the same") then
					print("Resulting board:")
					print(BoardParser.ToString(board))
					print("Expected board:")
					print(BoardParser.ToString(expectedBoard))
				end
			end
		end
		for name, pos in pairs(invalid) do
			local board = board:Clone()
			local move = Move.new(start, typeof(pos) == "Vector2" and {pos} or pos)
			t.equals(false, not not board:TryMove(team, move), name .. " - should be illegal")
		end
	end,
	argsLists = {},
}
local getValidTest = {
	test = function(board, team, start, valid, invalid, validBoardResults)
		local unFound = {} -- Dictionary<coordList keys, true>
		for name, pos in pairs(valid) do
			unFound[coordListToKey(typeof(pos) == "Vector2" and {pos} or pos)] = true
		end
		local alreadyFound = {}
		for _, move in ipairs(board:GetValidMoves(start)) do
			local key = coordListToKey(move.coords)
			if unFound[key] then
				unFound[key] = nil
				alreadyFound[key] = true
			elseif alreadyFound[key] then
				error("GetValidMoves has duplicate move " .. listToString(unpack(move.coords)))
			else
				error("GetValidMoves has incorrect move " .. listToString(unpack(move.coords)))
			end
		end
		t.equals(next(unFound), nil, "GetValidMoves missed valid moves")
	end,
	argsLists = {},
}

local function testMoves(caseName, board, team, start, valid, invalid, validBoardResults)
	local case = {name = caseName, board, team, start, valid, invalid, validBoardResults}
	table.insert(tryMoveTest.argsLists, case)
	table.insert(getValidTest.argsLists, case)
end

local start_normal = [[
.b.b.b.b
b.b.b.b.
.b.b.b.b
........
.r......
..r.r.r.
.r.r.r.r
r.r.r.r.
]]
testMoves("start", startBoard, "Red", v2(1,6),
	{normal=v2(2,5)},
	{straightUp=v2(1,5), farRight=v2(4,5), upRightJumpOverNothing=v2(3,4)},
	{normal=start_normal})
testMoves("no moves", startBoard, "Red", v2(2,7),
	{},
	{onOwnPiece=v2(1,6), jumpOverOwnPiece=v2(4,5)})

local twoPiecesText = [[
........
........
.......B
........
.....r..
........
........
........
]] -- r is at 6,5; b is at 8,3
local twoPieces = BoardParser.Parse(twoPiecesText)

testMoves("pawn in middle", twoPieces, "Red", v2(6,5),
	{upLeft=v2(5,4), upRight=v2(7,4)},
	{cannotMoveBackwardsLeft=v2(5,6), cannotMoveBackwardsRight=v2(7,6)})

-- Make sure kings can go backwards/forwards
testMoves("king on side", twoPieces, "Black", v2(8,3),
	{kingUpLeft=v2(7,2), kingDownLeft=v2(7,4)},
	{upRightOffBoard=v2(2,1)})

-- Make sure pawns cannot move backwards even if board starts with red on top
local twoPiecesReverse = BoardParser.Parse(twoPiecesText, true) -- red starts on top
testMoves("red on top: pawn in middle", twoPiecesReverse, "Red", v2(6,5),
	{downLeft=v2(5,6), downRight=v2(7,6)},
	{cannotMoveBackwardsUpLeft=v2(5,4), cannotMoveBackwardsUpRight=v2(7,4)})

local captureBoard = BoardParser.Parse[[
.b.b.b.b
..r.r...
........
..r...b.
.....r..
r.r.r...
.r.r.B.r
r.r.....
]]

local captureBoard_capture8_3 = [[
.b.b.b.b
..r.r...
.......r
..r.....
........
r.r.r...
.r.r.B.r
r.r.....
]]
testMoves("pawn can capture", captureBoard, "Red", v2(6, 5),
	{jump=v2(8,3)},
	{cannotIgnoreCapture=v2(5,4)},
	{jump=captureBoard_capture8_3})
testMoves("cannot ignore other pawn capture", captureBoard, "Red", v2(1, 6),
	{},
	{cannotMove=v2(2,5)})
local captureBoard_doubleJump = [[
...b.b.b
....r...
........
......b.
.b...r..
r.r.r...
.r.r.B.r
r.r.....
]]
testMoves("pawn can jump when multiple pawns can capture", captureBoard, "Black", v2(2, 1),
	{doubleJump={v2(4,3), v2(2,5)}},
	{ignoreDoubleJump=v2(4,3), ignoreJump=v2(1,2)},
	{doubleJump = captureBoard_doubleJump})
testMoves("pawn can capture when multiple options", captureBoard, "Black", v2(4, 1),
	{singleJump=v2(6,3), doubleJump={v2(2,3),v2(4,5)}},
	{cannotIgnoreDoubleJump=v2(5,4)})
testMoves("pawn can't capture backwards", captureBoard, "Red", v2(5, 6),
	{},
	{cannotJumpBackwards=v2(7,8)})
local captureBoard_kingJump = [[
.b.b.b.b
..r.r...
.B......
......b.
.....r..
r.r.....
.r.r...r
r.r.....
]]
testMoves("king can capture backwards", captureBoard, "Black", v2(6, 7),
	{kingCaptureBackwards={v2(4,5), v2(2,3)}},
	{kingCannotIgnoreCapture_Backwards=v2(7,6), kingCannotIgnoreCapture_Forwards=v2(7,8)},
	{kingCaptureBackwards=captureBoard_kingJump})

local promotionBoard = BoardParser.Parse[[
........
..r.....
.....b..
........
........
b.......
.r.r....
........
]]
local promotionBoard_promoteR = [[
...R....
........
.....b..
........
........
b.......
.r.r....
........
]]
testMoves("promote pawn", promotionBoard, "Red", v2(3, 2),
	{moveAndPromote=v2(4,1), moveAndPromoteOther=v2(2,1)},
	{up=v2(3,1)},
	{moveAndPromote=promotionBoard_promoteR})
local promotionBoard_promoteB = [[
........
..r.....
.....b..
........
........
........
...r....
..B.....
]]
testMoves("promote while jump", promotionBoard, "Black", v2(1,6),
	{jumpAndStop=v2(3,8)},
	{cannotJumpAfterPromote={v2(3,8),v2(5,6)}},
	{jumpAndStop=promotionBoard_promoteB})

-- Actually run the tests
tests["Board:TryMove()"] = tryMoveTest
tests["Board:GetValidMoves()"] = getValidTest



local nearEndOfGame = [[
........
........
........
........
........
..B.....
...r....
........
]]
local nearEndOfGameOutOfMoves = [[
........
........
........
....b.b.
.b.b.b..
b.b.b.r.
.r.r.r.r
r.r.r.r.
]]
local nearEndOfGameDraw = [[
.R......
..b.....
........
........
........
..B.....
........
........
]]
local notEndOfGame = [[
........
........
.....b..
........
........
..B.....
...r....
........
]]
local notEndOfGame2 = [[
........
........
........
........
...B....
..R.....
.b......
........
]]

tests.DetectEndOfGame = {
	test = function(boardString, move, eventType, eventTeamValue)
		local board = BoardParser.Parse(boardString)
		local events = board:MakeMove(move)
		local lastEvent = events[#events]
		if eventType then
			t.equals(lastEvent.Type, eventType)
			t.equals(lastEvent.Team, eventTeamValue)
		else
			t.notEquals(lastEvent.Type, "Victory")
			t.notEquals(lastEvent.Type, "Draw")
		end
	end,
	argsLists = {
		{name="Black wins", nearEndOfGame, Move.new(v2(3,6), {v2(5,8)}), "Victory", "Black"},
		{name="Red wins", nearEndOfGame, Move.new(v2(4,7), {v2(2,5)}), "Victory", "Red"},
		{name="Black wins - red out of moves", nearEndOfGameOutOfMoves, Move.new(v2(7,4), {v2(8,5)}), "Victory", "Black"},
		{name="Draw", nearEndOfGameDraw, Move.new(v2(2,1), {v2(4,3)}), "Draw"},
		{name="No draw when unpromoted", notEndOfGame, Move.new(v2(4,7), {v2(2,5)})},
		{name="No draw in corner", notEndOfGame2, Move.new(v2(3,6), {v2(1,8)})},
	}
}


end