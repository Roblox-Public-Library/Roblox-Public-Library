--This file manages all checker games client side
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Checkers = ReplicatedStorage.Checkers
local Board = require(Checkers.Board)
local Move = Board.Move
local BoardModel = require(Checkers.BoardModel)

local remotes = ReplicatedStorage.Remotes.Checkers
local checkersModelToGame = {}
local Game = require(Checkers.Game)(remotes)

local localPlayer = game:GetService("Players").LocalPlayer

local validMoves
local playerGame
local function handle(name, handler)
	remotes[name].OnClientEvent:Connect(function(checkersModel, ...)
		local game = checkersModelToGame[checkersModel]
		handler(game, ...)
	end)
end
handle("NewGame", function(game, redOnTop)
	game.board = Board.new(redOnTop)
end)
handle("StartTurn", function(game, team)
	if game:PlayerForTeam(team) == localPlayer then
		validMoves = playerGame:GetAllValidMoves()
		-- todo notify player it's their turn
		-- todo consider highlighting pieces in validMoves
	end
end)
handle("PlayerJoinedGame", function(game, player, team)
	game:PlayerSatDown(player, team)
	if player == localPlayer then
		playerGame = game
		-- todo init gui
	elseif game:PlayerOpponentToTeam(team) == localPlayer then
		-- todo notify player about opponent (and cancel any input movement if they were playing against themselves)
	end
end)
handle("MoveMade", function(game, move)
	game.board:TryMove(move)
end)
local function tryMove(move) -- todo call when player wants to try and move here
	if not playerGame or playerGame:GetPlayerTurn() ~= localPlayer then return end
	local key = ("%d %d"):format(move.pieceCoord.X, move.pieceCoord.Y)
	if not table.find(validMoves[key], move) then
		return false
	end
	remotes.TryMove:FireServer(playerGame.checkersModel, move)
end
for _, obj in ipairs(remotes.GetGames:InvokeServer()) do
	checkersModelToGame[obj[1]] = Game.Deserialize(obj[2])
end
local base = Game.new
function Game.new(...)
	local self = base(...)
	self.boardModel = BoardModel.new(self.board, self.checkersModel)
	return self
end
local base = Game.NewGame
function Game:NewGame()
	base(self)
	self.boardModel:Reset(self.board)
end
local base = Game.TryMove
function Game:TryMove(player, move)
	local success, events = base(self, player, move)
	if not success then return false end
	self.boardModel:AnimateEvents(events)
end