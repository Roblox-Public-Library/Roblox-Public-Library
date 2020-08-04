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

Overlapping themes (optional):
	Cross reference the different theme folders and if they have the same parts as children they are likely related
	Print any differences that the related themes have to notify user ?
]]

local ServerStorage = game:GetService("ServerStorage")
local Selection = game:GetService("Selection")

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
local widgetFrame = script.Parent.Widget:Clone()
widgetFrame.Parent = widget
local considerConnections -- defined below

local toolbar = plugin:CreateToolbar("Theme Editor")
local themeEditorButton = toolbar:CreateButton("Theme Editor", "Open the theme editor", "")
themeEditorButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
	considerConnections()
end)

local function setInstalled(installed)
	installed = not not installed
	widgetFrame.InstallButton.Visible = not installed
	widgetFrame.ThemesFrame.NewThemeButton.Visible = installed
	widgetFrame.PartsFrame.ApplyButton.Visible = installed
end
local editor
local curTheme
local defaultFolder
local function randomThemeColor(parent)
	local color = Instance.new("Color3Value")
	color.Name = "Theme Color"
	local v
	repeat
		v = Color3.new(math.random(), math.random(), math.random())
	until v.R + v.G + v.B > 0.4
	color.Value = v
	color.Parent = parent
	return color
end

local function installFinish(wasInstalled) -- called when user installs or when plugin starts up in installed place (possibly with widget closed)
	curTheme = editor:FindFirstChild("Current Theme")
	if not curTheme then
		curTheme = Instance.new("ObjectValue")
		curTheme.Name = "Current Theme"
		curTheme.Parent = editor
		if wasInstalled then
			print("Installed Current Theme object value")
		end
	end
	defaultFolder = editor:FindFirstChild("Default") or editor:FindFirstChildOfClass("Folder")
	if not defaultFolder then -- No themes
		defaultFolder = Instance.new("Folder")
		defaultFolder.Name = "Default"
		defaultFolder.Parent = editor
		if wasInstalled then
			print("Added Default theme folder")
		end
		randomThemeColor(defaultFolder)
	end
	if not curTheme.Value then
		curTheme.Value = defaultFolder
	end
end

editor = ServerStorage:FindFirstChild("Theme Editor")
setInstalled(editor)
if editor then
	installFinish(true)
end

widgetFrame.InstallButton.MouseButton1Click:Connect(function()
	editor = Instance.new("Folder")
	editor.Name = "Theme Editor"
	editor.Parent = ServerStorage
	local readme = script.Parent.Instructions:Clone()
	readme.Parent = editor
	plugin:OpenScript(readme)
	setInstalled(true)
	installFinish(false)
	considerConnections()
end)

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

local Studio = settings().Studio
local StudioColor = Enum.StudioStyleGuideColor
local StudioModifier = Enum.StudioStyleGuideModifier
local buttonNormalColor = Studio.Theme:GetColor(StudioColor.RibbonButton, StudioModifier.Default)
local buttonHoverColor = Studio.Theme:GetColor(StudioColor.RibbonButton, StudioModifier.Hover)
--todo Studio.ThemeChanged:Connect

