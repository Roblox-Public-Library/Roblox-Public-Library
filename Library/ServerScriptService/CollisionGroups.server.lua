local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local function playerAdded(player)
	local function charAdded(char)
		for _, c in ipairs(char:GetDescendants()) do
			if c:IsA("BasePart") then
				PhysicsService:SetPartCollisionGroup(c, "Players")
			end
		end
	end
	if player.Character then charAdded(player.Character) end
	player.CharacterAdded:Connect(charAdded)
end
Players.PlayerAdded:Connect(playerAdded)
for _, player in ipairs(Players:GetPlayers()) do playerAdded(player) end