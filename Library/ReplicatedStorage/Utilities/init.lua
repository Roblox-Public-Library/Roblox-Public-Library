local Utilities = require(script.Utilities)
for _, child in ipairs(script:GetChildren()) do
	Utilities[child.Name] = require(child)
end
return Utilities