local cons
local selectedTheme
local themeScroll = widgetFrame.ThemesFrame.ThemesScroll
local themeTemplate = themeScroll.Theme
themeTemplate.Parent = nil
local partsScroll = widgetFrame.PartsFrame.PartsScroll
local partTemplate = partsScroll.Part
partTemplate.Parent = nil
local function setConnections()
	-- Initialize theme list
	local currentViewports = {}
	local folderToRow = {}
	for i, folder in ipairs(editor:GetChildren()) do
		if folder:IsA("Folder") then
			local row = themeTemplate:Clone()
			folderToRow[folder] = row
			row.Parent = themeScroll
			local themeName = row.ThemeName
			local function updateName()
				themeName.Text = folder.Name
			end
			updateName()
			local color = folder:FindFirstChild("Theme Color")
			if not color then
				color = randomThemeColor(folder)
			end
			local function updateColor()
				row.Color.BackgroundColor3 = color.Value
			end
			updateColor()
			local cons; cons = {
				folder.Changed:Connect(updateName),
				color.Changed:Connect(updateColor),
				folder.AncestryChanged:Connect(function(child, parent)
					row:Destroy()
					for _, con in ipairs(cons) do
						con:Disconnect()
					end
				end),
				themeName.MouseButton1Click:Connect(function()
					selectedTheme = folder
					themeName.Active = false
					themeName.AutoButtonColor = false
					themeName.BackgroundColor3 = buttonHoverColor
					local i = 0
					for _, themePart in ipairs(folder:GetChildren()) do
						if themePart:IsA("BasePart") then
							i = i + 1
							local viewport = currentViewports[i]
							if not viewport then
								viewport = partTemplate:Clone()
								viewport.Parent = partsScroll
								viewport.InputBegan:Connect(function(input)
									if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
									Selection:Set({themePart})
								end)
								currentViewports[i] = viewport
							end
							local oldPart = viewport:FindFirstChildOfClass("BasePart")
							oldPart:Destroy()
							local newPart = themePart:Clone()
							newPart.Parent = viewport
							newPart.Position = Vector3.new(0, 0, -1.75)
							newPart.Size = Vector3.new(1, 1, 1)
							newPart.Orientation = Vector3.new(0, 0, 0)
							viewport.PartName.Text = newPart.Name
							-- todo setup connections here
						end
					end
					for j = i + 1, #currentViewports do
						currentViewports[j]:Destroy()
						currentViewports[j] = nil
					end
				end),
				-- todo disconnect these from disconnectConnections (probably store in table of folder -> connections and remove when needed)
			}
		end
	end
	local pastTheme
	local function boldCurTheme()
		if pastTheme then
			folderToRow[pastTheme].ThemeName.Font = Enum.Font.SourceSans
		end
		if curTheme.Value then
			folderToRow[curTheme.Value].ThemeName.Font = Enum.Font.SourceSansBold
		end
		pastTheme = curTheme.Value
	end
	boldCurTheme()
	curTheme.Changed:Connect(boldCurTheme)
	cons = {
		widgetFrame.ThemesFrame.NewThemeButton.MouseButton1Click:Connect(function()
			local newTheme
			if not curTheme.Value or not curTheme.Value.Parent then -- no cur theme (or was deleted)
				curTheme.Value = editor:FindFirstChild("Default") or editor:FindFirstChildOfClass("Folder") or nil
			end
			if curTheme.Value then
				newTheme = curTheme.Value:Clone()
				local _, _, baseName, num = newTheme.Name:find("(.*?) %((%d+)%)")
				newTheme.Name = ("%s (%d)"):format(baseName or newTheme.Name, (num or 1) + 1)
				local color = newTheme:FindFirstChild("Theme Color")
				if color then
					color:Destroy()
				else
					randomThemeColor(curTheme)
				end
				randomThemeColor(newTheme)
				newTheme.Parent = editor
			else
				installFinish(true)
			end
		end),
		widgetFrame.PartsFrame.ApplyButton.MouseButton1Click:Connect(function()
			-- match workspace to currently selected theme
		end),
	}
end

-- current todo:
-- select theme to look at
-- 		on select it should create one viewport for every part located within the relevant folder name
-- ui grid layout will organize them from there :)
-- perhaps store which theme is currently being looked at/modified somewhere?
--	could be stored within script
-- 	if stored within a string (object value?) then on pluginstartup it could display whatever you were looking at last time

local function disconnectConnections()
	for _, con in ipairs(cons) do
		con:Disconnect()
	end
	cons = nil
end
function considerConnections()
	if editor and widget.Enabled then
		if not cons then
			setConnections()
		end
	else
		if cons then
			disconnectConnections()
		end
	end
end
considerConnections()