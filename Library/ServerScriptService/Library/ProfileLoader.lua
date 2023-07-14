local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = require(ReplicatedStorage.Utilities)
local Event = Utilities.Event
local EventUtilities = Utilities.EventUtilities
local Table = Utilities.Table
local remotes = ReplicatedStorage.Remotes
local Serialization = require(ReplicatedStorage.Utilities.Serialization)

local ServerScriptService = game:GetService("ServerScriptService")
local BookMetricsUpdater = require(ServerScriptService.Library.BookMetricsUpdater)
local	metricsOnline = BookMetricsUpdater.OnlineTracker
local	Update = BookMetricsUpdater.Update
local	isShuttingDown = BookMetricsUpdater.IsShuttingDown
--		isShuttingDown note: it's intentionally taken from BookMetricsUpdater so as to prolong its shutdown routine (enabling functions from BookMetricsUpdater to prolong it without warnings)
local DataStores = require(ServerScriptService.Utilities.DataStores)
local profileStore = DataStores:GetDataStore("ProfileLoader")

local Profile = require(ServerScriptService.Library.Profile)
local NewRemote = require(ServerScriptService.Library.NewRemote)

local sync = require(ServerScriptService.Utilities.SyncTimeWithGoogle)

local Players = game:GetService("Players")
local MemoryStoreService = game:GetService("MemoryStoreService")

local AUTOSAVE_FREQ = 60
local PUBLIC_AUTOSAVE_FREQ = 30
local PROFILE_LOCK_EXPIRY = 60 * 5 + 15
local PROFILE_LOCK_REFRESH = 60 * 5

--[[profileStore layout:
[userId] = {
	Lock = {jobId, expireTime}
	Data = profile:Serialize() -- if a Lock exists, only the server owning that lock can mutate this field
	MSUpdate -- used to store data that didn't successfully get sent to a memory store
}
]]

local ProfileLoader = {}

local profiles = {} -- Player -> Profile
function ProfileLoader.GetProfile(player) return profiles[player] end -- may be nil if not loaded yet
local waitingForProfile = {} -- Player -> Event
local failedUpdateData = {} -- Player -> updateData or nil (data that failed to be submitted to the MS)
ProfileLoader.ProfileLoaded = Event.new() -- (player, profile)

local jobId = Serialization.SerializedJobId

-- local defaultData = {
-- 	-- Lock = {jobId, expireTime}
-- 	-- Data = {}, -- if a lock exists, only the server owning that lock can mutate Data
-- 	Updates = {}, -- List of {updateType, args...} -- premise is that this list can be expanded on by any server, but only cleaned up by a server with a lock
-- }
local function haveLock(data)
	return data.Lock and data.Lock[1] == jobId and data.Lock[2] >= sync.time()
end
local function otherServerHasLock(data)
	return data.Lock and data.Lock[1] ~= jobId and data.Lock[2] >= sync.time()
end
local function tryClaimLock(data, forceClaim)
	local lock = data.Lock
	if not lock then
		lock = {jobId, sync.time() + PROFILE_LOCK_EXPIRY}
		data.Lock = lock
		return true
	end
	if lock[1] == jobId or lock[2] < sync.time() or forceClaim then
		lock[1] = jobId
		lock[2] = sync.time() + PROFILE_LOCK_EXPIRY
		return true
	end
	return false
end

-- local function processUpdates(data, fn) -- returns true if at least one was processed successfully
-- 	local i = 1
-- 	local updates = data.Updates
-- 	local n = #updates
-- 	local anyProcessed = false
-- 	while i <= n do
-- 		if fn(unpack(updates)) then
-- 			table.remove(updates, i)
-- 			n -= 1
-- 			anyProcessed = true
-- 		else
-- 			i += 1
-- 		end
-- 	end
-- 	return anyProcessed
-- end

