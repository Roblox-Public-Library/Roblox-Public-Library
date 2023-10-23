local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BookmarkLayout = require(ReplicatedStorage.Gui.BookmarkLayout)
local Books = require(ReplicatedStorage.Library.BooksClient)
local BooksContentCache = require(ReplicatedStorage.Library.BooksContentCache)
local	imageHandler = BooksContentCache.ImageHandler
local MessageBox = require(ReplicatedStorage.Gui.MessageBox)
local profile = require(ReplicatedStorage.Library.ProfileClient)
local	booksProfile = profile.Books
local	bookPouch = profile.BookPouch
local	bvs = profile.BookViewingSettings
local Event = require(ReplicatedStorage.Utilities.Event)
local String = require(ReplicatedStorage.Utilities.String)
local Render = require(ReplicatedStorage.Writer).Render
local Colors = require(ReplicatedStorage.Writer).Colors

local ContentProvider = game:GetService("ContentProvider")
local localPlayer = game:GetService("Players").LocalPlayer
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local remotes = ReplicatedStorage:FindFirstChild("Remotes") -- workshop support (they don't have remotes)
local SFX = ReplicatedStorage.SFX
local musicClientScript = ReplicatedStorage:FindFirstChild("MusicClient")
local music = musicClientScript and require(musicClientScript) or {GoCrazy = function() end} -- Allows this script to be used in workshops without the music system

local BookGui = {
	BookOpen = false, -- id of book opened or false
	BookOpened = Event.new(), --(id of book opened)
	BookClosed = Event.new(),
	TutorialRequested = Event.new(),
}

local gui = ReplicatedStorage.Guis.BookGui
gui.Enabled = true

local mainFrame = gui.MainFrame
mainFrame.Visible = false
local originalMainFramePosition = mainFrame.Position

gui.Parent = localPlayer:WaitForChild("PlayerGui")

local goCrazyAndKill do
	local initialSilenceDuration = 5 -- for GoCrazy
	local specialScreen = gui.SpecialScreen
	goCrazyAndKill = function()
		music:GoCrazy(initialSilenceDuration)
		specialScreen.Visible = true
		task.wait(initialSilenceDuration)
		specialScreen.Visible = false
		local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
		local con1, con2
		con1 = RunService.RenderStepped:Connect(function()
			SFX.PageTurn:Play()
		end)
		con2 = localPlayer.CharacterAdded:Connect(function()
			con1:Disconnect()
			con2:Disconnect()
		end)
	end
end
local kill = false

local bookAudioPlayer = require(script.Parent.BookAudioPlayer)(mainFrame.TopPanel.Audio)
local bottomPanel = mainFrame.BottomPanel

local bookId, bookIdIsNumber
local content --:BookContent
local data -- from Books
local summary -- also from Books
local numPages
local curPage -- index
local curPageChanged = Event.new() --(index)
BookGui.CurPageChanged = curPageChanged
local maxCurPage -- max value for curPage (may be 1 less than total # of pages in 2-page view)

local lastSeenLocal = {} -- for book ids that aren't numbers
local setCurPage, tryGoToPage -- defined below

local updateTableOfContents do -- Table of Contents
	local idToTOCOpen = {} -- whether a book's TOC was left open by user or not (true/false or nil if they haven't touched it)
	local function shouldTOCBeOpen()
		local v = idToTOCOpen[bookId]
		return if v == nil
			then #content.Chapters > 1
			else v
	end
	local justNavigated -- true if user just clicked on a chapter to navigate to it

	local leftPanel = mainFrame.LeftPanel
	local frame = leftPanel.TableOfContents
	local template = frame.Entry
	template.Parent = nil
	local entries = {}
	local originalSize = frame.Size
	local closedSize = UDim2.new(UDim.new(), originalSize.Y)
	local tweening = false
	local tweenDuration = 2/3
	local tweening, open
	frame.Visible = false
	frame.Size = closedSize
	local function toggleTOCOpen(thisIsAutomaticAction)
		if tweening then return end
		open = not open
		if not thisIsAutomaticAction then
			idToTOCOpen[bookId] = open
		end
		tweening = true
		if open then
			frame.Visible = true
		end
		frame:TweenSize(
			if open then originalSize else closedSize,
			Enum.EasingDirection.InOut,
			Enum.EasingStyle.Quad,
			tweenDuration,
			true)
		task.wait(tweenDuration)
		if not open then
			frame.Visible = false
		end
		tweening = false
	end
	leftPanel.CollapseToggle.Activated:Connect(toggleTOCOpen)
	local function setOpen(value)
		open = value
		frame.Size = if open then originalSize else closedSize
		frame.Visible = open
	end
	local function updateMaxSize()
		local first = entries[1]
		if not first then return end
		local min = math.min(25, math.floor(0.1 * first.AbsoluteSize.X + 0.5))
		for _, entry in entries do
			entry.EntryPage.UITextSizeConstraint.MaxTextSize = 25
			local y = entry.EntryPage.TextBounds.Y
			if y < min then min = y end
		end
		for _, entry in entries do
			entry.EntryName.UITextSizeConstraint.MaxTextSize = min
			entry.EntryPage.UITextSizeConstraint.MaxTextSize = min
		end
	end
	updateTableOfContentsColor = function(bgColor, textColor)
		frame.BackgroundColor3 = bgColor
		frame.Table.TextColor3 = textColor
		for _, e in ipairs(entries) do
			e.BackgroundColor3 = bgColor
			e.EntryName.TextColor3 = textColor
			e.EntryPage.TextColor3 = textColor
		end
	end
	updateTableOfContents = function()
		local chapters = content.Chapters
		local num = #chapters
		for i = #entries + 1, num do
			local entry = template:Clone()
			entries[i] = entry
			entry.LayoutOrder = i
			entry.Parent = frame
			entry.Activated:Connect(function()
				-- Note: can't use 'chapters' upvalue because 'content' may have changed since this entry was created
				justNavigated = true
				setCurPage(content.Chapters[i].StartingPageIndex)
			end)
		end
		for i = num + 1, #entries do
			entries[i]:Destroy()
			entries[i] = nil
		end
		for i, entry in ipairs(entries) do
			local chapter = chapters[i]
			entry.EntryName.Text = chapter:GetName()
			entry.EntryPage.Text = content:GetSemiFormattedPageNumber(chapter.StartingPageIndex)
		end
		updateMaxSize()

		setOpen(shouldTOCBeOpen())
	end
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		task.defer(updateMaxSize)
	end)
	curPageChanged:Connect(function()
		if not justNavigated and BookGui.BookOpen and open and idToTOCOpen[bookId] == nil and not tweening then -- automatic close
			toggleTOCOpen(true)
		end
		justNavigated = false
	end)
