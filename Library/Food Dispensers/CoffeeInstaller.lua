local machine = script.Parent

local module = game.ServerScriptService:FindFirstChild("CoffeeMachinesHandler")
if not module then -- install script
	module = script.CoffeeMachinesHandler
	module.Parent = game.ServerScriptService
end
require(module):Add(machine)
script:Destroy()