local Players = game.Players
local Board = require(script.Parent.Board)
local Move = Board.Move

local Game = {}
Game.__index = Game
function Game.new(board, checkersModel)
	local self = setmetatable({
		redOnTop = false,
		checkersModel = checkersModel,
		board = board,
		-- redPlayer
		-- blackPlayer
		turn = "Red",
	}, Game)
	return self:init()
end
function Game:init()
	local model = self.checkersModel
	model.Top:GetPropertyChangedSignal("Occupant"):Connect(function()
		self:PlayerSatDown(Players:GetPlayerFromCharacter(model.Top.Occupant.Parent), self.redOnTop and "Red" or "Black")
	end)
	model.Bottom:GetPropertyChangedSignal("Occupant"):Connect(function()
		self:PlayerSatDown(Players:GetPlayerFromCharacter(model.Bottom.Occupant.Parent), self.redOnTop and "Black" or "Red")
	end)
	return self
end
function Game.Deserialize(game)
	-- Server->client only so no validation required
	game.board = Board.Deserialize(game.board)
	return setmetatable(game, Game):init()
end
function Game:PlayerSatDown(player, team)
	self[team == "Red" and "redPlayer" or "blackPlayer"] = player
end
function Game:PlayerForTeam(team)
	--	Returns the player that is allowed to move on behalf of 'team'
	return team == "Red" and self.redPlayer or self.blackPlayer or self.redPlayer -- extra 'or' in case blackPlayer is nil; this allows a solo player to control both sides
end
function Game:TryMove(player, move)
	if not player == self:PlayerForTeam(self.turn) then return false end -- player not allowed to make a move at this time
	-- todo don't allow moves if game is over
	return self.board:TryMove(self.turn, move)
end

return Game