-- local function getFromKeyPath(t, keyPath)
-- 	local prevKey
-- 	for key in keyPath:gmatch("[^.]+") do
-- 		if prevKey then
-- 			t = t[prevKey]
-- 		end
-- 		prevKey = key
-- 	end
-- 	return t, prevKey
-- end
-- local updateTypeToHandler = {
-- 	-- todo
-- 	-- [type] = function(profile, ...) -> true if processed successfully
-- }
-- local updateTypeToHandler_NoProfileYet = {
-- 	-- todo need these?
-- 	["Set"] = function(data, keyPath, value)
-- 		--	keyPath of the form "key1.key2" (any non-'.' character allowed)
-- 		local t, key = getFromKeyPath(data, keyPath)
-- 		t[key] = value
-- 	end,
-- 	["Delta"] = function(data, keyPath, delta)
-- 		--	keyPath of the form "key1.key2" (any non-'.' character allowed)
-- 		local t, key = getFromKeyPath(data, keyPath)
-- 		t[key] = (t[key] or 0) + delta
-- 	end,
-- }
local lastSave = {} -- [player] = os.clock()
local autosaveQueued = {}
local autosaving = {}
local function waitForSaveQueue(player)
	local yielded = false
	while true do
		local t = lastSave[player] or -math.huge
		local dt = os.clock() - t
		local waitTime = 6 - dt
		if waitTime > 0 then
			task.wait(waitTime)
			yielded = true
			continue
		end
		local co = autosaving[player]
		if co and coroutine.status(co) ~= "dead" then
			task.wait()
			yielded = true
			continue
		end
		break
	end
	return yielded
end
local updatingDSForFailedUpdate = {}
local function updateDSAsyncForFailedUpdate(player)
	--	This is to be used when the player has already left the game and the lock has been lost and yet there are still more failed updates
	if updatingDSForFailedUpdate[player] then return end
	updatingDSForFailedUpdate[player] = true
	Utilities.xpcall(function()
		repeat
			waitForSaveQueue(player)
			local failedDataUsed
			local success = profileStore:UpdateAsync(player.UserId, function(data)
				failedDataUsed = Table.Clone(failedUpdateData[player])
				data.MSUpdate = Update.CombineUpdateData(data.MSUpdate, failedDataUsed)
				return data
			end)
			if not success then
				warn("updateDSAsyncForFailedUpdate UpdateAsync returned unsuccessful")
				return
			end
			if failedDataUsed then
				Update.InvertDeltas(failedDataUsed)
				failedUpdateData[player] = Update.CombineUpdateData(failedDataUsed, failedUpdateData[player])
			end
		until not failedUpdateData[player]
	end)
	updatingDSForFailedUpdate[player] = nil
end
local function submitUpdateDataToMSAsync(player, updateData)
	Update.new(updateData):Send(function() -- on rejected:
		failedUpdateData[player] = Update.CombineUpdateData(failedUpdateData[player], updateData)
		if failedUpdateData[player] and not player.Parent then
			updateDSAsyncForFailedUpdate(player)
		end
	end)
