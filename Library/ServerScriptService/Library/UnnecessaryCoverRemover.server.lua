-- This script removes any book cover guis that are not visible to the player due to being obstructed.
wait(1)
local start = os.clock()
local magnitude = 0.15
local faceToDir = {
	[Enum.NormalId.Front] = Vector3.new(0, 0, -1),
	[Enum.NormalId.Back] = Vector3.new(0, 0, 1),
	[Enum.NormalId.Left] = Vector3.new(-1, 0, 0),
	[Enum.NormalId.Right] = Vector3.new(1, 0, 0),
	[Enum.NormalId.Top] = Vector3.new(0, 1, 0),
	[Enum.NormalId.Bottom] = Vector3.new(0, -1, 0),
}
local cornerFraction = 0.6 -- raycast starting this much of the way to each corner of the book (from the center of the gui)
local raycastBackMult = 1.5 -- go back this much * magnitude to check for overlapping books
local debugging = false
--local function isBookStyle1(c)
--	local book = c:IsA("ClickDetector") and c.Parent:FindFirstChild("Book")
--	if book and book:IsA("ScreenGui") then
--		return true
--	end
--	return false
--end
--local function isBookStyle2(c)
--	if c:IsA("ClickDetector") and c.Parent:IsA("Part") then
--		local script = c.Parent:FindFirstChildOfClass("Script")
--		return script and script:FindFirstChild("BookColor")
--	end
--	return false
--end
--local function getAllBooks()
--	local books = {}
--	for _, c in ipairs(workspace:GetDescendants()) do
--		if isBookStyle1(c) or isBookStyle2(c) then
--			books[#books + 1] = c.Parent
--		end
--	end
--	return books
--end
local function getAllBooks()
	local books = require(game.ServerScriptService.Books):GetBooks()
	local all = {}
	for _, book in ipairs(books) do
		for _, model in ipairs(book.Models) do
			all[#all + 1] = model
		end
	end
	return all
end

local corners = {}
for x = -1, 1, 2 do
	for y = -1, 1, 2 do
		for z = -1, 1, 2 do
			corners[#corners + 1] = Vector3.new(x, y, z)
		end
	end
end

local faceToCorners = {}
local function getCorners(face)
	local v = faceToCorners[face]
	if not v then
		local dir = faceToDir[face]
		table.sort(corners, function(a, b)
			return (a - dir).Magnitude < (b - dir).Magnitude
		end)
		-- First 4 corners are the ones to raycast from
		v = {}
		for i = 1, 4 do
			v[i] = dir * (1 - cornerFraction) + corners[i] * cornerFraction
		end
	end
	return v
end

local faceData = {}
for face, dir in pairs(faceToDir) do
	faceData[face] = {
		n = 0,
		total = 0,
		vector = dir * magnitude,
		names = {}, -- of destroyed objects
	}
end

local ignore = {}
local filterArg = RaycastParams.new()
filterArg.FilterDescendantsInstances = ignore
filterArg.FilterType = Enum.RaycastFilterType.Blacklist
local n = 0
local total = 0
local allBooks = getAllBooks()
for _, book in ipairs(allBooks) do
	local faceToList = {}
	for _, c in ipairs(book:GetChildren()) do
		if c:IsA("SurfaceGui") or c:IsA("FaceInstance") then
			local list = faceToList[c.Face]
			if not list then list = {}; faceToList[c.Face] = list end
			list[#list + 1] = c
		end
	end
	ignore[1] = book
	local bookSize = book.Size
	for face, list in pairs(faceToList) do
		local data = faceData[face]
		local keep
		for _, corner in ipairs(getCorners(face)) do
			local dir = book.CFrame:VectorToWorldSpace(data.vector)
			local orig = book.CFrame:PointToWorldSpace(corner * book.Size / 2) - dir * raycastBackMult
			dir = dir * (1 + raycastBackMult)
			local result = workspace:Raycast(
				orig,
				dir,
				filterArg)
			if debugging then
				local dest = orig + dir
				local p = Instance.new("Part")
				p.Name = "Corner " .. tostring(corner)
				p.Anchored = true
				p.CanCollide = false
				p.Size = Vector3.new(0.1, 0.1, (dest-orig).Magnitude)
				p.CFrame = CFrame.new((orig+dest)/2, dest)
				p.Parent = book
				if not result then
					p.BrickColor = BrickColor.Green()
					keep = true
					break
				else
					p.Name = "Corner: " .. tostring(result.Instance)
				end
			else
				if not result then
					keep = true
					break
				end
			end
		end
		if not keep then
			if debugging then print("Destroying", book:GetFullName() .. "'s", face.Name, "contents") end
			for _, obj in ipairs(list) do
				obj:Destroy()
				data.names[obj.Name] = true
			end
			data.n = data.n + 1
		end
		data.total = data.total + 1
	end
	if debugging then
		book.Transparency = 0.5
		local stuffing = book:FindFirstChild("Stuffing")
		if stuffing then stuffing.Transparency = 0.5 end
	end
end
for face, stats in pairs(faceData) do
	if stats.n > 0 then
		local nameList = {}
		for name, _ in pairs(stats.names) do
			nameList[#nameList + 1] = ('"%s"'):format(name)
		end
		table.sort(nameList)
		print(("Destroyed %d/%d guis on the %s side (with names %s) since they were covered up"):format(stats.n, stats.total, face.Name, table.concat(nameList, ", ")))
	end
end
print(("Scanning for covered up guis took %.3fs"):format(os.clock() - start))