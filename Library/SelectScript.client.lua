local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Books = require(ReplicatedStorage.Library.BooksClient)
local BookGui = require(ReplicatedStorage.Gui.BookGui)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local	localPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

local mouse = localPlayer:GetMouse()
local gui = script.Parent:WaitForChild("BookName")
local right = false

local considerWarn
local timesLeft = 40
considerWarn = function(model)
	warn(model:GetFullName(), "has no ClickDetector!")
	timesLeft -= 1
	if timesLeft == 0 then
		considerWarn = function() end
	end
end
local clickers = {}
for _, book in ipairs(Books:GetBooks()) do
	for _, model in ipairs(book.Models) do
		table.insert(clickers, model:FindFirstChildOfClass("ClickDetector") or considerWarn(model))
	end
end

local reading = false
BookGui.BookOpened:Connect(function()
	-- reading = true -- Disabled for now; BookGui disables all click detectors when appropriate
	gui.Visible = false
end)

BookGui.BookClosed:Connect(function()
	reading = false
end)

local handleClickDet
if UserInputService.MouseEnabled then
	local lastEnterTime
	local function closeHover()
		if lastEnterTime ~= workspace.DistributedGameTime then
			gui.Visible = false
		end
	end
	local function createSetHoverTitleWithLabel(label)
		return function()
			if not reading then
				gui.Text = label
				gui.Visible = true
				lastEnterTime = workspace.DistributedGameTime
			end
		end
	end
	local function createSetHoverTitle(title, author, numContentPages)
		return createSetHoverTitleWithLabel(("%s by %s\n%d Page%s"):format(title, author, numContentPages, if numContentPages == 1 then "" else "s"))
	end
	local function createSetHoverTitleNoPageCount(title, author)
		return createSetHoverTitleWithLabel(("%s by %s"):format(title, author))
	end
	local function connectHoverTitleWithPageCount(clickDet, book)
		return clickDet.MouseHoverEnter:Connect(createSetHoverTitle(book.Title, book.AuthorLine, book.PageCount - 2))
	end
	handleClickDet = function(clickDet, book)
		local con1 = clickDet.MouseHoverLeave:Connect(closeHover)
		local con2
		if book.PageCount then
			con2 = connectHoverTitleWithPageCount(clickDet, book)
		else
			con2 = clickDet.MouseHoverEnter:Connect(createSetHoverTitleNoPageCount(book.Title, book.AuthorLine))
			Books:OnPageCountReady(book, function()
				if not con2 then return end -- cleanup function below called
				con2:Disconnect()
				con2 = connectHoverTitleWithPageCount(clickDet, book)
			end)
		end
		return function() -- cleanup function
			con1:Disconnect()
			con2:Disconnect()
			con2 = nil
		end
	end
	for _, clickDet in ipairs(clickers) do
		handleClickDet(clickDet, Books:FromObj(clickDet.Parent))
	end
end

local function handleClickDet_Click(clickDet, book)
	local con = clickDet.MouseClick:Connect(function()
		if reading then return end
		gui.Visible = false
		BookGui.OpenAsync(book.Id)
	end)
	return function() con:Disconnect() end
end
for _, clickDet in ipairs(clickers) do
	handleClickDet_Click(clickDet, Books:FromObj(clickDet.Parent))
end

-- Merge handleClickDet_Click into handleClickDet
if handleClickDet then
	local base = handleClickDet
	handleClickDet = function(...)
		local cleanup1 = base(...)
		local cleanup2 = handleClickDet_Click(...)
		return function()
			cleanup1()
			cleanup2()
		end
	end
else
	handleClickDet = handleClickDet_Click
end

local cdToCleanup = {}
CollectionService:GetInstanceAddedSignal("SelectableBookCD"):Connect(function(cd)
	cdToCleanup[cd] = handleClickDet(cd, Books:FromObj(cd.BookRef.Value))
end)
CollectionService:GetInstanceRemovedSignal("SelectableBookCD"):Connect(function(cd)
	local cleanup = cdToCleanup[cd]
	if cleanup then
		cdToCleanup[cd] = nil
		cleanup()
	end
end)

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