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
local AUTO_PLAY = false -- for debugging (automatically submits random moves)

local base = Game.init
function Game:init()
	base(self)
	self.boardModel = BoardModel.new(self.Board, self.checkersModel)
	-- Initialize boardModel displays based on game state
	-- PlayerSatDown will trigger UpdateTurnDisplays unless GameOver so we only need to care of GameOver
	if self.GameOver then
		local event = if self.Victor then Board.Events.Victory(self.Victor) else Board.Events.Draw()
		self.boardModel:AnimateEvents({event})
	end
	if self.redPlayer then
		self:PlayerSatDown(self.redPlayer, "Red")
	end
	if self.blackPlayer then
		self:PlayerSatDown(self.blackPlayer, "Black")
	end
	return self
end
local base = Game.NewGame
function Game:NewGame(board, redOnTop)
	base(self, board, redOnTop)
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
		playerControls = Controls.new(self, self.boardModel, self.checkersModel, function(move)
			remotes.TryMove:FireServer(self.checkersModel, move)
		end)
	elseif self:PlayerForTeam(Board.OppositeTeam[team]) == localPlayer and self:PlayerForTeam(self.Turn) ~= localPlayer then
		playerControls:ClearMove() -- player may have been playing both sides; cancel any in-progress move
	end
	if not self.GameOver then
		self:UpdateTurnDisplays()
	end
end
local base = Game.PlayerStoodUp
function Game:PlayerStoodUp(player, team)
	base(self, player, team)
	if player == localPlayer then
		playerControls:Destroy()
		playerControls = nil
	end
end
local base = Game.SetTurn
function Game:SetTurn(turn)
	base(self, turn)
	self:UpdateTurnDisplays()
	if AUTO_PLAY then
		if self:PlayerForTeam(turn) == localPlayer then
			local validMoves = self.Board:GetAllValidMoves(turn)
			local c = 0
			for _, list in pairs(validMoves) do c += #list end
			c = math.random(1, c)
			for _, list in pairs(validMoves) do
				for _, move in ipairs(list) do
					c -= 1
					if c == 0 then
						remotes.TryMove:FireServer(self.checkersModel, move)
						break
					end
				end
				if c == 0 then break end
			end
		end
	end
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
	setmetatable(move, Move)
	local events = game.Board:MakeMove(move)
	game:moveMade(move, events)
	game.boardModel:AnimateEvents(events)
end)
handle("ProposeReset", function(game, reset, top)
	if reset then
		if top then
			game.boardModel:DisplayAlternatingText("Proposing new game...", "<-- Press for new game")
		else
			game.boardModel:DisplayAlternatingText("<-- Press for new game", "Proposing new game...")
		end
	elseif not game.GameOver then
		game:UpdateTurnDisplays()
	end
end)
handle("Reset", function(game, move)
	game.boardModel:StartResetAnimation(1)
end)