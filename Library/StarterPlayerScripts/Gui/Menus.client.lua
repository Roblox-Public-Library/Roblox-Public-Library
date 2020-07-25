--[[
Measurements/sizes for TopBar taken from TopBar+: https://github.com/1ForeverHD/HDAdmin/tree/master/Projects/Topbar%2B
A handy gear/settings icon is also available from them: http://www.roblox.com/asset/?id=2484556379
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local MessageBox = require(ReplicatedStorage.MessageBox)
local Utilities = ReplicatedStorage.Utilities
local Assert = require(Utilities.Assert)
local String = require(Utilities.String)
local ObjectList = require(Utilities.ObjectList)
local ButtonList = require(ReplicatedStorage.Gui.ButtonList)
local gui = ReplicatedStorage.Guis.Menus
local topBar = ReplicatedStorage.Guis.TopBar

local BookSearch = require(script.Parent.BookSearch)
local music = require(ReplicatedStorage.MusicClient)
local profile = require(ReplicatedStorage.ProfileClient)
local GuiUtilities = require(ReplicatedStorage.Gui.Utilities)

local localPlayer = game:GetService("Players").LocalPlayer
local playerGui = localPlayer.PlayerGui
gui.Parent = playerGui
topBar.Parent = playerGui

local sfx = ReplicatedStorage.SFX

local inputTypeIsClick = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.Touch] = true,
}

local handleVerticalScrollingFrame = GuiUtilities.HandleVerticalScrollingFrame

local displayedMenu
local function displayMenu(menu)
	if displayedMenu == menu then return end
	if displayedMenu then
		displayedMenu:Close()
		if not menu then -- only play sound if won't be playing BookOpen below
			sfx.BookClose:Play()
		end
	end
	displayedMenu = menu
	if displayedMenu then
		sfx.BookOpen:Play()
		displayedMenu:Open()
	end
end
local function closeMenu() displayMenu() end -- meant for use in connections

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
	local catchClick = gui.CatchClick
	catchClick.Activated:Connect(function()
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
		catchClick.Visible = true
	end
	function dropdown:Close()
		clearCons()
		dropdownFrame.Visible = false
		catchClick.Visible = false
	end
end

do -- About menu
	local menu = gui.About
	topBarMenus[topBar.Right.About] = menuFromFrame(menu)
	local function getTabs(obj)
		return {
			Controls = obj.Controls,
			FAQ = obj.FAQ,
			Credits = obj.Credits,
		}
	end
	local tabs = getTabs(menu.Tabs)
	local tabHeaders = getTabs(menu.TabHeaders)
	local selectedTab, selectedTabHeader
	local selectedBG = Color3.fromRGB(71, 71, 71)
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
	for name, tab in pairs(tabHeaders) do
		tab.Activated:Connect(function() selectTab(name) end)
	end
	selectTab("Controls")

	local About = require(ReplicatedStorage.About)
	tabs.FAQ.Text = About.FAQ
	tabs.Controls.Text = About.Controls
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

	menu.Close.Activated:Connect(closeMenu)
end

local function toTime(sec)
	sec = math.floor(sec + 0.5)
	return ("%d:%.2d"):format(sec / 60, sec % 60) -- %d does math.floor on the integer
end

do -- Music
	local menu = gui.Music
	topBarMenus[topBar.Right.Music] = menuFromFrame(menu)
	menu.Close.Activated:Connect(closeMenu)

	local content = menu.Content

	local currentlyPlayingProgress = content.CurrentlyPlayingProgress
	local currentlyPlayingLabel = content.CurrentlyPlaying
	local currentlyPlayingBar = currentlyPlayingProgress.Bar
	local function updateProgress()
		local sound = music:GetCurSong()
		if sound and sound.IsPlaying then
			currentlyPlayingLabel.Text = ("%s (#%d) %s/%s"):format(
				music:GetCurSongDesc() or "?", -- "?" would only happen if they saved a song that is no longer allowed. TODO filter these out on load, then remove the "?" here.
				music:GetCurSongId(),
				toTime(sound.TimePosition),
				toTime(sound.TimeLength))
			currentlyPlayingProgress.BackgroundTransparency = 0
			currentlyPlayingBar.BackgroundTransparency = 0
			currentlyPlayingBar.Size = UDim2.new(sound.TimePosition / sound.TimeLength, 0, 1, 0)
		else
			currentlyPlayingLabel.Text = ""
			currentlyPlayingProgress.BackgroundTransparency = 1
			currentlyPlayingBar.BackgroundTransparency = 1
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
		local playlistButton = content.Header.Playlist -- Used to open the dropdown
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

	-- Playlist Editor
	local appendSong
	local playlistEditor = content.PlaylistEditor
	do
		local customTracks = playlistEditor.CustomTracks
		handleVerticalScrollingFrame(customTracks)
		local newRow = customTracks.Row
		newRow.LayoutOrder = 1e6
		newRow.ID.PlaceholderText = "Song ID #"
		newRow.Title.Text = ""
		local customTemplate = newRow:Clone()
		do -- Cannot delete the new song row
			local button = newRow.DeleteHolder.Delete
			button.AutoButtonColor = false
			button.Text = ""
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
			obj.Title.Text = music:GetDescForId(id)
		end
		local customObjs
		updatePlaylist = function()
			customObjs:AdaptToList(customPlaylist and customPlaylist.Songs or {}, adaptToPlaylist)
			newRow.ID.Text = ""
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
		local viewTracks = playlistEditor.ViewTracks
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
		local function setPlaylistToView(playlist)
			viewPlaylist = playlist
			viewPlaylistLabel.Text = playlist.Name
			viewObjs:AdaptToList(playlist.Songs, function(obj, songId)
				obj.Title.Text = music:GetDescForId(songId)
			end)
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

topBarMenus[topBar.Right.Search] = BookSearch

for button, menu in pairs(topBarMenus) do
	local atRest = 0.5
	local onHover = 0.72
	local onClick = 0.33
	button.ImageTransparency = atRest
	button.MouseEnter:Connect(function()
		button.ImageTransparency = onHover
	end)
	button.InputBegan:Connect(function(input)
		if inputTypeIsClick[input.UserInputType] then
			button.ImageTransparency = onClick
		end
	end)
	button.InputEnded:Connect(function()
		button.ImageTransparency = atRest
	end)
	button.Activated:Connect(function()
		displayMenu(displayedMenu ~= menu and menu or nil)
	end)
end

local events = require(script.Parent.BookGui)
events.BookOpened:Connect(function()
	BookSearch:Hide()
	gui.Enabled = false
end)
events.BookClosed:Connect(function()
	BookSearch:Unhide()
	gui.Enabled = true
end)