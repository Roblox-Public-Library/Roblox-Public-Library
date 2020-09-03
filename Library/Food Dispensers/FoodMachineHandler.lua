local tweenDuration = 0.7
local resetAvailAfter = 30
local module = {}
function module:Add(machine, selection1Name, selection2Name, origModel, origTool, instruction1, instruction2, handleSelection1, handleSelection2)
	local screen = machine.Screen
	local frame = screen.SurfaceGui.Frame
	local clicker = screen.ClickDetector
	local maxActivationDistance = clicker.MaxActivationDistance
	local flavor = screen.FlavorSound
	local storage = machine.Storage
	local status = frame.Status

	local selection1 = frame[selection1Name]
	local selection2 = frame[selection2Name]
	local selection1OrigPos = selection1.Position
	local selection2OrigPos = selection2.Position
	origTool.Parent = script

	local inUseTime
	frame.Reset.Visible = false
	local cons
	local function resetCons()
		for i = 1, #cons do cons[i]:Disconnect() end
	end
	local eventNum = 0
	local function resetCommon()
		status.Text = ""
		frame.Entry.Visible = true
		clicker.MaxActivationDistance = maxActivationDistance
		inUseTime = nil
		eventNum = eventNum + 1
		frame.Reset.Visible = false
	end
	local ice
	local origStyle1 = selection1:FindFirstChildWhichIsA("TextButton", true).Style
	local origStyle2 = selection2:FindFirstChildWhichIsA("TextButton", true).Style
	clicker.MouseClick:Connect(function(player)
		if inUseTime then return end
		inUseTime = tick()
		clicker.MaxActivationDistance = 0
		frame.Entry.Visible = false
		ice = origModel:Clone()
		ice.Parent = storage
		status.Text = instruction1
		selection1:TweenPosition(UDim2.new(0, 0, 0, 0), "In", "Quint", tweenDuration, true)
		wait(tweenDuration)
		cons = {}
		for _, one in ipairs(selection1:GetChildren()) do
			if one:IsA("TextButton") then
				cons[#cons + 1] = one.MouseButton1Down:Connect(function()
					resetCons()
					handleSelection1(ice, one)
					status.Text = instruction2
					flavor:Play()
					one.Style = Enum.ButtonStyle.RobloxRoundDefaultButton
					selection1:TweenPosition(selection1OrigPos, "In", "Quint", tweenDuration, true)
					wait(tweenDuration)
					one.Style = origStyle1
					selection2:TweenPosition(UDim2.new(0, 0, 0, 0), "In", "Quint", tweenDuration, true)
					cons = {}
					for _, two in ipairs(selection2:GetChildren()) do
						if two:IsA("TextButton") then
							cons[#cons + 1] = two.MouseButton1Down:Connect(function()
								resetCons()
								handleSelection2(ice, two)
								status.Text = "Enjoy!"
								local tool = origTool:Clone()
								tool.Name = ("%s %s %s"):format(one.Text, two.Text, origTool.Name)
								tool.ToolTip = tool.Name
								local handl = storage.Handle:Clone()
								handl.Parent = tool
								for _, four in ipairs(ice:GetChildren()) do
									four.Parent = tool
								end
								ice:Destroy()
								tool.Parent = player.Backpack
								tool.Weld.Disabled = false
								tool.LocalScript.Disabled = false
								flavor:Play()
								two.Style = Enum.ButtonStyle.RobloxRoundDefaultButton
								selection2:TweenPosition(selection2OrigPos, "In", "Quint", tweenDuration, true)
								wait(tweenDuration)
								two.Style = origStyle2
								resetCommon()
							end)
						end
					end
				end)
			end
		end
		eventNum = eventNum + 1
		local num = eventNum
		wait(resetAvailAfter)
		if num == eventNum then
			frame.Reset.Visible = true
		end
	end)

	frame.Reset.MouseButton1Down:Connect(function()
		if inUseTime and tick() - inUseTime >= resetAvailAfter then
			resetCons()
			resetCommon()
			selection1:TweenPosition(selection1OrigPos, "In", "Quint", tweenDuration, true)
			selection2:TweenPosition(selection2OrigPos, "In", "Quint", tweenDuration, true)
			if ice then
				ice:Destroy()
			end
		end
	end)
end
return module