local shineColor = Color3.new(1, 1, 1) -- TextColor3 for TextButtons when clicked on
local shineDuration = 0.25
local flavourToName = {
	Regular = "Coffee",
	-- all others just use the flavour as the name
}


local module = {}
local list = {}
local buttonToMachine = {}
local buttonOrigColour = {}
local machineToCup = {}
local buttonToSound = {}
function module:Add(machine)
	list[#list + 1] = machine
	machineToCup[machine] = machine.Cup
	machine.Cup.Parent = nil
	local frame = machine.Screen.SurfaceGui.Frame
	local defaultSound = machine:FindFirstChildWhichIsA("Sound", true)
	for _, c in ipairs(frame:GetChildren()) do
		if c:IsA("TextButton") then
			buttonToMachine[c] = machine
			buttonOrigColour[c] = c.TextColor3
			buttonToSound[c] = c:FindFirstChildWhichIsA("Sound") or defaultSound
		end
	end
end

local getListRemote = Instance.new("RemoteFunction")
getListRemote.Name = "GetCoffeeMachines"
getListRemote.Parent = game.ReplicatedStorage
getListRemote.OnServerInvoke = function(player)
	return list
end

local animatingForPlayer = {}
local tool = script.Coffee

local requestCoffee = Instance.new("RemoteEvent")
requestCoffee.Name = "RequestCoffee"
requestCoffee.Parent = game.ReplicatedStorage
requestCoffee.OnServerEvent:Connect(function(player, button)
	local machine = buttonToMachine[button]
	if not machine or animatingForPlayer[player] then return end
	local origCup = machineToCup[machine]
	local cup = origCup:Clone()
	local drink = cup.Drink
	drink.BrickColor = button.Color.Value
	local origSize = drink.Size
	local origCF = drink.CFrame
	-- Note: drink is a cylinder on its side; must shrink its X size to affect its height
	drink.Size = Vector3.new(0.05, origSize.Y, origSize.Z)
	local base = cup.Base
	local extraHeight = base.Position.Y + base.Size.Y / 2 - (drink.Position.Y - origSize.X / 2)
	drink.CFrame = drink.CFrame - Vector3.new(0, origSize.X / 2 + 0.025 - extraHeight, 0)
	cup.Parent = machine.Storage
	local sound = buttonToSound[button]
	requestCoffee:FireAllClients(drink, sound, origSize, origCF)
	animatingForPlayer[player] = true
	sound:Play()
	button.TextColor3 = shineColor
	local dt = wait(shineDuration)
	button.TextColor3 = buttonOrigColour[button]
	wait(sound.TimeLength - dt)
	drink.Size = origSize
	drink.CFrame = origCF
	animatingForPlayer[player] = nil
	if player.Parent then -- Give coffee (else player left)
		local cof = tool:Clone()
		for _, child in ipairs(cup:GetChildren()) do
			child:Clone().Parent = cof
		end
		cof.Name = flavourToName[button.Text] or button.Text
		cof.ToolTip = cof.Name
		cof.Parent = player.Backpack
		cof.Weld.Disabled = false
	end
	cup:Destroy()
end)
script.CoffeeLocalController.Parent = game.StarterPlayer.StarterPlayerScripts
return module