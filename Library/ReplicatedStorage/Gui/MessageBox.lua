local MessageBox = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local screenGui = ReplicatedStorage.Guis.MessageBoxGui
screenGui.Enabled = false
screenGui.Parent = game:GetService("Players").LocalPlayer.PlayerGui
local messageFrame = screenGui.MessageFrame
messageFrame.Visible = true
local buttons = messageFrame.Buttons
local yesBtn, noBtn = buttons.First, buttons.Second
local contentLabel = messageFrame.ScrollingFrame.TextLabel
local catchClick = screenGui.CatchClick
local messageShowing = false
local event = Instance.new("BindableEvent")

function MessageBox.Show(prompt, confirmText, cancelText)
	--	Show the message box (cancelling any previously open messages), waiting until a response is received.
	--	Will display two options to the player (by default "Yes" and "No")
	--	Will return true only if the player presses "Yes"
	--	The player can also click outside the message box to cancel it
	if messageShowing then
		event:Fire(false)
	end
	contentLabel.Text = prompt
	yesBtn.Text = confirmText or "Yes"
	noBtn.Text = cancelText or "No"
	noBtn.Visible = true
	messageShowing = true
	screenGui.Enabled = true
	local response = event.Event:Wait()
	screenGui.Enabled = false
	messageShowing = false
	return response
end

function MessageBox.Notify(prompt, closeText, preventOutsideClick)
	--	Same as MessageBox.Show, except only one option is displayed to the user.
	--	They can still cancel it by clicking outside the message box.
	if messageShowing then
		event:Fire(false)
	end
	contentLabel.Text = prompt
	yesBtn.Text = closeText or "Okay!"
	noBtn.Visible = false
	messageShowing = true
	screenGui.Enabled = true
	local response
	repeat
		response = event.Event:Wait()
	until response or not preventOutsideClick
	screenGui.Enabled = false
	messageShowing = false
	return response
end

local function cancel()
	event:Fire(false)
end
MessageBox.Close = cancel -- Close any currently open message box, cancelling it

yesBtn.Activated:Connect(function()
	event:Fire(true)
end)
noBtn.Activated:Connect(cancel)
catchClick.Activated:Connect(cancel)

-- Make text bold when mouse hovers over
for _, button in ipairs(buttons:GetChildren()) do
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