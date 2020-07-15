--[[
Objective:
make brick turn color

For updating theme first time:
	look inside folder for part names
	cross reference all parts in library for things with that name
	change color and material of folder bricks to match library bricks

	if there are differences between library parts:
		print multiple values for part name "x"
		don't update color in theme

For plugin, normally:
	look inside folder for part names
	cross reference all parts in library for things with that name
	change color and material to match that of part in folder

PLANNING
Initialization for any place:
	Insert a Readme script with instructions command bar snippets for the user to go through
	(Could have an "Init" feature that searches workspace for things with consistent attributes that share the same name.)

Plugin gui:
	A dropdown to change which theme you're editing (dropdown is a scrolling frame)
		When you click the dropdown or select a theme, the theme in ServerStorage should be selected (so you can easily change the name from the properties window if you wish)
	New Theme button
	A scrolling frame where each row has: PartName ViewportFrameForThatPart
		Clicking anywhere on that row selects the part in Explorer so you can edit its properties
	Apply to Workspace - applies current theme to workspace and updates "CurrentlyAppliedThemeName" (a StringValue in Theme Editor folder in ServerStorage)

Plugin functionality:
	If a part is added to/removed from/renamed in one theme while the plugin is running, automatically add/remove/remove it to the others
		If the part is then added externally to the others, remove the duplicate
	If the plugin activates and there are inconsistencies between themes, warn the user about the list of inconsistencies (but keep functioning). Automatically delete any duplicates IF the duplicates are identical (otherwise add that to the list of things to warn the user about.)
	Any action taken by the plugin should be undoable

Theme Editor (in ServerStorage) layout:
	Instructions (disabled script)
	Current Theme:StringValue
	(all other themes, as folders, here)
]]

local ServerStorage = game:GetService("ServerStorage")

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Left,
	true,   -- Initially enabled
	false,  -- Override enabled
	300,    -- Default width
	150,    -- Default height
	215,    -- Minimum width
	125     -- Minimum height
)
local widget = plugin:CreateDockWidgetPluginGui("Main", widgetInfo)
widget.Name = "Theme Editor"
widget.Title = "Theme Editor"
script.Parent.Widget:Clone().Parent = widget

local toolbar = plugin:CreateToolbar("Theme Editor")
local themeEditorButton = toolbar:CreateButton("Theme Editor", "Open the theme editor", "")
themeEditorButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

local editor = ServerStorage:FindFirstChild("Theme Editor")
if not editor then
	editor = Instance.new("Folder")
	editor.Name = "Theme Editor"
	editor.Parent = ServerStorage
	local readme = script.Parent.Instructions:Clone()
	readme.Parent = editor
	plugin:OpenScript(readme)
end
local curTheme = editor:FindFirstChild("Current Theme")
if not curTheme then
	curTheme = Instance.new("ObjectValue")
	curTheme.Name = "Current Theme"
	curTheme.Parent = editor
end
if not editor:FindFirstChildOfClass("Folder") then -- No themes
	local default = Instance.new("Folder")
	default.Name = "Default"
	default.Parent = editor
end

local props = {"Material", "Color", "Transparency", "Reflectance"}
local function matchWorkspaceToTheme(theme)
	--	theme:Folder
	local nameToPart = {}
	for i, part in ipairs(theme:GetChildren()) do
		nameToPart[part.Name] = part
	end

	for i, child in ipairs(workspace:GetDescendants()) do
		if child:IsA("BasePart") then
			local part = nameToPart[child.Name]
			if part then
				for _, prop in ipairs(props) do
					child[prop] = part[prop]
				end
			end
		end
	end
	curTheme.Value = theme
end
--matchWorkspaceToTheme(editor.Default)