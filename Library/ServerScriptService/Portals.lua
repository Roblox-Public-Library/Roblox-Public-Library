local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage.Remotes
local Players = game:GetService("Players")
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

local askingAboutTP = {} -- Player -> TeleportPart we're asking about
local nearTP = {} -- Player -> TeleportPart that they are/have been asked about and haven't walked away from yet
Players.PlayerRemoving:Connect(function(player)
	askingAboutTP[player] = nil
	nearTP[player] = nil
end)
local function newRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local teleportRemote = newRemote("Teleport") --(placeId, teleportPart, placeName)
newRemote("TeleportWalkedAway").OnServerEvent:Connect(function(player, teleportPart)
	if askingAboutTP[player] == teleportPart then
		askingAboutTP[player] = nil
	end
	if nearTP[player] == teleportPart then
		wait(1) -- A player can trigger .Touch despite being far enough away to trigger WalkedAway.
		--	Waiting adds a debounce time to prevent the confirmation message from appearing a second time.
		nearTP[player] = nil
	end
end)
newRemote("TeleportCancel").OnServerEvent:Connect(function(player)
	askingAboutTP[player] = nil
end)

return {
	Setup = function(teleportPart)
		local parent = teleportPart.Parent
		local id = parent.Id.Value
		if math.floor(id) ~= id then
			error(teleportPart:GetFullName() .. "'s Id must be an integer, not " .. tostring(id))
		end
		local textLabel = parent.TextBrick.Front.Frame.TextLabel
		local placeName = textLabel.Text -- starting default value
		if placeName == "" then
			placeName = "Unknown"
			textLabel.Text = "(Loading...)"
		end
		teleportPart.Touched:Connect(function(hit)
			local player = game.Players:GetPlayerFromCharacter(hit.Parent)
			if player and not askingAboutTP[player] and nearTP[player] ~= teleportPart then
				askingAboutTP[player] = teleportPart
				nearTP[player] = teleportPart
				teleportRemote:FireClient(player, id, teleportPart, placeName)
			end
		end)
		placeName = getPlaceName(id)
		if placeName ~= "" then
			textLabel.Text = placeName
		else
			placeName = textLabel.Text
		end
	end,
}