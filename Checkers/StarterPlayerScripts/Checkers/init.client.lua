--This file manages all checker games client side
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Checkers = ReplicatedStorage.Checkers
local Board = require(Checkers.Board)
local Move = Board.Move
local BoardModel = require(Checkers.BoardModel)
local Controls = require(Checkers.Controls)

local remotes = ReplicatedStorage.Remotes.Checkers
local checkersModelToGame = {}
local Game = require(Checkers.Game)

local localPlayer = game:GetService("Players").LocalPlayer

local playerGame
local base = Game.init
function Game:init()
	base(self)
	self.boardModel = BoardModel.new(self.Board, self.checkersModel)
	if self.redPlayer then
		self:PlayerSatDown(self.redPlayer, "Red")
	end
	if self.blackPlayer then
		self:PlayerSatDown(self.blackPlayer, "Black")
	end
	return self
end
local base = Game.NewGame
function Game:NewGame()
	base(self)
	self.boardModel:Reset(self.Board)
end
function Game:UpdateTurnDisplays()
	if self:NumPlayers() < 2 then
		self.boardModel:UpdateDisplays(self.Turn .. " to move")
	else
		self.boardModel:UpdateDisplays(
			if (self.Turn == "Red") == self.redOnTop then "Your turn" else self.Turn .. " to move",
			if (self.Turn == "Red") ~= self.redOnTop then "Your turn" else self.Turn .. " to move")
	end
end
local base = Game.PlayerSatDown
function Game:PlayerSatDown(player, team)
	base(self, player, team)
	if player == localPlayer then
		playerGame = self
		playerControls = Controls.new(self, self.boardModel, self.checkersModel, function(move)
			remotes.TryMove:FireServer(self.checkersModel, move)
		end)
	elseif self:PlayerOpponentToTeam(team) == localPlayer and self:PlayerForTeam(self.Turn) ~= localPlayer then
		playerControls:ClearMove() -- player may have been playing both sides; cancel any in-progress move
	end
end
local base = Game.PlayerStoodUp
function Game:PlayerStoodUp(player, team)
	base(self, player, team)
	if player == localPlayer then
		playerGame = nil
		playerControls:Destroy()
		playerControls = nil
	end
end
local base = Game.SetTurn
function Game:SetTurn(turn)
	base(self, turn)
	self:UpdateTurnDisplays()
end

for _, obj in ipairs(remotes.GetGames:InvokeServer()) do
	local game = Game.Deserialize(obj)
	checkersModelToGame[game.checkersModel] = game
end

local function handle(name, handler)
	remotes[name].OnClientEvent:Connect(function(checkersModel, ...)
		local game = checkersModelToGame[checkersModel]
		handler(game, ...)
	end)
end
handle("NewGame", function(game, redOnTop)
	game:NewGame(nil, redOnTop)
end)
handle("StartTurn", function(game, team)
	game:SetTurn(team)
end)
handle("MoveMade", function(game, move)
	local events = game.Board:MakeMove(move)
	game.boardModel:AnimateEvents(events)
end)
handle("ProposeReset", function(game, reset, top)
	if reset then
		if top then
			game.boardModel:DisplayAlternatingText("Proposing new game...", "<-- Press for new game")
		else
			game.boardModel:DisplayAlternatingText("<-- Press for new game", "Proposing new game...")
		end
	elseif not game.gameOver then
		game:UpdateTurnDisplays()
	end
end)
handle("Reset", function(game, move)
	game.boardModel:StartResetAnimation(1)
end)