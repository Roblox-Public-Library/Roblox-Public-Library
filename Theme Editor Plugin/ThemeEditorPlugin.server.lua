local parent = script.Parent
local ThemePartsData = require(parent.ThemePartsData)
local MenuOption = require(parent.PluginUtility.MenuOption)

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")
local Selection = game:GetService("Selection")

local function undoable(desc, fn)
	game:GetService("ChangeHistoryService"):SetWaypoint("Before " .. desc)
	local success, msg = xpcall(fn, function(msg) return debug.traceback(msg, 2) end)
	game:GetService("ChangeHistoryService"):SetWaypoint(desc)
	if not success then error(msg) end
end

local function handleVerticalScrollingFrame(sf)
	--	Handles setting the CanvasSize for a vertical ScrollingFrame ('sf')
	--	Layout is optional, but there must exist a UIGridStyleLayout in ScrollingFrame if it is not provided (ex UIListLayout)
	--	Returns a the connection that keeps it up to date
	local layout = sf:FindFirstChildWhichIsA("UIGridStyleLayout") or error("No UIGridStyleLayout in " .. tostring(sf))
	local padding = sf:FindFirstChildWhichIsA("UIPadding")
	local function update()
		sf.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + (padding and padding.PaddingTop.Offset + padding.PaddingBottom.Offset or 0))
	end
	update()
	return layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
end

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
local widgetFrame = parent.Widget:Clone()
widgetFrame.Parent = widget
local considerStartup -- defined below

local toolbar = plugin:CreateToolbar("Theme Editor")
local themeEditorButton = toolbar:CreateButton("Theme Editor", "Open the theme editor", "")
themeEditorButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
	considerStartup()
end)

local function setInstalled(installed)
	installed = not not installed
	widgetFrame.InstallButton.Visible = not installed
	widgetFrame.ThemesFrame.NewThemeButton.Visible = installed
	widgetFrame.PartsFrame.ApplyButton.Visible = installed
end
local editor
local currentTheme
local selectedTheme
local internalSelectedTheme -- current client, not objectvalue
local function getRandomThemeColor()
	local v
	repeat
		v = Color3.new(math.random(), math.random(), math.random())
	until v.R + v.G + v.B > 0.4
	return v
end
local function createThemeColor(color, parent)
	local color = Instance.new("Color3Value")
	color.Name = "Theme Color"
	color.Value = color
	color.Parent = parent
	return color
end
local function createRandomThemeColor(parent)
	return createThemeColor(getRandomThemeColor(), parent)
end

local function getDefaultTheme(onCreated) : Folder
	local defaultTheme = editor:FindFirstChild("Default") or editor:FindFirstChildOfClass("Folder")()
	if not defaultTheme then -- No themes
		defaultTheme = Instance.new("Folder")
		defaultTheme.Name = "Default"
		defaultTheme.Parent = editor
		createRandomThemeColor(defaultTheme)
		if onCreated then
			onCreated()
		end
	end
	return defaultTheme
end
local installFinishedObj = Instance.new("BindableEvent")
local installFinished = installFinishedObj.Event
local function installFinish(wasInstalled) -- called when user installs or when plugin starts up in installed place (possibly with widget closed)
	currentTheme = editor:FindFirstChild("Current Theme")
	if not currentTheme then
		currentTheme = Instance.new("ObjectValue")
		currentTheme.Name = "Current Theme"
		currentTheme.Parent = editor
		if wasInstalled then
			print("Installed Current Theme object value")
		end
	end
	selectedTheme = editor:FindFirstChild("Selected Theme")
	if not selectedTheme then
		selectedTheme = Instance.new("ObjectValue")
		selectedTheme.Name = "Selected Theme"
		selectedTheme.Parent = editor
		if wasInstalled then
			print("Installed Selected Theme object value")
		end
	end
	if not currentTheme.Value then
		local onCreated = wasInstalled and function() print("Added Default theme folder") end
		local defaultTheme = getDefaultTheme(onCreated)
		currentTheme.Value = defaultTheme
		selectedTheme.Value = defaultTheme
	end
	installFinishedObj:Fire()
end
local function getCurrentTheme() : Folder?
	--	Returns currentTheme.Value unless it points to a deleted/nil theme in which case it returns nil
	if currentTheme.Value and not currentTheme.Value.Parent then
		currentTheme.Value = nil
	end
	return currentTheme.Value
