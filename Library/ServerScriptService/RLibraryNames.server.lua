local group = 2735192 -- put this group as whatever group you want
local guests = "Visitor" -- put this as whatever you want non-members to be called
local function onPlayerAdded(player)
	local role = player:GetRoleInGroup(group)
	local model = Instance.new("Model")
	model.Name = ("%s : %s"):format(player.Name, role == "Guest" and guests or role)
	Instance.new("Humanoid").Parent = model
	local weld = Instance.new("Weld")
	local function onCharacterAdded(character)
		character:WaitForChild("Humanoid").DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		local head = character:WaitForChild("Head")
		local newHead = head:Clone()
		local face = newHead:FindFirstChild("face")
		if face then
			face:Destroy()
		end
		head.Transparency = 1
		newHead.Parent = model
		weld.Part0 = head
		weld.Part1 = newHead
		weld.Parent = newHead
		model.Parent = character
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end
game.Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(game.Players:GetPlayers()) do
	onPlayerAdded(player)
end