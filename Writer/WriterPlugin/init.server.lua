local ChangeHistory = game:GetService("ChangeHistoryService")
local ToolBar = plugin:CreateToolbar("Book Writer")

local PluginParent = script.Parent
local PluginGui = PluginParent.BookWriterGui
local Back = PluginGui.Back

local Content = Back.Content
local Top = Back.Top
local mouse

local button = ToolBar:CreateButton(
	"Open", -- buttonId
	"", -- tooltip
	"" -- iconname
	-- text
)

--local PluginGuiService = game:GetService("PluginGuiService") -- we can dock Widgets here, see: https://developer.roblox.com/en-us/api-reference/function/Plugin/CreateDockWidgetPluginGui
local CoreGui = game:GetService("CoreGui")
local Studio = settings().Studio
local StudioColor = Enum.StudioStyleGuideColor
local StudioModifier = Enum.StudioStyleGuideModifier


local SelectedHoverColors = {} do
	local cache = {}
	local theme
	local rgb = {"R", "G", "B"}
	function SelectedHoverColors:Get(studioColor)
		local color = cache[studioColor]
		if not color then
			local hover = theme:GetColor(studioColor, StudioModifier.Hover)
			local selected = theme:GetColor(studioColor, StudioModifier.Selected)
			local _, _, v1 = Color3.toHSV(hover)
			local h, s, v2 = Color3.toHSV(selected)
			local newV = v2 > v1 -- brightening
				--ex .8 > .6
				and 1 - (1 - v2) ^ 2 / (1 - v1)
				or v2 ^ 2 / v1
			color = Color3.fromHSV(h, s, math.clamp(newV, 0, 1))
		end
		return color
	end
	function SelectedHoverColors:Reset(newTheme)
		cache = {}
		theme = newTheme
	end
end

local ThemeColor = {} do
	local theme
	local modifiers = {}
	for _, prop in ipairs({"Selected", "Hover", "Default", "Pressed", "Disabled"}) do
		local enum = StudioModifier[prop]
		modifiers[prop] = function(studioColor) return theme:GetColor(studioColor, enum) end
	end
	modifiers.SelectedHover = function(studioColor) return SelectedHoverColors:Get(studioColor) end
	function ThemeColor:Get(studioColor, modifier)
		--	modifier:string (any name from StudioModifier or "SelectedHover"); defaults to "Default"
		local func = modifiers[modifier or "Default"] or error("Modifier must be a valid string; received: " .. tostring(modifier))
		return func(studioColor)
	end
	function ThemeColor:Reset(newTheme)
		theme = newTheme
		SelectedHoverColors:Reset(newTheme)
	end
end

--[[ActionControl Interface
	.Frame
	:UpdateUiColors (from Theme)
	(May want to replace the following with more generic :MakeConnections if InputActionControl wants mouse hover over just InputField)
	:MouseEnter()
	:MouseLeave()
	:MouseDown()
	:MouseClick()
]]

local ToggleActionControl = {}
ToggleActionControl.__index = ToggleActionControl
function ToggleActionControl.new(frame)
	return setmetatable({
		Frame = frame,
		TextButton = frame.TextButton,
		ImageLabel = frame.ImageLabel,
		Selected = false, -- ex if this is Bold, then true would mean the user wants bold
		-- todo create event for SelectedChanged
	}, ToggleActionControl)
end
function ToggleActionControl:UpdateUiColors()
	self.Frame.BackgroundColor3 = ThemeColor:Get(StudioColor.RibbonButton, self.Selected and "Selected" or "Default")
	self.ImageLabel.ImageColor3 = ThemeColor:Get(StudioColor.MainText)
end
function ToggleActionControl:MouseEnter()
	self.Frame.BackgroundColor3 = ThemeColor:Get(StudioColor.RibbonButton, self.Selected and "SelectedHover" or "Hover")
end
function ToggleActionControl:MouseLeave()
	self.Frame.BackgroundColor3 = ThemeColor:Get(StudioColor.RibbonButton, self.Selected and "Selected" or "Default")
end
function ToggleActionControl:MouseDown()
	self.Frame.BackgroundColor3 = ThemeColor:Get(StudioColor.RibbonButton, "Pressed")
end
function ToggleActionControl:MouseClick()
	self.Selected = not self.Selected
	-- todo trigger SelectedChanged
	self.Frame.BackgroundColor3 = ThemeColor:Get(StudioColor.RibbonButton, self.Selected and "SelectedHover" or "Hover")
end

