local Players = game:GetService("Players")
local Board = require(script.Parent.Board)
local Move = Board.Move

local Game = {}
--Game.__index = Game
local function printAndReturn(name, ...)
	if select("#", ...) > 0 then
		print(name, ...)
	end
	return ...
end
local function printAndReturnSkipSelf(name, self, ...)
	print(name, ...)
	return self, ...
end
function Game:__index(key)
	local v = rawget(Game, key)
	if type(v) == "function" and key ~= "PlayerCanMove" and key ~= "PlayerForTeam" then
		return function(...)
			return printAndReturn("->", v(printAndReturnSkipSelf(key, ...)))
		end
	end
	return v
end
function Game.new(board, checkersModel, redOnTop)
	local self = setmetatable({
		redOnTop = not not redOnTop, -- defaults to false
		checkersModel = checkersModel,
		Board = board,
		-- redPlayer
		-- blackPlayer
		Turn = "Red",
		-- gameOver = false
	}, Game)
	return self
end
function Game:init()
	local model = self.checkersModel
	local function initSeat(seat, getTeam)
		local prevPlayer = seat.Occupant and Players:GetPlayerFromCharacter(seat.Occupant.Parent)
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			local player = seat.Occupant and Players:GetPlayerFromCharacter(seat.Occupant.Parent)
			if prevPlayer == player then return end
			if prevPlayer then
				self:PlayerStoodUp(prevPlayer, getTeam())
				prevPlayer = nil
			end
			if player then
				self:PlayerSatDown(player, getTeam())
				prevPlayer = player
			end
		end)
	end
	initSeat(model.Top, function() return if self.redOnTop then "Red" else "Black" end)
	initSeat(model.Bottom, function() return if self.redOnTop then "Black" else "Red" end)
	return self
end
function Game:Serialize()
	-- Must specify a new table because client/server versions of Game add extra variables
	return {
		redOnTop = self.redOnTop,
		checkersModel = self.checkersModel,
		Board = self.Board,
		Turn = self.Turn,
		redPlayer = self.redPlayer,
		blackPieces = self.blackPlayer,
		gameOver = self.gameOver,
	}
end
function Game.Deserialize(game)
	-- Server->client only so no validation required
	game.Board = Board.Deserialize(game.Board, game.redOnTop)
	return setmetatable(game, Game):init()
end
function Game:PlayerSatDown(player, team)
	self[if team == "Red" then "redPlayer" else "blackPlayer"] = player
end
function Game:PlayerStoodUp(player, team)
	self[if team == "Red" then "redPlayer" else "blackPlayer"] = nil
end
function Game:PlayerForTeam(team)
	--	Returns the player that is allowed to move on behalf of 'team'
	return team == "Red" and self.redPlayer or self.blackPlayer or self.redPlayer -- extra 'or' in case blackPlayer is nil; this allows a solo player to control both sides
end
function Game:PlayerForSide(side)
	--	side is "Top" or "Bottom"
	return if self.redOnTop == (side == "Top") then self.redPlayer else self.blackPlayer
end
function Game:NumPlayers()
	return (if self.redPlayer then 1 else 0) + (if self.blackPlayer and self.blackPlayer ~= self.redPlayer then 1 else 0)
end
function Game:TryMove(player, move)
	if not player == self:PlayerForTeam(self.Turn) or self.gameOver then return false end -- player not allowed to make a move at this time
	local success, events = self.Board:TryMove(self.Turn, move)
	if success then
		local e = events[#events]
		if e.Type == "Draw" or e.Type == "Victory" then
			self:GameOver(if e.Type == "Victory" then e.Team else nil)
		else
			self:SetTurn(if self.Turn == "Red" then "Black" else "Red")
		end
	end
	return success, events
end
function Game:SetTurn(turn)
	self.Turn = turn
end
function Game:GameOver(victor)
	self.gameOver = true
end
function Game:NewGame(board, redOnTop)
	if redOnTop ~= nil then
		self.redOnTop = redOnTop
	end
	self.Board = board or Board.new(self.redOnTop)
	self.gameOver = false
end
function Game:PlayerCanMove(player)
	return not self.gameOver and player == self:PlayerForTeam(self.Turn)
end

return Game