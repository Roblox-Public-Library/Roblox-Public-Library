local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local BookGui = require(ReplicatedStorage.Gui.BookGui)
local MessageBox = require(ReplicatedStorage.Gui.MessageBox)
local profile = require(ReplicatedStorage.Library.ProfileClient)
local	tutorial = profile.Tutorial
local	bvs = profile.BookViewingSettings

local Event = require(ReplicatedStorage.Utilities.Event)
local EventUtilities = require(ReplicatedStorage.Utilities.EventUtilities)
local Functions = require(ReplicatedStorage.Utilities.Functions)

local localPlayer = game:GetService("Players").LocalPlayer
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

ContentProvider:PreloadAsync({
	"rbxassetid://3926305904", -- arrow and search icon
})

local function showFirstTimeTour()
	local center = UDim2.new(0.5, 0, 0.5, 0)
	local leftArrow = Instance.new("ImageLabel")
	leftArrow.Image = "rbxassetid://3926305904"
	leftArrow.ImageColor3 = Color3.new(1, 1, 0)
	leftArrow.ImageRectOffset = Vector2.new(521, 761)
	leftArrow.ImageRectSize = Vector2.new(42, 42)
	leftArrow.ScaleType = Enum.ScaleType.Fit
	leftArrow.BackgroundTransparency = 1
	leftArrow.Size = UDim2.new(0, 42, 0, 42)
	leftArrow.Position = center
	local rightArrow = leftArrow:Clone()
	leftArrow.AnchorPoint = Vector2.new(1, 0)
	leftArrow.Rotation = 45
	rightArrow.Rotation = -45

	local topBarLeft = localPlayer.PlayerGui:WaitForChild("TopBar"):WaitForChild("Left")
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 0)
	local leftArrowTween = TweenService:Create(leftArrow, tweenInfo, {Position = UDim2.new(0, 0, 1, 0)})
	local rightArrowTween = TweenService:Create(rightArrow, tweenInfo, {Position = UDim2.new(1, 0, 1, 0)})
	local function explain(name, msg, closeText)
		local parent = topBarLeft:WaitForChild(name)
		leftArrow.Position, rightArrow.Position = center, center
		leftArrow.Parent, rightArrow.Parent = parent, parent
		-- Animate arrows until player dismisses message
		leftArrowTween:Play()
		rightArrowTween:Play()
		MessageBox.Notify(msg, closeText, true)
		leftArrowTween:Cancel()
		rightArrowTween:Cancel()
		leftArrow.Parent, rightArrow.Parent = nil, nil
	end
	explain("About", "Welcome to the Roblox Library!\nClick on the ? in the top bar for FAQ, controls, and more.")
	explain("Search", "Looking for books? Use the book search.\nThere are plenty of options to help you find what you're looking for, or to find something new!")
	explain("BookViewingSettings", "By default, others can see what you're reading and can read along with you! But if you wish to turn that off, you can do so here.\nYou can also customize Light vs Dark mode, change your camera zoom in 3D book mode, and choose between 2D and 3D book reading!")
	--explain("Music", "You can customize or disable music here.")
	leftArrow:Destroy()
	rightArrow:Destroy()
end
tutorial:ConsiderShow("firstTimeTour", showFirstTimeTour)
tutorial.AllReset:Connect(showFirstTimeTour)

local tutorialGui = ReplicatedStorage.Guis.Tutorial
tutorialGui.Enabled = false
local lineTemplate = tutorialGui.Line
lineTemplate.Parent = nil
local descTemplate = tutorialGui.Desc
descTemplate.Parent = nil
tutorialGui.Parent = localPlayer.PlayerGui

local AutoTutorial = require(ReplicatedStorage.AutoTutorial)(tutorialGui, lineTemplate, descTemplate)
local	createDescs = AutoTutorial.CreateDescs
local	closeTutorialEvent = AutoTutorial.CloseTutorialEvent
-- createDescs(mainFrame) -> descs, add, show
--	add : function(obj1Name, [obj2Name, ...], desc)
--		Adds a description that points to the specified objects (must be a descendant of mainFrame) to the tutorial that will be shown with 'show'
--	show : function(waitFn, screenSizeOverride)
--		waitFn : a function that yields until the tutorial should no longer be shown
--		screenSizeOverride : optional Vector2