end

local function indexToFormattedPageNumber(index)
	return content:GetSemiFormattedPageNumber(index)
end

local bookmarkTemplate = mainFrame.RightPanelFront.Bookmark
bookmarkTemplate.Parent = nil
mainFrame.RightPanelBack.Bookmark:Destroy()
local bookmarkLayout = BookmarkLayout.new(bookmarkTemplate, mainFrame.RightPanelBack, mainFrame.RightPanelFront, indexToFormattedPageNumber)
local bookmarkToggle = mainFrame.TopPanel.Saves.Bookmark
local function updateToggleVisual(toggle, filled)
	toggle.Filled.ImageTransparency = if filled then 0.25 else 1
	toggle.BackgroundTransparency = if filled then 0.25 else 0.5
end
curPageChanged:Connect(function(curPage)
	bookmarkLayout:SetCurrentPage(curPage)
	updateToggleVisual(bookmarkToggle, bookmarkLayout:HasBookmark(curPage))
end)
BookGui.BookOpened:Connect(function()
	updateToggleVisual(bookmarkToggle, bookmarkLayout:HasBookmark(curPage))
end)
local function cannotSaveBook()
	return not bookIdIsNumber
end
local function cannotSaveBook_ThenNotify(purpose)
	if cannotSaveBook() then
		StarterGui:SetCore("SendNotification", {
			Title = "Cannot " .. purpose,
			Text = "This book requires maintenance. Please contact a librarian.",
			Duration = 4,
		})
		return true
	end
end

