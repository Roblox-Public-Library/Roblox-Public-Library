local Players = game:GetService("Players")
local Board = require(script.Parent.Board)
local Move = Board.Move

local Game = {}
Game.__index = Game
function Game.new(board, checkersModel, redOnTop)
	local self = setmetatable({
		redOnTop = not not redOnTop, -- defaults to false
		checkersModel = checkersModel,
		Board = board,
		-- redPlayer
		-- blackPlayer
		Turn = "Red",
		-- GameOver = false
		-- Victor = "Red"/"Black"/nil for draw (only when GameOver is true)
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
		GameOver = self.GameOver,
		Victor = self.Victor,
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
function Game:moveMade(move, events)
	local last = events[#events]
	if last.Type == "Draw" or last.Type == "Victory" then
		self:RecordGameOver(if last.Type == "Victory" then last.Team else nil)
	end
end
function Game:TryMove(player, move)
	if player ~= self:PlayerForTeam(self.Turn) or self.GameOver then return false end -- player not allowed to make a move at this time
	local success, events = self.Board:TryMove(self.Turn, move)
	if success then
		self:moveMade(move, events)
	end
	return success, events
end
function Game:SetTurn(turn)
	self.Turn = turn
end
function Game:RecordGameOver(victor)
	self.GameOver = true
	self.Victor = victor -- can be nil for draw
end
function Game:NewGame(board, redOnTop)
	if redOnTop ~= nil then
		redOnTop = not not redOnTop
		if self.redOnTop ~= redOnTop then
			self.redOnTop = redOnTop
			self.redPlayer, self.blackPlayer = self.blackPlayer, self.redPlayer
		end
	end
	self.Board = board or Board.new(self.redOnTop)
	self.GameOver = false
	self.Victor = nil
	self.Turn = "Red"
end
function Game:PlayerCanMove(player)
	return not self.GameOver and player == self:PlayerForTeam(self.Turn)
end

return Game