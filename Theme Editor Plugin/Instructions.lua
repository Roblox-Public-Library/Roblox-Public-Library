--[[
local default = game.ServerStorage["Theme Editor"].Default:GetChildren()
for i, part in ipairs(default) do
	default[part.Name] = part
end

local nameToPartList = {}
local babies = workspace:GetDescendants()
for i, child in ipairs(babies) do
	if child:IsA("BasePart") then
		local name = child.Name
		if default[name] then
			if not nameToPartList[name] then
				nameToPartList[name] = {child}
			else
				table.insert(nameToPartList[name], child)
			end
		end
	end
end
-- see if all parts in workspace with same name have same color and material values
local props = {"Material", "Color", "Transparency", "Reflectance"}
for name, list in pairs(nameToPartList) do
	local mismatch
	for _, prop in ipairs(props) do
		for i = 1, #list - 1 do
			if list[i][prop] ~= list[i + 1][prop] then
				print(("Not all %s.%s are the same"):format(name, prop))
				print("\t", list[i]:GetFullName(), list[i][prop])
				print("\t", list[i + 1]:GetFullName(), list[i + 1][prop])
				mismatch = true
			end
		end
	end
	if not mismatch then
		for _, prop in ipairs(props) do
			default[name][prop] = list[1][prop]
		end
		print(name .. " all good B)")
	end
end

game.ServerStorage["Theme Editor"]["Current Theme"].Value = game.ServerStorage["Theme Editor"].Default
]]