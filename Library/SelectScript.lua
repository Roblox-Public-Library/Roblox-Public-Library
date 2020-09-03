local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Books = require(ReplicatedStorage.BooksClient)
local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()
local gui = script.Parent:WaitForChild("BookName")
local right = false
local clickers = {}


for _, obj in pairs(workspace:GetChildren()) do
	local book = Books:FromObj(obj)

	if book then
		clickers[#clickers + 1] = obj
	end
end


local reading = false
local events = require(localPlayer:WaitForChild("PlayerScripts"):WaitForChild("Gui"):WaitForChild("BookGui"))

events.BookOpened:Connect(function()
	reading = true
	gui.Visible = false
end)

events.BookClosed:Connect(function()
	reading = false
end)

local lastEnterTime

local function closeHover()
	if lastEnterTime ~= workspace.DistributedGameTime then
		gui.Visible = false
	end
end

local function createSetHoverTitle(title, author)
	local label = ("%s by %s"):format(title, author)
	return function()
		if not reading then
			gui.Text = label
			gui.Visible = true
			lastEnterTime = workspace.DistributedGameTime
		end
	end
end

if UserInputService.MouseEnabled then
	for _, clickDet in ipairs(clickers) do
		local book = Books:FromObj(clickDet.Parent)
		clickDet.MouseHoverLeave:Connect(closeHover)
		clickDet.MouseHoverEnter:Connect(createSetHoverTitle(book.Title, book.AuthorLine))
	end
end

for _, clickDet in ipairs(clickers) do
	local model = clickDet.Parent
	clickDet.MouseClick:Connect(function()
		if not reading then
			gui.Visible = false
			open:Fire(model, getData:FireServer(model))
		end
	end)
end

mouse.Move:Connect(function()
	if reading then return end
	local x = mouse.X
	local y = mouse.Y
	if not right then
		gui.Position = UDim2.new(0, x + 30, 0, y)
	else
		gui.Position = UDim2.new(0, x - 180, 0, y)
	end
end)

local rightFrame = script.Parent:WaitForChild("Right")

rightFrame.MouseEnter:Connect(function()
	right = true
end)

rightFrame.MouseLeave:Connect(function()
	right = false
end)