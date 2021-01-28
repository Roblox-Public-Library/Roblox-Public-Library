--[[PageSpaceTracker: Tracks the space left over based on placing items at various locations on a page
Each function returns the UDim2 coordinate that an item should be placed at, or nil if there's no room
	If nil is returned, the instance's state remains unmodified
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
		left = {i = 1}, -- list of regions on the left in the format {.right .top .bottom}
		--	note that the element is not actually on the 'right' nor 'bottom' pixel
		--		that is, a left object of width 10 starts at x = 0 and ends at x = 9 with .right = 10
		--	left.i is the index of the region we may not have gotten past yet (so we will check it again in findRegionAtY)
		right = {i = 1}, -- list of regions on the right in the format {.left .top .bottom}
	}, PageSpaceTracker)
end
function PageSpaceTracker:save() -- save state so it can be restored later (for undoing state changes)
	--	Note: Doesn't save left/right tables, so be sure not to modify those
	return {
		x = self.x,
		y = self.y,
		curLineHeight = self.curLineHeight,
		leftI = self.left.i,
		rightI = self.right.i,
	}
end
function PageSpaceTracker:restore(state) -- restore a saved state
	self.x = state.x
	self.y = state.y
	self.curLineHeight = state.curLineHeight
	self.left.i = state.leftI
	self.right.i = state.rightI
