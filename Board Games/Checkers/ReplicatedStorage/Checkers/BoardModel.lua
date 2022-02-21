--[[
BoardModel:
	Contains reference to board model in workspace. Tracks where pieces are.
	:MakeMove(move) -- would update piece appropriately with Tweening
	:Reset(newBoard)
]]
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Event = require(ReplicatedStorage.Utilities.Event)

local Board = require(script.Parent.Board)

local BoardModel = {}
BoardModel.__index = BoardModel

local moveHeightOffset = 0.12
local timeBetweenAlternatingMsg = 3

-- EasingStyles: 'In' starts slow, ends fast; 'Out' is the opposite

--local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
local tweenInfoMove1 = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local tweenInfoMove2 = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenInfoCapture = TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
local tweenInfoFadeIn = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
local storage = ReplicatedStorage.CheckerPieces
local pawn = storage.Piece
local king = storage.KingedPiece
local redColor = Color3.fromRGB(255, 0, 0)
local blackColor = Color3.fromRGB(27, 42, 53)
pawn.Color = redColor
king.Color = redColor
local boardTileToModel = {
	r = pawn,
	R = king,
	b = pawn:Clone(),
	B = king:Clone(),
}
boardTileToModel.b.Color = blackColor
boardTileToModel.B.Color = blackColor
local nameToHeight = {}
for name, model in pairs(boardTileToModel) do
	if not nameToHeight[model.Name] then
		nameToHeight[model.Name] = math.abs(model.CFrame:VectorToWorldSpace(model.Size).Y)
	end
end
local function getPieceHeight(piece)
	return nameToHeight[piece.Name]
end
local function getPieceTeam(piece)
	return if piece.Name:find("Red", 1, true) then "Red" else "Black"
end

local function newGrid()
	local grid = table.create(8)
	for x = 1, 8 do grid[x] = table.create(8) end
	return grid
end

function BoardModel.new(board, model)
	--	board: the board representation
	--	model: the model in workspace that contains the checker board
	local grid = newGrid()
	local topLeft = model.Board["1"].Position
	local statusFrame = model.Table.Top.SurfaceGui.Status
	local self = setmetatable({
		DisplaysChanged = Event.new(), -- Occurs whenever a new message (or alternating message) is configured to be displayed. Note that this only fires once per function call (even for DisplayAlternatingText).

		model = model,
		topLeft = topLeft, -- Position
		down = model.Board["9"].Position - topLeft, -- Direction
		right = model.Board["2"].Position - topLeft, -- Direction
		grid = grid,
		pieceToTeam = {},
		-- animating = {[animating coroutine] = true} if animating, otherwise nil
		activeTweens = {}, -- [tween] = true
		highlights = {}, -- Dict<part, funcToUndo> for highlighted parts
		piecesFolder = model.Pieces,
		topStatus = statusFrame.Top,
		bottomStatus = statusFrame.Bottom,
		ghosts = {}, -- [ghost] = true
	}, BoardModel)
	self:Reset(board)
	return self
end

function BoardModel:GetPieceTeam(pos)
	local piece = self.grid[pos.X][pos.Y]
	return self.pieceToTeam[piece]
end
function BoardModel:BoardPosToVector3(pos, pieceHeight)
	--	returns the Vector3 position for a piece to sit at the Vector2 'pos'
	return self.topLeft
		+ self.right * (pos.X - 1)
		+ self.down * (pos.Y - 1)
		+ Vector3.new(0, pieceHeight / 2, 0)
end
function BoardModel:Vector3ToBoardPos(pos)
	local rPos = pos - self.topLeft
	local right, down = self.right, self.down
	return Vector2.new(
		math.floor(right:Dot(rPos) / right.Magnitude ^ 2 + 0.5) + 1,
		math.floor(down:Dot(rPos) / down.Magnitude ^ 2 + 0.5) + 1)
