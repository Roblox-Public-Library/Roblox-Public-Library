local Config = {
	Props = {"Material", "Color", "Transparency", "Reflectance"},
}

local props = Config.Props
function Config.ArePartPropsDuplicate(a, b)
	for _, prop in ipairs(props) do
		if a[prop] ~= b[prop] then
			return false
		end
	end
	return true
end
return Config