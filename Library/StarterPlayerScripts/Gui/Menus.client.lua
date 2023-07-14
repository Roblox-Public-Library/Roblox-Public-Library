--[[
Measurements/sizes for TopBar taken from TopBar+: https://github.com/1ForeverHD/HDAdmin/tree/master/Projects/Topbar%2B
A handy gear/settings icon is also available from them: http://www.roblox.com/asset/?id=2484556379
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local MessageBox = require(ReplicatedStorage.Gui.MessageBox)
local Utilities = ReplicatedStorage.Utilities
local Assert = require(Utilities.Assert)
local String = require(Utilities.String)
local ObjectList = require(Utilities.ObjectList)
local ButtonList = require(ReplicatedStorage.Gui.ButtonList)
local gui = ReplicatedStorage.Guis.Menus
local topBar = ReplicatedStorage.Guis.TopBar

local BookGui = require(ReplicatedStorage.Gui.BookGui)
local BookSearch = require(ReplicatedStorage.Gui.BookSearch)
local BookViewingSettings = require(ReplicatedStorage.Gui.BookViewingSettings)
local GuiUtilities = require(ReplicatedStorage.Gui.Utilities)
local profile = require(ReplicatedStorage.Library.ProfileClient)
local	music = profile.Music

local UserInputService = game:GetService("UserInputService")

local localPlayer = game:GetService("Players").LocalPlayer
local playerGui = localPlayer.PlayerGui
gui.Enabled = true
gui.Parent = playerGui
topBar.Parent = playerGui

local sfx = ReplicatedStorage.SFX

local inputTypeIsClick = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.Touch] = true,
}

local handleVerticalScrollingFrame = GuiUtilities.HandleVerticalScrollingFrame

--[[Menus have the following interface:
:Open()
:Close()
.CloseOnCatchClick = true by default
]]

local closeOnClick = false
local displayedMenu
local displayedBVS
local restoreBook = false
--[[
displayMenu rules...
for BVS, use 2nd arg
for search, always nil 2nd arg
for all others, keep 2nd arg
]]
local function displayMenu(menu, bvsMenu, suppressCloseSound)
	-- Return if nothing needs to change
	if menu == displayedMenu and bvsMenu == displayedBVS then return end
	-- Close menus as appropriate
	local closed, opened = false, false
	if displayedBVS ~= bvsMenu then
		if displayedBVS then
			displayedBVS:Close()
			closed = true
		end
		displayedBVS = bvsMenu
		if displayedBVS then
			displayedBVS:Open()
			opened = true
		end
	end
	if displayedMenu ~= menu then
		if displayedMenu then
			displayedMenu:Close()
			closed = true
		end
		displayedMenu = menu
		if displayedMenu then
			opened = true
			displayedMenu:Open()
			closeOnClick = menu.CloseOnCatchClick ~= false
			restoreBook = BookGui.BookOpen
			if restoreBook then
				BookGui.Minimize(function()
					-- BookGui wants to restore
					displayMenu(nil, displayedBVS)
				end)
			end
		else
			closeOnClick = false
			if restoreBook then -- Restore minimized book
				restoreBook = false
				BookGui.Restore()
			end
		end
	end
	if opened then
		sfx.BookOpen:Play()
	elseif closed and not suppressCloseSound then
		sfx.BookClose:Play()
	end
end
UserInputService.InputBegan:Connect(function(input, processed)
	if closeOnClick and not processed and inputTypeIsClick[input.UserInputType] then
		displayMenu(nil, displayedBVS)
	end
end)

local topBarMenus = {}
local function menuFromFrame(obj)
	return {
		Open = function() obj.Visible = true end,
		Close = function() obj.Visible = false end,
	}
end

local function Option(name, font, enabled)
	return {
		Text = Assert.String(name),
		Font = font,
		Enabled = enabled,
	}
end

