local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage.Remotes
local MarketplaceService = game:GetService("MarketplaceService")
local NUM_ATTEMPTS = 30 -- times to try fetching the name of a place
local SECONDS_BETWEEN_ATTEMPTS = 30

local placeNames = {} -- PlaceId -> Name
local placeNameEvents = {} -- PlaceId -> Event (only exists before MarketplaceService returns a value)
local function getPlaceName(id) -- Note: returns "" if it fails to get the name
	local placeName = placeNames[id]
	if not placeName then
		if placeNameEvents[id] then
			return placeNameEvents[id]:Wait()
		end
		local event = Instance.new("BindableEvent")
		placeNameEvents[id] = event.Event
		for i = 1, NUM_ATTEMPTS do
			local success, placeInfo = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id)
			if success then
				placeName = placeInfo.Name
				break
			elseif i == 1 then
				warn("Error attempting to get place name for teleport (id", id .. "):", placeInfo)
			end
			wait(SECONDS_BETWEEN_ATTEMPTS)
		end
		placeName = placeName or ""
		placeNames[id] = placeName
		event:Fire(placeName)
		event:Destroy()
		placeNameEvents[id] = nil
	end
	return placeName
end

local teleInRange = {} -- UserId -> Part
local function newRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local teleportRemote = newRemote("Teleport")
newRemote("TeleportClear").OnServerEvent:Connect(function(player)
	teleInRange[player] = nil
end)

return {
	Setup = function(tele)
		local parent = tele.Parent
		local id = tele.Parent.id.Value
		if not type(id) == "number" and math.floor(id) == id then
			error(tele:GetFullName() .. "'s ID must be an integer, not " .. tostring(id))
		end
		local placeName = getPlaceName(id)
		if placeName ~= "" then
			parent.TextBrick.Front.Frame.TextLabel.Text = placeName
		end
		tele.Touched:Connect(function(hit)
			local player = game.Players:GetPlayerFromCharacter(hit.Parent)
			if player and not teleInRange[player.UserId] then
				teleInRange[player.UserId] = tele
				teleportRemote:FireClient(player, id, tele, placeName)
			end
		end)
	end,
}