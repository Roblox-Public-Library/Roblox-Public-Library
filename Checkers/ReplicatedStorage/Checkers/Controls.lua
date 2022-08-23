local localPlayer = game:GetService("Players").LocalPlayer
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Board = require(script.Parent.Board)
local Move = Board.Move

local idleMidTurnInstructionTime = 6
local idleMidTurnInstructions = "Keep jumping!"
local idleMidTurnInstructions2 = "Click off board to cancel"

local finalNode = {canStop = true}
local function convertValidMovesToTree(validMoves)
	-- we want [pos] = {valid}
	-- we want [pos] = {canStop = true, pos2 = tree, }
	-- problem: Vector2s can't be keys (Vector3s can)
	-- ah: just use tostring
	local tree = {} -- {[posKey] = tree, .canStop}
	for _, move in ipairs(validMoves) do
		local pointer = tree
		local i = 0
		while true do
			i += 1
			local pos = move.coords[i]
			if not pos then break end
			local key = tostring(pos) -- 1, 2
			local value = pointer[key] -- nil
			local moreExist = move.coords[i + 1] -- true
			if not value then
				value = if moreExist then {} else finalNode
				pointer[key] = value
			elseif value == finalNode and moreExist then
				value = {canStop = true}
				pointer[key] = value
			end
			pointer = value
		end
	end
	return tree
end
local function stringToVector2(moveString)
	return Vector2.new(moveString:match("(%d+)[%D]+(%d+)"))
end

