local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assert = require(ReplicatedStorage.Utilities.Assert)
local Utilities = {}
function Utilities.HandleVerticalScrollingFrame(sf, layout)
	--	Handles setting the CanvasSize for a vertical ScrollingFrame ('sf')
	--	Layout is optional, but there must exist a UIGridStyleLayout in ScrollingFrame if it is not provided (ex UIListLayout)
	--	Unlike just setting AutomaticCanvasSize, this function disables scrolling when it is unnecessary (enabling the player to zoom out while their cursor is over the ScrollingFrame)
	--	Returns a the connection that keeps it up to date
	Assert.IsA(sf, "ScrollingFrame")
	layout = layout
		and Assert.IsA(layout, "UIGridStyleLayout") -- must support AbsoluteContentSize
		or sf:FindFirstChildWhichIsA("UIGridStyleLayout")
		or error("No UIGridStyleLayout in " .. tostring(sf))
	local padding = layout:FindFirstChildWhichIsA("UIPadding")
	local function update()
		local y = layout.AbsoluteContentSize.Y + (padding and padding.Top.Offset + padding.Bottom.Offset or 0)
		sf.CanvasSize = UDim2.new(0, 0, 0, y)
		sf.ScrollingEnabled = y > sf.AbsoluteSize.Y
	end
	update()
	return layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
end
return Utilities