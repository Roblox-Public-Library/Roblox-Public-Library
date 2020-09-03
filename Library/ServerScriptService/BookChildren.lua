-- Book Children
local data = {
	-- Name defaults to Type
	-- Old = true means it's an old child that should no longer be included at all (only Name needs to be kept with these entries)
	{Type = "ClickDetector"},
	{Type = "Decal", Name = "Cover", Props = {Color3 = Color3.new(1, 1, 1), Texture = "http://www.roblox.com/asset/?id=131591224", Transparency = 0.5, Face = Enum.SurfaceId.Top}},
	{Type = "Decal", Name = "Pages", Props = {Color3 = Color3.new(1, 1, 1), Texture = "http://www.roblox.com/asset/?id=131591224", Transparency = 0, Face = Enum.SurfaceId.Front}},
	{Old = true, Name = "BookClick"}
}
local dataToAdd = {}
for _, data in ipairs(data) do
	if not data.Old then
		dataToAdd[#dataToAdd + 1] = data
	end
end
local module = {}
module.Data = data
function module.RemoveFrom(book)
	--	Returns true if anything removed from book
	local found = false
	for _, data in ipairs(data) do
		local c = book:FindFirstChild(data.Name or data.Type)
		if c then
			c:Destroy()
			found = true
		end
	end
	return found
end
function module.AddTo(book)
	for _, data in ipairs(dataToAdd) do
		if not book:FindFirstChild(data.Name or data.Type) then
			local obj = Instance.new(data.Type)
			if data.Name then obj.Name = data.Name end
			for k, v in pairs(data.Props) do
				obj[k] = v
			end
			obj.Parent = book
		end
	end
end
function module.UpdateGuis(book, title)
	local titleColor = book.TitleColor.Value
	local titleOutlineColor = book.TitleOutlineColor.Value
	for _, obj in ipairs({book.BookNameFront.BookName, book.BookNameSide.BookName}) do
		obj.Text = title
		obj.TextColor3 = titleColor
		obj.TextStrokeColor3 = titleOutlineColor
	end
end
return module