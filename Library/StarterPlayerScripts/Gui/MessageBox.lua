local screenFrame = script.Parent.ScreenFrame
local messageFrame = screenFrame.MessageFrame
local yesBtn = messageFrame.ButtonL
local noBtn = messageFrame.ButtonR
local fullScreenButton = screenFrame.FullScreenButton

local replicatedStorage = game:GetService("ReplicatedStorage")
local TeleOpenGui = replicatedStorage.TeleOpenGui
local TeleGuiClosed = replicatedStorage.TeleGuiClosed

local placeId = 0

-- Show message(or change to new place)
TeleOpenGui.OnClientEvent:Connect(function(id, name)
	messageFrame.TextLabel.Text = "Teleport to "..name.."?"
	placeId = id
	screenFrame.Visible = true
end)

-- Teleport player
yesBtn.MouseButton1Click:Connect(function()
	game:GetService("TeleportService"):Teleport(placeId)
end)

-- Close GUI, inform server
local function closeGui()
	screenFrame.Visible = false
	TeleGuiClosed:FireServer()
end
noBtn.MouseButton1Click:Connect(closeGui) -- todo: .Activated works for all input types
fullScreenButton.MouseButton1Click:Connect(closeGui)

-- Make text bold when mouse hovers over
for _, button in pairs(messageFrame:GetChildren()) do
	if button:IsA("TextButton") then

        button.MouseEnter:Connect(function()
			button.Font = "SourceSansBold"
		end)
		button.MouseLeave:Connect(function()
			button.Font = "SourceSans"
		end)

	end
end