local showingTutorial = false
local function showBookGuiTutorial()
	if showingTutorial then return end
	showingTutorial = true
	task.wait()
	local mainFrame = BookGui.GetCurMainFrame()
	local screenSizeOverride = nil
	if mainFrame.Parent:IsA("SurfaceGui") then
		screenSizeOverride = mainFrame.Parent.AbsoluteSize * 9/10
	end
	local descs, add, show = createDescs(mainFrame)
	add("CollapseToggle", "Open/close the Table of Contents, where you can jump to a particular chapter")
	add("Like", "Click this if you liked the book or found it useful")
	add("MarkRead", "Record that you've read this, making it easy to find books you <i>haven't</i> read yet in the book search")
	add("Audio", "Open the audio player controls (for audiobooks only)")
	add("Saves.Backpack", "Put this book in your Book Pouch for quick access")
	add("Saves.AddToList", "Put this book in a custom list for easy searching")
	add("Saves.Bookmark", "Bookmark the current page so you can jump to this location later. (The last page you were open to is saved automatically when you close the book.)")
	add("X", "Close the book")
	add("Plus", "Turn the page")
	add("PageDisplay", "The current page. You can jump to a page by typing in its number.")
	add("Help", "Show this tutorial screen")

	local redo
	show(function()
		local e = EventUtilities.WaitForAnyEvent({closeTutorialEvent, BookGui.BookClosed, bvs.ThreeD.Changed})
		redo = e == bvs.ThreeD.Changed
	end, screenSizeOverride)

	showingTutorial = false
	if redo then
		showBookGuiTutorial()
	else
		tutorial:RecordShown("BookGui")
	end
end
local function connect()
	if tutorial:ShouldShow("BookGui") then
		if BookGui.BookOpen then
			showBookGuiTutorial()
		else
			BookGui.BookOpened:Once(showBookGuiTutorial)
		end
	end
end
connect()
tutorial.AllReset:Connect(connect)
BookGui.TutorialRequested:Connect(showBookGuiTutorial)

local function makeTutorial(guiName, controlName, fn)
	local showCon
	local gui = localPlayer.PlayerGui:WaitForChild(guiName)
	local showTutorial = Functions.Debounce(function()
		local mainFrame = gui[controlName]
		local descs, add, show = createDescs(mainFrame)
		fn(add)

		show(function()
			if EventUtilities.WaitForAnyEvent({closeTutorialEvent, gui:GetPropertyChangedSignal("Enabled")}) == closeTutorialEvent then
				tutorial:RecordShown(guiName)
				if showCon then
					showCon:Disconnect()
				end
			end
		end)
	end)
	local showButton = gui:FindFirstChild("ShowTutorial", true)
	local function connect()
		if tutorial:ShouldShow(guiName) then
			showCon = gui:GetPropertyChangedSignal("Enabled"):Connect(showTutorial)
		end
		if showButton then
			showButton.Activated:Connect(showTutorial)
		end
	end
	connect()
	tutorial.AllReset:Connect(connect)
	return showTutorial
end

makeTutorial("BookSearch", "Options", function(add)
	add("DateLow", "DateHigh", "Search for books that were published at a particular time. Format is month/day/year or \"Jan 1, 2000\"")
	add("Read", "Change checkboxes like this to adjust what books show up. ✔ means books <b>must</b> have it, <b>X</b> means books <b>must not</b> have it. For Marked Read, change to <b>X</b> to find books you've never read!")
	add("Bookmarked", "Whether to find books in which you've left a bookmark")
	add("Genres.Header", "Expand this to find books in (or <i>not</i> in) specific genres")
	add("Lists.Header", "Expand this to find books in (or <i>not</i> in) specific lists you've made")
	add("ShowTutorial", "Show this tutorial screen")
end)

makeTutorial("BookViewingSettings", "Frame", function(add)
	add("BookDistance", "Change how far away your camera is (more control than the normal zoom)")
	add("PublicOptions", "If <b>No</b>, others will only see that you're reading <i>something</i> - you will still see the book as normal")
	add("ColorMode", "Changes the book color scheme for all books you see")
end)