local ReplicatedStorage = game.ReplicatedStorage
local gui = ReplicatedStorage.Guis.Menus

local localPlayer = game.Players.LocalPlayer
local playerGui = localPlayer.PlayerGui
gui.Parent = playerGui
local BookSearch = require(script.Parent.BookSearch)

local sfx = ReplicatedStorage.SFX

local main = gui.MainMenu
local mainButton = main.MainButton
local mainButtonOrigText = mainButton.Text

local displayedDropdown
local function displayDropdown(obj)
	if displayedDropdown == obj then return end
	if displayedDropdown then
		displayedDropdown.Visible = false
	end
	displayedDropdown = obj
	if displayedDropdown then
		displayedDropdown.Visible = true
	end
end
local displayedMenu
local function displayMenu(menu)
	if displayedMenu == menu then return end
	if displayedMenu then
		displayedMenu:Close()
	end
	displayedMenu = menu
	if displayedMenu then
		displayedMenu:Open()
	end
end

local menuDrop = main.MenuDrop
-- Note: the menu is considered open if any dropdown/submenu is open.
local function openMainMenu() -- assumes menu is closed
	sfx.BookOpen:Play()
	displayDropdown(menuDrop)
end
local function closeMainMenu() -- assumes menu is not closed
	sfx.BookClose:Play()
	displayMenu(nil)
	displayDropdown(nil)
end
local function returnToMainMenu() -- assumes a submenu is open
	mainButton.Text = mainButtonOrigText
	sfx.PageTurn:Play()
	displayMenu(nil)
	displayDropdown(menuDrop)
end
mainButton.Activated:Connect(function()
	if not (displayedDropdown or displayedMenu) then
		openMainMenu()
	elseif displayedDropdown == menuDrop then
		closeMainMenu()
	else
		returnToMainMenu()
	end
end)

local function openMenuForButtonAndRun(button, func)
	button.Activated:Connect(function()
		mainButton.Text = button.Text:upper()
		sfx.PageTurn:Play()
		func()
	end)
end
openMenuForButtonAndRun(menuDrop.BookFinder, function()
	displayMenu(BookSearch)
end)
local playlistDrop = main.PlaylistDrop
local customPlaylistDrop = main.CustomPlaylistDrop
local simpleConnections = {
	-- [button] = dropdown to open when activated
	[menuDrop.Credits] = main.CreditDrop,
	[menuDrop.Playlist] = playlistDrop,
	[menuDrop.PlaylistCreator] = customPlaylistDrop,
}
for button, dropdown in pairs(simpleConnections) do
	openMenuForButtonAndRun(button, function()
		displayDropdown(dropdown)
	end)