local dropdown = {} do
	local dropdownFrame = gui.Dropdown
	local template = dropdownFrame.Button
	template.Parent = nil
	local listSizeY = template.Size.Y.Offset
	handleVerticalScrollingFrame(dropdownFrame)
	local event = Instance.new("BindableEvent")
	dropdown.OptionSelected = event.Event --(index)
	local MAX_BOTTOM_Y_SCALE = 0.9 -- bottom of dropdown cannot reach past this scale on screen

	local list = ButtonList.new(function()
		local button = template:Clone()
		button.Parent = dropdownFrame
		return button
	end)
	list.Activated:Connect(function(i, button, enabled)
		if enabled then
			event:Fire(i)
		end
		dropdown:Close()
	end)
	local function setOptions(options)
		Assert.List(options) --List<{.Text .Font=SourceSans .Enabled=true} or text:string>
		list:AdaptToList(options, function(button, option)
			if type(option) == "table" then
				button.Text = option.Text
				button.Font = option.Font or Enum.Font.SourceSans
				return option.Enabled ~= false
			else
				button.Text = option
				button.Font = Enum.Font.SourceSans
				return true
			end
		end)
	end
	local cons
	local function clearCons()
		if cons then
			for _, con in ipairs(cons) do
				con:Disconnect()
			end
			cons = nil
		end
	end
	local UserInputService = game:GetService("UserInputService")
	local dropdownCatchClick = gui.DropdownCatchClick
	function dropdown:Open(options, handler, beneath, extraXSize)
		setOptions(options) -- options:List<text:string or {.Text .Font=SourceSans .Enabled=true}>
		Assert.Function(handler) --(index selected)
		Assert.IsA(beneath, "GuiObject")
		extraXSize = extraXSize and Assert.Number(extraXSize) or 0
		clearCons()
		local function update()
			local pos = beneath.AbsolutePosition
			local size = beneath.AbsoluteSize
			local posY = pos.Y + size.Y + math.max(beneath.BorderSizePixel, dropdownFrame.BorderSizePixel)
			dropdownFrame.Position = UDim2.new(0, pos.X, 0, posY)
			local availSpace = gui.AbsoluteSize.Y * MAX_BOTTOM_Y_SCALE - posY
			dropdownFrame.Size = UDim2.new(0, size.X + extraXSize, 0, math.min(list:Count() * listSizeY, availSpace))
		end
		update()
		dropdownFrame.Visible = true
		cons = {
			beneath:GetPropertyChangedSignal("AbsolutePosition"):Connect(update),
			beneath:GetPropertyChangedSignal("AbsoluteSize"):Connect(update),
			gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update),
			dropdownFrame.ChildAdded:Connect(update),
			dropdownFrame.ChildRemoved:Connect(update),
			UserInputService.InputEnded:Connect(function(input, processed)
				if processed or not inputTypeIsClick[input.UserInputType] then return end
				RunService.Heartbeat:Wait()
				if dropdownFrame.Visible then
					self:Close()
				end
			end),
			self.OptionSelected:Connect(handler),
		}
		dropdownCatchClick.Visible = true
	end
	function dropdown:IsOpen()
		return dropdownFrame.Visible
	end
	function dropdown:Close()
		clearCons()
		dropdownFrame.Visible = false
		dropdownCatchClick.Visible = false
	end
	dropdownCatchClick.Activated:Connect(function()
		dropdown:Close()
	end)
end

