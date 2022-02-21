local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MessageBox = require(ReplicatedStorage.Library.MessageBox)
local profile = require(ReplicatedStorage.Library.ProfileClient)
local tutorial = profile.Tutorial

if not tutorial.firstTimeFaq then
	local leftArrow = Instance.new("ImageLabel")
	leftArrow.Image = "rbxassetid://3926305904"
	leftArrow.ImageColor3 = Color3.new(1, 1, 0)
	leftArrow.ImageRectOffset = Vector2.new(521, 761)
	leftArrow.ImageRectSize = Vector2.new(42, 42)
	leftArrow.ScaleType = Enum.ScaleType.Fit
	leftArrow.BackgroundTransparency = 1
	leftArrow.Size = UDim2.new(0, 42, 0, 42)
	leftArrow.Position = UDim2.new(0.5, 0, 0.5, 0)
	local rightArrow = leftArrow:Clone()
	leftArrow.AnchorPoint = Vector2.new(1, 0)
	leftArrow.Rotation = 45
	rightArrow.Rotation = -45
	local parent = game:GetService("Players").LocalPlayer.PlayerGui:WaitForChild("TopBar").Left.About
	leftArrow.Parent, rightArrow.Parent = parent, parent
	-- Animate arrows until player dismisses message
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 0)
	local leftArrowTween = TweenService:Create(leftArrow, tweenInfo, {Position = UDim2.new(0, 0, 1, 0)})
	local rightArrowTween = TweenService:Create(rightArrow, tweenInfo, {Position = UDim2.new(1, 0, 1, 0)})
	leftArrowTween:Play()
	rightArrowTween:Play()
	MessageBox.Notify("Click on the ? in the top bar to view the frequently asked questions, controls, and more!")
	leftArrowTween:Cancel()
	rightArrowTween:Cancel()
	leftArrow:Destroy()
	rightArrow:Destroy()
	ReplicatedStorage.Remotes.Tutorial:FireServer("firstTimeFaq")
end