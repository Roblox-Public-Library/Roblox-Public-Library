local workspace = workspace.ThemeEditorTesting
local parent = script.Parent
local ThemePartsData = require(parent.ThemePartsData)
local MenuOption = require(parent.PluginUtility.MenuOption)
local Config = require(parent.Config)
local props = Config.Props

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Lighting = game:GetService("Lighting")
local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")

local function log(...)
	print(parent.Name .. ":", ...)
end

local function undoable(desc, fn)
	ChangeHistoryService:SetWaypoint("Before " .. desc)
	local success, msg = xpcall(fn, function(msg) return debug.traceback(msg, 2) end)
	ChangeHistoryService:SetWaypoint(desc)
	if not success then error(msg) end
end

local function connectCall(event, fn)
	fn()
	return event:Connect(fn)
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

local applyButton = widgetFrame.PartsFrame.ApplyButton
local function setInstalled(installed)
	installed = not not installed
	widgetFrame.InstallButton.Visible = not installed
	widgetFrame.ThemesFrame.NewThemeButton.Visible = installed
	applyButton.Visible = installed
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
local function createThemeColor(color, parentTheme)
	local colorValue = Instance.new("Color3Value")
	colorValue.Name = "Theme Color"
	colorValue.Value = color
	colorValue.Parent = parentTheme
	return colorValue
end
local function createRandomThemeColor(parentTheme)
	return createThemeColor(getRandomThemeColor(), parentTheme)
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
			log("Installed Current Theme object value")
		end
	end
	selectedTheme = editor:FindFirstChild("Selected Theme")
	if not selectedTheme then
		selectedTheme = Instance.new("ObjectValue")
		selectedTheme.Name = "Selected Theme"
		selectedTheme.Parent = editor
		if wasInstalled then
			log("Installed Selected Theme object value")
		end
	end
	if not currentTheme.Value then
		local onCreated = wasInstalled and function() log("Added Default theme folder") end
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
	undoable("Install Theme Editor", function()
		editor = Instance.new("Folder")
		editor.Name = "Theme Editor"
		editor.Parent = ServerStorage
		local readme = parent.Instructions:Clone()
		readme.Parent = editor
		plugin:OpenScript(readme)
		setInstalled(true)
		installFinish(false)
		considerStartup()
	end)
end)

