local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Event = require(ReplicatedStorage.Utilities.Event)
local EventUtilities = require(ReplicatedStorage.Utilities.EventUtilities)
local ObjectPool = require(ReplicatedStorage.Utilities.ObjectPool)
local Value = require(ReplicatedStorage.Utilities.Value)

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local normalFont = Font.new("Source Sans Pro", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local boldFont = Font.new("Source Sans Pro", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

local dropdown = ReplicatedStorage.Guis.BookSearchDropdown
dropdown.Enabled = false
dropdown.Parent = localPlayer.PlayerGui
local Dropdown = {}
Dropdown.ValueSelected = Event.new() -- (value, index)
local noChange = Event.new()
local sf = dropdown.Dropdown
local entry = sf.Entry
entry.Parent = nil
local rowToCon = {}
local rowPool = ObjectPool.new({
	create = function() return entry:Clone() end,
	release = function(row)
		rowToCon[row]:Disconnect()
		rowToCon[row] = nil
		row.Parent = nil
	end,
	destroy = function(row)
		rowToCon[row]:Disconnect()
		rowToCon[row] = nil
		row:Destroy()
	end,
	max = 10,
})
local rows = {}
local curValue
local rowSize = Value.new(entry.Size)
function Dropdown:SetRowSize(size)
	rowSize:Set(size)
end
function Dropdown:Open(pos, anchor, options, _curValue)
	sf.Position = pos
	sf.AnchorPoint = anchor
	curValue = _curValue
	dropdown.Enabled = true
	for _, row in rows do
		rowPool:Release(row)
	end
	table.clear(rows)
	for i, o in options do
		local row = rowPool:Get()
		rows[i] = row
		row.LayoutOrder = i
		row.Text = o
		if o == curValue then
			row.FontFace = boldFont
		else
			row.FontFace = normalFont
		end
		row.Size = rowSize.Value
		row.Parent = sf
		rowToCon[row] = EventUtilities.CombineConnections({
			row.Activated:Connect(function()
				dropdown.Enabled = false
				if curValue == o then
					noChange:Fire()
					return
				end
				curValue = o
				Dropdown.ValueSelected:Fire(o, i)
			end),
			rowSize.Changed:Connect(function(value)
				row.Size = value
			end),
		})
	end
end
function Dropdown:SetPos(pos)
	sf.Position = pos
end
dropdown.Close.Activated:Connect(function()
	dropdown.Enabled = false
end)
local events = {dropdown.Close.Activated, Dropdown.ValueSelected, noChange}
function Dropdown:OpenAsync(...) -- returns nil if nothing changed else `value, index`
	self:Open(...)
	local function handle(e, ...)
		if e == dropdown.Close.Activated then return end
		return ...
	end
	return handle(EventUtilities.WaitForAnyEvent(events))
end
return Dropdown