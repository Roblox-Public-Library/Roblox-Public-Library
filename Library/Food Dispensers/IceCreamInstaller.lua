local machine = script.Parent.Parent
local selection1Name = "Flavors"
local selection2Name = "Toppings"
local origModel = machine.IceCream
local origTool = script["Ice Cream"]
local instruction1 = "Select flavor"
local instruction2 = "Select topping"
local function handleSelection1(ice, button)
	ice.Scoop.BrickColor = button.Color.Value
end
local function handleSelection2(ice, button)
	ice.Scoop.Topping.Texture = button.ToppingID.Value
end

local module = game.ServerScriptService:FindFirstChild("FoodMachineHandler")
if not module then -- install script
	module = script.FoodMachineHandler
	module.Parent = game.ServerScriptService
else
	script.FoodMachineHandler:Destroy()
end
require(module):Add(machine, selection1Name, selection2Name, origModel, origTool, instruction1, instruction2, handleSelection1, handleSelection2)