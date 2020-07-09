local TeleportRequester = {}

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleOpenGui = ReplicatedStorage.TeleOpenGui
local TeleGuiClosed = ReplicatedStorage.TeleGuiClosed

local MAX_FOCUS_DIST = 3
local magnitude

local teleportNames = {}
local teleportPositions = {}
local telesStillInRange = {} -- teleIds:(UserId of players still in range - haven't walked away yet - don't reshow GUI)
local playerGuis = {} -- UserId:(id of teleport gui currently open)

for _,v in pairs(game.Workspace:GetChildren()) do
	if v.Name == "Portal" then
		
		local id = v.Teleporter.id.Value
		
		-- Get tele name, display on SurfaceGui
		local success, placeInfo = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id)
		if success then
			teleportNames[id] = placeInfo.Name
			v.TextBrick.Front.Frame.TextLabel.Text = teleportNames[id]
		end
		
		-- Get position
		teleportPositions[id] = v.TextBrick.Position
		
		-- Add to telesStillInRange list
		telesStillInRange[id] = {}
		
	end
end

-- Called when player leaves teleport area
local function removePlayerFromTelesStillInRange(player, teleId)
	for i,v in pairs(telesStillInRange[teleId]) do
		if v == player.UserId then table.remove(telesStillInRange[teleId],i) end
	end
end

-- Client closed gui - update table
TeleGuiClosed.OnServerEvent:Connect(function(player)
	playerGuis[player.UserId] = nil
end)
-- todo handle player leaving without TeleGuiClosed firing

-- Called by coroutine function
local function getShortestDistToTele(player, tele) -- Player, Part
	local playerPos = player.Character.HumanoidRootPart.Position
	local Transform = tele.CFrame:pointToObjectSpace(playerPos) -- Transform into local space
	local HalfSize = tele.Size * 0.5
	local closestPoint = tele.CFrame * Vector3.new( -- Clamp & transform into world space
		math.clamp(Transform.x, -HalfSize.x, HalfSize.x),
		math.clamp(Transform.y, -HalfSize.y, HalfSize.y),
		math.clamp(Transform.z, -HalfSize.z, HalfSize.z)
	)
	return ((closestPoint - playerPos).Magnitude)
end

-- Runs as a coroutine to monitor player dist from a tele, returns when they're out of range
local function monitorPlayerDist(player, tele) -- Player, Part
	while true do
		wait(0.2)
		magnitude = getShortestDistToTele(player, tele)	
		print(magnitude)
		if magnitude > MAX_FOCUS_DIST then 
			removePlayerFromTelesStillInRange(player, tele.Parent.id.Value)
			return 
		end		
	end
end
	
-- Check if player is still in range of a teleport	
local function playerNearTele(player, teleId)
	for _,v in pairs(telesStillInRange[teleId]) do
		if v == player.UserId then return true end
	end
	return false
end

-- Obj touched a teleport
function TeleportRequester.TeleTouched(tele, hit) -- Part, obj that hit
	local id = tele.Parent.id.Value
	local player = game.Players:GetPlayerFromCharacter(hit.Parent)
	if player and playerGuis[player.UserId] ~= id and not playerNearTele(player,id) then
		playerGuis[player.UserId] = id
		table.insert(telesStillInRange[id], player.UserId)
		TeleOpenGui:FireClient(player, id, teleportNames[id])
		local monitor = coroutine.create(monitorPlayerDist)
		coroutine.resume(monitor, player, tele)
	end
end


return TeleportRequester