end
local function findRegionAtY(list, y)
	--	Find the region in the list (with list.i indicating index to search at) that 'y' is beside
	--	Returns region, i (region may be nil, meaning i will be #list + 1)
	local i = list.i
	while true do
		local cur = list[i]
		if not cur or y < cur.top then
			return nil, i
		elseif y < cur.bottom then
			return cur, i
		else
			i += 1
		end
	end
end
local function findRegionAtYUpdateI(list, y)
	--	Find the region in the list (with list.i indicating index to search at) that 'y' is beside
	--	Moves list.i past irrelevant regions
	local value, i = findRegionAtY(list, y)
	list.i = i
	return value, i
end
function PageSpaceTracker:findRightRegionBesideTextUpdateI()
	local right = self.right
	local y = self.y
	local region, upperI = findRegionAtYUpdateI(right, y)
	if region then
		return region, upperI
	end
	local lowerI
	local bottom = y + self.curLineHeight
	region, lowerI = findRegionAtY(right, bottom - 1)
	-- In the 'for' loop upper bound, if the region is nil then we shouldn't check self.right[lowerI] - it might exist, but it'll be out of range
	for i = upperI + 1, region and lowerI or lowerI - 1 do
		region = right[i]
		if region and bottom > region.top and y < region.bottom then
			return region, i
		end
	end
end
function PageSpaceTracker:newLine()
	--	Advances to a new line without calling moveCursorToValidLocation
	if self.curLineHeight == 0 then error("newLine called with no curLineHeight", 2) end
	self.y += self.curLineHeight
	self.curLineHeight = 0
	self.x = 0
end
function PageSpaceTracker:NewLine()
	--	Advances to a valid location on a new line based on curLineHeight, which must be greater than 0
	--	Doesn't return anything
	self:newLine()
	self:moveCursorToValidLocation()
end
local function getBottomOfNextObject(list, y)
	local region = list[list.i]
	return region and y >= region.top and region.bottom
end
local function getBottomOfY(list, listI, y)
	--	return the bottom of the first region that 'y' is in (in list, starting the search at list[listI])
	for i = listI, #list do
		local region = list[i]
		if y < region.top then
			return nil
		elseif y < region.bottom then
			return region.bottom
		end
	end
end
function PageSpaceTracker:GetBottomOfNextObject(y)
	local left, right
	if y then
		left = getBottomOfY(self.left, 1, y)
		right = getBottomOfY(self.right, 1, y)
	else
		left = getBottomOfNextObject(self.left, self.y)
		right = getBottomOfNextObject(self.right, self.y)
	end
	-- Return the lesser of left/right or whichever one isn't nil
	return left and right and left < right and left or right or left
end
function PageSpaceTracker:AdvanceToBottomOfNextObject()
	--	Advances to the bottom of the next object (there must be at least one object on either side)
	local y = self:GetBottomOfNextObject()
	if y then
		self.x, self.y = 0, y
		self:moveCursorToValidLocation()
	else
		error("No object to advance beyond", 2)
	end
end
function PageSpaceTracker:AdvanceToRightOfNextObject(width, height)
	--	Advances to the right of the obstacle that is blocking a placement of 'height' at the current self.x, self.y
	--	Will advance vertically instead if the obstacle is a right-aligned object
	--	If there is no obstacle, the cursor will *not* be advanced.
	local function consider(list)
		for i = list.i, #list do
			local region = list[i]
			if self.x < (region.right or self.width) and self.x + width > (region.left or 0) then
				if self.y + height > region.top then
					if region.right then -- it's a left-aligned object
						self.x = region.right
						self:moveCursorToValidLocation()
						return true -- theoretically there might be multiple but we'll get there eventually
					else -- it's a right-aligned object; we can only get "past" it by going to a new line
						if self.curLineHeight > 0 then
							self:NewLine()
						else
							self:AdvanceToBottomOfNextObject()
						end
						return true
					end
				end
			end
		end
	end
	return consider(self.left) or consider(self.right)
end
function PageSpaceTracker:EnsureFullNewLine()
	--	Ensures that the tracker is on a full new line, advancing it if necessary
	--	Returns true if successful, false if out of room
	if self:OutOfSpace() then
		return false
	end
	while self.x > 0 or self:findRightRegionBesideTextUpdateI() do
		self:AdvanceToBottomOfNextObject()
		if self:OutOfSpace() then
			return false
		end
	end
	return true
end
function PageSpaceTracker:moveCursorToValidLocation()
	while true do
		local curRight, curRightI = findRegionAtYUpdateI(self.right, self.y)
		if curRight and self.x >= curRight.left or self.x >= self.width then
			if self.curLineHeight > 0 then
				self:newLine()
			else -- move past either left or right region
				local curLeft = findRegionAtYUpdateI(self.left, self.y)
				self.x = 0
				if curLeft and (not curRight or curLeft.bottom > curRight.bottom) then
					self.y = curLeft.bottom
					self.left.i += 1
				else
					self.y = curRight.bottom
					self.right.i += 1
				end
			end
		else
			local curLeft = findRegionAtYUpdateI(self.left, self.y)
			if curLeft and self.x < curLeft.right then
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
function PageSpaceTracker:placeObject(sideProp, oppProp, destX, destOppSide, width, height)
	--	sideProp: "left" or "right" side in which to place an object of size width x height
	--	oppProp: the property on the opposite side
	--	destX: the x coordinate to potentially place the object at
	--	destOppSide: the left side of a right region or vice versa
	--[[Visual Examples
		Scenario 1, placing "***" 2 lines high on the left (page is 4 characters wide)...
			&. +	<-- '&' is left-image; '.' is text; '+' is 2-line high right-image
			   +
			 xxx	<-- wide right-image
			   +	<-- 3rd right-image

			so we start at line 2 and it's wide enough
			so we set 'lower' to the 'xxx' and determine it's no good
			so we set 'upper' to the 3rd '+' and it's okay
			then we run out of regions so we place it there

		Scenario 2, placing "**" (2 lines high) on the right side
			&. +
			 .
			xxx
			+

			so we start at line 2 and have to notice that the text is in range
			then we continue as normal]]
	local list = self[sideProp]
	local n = #list
	local last = list[n]
	local top = last and last.bottom -- top of new list element
		or self.y + -- place left objects after text; right objects after text only if insufficient width
			((sideProp == "left" or self.x > self.width - width) -- self.width - width is accurate since this only runs if there are no images on the right side
				and self.curLineHeight
				or 0)
	-- The last element can be beside the text. If we're left-aligning, always go past the text.
	-- If we're right-aligning and the text overlaps the proposed location, we must move past the text.
	local bottomOfText = self.y + self.curLineHeight
	if bottomOfText > top and (sideProp == "left" or last and self.x > self.width - width and bottomOfText > top) then
		top = bottomOfText
	end
	local bottom = top + height
	local oppList = self[oppProp]
	local oppWidthOkay = sideProp == "left"
		-- function(region/nil) -> true if object we're placing would fit in width left by region, if any
		and function(right) return not right or width <= right.left end
		or function(left) return not left or width <= self.width - left.right end
	local upper, upperI = findRegionAtY(oppList, top) -- region and region-index at the top of the object we're trying to place
	-- Incase we are placing a tall object and there are aligned objects on the opposite side that are too wide for this one to fit beside,
	--	we check the available width of each opposite object starting from 'upper' and incrementing 'lower' until we get out of range
	while oppList[upperI] do -- while there are regions left to analyze (NOTE: We don't use 'upper' because it can be nil despite more regions existing)
		if bottom > self.height then return nil end
		local okay
		if not upper or oppWidthOkay(upper) then -- check regions below upperI
			okay = true
			local lower
			local lowerI = upperI -- we have to recheck upperI in case upper is nil (can happen if we start beside text and there's an image below it)
			while true do
				lower = oppList[lowerI]
				if not lower or lower.top >= bottom then
					break
				elseif not oppWidthOkay(lower) then
					okay = false
					upperI = lowerI -- and upperI will be incremented past this problematic one below
					break
				end
				lowerI += 1
			end
		end
		if okay then break end
		upperI += 1
		upper = oppList[upperI]
		if not upper then
			top = oppList[upperI - 1].bottom
			bottom = top + height
			break
		end
		top = upper.top
		bottom = top + height
	end
	list[n + 1] = {
		[oppProp] = destOppSide,
		top = top,
		bottom = bottom,
	}
	return self:pos(destX, top)
end
function PageSpaceTracker:PlaceLeft(width, height)
	return self:placeObject("left", "right", 0, width, width, height)
end
function PageSpaceTracker:PlaceRight(width, height)
	local left = self.width - width
	return self:placeObject("right", "left", left, left, width, height)
end
function PageSpaceTracker:PlaceLeftNoWrap(width, height)
	if not self:EnsureFullNewLine() then return nil end
	local y = self.y
	self.y += height
	return self:pos(0, y)
end
function PageSpaceTracker:PlaceRightNoWrap(width, height)
	if not self:EnsureFullNewLine() then return nil end
	local y = self.y
	self.y += height
	return self:pos(self.width - width, y)
end
function PageSpaceTracker:PlaceCenter(width, height)
	if not self:EnsureFullNewLine() then return nil end
	local y = self.y
	local bottom = y + height
	if bottom >= self.height then return nil end
	self.y += height
	self.x = 0
	return self:pos(self.width / 2 - width / 2, y)
end
function PageSpaceTracker:PlaceFullWidth(height)
	if not self:EnsureFullNewLine() then return nil end
	local y = self.y
	self.y += height
	return self:pos(0, y)
end
function PageSpaceTracker:Place(width, height)
	if width > self.width then error(("Width %f > page width %f"):format(width, self.width), 2) end
	local state = self:save()
	while true do
		local x, y = self.x, self.y
		if height > self.height - y then -- no room left on page
			self:restore(state)
			return nil
		end
		if self:PlacementFitsHorizontally(width, height) then
			if self:PlacementFitsVertically(width, height) then
				self.x += width
				if height > self.curLineHeight then
					self.curLineHeight = height
				end
				return self:pos(x, y)
			else -- Advance cursor horizontally
				self:AdvanceToRightOfNextObject(width, height)
			end
		else -- Advance cursor vertically
			if self.curLineHeight > 0 then
				self:NewLine()
			else -- we have no text so we just need to get past the next object
				self:AdvanceToBottomOfNextObject()
				if y == self.y then
					error("AdvanceToBottomOfNextObject did nothing")
				end
			end
		end
	end
end

function PageSpaceTracker:leftOf(right)
	--	Returns the left side of the region or self.width if no region
	return right and right.left or self.width
end
function PageSpaceTracker:GetWidthRemaining(height)
	--	Returns available width for a placement (at current x, y) with the specified height
	--	Warning: does not check for the available height (ex it is limited by page height but also by left-aligned objects beneath the current row of text!)
	local region, upperI = findRegionAtYUpdateI(self.right, self.y)
	local right = self:leftOf(region)
	if height then
		local lowerI
		region, lowerI = findRegionAtY(self.right, self.y + height - 1)
		-- In the 'for' loop bounds:
		--	Start at 'upperI' in case the upper-most region didn't start right at self.y (in which case findRegionAtY returned nil)
		--	If region is nil then we shouldn't check self.right[lowerI] - it might exist, but it'll be out of range
		for i = upperI, region and lowerI or lowerI - 1 do
			region = self.right[i]
			local otherRight = self:leftOf(region)
			if otherRight < right then
				right = otherRight
			end
		end
	end
	return right - self.x
end
function PageSpaceTracker:GetHeightRemaining(width)
	--	Returns available height for a placement (at current x, y) with the specified width
	--	Warning: does not check for the available width
	--[[Example:
		+.
		*
		++++	<-- left or right-aligned object
		Answer is 2 lines tall
		Note that we must check both left & right images all the way down
		Anything that horizontally overlaps with self.x to self.x + width must be considered
	]]
	width = width or 0
	local maxHeight = self.height - self.y
	local function consider(list)
		for i = list.i, #list do
			local region = list[i]
			if self.x < (region.right or self.width) and self.x + width > (region.left or 0) then
				local height = region.top - self.y
				if height < maxHeight then
					maxHeight = height
				end
			end
		end
	end
	consider(self.left)
	consider(self.right)
	return maxHeight
end
function PageSpaceTracker:PlacementFitsVertically(width, height)
	--	Note: does not check if placement fits horizontally
	return height <= self:GetHeightRemaining(width)
end
function PageSpaceTracker:PlacementFitsHorizontally(width, height)
	--	Note: does not check if placement fits vertically
	return width <= self:GetWidthRemaining(height)
end
function PageSpaceTracker:PlacementFits(width, height)
	return self:PlacementFitsVertically(width, height) and self:PlacementFitsHorizontally(width, height)
end
function PageSpaceTracker:OutOfSpace()
	return self.y >= self.height
end
return PageSpaceTracker