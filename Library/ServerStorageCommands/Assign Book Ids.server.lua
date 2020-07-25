-- To be run in the command bar when there are new books
local function isBook(obj)
	if obj:IsA("BasePart") and obj:FindFirstChild("ClickDetector") then
		local script = obj:FindFirstChildOfClass("Script")
		return script and script:FindFirstChild("BookColor")
	end
	return false
end
local new = {} -- list of new book models
local scriptContentToId = {}
local max = 0
for _, folder in ipairs({workspace.Books, workspace["Post Books"]}) do
	for _, c in ipairs(folder:GetDescendants()) do
		if isBook(c) then
			local id = c:FindFirstChild("Id")
			if id then
				scriptContentToId[c:FindFirstChildOfClass("Script").Source] = id
				if id.Value > max then max = id.Value end
			else
				new[#new + 1] = c
			end
		end
	end
end
local nextId = max + 1
for _, model in ipairs(new) do
	local id = Instance.new("IntValue")
	id.Name = "Id"
	id.Value = nextId
	nextId = nextId + 1
	id.Parent = model
	scriptContentToId[model:FindFirstChildOfClass("Script").Source] = id
end
for _, c in ipairs(workspace.BookOfTheMonth:GetDescendants()) do
	if isBook(c) then
		if not c:FindFirstChild("Id") then
			local id = scriptContentToId[c:FindFirstChildOfClass("Script").Source]
			if id then
				id:Clone().Parent = c
			else
				warn("No book script is the same as the one in", c:GetFullName())
			end
		end
	end
end