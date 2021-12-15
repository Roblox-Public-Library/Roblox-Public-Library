local function disconnectList(list)
	for _, con in ipairs(list) do
		con:Disconnect()
	end
end

local ThemePartsData = {}
ThemePartsData.__index = ThemePartsData
function ThemePartsData.new(folder)
	--	Manages parts within a theme; you can add parts to it with duplicate/non unique (in name) parts not being added
	local nameToPart = {}
	local self
	local function registerObjIfPart(obj)
		if obj:IsA("BasePart") then
			self:registerPart(obj)
		end
	end
	local function unregisterObjIfPart(obj)
		if obj:IsA("BasePart") then
			self:unregisterPart(obj)
		end
	end
	self = setmetatable({
		nameToPart = nameToPart, --[partName][part] = connection to part name being changed
		folder = folder,
		cons = {
			folder.DescendantAdded:Connect(registerObjIfPart),
			folder.DescendantRemoving:Connect(unregisterObjIfPart),
		},
		-- suppressNameChange = false,
	}, ThemePartsData)
	for _, obj in ipairs(folder:GetDescendants()) do
		registerObjIfPart(obj)
	end
	return self
end
function ThemePartsData:ContainsPartName(partName)
	return self.nameToPart[partName]
end
function ThemePartsData:registerPart(part)
	local nameToPart, name = self.nameToPart, part.Name
	if not nameToPart[name] then
		nameToPart[name] = {}
	end
	local con
	con = part:GetPropertyChangedSignal("Name"):Connect(function()
		if self.suppressNameChange then
			name = part.Name
			return
		end
		nameToPart[name][part] = nil
		if not next(nameToPart[name]) then
			nameToPart[name] = nil
		end
		name = part.Name
		if not nameToPart[name] then
			nameToPart[name] = {}
		end
		nameToPart[name][part] = con
	end)
	nameToPart[name][part] = con
end
function ThemePartsData:unregisterPart(part)
	local nameToPart, name = self.nameToPart, part.Name
	nameToPart[name][part]:Disconnect()
	nameToPart[name][part] = nil
	if not next(nameToPart[name]) then
		nameToPart[name] = nil
	end
end
function ThemePartsData:AddPart(part)
	self:registerPart(part)
	local newPart = part:Clone()
	newPart.Parent = self.folder
end
function ThemePartsData:AddPartIfUnique(part)
	if not self:ContainsPartName(part.Name) then
		self:AddPart(part)
		return true
	end
end
function ThemePartsData:RenamePart(oldName, newName)
	if self:ContainsPartName(oldName) then
		local nameToPart = self.nameToPart
		local parts = nameToPart[oldName]
		nameToPart[newName] = parts
		nameToPart[oldName] = nil
		self.suppressNameChange = true
		for part in pairs(parts) do
			part.Name = newName
		end
		self.suppressNameChange = false
		return true
	end
end
function ThemePartsData:Destroy()
	disconnectList(self.cons)
	for _, partSet in pairs(self.nameToPart) do
		for _, con in pairs(partSet) do
			con:Disconnect()
		end
	end
end
return ThemePartsData