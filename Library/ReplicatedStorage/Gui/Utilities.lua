local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assert = require(ReplicatedStorage.Utilities.Assert)
local Utilities = {}
function Utilities.HandleVerticalScrollingFrame(sf, layout)
	--	Handles setting the CanvasSize for a vertical ScrollingFrame ('sf')
	--	Layout is optional, but there must exist a UIGridStyleLayout in ScrollingFrame if it is not provided (ex UIListLayout)
	--	Returns a the connection that keeps it up to date
	Assert.IsA(sf, "ScrollingFrame")
	layout = layout
		and Assert.IsA(layout, "UIGridStyleLayout") -- must support AbsoluteContentSize
		or sf:FindFirstChildWhichIsA("UIGridStyleLayout")
		or error("No UIGridStyleLayout in " .. tostring(sf))
	local function update()
		sf.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
	end
	update()
	return layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
end
return Utilities