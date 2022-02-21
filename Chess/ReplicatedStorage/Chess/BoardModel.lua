local pieceTemplates = game:GetService("ServerStorage").ChessPieces
local BoardModel = {}
BoardModel.__index = BoardModel
function BoardModel.new(model)
	-- Kept in a replicatable state
	local coordToModel = {}
	for y = 1, 8 do coordToModel[y] = {} end
	return setmetatable({
		model = model,
		coordToModel = coordToModel, --[y][x] = model
		modelToCoord = {}, --[model] = Vector2.new(x, y)
	}, BoardModel)
end
function BoardModel:SetBoardState(boardState)
	-- todo cleanup previous boardState connections (if any)
	self:Clear()
	boardState:ForEachPiece(function(pos, piece)
		self:AddModel(pos, pieceTemplates[piece.Team][piece.Type]:Clone())
	end)
	self.boardState = boardState
end
function BoardModel:AddModel(pos, model)
	self.coordToModel[pos.Y][pos.X] = model
	self.modelToCoord[model] = pos
end
function BoardModel:GetModel(pos)
	return self.coordToModel[pos.Y][pos.X]
end
function BoardModel:MoveModel(from, to)
	-- TODO move tweens & animations here
	-- TODO need to support capturing
	--	may be better to have a list of "effects" to be applied to the board
	--	ex castling would be two moves; en passent is a move & piece removal
	-- 	OR just have functions for each type of move - the board can receive an optional model argument with which it can tell it how to update

	--	To support capturing: tween the capturing piece and have the captured one disappear (or move to the "jail") before the capturing one arrives at the destination square
	--	Should therefore also have the concept of where the "jail"/captured pieces area is in BoardModel
	local model = self:GetModel(from)
	if not model then error("No model at 'from' " .. tostring(from) .. "->" .. tostring(to), 2) end
	if self:GetModel(to) then error("Model at 'to' " .. tostring(from) .. "->" .. tostring(to), 2) end
	self.coordToModel[from.Y][from.X] = nil
	self.coordToModel[to.Y][to.X] = model
	self.modelToCoord[model] = to
end
function BoardModel:RemoveModel(pos)
	self.modelToCoord[self:GetModel(pos)] = nil
	self.coordToModel[pos.Y][pos.X] = nil
end
function BoardModel:Clear()
	local modelToCoord, coordToModel = self.modelToCoord, self.coordToModel
	for model, coord in pairs(modelToCoord) do
		self:RemoveModel(coord)
		model:Destroy()
	end
end
function BoardModel:GetCoord(model)
	return self.modelToCoord[model]
end
return BoardModel