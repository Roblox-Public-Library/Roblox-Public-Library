local Players = game:GetService("Players")
local GROUP_ID = 2735192 -- put this group as whatever group you want
local GUEST_ROLE = "Visitor" -- put this as whatever you want non-group-members to be called

local heartbeat = game:GetService("RunService").Heartbeat

local function shouldNotClone(child)
	return child.Name == "Neck" or child:IsA("Attachment") or child:IsA("Decal")
end
local propsToUpdate = {"Color", "Material", "Reflectance"} -- for the head
local function onPlayerAdded(player)
	local role = player:GetRoleInGroup(GROUP_ID)
	local modelName = ("%s : %s"):format(player.Name, role == "Guest" and GUEST_ROLE or role)
	local function onCharacterAdded(character)
		-- Create a new model each time because (as of Sept 2020) Roblox's replication gets messed up otherwise (we get duplicate heads on respawn, for instance)
		local model = Instance.new("Model")
		model.Name = modelName
		local newHumanoid = Instance.new("Humanoid")
		newHumanoid.Parent = model
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		local head = character:WaitForChild("Head")
		local newHead = head:Clone()
		for _, c in ipairs(newHead:GetChildren()) do
			if shouldNotClone(c) then
				c:Destroy()
			end
		end
		local weld = Instance.new("Weld")
		weld.Part0 = head
		weld.Part1 = newHead
		weld.Parent = newHead
		newHead.Parent = model
		model.Parent = character
		weld.Enabled = true
		if newHead:FindFirstChildWhichIsA("SpecialMesh") then newHead:FindFirstChildWhichIsA("SpecialMesh").Scale = Vector3.new(0,0,0) end -- Really bad ugliness, but roblox Humanoid behaviors forced my hand
		for _, prop in ipairs(propsToUpdate) do
			head:GetPropertyChangedSignal(prop):Connect(function()
				newHead[prop] = head[prop]
			end)
		end
		head.ChildAdded:Connect(function(child)
			if shouldNotClone(child) then return end
			if child.Name == "face" then
				local old = newHead:FindFirstChild("face")
				if old then -- default face is generated when we clone the head and needs to be destroyed (Sept 2020)
					old:Destroy()
				end
				heartbeat:Wait() -- must yield before changing child.Parent to prevent a warning from occurring
				child.Parent = newHead
			else
				child:Clone().Parent = newHead
			end
		end)
		script.Parent.UpdateCameraSubjectOnDeath:Clone().Parent = model
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
