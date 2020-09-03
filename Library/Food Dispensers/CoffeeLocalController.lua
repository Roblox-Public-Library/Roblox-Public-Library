local maxActivationDist = 32
local TweenService = game:GetService("TweenService")
local remote = game.ReplicatedStorage.RequestCoffee
local localPlayer = game.Players.LocalPlayer
local function closeTo(obj)
	local char = localPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and (root.Position - obj.Position).Magnitude <= maxActivationDist
end
for _, machine in ipairs(game.ReplicatedStorage.GetCoffeeMachines:InvokeServer()) do
	local screen = machine.Screen
	local frame = screen.SurfaceGui.Frame
	for _, c in ipairs(frame:GetChildren()) do
		if c:IsA("TextButton") then
			c.Activated:Connect(function()
				if closeTo(screen) then
					remote:FireServer(c)
				end
			end)
		end
	end
end
remote.OnClientEvent:Connect(function(drink, sound, origSize, origCF)
	TweenService:Create(drink, TweenInfo.new(sound.TimeLength), {
		Size = origSize,
		CFrame = origCF,
	}):Play()
end)