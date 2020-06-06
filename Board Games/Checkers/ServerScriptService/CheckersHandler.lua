--This file manages all checker games server side and creates needed remotes

-- Setup remotes
local function create(parent, type, name)
	local obj = Instance.new(type)
	if name then obj.Name = name end
	obj.Parent = parent
	return obj
end
local remotes = game.ReplicatedStorage.Checkers
for _, name in ipairs({
	"NewGame", --(checkersModel, redOnTop)
	"StartTurn", --(checkersModel, team)
	--"PlayerJoinedGame", --(checkersModel, player, team) -- so client from single player can cancel accepting a move if another player replaces them.)
	"MoveMade", --(checkersModel, move)
	-- Client->Server
	"TryMove", --(checkersModel, move)
}) do
	create(remotes, "RemoteEvent", name)
end
for _, name in ipairs({
	"GetGames" --():List<{checkersModel, game}>
}) do
	create(remotes, "RemoteFunction", name)
end

local Board = require(script.Parent.Board)
local Move = Board.Move
local checkersModelToGame = {}

local Game = require(Checkers.Game)(remotes)
local base = Game.new
function Game.new(checkersModel)
	local self = base(Board.new(), checkersModel)
	self.redOnTop = false
	self:finishNewGame()
	-- todo connect player sitting down to playerSatDown
	return self
end
function Game:Fire(remoteName, ...)
	remotes[remoteName]:FireAllClients(self.checkersModel, ...)
end
function Game:FirePlayer(player, remoteName, ...)
	remotes[remoteName]:FireClient(player, self.checkersModel, ...)
end
function Game:FirePlayers(remoteName, ...)
	local remote = remotes[remoteName]
	if self.redPlayer then
		self:FirePlayer(self.redPlayer, remoteName, ...)
	end
	if self.blackPlayer and self.redPlayer ~= self.blackPlayer then
		self:FirePlayer(self.blackPlayer, remoteName, ...)
	end
end
function Game:finishNewGame()
	self:Fire("NewGame", self.redOnTop)
end
function Game:NewGame()
	self.redOnTop = not self.redOnTop
	self.board = Board.new(self.redOnTop)
end
local base = Game.PlayerSatDown
function Game:PlayerSatDown(player, team)
	base(self, player, team)
	--self:FirePlayers("PlayerJoinedGame", player, team)
	if self.Turn == team then -- todo don't do this if game over
		self:FirePlayers("StartTurn", team)
	end
end

remotes.TryMove.OnServerEvent:Connect(function(player, checkersModel, move)
	local game = checkersModelToGame[checkersModel]
	if not game then print("No game for", checkersModel) return end -- todo get rid of print statements when done debugging
	move = Move.FromClient(move)
	if not move then print("Invalid move") return end
	local legal, eventList = game:TryMove(move)
	if not legal then print("Illegal move") return end
	self:Fire("MoveMade", eventList)
end)

create(script, "BindableFunction", "Add").OnInvoke = function(model)
	checkersModelToGame[model] = Game.new(model)
end
remotes.GetGames.OnServerInvoke = function(player)
	local list = {}
	for checkersModel, game in pairs(checkersModelToGame) do
		list[#list + 1] = {checkersModel, game}
	end
	return list
end