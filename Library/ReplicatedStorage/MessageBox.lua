local MessageBox = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShowMsgGui = Instance.new("RemoteEvent")
ShowMsgGui.Name = "ShowMsgGui"
ShowMsgGui.Parent = ReplicatedStorage

local HideMsgGui = Instance.new("RemoteEvent")
HideMsgGui.Name = "HideMsgGui"
HideMsgGui.Parent = ReplicatedStorage

local MsgGuiLButton = Instance.new("RemoteEvent")
MsgGuiLButton.Name = "MsgGuiLButton"
MsgGuiLButton.Parent = ReplicatedStorage

local MsgGuiRButton = Instance.new("RemoteEvent")
MsgGuiRButton.Name = "MsgGuiRButton"
MsgGuiRButton.Parent = ReplicatedStorage


function MessageBox.ShowMsg(player, prompt, leftText, rightText)
	ShowMsgGui:FireClient(player, prompt, leftText, rightText)
end

function MessageBox.HideMsg(player)
	HideMsgGui:FireClient(player)
end

return MessageBox
