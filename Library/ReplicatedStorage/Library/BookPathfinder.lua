local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ObjectList = require(ReplicatedStorage.Utilities.ObjectList)

local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local localPlayer = game:GetService("Players").LocalPlayer

local BookPathfinder = {}

local reachedDist = 5
local recalcDist = 10.5 -- note: must be > 2 * reachedDist
local nodeExtraHeight = Vector3.new(0, 2, 0)
--local nodeTweenHeight = 0.5 -- todo implement
--local nodeTweenTime = 1
local RunService = game:GetService("RunService")
local nodeFolder = Instance.new("Folder")
nodeFolder.Name = "Pathfind Nodes"
nodeFolder.Parent = workspace
local node = Instance.new("Part")
node.Size = Vector3.new(1, 1, 1)
node.TopSurface = Enum.SurfaceType.Smooth
node.BottomSurface = Enum.SurfaceType.Smooth
node.Shape = Enum.PartType.Ball
node.Anchored = true
node.CanCollide = false
node.Material = Enum.Material.SmoothPlastic
node.BrickColor = BrickColor.Green()
local nodes = ObjectList.new(function() return node:Clone() end, 200, function(n) n.Parent = nil end)
local nodeIndex = 1
local scanning = false
local function setNextNodeIndex(index)
	for i = nodeIndex, index - 1 do
		nodes:Get(i).Parent = nil
	end
	nodeIndex = index
end
local highlightedBook
local boxTweenInfo = TweenInfo.new(0.7)
local boxTween
local boxStartColor, boxEndColor = Color3.new(1, 1, 1), Color3.fromRGB(170, 120, 255)
local boxHandles = ObjectList.new(function()
	local boxHandle = Instance.new("BoxHandleAdornment")
	boxHandle.Transparency = 0.5
	boxHandle.AlwaysOnTop = false
	return boxHandle
end):SetAdaptFunc(function(boxHandle, model)
	boxHandle.Color3 = boxStartColor
	boxHandle.Size = model.Size + Vector3.new(0, 0, 0.25)
	if boxTween then boxTween:Cancel() boxTween = nil end
	boxHandle.Adornee = model
	boxHandle.Parent = model
end)
local function highlightBook(book)
	if highlightedBook == book then return end
	boxHandles:AdaptToList(book.Models)
	coroutine.wrap(function()
		local nextColor = boxEndColor
		while boxHandles:Count() > 0 do
			boxHandles:ForEach(function(i, boxHandle)
				local tween = TweenService:Create(boxHandle, boxTweenInfo, {Color3 = nextColor})
				if i == 1 then boxTween = tween end
				tween:Play()
			end)
			if boxTween.Completed:Wait() == Enum.PlaybackState.Cancelled then return end
			nextColor = nextColor == boxEndColor and boxStartColor or boxEndColor
		end
	end)()
	highlightedBook = book
end
local function unhighlightBook()
	if boxTween then boxTween:Cancel() end
	boxHandles:EmptyList()
	highlightedBook = nil
end
local function clearPathfind()
	unhighlightBook()
	for i = nodeIndex, nodes:Count() do
		nodes:Get(i).Parent = nil
	end
	nodeIndex = nodes:Count() + 1
end
local pathfindTarget, pathfindTargetBook
local function stopScanning()
	if scanning then
		scanning:Disconnect()
		scanning = false
		pathfindTarget, pathfindTargetBook = nil, nil
	end
end
function BookPathfinder.Clear()
	stopScanning()
	clearPathfind()
end
local pathfindTo
local function repathfind()
	local targetBook = pathfindTargetBook
	stopScanning()
	pathfindTo(targetBook)
end
local function startScanning()
	if scanning then return end
	scanning = RunService.Heartbeat:Connect(function()
		local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local node1, node2 = nodes:Get(nodeIndex), nodes:Get(nodeIndex + 1)
		if node1 then
			local m1 = (node1.Position - root.Position).Magnitude
			if m1 <= reachedDist then
				setNextNodeIndex(nodeIndex + 1)
			elseif node2 and (node2.Position - root.Position).Magnitude <= m1 then
				setNextNodeIndex(nodeIndex + 2)
			elseif m1 >= recalcDist then
				repathfind()
			end
		elseif (pathfindTarget.Position - root.Position).Magnitude >= recalcDist then
			repathfind()
		end
	end)
end
local pathfindTargetFromBookModel do -- raycasting setup
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	local list = {}
	local function search(folder)
		for _, c in ipairs(folder:GetDescendants()) do
			if c.ClassName == "Model" and c.Name == "Floor" then
				list[#list + 1] = c
			end
		end
	end
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name:find("Hall") then
			search(obj)
		end
	end
	raycastParams.FilterDescendantsInstances = list
	pathfindTargetFromBookModel = function(bookModel)
		local result = workspace:Raycast(bookModel.Position, Vector3.new(0, -15, 0), raycastParams)
		return result and result.Position + Vector3.new(0, 2, 0) or bookModel.Position
	end
end
local path = PathfindingService:CreatePath()
local function acceptableWaypoints(waypoints, targetPos)
	local n = waypoints and #waypoints
	return n and n > 0 and waypoints[n].Position.Y <= targetPos.Y + 1 -- if position.Y > targetPos.Y then pathfinding went to the floor above
end
local cfTranslationAttempt, numCFTranslationAttempts do
	local key = {"RightVector", "RightVector", "UpVector", "LookVector", "LookVector"}
	local dist = 4
	local multiplier = {2, dist, -dist, -dist, dist}
	numCFTranslationAttempts = #key
	-- RightVector * 2 will work for books whose spine faces outward
	-- UpVector * -2 will work for books whose front cover faces outward
	-- LookVector * +/-2 will work for books that are lying down
	cfTranslationAttempt = function(cf, i)
		return cf[key[i]] * multiplier[i]
	end
end
local function getBookModelForPathfinding(book, root)
	-- Choose model nearest to player character position
	local models = book.Models
	local best = models[1]
	if #models > 1 then
		local bestDist = (best.Position - root.Position).Magnitude
		for i = 2, #models do
			local model = models[i]
			local dist = (model.Position - root.Position).Magnitude
			if dist < bestDist then
				bestDist = dist
				best = models[i]
			end
		end
	end
	return best
end
pathfindTo = function(book)
	pathfindTargetBook = book
	highlightBook(book)
	local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local bookModel = getBookModelForPathfinding(book, root)
	pathfindTarget = bookModel
	local targetPos = pathfindTargetFromBookModel(bookModel)
	local waypoints
	local function try(pos)
		path:ComputeAsync(root.Position, pos)
		waypoints = path:GetWaypoints()
		return acceptableWaypoints(waypoints, targetPos)
	end
	local success = try(targetPos)
	if not success then -- try to get a lower down position away from the shelf
		local cf = bookModel.CFrame
		local down = targetPos - Vector3.new(0, 3.9, 0)
		for i = 1, numCFTranslationAttempts do
			local translation = cfTranslationAttempt(cf, i)
			success = math.abs(translation.Y) < 0.2 and try(down + translation)
			if success then break end
		end
	end
	if success then
		nodes:AdaptToList(waypoints, function(node, waypoint)
			node.Position = waypoint.Position + nodeExtraHeight
			node.Parent = nodeFolder
		end)
		nodeIndex = 1
		startScanning()
	else
		print("Failed to find a path to", bookModel:GetFullName())
	end
end
BookPathfinder.PathfindTo = pathfindTo

return BookPathfinder