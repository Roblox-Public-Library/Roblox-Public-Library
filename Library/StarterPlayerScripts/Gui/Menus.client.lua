--[[
Measurements/sizes for TopBar taken from TopBar+: https://github.com/1ForeverHD/HDAdmin/tree/master/Projects/Topbar%2B
A handy gear/settings icon is also available from them: http://www.roblox.com/asset/?id=2484556379
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Assert = require(ReplicatedStorage.Utilities.Assert)
local gui = ReplicatedStorage.Guis.Menus
local topBar = ReplicatedStorage.Guis.TopBar

local BookSearch = require(script.Parent.BookSearch)
local music = require(script.Parent.Parent.Music)
local profile = require(script.Parent.Parent.Profile)

local localPlayer = game:GetService("Players").LocalPlayer
local playerGui = localPlayer.PlayerGui
gui.Parent = playerGui
topBar.Parent = playerGui

local sfx = ReplicatedStorage.SFX

local inputTypeIsClick = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.Touch] = true,
}

local function handleVerticalScrollingFrame(sf, layout)
	Assert.IsA(sf, "ScrollingFrame")
	layout = layout
		and Assert.IsA(layout, "UIGridStyleLayout") -- must support AbsoluteContentSize
		or sf:FindFirstChildWhichIsA("UIGridStyleLayout")
		or error("No UIGridStyleLayout in " .. tostring(sf))
	local function update()
		sf.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
	end
	update()
	return layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
end

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
local closeMenu = displayMenu -- meant for use in connections; works so long as no arguments sent

local topBarMenus = {}
local function menuFromFrame(obj)
	return {
		Open = function() obj.Visible = true end,
		Close = function() obj.Visible = false end,
	}
end

local ObjectList = {} -- A list of reusable objects that may contain connections.
ObjectList.__index = ObjectList
function ObjectList.new(init)
	--	init:function(i):object, con/List<con> to be disconnected when the object is destroyed
	return setmetatable({
		init = init,
		list = {},
		cons = {},
	}, ObjectList)
end
function ObjectList:get(i)
	local list = self.list
	local value = list[i]
	if not value then
		local cons
		value, cons = self.init(i)
		list[i] = value
		self.cons[i] = cons
	end
	return value
end
function ObjectList:destroy(i)
	self.list[i]:Destroy()
	self.list[i] = nil
	local cons = self.cons[i]
	self.cons[i] = nil
	if cons then
		if cons.Disconnect then
			cons:Disconnect()
		else
			for _, con in ipairs(cons) do
				con:Disconnect()
			end
		end
	end
end
function ObjectList:destroyRest(startIndex)
	local list = self.list
	for i = startIndex, #list do
		self:destroy(i)
	end