local Controls = {}
Controls.__index = Controls
function Controls.new(game, boardModel, model, submitMove)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {model.Board, model.Pieces}
	raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
	local raycastParamsBoardOnly = RaycastParams.new()
	raycastParamsBoardOnly.FilterDescendantsInstances = {model.Board}
	raycastParamsBoardOnly.FilterType = Enum.RaycastFilterType.Whitelist
	local self = setmetatable({
		game = game or error("no game", 2), --:Game
		boardModel = boardModel or error("no boardModel", 2), --:BoardModel
		model = model or error("no model", 2), -- the model in workspace
		submitMove = submitMove,

		raycastParams = raycastParams,
		raycastParamsBoardOnly = raycastParamsBoardOnly,
		moveSoFar = {},
		-- validMovesTree
		-- selected : Ghost
		-- moveStartPos : Vector2
		-- canSubmitAt : Vector2

		-- lastGhostBoardPos -- for dragging, the last board position the ghost was dragged to (whether valid or not)
		-- lastValidGhostPos -- the last valid board position the ghost was moved to
		-- lastValidGhostPosAtInputBegan -- used to see if the ghost should be deselected on InputEnded; nil if the ghost was just created
		actions = 0, -- used to track whether the player is doing anything (so that they can be advised about forced jumping rules)
	}, Controls)
	self:EnterGameCameraMode()
	self.cons = {
		UserInputService.InputBegan:Connect(function(input, processed)
			if not self:isOurTurn() then return end
			if processed or not (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then return end
			local targetType, pos = self:identifyInputTarget(input)
			if targetType == "Ghost" then -- Don't modify selection (allow drag)
				self.lastValidGhostPosAtInputBegan = self.lastValidGhostPos -- record this so that if InputEnded occurs and ghost hasn't been moved, we cancel the move entirely
			elseif targetType == "Piece" then
				if self.selected and self.moveSoFar[1] == nil and pos ~= self.moveStartPos then -- if pos == self.moveStartPos then we don't want to clear the move; the user may have clicked and now want to drag the piece
					self:ClearMove()
				end
				if not self.selected and self:isOurPiece(pos) then
					local validMoves = game.Board:GetValidMoves(pos)
					if validMoves[1] then -- only select the piece if at least 1 valid move
						self.validMovesTree = convertValidMovesToTree(validMoves)
						self.selected = boardModel:NewGhost(pos)
						self.moveStartPos = pos
						self.lastValidGhostPos = pos
						self.lastGhostBoardPos = pos
						self.lastValidGhostPosAtInputBegan = nil
						for moveString in pairs(self.validMovesTree) do
							local move = stringToVector2(moveString)
							if (move - pos).Magnitude > 2 then -- (2, 2)'s magnitude is ~2.8
								self.boardModel:HighlightAttackSquare(move)
							else
								self.boardModel:HighlightSquare(move)
							end
						end
					end
				end
			elseif targetType == "Square" then
				if self.selected then
					if not self:tryAdvanceMove(pos, true) and self.moveSoFar[1] ~= nil then -- Allows deselecting by clicking on squares if you haven't started jumping
						self:ClearMove()
					else
						self.lastGhostBoardPos = pos
					end
				end
			else -- no targetType
				if self.selected then -- Allows cancelling a move by clicking outside the board
					self:ClearMove()
				end
			end
			self.dragging = self.selected
		end),
		UserInputService.InputEnded:Connect(function(input, processed)
			if not self:isOurTurn() then return end
			if not (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then return end
			if self.dragging then
				self.dragging = false
				if self.selected then
					if self.canSubmitAt and self.canSubmitAt == self.lastGhostBoardPos and not processed then
						self:submit()
					else
						local targetType, pos = self:identifyInputTarget(input)
						if targetType == "Ghost" and self.lastValidGhostPosAtInputBegan == self.lastGhostBoardPos then
							self:ClearMove()
						else -- move ghost to last valid location
							self.selected:Move(self.lastValidGhostPos)
							self.lastGhostBoardPos = self.lastValidGhostPos
						end
					end
				end
			end
		end),
		UserInputService.InputChanged:Connect(function(input, processed)
			if not self:isOurTurn() then return end
			if processed or not (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then return end
			if self.dragging then
				if self.selected then -- update drag position
					local boardPos, pos = self:identifyInputPos(input)
					if not boardPos then
						self:ClearMove()
					elseif not self:tryAdvanceMove(boardPos, false) then
						self.selected:MoveToVector3(pos)
					end
					self.lastGhostBoardPos = boardPos
				end
			elseif self.selected then -- hover
				-- local boardPos, pos = self:identifyInputPos(input)
				-- We could further highlight the square if it's a valid move
			end
			if not self.dragging then -- Highlight piece if valid for selection
				local targetType, pos = self:identifyInputTarget(input)
				if self.prevHighlightPos then
					self.boardModel:UnhighlightPiece(self.prevHighlightPos)
				end
				if targetType == "Piece" and self:isOurPiece(pos) and game.Board:GetValidMoves(pos)[1] then
					self.boardModel:HighlightPiece(pos)
					self.prevHighlightPos = pos
				else
					self.prevHighlightPos = nil
				end
			end
		end),
	}
	return self
end
function Controls:Destroy()
	self:ClearMove()
	for _, con in ipairs(self.cons) do
		con:Disconnect()
	end
	self:ExitGameCameraMode()
end
function Controls:EnterGameCameraMode()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Follow
	camera.CameraSubject = self.model.Table.CameraTarget
	localPlayer.CameraMinZoomDistance = 2.8
	localPlayer.CameraMaxZoomDistance = 7
end
function Controls:ExitGameCameraMode()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = localPlayer.Character:FindFirstChild("Humanoid")
	localPlayer.CameraMinZoomDistance = StarterPlayer.CameraMinZoomDistance
	localPlayer.CameraMaxZoomDistance = StarterPlayer.CameraMaxZoomDistance
end
function Controls:ClearMove() -- clear/cancel any move-in-progress
	self:newAction()
	self.canSubmitAt = false
	if self.selected then
		self.selected:Destroy()
		self.selected = nil
	end
	table.clear(self.moveSoFar)
	self.boardModel:ClearHighlights()
end

function Controls:identifyInputTarget(input) -- returns nil, "Ghost", or targetType ("Square"/"Piece"), boardPos
	local ray = workspace.CurrentCamera:ScreenPointToRay(input.Position.X, input.Position.Y)
	local result = workspace:Raycast(ray.Origin, ray.Direction * 14, self.raycastParams)
	if result then
		if self.selected and self.selected.Instance == result.Instance then
			return "Ghost"
		else
			return self.boardModel:WhatIsPart(result.Instance)
		end
	end
end
function Controls:identifyInputPos(input) -- returns boardPos, Vector3 pos
	local ray = workspace.CurrentCamera:ScreenPointToRay(input.Position.X, input.Position.Y)
	local result = workspace:Raycast(ray.Origin, ray.Direction * 14, self.raycastParamsBoardOnly)
	if result then
		return self.boardModel:Vector3ToBoardPos(result.Position), result.Position
	end
end
function Controls:newAction()
	self.actions += 1
	if self.idleInstructionsGiven then
		self.idleInstructionsGiven = false
		self.game:UpdateTurnDisplays()
	end
end
function Controls:tryAdvanceMove(pos, allowSubmit) -- board pos
	local key = tostring(pos)
	local value = self.validMovesTree[key]
	if not value then
		return false
	end
	self:newAction()
	self.validMovesTree = value
	table.insert(self.moveSoFar, pos)
	if value.canStop then
		-- Note: we assume rules are "forced jump", meaning there'll never be a case where the player can choose between stopping and continuing
		if allowSubmit then
			self:submit()
		else
			self.canSubmitAt = pos
		end
	else
		self.selected:Move(pos)
		self.lastValidGhostPos = pos
		self.boardModel:ClearSquareHighlights()
		for move in pairs(self.validMovesTree) do
			-- only way you can double move is through a capture
			self.boardModel:HighlightAttackSquare(stringToVector2(move))
		end
		local startActions = self.actions
		task.delay(idleMidTurnInstructionTime, function()
			if self.actions == startActions then
				self.boardModel:UpdateDisplays(idleMidTurnInstructions2)
				self.boardModel:DisplayAlternatingText(idleMidTurnInstructions)
				self.idleInstructionsGiven = true
			end
		end)
	end
	return true
end
function Controls:submit()
	local move = Move.new(self.moveStartPos, self.moveSoFar)
	self.submitMove(move)
	self:ClearMove()
	self.submittedRecently = true -- used to temporarily disable controls
	task.delay(0.25, function()
		self.submittedRecently = false
	end)
end
-- isOurPiece and isOurTurn work in such a way that a single player can still control both colours (one at a time)
function Controls:isOurPiece(pos)
	return self.boardModel:GetPieceTeam(pos) == self.game.Turn
end
function Controls:isOurTurn()
	return not self.submittedRecently and self.game:PlayerCanMove(localPlayer)
end

return Controls