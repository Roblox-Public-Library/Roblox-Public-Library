-- This file manages all checker games server side and creates needed remotes
-- Animation note: with the exception of the reset buttons, animation is handled client-side via remotes

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Event = require(ReplicatedStorage.Utilities.Event)

local Checkers = ReplicatedStorage.Checkers
local Board = require(Checkers.Board)
local Move = Board.Move
local Game = require(Checkers.Game)

-- Setup remotes
local function create(parent, name, type)
	local obj = Instance.new(type)
	obj.Name = name
	obj.Parent = parent
	return obj
end
local remotes = create(ReplicatedStorage.Remotes, "Checkers", "Folder")
for _, name in ipairs({
	"NewGame", --(checkersModel, redOnTop)
	"StartTurn", --(checkersModel, team)
	"MoveMade", --(checkersModel, move)
	"ProposeReset", --(checkersModel, reset, topProposed) -- reset can be false if the proposal is withdrawn, in which case topProposed will not be provided
	"Reset", --(checkersModel) -- means to start reset animation (NewGame will be triggered after)
	-- Client->Server
	"TryMove", --(checkersModel, move)
}) do
	create(remotes, name, "RemoteEvent")
end
for _, name in ipairs({
	"GetGames" --():List<{checkersModel, game}>
}) do
	create(remotes, name, "RemoteFunction")
end

local checkersModelToGame = {}

local normalColor = Color3.fromRGB(165, 88, 47)
local normalHoverColor = Color3.fromRGB(130, 68, 36)
local resetColor = Color3.fromRGB(255, 132, 70)
local resetHoverColor = Color3.fromRGB(195, 101, 53)
local ResetButton = {}
ResetButton.__index = ResetButton
function ResetButton.new(button, isPlayerAuthorized)
	local cd = button.ClickDetector
	local self = setmetatable({
		Reset = false,
		button = button,
		Toggled = Event.new(),
		startDistance = cd.MaxActivationDistance,
		cd = cd,
	}, ResetButton)
	cd.MouseClick:Connect(function(player)
		if not isPlayerAuthorized(player) or self.paused then return end
		self.Reset = not self.Reset
		self:update()
		self.Toggled:Fire()
	end)
	cd.MouseHoverEnter:Connect(function(player)
		if not isPlayerAuthorized(player) or self.paused then return end
		self.hover = true
		self:update()
	end)
	cd.MouseHoverLeave:Connect(function(player)
		if not isPlayerAuthorized(player) or self.paused then return end
		self.hover = false
		self:update()
	end)
	return self
end
function ResetButton:CancelReset()
	if self.paused then return end
	self.Reset = false
	self:update()
end
function ResetButton:pauseUpdates()
	self.paused = true
	self.cd.MaxActivationDistance = 0
end
function ResetButton:resumeUpdates()
	self.paused = false
	self.cd.MaxActivationDistance = self.startDistance
	self:update()
end
function ResetButton:update()
	local button = self.button
	button.Material = if self.Reset then Enum.Material.Neon else Enum.Material.SmoothPlastic
	if self.Reset then
		button.Color = if self.hover then resetHoverColor else resetColor
	else
		button.Color = if self.hover then normalHoverColor else normalColor
	end
end
function ResetButton:AnimateReset(duration)
	self.Reset = true
	self.hover = false
	self:update()
	self:pauseUpdates()
	task.delay(duration, function()
		self.Reset = false
		self:resumeUpdates()
	end)
end

local base = Game.new
function Game.new(checkersModel)
	local self = base(Board.new(), checkersModel)
	local function playerAuthorizedTop(player)
		return player == self:PlayerForTeam(if self.redOnTop then "Red" else "Black")
	end
	local topReset = ResetButton.new(checkersModel.TopReset, playerAuthorizedTop)
	local function playerAuthorizedBottom(player)
		return player == self:PlayerForTeam(if self.redOnTop then "Black" else "Red")
	end
	local bottomReset = ResetButton.new(checkersModel.BottomReset, playerAuthorizedBottom)
	local function considerReset()
		local shouldReset = if self.gameOverFor3Sec
			then topReset.Reset or bottomReset.Reset
			else topReset.Reset and bottomReset.Reset
		if shouldReset then
			self:GameOver()
			self:Reset()
		elseif topReset.Reset or bottomReset.Reset then
			self:Fire("ProposeReset", true, topReset.Reset)
		else
			self:Fire("ProposeReset", false)
		end
	end
	topReset.Toggled:Connect(considerReset)
	bottomReset.Toggled:Connect(considerReset)
	self.topReset = topReset
	self.bottomReset = bottomReset
	self.redOnTop = false
	self.resetting = false
	self:init()
	self:finishNewGame()
	return self
end
function Game:Reset()
	if self.resetting then return end
	self.resetting = true
	self:Fire("Reset")
	self.topReset:AnimateReset(1.5)
	self.bottomReset:AnimateReset(1.5)
	task.wait(1.5)
	self:NewGame()
end
function Game:Fire(remoteName, ...)
	remotes[remoteName]:FireAllClients(self.checkersModel, ...)
end
function Game:finishNewGame()
	self:Fire("NewGame", self.redOnTop)
end
local base = Game.NewGame
function Game:NewGame()
	self.redOnTop = not self.redOnTop
	base(self, Board.new(self.redOnTop))
	self.resetting = false
	self.gameOverFor3Sec = false
	self:finishNewGame()
end
local base = Game.GameOver
function Game:GameOver(victor)
	base(self, victor)
	task.delay(3, function()
		if self.gameOver then
			self.gameOverFor3Sec = true
		end
	end)
end
local base = Game.PlayerSatDown
function Game:PlayerSatDown(player, team)
	base(self, player, team)
	self:playerChange(team)
end
local base = Game.PlayerStoodUp
function Game:PlayerStoodUp(player, team)
	base(self, player, team)
	self:playerChange(team)
end
function Game:playerChange(team)
	local resetButton = if team == (if self.redOnTop then "Red" else "Black") then self.topReset else self.bottomReset
	resetButton:CancelReset()
	if self.Turn == team and not self.gameOver then
		self:Fire("StartTurn", team)
	end
end
local base = Game.SetTurn
function Game:SetTurn(turn)
	base(self, turn)
	self:Fire("StartTurn", turn)
end

remotes.TryMove.OnServerEvent:Connect(function(player, checkersModel, move)
	local game = checkersModelToGame[checkersModel]
	if not game then return end
	move = Move.FromClient(move)
	if not move then return end
	if player ~= game:PlayerForTeam(game.Turn) then return end
	local legal, eventList = game:TryMove(player, move)
	if not legal then return end
	game:Fire("MoveMade", move)
end)

local function handle(model)
	checkersModelToGame[model] = Game.new(model)
end
for _, model in ipairs(CollectionService:GetTagged("Checkers Game")) do
	handle(model)
end
CollectionService:GetInstanceAddedSignal("Checkers Game"):Connect(handle)

remotes.GetGames.OnServerInvoke = function(player)
	local list = {}
	for checkersModel, game in pairs(checkersModelToGame) do
		table.insert(list, game:Serialize())
	end
	return list
end