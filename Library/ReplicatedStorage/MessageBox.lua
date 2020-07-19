local MessageBox = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local screenGui = ReplicatedStorage.Guis.MessageBoxGui
screenGui.Parent = game:GetService("Players").LocalPlayer.PlayerGui
local messageFrame = screenGui.MessageFrame
local yesBtn = messageFrame.ButtonL
local noBtn = messageFrame.ButtonR
local fullScreenButton = screenGui.FullScreenButton
local msgShowing = false
local event = Instance.new("BindableEvent")

function MessageBox.Show(prompt, confirmText, cancelText)
	--	Will show the user 'prompt' and yield until they confirm/cancel or until MessageBox.Show is called again (this counts as cancelling)
	--	Will return true if they confirmed (false otherwise)
	if msgShowing then
		event:Fire(false)
	end
	messageFrame.TextLabel.Text = prompt
	yesBtn.Text = confirmText or "Yes"
	noBtn.Text = cancelText or "No"
	msgShowing = true
	screenGui.Enabled = true
	local response = event.Event:Wait()
	screenGui.Enabled = false
	msgShowing = false
	return response
end
local function cancel()
	event:Fire(false)
end
MessageBox.Close = cancel

yesBtn.Activated:Connect(function()
	event:Fire(true)
end)
noBtn.Activated:Connect(cancel)
fullScreenButton.Activated:Connect(cancel)

-- Make text bold when mouse hovers over
for _, button in ipairs(messageFrame:GetChildren()) do
	if button:IsA("TextButton") then
        button.MouseEnter:Connect(function()
			button.Font = "SourceSansBold"
		end)
		button.MouseLeave:Connect(function()
			button.Font = "SourceSans"
		end)
	end
end
return MessageBox