end
menuDrop.Music.Activated:Connect(function()
	-- todo ask music script whether music is enabled/not and toggle it:
	local musicOn -- todo   = not music:GetEnabled(); music:SetEnabled(musicOn)
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

do -- PlaylistDrop
	-- todo rewrite
	local playlist = playlistDrop.Parent.Parent:WaitForChild("Playlist")
	local gDebounce = playlistDrop.Parent.Parent.Parent:WaitForChild("MusicScript"):WaitForChild("Switching")

	local selectedColor = Color3.fromRGB(42, 45, 54)
	local normalColor = Color3.fromRGB(100, 104, 111)

	local function updateColors()
		for i, v in ipairs(playlistDrop:GetChildren()) do
			if v.Visible then
				v.TextColor3 = v.Text == playlist.Value and selectedColor or normalColor
			end
		end
	end

	for i, v in pairs(playlistDrop:GetChildren()) do
		if v.Name == "TextButton" and v.Visible == true then
			if v.Text == "Custom Playlist" then
				v.Activated:Connect(function()
					-- todo 'if' is trying to check to see if there exists a custom playlist (with an actual Sound object)
					--	rewrite so that this button only appears if there is one!
					if not gDebounce.Value and v.TextColor3 == selectedColor and playlistDrop.Parent.Parent.Parent:WaitForChild("MusicScript"):WaitForChild("Custom"):FindFirstChild("Sound") ~= nil then
						playlist.Value = v.Text
						sfx.PageTurn:Play()
						updateColors()
					end
				end)
			else
				v.Activated:Connect(function()
					if not gDebounce.Value and v.TextColor3 == selectedColor then
						playlist.Value = v.Text
						sfx.PageTurn:Play()
						updateColors()
					end
				end)
			end
		end
	end

	updateColors()
end

do -- CustomPlaylistDrop
	local debounce = false
	local musicScript = customPlaylistDrop.Parent.Parent.Parent:WaitForChild("MusicScript")
	local savedList = game.Players.LocalPlayer:WaitForChild("SavedPlaylist")
	local reading = false
	local customPlaylist = {}
	local playlistIDs = {}
	for i = 1, 9 do
		customPlaylist[i] = customPlaylistDrop[tostring(i)]
		playlistIDs[i] = "nil"
	end

	for i, v in ipairs(customPlaylist) do
		local textBox = v.TextBox
		local textButton = v.TextButton
		local oldVal = "nil"
		textButton.Activated:Connect(function()

			if not debounce then
				sfx:WaitForChild("PageTurn"):Play()
				debounce = true
				if textBox.Text ~= "Enter SoundID Here..." then
					print(textBox.Text)
					local numberVal = tonumber(textBox.Text)
					if numberVal ~= nil then
						if tostring("lol"..tonumber(textBox.Text)) == tostring("lol"..textBox.Text) then
							print("Successfully found number ID!")
							textBox.Text = "ID Accepted!"
							playlistIDs[i] = numberVal
							oldVal = numberVal
							wait(2)
							textBox.Text = oldVal
						else
							print("No ID found!")
							textBox.Text = "No ID found!"
							playlistIDs[i] = oldVal
							wait(2)
							if oldVal == "nil" then
								textBox.Text = "Enter SoundID Here..."
							else
								textBox.Text = oldVal
							end
						end
					else
						print("No ID found!")
						textBox.Text = "No ID found!"
						playlistIDs[i] = oldVal
						wait(2)
						if oldVal == "nil" then
							textBox.Text = "Enter SoundID Here..."
						else
							textBox.Text = oldVal
						end
					end
				end
				wait()
				debounce = false
			end
		end)
	end

	function sendToMusic()
		if debounce then
			customPlaylistDrop.Parent.Visible = false
			customPlaylistDrop.Parent.Parent:WaitForChild("LoadingPlaylist").Visible = true
			for i, v in pairs(musicScript:WaitForChild("Custom"):GetChildren()) do
				if v then v:Destroy() end
			end
			for i, v in pairs(playlistIDs) do
				if type(v) == "number" then
					local sound = musicScript.Sound:Clone()
					sound.Parent = musicScript.Custom
					local con; con = sound:GetPropertyChangedSignal("TimeLength"):Connect(function()
						if sound.TimeLength == 0 then
							sound:Destroy()
						end
						con:Disconnect()
					end)
					sound.SoundId = "rbxassetid://"..v
				end
			end
			if customPlaylistDrop.Parent.Parent:WaitForChild("Playlist").Value == "Custom Playlist" then
				musicScript:WaitForChild("MusicEvent"):Fire(musicScript:WaitForChild("Temp"))
				wait(1)
				musicScript:WaitForChild("MusicEvent"):Fire(musicScript:WaitForChild("Custom"))
			end
			customPlaylistDrop.Parent.Visible = true
			customPlaylistDrop.Parent.Parent:WaitForChild("LoadingPlaylist").Visible = false
			if reading == true then
				customPlaylistDrop.Parent.Parent:WaitForChild("Reading").Value = false
				reading = false
			end
			game:GetService("ReplicatedStorage"):WaitForChild("PlaylistEvent"):FireServer(playlistIDs)
			wait()
			debounce = false
		end
	end

	function onSave()
		if not debounce then
			debounce = true
			sfx.BookClose:Play()
			sendToMusic()
			wait()
		end
	end

	customPlaylistDrop:WaitForChild("Save").Activated:Connect(onSave)
	customPlaylistDrop.Cancel.Activated:Connect(returnToMainMenu) -- todo this doesn't actually cancel!

	for i, v in pairs(savedList:GetChildren()) do
		if v.Value == "nil" then
			playlistIDs[i] = v.Value
		else
			customPlaylist[i]:WaitForChild("TextBox").Text = v.Value
			playlistIDs[i] = tonumber(v.Value)
		end
	end

	onSave()
end

-- Scripts left:
-- Music
-- Playlist
-- Book
--[[todo
when playlist changes (currently a StringValue; change that?):
menuDrop.Playlist.TextLabel.Text = playlist.Value

BookSearch must now be a ModuleScript and support :Open() :Close()
when a book is opened (should be a BindableEvent):

when a book is closed:
	ensureAtMainMenu()
	BookSearch:Unhide()
]]