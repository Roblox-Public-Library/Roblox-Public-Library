local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessageBox = require(ReplicatedStorage.Gui.MessageBox)
local TeleportService = game:GetService("TeleportService")
local remotes = ReplicatedStorage.Remotes
local AUTO_CLOSE_RADIUS = 7
local localPlayer = game:GetService("Players").LocalPlayer

local function getTeleDist(teleportPart)
	--	Get distance from player to closest part of the teleportPart; returns math.huge if the player despawns
	local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not root then return math.huge end
	local playerPos = root.Position
	local transform = teleportPart.CFrame:PointToObjectSpace(playerPos)
	local halfSize = teleportPart.Size * 0.5
	local closestPoint = teleportPart.CFrame * Vector3.new(
		math.clamp(transform.x, -halfSize.x, halfSize.x),
		math.clamp(transform.y, -halfSize.y, halfSize.y),
		math.clamp(transform.z, -halfSize.z, halfSize.z)
	)
	return (closestPoint - playerPos).Magnitude
end

local function waitUntilWalkAwayFrom(teleportPart)
	local magnitude
	repeat
		wait(0.1)
		magnitude = getTeleDist(teleportPart)
	until magnitude >= AUTO_CLOSE_RADIUS
end

local teleportDetails
--local messageBoxTeleportPart -- the teleport part we're displaying the MessageBox for
local fireNum = 0
remotes.Teleport.OnClientEvent:Connect(function(id, teleportPart, placeName)
	fireNum += 1
	local num = fireNum
	task.spawn(function()
		waitUntilWalkAwayFrom(teleportPart)
		remotes.TeleportWalkedAway:FireServer(teleportPart)
		-- Close the MessageBox if we haven't had a new teleport suggestion.
		-- Because we set num to nil after a response, `num == fireNum` will also be false if the MessageBox has already been closed.
		-- This is important in case the message box was opened again since then.
		if num == fireNum then
			MessageBox.Close()
		end
	end)
	local response = MessageBox.Show("Teleport to "..placeName.."?")
	if response then
		teleportDetails = {id = id, placeName = placeName}
		TeleportService:Teleport(id)
	elseif num == fireNum then
		remotes.TeleportCancel:FireServer()
	end -- otherwise a new teleport suggestion has occurred
	num = nil -- This ensures that the player walking away from the teleport won't close the MessageBox
end)
TeleportService.TeleportInitFailed:Connect(function()
	if not teleportDetails then return end -- teleport from a different system
	if MessageBox.Show("Teleport to " .. teleportDetails.placeName .. " failed. Try again?") then
		TeleportService:Teleport(teleportDetails.id)
	else
		teleportDetails = nil
		remotes.TeleportCancel:FireServer()
	end
end)