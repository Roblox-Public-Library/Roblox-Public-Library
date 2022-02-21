local UserInputService = game:GetService("UserInputService")
local localPlayer = game:GetService("Players").LocalPlayer

local humanoid
local isRunning = false
local function setIsRunning(value)
	isRunning = value
	if humanoid then
		humanoid.WalkSpeed = isRunning and 32 or 16
	end
end
local runGui = localPlayer:WaitForChild("PlayerGui"):WaitForChild("RunGui")
local button -- button in runGui (nil if touch controls are not enabled)
if UserInputService.TouchEnabled then
	runGui.Enabled = true
	local base = setIsRunning
	button = runGui:WaitForChild("Button")
	setIsRunning = function(value)
		base(value)
		button.Font = value and Enum.Font.SourceSansItalic or Enum.Font.SourceSans
		button.BackgroundColor3 = value and Color3.new(.3, .3, .3) or Color3.new(.1, .1, .1)
	end
	-- Set it up so that the use of a keyboard or gamepad will make the touch controls invisible
	local nonTouchTypes = {
		[Enum.UserInputType.Keyboard] = true
	}
	for i = 1, 8 do
		nonTouchTypes[Enum.UserInputType["Gamepad" .. i]] = true
	end
	local function inputTypeChanged(inputType)
		if nonTouchTypes[inputType] then
			runGui.Enabled = false
		elseif inputType == Enum.UserInputType.Touch then
			runGui.Enabled = true
		end
	end
	UserInputService.LastInputTypeChanged:Connect(inputTypeChanged)
	inputTypeChanged(UserInputService:GetLastInputType())
else
	runGui:Destroy()
	runGui = nil
end
local function toggleRun()
	setIsRunning(not isRunning)
end
local function startRun() setIsRunning(true) end
local function endRun() setIsRunning(false) end

local controlsNeedInit = true
local function setupControls()
	controlsNeedInit = false
	local beganControls = {
		[Enum.KeyCode.LeftControl] = toggleRun,
		[Enum.KeyCode.RightControl] = toggleRun,
		[Enum.KeyCode.LeftShift] = startRun,
		[Enum.KeyCode.RightShift] = startRun,
		[Enum.KeyCode.ButtonX] = startRun,
		[Enum.KeyCode.ButtonY] = toggleRun,
	}
	local endedControls = {
		[Enum.KeyCode.LeftShift] = endRun,
		[Enum.KeyCode.RightShift] = endRun,
		[Enum.KeyCode.ButtonX] = endRun,
	}
	-- In case they have (or connect) a keyboard/gamepad:
	local keyWasProcessed = {}
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			keyWasProcessed[input.KeyCode] = true -- will be Unknown for non-keys
			return
		end
		local action = beganControls[input.KeyCode]
		if action then
			action()
		end
	end)
	UserInputService.InputEnded:Connect(function(input, processed)
		if processed or keyWasProcessed[input.KeyCode] then
			keyWasProcessed[input.KeyCode] = nil
			return
		end
		local action = endedControls[input.KeyCode]
		if action then
			action()
		end
	end)
	if button then
		button.Activated:Connect(toggleRun)
	end
end

local function charAdded(char)
	humanoid = char:WaitForChild("Humanoid")
	if controlsNeedInit then
		setupControls()
	end
	setIsRunning(false)
end
localPlayer.CharacterAdded:Connect(charAdded)
if localPlayer.Character then charAdded(localPlayer.Character) end