bookmarkToggle.Activated:Connect(function()
	if cannotSaveBook_ThenNotify("add bookmark") then return end
	local value
	if bookmarkLayout:HasBookmark(curPage) then
		bookmarkLayout:Remove(curPage)
		value = false
	elseif bookmarkLayout:Num() < booksProfile.MAX_BOOKMARKS then
		bookmarkLayout:Add(curPage)
		value = true
	else
		StarterGui:SetCore("SendNotification", {
			Title = "Cannot add bookmark",
			Text = "Max " .. booksProfile.MAX_BOOKMARKS .. " bookmarks per book",
			Duration = 2,
		})
		return
	end
	updateToggleVisual(bookmarkToggle, value)
	booksProfile:SetBookmark(bookId, curPage, value)
end)
local likeToggle = mainFrame.TopPanel.Like
likeToggle.Activated:Connect(function()
	if cannotSaveBook_ThenNotify("like book") then return end
	local value = not booksProfile:GetLike(bookId)
	booksProfile:SetLike(bookId, value)
	updateToggleVisual(likeToggle, value)
end)
local markReadToggle = mainFrame.TopPanel.MarkRead
local function updateMarkReadVisual(read)
	markReadToggle.Text = if read then "Mark Unread" else "Mark Read"
	markReadToggle.BackgroundTransparency = if read then 0.25 else 0.5
end
markReadToggle.Activated:Connect(function()
	if cannotSaveBook_ThenNotify("mark read") then return end
	local value = not booksProfile:GetRead(bookId)
	booksProfile:SetRead(bookId, value)
	updateMarkReadVisual(value)
end)
curPageChanged:Connect(function(curPage)
	if bookIdIsNumber then
		booksProfile:SetLastSeenPage(bookId, curPage)
		if curPage == maxCurPage and not booksProfile:GetRead(bookId) then -- Auto set Mark Read when at the end of the book
			booksProfile:SetRead(bookId, true)
			updateMarkReadVisual(true)
		end
	else
		lastSeenLocal[bookId] = curPage
	end
end)
local backpackToggle = mainFrame.TopPanel.Saves.Backpack
local animateBookPouch do
	local duration = 1
	local animating = false
	local icon = backpackToggle:Clone()
	icon.Filled.ImageTransparency = 0
	local tl = Instance.new("TextLabel")
	tl.Parent = icon
	for _, k in {"Position", "AnchorPoint", "Size", "BackgroundTransparency", "BackgroundColor3"} do
		tl[k] = icon.Filled[k]
	end
	icon.Filled:Destroy()
	tl.Text = "📕"
	tl.TextScaled = true
	local s = backpackToggle.AbsoluteSize
	icon.Size = UDim2.fromOffset(s.X, s.Y)
	animateBookPouch = function()
		if animating then return end
		animating = true
		task.spawn(function()
			local p = backpackToggle.AbsolutePosition
			icon.Position = UDim2.fromOffset(p.X, p.Y)
			icon.Parent = gui
			local t = 0.01
			local xDif = 10 - p.X
			local yDif = gui.AbsoluteSize.Y / 2 - p.Y - s.Y / 2
			while true do
				local alpha = t / duration
				local x = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut) * xDif + p.X
				local y = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.In) * yDif + p.Y
				icon.Position = UDim2.fromOffset(x, y)
				t += task.wait()
				if alpha >= 1 then break end
			end
			icon.Parent = nil
			animating = false
		end)
	end
end
backpackToggle.Activated:Connect(function()
	local value = not bookPouch:Contains(bookId)
	if value and bookPouch:IsFull() then
		StarterGui:SetCore("SendNotification", {
			Title = "Book Pouch Full",
			Text = "You can't add any more books to your pouch - remove some first.",
			Duration = 2.5,
		})
		return
	end
	bookPouch:SetInPouch(bookId, value)
	updateToggleVisual(backpackToggle, value)
	if value then
		animateBookPouch()
	end
	if value and cannotSaveBook() then
		StarterGui:SetCore("SendNotification", {
			Title = "Warning - Can't Save Book",
			Text = "This book requires maintenance; it will not stay in your book pouch when you leave. Please contact a librarian.",
			Duration = 10,
		})
	end
end)
local addToListPopup = gui.AddToListPopup
local updateAddToListIcon do -- addToList popup opening/closing
	local closePopup = gui.ClosePopup
	addToListPopup.Visible = false
	closePopup.Visible = false
	closePopup.Activated:Connect(function()
		local tb = UserInputService:GetFocusedTextBox()
		if tb then
			tb:ReleaseFocus()
		else
			addToListPopup.Visible = false
			closePopup.Visible = false
		end
	end)
	local addToList = mainFrame.TopPanel.Saves.AddToList
	local function updatePopupPos()
		local pos, size = addToList.AbsolutePosition, addToList.AbsoluteSize
		addToListPopup.Position = UDim2.fromOffset(pos.X + size.X, pos.Y + size.Y)
	end
	addToList:GetPropertyChangedSignal("AbsoluteSize"):Connect(updatePopupPos)
	addToList:GetPropertyChangedSignal("AbsolutePosition"):Connect(updatePopupPos)
	addToList.Activated:Connect(function()
		if cannotSaveBook_ThenNotify("add to list") then return end
		addToListPopup.Visible = true
		closePopup.Visible = true
	end)
	updateAddToListIcon = function()
		local inAnyList = false
		for name, list in booksProfile:GetAllLists() do
			if booksProfile:ListHasBook(name, bookId) then
				inAnyList = true
				break
			end
		end
		addToList.Normal.Visible = not inAnyList
		addToList.Added.Visible = inAnyList
		addToList.BackgroundTransparency = if inAnyList then 0.25 else 0.5
	end
	BookGui.BookOpened:Connect(updateAddToListIcon)
