local maxResults = 200

local module = {}

local TweenService = game:GetService("TweenService")
local tweenInfo = TweenInfo.new(0.3)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AuthorDirectory = require(ReplicatedStorage.AuthorDirectory)
local ObjectList = require(ReplicatedStorage.Utilities.ObjectList)
local Books = require(ReplicatedStorage.BooksClient)
local books = Books:GetBooks()
local gui = ReplicatedStorage.Guis.BookSearch
gui.Enabled = false
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
gui.Parent = localPlayer.PlayerGui
local searchFrame = gui.Search

local resultsFrame = searchFrame.Results
local results -- list of book
local entry = resultsFrame.Entry
entry.Parent = nil
local entries = {entry}
for i = 2, maxResults do
	entries[i] = entry:Clone()
	entries[i].LayoutOrder = i
end
local shrunk = false
local entrySizeY = entry.Size.Y.Offset
local origSize = resultsFrame.Size
local shrinkSize = UDim2.new(resultsFrame.Size.X, UDim.new(0, entrySizeY))
local origPos = resultsFrame.Position
local shrinkPos = UDim2.new(resultsFrame.Position.X, resultsFrame.Position.Y)
local tween
local function newTween(props, instant)
	if tween then tween:Cancel() end
	if instant then
		for k, v in pairs(props) do
			resultsFrame[k] = v
		end
	else
		tween = TweenService:Create(resultsFrame, tweenInfo, props)
		tween:Play()
	end
end
local function shrink(toIndex)
	shrunk = true
	resultsFrame.Visible = false
	local targetY = (toIndex - 1) * (entrySizeY + 1) - 1 -- +1 for padding, -1 because first entry doesn't have padding
	newTween({
		Position = shrinkPos,
		Size = shrinkSize,
		CanvasPosition = Vector2.new(0, targetY),
	})
	coroutine.wrap(function() -- CanvasPosition doesn't end up in correct spot, so fix it when the tween finishes:
		if tween.Completed:Wait() == Enum.PlaybackState.Completed then
			resultsFrame.CanvasPosition = Vector2.new(0, targetY)
		end
	end)
end
local function expand(instant)
	shrunk = false
	resultsFrame.Visible = true
	newTween({
		Position = origPos,
		Size = origSize,
	}, instant)
end

-- todo pathfind functions -> dif module
local PathfindingService = game:GetService("PathfindingService")
local reachedDist = 5
local recalcDist = 8
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
			if m1 <= reachedDist or (node2 and (node2.Position - root.Position).Magnitude <= m1) then
				setNextNodeIndex(nodeIndex + 1)
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
	raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
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

for i, entry in ipairs(entries) do
	entry.Activated:Connect(function()
		if shrunk then
			clearPathfind()
			expand()
			return
		end
		local book = results[i]
		if not book then return end
		pathfindTo(book)
		shrink(i)
	end)
end

local function titleSearch(value)
	local results = {}
	value = value:lower()
	for _, book in ipairs(books) do
		if book.Title:find(value, 1, true) then
			results[#results + 1] = book
		end
	end
	return results
end
local function authorSearch(value)
	--[[So what's our new authorSearch algorithm need to be?
	I know that if you look for "X" and "X" maps to an author ID, then we want all books with that author ID
		Notably, there could be multiple IDs here
	Also, if any author name includes "X" then we want that one too, regardless of id
	]]
	local results = {}
	local authorIds
	local authorId = tonumber(value)
	if not authorId then -- see if can convert to userId. We can only do this if 'value' is the name of a player in the server
		local player = Players:FindFirstChild(value)
		if player then
			authorId = player.UserId
		end
	end
	if authorId then
		authorIds = {authorId}
	else
		authorIds = AuthorDirectory.ExactMatches(authorId or value)
		if not authorIds or #authorIds == 0 then -- todo consider allowing both but at different priorities
			authorIds = AuthorDirectory.PartialMatches(authorId or value)
		end
	end
	if authorIds and #authorIds > 0 then
		for _, authorId in ipairs(authorIds) do
			for _, book in ipairs(books) do
				local lookup = Books:GetAuthorIdLookup(book)
				if lookup[authorId] then
					results[#results + 1] = book
				end
			end
		end
	end
	if #results > 0 then -- todo consider continuing but making the rest a lower priority
		return results
	end
	for _, book in ipairs(books) do
		if Books:AuthorNamesContainsFullWord(book, value) then
			results[#results + 1] = book
		end
	end
	if #results > 0 then -- todo consider allowing to continue at lower priority
		return results
	end
	for _, book in ipairs(books) do
		if Books:AuthorNamesContain(book, value) then
			results[#results + 1] = book
		end
	end
	return results
end

local box = searchFrame.TextBox
local search = titleSearch
local title = searchFrame.SortBy.Title
local author = searchFrame.SortBy.Author
local function highlight(obj)
	obj.TextStrokeTransparency = 0
	obj.TextTransparency = 0
end
local function unhighlight(obj)
	obj.TextStrokeTransparency = 1
	obj.TextTransparency = 0.25
end
local function performSearch()
	if box.Text == "" then return end
	results = search(box.Text)
	local num = math.min(#results, 200)
	for i = 1, num do
		local entry = entries[i]
		local book = results[i]
		entry.Text = ("%s by %s%s"):format(book.Title, book.AuthorLine, book.Genre and (" (%s)"):format(book.Genre) or "")
		entry.Parent = resultsFrame
	end
	resultsFrame.CanvasSize = UDim2.new(0, 0, 0, entry.Size.Y.Offset * num)
	for i = num + 1, #entries do
		entries[i].Parent = nil
	end
end
title.Activated:Connect(function()
	search = titleSearch
	highlight(title)
	unhighlight(author)
	performSearch()
end)
author.Activated:Connect(function()
	search = authorSearch
	highlight(author)
	unhighlight(title)
	performSearch()
end)
box:GetPropertyChangedSignal("Text"):Connect(performSearch)

local open = false
local hidden = false
function module:Open()
	open = true
	if not hidden then
		gui.Enabled = true
	end
end
function module:Close()
	open = false
	clearPathfind()
	stopScanning()
	gui.Enabled = false
	if shrunk then
		expand(true)
	end
end
function module:Hide()
	gui.Enabled = false
end
function module:Unhide()
	if open then
		gui.Enabled = true
	end
end

localPlayer.CharacterAdded:Connect(function()
	if gui.Enabled then
		module:Close()
	end
end)

return module