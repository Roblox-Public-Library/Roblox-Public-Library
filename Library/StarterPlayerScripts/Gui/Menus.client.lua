--[[
Measurements/sizes for TopBar taken from TopBar+: https://github.com/1ForeverHD/HDAdmin/tree/master/Projects/Topbar%2B
A handy gear/settings icon is also available from them: http://www.roblox.com/asset/?id=2484556379
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local function handleVerticalScrollingFrame(sf, layout)
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
	--	init:function(i):object, con(s) to be disconnected when the object is destroyed
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
function ObjectList:AdaptToList(newList, adaptObject)
	--	Create or reuse an object for each item in newList using adaptObject(object, item) to adapt them
	for i, item in ipairs(newList) do
		adaptObject(self:get(i), item)
	end
	self:destroyRest(#newList + 1)
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
	isEnabled[i] = value
end
function ButtonList:AdaptToList(newList, adaptButtonReturnEnabled)
	for i, item in ipairs(newList) do
		local button = self:get(i)
		self:SetEnabled(button, adaptButtonReturnEnabled(button, item))
	end
	self:destroyRest(#newList + 1)
end

local dropdown = {} do
	local dropdownFrame = gui.Dropdown
	local template = gui.Button
	template.Parent = nil
	local listSizeY = template.Size.Y.Offset
	handleVerticalScrollingFrame(dropdownFrame)
	local event = Instance.new("BindableEvent")
	dropdown.OptionSelected = event.Event --(index, text)
	local MAX_BOTTOM_Y_SCALE = 0.9 -- bottom of dropdown cannot reach past this scale on screen
	
	local list = ButtonPool.new(function()
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
		local function update()
			local pos = beneath.AbsolutePosition
			local size = beneath.AbsoluteSize
			local posY = pos.Y + size.Y + math.max(beneath.BorderSizePixel, dropdownFrame.BorderSizePixel)
			dropdownFrame.Position = UDim2.new(0, pos.X, 0, posY)
			local availSpace = gui.AbsoluteSize.Y * MAX_BOTTOM_Y_SCALE - posY
			dropdownFrame.Size = UDim2.new(0, size.X + extraXSize, 0, math.min(#list * listSizeY, availSpace))
		end
		update()
		dropdownFrame.Visible = true
		cons = {
			beneath:GetPropertyChangedSignal("AbsolutePosition"):Connect(update),
			beneath:GetPropertyChangedSignal("AbsoluteSize"):Connect(update),
			gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update),
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
	for name, tab in ipairs(tabHeaders) do
		tab.Activated:Controls(function() selectTab(name) end)
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
		row.Size = math.max(row.Title.FontSize, row.Credit.FontSize * numRows)
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
		local sound = music:GetCurrentSound()
		if sound and sound.IsPlaying then
			currentlyPlayingProgress.Visible = true
			currentlyPlayingLabel.Visible = true
			currentlyPlayingLabel.Text = ("%s (#%d) %s/%s"):format(music:GetCurSongDesc(), music:GetCurSongId(), toTime(sound.TimePosition), toTime(sound.TimeLength))
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
	end
	playlistButton.Activated:Connect(function()
		local cur = profile:GetMusicEnabled() and profile:GetActivePlaylistName()
		local options = {
			not cur and {Text = "Off", Font = Enum.Font.SourceSansBold, Enabled = false} or "Off",
			cur == "Default" and {Text = "Default", Font = Enum.Font.SourceSansBold, Enabled = false} or "Default",
		}
		for _, name in ipairs(music:GetSortedCustomPlaylistNames()) do
			options[#options + 1] = cur ~= name and name or {
				Text = name,
				Font = Enum.Font.SourceSansBold,
				Enabled = false,
			}
		end
		dropdown:Open(options, editPlaylistDropdownHandler, playlistButton)
	end)

	-- Playlist Editor
	local playlistEditor = content.PlaylistEditor
	handleVerticalScrollingFrame(playlistEditor.CustomTracks)
	handleVerticalScrollingFrame(playlistEditor.ViewTracks)
	local customName = content.CustomName
	local function editPlaylist(name)
		--	name should be nil/false if this is a new playlist
		customName.Text = ""
		if name then
			customName.PlaceholderText = text
			-- todo fill contents
		else
			customName.PlaceholderText = music:GetNewPlaylistName()
			--	todo unit test GetNewPlaylistName? - if "Custom #1" already exists, do "Custom #2"
			-- todo clear out contents
		end
	end
	content.CustomNameArrow.Activated:Connect(function()
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
	local viewPlaylistButton = content.ViewPlaylist
	local viewPlaylistLabel = viewPlaylistButton.Label
	local viewTracks = content.ViewTracks
	local viewTemplate = viewTracks.Row
	local viewObjs = ObjectList.new(function(i)
		local obj = viewTemplate:Clone()
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
	local function viewDropdownHandler(i, text)
		setPlaylistToView(text)
	end
	viewPlaylistButton.Activated:Connect(function()
		local options = {}
		local cur = viewPlaylistLabel.Text
		for _, name in ipairs(music:GetDefaultPlaylists()) do
			options[#options + 1] = name ~= cur and name or {
				Text = name,
				Font = Enum.SourceSansBold,
				Enabled = false,
			}
		end
		for _, name in ipairs(music:GetSortedCustomPlaylistNames()) do
			options[#options + 1] = name ~= cur and name or {
				Text = name,
				Font = Enum.SourceSansBold,
				Enabled = false,
			}
		end
		dropdown:Open(options, viewDropdownHandler, viewPlaylistButton)
	end)
end

topBarMenus[topBar.Right.Search] = BookSearch

local inputTypeIsClick = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.Touch] = true,
}
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


------TODO REWRITE BELOW

menuDrop.Music.Activated:Connect(function()
	local musicOn = not profile:GetMusicEnabled()
	profile:SetMusicEnabled(musicOn)
	menuDrop.Music.TextLabel.Text = musicOn and "On" or "Off"
	sfx.PageTurn:Play()
end)

local events = require(script.Parent.BookGui)
events.BookOpened:Connect(function()
	BookSearch:Hide()
	gui.Enabled = false
end)
events.BookClosed:Connect(function()
	BookSearch:Unhide()
	gui.Enabled = true
end)

do -- PlaylistDrop (allow selection between playlists)
	local curPlaylistName = music:GetActivePlaylistName()
	local function updateCurrentPlaylistName()
		menuDrop.Playlist.TextLabel.Text = curPlaylistName
	end
	updateCurrentPlaylistName()

	local selectedColor = Color3.fromRGB(42, 45, 54)
	local normalColor = Color3.fromRGB(100, 104, 111)
	local buttons = {
		playlistDrop.Default,
		playlistDrop.Custom,
	}
	local function updateColors()
		for i, v in ipairs(buttons) do
			v.TextColor3 = v.Text == curPlaylistName and selectedColor or normalColor
		end
	end
	updateColors()
	local function setActivePlaylist(name)
		profile:SetActivePlaylistName(name)
		updateColors()
	end
	for i, v in ipairs(buttons) do
		v.Activated:Connect(function()
			setActivePlaylist(v.Text)
			sfx.PageTurn:Play()
		end)
	end
	if not music:CustomPlaylistHasContent() then
		playlistDrop.Custom.Visible = false
	end
	music.CustomPlaylistNowExists:Connect(function()
		playlistDrop.Custom.Visible = true
	end)
	music.CustomPlaylistNowEmpty:Connect(function()
		playlistDrop.Custom.Visible = false
	end)

	profile.ActivePlaylistNameChanged:Connect(function(value)
		curPlaylistName = value
		updateCurrentPlaylistName()
		updateColors()
	end)
end

-- do -- CustomPlaylistDrop
-- 	local debounce = false
-- 	for i = 1, 9 do
-- 		customPlaylist[i] = customPlaylistDrop[tostring(i)]
-- 		playlistIDs[i] = "nil"
-- 	end

-- 	for i, v in ipairs(customPlaylist) do
-- 		local textBox = v.TextBox
-- 		local textButton = v.TextButton
-- 		local oldVal = "nil"
-- 		textButton.Activated:Connect(function()

-- 			if not debounce then
-- 				sfx:WaitForChild("PageTurn"):Play()
-- 				debounce = true
-- 				if textBox.Text ~= "Enter SoundID Here..." then
-- 					print(textBox.Text)
-- 					local numberVal = tonumber(textBox.Text)
-- 					if numberVal ~= nil then
-- 						if tostring("lol"..tonumber(textBox.Text)) == tostring("lol"..textBox.Text) then
-- 							print("Successfully found number ID!")
-- 							textBox.Text = "ID Accepted!"
-- 							playlistIDs[i] = numberVal
-- 							oldVal = numberVal
-- 							wait(2)
-- 							textBox.Text = oldVal
-- 						else
-- 							print("No ID found!")
-- 							textBox.Text = "No ID found!"
-- 							playlistIDs[i] = oldVal
-- 							wait(2)
-- 							if oldVal == "nil" then
-- 								textBox.Text = "Enter SoundID Here..."
-- 							else
-- 								textBox.Text = oldVal
-- 							end
-- 						end
-- 					else
-- 						print("No ID found!")
-- 						textBox.Text = "No ID found!"
-- 						playlistIDs[i] = oldVal
-- 						wait(2)
-- 						if oldVal == "nil" then
-- 							textBox.Text = "Enter SoundID Here..."
-- 						else
-- 							textBox.Text = oldVal
-- 						end
-- 					end
-- 				end
-- 				wait()
-- 				debounce = false
-- 			end
-- 		end)
-- 	end

-- 	local function sendToMusic()
-- 		if debounce then
-- 			customPlaylistDrop.Parent.Visible = false
-- 			customPlaylistDrop.Parent.Parent:WaitForChild("LoadingPlaylist").Visible = true
-- 			for i, v in pairs(musicScript:WaitForChild("Custom"):GetChildren()) do
-- 				if v then v:Destroy() end
-- 			end
-- 			for i, v in pairs(playlistIDs) do
-- 				if type(v) == "number" then
-- 					local sound = musicScript.Sound:Clone()
-- 					sound.Parent = musicScript.Custom
-- 					local con; con = sound:GetPropertyChangedSignal("TimeLength"):Connect(function() -- Note: this event is triggered when the length is loaded, even if the value doesn't actually change
-- 						if sound.TimeLength == 0 then
-- 							sound:Destroy()
-- 						end
-- 						con:Disconnect()
-- 					end)
-- 					sound.SoundId = "rbxassetid://"..v
-- 				end
-- 			end
-- 			if customPlaylistDrop.Parent.Parent:WaitForChild("Playlist").Value == "Custom Playlist" then
-- 				musicScript:WaitForChild("MusicEvent"):Fire(musicScript:WaitForChild("Temp"))
-- 				wait(1)
-- 				musicScript:WaitForChild("MusicEvent"):Fire(musicScript:WaitForChild("Custom"))
-- 			end
-- 			customPlaylistDrop.Parent.Visible = true
-- 			customPlaylistDrop.Parent.Parent:WaitForChild("LoadingPlaylist").Visible = false
-- 			if reading == true then
-- 				customPlaylistDrop.Parent.Parent:WaitForChild("Reading").Value = false
-- 				reading = false
-- 			end
-- 			game:GetService("ReplicatedStorage"):WaitForChild("PlaylistEvent"):FireServer(playlistIDs)
-- 			wait()
-- 			debounce = false
-- 		end
-- 	end

-- 	local function onSave()
-- 		if not debounce then
-- 			debounce = true
-- 			sfx.BookClose:Play()
-- 			sendToMusic()
-- 			wait()
-- 		end
-- 	end

-- 	customPlaylistDrop:WaitForChild("Save").Activated:Connect(onSave)
-- 	customPlaylistDrop.Cancel.Activated:Connect(returnToMainMenu) -- todo this doesn't actually cancel!

-- 	for i, v in pairs(savedList:GetChildren()) do
-- 		if v.Value == "nil" then
-- 			playlistIDs[i] = v.Value
-- 		else
-- 			customPlaylist[i]:WaitForChild("TextBox").Text = v.Value
-- 			playlistIDs[i] = tonumber(v.Value)
-- 		end
-- 	end

-- 	onSave()
-- end

-- Scripts left:
-- Music
-- Playlist
-- Book