end
-- local rnd = Random.new()
-- function BoardModel:getNewJailPosition(piece, team)
-- 	local jail = self.model.Jail[team .. "Jail"]
-- 	return jail.CFrame:PointToWorldSpace(Vector3.new(
-- 		rnd:NextNumber(-x, x),
-- 		(jail.Size.Y + ) / 2,
--		rnd:NextNumber(-z, z))
-- end

function BoardModel:WhatIsPart(part)
	--	returns nil OR "Square"/"Piece", boardPos : Vector2
	if part.Parent == self.model.Board then
		local num = tonumber(part.Name)
		if num then
			local x = (num - 1) % 8 + 1
			local y = math.floor((num - 1) / 8) + 1
			return "Square", Vector2.new(x, y)
		end
	elseif part.Parent == self.piecesFolder then
		return "Piece", self:Vector3ToBoardPos(part.Position)
	end
end

local function blend(a, b)
	return Color3.new(
		(a.R + b.R) / 2,
		(a.G + b.G) / 2,
		(a.B + b.B) / 2)
end
local function highlightSquare(part)
	local start = part.Color
	part.Color = blend(start, Color3.new(0, 1, 1))
	return function() part.Color = start end
end
local function highlightAttackSquare(part)
	local start = part.Color
	part.Color = blend(start, Color3.new(1, 0.5, 0.5))
	return function() part.Color = start end
end
local function highlightPiece(part)
	local start = part.Color
	part.Color = blend(start, Color3.new(1, 1, 1))
	return function() part.Color = start end
end
function BoardModel:HighlightPart(part, apply) -- apply must return an undo function
	if self.highlights[part] then
		self.highlights[part](part)
	end
	self.highlights[part] = apply(part)
end
function BoardModel:UnhighlightPart(part)
	if not part then return end -- can occur when using UnhighlightPiece(pos) after moves are animated (which is why ClearHighlights is called from AnimateEvents - pieces move around and references are broken)
	if self.highlights[part] then
		self.highlights[part](part)
	end
	self.highlights[part] = nil
end
function BoardModel:HighlightSquare(pos)
	local x, y = pos.X, pos.Y
	self:HighlightPart(self.model.Board[tostring((y - 1) * 8 + x)], highlightSquare)
end
function BoardModel:HighlightAttackSquare(pos)
	local x, y = pos.X, pos.Y
	self:HighlightPart(self.model.Board[tostring((y - 1) * 8 + x)], highlightAttackSquare)
end
function BoardModel:HighlightPiece(pos)
	local x, y = pos.X, pos.Y
	self:HighlightPart(self.grid[x][y], highlightPiece)
end
function BoardModel:UnhighlightPiece(pos)
	local x, y = pos.X, pos.Y
	self:UnhighlightPart(self.grid[x][y])
end
function BoardModel:ClearHighlights()
	for part, undo in pairs(self.highlights) do
		undo(part)
	end
	table.clear(self.highlights)
end
function BoardModel:ClearSquareHighlights()
	for part, _ in pairs(self.highlights) do
		if tonumber(part.Name) then
			self:UnhighlightPart(part)
		end
	end
end

local Ghost = {}
Ghost.__index = Ghost
local ghostOffset = Vector3.new(0, 0.05, 0)
function Ghost.new(boardModel, original)
	local ghost = original:Clone()
	ghost.Transparency = 0.7
	ghost.Parent = original.Parent
	ghost.CFrame += ghostOffset
	original.Transparency = 0.9
	boardModel.pieceToTeam[ghost] = boardModel.pieceToTeam[original]
	return setmetatable({
		boardModel = boardModel,
		original = original,
		Instance = ghost,
	}, Ghost)
end
function Ghost:Destroy()
	self.original.Transparency = 0
	self.boardModel.pieceToTeam[self.Instance] = nil
	self.Instance:Destroy()
	self.boardModel.ghosts[self] = nil
end
function Ghost:Move(newBoardPos)
	self.Instance.Position = self.boardModel:BoardPosToVector3(newBoardPos, getPieceHeight(self.Instance)) + ghostOffset
end
function Ghost:MoveToVector3(pos)
	self.Instance.Position = pos + ghostOffset
end
function BoardModel:NewGhost(pos) -- returns nil or a Ghost with :Move(newBoardPos) and :Destroy()
	local part = self.grid[pos.X][pos.Y]
	if not part then return nil end
	local ghost = Ghost.new(self, part)
	self.ghosts[ghost] = true
	return ghost
end

function BoardModel:Reset(board)
	table.clear(self.pieceToTeam)
	self:ClearHighlights()
	self:stopAnyAnimations()
	for ghost in pairs(self.ghosts) do
		ghost:Destroy()
	end
	local parent = self.piecesFolder
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
	parent:ClearAllChildren() -- in case of any animating ones
	-- todo if have a jail, clear it
	local topLeft, down, right = self.topLeft, self.down, self.right
	for x = 1, 8 do
		for y = 1, 8 do
			local b = board:Get(Vector2.new(x, y))
			if b then
				local m = boardTileToModel[b]:Clone()
				self.pieceToTeam[m] = Board.PieceToTeam[b]
				m.Position = topLeft + down * (y - 1) + right * (x - 1) + Vector3.new(0, getPieceHeight(m) / 2, 0)
				m.Parent = parent
				grid[x][y] = m
			end
		end
	end
end
function BoardModel:stopAnyAnimations()
	if not self.animating then return end
	for co in pairs(self.animating) do
		coroutine.close(co)
	end
	self.animating = nil
	for tween in pairs(self.activeTweens) do
		tween:Cancel()
		tween:Destroy()
	end
	table.clear(self.activeTweens)
end

function BoardModel:playTweenAsync(obj, tweenInfo, props)
	local tween = TweenService:Create(obj, tweenInfo, props)
	self.activeTweens[tween] = true
	tween:Play()
	tween.Completed:Wait()
	self.activeTweens[tween] = nil
end
function BoardModel:playTween(obj, tweenInfo, props)
	local tween = TweenService:Create(obj, tweenInfo, props)
	self.activeTweens[tween] = true
	tween:Play()
	local con; con = tween.Completed:Connect(function()
		con:Disconnect()
		self.activeTweens[tween] = nil
	end)
end

local eventTypeToHandler = {
	Move = function(self, event)
		local pos1 = event.Pos1
		local pos2 = event.Pos2
		local grid = self.grid
		local piece = grid[pos1.X][pos1.Y] or error("Invalid move: no piece at " .. tostring(pos1))
		grid[pos1.X][pos1.Y] = nil
		grid[pos2.X][pos2.Y] = piece
		local topLeft, down, right = self.topLeft, self.down, self.right
		local height = getPieceHeight(piece)
		local start = self:BoardPosToVector3(pos1, height)
		local dest = self:BoardPosToVector3(pos2, height)
		local mid = (start + dest) / 2 + Vector3.new(0, moveHeightOffset, 0)
		self:playTweenAsync(piece, tweenInfoMove1, {Position = mid})
		self:playTweenAsync(piece, tweenInfoMove2, {Position = dest})
	end,
	Capture = function(self, event)
		local pos = event.Pos
		local grid = self.grid

		local piece = grid[pos.X][pos.Y] or error("Invalid capture event: no piece at " .. tostring(pos))
		grid[pos.X][pos.Y] = nil
		self:playTweenAsync(piece, tweenInfoCapture, {
			Position = piece.Position + Vector3.new(0, moveHeightOffset * 3, 0),
			Transparency = 1,
		})
		piece:Destroy()
		self.pieceToTeam[piece] = nil
		-- piece.Position = self:getNewJailPosition(getPieceTeam(piece))
		-- piece.Transparency = 0
	end,
	Promote = function(self, event)
		local pos = event.Pos
		local grid = self.grid
		local piece = grid[pos.X][pos.Y]
		local team = getPieceTeam(piece)
		local newModel = boardTileToModel[team:sub(1, 1)]:Clone()
		newModel.Transparency = 1
		newModel.Position = self:BoardPosToVector3(pos, getPieceHeight(newModel))
		grid[pos.X][pos.Y] = newModel
		newModel.Parent = piece.Parent
		self:playTweenAsync(newModel, tweenInfoFadeIn, {Transparency = 0})
		piece:Destroy()
		self.pieceToTeam[newModel] = self.pieceToTeam[piece]
		self.pieceToTeam[piece] = nil
	end,
	Draw = function(self)
		self.topStatus.Text = "Draw"
		self.bottomStatus.Text = "Draw"
		self:handleEndOfGame()
	end,
	Victory = function(self, event)
		local topWins = (event.Team == "Red") == self.redOnTop
		self.topStatus.Text = if topWins then "You win!" else event.Team .. " Wins"
		self.bottomStatus.Text = if not topWins then "You win!" else event.Team .. " Wins"
		self:handleEndOfGame()
	end,
}
local invisible = {Transparency = 1}
function BoardModel:StartResetAnimation(duration)
	self:stopAnyAnimations()
	self:UpdateDisplays("-- STARTING NEW GAME --")
	self.animating = {}
	local tweenInfoFadeOut = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
	for _, piece in ipairs(self.piecesFolder:GetChildren()) do
		self:playTween(piece, tweenInfoFadeOut, invisible)
	end
end
function BoardModel:AnimateEvents(events)
	self:ClearHighlights()
	if self.animating then
		local animationEventsLeft = self.animationEventsLeft
		local n = #events
		table.move(events, 1, n, #animationEventsLeft + 1, animationEventsLeft)
	else
		local startNum = self.resetNum -- Stop this animation loop if resetNum changes
		local animationEventsLeft = events
		self.animationEventsLeft = animationEventsLeft
		task.spawn(function()
			self.animating = {[coroutine.running()] = true}
			while true do
				local event = table.remove(animationEventsLeft, 1)
				if not event then
					self.animating = false
					return
				end
				if event.Type == "Move" then
					local nextEvent = animationEventsLeft[1]
					if nextEvent and nextEvent.Type == "Capture" then
						table.remove(animationEventsLeft, 1)
						local co = coroutine.create(eventTypeToHandler.Capture)
						self.animating[co] = true
						task.spawn(co, self, nextEvent)
					end
				end
				eventTypeToHandler[event.Type](self, event)
				local nextEvent = animationEventsLeft[1]
				if nextEvent and nextEvent.Type ~= "Move" then
					task.wait(0.2)
				end
			end
		end)
	end
end
function BoardModel:updateDisplays(topText, bottomText) -- bottomText defaults to topText unless 'false' is provided
	if topText ~= false then
		self.topStatus.Text = topText
		self.topStatusText = topText -- needed if alternating
	end
	if bottomText ~= false then
		bottomText = bottomText or topText
		self.bottomStatus.Text = bottomText
		self.bottomStatusText = bottomText -- needed if alternating
	end
end
function BoardModel:UpdateDisplays(topText, bottomText) -- bottomText defaults to topText unless 'false' is provided
	self:updateDisplays(topText, bottomText)
	self.DisplaysChanged:Fire()
end
function BoardModel:DisplayAlternatingText(topText, bottomText) -- bottomText defaults to topText unless 'false' is provided. The displays alternate between what they were previously set to and the arguments provided.
	local ignore = false
	local function update1()
		ignore = true
		self:updateDisplays(topText, bottomText)
		ignore = false
	end
	local prevTop = self.topStatusText
	local prevBottom = self.bottomStatusText
	local function update2()
		ignore = true
		self:updateDisplays(prevTop, prevBottom)
		ignore = false
	end
	local con
	task.spawn(function()
		repeat
			update1()
			task.wait(timeBetweenAlternatingMsg)
			if not con then break end
			update2()
			task.wait(timeBetweenAlternatingMsg)
		until not con
	end)
	self.DisplaysChanged:Fire()
	con = self.DisplaysChanged:Connect(function()
		if ignore then return end
		con:Disconnect()
		con = nil
	end)
end
function BoardModel:handleEndOfGame()
	local con; con = self.DisplaysChanged:Connect(function()
		con:Disconnect()
		con = nil
	end)
	task.delay(timeBetweenAlternatingMsg, function()
		if not con then return end
		self:DisplayAlternatingText("<-- Press for new game") -- note: this will trigger the connection to clean itself up
	end)
end
return BoardModel