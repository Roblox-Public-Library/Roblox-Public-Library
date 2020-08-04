local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessageBox = require(ReplicatedStorage.MessageBox)
local remotes = ReplicatedStorage.Remotes
local AUTO_CLOSE_RADIUS = 3

-- Get distance from player to closest part of the tele Part; returns math.huge if the player despawns
local function playerTeleDist(player, tele)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return math.huge end
	local playerPos = root.Position
	local transform = tele.CFrame:PointToObjectSpace(playerPos)
	local halfSize = tele.Size * 0.5
	local closestPoint = tele.CFrame * Vector3.new(
		math.clamp(transform.x, -halfSize.x, halfSize.x),
		math.clamp(transform.y, -halfSize.y, halfSize.y),
		math.clamp(transform.z, -halfSize.z, halfSize.z)
	)
	return ((closestPoint - playerPos).Magnitude)
end

local function watchPlayer(player, tele)
	local magnitude
	repeat
		wait(0.1)
		magnitude = playerTeleDist(player, tele)
	until magnitude > AUTO_CLOSE_RADIUS
	-- todo close MessageBox if it's open to this particular teleport
	remotes.TeleportClear:FireServer() -- todo also call this if player selects Cancel
end
--[[todo



			local response = MessageBox.Show("Teleport to '"..placeName.."'?", "Yes", "No")

			local watch = coroutine.create(watchPlayer)
			coroutine.resume(watch, player, tele)



func = coroutine.wrap(function()
	error("test")
	coroutine.yield()
	coroutine.yield()
end)
func()
func() -- resumes the coroutine each time
]]