local InputActionControl = {}
InputActionControl.__index = InputActionControl
function InputActionControl.new(frame)
	local inputField = frame.InputField
	local textBox = inputField.TextBox
	local self = setmetatable({
		Frame = frame,
		InputField = inputField,
		ImageButton = inputField.ImageButton,
		TextBox = textBox,
	}, InputActionControl)
	textBox.Focused:Connect(function()
		self:MouseClick()
	end)
	textBox.FocusLost:Connect(function()
		self:MouseLeave()
	end)
	return self
end
function InputActionControl:UpdateBackgroundColors(state) -- state is optional
	self.Frame.BackgroundColor3 = ThemeColor:Get(StudioColor.InputFieldBorder, state) -- was RibbonButton
	self.InputField.BackgroundColor3 = ThemeColor:Get(StudioColor.InputFieldBackground, state)
end
function InputActionControl:UpdateUiColors()
	self:UpdateBackgroundColors()
	self.ImageButton.ImageColor3 = ThemeColor:Get(StudioColor.MainText)
	self.TextBox.TextColor3 = ThemeColor:Get(StudioColor.MainText)
end
function InputActionControl:MouseEnter()
	self:UpdateBackgroundColors("Hover")
end
function InputActionControl:MouseLeave()
	self:UpdateBackgroundColors("Default")
end
function InputActionControl:MouseDown()
	self:UpdateBackgroundColors("Pressed")
end
function InputActionControl:MouseClick()
	self:UpdateBackgroundColors("Default")
end

local controls = {
	Alignment = ToggleActionControl.new(Top.AlignmentButton),
	Bold = ToggleActionControl.new(Top.BoldButton),
	Font = InputActionControl.new(Top.Font),
	FontSize = InputActionControl.new(Top.FontSize),
	Image = ToggleActionControl.new(Top.ImageButton),
	Italic = ToggleActionControl.new(Top.ItalicButton),
	TextColor = ToggleActionControl.new(Top.TextColorButton),
	Underline = ToggleActionControl.new(Top.UnderlineButton),
}

local function updateUiColors()
	ThemeColor:Reset(Studio.Theme)
	
	Back.BackgroundColor3 = ThemeColor:Get(StudioColor.ScriptWhitespace)
	Content.BackgroundColor3 = ThemeColor:Get(StudioColor.InputFieldBackground)
	Top.BackgroundColor3 = ThemeColor:Get(StudioColor.RibbonButton)

	for _, control in pairs(controls) do
		control:UpdateUiColors()
	end
end

local function makeConnections()
	local mouseTarget
	local mouseControlTarget
	local mouseDownControlTarget -- don't trigger MouseClick unless mouse started on this control when click occurred and hasn't left since
	local connections = {}
	local n = 0
	for _, control in pairs(controls) do
		local frame = control.Frame
		connections[n + 1] = frame.MouseEnter:Connect(function()
			control:MouseEnter()
			mouseTarget = frame
			mouseControlTarget = control
		end)
		connections[n + 2] = frame.MouseLeave:Connect(function()
			control:MouseLeave()
			mouseDownControlTarget = nil
			if mouseTarget == frame then
				mouseTarget = nil
				mouseControlTarget = nil
			end
		end)
		n = n + 2
	end
	mouse.Button1Down:Connect(function()
		if mouseControlTarget then
			mouseDownControlTarget = mouseControlTarget
			mouseControlTarget:MouseDown()
		end
	end)
	mouse.Button1Up:Connect(function()
		if mouseDownControlTarget then
			mouseDownControlTarget:MouseClick()
		end
	end)
	return connections
end

local function disconnectConnections(connections)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
end

local connections = {}
local themeChangedConnection
local open = false
local function toggleOpen()
	open = not open
	PluginGui.Parent = open and CoreGui or PluginParent
	
	if open then
		plugin:Activate(true)
		mouse = plugin:GetMouse()
		updateUiColors()
		themeChangedConnection = Studio.ThemeChanged:Connect(updateUiColors)
		connections = makeConnections()
	else
		plugin:Deactivate()
		themeChangedConnection:Disconnect()
		disconnectConnections(connections)
	end
end

button.Click:Connect(toggleOpen)
plugin.Unloading:Connect(function()
	if open then toggleOpen() end -- cleans up connections
end)

-- local box = Content.Row.TextBox
-- box:GetPropertyChangedSignal("Text"):Connect(function()
-- end)
-- box.InputBegan:Connect(function(input)
-- 	if input.UserInputType == Enum.UserInputType.Keyboard then
-- 		print(input.KeyCode)
-- 	end
-- end)