local function changeScript(s)
    s.Source = s.Source:gsub(':WaitForChild%("([^"]+)"%)', '.%1')
end
for _, c in ipairs(workspace:GetDescendants()) do
	if c:IsA("Script") and c.Name:find("BookEventScript") then
		changeScript(c)
	end
end