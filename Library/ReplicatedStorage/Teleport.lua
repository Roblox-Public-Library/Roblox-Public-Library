local TeleportRequester = {}

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleOpenGui = ReplicatedStorage.TeleOpenGui
local TeleGuiClosed = ReplicatedStorage.TeleGuiClosed
local playerGuis = {} -- UserId:(id of teleport gui currently open)

-- Name all teleports on startup
local teleportNames = {}
for _,v in pairs(game.Workspace:GetChildren()) do
	if v.Name == "Tele" then
		local success, placeInfo = pcall(MarketplaceService.GetProductInfo, MarketplaceService, v.id)
		if success then
			teleportNames[v.id] = placeInfo.Name
		end
	end
end

-- Obj touched a teleport
function TeleportRequester.TeleTouched(id, hit)
	local player = game.Players:GetPlayerFromCharacter(hit.Parent)
	if player and playerGuis[player.UserId] ~= id and player.Character:FindFirstChild("TeleDebounce"..id) == nil then

		playerGuis[player.UserId] = id
		TeleOpenGui:FireClient(player, id, teleportNames[id])
		
	end
end

-- Client closed gui - update table
TeleGuiClosed.OnServerEvent:Connect(function(player)
	playerGuis[player.UserId] = nil
end)
-- todo handle player leaving without TeleGuiClosed firing


return TeleportRequester
