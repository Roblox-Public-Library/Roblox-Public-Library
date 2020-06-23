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
main.CustomDrop.Cancel.Activated:Connect(returnToMainMenu)

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
local simpleConnections = {
	-- [button] = dropdown to open when activated
	[menuDrop.Credits] = main.CreditDrop,
	[menuDrop.Playlist] = main.PlaylistDrop,
	[menuDrop.PlaylistCreator] = main.CustomPlaylistDrop,
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