local Input = script.Input
local Combination = require(Input.Combination)

local ChangeHistory = game:GetService("ChangeHistoryService")
local UserInputService = game:GetService("UserInputService")
local ToolBar = plugin:CreateToolbar("Book Writer")

local PluginParent = script.Parent
local PluginGui = PluginParent.BookWriterGui
local Back = PluginGui.Back

local Content = Back.Content
local Top = Back.Top
local mouse

local button
pcall(function()
button = ToolBar:CreateButton(
	"Open", -- buttonId
	"", -- tooltip
	"" -- iconname
	-- text
)
end)

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
	--TextColor = ToggleActionControl.new(Top.TextColorButton),
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

if button then -- todo this is temporary
button.Click:Connect(toggleOpen)
end
plugin.Unloading:Connect(function()
	if open then toggleOpen() end -- cleans up connections
end)

--[[Keyboard input
So long as we make sure a TextBox is always active, all characters that are meant to be typed will be entered into the TextBox. However, we must monitor the input for shortcut commands, like ctrl+b - and we must use GetStringForKeyCode to determine if they pressed "b" or something else. (Possibly, we should try all reasonable keycodes and if none give back "B" then we can revert to using KeyCode.B)
Shortcut commands include:
	- Ctrl+x/c: we must save what is selected (including formatting). If any text is actually selected in the focused TextBox, also save this as "what's on the system clipboard"
	- Ctrl+v: if what is pasted in is identical to "what's on the system clipboard" (or if nothing was pasted in), delete what was added in and then paste in what we have saved. Otherwise, let the system paste persist. If we don't know what might be on the system clipboard (ex because the user copied an image or table), do a custom paste.
	- If they type in any navigation keys, we must redo whatever Roblox did (if anything):
		- Roblox ignores Shift+Numpad7 (this should be interpreted as "Home"), along with the other Shift+Numpad commands
		- Roblox doesn't know how to perform "End" correctly if there are special characters involved
		- If we have several TextBoxes on the same line, or if the user is holding down other modifier keys (like ctrl+home or ctrl+shift+home) then we have to handle that
		- If shift is being held down (ignoring shift+numpad commands), we should ensure that things are getting selected (Roblox doesn't support this except through the mouse clicking & dragging - if you select something and press shift+left/right, Roblox will cancel the selection without moving the text cursor)
	- While the user is holding Alt, we should remove any text that was entered on InputBegan (Roblox doesn't filter it out - it filters out Ctrl+typing, however). Altcodes are inserted when the user releases Alt; these should be kept.
	Neat: We can support Ctrl+s and, so long as a TextBox has focus, Roblox won't try to save the place (meaning we can use this to save the book!)
We also need to support clicking & dragging to select the text in multiple lines.

If Alt or other non-shift modifiers are being held down, we ignore characters added on InputBegan.
For characters added into the active TextBox when no non-shift modifiers are held down:
	- If it was a newline or a tab, delete it and process it properly (ex for tabs, it might insert a newline, but shift+tab should remove the indent on the current line/unindent list items/navigate to the previous cell in tables, and tab on its own may also have special behaviour)
	- Otherwise the character is allowed, assuming there isn't a multi-step command active (like "ctrl+i,j" - if the user can let go of 'ctrl' after pressing 'i', then we'd have to potentially deal with that here)
	- If any text was selected, it must all be deleted (note that it would already be deleted in the active TextBox).
If other modifiers are being held down, we can check the commands to see if their particular combination is bound to anything. Roblox gives us a KeyCode, we transform it with GetStringForKeyCode, and see if any commands use that string with the combination of modifiers that are held down.

Note: to ensure that Ctrl+b is the same shortcut regardless of layout, we must store the binding as Ctrl+"B" without using KeyCodes.
]]
local KeyCode = Enum.KeyCode

local actions = {} -- actions[Combination][letter from GetStringForKeyCode or KeyCode] -> function()
for i = 0, 15 do actions[i] = {} end

local numsInEnglish = {[0] = "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"}
-- for i = 0, 9 do

local shiftNumpad = {} do -- KeyCode -> what KeyCode should be used if shift is being pressed. This table is only for Numpad keys, where holding shift triggers a special ability while acting like shift isn't being pressed down
	local t = {}
	t["1"] = "End"
	t["2"] = "Down"
	t["3"] = "PageDown"
	t["4"] = "Left"
	t["5"] = "Unknown" -- use Unknown to ignore (shift+numpad 5 does nothing normally)
	t["6"] = "Right"
	t["7"] = "Home"
	t["8"] = "Up"
	t["9"] = "PageUp"
	t["0"] = "Insert"
	t["."] = "Delete"
	for k, v in pairs(t) do
		shiftNumpad[KeyCode["Keypad" .. (numsInEnglish[tonumber(k)] or "Period")]] = KeyCode[v]
	end
end
-- local isKeyCodeNumpad = {}
-- for _, name in ipairs({"Enter", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Period", "Divide", "Multiply", "Minus", "Plus", "Enter", "Equals"}) do
-- 	isKeyCodeNumpad[KeyCode["Keypad" .. name]] = true
-- end
local keyCodeToModifiers = {}
for _, name in ipairs({"Shift", "Control", "Meta", "Super", "Alt"}) do
	keyCodeToModifiers[KeyCode["Left" .. name]] = name
	keyCodeToModifiers[KeyCode["Right" .. name]] = name
end

local box = Content.TextBox
box.Text = ""
local template = box:Clone()

local function applyFormattingTo(formatting, obj)
	obj.Font = formatting.Bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans
end

local function load(segments)
	for _, segment in ipairs(segments) do
		-- normally would check to see what type it is (or ideally use a polymorphic function)
		local text, formatting = segment[1], segment[2]
		-- create new textbox I guess
		local box = template:Clone()
		box.Text = text -- note: this won't work because we need to handle newlines (natural and explicit)
		applyFormattingTo(formatting, box)
		box.Parent = Content -- should sometimes be Row
	end
end

local normal, bold = {}, {Bold=true}
local segments = {{"some ", normal}, {"bold", bold}, {" text\nline2", normal}}
load(segments)

--local boxes = DoublyLinkedList.new()
local first = {
	TextBox = box,
	Format = formatting,
	-- next/prev?
}
--boxes:Append(box)
local active
local function setActive(new)
	if active then
		-- disconnect?
	end
	active = new
	if active then
		local prevText = active.Text
		local prevCursorPos, curCursorPos = active.CursorPosition, active.CursorPosition
		local prevSelectionStart, curSelectionStart = active.SelectionStart, active.SelectionStart
		active:GetPropertyChangedSignal("CursorPosition"):Connect(function()
			prevCursorPos = curCursorPos
			curCursorPos = active.CursorPosition
			print("CursorPosition changed", prevCursorPos, curCursorPos)
		end)
		active:GetPropertyChangedSignal("SelectionStart"):Connect(function()
			prevSelectionStart = curSelectionStart
			curSelectionStart = active.SelectionStart
			print("SelectionStart changed", prevSelectionStart, curSelectionStart)
		end)
		active:GetPropertyChangedSignal("Text"):Connect(function()
			-- For ctrl+v, certain other commands, and history purposes, we want to know what was inserted/removed
			if prevSelectionStart ~= -1 then -- replace occurred
				print("Replaced", prevText:sub(math.min(prevCursorPos, prevSelectionStart), math.max(prevCursorPos, prevSelectionStart) - 1), "with", active.Text:sub(math.min(prevCursorPos, prevSelectionStart), active.CursorPosition - 1))
			elseif #active.Text > #prevText then
				print("Added", active.Text:sub(prevCursorPos, active.CursorPosition - 1))
			elseif prevCursorPos == active.CursorPosition then
				print("Deleted", prevText:sub(prevCursorPos, prevCursorPos + #prevText - #active.Text - 1))
			else
				print("Backspaced", prevText:sub(active.CursorPosition, prevCursorPos - 1))
			end
			prevText = active.Text
			prevCursorPos = active.CursorPosition
			prevSelectionStart = active.SelectionStart
		end)
		-- active.InputBegan:Connect(function(input)
		-- 	if input ~= Enum.UserInputType.Keyboard then return end

		-- end)
	end
end
setActive(box)

local function splitAtCursor()
	-- 1. determine if this is the 2nd line in the textbox. If so, move all lines before this one to their own textbox.
--[[REALIZATION
Every time resolution changes, all textboxes will be changing their content
so is it easier to ask for a complete redo every time?
can that algorithm determine the differences as it goes along?
Say the document is:
{"some ", normal}, {"bold", bold}, {" text\nline2", normal}
To load this
	create a new TextBox for each
		for the \n, we must also split that
	activate the last one

question is can we just modify the doc & reload after every input
	well we certainly can't reload the entire document if it's a large multi-page one
	we could reload since the last page break but that's no good if it's a huge chapter

]]
end

actions[Combination.None][Enum.KeyCode.Backspace] = function()
	if active.CursorPosition == 1 then
		-- todo if there's a highlight, just delete the highlight contents
		-- else if there is a textbox before this one, make it active and perform backspace
		--	if this textbox is empty, delete it
	end
end
actions[Combination.Ctrl]["B"] = function()
	-- todo add a new textbox with proper formatting
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local keyCode = input.KeyCode
		if keyCodeToModifiers[keyCode] then
			print("Modifier detected", keyCode)
			return
		end
		local key = UserInputService:GetStringForKeyCode(keyCode) -- support alternate keyboard layouts
		local name -- todo I want to try using name of KeyCode so actions can always be "*", "PageDown", "A", etc. (code below needs checking/updating.)
		-- If this is shift+Numpad, effective key is sometimes different and shift is ignored in command consideration
		local ignoreShift
		if shiftNumpad[key] and isKeyCodeNumpad[keyCode] and input:IsModifierKeyDown(Enum.Modifier.Shift) then
			keyCode = shiftNumpad[key] or keyCode
			key = nil
			ignoreShift = true
		end
		local combination = Combination.FromInput(input, ignoreShift)
		local action = actions[combination][key ~= "" and key or keyCode]
		if action then
			action()
		-- 	print("Handled", input.KeyCode, "|", key)
		-- else
		-- 	print("Unhandled", input.KeyCode, "|", key)
		end
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

end)
UserInputService.InputEnded:Connect(function(input)
	
end)

toggleOpen()