--[[
BoardModel:
	Contains reference to board model in workspace. Tracks where pieces are.
	:MakeMove(move) -- would update piece appropriately with Tweening
	:Reset(newBoard)
]]
local BoardModel = {}
BoardModel.__index = BoardModel

local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0)
local storage = game.ServerStorage.Checkers
local boardTileToModel = {
	r = storage.RedPiece,
	R = storage.RedKingedPiece,
	b = storage.BlackPiece,
	B = storage.BlackKingedPiece,
}

local function newGrid()
	local grid = {}
	for x = 1, 8 do grid[x] = {} end
	return grid
end

function BoardModel.new(board, model)
	--	board: the board representation
	--	model: the model in workspace that contains the checker board
	local grid = newGrid()
	local topLeft = model["1"].Position
	local self = setmetatable({
		model = model,
		grid = grid,
		topLeft = topLeft, -- Position
		down = model["9"].Position - topLeft, -- Direction
		right = model["2"].Position - topLeft, -- Direction
		resetNum = 0, -- increases on reset/destroy to tell animations to stop
		highlights = {}, -- Dict<part, funcToUndo> for highlighted parts
	}, BoardModel)
	self:Reset(board)
	return self
end

--[[
function BoardModel:WhatIsPart(part)
	--	returns nil OR "square"/"piece", x, y

end
function BoardModel:PartToCoord(part)
	--	returns Vector2 coordinate of part IF part is a square or piece
	
end
]]

local function highlightSquare(part)
	local start = part.Color
	part.Color = Color3.new(0, 1, 1)
	return function() part.Color = start end
end
local function highlightAttackSquare(part)
	local start = part.Color
	part.Color = Color3.new(0.6)
	return function() part.Color = start end
end
local function highlightPiece(part)
	local start = part.Color
	part.Color = Color3.new(1, 1, 1)
	return function() part.Color = start end
end
function BoardModel:HighlightPart(part, apply) -- apply must return an undo function
	if self.highlights[part] then
		self.highlights[part](part)
	end
	self.highlights[part] = apply(part)
end
function BoardModel:UnhighlightPart(part)
	if self.highlights[part] then
		self.highlights[part](part)
	end
	self.highlights[part] = nil
end
function BoardModel:HighlightSquare(pos)
	local x, y = pos.X, pos.Y
	self:HighlightPart(self.model[tostring((y - 1) * 8 + x)], highlightSquare)
end
function BoardModel:HighlightAttackSquare(pos)
	local x, y = pos.X, pos.Y
	self:HighlightPart(self.model[tostring((y - 1) * 8 + x)], highlightAttackSquare)
end
function BoardModel:HighlightPiece(pos)
	local x, y = pos.X, pos.Y
	self:HighlightPart(self.grid[x][y], highlightPiece)
end
function BoardModel:ClearHighlights()
	for part, _ in pairs(self.highlights) do
		self:UnhighlightPart(part)
	end
end
function BoardModel:Reset(board)
	self.resetNum = self.resetNum + 1
	local parent = self.model.Pieces
	local grid = self.grid
	for x = 1, 8 do
		for y = 1, 8 do
			local piece = grid[x][y]
			if piece then
				piece:Destroy()
				grid[x][y] = nil
			end
		end
	end
	local topLeft, down, right = self.topLeft, self.down, self.right
	for x = 1, 8 do
		for y = 1, 8 do
			local b = board:Get(Vector2.new(x, y))
			if b then
				local m = boardTileToModel[b]:Clone()
				m.CFrame = CFrame.new(topLeft + down * (y - 1) + right * (x - 1) + Vector3.new(0, m.Size.Y / 2, 0))
				m.Parent = parent
				grid[x][y] = m
			end
		end
	end
end
local TweenService = game:GetService("TweenService")
function BoardModel:MakeMove(move)
	--	Note: at the moment does not wait before returning (TODO perhaps it should?)
	local pos = move.pieceCoord
	local piece = self.grid[pos.X][pos.Y] or error("Invalid move: no piece at " .. tostring(pos))
	local last = move.coords[#move.coords]
	self.grid[pos.X][pos.Y] = nil
	self.grid[last.X][last.Y] = piece
	-- todo cleanup grid for any pieces captured. Instead of sending 'move' to both Board and BoardModel, Board needs to return a list of BoardEvents describing what happened: move, jump (resulting in capture of a specified piece), draw, red won, black won
	local topLeft, down, right = self.topLeft, self.down, self.right
	local startNum = self.resetNum -- Stop animating if resetNum changes
	--coroutine.resume(coroutine.create(function()
		for _, coord in ipairs(move.coords) do
			local tween = TweenService:Create(piece, tweenInfo, {Position = topLeft + down * (coord.Y - 1) + right * (coord.X - 1) + Vector3.new(0, piece.Size.Y / 2, 0)})
			tween:Play()
			tween.Completed:Wait()
			wait(0.2) -- pause before continuing animation
			if startNum ~= self.resetNum then return end
			--	TODO: check to see if piece is promoted at this stage, then animate/replace model to do so
		end
	--end))
end
function BoardModel:Animate(events)
	-- todo
end
return BoardModel