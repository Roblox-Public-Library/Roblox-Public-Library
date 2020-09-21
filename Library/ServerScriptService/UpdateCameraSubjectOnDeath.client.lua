local model = script.Parent
local newHead = model.Head
local head = model.Parent.Head
model.Parent.Humanoid.Died:Connect(function()
	if newHead.Parent then
		workspace.CurrentCamera.CameraSubject = newHead
	end
	-- Sometimes the face is regenerated when the character dies (Sept 2020)
	local face = head:FindFirstChild("face")
	if face then
		face:Destroy()
	end
end)