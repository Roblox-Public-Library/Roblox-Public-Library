local parent = script.Parent.Parent
local Config = require(parent.Config)
local Plugin = require(parent.PluginUtility.Plugin)
local log = Plugin.GenLog(script)
local undoable = Plugin.Undoable
local PropsSerializer = require(parent.PluginUtility.PropsSerializer)

local Selection = game:GetService("Selection")

local AddPartsWidget = {}

local seenBefore = {} -- [Instance] = true if we've seen this exact instance before
local partsList = {}  -- [name] = table with .Count and .NumToList and [num] = List<Part> with properties that serialize into 'num'
local function getConsistentInconsistent()
	local consistent, inconsistent = {}, {}
	for name, t in partsList do
		if t.Count == 1 then
			consistent[name] = t
		else
			inconsistent[name] = t
		end
	end
	return consistent, inconsistent
end

local selectedRow -- UI instance
local selectedList -- from partsList
local selectedPart
local selectionIndex -- for select next
local function selectRow(row, list)
	if selectedRow then
		-- deselect
	end
	selectedRow = row
	selectedList = list
	selectedPart = selectedList[1]
	selectionIndex = 0
	if row then
		-- select
	end
	local enabled = not not row
	-- todo enable/disable Select/Remove buttons
end
local function selectNext()
	selectionIndex = (selectionIndex % #selectedList) + 1 -- lists are 1 based
	Selection:Set({selectedList[selectionIndex]})
end
local function selectAll()
	Selection:Set(selectedList)
end
local function removeRow()
	for _, v in ipairs(selectedList) do
		seenBefore[v] = nil
	end
	local t = partsList[selectedPart.Name]
	t.NumToList[PropsSerializer.PartToNum(selectedPart)] = nil
	t.Count -= 1
	if t.Count == 0 then
		partsList[selectedPart.Name] = nil
	elseif t.Count == 1 then
		-- todo transform from inconsistent to consistent (or updateWidget())
	end
	selectedRow:Destroy() -- todo reuse instances
	selectRow(nil)
end
local function clearAll()
	-- clear out lists
	-- update UI
	table.clear(partsList)
	table.clear(seenBefore)
end
local tmp
selectRow(tmp)
selectNext(tmp)
selectAll(tmp)
removeRow(tmp)
clearAll(tmp)



--[[ Ideal order of operations:
1. select parts
2. open widget
3. select themes in Explorer (optional; defaults to SelectedTheme)
]]

local function analyzeConsistency(list) -- adds parts from list to partsList
	for _, instance in ipairs(list) do
		if seenBefore[instance] then continue end
		seenBefore[instance] = true
		analyzeConsistency(instance:GetChildren())
		if instance:IsA("BasePart") then
			local t = partsList[instance.Name]
			if not t then
				t = {Count = 0, NumToList = {}}
				partsList[instance.Name] = t
			end
			local num = PropsSerializer.PartToNum(instance)
			local partList = t.NumToList[num]
			if not partList then
				partList = {}
				t.NumToList[num] = partList
				t.Count += 1
			end
			table.insert(partList, instance)
		end
	end
end
local function updateWidget()
	local consistent, inconsistent = getConsistentInconsistent()

end
local function addToWidget(list)
	analyzeConsistency(list)
	updateWidget()
end
function AddPartsWidget.ScanSelection()
	addToWidget(Selection:Get())
end
function AddPartsWidget.ScanWorkspace()
	addToWidget(workspace:GetDescendants())
end



-- Only called if everything is consistent
local function addPartsToTheme(theme)
	local added = 0
	local identical = 0
	local conflicts = {}
	local partsData = folderToThemeData[theme].PartsData
	for name, t in partsList do
		local part = next(t.NumToList)[1]
		if partsData:AddPartIfUnique(part) then
			added += 1
		else
			local other = partsData:GetAPartFromName(name)
			if Config.ArePartPropsDuplicate(part, other) then
				identical += 1
			else
				table.insert(conflicts, name)
			end
		end
	end
	return {
		Added = added,
		Identical = identical,
		Conflicts = conflicts,
	}
end
local function addToSelected()
	-- todo if 1+ themes in game.Selection, use them. Otherwise use GetSelectedTheme.
	undoable("Add parts to " .. n .. " selected theme" .. (if n == 1 then "" else "s"), function() -- todo n
		-- for _, theme in ?? do
		-- 	addPartsToTheme(theme)
		-- end
		addPartsToTheme(GetSelectedTheme())
	end)
end
local function addToAllThemes()
	undoable("Add parts to all themes", function()
		for _, theme in GetAllThemes() do
			addPartsToTheme(theme)
		end
	end)
end
	
addPartsToTheme(tmp)
addToSelected(tmp)
addToAllThemes(tmp)

function AddPartsWidget.Init()
	
end

return AddPartsWidget