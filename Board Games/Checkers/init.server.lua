local StarterPlayer = game:GetService("StarterPlayer")
local special = {
	StarterPlayerScripts = StarterPlayer.StarterPlayerScripts,
	StarterCharacterScripts = StarterPlayer.StarterCharacterScripts,
}
for _, folder in ipairs(script:GetChildren()) do
	local dest = special[folder.Name] or game[folder.Name]
	for _, c in ipairs(folder:GetChildren()) do
		if not dest:FindFirstChild(c.Name) then
			c.Parent = dest
		end
	end
end