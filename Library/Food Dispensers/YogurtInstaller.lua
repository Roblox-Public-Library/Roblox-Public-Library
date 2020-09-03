local machine = script.Parent.Parent
local selection1Name = "Flavors"
local selection2Name = "FlavorsTwo"
local origModel = machine.Yogurt
local origTool = script["Frozen Yogurt"]
local instruction1 = "Select first flavor"
local instruction2 = "Select second flavor"
local function handleSelection1(obj, button)
	obj.FillingOne.BrickColor = button.Color.Value
	obj.FillingOne.Material = button.Material.Value
end
local function handleSelection2(obj, button)
	obj.FillingTwo.BrickColor = button.Color.Value
	obj.FillingTwo.Material = button.Material.Value
end

local module = game.ServerScriptService:FindFirstChild("FoodMachineHandler")
if not module then -- install script
	module = script.FoodMachineHandler
	module.Parent = game.ServerScriptService
else
	script.FoodMachineHandler:Destroy()
end
require(module):Add(machine, selection1Name, selection2Name, origModel, origTool, instruction1, instruction2, handleSelection1, handleSelection2)