end
local function getSelectedTheme(onCreated) : Folder
	--	Returns selectedTheme.Value unless it points to a deleted/nil theme in which case it fixes it
	if not selectedTheme.Value or not selectedTheme.Value.Parent then
		selectedTheme.Value = getCurrentTheme() or getDefaultTheme(onCreated)
	end
	return selectedTheme.Value
end
local function getInternalSelectedTheme() : Folder?
	if not internalSelectedTheme or not internalSelectedTheme.Parent then
		internalSelectedTheme = nil
	end
	return internalSelectedTheme
end

widgetFrame.InstallButton.MouseButton1Click:Connect(function()
	ChangeHistoryService:SetWaypoint("Before install Theme Editor")
	editor = Instance.new("Folder")
	editor.Name = "Theme Editor"
	editor.Parent = ServerStorage
	local readme = parent.Instructions:Clone()
	readme.Parent = editor
	plugin:OpenScript(readme)
	setInstalled(true)
	installFinish(false)
	considerStartup()
	ChangeHistoryService:SetWaypoint("Install Theme Editor")
end)

local props = {"Material", "Color", "Transparency", "Reflectance"}
local function matchWorkspaceToTheme(theme)
	--	theme:Folder
	undoable("Apply " .. theme.Name .. " to workspace", function()
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
		currentTheme.Value = theme
	end)
end

local Studio = settings().Studio
local StudioColor = Enum.StudioStyleGuideColor
local StudioModifier = Enum.StudioStyleGuideModifier
local buttonNormalColor
local buttonHoverColor
local function updateColors()
	buttonNormalColor = Studio.Theme:GetColor(StudioColor.RibbonButton, StudioModifier.Default)
	buttonHoverColor = Studio.Theme:GetColor(StudioColor.RibbonButton, StudioModifier.Hover)
end
updateColors()

local function disconnectList(list)
	for _, con in ipairs(list) do
		con:Disconnect()
	end
end

local partsScroll = widgetFrame.PartsFrame.PartsScroll
local partTemplate = partsScroll.Part
partTemplate.Parent = nil

local renamePartMenu
local renameTarget -- the theme part from which the rename menu was activated

local PartViewport = {}
PartViewport.__index = PartViewport
function PartViewport.new()
	local self
	local viewport = partTemplate:Clone()
	viewport.Parent = partsScroll
	viewport.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Selection:Set({self.themePart})
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			renameTarget = self.themePart
			renamePartMenu:ShowAsync()
		end
	end)
	self = setmetatable({
		viewport = viewport,
	}, PartViewport)
	return self
end
function PartViewport:ChangeThemePart(themePart)
	local viewport = self.viewport
	local part = viewport.Part
	if self.cons then
		disconnectList(self.cons)
	end
	local cons = {}
	for i, prop in ipairs(props) do
		local function updatePartProp()
			part[prop] = themePart[prop]
		end
		updatePartProp()
		cons[i] = themePart:GetPropertyChangedSignal(prop):Connect(updatePartProp)
	end
	viewport.PartName.Text = themePart.Name
	self.themePart = themePart
	self.cons = cons
end
function PartViewport:Destroy() -- todo make sure if themePart is deleted that PartViewport is destroyed
	self.viewport:Destroy()
	if self.cons then
		disconnectList(self.cons)
	end
end

local function log(...)
	print(parent.Name .. ":", ...)
end

local folderToThemeData
local function forEachThemePartsData(fn)
	for _, folder in ipairs(editor:GetChildren()) do
		if fn(folderToThemeData[folder].PartsData) then return end
	end
end

local function addPartsToTheme()
	local partsData = folderToThemeData[getSelectedTheme()].PartsData
	local parts = Selection:Get()
	local notUnique = {}
	for _, part in ipairs(parts) do
		if not partsData:AddPartIfUnique(part) then
			table.insert(notUnique, part.Name)
		end
	end
	if #parts == 0 then
		log("No parts selected")
	elseif #notUnique == #parts then
		log("All selected parts are already in " .. getSelectedTheme().Name)
	elseif #notUnique ~= 0 then
		log("Parts " .. table.concat(notUnique, ", ") .. " are already in " .. getSelectedTheme().Name)
	end
end
local function addPartsToAllThemes()
	local parts = Selection:Get()
	forEachThemePartsData(function(partsData)
		for _, part in ipairs(parts) do
			partsData:AddPartIfUnique(part)
		end
	end)
end

