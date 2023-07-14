local BookChildren = {}
function BookChildren.GetAttribute(scr, name) -- support either GetAttribute on the script or Value instances as a child of the book
	local value = scr:GetAttribute(name)
	if value then return value end
	value = scr.Parent:FindFirstChild(name)
	return value and value.Value
end
function BookChildren.GetBookScript(model)
	return model:FindFirstChild("BookScript") or model:FindFirstChildOfClass("Script")
end
return BookChildren