local Players = game:GetService("Players")
local	localPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Books = require(ReplicatedStorage.Library.BooksClient)
local bookPouch = require(ReplicatedStorage.Library.ProfileClient).BookPouch
local BookGui = require(ReplicatedStorage.Gui.BookGui)

local TweenService = game:GetService("TweenService")

local gui = ReplicatedStorage.Guis.BookPouchGui
gui.Enabled = true

local bg = gui.BooksBG -- background frame
local normalSize = bg.Size
local noSize = UDim2.new(UDim.new(), normalSize.Y)
local uiSizeConstraint = bg.UISizeConstraint
bg.Size = noSize
local normalMinSize = uiSizeConstraint.MinSize
local noMinSize = Vector2.new(0, 0)
uiSizeConstraint.MinSize = noMinSize
bg.Visible = false

local open = false

local sf = bg.Books -- scrolling frame
local rowTemplate = sf.Row
rowTemplate.Parent = nil
local idToRow = {}
local function addBook(id)
	local row = rowTemplate:Clone()
	local book = Books:FromId(id)
	row.Book.Text = if book then string.format("%s <i>by %s</i>", book.Title, book.AuthorLine)
		else (warn("No book with id", id) or "?")
	row.Book.Activated:Connect(function()
		BookGui.OpenAsync(id)
	end)
	row.Delete.Activated:Connect(function()
		row:Destroy()
		idToRow[id] = nil
		bookPouch:SetInPouch(id, false)
	end)
	row.Parent = sf
	idToRow[id] = row
end
bookPouch:ForEachBookId(addBook)
bookPouch.ListChanged:Connect(function(id, added)
	if added then
		addBook(id)
	elseif idToRow[id] then
		idToRow[id]:Destroy()
		idToRow[id] = nil
	end
end)

gui.Parent = localPlayer.PlayerGui

local toggle = gui.ExpandToggle
local arrows = toggle.Arrows
local tweenDuration = 0.7
local arrowTweenInfo = TweenInfo.new(tweenDuration / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local tweening
local function toggleOpen()
	open = not open
	uiSizeConstraint.MinSize = noMinSize
	bg.Visible = true
	bg:TweenSize(
		if open then normalSize else noSize,
		Enum.EasingDirection.InOut,
		Enum.EasingStyle.Quad,
		tweenDuration,
		true)
	TweenService:Create(arrows, arrowTweenInfo, {Rotation = if open then 90 else -90}):Play()
	task.wait(tweenDuration)
	bg.Visible = open
	uiSizeConstraint.MinSize = normalMinSize
	tweening = false
end
toggle.Activated:Connect(function()
	if tweening then return end
	toggleOpen()
end)

local wasOpen
BookGui.BookOpened:Connect(function()
	wasOpen = open
	if open then
		toggleOpen()
	end
end)
BookGui.BookClosed:Connect(function()
	if wasOpen and not open then
		toggleOpen()
	end
end)