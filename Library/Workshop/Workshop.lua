for _, folder in ipairs(script:GetChildren()) do
	local service = game:GetService(folder.Name)
	for _, child in ipairs(folder:GetChildren()) do
		child.Parent = service
	end
end