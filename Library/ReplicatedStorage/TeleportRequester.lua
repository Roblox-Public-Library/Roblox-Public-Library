local TeleportRequester = {}

local MessageBox = require(game:GetService("ReplicatedStorage").MessageBox)

local MarketplaceService = game:GetService("MarketplaceService")
local TELE_RADIUS = 3
local teleInRange = {} 		-- UserId -> Part
local placeNames = {} 		-- Int -> Name
local teleportPositions = {}-- Part -> Vector3


for i,v in ipairs(game.Workspace:GetChildren()) do
	if v.Name == "Portal" then
		
		local id = v.Teleporter.id.Value
		
		-- Get tele name
		local success, placeInfo = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id)
		if success then
			placeNames[id] = placeInfo.Name
			v.TextBrick.Front.Frame.TextLabel.Text = placeNames[id]
		end
		
		teleportPositions[v.Teleporter.Tele] = v.TextBrick.Position
		
	end
end


-- Get distance from player to closest part of the tele Part
local function playerTeleDist(player, tele)
	
	-- Catch error if player has left
	local success, playerPos = pcall(function() return player.Character.HumanoidRootPart.Position end)
	if not success then return 9999 end
	
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
	while true do
		
		wait(0.1)
		magnitude = playerTeleDist(player, tele)	
		
		if magnitude > TELE_RADIUS then
			teleInRange[player.UserId] = nil
			MessageBox.HideMsg(player)
			return 
			
		end		
	end
end


function TeleportRequester.TeleTouched(tele, hit)
	local id = tele.Parent.id.Value
	local player = game.Players:GetPlayerFromCharacter(hit.Parent)
	if player and teleInRange[player.UserId] ~= tele then
		
		teleInRange[player.UserId] = tele
		MessageBox.ShowMsg(player, "Teleport to '"..placeNames[id].."'?", "Yes", "No") 
		
		local watch = coroutine.create(watchPlayer)
		coroutine.resume(watch, player, tele)
		
	end
end


function TeleportRequester.Setup(tele)
	tele.Touched:Connect(function(hit)
		TeleportRequester.TeleTouched(tele, hit)
	end)	
end


return TeleportRequester