local function renamePartInAllThemesBase(callback)
	if not renameTarget then
		local list = game.Selection:Get()
		if #list == 1 then
			renameTarget = list[1]
		elseif #list == 0 then
			log("Cannot rename part: no part selected")
			return
		else
			log("Cannot rename part: multiple parts selected")
			return
		end
	else
		game.Selection:Set({renameTarget})
	end
	local oldName = renameTarget.Name
	local partsData = folderToThemeData[getSelectedTheme()].PartsData
	local con1, con2
	local function cleanup()
		con1:Disconnect()
		con2:Disconnect()
	end
	con1 = game.Selection.SelectionChanged:Connect(function()
		log("Rename cancelled")
		cleanup()
	end)
	con2 = renameTarget:GetPropertyChangedSignal("Name"):Connect(function()
		cleanup()
		local newName = renameTarget.Name
		local numChanges = 1 -- it's automatically renamed in the selected theme
		task.defer(function()
			forEachThemePartsData(function(partsData)
				if partsData:PartExists(oldName) then
					partsData:RenamePart(oldName, newName)
					numChanges += 1
				end
			end)
			callback(oldName, newName)
		end)
	end)
end
local function renamePartInAllThemes()
	renamePartInAllThemesBase(function(oldName, newName, numThemesChanged)
		log("'" .. oldName .. "' renamed to '" .. newName .. "' in " .. numThemesChanged .. " themes.")
	end)
end

local function renamePartInWorkspace()
	renamePartInAllThemesBase(function(oldName, newName, numThemesChanged)
		local numWorkspaceChanged = 0
		for i, child in ipairs(workspace:GetDescendants()) do
			if child:IsA("BasePart") then
				if child.Name == oldName then
					child.Name = newName
					numWorkspaceChanged += 1
				end
			end
		end
		log("'" .. oldName .. "' renamed to '" .. newName .. "' in " .. numThemesChanged .. " themes and " .. numWorkspaceChanged .. " places in workspace.")
	end)
end

local addPartsButton = widgetFrame.PartsFrame.AddPartsButton
-- local addPartsButtonEnabled = false
-- local enabledColor = Color3.fromRGB(217, 217, 217)
-- local disabledColor = Color3.fromRGB(175, 175, 175)
-- local function setPartsButtonEnabled(enabled)
-- 	addPartsButtonEnabled = enabled
-- 	addPartsButton.Font = if enabled then Enum.Font.SourceSans else Enum.Font.Arial
-- 	addPartsButton.Text = if enabled then "+" else "<i>+</i>"
-- 	addPartsButton.TextColor3 = if enabled then enabledColor else disabledColor
-- end

local addPartsMenu
local addToThemeOption
local addToAllThemesOption
local function prepareAddPartsMenu()
	addPartsMenu:Clear()
	addToThemeOption:AddToMenu(addPartsMenu)
	addToAllThemesOption:AddToMenu(addPartsMenu)
end

installFinished:Connect(function()
	addPartsMenu = plugin:CreatePluginMenu("0", "Add Part(s)")
	local addToThemeAction = plugin:CreatePluginAction("AddToTheme", "Add part(s) to selected theme", "Adds the currently selected part(s) to the selected theme, ignoring duplicates.")
	addToThemeAction.Triggered:Connect(addPartsToTheme)
	addToThemeOption = MenuOption.new(addToThemeAction)
	local addToAllThemesAction = plugin:CreatePluginAction("AddToThemes", "Add part(s) to all themes", "Adds the currently selected part(s) to all themes, ignoring duplicates.")
	addToAllThemesAction.Triggered:Connect(addPartsToAllThemes)
	addToAllThemesOption = MenuOption.new(addToAllThemesAction)
	prepareAddPartsMenu()
	addPartsButton.MouseButton1Click:Connect(function()
		addPartsMenu:ShowAsync()
	end)

	renamePartMenu = plugin:CreatePluginMenu("1", "Rename Part")
	local renamePartAllThemesAction = plugin:CreatePluginAction("RenamePartAllThemes", "Renames this part in all themes.")
	renamePartAllThemesAction.Triggered:Connect() --TODO
	local renamePartInWorkspace = plugin:CreatePluginAction("RenamePartInWorkspace", "Renames this part in workspace and all themes.")
	renamePartInWorkspace.Triggered:Connect() --TODO
	renamePartMenu:AddAction(renamePartInAllThemes)
	renamePartMenu:AddAction(renamePartInWorkspace)
	renamePartMenu:AddSeparator()
	renamePartMenu:AddAction(addToAllThemesAction)
end)