end
local function saveProfileAsync(player, shouldCancel, releaseLock)
	-- Kill older autosave thread (newer one could have 'releaseLock' instruction)
	if autosaveQueued[player] then
		coroutine.close(autosaveQueued[player])
	end
	autosaveQueued[player] = coroutine.running()
	local yielded = waitForSaveQueue(player)
	autosaveQueued[player] = nil
	if yielded and shouldCancel and shouldCancel() then return end

	autosaving[player] = coroutine.running()
	local profile = profiles[player]

	-- Prepare update & failedUpdate
	-- Note that we must not mutate anything until after the UpdateAsync returns
	-- Note that failedUpdateData[player] could theoretically change while UpdateAsync runs
	-- In below, 'update' refers to 'update data meant for MS' while 'failedUpdate' refers to 'update data meant for DS'; we essentially use one or the other based on whether the MS appears to be operational

	-- Disclaimer: not the most elegant solution; a lot could be revised to be simpler by using more functional style instead of PublicChangesFailed/etc & 'failedUpdates' serves a similar purpose as to what BooksProfile is maintaining

	local collectedPublicChanges
	local function getUpdateData()
		if collectedPublicChanges then
			profile.Books:PublicChangesFailed()
		elseif not profile.Books:HasPublicChanges() then
			return nil
		end
		collectedPublicChanges = true
		local publicUpdate = profile.Books:CollectPublicUpdate()
		return if publicUpdate then publicUpdate:Serialize() else nil
	end

	local failedUpdateDataUsed -- so we can essentially "subtract" the update from failedUpdateData later, in case it changed (done in failedUpdateMerged)
	local function getFailedUpdateData()
		failedUpdateDataUsed = Table.DeepClone(failedUpdateData[player])
		return failedUpdateDataUsed
	end
	local function failedUpdateMerged()
		if failedUpdateDataUsed then
			Update.InvertDeltas(failedUpdateDataUsed)
			failedUpdateData[player] = Update.CombineUpdateData(failedUpdateData[player], failedUpdateDataUsed)
		end
	end

	local updateData
	local success = profileStore:UpdateAsync(player.UserId, function(data)
		if shouldCancel and shouldCancel() then return nil end

		-- Update lock
		if releaseLock then
			if haveLock(data) then
				data.Lock = nil
			elseif otherServerHasLock(data) then -- we don't want to overwrite their data, so cancel the operation
				-- The only thing we can do is handle updateData and *not* use data.MSUpdate
				updateData = Update.CombineUpdateData(getUpdateData(), getFailedUpdateData())
				return nil
			end
		else -- we should already have the lock
			tryClaimLock(data, true)
		end

		-- todo public updates here
		-- processUpdates(data, function(updateType, ...)
		-- 	local handler = updateTypeToHandler[updateType]
		-- 	if handler then
		-- 		return handler(profile, ...)
		-- 	end
		-- end)

		data.Data = profile:Serialize()

		-- MSUpdate
		if metricsOnline.Online then -- send any updates to MS
			updateData = Update.CombineUpdateData(data.MSUpdate, getUpdateData(), getFailedUpdateData())
			data.MSUpdate = nil
		else -- MS has been failing; store in profile
			data.MSUpdate = Update.CombineUpdateData(data.MSUpdate, getUpdateData(), getFailedUpdateData())
			updateData = nil
		end

		lastSave[player] = os.clock()
		return data
	end, shouldCancel)
	if success then
		profile:RecordSaved(lastSave[player])
		failedUpdateMerged()
		if collectedPublicChanges then
			profile.Books:PublicChangesSubmitted()
		end
		if updateData then
			-- Try to submit to MS else move to failed
			submitUpdateDataToMSAsync(player, updateData)
		end
	else
		if collectedPublicChanges then
			profile.Books:PublicChangesFailed()
		end
	end
	autosaving[player] = nil
end