end
function ObjectList:Count() return #self.list end
function ObjectList:AdaptToList(newList, adaptObject)
	--	Create or reuse an object for each item in newList using adaptObject(object, item) to adapt them
	for i, item in ipairs(newList) do
		adaptObject(self:get(i), item)
	end
	self:destroyRest(#newList + 1)
end
function ObjectList:ForEach(func, startIndex)
	local list = self.list
	for i = startIndex or 1, #list do
		if func(i, list[i]) then break end
	end
end

local ButtonList = setmetatable({}, ObjectList)
ButtonList.__index = ButtonList
function ButtonList.new(initButton)
	--	initButton:function(i):button
	local isEnabled = {}
	local event = Instance.new("BindableEvent")
	local function init(i)
		local button = initButton(i)
		return button, button.Activated:Connect(function()
			event:Fire(i, button, isEnabled[i])
		end)
	end
	local self = setmetatable(ObjectList.new(init), ButtonList)
	self.isEnabled = isEnabled
	self.Activated = event.Event --(i, button, enabled)
	return self
end
local base = ButtonList.destroy
function ButtonList:destroy(i)
	base(self, i)
	self.isEnabled[i] = nil
end
function ButtonList:SetEnabled(i, value)
	value = not not value
	self:get(i).AutoButtonColor = value
	self.isEnabled[i] = value
end
function ButtonList:AdaptToList(newList, adaptButtonReturnEnabled)
	for i, item in ipairs(newList) do
		local button = self:get(i)
		self:SetEnabled(button, adaptButtonReturnEnabled(button, item))
	end
	self:destroyRest(#newList + 1)
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
	dropdown.OptionSelected = event.Event --(index, text)
	local MAX_BOTTOM_Y_SCALE = 0.9 -- bottom of dropdown cannot reach past this scale on screen

	local list = ButtonList.new(function()
		local button = template:Clone()
		button.Parent = dropdownFrame
		return button
	end)
	list.Activated:Connect(function(i, button, enabled)
		if enabled then
			event:Fire(i, button.Text)
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
		Assert.Function(handler) --(index selected, text)
		Assert.IsA(beneath, "GuiObject")
		extraXSize = extraXSize and Assert.Number(extraXSize) or 0
		clearCons()
		for i, op in ipairs(options) do
			print(i, type(op) == "table" and op.Text or op)
		end
		local function update()
			local pos = beneath.AbsolutePosition
			local size = beneath.AbsoluteSize
			local posY = pos.Y + size.Y + math.max(beneath.BorderSizePixel, dropdownFrame.BorderSizePixel)
			dropdownFrame.Position = UDim2.new(0, pos.X, 0, posY)
			local availSpace = gui.AbsoluteSize.Y * MAX_BOTTOM_Y_SCALE - posY
			dropdownFrame.Size = UDim2.new(0, size.X + extraXSize, 0, math.min(list:Count() * listSizeY, availSpace))
			print("update dropdownFrame", dropdownFrame.Size, "|", list:Count(), listSizeY, availSpace)
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
	local function updateProgress()
		local sound = music:GetCurSong()
		if sound and sound.IsPlaying then
			currentlyPlayingProgress.Visible = true
			currentlyPlayingLabel.Visible = true
			currentlyPlayingLabel.Text = ("%s (#%d) %s/%s"):format(
				music:GetCurSongDesc() or "?", -- "?" would only happen if they saved a song that is no longer allowed. TODO filter these out on load, then remove the "?" here.
				music:GetCurSongId(),
				toTime(sound.TimePosition),
				toTime(sound.TimeLength))
			currentlyPlayingProgress.Bar.Size = UDim2.new(sound.TimePosition / sound.TimeLength, 0, 1, 0)
		else
			currentlyPlayingLabel.Visible = false
			currentlyPlayingProgress.Visible = false
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

	-- Playlist Selector
	local playlistButton = content.Header.Playlist
	local playlistLabel = playlistButton.PlaylistLabel
	local function editPlaylistDropdownHandler(i, text)
		if i == 1 then
			profile:SetMusicEnabled(false)
			playlistLabel.Text = "Off"
		else
			profile:SetMusicEnabled(true)
			profile:SetActivePlaylistName(text)
			playlistLabel.Text = text
		end
		sfx.PageTurn:Play()
	end
	playlistButton.Activated:Connect(function()
		local cur = profile:GetMusicEnabled() and profile:GetActivePlaylistName()
		local options = {
			not cur and {Text = "Off", Font = Enum.Font.SourceSansBold, Enabled = false} or "Off",
			cur == "Default" and {Text = "Default", Font = Enum.Font.SourceSansBold, Enabled = false} or "Default",
		}
		for _, name in ipairs(music:GetSortedCustomPlaylistNames()) do
			options[#options + 1] = cur ~= name
				and name
				or Option(name, Enum.Font.SourceSansBold, false)
		end
		dropdown:Open(options, editPlaylistDropdownHandler, playlistButton)
	end)

	-- Playlist Editor
	local playlistEditor = content.PlaylistEditor
	local customTracks = playlistEditor.CustomTracks
	handleVerticalScrollingFrame(customTracks)
	local customName = playlistEditor.CustomName
	local customPlaylistName -- nil for "new with no songs yet" state
	local customTemplate = customTracks.Row
	-- customTemplate is also the "enter new id" row
	customTemplate.LayoutOrder = 1e6
	customTemplate.ID.PlaceholderText = "Song ID #"
	customTemplate.Title.Text = ""
	local deleting = false
	local boxWithFocus
	local function adaptToPlaylist(obj, id)
		obj.ID.PlaceholderText = id
		obj.ID.Text = ""
		obj.Title.Text = music:GetDescForId(id)
	end
	local function updatePlaylist()
		customObjs:AdaptToList(customPlaylist, adaptToPlaylist)
	end
	local customObjs; customObjs = ObjectList.new(function(i)
		local obj = customTemplate:Clone()
		obj.LayoutOrder = i
		obj.Parent = customTracks
		local box = obj.ID
		local prevText = ""
		return obj, {
			obj.DeleteHolder.Delete.Activated:Connect(function()
				table.remove(customPlaylist, i)
				if boxWithFocus then boxWithFocus:ReleaseFocus(false) end
				updatePlaylist()
			end)
			box:GetPropertyChangedSignal("Text"):Connect(function()
				if deleting then return end
			end),
			box.Focused:Connect(function()
				boxWithFocus = box
			end),
			box.FocusLost:Connect(function(enterPressed)
				if boxWithFocus == box then
					boxWithFocus = nil
				end
				if box.Text == "" or box.Text == prevText then return end
				if enterPressed then
					local id = tonumber(box.Text)
					local problem
					if id then
						box.Text = id
						music:TrySetCustomPlaylistTrack(customPlaylistName, i, id)
						customPlaylist[i] = id
						updatePlaylist()
					else
						problem = "Enter in the number only"
					end
					if problem then
						StarterGui:SetCore("SendNotification", {
							Title = "Invalid Sound ID",
							Text = problem,
							Duration = 3,
						})
						box.Text = ""
					end
				else
					box.Text = ""
				end
			end)
		}
	end)
	customName.FocusLost:Connect(function(enterPressed)
		profile:InvokeRenameCustomPlaylist(oldName, newName)

	end)
	local function editPlaylist(name)
		--	name should be nil/false if this is a new playlist
		customName.Text = ""
		if name then
			customName.PlaceholderText = name

			-- todo fill contents
		else
			customName.PlaceholderText = music:GetNewPlaylistName()
			--	todo unit test GetNewPlaylistName? - if "Custom #1" already exists, do "Custom #2"
			-- todo clear out contents
		end
		sfx.PageTurn:Play()
	end

	playlistEditor.CustomNameArrow.Activated:Connect(function()
		local options = {{Text = "New", Font = Enum.Font.SourceSansItalic}}
		for _, name in ipairs(music:GetSortedCustomPlaylistNames()) do
			options[#options + 1] = name
		end
		local function handler(i, text)
			editPlaylist(i > 1 and text)
			-- todo
		end
		dropdown:Open(options, handler, playlistButton)
	end)

	-- Playlist Viewer
	local viewPlaylist -- list of ids
	local viewPlaylistButton = playlistEditor.ViewPlaylist
	local viewPlaylistLabel = viewPlaylistButton.Label
	local viewTracks = playlistEditor.ViewTracks
	handleVerticalScrollingFrame(viewTracks)
	local viewTemplate = viewTracks.Row
	viewTemplate.Parent = nil
	local viewObjs = ObjectList.new(function(i)
		local obj = viewTemplate:Clone()
		obj.Parent = viewTracks
		return obj, obj.CopyHolder.Copy.Activated:Connect(function()
			-- todo copy this song id to the playlist being edited
			appendSong(viewPlaylist[i])
		end)
	end)
	local function setPlaylistToView(name)
		viewPlaylistLabel.Text = name
		viewObjs:AdaptToList(music:GetPlaylist(name) or error("No playlist named " .. tostring(name)), function(obj, songId)
			obj.Title.Text = music:GetDescForId(songId)
		end)
	end
	setPlaylistToView("Default")
	local function viewDropdownHandler(i, text)
		setPlaylistToView(text)
		sfx.PageTurn:Play()
	end
	viewPlaylistButton.Activated:Connect(function()
		local options = {}
		local cur = viewPlaylistLabel.Text
		for _, name in ipairs(music:GetDefaultPlaylists()) do
			options[#options + 1] = name ~= cur
				and name
				or Option(name, Enum.Font.SourceSansBold, false)
		end
		for _, name in ipairs(music:GetSortedCustomPlaylistNames()) do
			options[#options + 1] = name ~= cur
				and name
				or Option(name, Enum.Font.SourceSansBold, false)
		end
		dropdown:Open(options, viewDropdownHandler, viewPlaylistButton)
	end)
end

topBarMenus[topBar.Right.Search] = BookSearch

for button, menu in pairs(topBarMenus) do
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