end
local updateAddToList do
	local sf = addToListPopup.ScrollingFrame
	local entryTemplate = sf.Entry
	entryTemplate.Parent = nil

	local function newEntry(name, list, autoAdd)
		local bookInList = booksProfile:ListHasBook(name, bookId)

		local self
		local obj = entryTemplate:Clone()
		local filtered = booksProfile:GetFilteredListName(name)
		local function updateDesc()
			local txt = if filtered == nil then "[Loading...]"
				else filtered or "?"
			obj.Button.Desc.Text = string.format("%s (%d)", txt, #list)
		end
		updateDesc()
		local checkImg = obj.Button.Checkbox.Check
		local function updateCheck()
			checkImg.Visible = not not bookInList
		end
		updateCheck()
		local function toggleInList()
			bookInList = not bookInList
			booksProfile:SetInList(name, bookId, bookInList)
			updateAddToListIcon()
			updateDesc()
			updateCheck()
		end
		obj.Button.Activated:Connect(toggleInList)
		if autoAdd then
			toggleInList()
		end
		local editName = obj.Button.EditName
		local desc = obj.Button.Desc
		local function performRenameAsync()
			editName:CaptureFocus()
			editName.FocusLost:Wait()
			local newName = String.Trim(editName.Text)
			if newName == name or newName == filtered then return end
			local newFiltered, errMsg = booksProfile:TryRenameList(name, newName)
			if errMsg or not newFiltered then
				StarterGui:SetCore("SendNotification", {
					Title = "Rename Error",
					Text = errMsg or "Something went wrong",
					Duration = 3,
				})
				return
			end
			filtered = newFiltered
			name = newFiltered
			obj.Name = name
			updateDesc()
		end
		obj.Name = name
		obj.Rename.Activated:Connect(function()
			if editName.Visible then return end
			editName.Visible = true
			desc.Visible = false
			performRenameAsync()
			editName.Visible = false
			desc.Visible = true
		end)
		obj.X.Activated:Connect(function()
			if #list > 0 then
				local msg = string.format("Permanently delete %s (with %d books)?", filtered or " list", #list)
				if not MessageBox.Show(msg, "Delete", "Cancel") then return end
			end
			booksProfile:DeleteList(obj.Name)
			self:Destroy()
			updateAddToListIcon()
		end)
		local con
		if filtered == nil then
			con = booksProfile.FilteredNameAdded:Connect(function(raw, _filtered)
				if raw == name then
					filtered = _filtered
					updateDesc()
					con:Disconnect()
				end
			end)
		end
		obj.Parent = sf
		self = {Destroy = function()
			if con then con:Disconnect() end
			obj:Destroy()
		end}
		return self
	end

	local entries = {}
	updateAddToList = function()
		for _, e in entries do
			e:Destroy()
		end
		table.clear(entries)
		for name, list in booksProfile:GetAllLists() do
			table.insert(entries, newEntry(name, list))
		end
	end
	local newList = addToListPopup.NewList
	local prevText = newList.Text
	newList:GetPropertyChangedSignal("Text"):Connect(function()
		if #newList.Text > booksProfile.MAX_LIST_NAME_LENGTH then
			newList.Text = prevText
		else
			prevText = String.Trim(newList.Text)
		end
	end)
	newList.FocusLost:Connect(function(enterPressed)
		if not enterPressed then return end
		local text = String.Trim(newList.Text)
		if text == "" then return end
		local name, msg = booksProfile:TryCreateList(text)
		if name then
			local list = booksProfile:GetList(name)
			table.insert(entries, newEntry(name, list, true))
		end
	end)
end
BookGui.BookOpened:Connect(function()
	updateToggleVisual(backpackToggle, bookPouch:Contains(bookId))
	updateAddToList()
	updateToggleVisual(likeToggle, booksProfile:GetLike(bookId))
	updateMarkReadVisual(booksProfile:GetRead(bookId))
end)
bookPouch.ListChanged:Connect(function(id, added)
	if id ~= BookGui.BookOpen then return end
	updateToggleVisual(backpackToggle, added)
end)

local PageDisplay = {} do
	local frame = bottomPanel.PageDisplay
	local prevPageNum
	local curPage = frame.CurPage
	local maxPages = frame.MaxPages
	function PageDisplay:ShowPage(num)
		curPage.Text = num
		prevPageNum = num
	end
	function PageDisplay:ShowMaxPages(num)
		maxPages.Text = "/ " .. num
	end
	curPage.FocusLost:Connect(function(enterPressed)
		if enterPressed and tryGoToPage(curPage.Text) then
			return
		end
		curPage.Text = prevPageNum
	end)
end


function BookGui.RenderPages(leftRender, rightRender, leftPage, rightPage, summary, content, curPage)
	if leftRender then
		leftRender:ClearPage()
	else
		leftRender = Render.new(leftPage, BooksContentCache:GetReaderConfig(), true, imageHandler)
	end
	local leftPageContent = content.Pages[curPage]
	if leftPageContent then -- TODO this has happened, even though it never should
		leftRender:RenderPage(leftPageContent)
	end
	-- Show header only if not on first 2 pages and only if a chapter doesn't start on this page
	leftPage.Header.Text = if curPage <= 2 or content:ChapterStartsOnPage(curPage) then "" else summary.Title

	if rightRender then
		rightRender:ClearPage()
	else
		rightRender = Render.new(rightPage, BooksContentCache:GetReaderConfig(), true, imageHandler)
	end
	local rPage = content.Pages[curPage + 1]
	if rPage then
		rightRender:RenderPage(rPage)
		rightPage.Header.Text = if curPage <= 2 or content:ChapterStartsOnPage(curPage + 1) then "" else content:GetChapterForPageIndex(curPage + 1):GetText()
	else
		rightPage.Header.Text = ""
	end
	return leftRender, rightRender
end
local renderPages = BookGui.RenderPages

local lightBG = Color3.fromRGB(217, 197, 177)
local darkBG = Color3.fromRGB(38, 34, 31)
function BookGui.GetPageColorFromLightMode(lightMode)
	return if lightMode then lightBG else darkBG
end

local leftPage = mainFrame.LeftPage
local rightPage = mainFrame.RightPage
local leftRender, rightRender
local function callRender(resetRenders)
	if resetRenders then
		if leftRender then
			leftRender:ClearPage()
			leftRender = nil
		end
		if rightRender then
			rightRender:ClearPage()
			rightRender = nil
		end
	end
	leftRender, rightRender = renderPages(leftRender, rightRender, leftPage, rightPage, summary, content, curPage)
end
local function updatePageColor()
	local lightMode = bvs.LightMode:Get()
	local color = BookGui.GetPageColorFromLightMode(lightMode)
	leftPage.BackgroundColor3 = color
	rightPage.BackgroundColor3 = color
	updateTableOfContentsColor(color, (if lightMode then Colors.Light else Colors.Dark).Default)
	local id = BookGui.BookOpen
	if id and not bvs.ThreeD:Get() then
		task.defer(function()
			-- defer to ensure data is cleared before we run this (in response to LightMode.Changed)
			content, data = BooksContentCache:GetContentDataAsync(id)
			callRender(true)
		end)
	end
end
updatePageColor()
bvs.LightMode.Changed:Connect(updatePageColor)
setCurPage = function(index)
	index = math.clamp(index, 1, maxCurPage)
	if index % 2 == 0 then
		index -= 1
	end
	if curPage == index then return end
	curPage = index
	curPageChanged:Fire(index)

	if not bvs.ThreeD:Get() then
		callRender()
	end

	local hasRightPage = content.Pages[curPage + 1]
	PageDisplay:ShowPage(content:GetSemiFormattedPageNumber(if hasRightPage then curPage + 1 else curPage))

	SFX.PageTurn:Play()
	if remotes and bvs.Public:Get() then
		remotes.PageTurnSound:FireServer()
	end
end
bvs.ThreeD.Changed:Connect(function(value)
	if not value and BookGui.BookOpen then -- entering 2d mode while a book is open
		callRender()
	elseif value then
		if leftRender then
			leftRender:ClearPage()
			leftRender = nil
		end
		if rightRender then
			rightRender:ClearPage()
			rightRender = nil
		end
	end
end)
tryGoToPage = function(num) -- returns false if 'num' not recognized
	local index = content:GetPageIndexFromNumber(num)
	if index then
		setCurPage(index)
		return true
	end
	return false
end

local inBookModel = false
local inReadingMode do
	local model
	local cToTrans = {}
	local function setLocalPlayerHidden(hidden)
		if hidden then
			for _, c in localPlayer.Character:GetDescendants() do
				if c:IsA("BasePart") or c:IsA("Decal") then
					cToTrans[c] = c.Transparency
					-- todo tweening these would look cooler
					c.Transparency = 1
				end
			end
		else
			for c, trans in cToTrans do
				c.Transparency = trans
			end
			table.clear(cToTrans)
		end
	end

	local hidePlayerTagModel, showPlayerTagModel do
		local playerTagModel, playerTagModelName
		local shouldBeHidden = false
		local function analyze(char)
			for i = 1, 3 do
				for _, c in ipairs(char:GetChildren()) do
					if c:IsA("Model") and c:FindFirstChildOfClass("Humanoid") then
						playerTagModel = c
						playerTagModelName = c.Name
					end
				end
				if playerTagModel then break end
				task.wait(1)
			end
			if playerTagModel and shouldBeHidden then
				playerTagModel.Name = ""
			end
		end
		if localPlayer.Character then task.spawn(analyze, localPlayer.Character) end
		localPlayer.CharacterAdded:Connect(analyze)
		hidePlayerTagModel = function()
			shouldBeHidden = true
			if playerTagModel then
				playerTagModel.Name = ""
			end
		end
		showPlayerTagModel = function()
			shouldBeHidden = false
			if playerTagModel then
				playerTagModel.Name = playerTagModelName
			end
		end
	end
	local disableClickDetectors, enableClickDetectors do
		local cdToDist = {}
		local disable = false
		local function check(c)
			if c:IsA("ClickDetector") then
				cdToDist[c] = c.MaxActivationDistance
				if disable then
					c.MaxActivationDistance = 0
				end
			end
		end
		for _, c in workspace:GetDescendants() do
			check(c)
		end
		workspace.DescendantAdded:Connect(check)
		workspace.DescendantRemoving:Connect(function(c)
			local dist = cdToDist[c]
			if dist then
				c.MaxActivationDistance = dist -- restore incase the cd will be reused
				cdToDist[c] = nil
			end
		end)
		disableClickDetectors = function()
			disable = true
			for cd in cdToDist do
				cd.MaxActivationDistance = 0
			end
		end
		enableClickDetectors = function()
			disable = false
			for cd, dist in cdToDist do
				cd.MaxActivationDistance = dist
			end
		end
	end

	local readingMode = gui.ReadingMode
	readingMode.Visible = false
	local inReadingMode2D, inReadingMode3D = false, false
	inReadingMode = function() return readingMode.Modal end
	local function turnOnReadingMode2D()
		mainFrame.Visible = true
	end
	local function turnOffReadingMode2D()
		mainFrame.Visible = false
	end
	local prevDist
	local prevReadingDist = 1.25
	local prevMin, prevMax
	local currentCameraMovedCon
	local updateViewDistCon
	local ignoreCamChange = false
	local function updateCameraDist(dist)
		ignoreCamChange = true
		localPlayer.CameraMinZoomDistance = dist
		localPlayer.CameraMaxZoomDistance = dist
		task.spawn(function()
			task.wait()
			ignoreCamChange = false
			if math.abs(localPlayer.CameraMinZoomDistance - dist) <= 0.1 then
				localPlayer.CameraMinZoomDistance = bvs.MinViewDistance
				localPlayer.CameraMaxZoomDistance = bvs.MaxViewDistance
			end
		end)
	end
	local ignoreBVSChange = false
	local function turnOnReadingMode3D()
		setLocalPlayerHidden(true)
		hidePlayerTagModel()

		local cam = workspace.CurrentCamera
		prevDist = (cam.Focus.Position - cam.CFrame.Position).Magnitude
		local mid = model.Middle
		cam.CameraSubject = mid
		if not prevMin then
			prevMin = localPlayer.CameraMinZoomDistance
			prevMax = localPlayer.CameraMaxZoomDistance
		end
		updateCameraDist(bvs.ViewDistance:Get())
		currentCameraMovedCon = workspace.CurrentCamera:GetPropertyChangedSignal("CFrame"):Connect(function()
			if ignoreCamChange then return end
			ignoreBVSChange = true
			bvs.ViewDistance:Set((cam.Focus.Position - cam.CFrame.Position).Magnitude)
			ignoreBVSChange = false
		end)
		updateViewDistCon = bvs.ViewDistance.Changed:Connect(function()
			if ignoreBVSChange then return end
			updateCameraDist(bvs.ViewDistance:Get())
		end)
		cam.CFrame = CFrame.new(mid.Position + mid.CFrame.RightVector * prevReadingDist, mid.Position)
	end
	local function turnOffReadingMode3D()
		local cam = workspace.CurrentCamera
		setLocalPlayerHidden(false)
		showPlayerTagModel()

		prevReadingDist = (cam.Focus.Position - cam.CFrame.Position).Magnitude
		cam.CameraSubject = localPlayer.Character.Humanoid
		updateViewDistCon:Disconnect()
		currentCameraMovedCon:Disconnect()
		localPlayer.CameraMaxZoomDistance = prevMax
		localPlayer.CameraMinZoomDistance = prevDist
		task.spawn(function()
			task.wait()
			localPlayer.CameraMinZoomDistance = prevMin
		end)
	end
	local function updateReadingModeBasics(twoD, threeD)
		local cur = twoD or threeD
		if readingMode.Modal == cur then return end
		readingMode.Modal = cur
		if cur then -- entering reading mode
			readingMode.Text = "Minimize"
			disableClickDetectors()
		else
			readingMode.Text = "Restore"
			enableClickDetectors()
		end
	end
	local function setReadingModeRaw(twoD, threeD)
		updateReadingModeBasics(twoD, threeD)
		-- First turn off either mode
		if not twoD and inReadingMode2D then
			inReadingMode2D = false
			turnOffReadingMode2D()
		end
		if not threeD and inReadingMode3D then
			inReadingMode3D = false
			turnOffReadingMode3D()
		end
		-- Now turn on whichever mode (we assume both won't be on simultaneously)
		if twoD and not inReadingMode2D then
			inReadingMode2D = true
			turnOnReadingMode2D()
		elseif threeD and not inReadingMode3D then
			inReadingMode3D = true
			turnOnReadingMode3D()
		end
	end
	local function setReadingMode2D() setReadingModeRaw(true, false) end
	local function setReadingMode3D() setReadingModeRaw(false, true) end
	local function setReadingModeOff() setReadingModeRaw(false, false) end
	local function setReadingModeOn()
		if inBookModel then
			setReadingMode3D()
		else
			setReadingMode2D()
		end
	end
	local function setInBookModel(value)
		if inBookModel == value then return end
		inBookModel = value
		if inReadingMode() then
			setReadingModeOn()
		end
	end
	local wantReadingMode = true
	local restoreCallback -- equals a function to call, if the book was forcibly minimized
	readingMode.Activated:Connect(function()
		if restoreCallback then
			restoreCallback()
			return
		end
		wantReadingMode = not wantReadingMode
		if wantReadingMode then
			setReadingModeOn()
		else
			setReadingModeOff()
		end
	end)

	function BookGui.Minimize(_restoreCallback)
		restoreCallback = _restoreCallback
		if wantReadingMode then
			setReadingModeOff()
		end
	end
	function BookGui.Restore()
		restoreCallback = nil
		if wantReadingMode then
			setReadingModeOn()
		end
	end

	local guiControls = {gui.AddToListPopup, gui.ClosePopup}
	local mainFrameControls = gui.MainFrame:GetChildren()
	for i = #mainFrameControls, 1, -1 do
		local c = mainFrameControls[i]
		if c.Name == "UIAspectRatioConstraint" or c.Name == "LeftPage" or c.Name == "RightPage" then
			table.remove(mainFrameControls, i)
		end
	end
	local mainFrame = gui.MainFrame
	local curMainFrame = mainFrame
	function BookGui.TransferToModel(_model, mGui, mMainFrame)
		model = _model
		for _, c in ipairs(guiControls) do
			c.Parent = mGui
		end
		for _, c in ipairs(mainFrameControls) do
			c.Parent = mMainFrame
		end
		curMainFrame = mMainFrame
		mainFrame.Visible = false
		setInBookModel(true)
	end
	function BookGui.TransferFromModel()
		model = nil
		for _, c in ipairs(guiControls) do
			c.Parent = gui
		end
		for _, c in ipairs(mainFrameControls) do
			c.Parent = mainFrame
		end
		curMainFrame = mainFrame
		mainFrame.Visible = if BookGui.BookOpen and inReadingMode() then true else false
		setInBookModel(false)
	end
	function BookGui.GetCurMainFrame() return curMainFrame end
	local function turnOn()
		readingMode.Visible = true
		if wantReadingMode then
			setReadingModeOn()
		end
	end
	BookGui.BookOpened:Connect(turnOn)
	local function turnOff()
		readingMode.Visible = false
		setReadingModeOff()
	end
	BookGui.BookClosed:Connect(turnOff)
	local function charAdded(char)
		if BookGui.BookOpen then
			turnOn()
		end
		char:WaitForChild("Humanoid").Died:Connect(turnOff)
	end
	if localPlayer.Character then charAdded(localPlayer.Character) end
	localPlayer.CharacterAdded:Connect(charAdded)
end

local invokeNum = 0
function BookGui.OpenAsync(id)
	if BookGui.BookOpen == id then return end
	bookId = id
	bookIdIsNumber = type(id) == "number"
	summary = Books:FromId(id)
	if not summary then
		error("No book with id " .. tostring(id), 2)
	end
	SFX.BookOpen:Play()
	content, data = BooksContentCache:GetContentDataAsync(id)
	if not content then
		local msg = "That book (ID " .. tostring(id) .. ") is broken. Please contact a librarian."
		print(msg)
		StarterGui:SetCore("SendNotification", {
			Title = "Broken Book",
			Text = msg,
			Duration = 4,
		})
		return
	end

	kill = content:HasFlag("Kill")
	bookAudioPlayer:SetBookAudioList(data.Audio)

	curPage = nil -- setCurPage won't act if curPage equals the page number we give it
	numPages = #content.Pages
	summary.PageCount = numPages -- sometimes server won't have created the PageCount and this will have been nil, but in either case the client count is more accurate
	PageDisplay:ShowMaxPages(content:GetSemiFormattedPageNumber(numPages))
	maxCurPage = if numPages % 2 == 0 then numPages - 1 else numPages

	local lastSeen = booksProfile:GetLastSeenPage(bookId) or lastSeenLocal[bookId] or 1
	setCurPage(if lastSeen == maxCurPage then 1 else lastSeen) -- if at the end of the book, start from the beginning

	updateTableOfContents()
	bookmarkLayout:NewBook(numPages, booksProfile:GetBookmarks(bookId))

	mainFrame.Visible = not inBookModel
	BookGui.BookOpen = id
	BookGui.BookOpened:Fire(id)
end

bookmarkLayout.Clicked:Connect(setCurPage)

local function canGoToPrevPage()
	return curPage >= 3
end
local function canGoToNextPage()
	return curPage + 2 <= numPages
end
local function setupPageTurn(button, checkFn, delta)
	button.Activated:Connect(function()
		if checkFn() then
			setCurPage(curPage + delta)
		end
	end)
	local function check()
		button.Visible = checkFn()
	end
	curPageChanged:Connect(check)
	BookGui.BookOpened:Connect(check)
end
setupPageTurn(bottomPanel.Minus, canGoToPrevPage, -2)
setupPageTurn(bottomPanel.Plus, canGoToNextPage, 2)

local numClosed = 0
mainFrame.X.Activated:Connect(function()
	SFX.BookClose:Play()
	mainFrame.Visible = false
	bookAudioPlayer:BookClosed()
	BookGui.BookOpen = false
	BookGui.BookClosed:Fire()
	numClosed += 1
	if numClosed % 10 == 0 then
		imageHandler:Clear()
	end

	if kill then
		kill = false
		goCrazyAndKill()
	end
end)
mainFrame.Help.Activated:Connect(function()
	BookGui.TutorialRequested:Fire()
end)

return BookGui