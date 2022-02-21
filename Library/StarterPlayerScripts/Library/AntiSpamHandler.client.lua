local ReplicatedStorage = game:GetService("ReplicatedStorage")
local antiSpamEvent = ReplicatedStorage.Remotes.AntiSpamEvent
local player = game:GetService("Players").LocalPlayer
local StarterGui = game:GetService("StarterGui")
local isMuted = false

antiSpamEvent.OnClientEvent:Connect(function(mute)
    isMuted = mute
    StarterGui:SetCore("ChatBarDisabled", mute)
    if isMuted then
        StarterGui:SetCore("ChatMakeSystemMessage", {
            Text = "You have been muted for spamming.",
            Color = Color3.new(255, 0, 0),
        })
    end
end)

player.CharacterAdded:Connect(function()
    if isMuted then
        StarterGui:SetCore("ChatBarDisabled", true)
    end
end)