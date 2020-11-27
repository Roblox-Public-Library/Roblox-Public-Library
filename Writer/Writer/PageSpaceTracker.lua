--[[PageSpaceTracker: Tracks the space left over based on placing items at various locations on a page
Each function returns the UDim2 coordinate that an item should be placed at, or nil if there's no room
	If nil is returned, the PageSpaceTracker's state remains unmodified
]]
local function pos(x, y)
	return UDim2.new(0, x, 0, y)
end
local PageSpaceTracker = {}
PageSpaceTracker.__index = PageSpaceTracker
function PageSpaceTracker.new(width, height)
	return setmetatable({
		width = width,
		height = height,
		x = 0, -- current X coordinate of next element
		y = 0, -- current Y coordinate of next element
		curLineHeight = 0,
		left = {}, -- queue of regions on the left in the format {.right .top .bottom} -- note that the element is not actually on the 'right' nor 'bottom' pixel
		right = {}, -- queue of regions on the right (same format except has .left instead of .right)
		--	These queue elements are dropped once the cursor (x/y) is past them
	}, PageSpaceTracker)
end
local function inRegion(region, y)
	return y >= region.top and y < region.bottom
end
local function findCurY(list, y)
	--	Find the region in the list given the current y coordinate
	--	Deletes regions that are no longer relevant
	while true do
		local cur = list[1]
		if not cur or y < cur.top then
			return nil
		elseif y < cur.bottom then
			return cur
		else
			table.remove(list, 1)
		end
	end
end
function PageSpaceTracker:newLine()
	--	Advances to a new line without calling moveCursorToValidLocation
	self.y += self.curLineHeight
	self.curLineHeight = 0
	self.x = 0
end
function PageSpaceTracker:NewLine()
	--	Advances to a new line (does not return any positions)
	self:newLine()
	self:moveCursorToValidLocation()
end
function PageSpaceTracker:moveCursorToValidLocation()
	while true do
		local curRight = findCurY(self.right, self.y)
		if curRight and self.x >= curRight.left or self.x >= self.width then
			if self.curLineHeight > 0 then
				self:newLine()
			else -- move past either left or right region
				local curLeft = findCurY(self.left, self.y)
				self.x = 0
				if curLeft and curLeft.bottom > curRight.bottom then
					self.y = curLeft.bottom
					table.remove(self.left, 1)
				else
					self.y = curRight.bottom
					table.remove(self.right, 1)
				end
			end
		else
			local curLeft = findCurY(self.left, self.y)
			if self.x < curLeft.right then
				self.x = curLeft.right
			else
				return
			end
		end
	end
end
function PageSpaceTracker:pos(x, y)
	--	to be used to return a position - also moves cursor to a valid location
	self:moveCursorToValidLocation()
	return UDim2.new(0, x, 0, y)
end
-- function PageSpaceTracker:assertWH(w, h)
-- 	if width > self.width then error("width " .. tostring(width) .. " wider than page width " .. tostring(self.width), 2) end
-- 	if height > self.height then error("height " .. tostring(height) .. " wider than page height " .. tostring(self.height), 2) end
-- end
local function traverseY(list, y)
	local i = 0
	local region
	repeat
		i += 1
		region = list[i]
	until not region or inRegion(region, y)
	return {
		--i = i,
		value = region,
		next = function(self)
			--self.i += 1
			--self.value = list[self.i]
			i += 1
			self.value = list[i]
			return self.value
		end,
	}
end
local function getY(list)
	--	returns a 'get(y)' function that returns the region at 'y'. Each successive 'y' is expected to be >= the last 'y' used.
	local i = 1
	local region = list[1]
	return function(y)
		while true do
			if not region or y < region.top then
				return nil
			elseif y < region.bottom then
				return region
			end
			i += 1
			region = list[i]
		end
	end
end
function PageSpaceTracker:PlaceLeft(width, height)
	local left = self.left
	local n = #left
	local last = left[n]
	local top = last and last.bottom or self.y -- top of new left element
	-- we need to know if there's sufficient width given whatever's in 'right'
	local right = traverseY(self.right, top)
	local curRight = right.value
	while curRight and width > curRight.left do -- insufficient width for left element here
		top = curRight.bottom
		curRight = right:next()
	end
	local bottom = top + height
	if bottom > self.height then return nil end
	left[n + 1] = {
		right = width,
		top = top,
		bottom = bottom,
	}
	return self:pos(0, top)
end
function PageSpaceTracker:PlaceRight(width, height)

end
function PageSpaceTracker:PlaceCenter(width, height)
	self:EnsureFullNewLine()
	local y = self.y
	local bottom = y + height
	if bottom >= self.height then return nil end
	self.y += height
	self.x = 0
	return self:pos(self.width / 2 - width / 2, y)
end
function PageSpaceTracker:PlaceFullWidth(height)
	self:EnsureFullNewLine()
	local y = self.y
	self.y += height
	return self:pos(0, y)
end
function PageSpaceTracker:Place(width, height)
	local x, y, curLineHeight = self.x, self.y, self.curLineHeight
	local getLeft, getRight = getY(self.left), getY(self.right)
	local getLeft2, getRight2 = getY(self.left), getY(self.right)
	-- We have getLeft2/getRight2 because getY is increase-only and we need to measure the bottom of a potentially tall element
	--	ex if the element is 60 pixels tall and we try positions in increments of 15
	local function availWidth(left, right)
		return (right and right.left or self.width) - (left and left.right or 0)
	end
	local function widthFits()
		return width <= availWidth(getLeft(y), getRight(y)) -- width at top of proposed location
			and width <= availWidth(getLeft(y + height), getRight(y + height)) -- width at bottom of proposed location
	end
	-- local function availHeight(x, y)
	-- end
	while true do
		if height > self.height - y then -- no room left on page
			return nil
		end
		-- todo to make PlaceLeft2ndWiderTallText test work requires determining available height
		if widthFits() then
			self.x += width
			if height > self.curLineHeight then
				self.curLineHeight = height
			end
			return self:pos(x, y)
		end
		-- TODO I think we need to call :NewLine without actually mutating anything
		--	since we could still return nil
		--	however, we also need that moveCursorToValidLocation algorithm!
		self:NewLine()
	end
end
function PageSpaceTracker:GetWidthRemaining()
	return self.width - self.x -- todo not right - consider regions
end
function PageSpaceTracker:GetHeightRemaining()
	return self.height - self.y
end
--[[NOT SURE if this is true:
so if we're doing text
we're going to be adding word by word
but we don't want to commit it to a line
because if half-way through the line we have an extra tall word (dif font)
then we want the whole line on a new line
so we ask for block dimensions left
and try to fill it up. if we at least get width, we submit it and repeat
if we fail, we need to say 'i need more space, get me the next block'
]]
-- function PageSpaceTracker:GetBlockSpaceRemaining()
-- 	--	Get the available height that text can take up before it should go onto a new line
-- 	return Vector2.new(self.width - self.x, self.height - self.y) -- todo not right - consider regions
-- 	-- Note: if 2 left-images have same width and are immediately above/below each other (or maybe even very close?), that's the same region
-- 	--	since text can't fit in between them
-- end
-- function PageSpaceTracker:MoveToNextBlock()
-- 	--	Move down to the next block that has more 
-- end
function PageSpaceTracker:OutOfSpace()
	return self.y >= self.height
end
return PageSpaceTracker