local function matchWorkspaceToTheme(theme)
	--	theme:Folder
	undoable("Apply " .. theme.Name .. " to workspace", function()
		local nameToPart = {}
		for _, part in ipairs(theme:GetChildren()) do
			nameToPart[part.Name] = part
		end

		for _, child in ipairs(workspace:GetDescendants()) do
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

local viewports = {[partTemplate] = true} -- Set of viewports whose Ambient should be kept up-to-date
local PartViewport = {}
PartViewport.__index = PartViewport
function PartViewport.new()
	local self
	local viewport = partTemplate:Clone()
	viewports[viewport] = true
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
	table.insert(cons, connectCall(themePart:GetPropertyChangedSignal("Name"), function()
		viewport.PartName.Text = themePart.Name
	end))
	self.themePart = themePart
	self.cons = cons
end
function PartViewport:Destroy() -- todo make sure if themePart is deleted that PartViewport is destroyed
	viewports[self.viewport] = true
	self.viewport:Destroy()
	if self.cons then
		disconnectList(self.cons)
	end
end
Lighting:GetPropertyChangedSignal("Ambient"):Connect(function()
	local ambient = Lighting.Ambient
	for viewport in pairs(viewports)
		viewport.Ambient = ambient
	end
end)

local folderToThemeData
local function forEachThemePartsData(fn)
	for _, themeData in pairs(folderToThemeData) do
		if fn(themeData.PartsData) then return end
	end
end

local function addPartsToTheme()
	local partsData = folderToThemeData[getSelectedTheme()].PartsData
	local seenBefore = {} -- [Instance] = true if we've already analyzed it (protects against if user has a model and some of its descendants selected simultaneously)
	local alreadyWasInTheme = {} -- List and set of part names
	local inconsistentNames = {} -- List and set of part names with inconsistent properties
	local uniqueSoFar = {} -- [name] = part if it's unique (ignoring duplicates with identical properties)
	local partsSelected = 0
	local partsAdded = 0
	local function check(list)
		for _, instance in ipairs(list) do
			if seenBefore[instance] then continue end
			seenBefore[instance] = true
			check(instance:GetChildren())
			if instance:IsA("BasePart") then
				partsSelected += 1
				local name = instance.Name
				local other = uniqueSoFar[name]
				if other then
					-- make sure it's got the identical properties, otherwise it's inconsistent
					if not Config.ArePartPropsDuplicate(instance, other) then
						table.insert(inconsistentNames, name)
						inconsistentNames[name] = true
						uniqueSoFar[name] = nil
					end -- otherwise nothing to be done
				elseif inconsistentNames[name] or alreadyWasInTheme[name] then
					continue
				else -- haven't seen it before in this operation
					if partsData:ContainsPartName(instance.Name) then
						table.insert(alreadyWasInTheme, name)
						alreadyWasInTheme[name] = true
					else
						uniqueSoFar[name] = instance
					end
				end
			end
		end
	end
	--[[
		options for parts:
		in theme already (alreadyWasInTheme) <-- warn if nothing to be added OR could always report
		inconsistent in selection (inconsistentNames) <-- always warn
		good to be added [or is a duplicate of one to be added] (uniqueSoFar)
	]]
	check(Selection:Get())
	if next(uniqueSoFar) then
		undoable("Add selected parts to selected theme", function()
			for part in ipairs(uniqueSoFar) do
				partsAdded += 1
				partsData:AddPart(part)
			end
		end)
	end
	
	if partsSelected == 0 then
		log("No parts selected")
	else

		log([[Add Selected Parts to Theme Report
	3 parts added: List [but only show ': List' if <= 6?]
	5 parts already in theme [list max length 6?]
	10 parts with inconsistent properties: list parts [max length 20?]
]])
	end
	--[[TODO
	Finish converting log plan above into code (merge below commented out as desired)
	Figure out how much is desired for "add to all themes" case
		Extract common code & call
	]]
	-- elseif #alreadyWasInTheme == partsSelected then
	-- 	log("All selected parts are already in " .. getSelectedTheme().Name)
	-- elseif #alreadyWasInTheme ~= 0 then
	-- 	log("Parts " .. table.concat(alreadyWasInTheme, ", ") .. " are already in " .. getSelectedTheme().Name)
	-- end
end
local function addPartsToAllThemes()
	local parts = Selection:Get()
	undoable("Add selected parts to all themes", function()
		forEachThemePartsData(function(partsData)
			for _, part in ipairs(parts) do
				partsData:AddPartIfUnique(part)
			end
		end)
	end)
end

local function renamePartInAllThemesBase(desc, callback)
	if not renameTarget then
		local list = Selection:Get()
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
		Selection:Set({renameTarget})
	end
	local oldName = renameTarget.Name
	-- local partsData = folderToThemeData[getSelectedTheme()].PartsData
	local con1, con2
	local function cleanup()
		con1:Disconnect()
		con2:Disconnect()
	end
	log("Rename the selected part to rename it in ", desc)
	con1 = Selection.SelectionChanged:Connect(function()
		log("Rename cancelled")
		cleanup()
	end)
	con2 = renameTarget:GetPropertyChangedSignal("Name"):Connect(function()
		cleanup()
		local newName = renameTarget.Name
		local numThemesChanged = 1 -- it's automatically renamed in the selected theme
		task.defer(function()
			undoable("Rename " .. desc, function()
				forEachThemePartsData(function(partsData)
					if partsData:RenamePart(oldName, newName) then
						numThemesChanged += 1
					end
				end)
				callback(oldName, newName, numThemesChanged)
			end)
		end)
	end)
end
local function renamePartInAllThemes()
	renamePartInAllThemesBase(
		"in all themes",
		function(oldName, newName, numThemesChanged)
			log(string.format("'%s' renamed to '%s' in %s theme%s.", oldName, newName, numThemesChanged, if numThemesChanged == 1 then "" else "s"))
		end)
end

local function renamePartInWorkspace()
	renamePartInAllThemesBase(
		"in all themes and workspace",
		function(oldName, newName, numThemesChanged)
			local numWorkspaceChanged = 0
			for _, child in ipairs(workspace:GetDescendants()) do
				if child:IsA("BasePart") then
					if child.Name == oldName then
						child.Name = newName
						numWorkspaceChanged += 1
					end
				end
			end
			log(string.format("'%s' renamed to '%s' in %s theme%s and %s place%s in workspace.",
				oldName, newName,
				numThemesChanged, if numThemesChanged == 1 then "" else "s",
				numWorkspaceChanged, if numWorkspaceChanged == 1 then "" else "s"))
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
	local renamePartAllThemesAction = plugin:CreatePluginAction("RenamePartAllThemes", "Renames this part in all themes.","Renames this part in all themes; logs how many themes contained the part.")
	renamePartAllThemesAction.Triggered:Connect(renamePartInAllThemes)
	local renamePartInWorkspaceAction = plugin:CreatePluginAction("RenamePartInWorkspace", "Renames this part in workspace and all themes.", "Renames this part in workspace and all themes; logs how many themes contained the part and how many parts in workspace were renamed.")
	renamePartInWorkspaceAction.Triggered:Connect(renamePartInWorkspace)
	renamePartMenu:AddAction(renamePartAllThemesAction)
	renamePartMenu:AddAction(renamePartInWorkspaceAction)
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
	local row = themeTemplate:Clone()
	row.Parent = themeScroll
	local themeName = row.ThemeName
	local color = folder:FindFirstChild("Theme Color")
	if not color then
		color = createRandomThemeColor(folder)
	end
	local onClicked = Instance.new("BindableEvent")
	local onSelected = Instance.new("BindableEvent")
	local onDestroyed = Instance.new("BindableEvent")
	local self = setmetatable({
		OnDestroyed = onDestroyed.Event, -- Event (can :Connect to this)
		onDestroyed = onDestroyed, -- BindableEvent
		OnClicked = onClicked.Event,
		onClicked = onClicked,
		OnSelected = onSelected.Event,
		onSelected = onSelected,
		row = row,
		themeName = themeName,
		folder = folder,
	}, ThemeRow)
	self.cons = {
		connectCall(folder.Changed, function()
			row.Name = folder.Name
			self:updateName()
		end),
		connectCall(color.Changed, function()
			row.Color.BackgroundColor3 = color.Value
		end),
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
	return self
end
function ThemeRow:updateName()
	self.themeName.Text = if self.applied
		then "> " .. self.folder.Name .. " <"
		else "    " .. self.folder.Name
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
	local themeName = self.themeName
	themeName.Active = false -- todo this isn't working?
	themeName.AutoButtonColor = false
	themeName.BackgroundColor3 = buttonHoverColor
	self.onSelected:Fire()
end
function ThemeRow:Deselect()
	local themeName = self.themeName
	themeName.BackgroundColor3 = buttonNormalColor
	themeName.Active = true
	themeName.AutoButtonColor = true
end
function ThemeRow:AppliedToWorkspace()
	self.applied = true
	self.themeName.Font = Enum.Font.SourceSansBold
	self:updateName()
end
function ThemeRow:NotAppliedToWorkspace()
	self.applied = false
	self.themeName.Font = Enum.Font.SourceSans
	self:updateName()
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
	local function updateApplyButton()
		applyButton.Text = if currentTheme.Value == selectedTheme.Value
			then "Reapply to Workspace"
			else "Apply to Workspace"
	end
	local function selectTheme(newSelectedTheme)
		assert(newSelectedTheme, "newSelectedTheme must be provided")
		if internalSelectedTheme and internalSelectedTheme.Parent then
			folderToThemeData[internalSelectedTheme].Row:Deselect()
		end
		folderToThemeData[newSelectedTheme].Row:Select()
		internalSelectedTheme = newSelectedTheme
		selectedTheme.Value = newSelectedTheme
		updateApplyButton()
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
	for _, child in ipairs(editor:GetChildren()) do
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
		updateApplyButton()
	end
	updateCurrentTheme()
	local function setUIColors()
		themeTemplate.ThemeName.BackgroundColor3 = buttonNormalColor
		partTemplate.BackgroundColor3 = buttonNormalColor -- todo this is viewport; update (NOT buttonNormalColor)
		-- todo update all existing ui
		-- should we move this below the updateColors function? or move that function here?
	end
	setUIColors()
	-- local selectionChangedRecently
	cons = {
		handleVerticalScrollingFrame(themeScroll),
		handleVerticalScrollingFrame(partsScroll),
		currentTheme.Changed:Connect(function() task.spawn(updateCurrentTheme) end),
		widgetFrame.ThemesFrame.NewThemeButton.MouseButton1Click:Connect(function()
			undoable("New Theme", function()
				local newTheme
				local created
				local themeToUse = getInternalSelectedTheme() or getSelectedTheme(function() created = true end)
				if not created then
					newTheme = themeToUse:Clone()
					local _, _, baseName, num = newTheme.Name:find("^(.-)%s*%((%d+)%)%s*$")
					baseName = baseName or newTheme.Name
					num = num and tonumber(num) or 1
					for _, theme in ipairs(editor:GetChildren()) do
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
			end)
		end),
		editor.ChildAdded:Connect(onEditorChildAdded),
		applyButton.MouseButton1Click:Connect(function()
			local theme = getInternalSelectedTheme()
			if theme then
				matchWorkspaceToTheme(theme)
			else -- todo disable button when internalSelectedTheme is nil or becomes invalid (deparented)
				log("Please select a theme to apply!")
			end
		end),
		Studio.ThemeChanged:Connect(function()
			updateColors()
			setUIColors()
		end),
		-- Selection.SelectionChanged:Connect(function()
		-- 	if selectionChangedRecently then return end
		-- 	selectionChangedRecently = true
		-- 	-- conditions we care about:
		-- 	-- a theme must be selected
		-- 	-- 1+ part selected not in selected theme that is in the workspace
		-- 	--
		-- 	task.defer(function()
		-- 		selectionChangedRecently = false
		-- 		for _, v in ipairs(Selection:Get()) do
		-- 			-- conditions
		-- 		end
		-- 	end)
		-- end),
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