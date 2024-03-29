local function destroyIfExists(obj)
	if obj then
		obj:Destroy()
	end
end
destroyIfExists(game:GetService("StarterPack"):FindFirstChild("SelectScript"))
local StarterGui = game:GetService("StarterGui")
for _, folder in ipairs(script:GetChildren()) do
	local service = if folder.Name:find("Starter.*Scripts") then game:GetService("StarterPlayer"):FindFirstChildOfClass(folder.Name)
		else game:GetService(folder.Name)
	for _, child in ipairs(folder:GetChildren()) do
		destroyIfExists(service:FindFirstChild(child.Name))
		child.Parent = service
	end
end