local themeScroll = widgetFrame.ThemesFrame.ThemesScroll
local themeTemplate = themeScroll.Theme
themeTemplate.Parent = nil

local ThemeRow = {}
ThemeRow.__index = ThemeRow
function ThemeRow.new(folder)
	--	folder: the theme folder
	local self
	local row = themeTemplate:Clone()
	row.Parent = themeScroll
	local themeName = row.ThemeName
	local function updateName()
		row.Name = folder.Name
		themeName.Text = folder.Name
	end
	updateName()
	local color = folder:FindFirstChild("Theme Color")
	if not color then
		color = createRandomThemeColor(folder)
	end
	local function updateColor()
		row.Color.BackgroundColor3 = color.Value
	end
	updateColor()
	local cons; cons = {
		folder.Changed:Connect(updateName),
		color.Changed:Connect(updateColor),
		folder.AncestryChanged:Connect(function(child, parent)
			if parent ~= editor then
				self:Destroy()
			end
		end),
		themeName.MouseButton1Click:Connect(function()
			Selection:Set({folder})
			self.onClicked:Fire()
		end),
		row.Color.MouseButton1Click:Connect(function()
			Selection:Set({color})
		end),
	}
	local onClicked = Instance.new("BindableEvent")
	local onSelected = Instance.new("BindableEvent")
	local onDestroyed = Instance.new("BindableEvent")
	self = setmetatable({
		OnDestroyed = onDestroyed.Event, -- Event (can :Connect to this)
		onDestroyed = onDestroyed, -- BindableEvent
		OnClicked = onClicked.Event,
		onClicked = onClicked,
		OnSelected = onSelected.Event,
		onSelected = onSelected,
		cons = cons,
		row = row,
		folder = folder,
	}, ThemeRow)
	return self
end
function ThemeRow:Destroy()
	self.onDestroyed:Fire()
	self.onDestroyed:Destroy()
	self.onClicked:Destroy()
	self.onSelected:Destroy()
	disconnectList(self.cons)
	self.row:Destroy()
end
function ThemeRow:Select()
	local themeName = self.row.ThemeName
	themeName.Active = false -- todo this isn't working?
	themeName.AutoButtonColor = false
	themeName.BackgroundColor3 = buttonHoverColor
	self.onSelected:Fire()
end
function ThemeRow:Deselect()
	local themeName = self.row.ThemeName
	themeName.BackgroundColor3 = buttonNormalColor
	themeName.Active = true
	themeName.AutoButtonColor = true
end
function ThemeRow:AppliedToWorkspace()
	local themeName = self.row.ThemeName
	themeName.Font = Enum.Font.SourceSansBold
end
function ThemeRow:NotAppliedToWorkspace()
	local themeName = self.row.ThemeName
	themeName.Font = Enum.Font.SourceSans
end

local ThemeData = {}
ThemeData.__index = ThemeData
function ThemeData.new(folder)
	return setmetatable({
		folder = folder,
		Row = ThemeRow.new(folder),
		PartsData = ThemePartsData.new(folder),
	}, ThemeData)
end
function ThemeData:Destroy()
	self.Row:Destroy()
	self.PartsData:Destroy()
end