Players.PlayerAdded:Connect(function(player)
	local profile
	local shouldCancel = function() return not player.Parent end
	-- Read the data, attempting to lock in the process
	local startTime = os.clock()
	local updateData
	local lockCancelledTryAgain = false
	for i = 1, 3 do -- Try up to 3x, waiting 7 seconds between each attempt (so player won't have to wait longer than 15 seconds if the previous server crashed)
		local claimedLock
		local success, data = profileStore:UpdateAsync(player.UserId, function(data)
			if shouldCancel() then return end
			-- premise of this UpdateAsync is to lock it if we can and deal with any global updates & MSUpdate
			if not data then
				data = {} --Table.DeepClone(defaultData)
			elseif not data.Data then -- old version; upgrade
				data = {Data = data}
			end
			-- In next line we check the time in case UpdateAsync got repeated due to a temporary failure or otherwise repeated
			local forceLock = i == 3 or os.clock() - startTime >= 14
			if not tryClaimLock(data, forceLock) then
				lockCancelledTryAgain = not forceLock
				return nil
			end
			claimedLock = true
			profile = Profile.DeserializeDataStore(data.Data, player)
			-- local anyProcessed = processUpdates(data, function(updateType, ...)
			-- 	local handler = updateTypeToHandler[updateType]
			-- 	if handler then
			-- 		return handler(profile, ...)
			-- 	end
			-- end)
			-- if anyProcessed then
			-- 	data.Data = profile:Serialize()
			-- end
			if metricsOnline.Online and data.MSUpdate then
				updateData = data.MSUpdate
				data.MSUpdate = nil
			end

			lastSave[player] = os.clock()
			return data
		end, shouldCancel)
		if shouldCancel() then return end
		if not success and not lockCancelledTryAgain then
			warn("Error loading", player.Name .. "'s profile", data)
			break
		end
		if profile then break end
		task.wait(7)
		if shouldCancel() then return end
	end
	if not profile then
		profile = Profile.new(player)
		local reason = if os.clock() - startTime >= 10 then "down" else "error"
		profile:MarkTemporary(reason)
	end

	local event = waitingForProfile[player]
	profiles[player] = profile
	if event then
		event:Fire(profile)
		event:Destroy()
		waitingForProfile[player] = nil
	end
	ProfileLoader.ProfileLoaded:Fire(player, profile)

	if profile:IsTemporary() then return end

	if updateData then
		task.spawn(submitUpdateDataToMSAsync, player, updateData)
	end

	local function shouldCancelINC() -- INC meaning also cancel If No Changes
		return shouldCancel() or not profile:HasChanges()
	end
	-- Autosave loop
	while true do
		--[[
		We want to wait until 30 sec since last save
			and autosave then if public changes (or at any point > 30sec)
		then 60
			and autosave then if private changes (or at any point > 60sec)
		then PROFILE_LOCK_REFRESH
			and refresh lock

		This loop is structured so that whenever anything changes, we rerun the whole loop (so we can make sure the player is still in the game and we can adapt to the player's profile being saved by other code)
		]]
		if not player.Parent then return end
		local dt = os.clock() - lastSave[player]
		if dt < PUBLIC_AUTOSAVE_FREQ then
			task.wait(PUBLIC_AUTOSAVE_FREQ - dt)
		elseif dt < AUTOSAVE_FREQ then
			if profile.Books:HasPublicChanges() then
				saveProfileAsync(player, shouldCancelINC)
			else
				EventUtilities.WaitForEvent(profile.Changed, AUTOSAVE_FREQ - dt)
			end
		elseif dt < PROFILE_LOCK_REFRESH then
			if profile:HasChanges() then
				saveProfileAsync(player, shouldCancelINC)
			else
				EventUtilities.WaitForEvent(profile.Changed, PROFILE_LOCK_REFRESH - dt)
			end
		else -- autosave to refresh lock
			saveProfileAsync(player, shouldCancel)
		end
	end
end)
Players.PlayerRemoving:Connect(isShuttingDown:WrapTask(function(player)
	local event = waitingForProfile[player]
	if event then
		event:Destroy()
		waitingForProfile[player] = nil
	end
	local profile = profiles[player]
	if profile then
		if not profile:IsTemporary() then
			saveProfileAsync(player, nil, true)
			if failedUpdateData[player] then
				updateDSAsyncForFailedUpdate(player)
			end
		end
		profile:Destroy()
		profiles[player] = nil
	end
	autosaveQueued[player] = nil
	autosaving[player] = nil
end))

local function new(type, name)
	local r = Instance.new(type)
	r.Name = name
	r.Parent = remotes
	return r
end
local function waitForProfile(player) -- note: may fail to return if the player leaves before their profile loads
	local profile = profiles[player]
	if not profile then
		local event = waitingForProfile[player]
		if not event then
			event = Event.new()
			waitingForProfile[player] = event
		end
		return event:Wait()
	end
	return profile
end
ProfileLoader.WaitForProfile = waitForProfile
new("RemoteFunction", "GetProfile").OnServerInvoke = function(player)
	return waitForProfile(player):Serialize()
end
local function get(key)
	return function(player)
		local profile = waitForProfile(player)
		return profile and profile[key]
	end
end

for moduleName, profileKey in Profile.moduleToKey do
	local module = require(ServerScriptService.Library[moduleName])
	module.InitRemotes(NewRemote.newFolder(remotes, moduleName, get(profileKey)))
end
return ProfileLoader