local topBarLeft = topBar.Left
do -- About menu
	local TextService = game:GetService("TextService")
	local function getTextHeight(label, width)
		return TextService:GetTextSize(label.Text, label.TextSize, label.Font, Vector2.new(width, 32767)).Y
	end
	local About = require(ReplicatedStorage.Library.About)
	local menu = gui.About

	local function getTabs(obj)
		return {
			Controls = obj.Controls,
			FAQ = obj.FAQ,
			Credits = obj.Credits,
			Map = obj.Map,
		}
	end
	local tabHeaders = getTabs(menu.Buttons)
	local tabs = getTabs(menu.Content)

	local menuInstance = menuFromFrame(menu)
	local base = menuInstance.Open
	function menuInstance.Open()
		base()
		local ContentProvider = game:GetService("ContentProvider")
		ContentProvider:PreloadAsync({tabs.Controls})
		ContentProvider:PreloadAsync(About.FloorMaps)
		menuInstance.Open = base -- only need to preload the first time
	end
	topBarMenus[topBarLeft.About] = menuInstance

	local selectedTab, selectedTabHeader
	local selectedBG = Color3.fromRGB(0, 0, 0)
	local unselectedBG = tabHeaders.FAQ.BackgroundColor3
	local function selectTab(name)
		if selectedTab and selectedTab.Name == name then return end
		if selectedTab then
			selectedTab.Visible = false
			selectedTabHeader.Font = Enum.Font.SourceSans
			selectedTabHeader.AutoButtonColor = true
			selectedTabHeader.BackgroundColor3 = unselectedBG
			sfx.PageTurn:Play() -- playing this here ensures it won't run when selectTab is first initialized
		end
		selectedTab = tabs[name]
		selectedTabHeader = tabHeaders[name]
		selectedTab.Visible = true
		selectedTabHeader.Font = Enum.Font.SourceSansBold
		selectedTabHeader.BackgroundColor3 = selectedBG
		selectedTabHeader.AutoButtonColor = false
	end
	for name, tab in tabHeaders do
		tab.Activated:Connect(function() selectTab(name) end)
	end
	selectTab("FAQ")

	local qaLabels = {} -- list of {.question : label .answer : list<label>}
	local faqFrame = tabs.FAQ
	for i, v in ipairs(About.FAQ) do
		local question, answer = v.Question, v.Answer
		local q = Instance.new("TextLabel")
		q.Name = "Q"..i
		q.BackgroundTransparency = 1
		q.Font = Enum.Font.SourceSansItalic
		q.Text = "Q"..i..") "..question
		q.TextSize = 32
		q.TextWrapped = true
		q.TextXAlignment = Enum.TextXAlignment.Left
		q.TextColor3 = Color3.new(1, 1, 1)
		q.Parent = faqFrame
		if type(answer) == "string" then
			answer = {answer}
		end
		local aList = table.create(#answer)
		for j, text in answer do
			local a = Instance.new("TextLabel")
			a.Name = "A"..i.."-"..j
			a.BackgroundTransparency = 1
			a.Font = Enum.Font.SourceSansLight
			a.Text = if j == 1 then "A"..i..") "..text else text
			a.TextSize = 24
			a.TextWrapped = true
			a.TextXAlignment = Enum.TextXAlignment.Left
			a.TextColor3 = q.TextColor3
			a.Parent = faqFrame
			aList[j] = a
		end
		qaLabels[i] = {question = q, answer = aList}
	end
	local resetTutorials = faqFrame.ResetTutorials
	local function calcOffsets()
		local offset = 2 * (resetTutorials.AbsolutePosition.Y - resetTutorials.Parent.AbsolutePosition.Y) - faqFrame.UIPadding.PaddingTop.Offset + resetTutorials.AbsoluteSize.Y
		local padding = faqFrame.UIPadding
		local width = faqFrame.AbsoluteWindowSize.X - padding.PaddingLeft.Offset - padding.PaddingRight.Offset
		for i, t in ipairs(qaLabels) do
			local q, aList = t.question, t.answer
			local height = getTextHeight(q, width)
			q.Size = UDim2.new(1, 0, 0, height)
			q.Position = UDim2.new(0, 0, 0, offset)
			offset += height

			for j, a in ipairs(aList) do
				height = getTextHeight(a, width)
				a.Size = UDim2.new(1, 0, 0, height)
				a.Position = UDim2.new(0, 0, 0, offset)
				offset += height
			end
			offset += 25
		end
		local y = offset - 25 + padding.PaddingBottom.Offset + padding.PaddingTop.Offset
		faqFrame.CanvasSize = UDim2.new(0, 0, 0, y)
		faqFrame.ScrollingEnabled = y > faqFrame.AbsoluteSize.Y
	end
	calcOffsets()
	faqFrame:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(calcOffsets)
	resetTutorials.Activated:Connect(function()
		displayMenu(nil, nil)
		profile.Tutorial:ResetAll()
	end)

	local creditFrame = tabs.Credits
	local template = creditFrame.Row
	for i, t in ipairs(About.Credits) do
		local title, credit = t[1], t[2]
		local row = i == 1 and template or template:Clone()
		local _, numNewLines = credit:gsub("\n", "")
		local numRows = 1 + numNewLines
		row.Size = UDim2.new(1, 0, 0, math.max(row.Title.TextSize, row.Credit.TextSize * numRows))
		row.Title.Text = title
		row.Credit.Text = credit
		row.Parent = creditFrame
	end
	handleVerticalScrollingFrame(creditFrame)

	local floorMap = tabs.Map.FloorMapHolder.FloorMap
	local mapHeader = tabs.Map.Header
	local mapLabel = mapHeader.Floor
	local curFloor = 1
	local function setFloor(i)
		curFloor = i
		mapLabel.Text = "Floor " .. i
		floorMap.Image = About.FloorMaps[i]
	end
	mapHeader.Back.Activated:Connect(function()
		local new = curFloor - 1
		setFloor(new == 0 and #About.FloorMaps or new)
	end)
	mapHeader.Next.Activated:Connect(function()
		setFloor((curFloor % #About.FloorMaps) + 1)
	end)
end

local function toTime(sec)
	sec = math.floor(sec + 0.5)
	return ("%d:%.2d"):format(sec / 60, sec % 60) -- %d does math.floor on the integer
end

-- TODO make MusicClient know curTrackOriginalIndex (keep track during shuffling)
--	then have CurTrackIndexChanged (and also listen to PlaylistChanged)
--	and bold the currently playing track
--	(useful if the same track is in the playlist more than once)
-- TODO filter out non-permitted on load (consider not filtering out those that fail with "Attempt to retrieve data failed" - definitely don't delete them forever!)
do -- Music
	local menu = gui.Music
	topBarMenus[topBarLeft.Music] = menuFromFrame(menu)

	local currentlyPlayingProgress = menu.CurrentlyPlayingProgress
	local currentlyPlayingLabel = menu.CurrentlyPlaying
	local currentlyPlayingBar = currentlyPlayingProgress.Bar
	local function updateProgress()
		if music:GetEnabled() then
			local sound = music:GetCurSong()
			if sound then
				local curSongId = music:GetCurSongId()
				currentlyPlayingLabel.Text = ("%s%s %s/%s"):format(
					music:GetCurSongDesc() or "?", -- "?" would only happen if they saved a song that is no longer allowed or if a Roblox service is down (which has happened)
					if curSongId then " (#" .. curSongId .. ")" else "",
					toTime(sound.TimePosition),
					toTime(sound.TimeLength))
					currentlyPlayingBar.Size = UDim2.new(sound.TimePosition / sound.TimeLength, 0, 1, 0)
			end
		end
	end
	-- Continously call updateProgress while menu is open
	local con
	menu:GetPropertyChangedSignal("Visible"):Connect(function()
		updateProgress()
		if menu.Visible then
			con = RunService.Heartbeat:Connect(updateProgress)
		else
			con:Disconnect()
		end
	end)

	local actions = menu.Actions
	local playRectOffset = Vector2.new(764, 244)
	local pauseRectOffset = Vector2.new(804, 124)
	local togglePause = actions.TogglePause
	local function updateTogglePause()
		togglePause.ImageRectOffset = if music:IsPaused() then playRectOffset else pauseRectOffset
	end
	togglePause.Activated:Connect(function()
		music:TogglePause()
		updateTogglePause()
	end)
	updateTogglePause()
	actions.Prev.Activated:Connect(function()
		music:PrevSong()
		updateTogglePause()
	end)
	actions.Next.Activated:Connect(function()
		music:NextSong()
		updateTogglePause()
	end)
	local actionButtons = {togglePause, actions.Prev, actions.Next}
	local headerBGColor = menu.Header.BackgroundColor3
	local progressPlayingBG = Color3.new()
	music.EnabledChanged:Connect(function(enabled)
		if enabled then
			currentlyPlayingProgress.BackgroundColor3 = progressPlayingBG
			currentlyPlayingBar.BackgroundTransparency = 0
			for _, b in ipairs(actionButtons) do b.Visible = true end
		else
			currentlyPlayingLabel.Text = ""
			currentlyPlayingProgress.BackgroundColor3 = headerBGColor
			currentlyPlayingBar.BackgroundTransparency = 1
			for _, b in ipairs(actionButtons) do b.Visible = false end
		end
	end)

	-- Playlist Dropdown Helper Functions
	local function makeOption(playlist, disabled)
		local text = ("%s (%d)"):format(playlist.Name, #playlist.Songs)
		return disabled and Option(text, Enum.Font.SourceSansBold, false) or text
	end
	local function addDefaultPlaylistsToOptions(n, options, indexToPlaylist, curPlaylist)
		--	curPlaylist: currently selected playlist in the dropdown control
		for _, playlist in ipairs(music.ListOfDefaultPlaylists) do
			n = n + 1
			options[n] = makeOption(playlist, curPlaylist == playlist)
			indexToPlaylist[n] = playlist
		end
		return n
	end
	local function addCustomPlaylistsToOptions(n, options, indexToPlaylist, curPlaylist, includeEmpty)
		--	curPlaylist: currently selected playlist in the dropdown control
		for _, playlist in ipairs(includeEmpty and music:GetSortedCustomPlaylists() or music:GetSortedCustomPlaylistsWithContent()) do
			n = n + 1
			options[n] = makeOption(playlist, curPlaylist == playlist)
			indexToPlaylist[n] = playlist
		end
	end

	do -- Playlist Selector
		local playlistButton = menu.Header.Playlist -- Used to open the dropdown
		local playlistLabel = playlistButton.PlaylistLabel -- Used to show which playlist is active
		local indexToPlaylist
		playlistLabel.Text = music:GetEnabled()
			and music:GetActivePlaylist().Name
			or "Off"
		local function playlistSelectorDropdownHandler(i)
			if i == 1 then
				music:InvokeSetEnabled(false)
				playlistLabel.Text = "Off"
			else
				music:InvokeSetEnabled(true)
				actions.Visible = true
				local playlist = indexToPlaylist[i]
				music:InvokeSetActivePlaylist(playlist)
				playlistLabel.Text = playlist.Name
			end
			sfx.PageTurn:Play()
		end
		music.ActivePlaylistChanged:Connect(function(playlist)
			if music:GetEnabled() then
				playlistLabel.Text = playlist.Name
			end
		end)
		playlistButton.Activated:Connect(function()
			local cur = music:GetEnabled() and music:GetActivePlaylist()
			local options = {not cur and {Text = "Off", Font = Enum.Font.SourceSansBold, Enabled = false} or "Off"}
			indexToPlaylist = {}
			local n = 1
			n = addDefaultPlaylistsToOptions(n, options, indexToPlaylist, cur)
			addCustomPlaylistsToOptions(n, options, indexToPlaylist, cur)
			dropdown:Open(options, playlistSelectorDropdownHandler, playlistButton)
		end)
	end

	local function genBoldLabel(getPlaylist, indexToLabel)
		--	returns boldLabel(label), updateBold(), cons -- you should call boldLabel(nil) before changing list of labels and updateBold after
		local prevBoldLabel
		local function boldLabel(label)
			if prevBoldLabel then
				prevBoldLabel.Font = Enum.Font.SourceSans
			end
			prevBoldLabel = label
			if label then
				label.Font = Enum.Font.SourceSansBold
			end
		end
		local function updateBold()
			local playlist = music:GetEnabled() and getPlaylist()
			if not playlist then
				boldLabel(nil)
				return
			end
			if playlist == music:GetActivePlaylist() then
				boldLabel(indexToLabel(music:GetCurSongIndex()))
			else
				-- find first one that shares the same id
				local targetId = music:GetCurSongId()
				for i, id in ipairs(playlist.Songs) do
					if id == targetId then
						boldLabel(indexToLabel(i))
						return
					end
				end
				boldLabel(nil)
			end
		end
		return boldLabel, updateBold, {
			music.CurSongIndexChanged:Connect(updateBold),
			music.EnabledChanged:Connect(updateBold),
		}
	end

	-- Playlist Editor
	local appendSong
	local playlistEditor = menu.PlaylistEditor
	do
		local customTracks = playlistEditor.CustomTracksHolder.CustomTracks
		handleVerticalScrollingFrame(customTracks)
		local newRow = customTracks.Row
		newRow.LayoutOrder = 1e6
		newRow.ID.PlaceholderText = "Song ID #"
		newRow.Title.Text = ""
		local customTemplate = newRow:Clone()
		do -- Cannot delete the new song row
			local button = newRow.DeleteHolder.Delete
			button.AutoButtonColor = false
			button.Image = ""
			button.Active = false
			button.BackgroundTransparency = 1
		end
		local customName = playlistEditor.CustomName
		local updatePlaylist, updatePlaylistName -- defined below
		local customPlaylist
		local deletePlaylist = playlistEditor.DeleteCustom
		local con
		local nameCon
		local function setCustomPlaylist(playlist)
			if con then
				con:Disconnect()
				nameCon:Disconnect()
				con = nil
			end
			customPlaylist = playlist
			if playlist then
				con = customPlaylist.SongsChanged:Connect(updatePlaylist)
				nameCon = customPlaylist.NameChanged:Connect(updatePlaylistName)
				newRow.Visible = true
				deletePlaylist.Visible = true
			else
				newRow.Visible = false
				deletePlaylist.Visible = false
			end
			updatePlaylistName()
			updatePlaylist()
		end
		music.PlaylistRemoved:Connect(function(playlist)
			if playlist == customPlaylist then
				setCustomPlaylist(nil)
			end
		end)
		local deleting = false
		local boxWithFocus
		local function adaptToPlaylist(obj, id)
			obj.ID.PlaceholderText = id
			obj.ID.Text = ""
			local desc, reason = music:GetDescForId(id)
			obj.Title.Text = desc or ("? (%s)"):format(reason)
		end
		local customObjs
		local boldLabel, updateBold = genBoldLabel(function() return customPlaylist end, function(i) return customObjs:Get(i).Title end)
		updatePlaylist = function()
			boldLabel(nil)
			customObjs:AdaptToList(customPlaylist and customPlaylist.Songs or {}, adaptToPlaylist)
			newRow.ID.Text = ""
			updateBold()
		end
		updatePlaylistName = function()
			customName.PlaceholderText = customPlaylist and customPlaylist.Name or "Create/Edit"
			customName.Text = ""
		end
		deletePlaylist.Activated:Connect(function()
			if not customPlaylist then return end
			if not MessageBox.Show(("Are you sure you want to delete %s?"):format(customPlaylist.Name)) then return end
			local playlist = customPlaylist
			music:InvokeRemoveCustomPlaylist(playlist)
		end)

		local function setupBoxHandler(row, onSongEntered)
			local box = row.ID
			local prevText = ""
			return {
				box:GetPropertyChangedSignal("Text"):Connect(function()
					if deleting or box.Text == prevText then return end
					-- Only allow positive integers
					if not box.Text:match("^%d*$") then
						box.Text = prevText
					end
					prevText = box.Text
				end),
				box.Focused:Connect(function()
					boxWithFocus = box
				end),
				box.FocusLost:Connect(function(enterPressed)
					if boxWithFocus == box then
						boxWithFocus = nil
					end
					if box.Text == "" or box.Text == box.PlaceholderText then
						box.Text = ""
						return
					end
					if enterPressed then
						local songId = tonumber(box.Text)
						if songId then
							box.Text = songId
							onSongEntered(songId)
						else
							StarterGui:SetCore("SendNotification", {
								Title = "Invalid Sound ID",
								Text = "Enter in the number only",
								Duration = 3,
							})
							box.Text = ""
						end
					else
						box.Text = ""
					end
				end)
			}
		end
		function appendSong(songId)
			newRow.ID.Text = ""
			if not customPlaylist then
				local newPlaylist = music:InvokeCreateCustomPlaylist({Songs = {songId}})
				if newPlaylist then
					setCustomPlaylist(newPlaylist)
				end
				return
			end
			music:InvokeSetCustomPlaylistTrack(customPlaylist, #customPlaylist.Songs + 1, songId)
		end
		setupBoxHandler(newRow, appendSong)
		customObjs = ObjectList.new(function(i)
			local row = customTemplate:Clone()
			row.LayoutOrder = i
			row.Parent = customTracks
			local cons = setupBoxHandler(row, function(songId) music:InvokeSetCustomPlaylistTrack(customPlaylist, i, songId) end)
			cons[#cons + 1] = row.DeleteHolder.Delete.Activated:Connect(function()
				music:InvokeRemoveCustomPlaylistTrack(customPlaylist, i)
				if boxWithFocus then boxWithFocus:ReleaseFocus(false) end
			end)
			return row, cons
		end)
		customName.FocusLost:Connect(function(enterPressed)
			local newName = String.Trim(customName.Text):sub(1, music.MAX_PLAYLIST_NAME_LENGTH)
			if newName == "" then return end
			local existing = music:GetCustomPlaylistByName(newName)
			if existing then
				setCustomPlaylist(existing)
			elseif not customPlaylist then
				music:InvokeCreateCustomPlaylist({Name = newName})
			else
				if customPlaylist.Name ~= newName then
					music:InvokeRenameCustomPlaylist(customPlaylist, newName)
				else
					customName.Text = ""
				end
			end
		end)
		customName:GetPropertyChangedSignal("Text"):Connect(function()
			if #customName.Text > music.MAX_PLAYLIST_NAME_LENGTH then
				customName.Text = customName.Text:sub(1, music.MAX_PLAYLIST_NAME_LENGTH)
			end
		end)
		setCustomPlaylist(nil)

		local customNameArrow = playlistEditor.CustomNameArrow
		local indexToPlaylist
		local function editPlaylistDropdownHandler(i)
			if i == 1 then -- new
				local newCustomPlaylist = music:InvokeCreateCustomPlaylist()
				if not newCustomPlaylist then return end
				setCustomPlaylist(newCustomPlaylist)
			else
				setCustomPlaylist(indexToPlaylist[i])
			end
			sfx.PageTurn:Play()
		end
		customNameArrow.Activated:Connect(function()
			local options = {{Text = "New", Font = Enum.Font.SourceSansItalic}}
			indexToPlaylist = {}
			addCustomPlaylistsToOptions(1, options, indexToPlaylist, customPlaylist, true)
			dropdown:Open(options, editPlaylistDropdownHandler, customName, customNameArrow.AbsoluteSize.X)
		end)
	end

	do -- Playlist Viewer
		local viewPlaylist
		local viewPlaylistButton = playlistEditor.ViewPlaylist
		local viewPlaylistLabel = viewPlaylistButton.Label
		local viewTracks = playlistEditor.ViewTracksHolder.ViewTracks
		handleVerticalScrollingFrame(viewTracks)
		local viewTemplate = viewTracks.Row
		viewTemplate.Parent = nil
		local indexToPlaylist
		local viewObjs = ObjectList.new(function(i)
			local obj = viewTemplate:Clone()
			obj.Parent = viewTracks
			return obj, obj.CopyHolder.Copy.Activated:Connect(function()
				appendSong(viewPlaylist.Songs[i])
			end)
		end)
		local cons
		local boldLabel, updateBold = genBoldLabel(
			function() return viewPlaylist end,
			function(i)
				local obj = viewObjs:Get(i)
				return obj and obj.Title
			end)
		local function setPlaylistToView(playlist)
			viewPlaylist = playlist
			viewPlaylistLabel.Text = playlist.Name
			boldLabel(nil)
			viewObjs:AdaptToList(playlist.Songs, function(obj, songId)
				local desc, reason = music:GetDescForId(songId)
				obj.Title.Text = desc or ("? (%s)"):format(reason)
			end)
			updateBold()
			if cons then
				for _, con in ipairs(cons) do con:Disconnect() end
			end
			local function refresh() setPlaylistToView(viewPlaylist) end
			cons = {
				viewPlaylist.NameChanged:Connect(refresh),
				viewPlaylist.SongsChanged:Connect(refresh),
			}
		end
		music.PlaylistRemoved:Connect(function(playlist)
			if playlist == viewPlaylist then
				setPlaylistToView(music:GetActivePlaylist())
			end
		end)
		setPlaylistToView(music:GetActivePlaylist())
		local function viewDropdownHandler(i)
			setPlaylistToView(indexToPlaylist[i])
			sfx.PageTurn:Play()
		end
		viewPlaylistButton.Activated:Connect(function()
			local options = {}
			indexToPlaylist = {}
			local n = addDefaultPlaylistsToOptions(0, options, indexToPlaylist, viewPlaylist)
			addCustomPlaylistsToOptions(n, options, indexToPlaylist, viewPlaylist)
			dropdown:Open(options, viewDropdownHandler, viewPlaylistButton)
		end)
	end
end

topBarMenus[topBarLeft.Search] = BookSearch
topBarMenus[topBarLeft.BookViewingSettings] = BookViewingSettings

for button, menu in topBarMenus do
	local atRest = 0.5
	local onHover = 0.72
	local onClick = 0.33
	button.BackgroundTransparency = atRest
	button.MouseEnter:Connect(function()
		button.BackgroundTransparency = onHover
	end)
	button.InputBegan:Connect(function(input)
		if inputTypeIsClick[input.UserInputType] then
			button.BackgroundTransparency = onClick
		end
	end)
	button.InputEnded:Connect(function()
		button.BackgroundTransparency = atRest
	end)
	if menu == BookViewingSettings then
		button.Activated:Connect(function()
			displayMenu(
				if displayedMenu ~= BookSearch then displayedMenu else nil,
				if displayedBVS ~= menu then menu else nil)
		end)
	else
		button.Activated:Connect(function()
			displayMenu(
				if displayedMenu ~= menu then menu else nil,
				if menu ~= BookSearch then displayedBVS else nil)
		end)
	end
end

BookGui.BookOpened:Connect(function()
	displayMenu(nil, displayedBVS, true)
end)

do -- Keep top bar at the correct position
	local enabledPos = UDim2.new(0, 104, 0, 4)
	local disabledPos = UDim2.new(0, 60, 0, 4)
	-- Unfortunately the event to let us know when the Chat has been disabled/enabled is only available to CoreScripts; see https://developer.roblox.com/api-reference/event/StarterGui/CoreGuiChangedSignal
	RunService.Heartbeat:Connect(function()
		topBarLeft.Position = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Chat) and enabledPos or disabledPos
	end)
end