local cons
local currentViewports
local function init()
	-- Initialize theme list
	folderToThemeData = {}
	currentViewports = {}
	local function selectTheme(newSelectedTheme)
		assert(newSelectedTheme, "newSelectedTheme must be provided")
		if internalSelectedTheme and internalSelectedTheme.Parent then
			folderToThemeData[internalSelectedTheme].Row:Deselect()
		end
		folderToThemeData[newSelectedTheme].Row:Select()
		internalSelectedTheme = newSelectedTheme
		selectedTheme.Value = newSelectedTheme
	end
	local function addThemeButton(themeFolder)
		local themeData = ThemeData.new(themeFolder)
		folderToThemeData[themeFolder] = themeData
		local row = themeData.Row
		row.OnDestroyed:Connect(function()
			folderToThemeData[themeFolder] = nil
		end)
		row.OnClicked:Connect(function()
			selectTheme(themeFolder)
		end)
		row.OnSelected:Connect(function()
			local i = 0
			for _, themePart in ipairs(themeFolder:GetChildren()) do
				if themePart:IsA("BasePart") then
					i = i + 1
					local viewport = currentViewports[i]
					if not viewport then
						viewport = PartViewport.new()
						currentViewports[i] = viewport
					end
					viewport:ChangeThemePart(themePart)
				end
			end
			for j = i + 1, #currentViewports do
				currentViewports[j]:Destroy()
				currentViewports[j] = nil
			end
		end)
	end
	local function onEditorChildAdded(child)
		if child:IsA("Folder") then
			addThemeButton(child)
		end
	end
	for i, child in ipairs(editor:GetChildren()) do
		onEditorChildAdded(child)
	end
	selectTheme(getSelectedTheme())
	local pastTheme = getCurrentTheme()
	local function updateCurrentTheme()
		if pastTheme and pastTheme.Parent then
			folderToThemeData[pastTheme].Row:NotAppliedToWorkspace()
		end
		local curTheme = getCurrentTheme()
		if curTheme then
			folderToThemeData[curTheme].Row:AppliedToWorkspace()
		end
		pastTheme = curTheme
	end
	updateCurrentTheme()
	local function setUIColors()
		themeTemplate.ThemeName.BackgroundColor3 = buttonNormalColor
		partTemplate.BackgroundColor3 = buttonNormalColor -- todo this is viewport; update (NOT buttonNormalColor)
		-- todo update all existing ui
		-- should we move this below the updateColors function? or move that function here?
	end
	setUIColors()
	local selectionChangedRecently
	cons = {
		handleVerticalScrollingFrame(themeScroll),
		handleVerticalScrollingFrame(partsScroll),
		currentTheme.Changed:Connect(function() task.spawn(updateCurrentTheme) end),
		widgetFrame.ThemesFrame.NewThemeButton.MouseButton1Click:Connect(function()
			local newTheme
			local created
			local themeToUse = getInternalSelectedTheme() or getSelectedTheme(function() created = true end)
			if not created then
				newTheme = themeToUse:Clone()
				local _, _, baseName, num = newTheme.Name:find("^(.-)%s*%((%d+)%)%s*$")
				baseName = baseName or newTheme.Name
				num = num and tonumber(num) or 1
				for i, theme in ipairs(editor:GetChildren()) do
					local _, _, num2 = theme.Name:find("^" .. baseName .. " *%((%d+)%) *$")
					num2 = tonumber(num2)
					num = num2 and num2 > num and num2 or num
				end
				newTheme.Name = ("%s (%d)"):format(baseName, num + 1)
				local color = newTheme:FindFirstChild("Theme Color")
				if not color then
					local rndColor = getRandomThemeColor()
					createThemeColor(rndColor, currentTheme) -- old theme needs to have a theme color
					createThemeColor(rndColor, newTheme)
				end
				newTheme.Parent = editor
			end
		end),
		editor.ChildAdded:Connect(onEditorChildAdded),
		widgetFrame.PartsFrame.ApplyButton.MouseButton1Click:Connect(function()
			local theme = getInternalSelectedTheme()
			if theme then
				matchWorkspaceToTheme(theme)
			else -- todo disable button when internalSelectedTheme is nil or becomes invalid (deparented)
				print("Please select a theme to apply!")
			end
		end),
		Studio.ThemeChanged:Connect(function()
			updateColors()
			setUIColors()
		end),
		game.Selection.SelectionChanged:Connect(function()
			if selectionChangedRecently then return end
			selectionChangedRecently = true
			-- conditions we care about:
			-- a theme must be selected
			-- 1+ part selected not in selected theme that is in the workspace
			-- 
			task.defer(function()
				selectionChangedRecently = false
				for _, v in ipairs(game.Selection:Get()) do
					-- conditions
				end
			end)
		end)
	}
end

local function cleanup()
	-- delete all children except the uilistlayout
	for _, con in ipairs(cons) do
		con:Disconnect()
	end
	cons = nil
	for _, viewport in ipairs(currentViewports) do
		viewport:Destroy()
	end
	currentViewports = nil
	for _, themeData in pairs(folderToThemeData) do
		themeData:Destroy()
	end
	folderToThemeData = nil
end
plugin.Unloading:Connect(function()
	if cons then
		cleanup()
	end
end)
function considerStartup()
	if editor and widget.Enabled then
		if not cons then
			init()
		end
	else
		if cons then
			cleanup()
		end
	end
end

editor = ServerStorage:FindFirstChild("Theme Editor")
setInstalled(editor)
if editor then
	installFinish(true)
end
considerStartup()