--[[PageSpaceTracker: Tracks the space left over based on placing items at various locations on a page
Conceptually:
	List<object with size & type> -> their positions on a page
Typical API:
	.new(width, height)
	:PlaceLeft(width, height) -> Vector2/nil -- also LeftNoWrap, Right, RightNoWrap, Center, and just Place (for text)
	:PlaceFullWidth(height) -> Vector2/nil
	Placement functions return nil in the event that there is no more room on the page
		If nil is returned, the PageSpaceTracker instance's state remains unmodified
	:NewLine(lineHeight, implicit)
	:PlacementFits(width, height) -> bool -- for text
	:OutOfSpace() -> bool
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage.Utilities
local Class = require(Utilities.Class)

local PageSpaceTracker = Class.New("PageSpaceTracker")

function PageSpaceTracker.new(width, height)
	return setmetatable({
		width = width,
		height = height,
		x = 0, -- current X coordinate of next element
		y = 0, -- current Y coordinate of next element
		curLineHeight = 0, -- height of current line (only non-zero if the current line has content)
		left = {i = 1}, -- list of regions on the left in the format {.right .top .bottom}
		--	note that the element is not actually on the 'right' nor 'bottom' pixel
		--		that is, a left object of width 10 starts at x = 0 and ends at x = 9 with .right = 10
		--	left.i is the index of the region we may not have gotten past yet (so we will check it again in findRegionAtY)
		right = {i = 1}, -- list of regions on the right in the format {.left .top .bottom}
		-- implicitNewLine -- true if just advanced to a new line without an explicit :NewLine call and no content added to this line yet (not including objects added using PlaceLeft/PlaceRight)
		startOfLine = true, -- true if Place has not been called since the last change in 'y'
	}, PageSpaceTracker)
end
function PageSpaceTracker:Reset()
	self.x = 0
	self.y = 0
	self.curLineHeight = 0
	self.left = {i = 1}
	self.right = {i = 1}
	self.implicitNewLine = false
	self.startOfLine = true
end
function PageSpaceTracker:ResetImplicitNewLine()
	self.implicitNewLine = false
end
function PageSpaceTracker:GetX() return self.x end
function PageSpaceTracker:GetY() return self.y end
function PageSpaceTracker:GetPos() return Vector2.new(self.x, self.y) end
function PageSpaceTracker:AtStartOfLine() return self.startOfLine end
function PageSpaceTracker:save() -- save state so it can be restored later (for undoing state changes)
	--	Note: Doesn't save left/right tables, so be sure not to modify those
	return {
		x = self.x,
		y = self.y,
		curLineHeight = self.curLineHeight,
		leftI = self.left.i,
		rightI = self.right.i,
		implicitNewLine = self.implicitNewLine,
		startOfLine = self.startOfLine,
	}
end
function PageSpaceTracker:restore(state) -- restore a saved state
	self.x = state.x
	self.y = state.y
	self.curLineHeight = state.curLineHeight
	self.left.i = state.leftI
	self.right.i = state.rightI
	self.implicitNewLine = state.implicitNewLine
	self.startOfLine = state.startOfLine
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
	for i = upperI + 1, if region then lowerI else lowerI - 1 do
		region = right[i]
		if region and bottom > region.top and y < region.bottom then
			return region, i
		end
	end
end
function PageSpaceTracker:newLine(lineHeight, numLines)
	--	Advances to a new line without calling moveCursorToValidLocation
	--	lineHeight is the height of the text on the current line
	if not lineHeight or lineHeight < self.curLineHeight then
		lineHeight = self.curLineHeight
	end
	if lineHeight == 0 then error("newLine called with no curLineHeight and no lineHeight", 2) end
	self.y += lineHeight * (numLines or 1)
	self.startOfLine = true
	self.curLineHeight = 0
	self.x = 0
end
function PageSpaceTracker:NewLine(lineHeight, implicit, numLines)
	--	Advances to a valid location on a new line based on 'lineHeight' (the height of the text on the current line), which can be left nil if text has been placed on the current line already.
	--	Note: won't actually move to a new line if this is the start of a line that occurred by filling up the previous line
	--	Returns true if successful (false if ran out of space)
	numLines = numLines or 1
	if numLines < 1 then return true end
	if numLines > 1 and implicit then error("implicit & numLines > 1 is probably not what you want to do", 2) end
	if self.implicitNewLine then
		self.implicitNewLine = implicit
		return self:NewLine(lineHeight, false, numLines - 1)
	elseif implicit and self.curLineHeight == 0 then -- nothing on the current line, so no need to advance
		-- Note: we don't set implicitNewLine to true because this can only happen after an explicit new line; if another explicit new line comes along, we don't want to ignore it.
		return true
	end
	self:newLine(lineHeight, 1) -- always call with 1 first in case we're moving past a large line
	if numLines > 1 then
		self:newLine(lineHeight, numLines - 1)
	end
	self:moveCursorToValidLocation()
	if implicit then
		self.implicitNewLine = true
	end
	return not self:OutOfSpace()
end
function PageSpaceTracker:EnsureWrappedToNewLine(lineHeight)
	--	Useful after placing objects/text via :Place to ensure that a new line has been started.
	--	Sets implicitNewLine as true.
	--	Returns true if successful (false if out of room)
	if not self.implicitNewLine then
		return self:NewLine(lineHeight, true)
	end
	return true
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
	local left, right -- bottom of the left/right object
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
		self.startOfLine = true
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
							self:NewLine(nil, true)
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
	--	Ensures that the tracker is on a full new line (no 'left'/'right' elements on the sides), advancing it if necessary
	--	Returns true if successful, false if out of room
	if self:OutOfSpace() then
		return false
	end
	if self.curLineHeight > 0 and self.x > 0 then -- there is text on this line
		self:NewLine(nil)
		if self:OutOfSpace() then
			return false
		end
	end
	while self.x > 0 or self:findRightRegionBesideTextUpdateI() do
		self:AdvanceToBottomOfNextObject()
		if self:OutOfSpace() then
			return false
		end
	end
	return true
end
function PageSpaceTracker:IsOnFullNewLine()
	if self:OutOfSpace() then
		return false
	end
	if self.curLineHeight > 0 and self.x > 0 then -- there is text on this line
		return false
	end
	-- findRightRegionBesideTextUpdateI is safe to call because we aren't looking forward (we're not advancing self.y temporarily or anything)
	if self.x > 0 or self:findRightRegionBesideTextUpdateI() then
		return false
	end
	return true
end
function PageSpaceTracker:AtTopLeftOfPage()
	return self.x == 0 and self.y == 0 and not getBottomOfNextObject(self.left, 0) and not getBottomOfNextObject(self.right, 0)
end
function PageSpaceTracker:AtTopOfPage()
	return self.y == 0
end
function PageSpaceTracker:CurrentlyImplicitNewLine() -- returns true if placements have caused the PageSpaceTracker to go to the next line without an explicit new line. This is only true while at the start of the line.
	return self.implicitNewLine
end
function PageSpaceTracker:moveCursorToValidLocation()
	while true do
		local curRight, curRightI = findRegionAtYUpdateI(self.right, self.y)
		if curRight and self.x >= curRight.left or self.x >= self.width then -- move to new line
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
				self.startOfLine = true
			end
			self.implicitNewLine = true
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
	return Vector2.new(x, y)
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
	if bottomOfText > top and (sideProp == "left" or self.x > self.width - width) then
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
function PageSpaceTracker:GetHeightAvailForObj(width, alignment) -- alignment is "Left"/"Center"/"Right"; this function assumes that the height may be as large as possible
	local y = self.y
	-- Advance past text
	local bottomOfText = self.y + self.curLineHeight
	if bottomOfText > y and (alignment == "Left" or self.x > self.width - width) then
		y = bottomOfText
	end
	local left, right = self.left, self.right
	if alignment ~= "Right" then -- advance past left objects
		local last = left[math.max(#left, left.i)]
		if last then
			y = math.max(y, last.bottom)
		end
		-- If alignment is center, we'll advance past all right objects, so no point in analyzing if they're too wide
		if alignment ~= "Center" then
			-- Advance past right objects if they're too wide
			for i = right.i, #right do
				local r = right[i]
				if r.top >= y and r.left < width then
					y = r.bottom
				end
			end
		end
	end
	if alignment ~= "Left" then -- advance past right objects
		local right = self.right
		local last = right[math.max(#right, right.i)]
		if last then
			y = math.max(y, last.bottom)
		end
		if alignment ~= "Center" then
			-- Advance past left objects if they're too wide
			local maxRight = self.width - width
			for i = left.i, #left do
				local l = left[i]
				if l.top >= y and l.right > maxRight then
					y = l.bottom
				end
			end
		end
	end
	return self.height - y
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
	if self.height - y < height then return nil end
	self.y += height
	self.startOfLine = true
	self.implicitNewLine = true
	return self:pos(0, y)
end
function PageSpaceTracker:PlaceRightNoWrap(width, height)
	if not self:EnsureFullNewLine() then return nil end
	local y = self.y
	if self.height - y < height then return nil end
	self.y += height
	self.startOfLine = true
	self.implicitNewLine = true
	return self:pos(self.width - width, y)
end
function PageSpaceTracker:PlaceCenter(width, height)
	if not self:EnsureFullNewLine() then return nil end
	local y = self.y
	if self.height - y < height then return nil end
	self.y += height
	self.x = 0
	self.startOfLine = true
	self.implicitNewLine = true
	return self:pos(self.width / 2 - width / 2, y)
end
function PageSpaceTracker:PlaceFullWidth(height)
	if not self:EnsureFullNewLine() then return nil end
	local y = self.y
	if self.height - y < height then return nil end
	self.y += height
	self.startOfLine = true
	self.implicitNewLine = true
	return self:pos(0, y)
end
function PageSpaceTracker:Place(width, height, notContent) -- returns nil if no room; automatically advances to a new line as needed
	--	notContent: if true, does not change implicitNewLine nor startOfLine (useful if placing whitespace)
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
				if width > 0 then
					self.implicitNewLine = false
					self.startOfLine = false
					self.x += width
				end
				if height > self.curLineHeight then
					self.curLineHeight = height
				end
				return self:pos(x, y)
			else -- Advance cursor horizontally
				self:AdvanceToRightOfNextObject(width, height)
			end
		else -- Advance cursor vertically
			if self.curLineHeight > 0 then
				self:NewLine(nil, true)
			else -- we have no text so we just need to get past the next object
				self:AdvanceToBottomOfNextObject()
				if y == self.y then
					error("AdvanceToBottomOfNextObject did nothing")
				end
			end
		end
	end
end

function PageSpaceTracker:leftOf(rightRegion)
	--	Returns the left side of the region or self.width if no region
	return if rightRegion then rightRegion.left else self.width
end
function PageSpaceTracker:getHorizontalRoom(height)
	--	GetWidthRemaining but without checking for the available height (doesn't check page height or left/right-aligned objects beneath the current row of text)
	local region, upperI = findRegionAtYUpdateI(self.right, self.y)
	local right = self:leftOf(region)
	if height and height > 0 then
		--local leftRegion, leftUpperI = findRegionAtYUpdateI(self.left, self.y)
		local lowerI
		region, lowerI = findRegionAtY(self.right, self.y + height - 1)
		-- In the 'for' loop bounds:
		--	Start at 'upperI' in case the upper-most region didn't start right at self.y (in which case findRegionAtY returned nil)
		--	If region is nil then we shouldn't check self.right[lowerI] - it might exist, but it'll be out of range
		for i = upperI, if region then lowerI else lowerI - 1 do
			region = self.right[i]
			local otherRight = self:leftOf(region)
			if otherRight < right then
				right = otherRight
			end
		end
	end
	return right - self.x
end
function PageSpaceTracker:GetWidthRemaining(height)
	--	Returns available width for a placement with the specified height (defaults to a height of 1 pixel). The placement is for the current 'y' and >= the current 'x' (this matches 'Place', which will move to the right if there's room)
	height = height or 1
	if self.y + height > self.height then return 0 end -- no room
	local right = self.width
	local left = self.x
	local leftRegions = self.left
	for i = leftRegions.i, #leftRegions do
		local region = leftRegions[i]
		if self.y < region.bottom and self.y + height > region.top then
			if region.right > left then
				left = region.right
			end
		end
	end
	local rightRegions = self.right
	for i = rightRegions.i, #rightRegions do
		local region = rightRegions[i]
		if self.y < region.bottom and self.y + height > region.top then
			if region.left < right then
				right = region.left
			end
		end
	end
	return math.max(right - left, 0)
end
function PageSpaceTracker:GetHeightRemaining(width)
	--	Returns available height for a placement (at current x, y) with the specified width
	--[[Example:
		+.
		*
		++++	<-- left or right-aligned object
		Answer is 2 lines tall
		Note that we must check both left & right images all the way down
		Anything that horizontally overlaps with self.x to self.x + width must be considered
	]]
	width = width or 1
	if width > self:getHorizontalRoom() then return 0 end -- no room
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
	return width <= self:getHorizontalRoom(height)
end
function PageSpaceTracker:PlacementFits(width, height)
	return self:PlacementFitsVertically(width, height) and self:PlacementFitsHorizontally(width, height)
end
function PageSpaceTracker:OutOfSpace()
	return self.y >= self.height
end

-- Padded class. Note that this isn't ideal code:
--	> It makes various assumptions about which functions call which other functions
--	> It should really be part of the class so that the logic can be integrated properly
-- The strategy is to tell the base class that it has 'padding' extra width to work with, but also to tell it that all objects are 'padding' wider than normal. We also subtract padding from functions like GetWidthRemaining and have to make a few other adjustments so that everything works as expected.
local Padded = Class.New("PaddedPageSpaceTracker", PageSpaceTracker)
PageSpaceTracker.Padded = Padded
local base = Padded.new
function Padded.new(width, height, padding)
	--	padding only applies to X dimension
	local self = setmetatable(base(width + padding, height), Padded)
	self.padding = padding
	return self
end
for _, name in {"AdvanceToRightOfNextObject", "PlaceLeft", "PlaceRight", "PlaceLeftNoWrap", "PlaceRightNoWrap", "PlaceCenter", "PlacementFitsHorizontally"} do
	-- Note: we do not override PlacementFits as it is implemented in terms of PlacementFitsVertically and PlacementFitsHorizontally
	--	PlacementFitsVertically just uses GetHeightRemaining which is overridden below
	local base = Padded[name]
	Padded[name] = function(self, width, ...)
		return base(self, if width == 0 then 0 else width + self.padding, ...)
	end
end
local base = Padded.GetHeightRemaining
function Padded:GetHeightRemaining(width)
	return base(self, if width then width + self.padding else nil)
end
local base = Padded.GetHeightAvailForObj
function Padded:GetHeightAvailForObj(width, alignment)
	return base(self, width + self.padding, alignment)
end
local base = Padded.GetWidthRemaining
function Padded:GetWidthRemaining(height)
	return base(self, height) - self.padding
end
PageSpaceTracker.PlaceUnpadded = PageSpaceTracker.Place
function Padded:Place(width, height, notContent) -- returns nil if no room; automatically advances to a new line as needed
	--	notContent: if true, does not change implicitNewLine nor startOfLine (useful if placing whitespace)
	local baseWidth = width
	if width > 0 then
		width += self.padding
	end
	-- The following is copied from PageSpaceTracker.Place except some functions are passed the baseWidth to compensate for how we've overridden them
	if width > self.width then error(("Width %f > page width %f"):format(baseWidth, self.width - self.padding), 2) end
	local state = self:save()
	while true do
		local x, y = self.x, self.y
		if height > self.height - y then -- no room left on page
			self:restore(state)
			return nil
		end
		if self:PlacementFitsHorizontally(baseWidth, height) then
			if self:PlacementFitsVertically(baseWidth, height) then
				if width > 0 then
					self.implicitNewLine = false
					self.startOfLine = false
					self.x += width
				end
				if height > self.curLineHeight then
					self.curLineHeight = height
				end
				return self:pos(x, y)
			else -- Advance cursor horizontally
				self:AdvanceToRightOfNextObject(baseWidth, height)
			end
		else -- Advance cursor vertically
			if self.curLineHeight > 0 then
				self:NewLine(nil, true)
			else -- we have no text so we just need to get past the next object
				self:AdvanceToBottomOfNextObject()
				if y == self.y then
					error("AdvanceToBottomOfNextObject did nothing")
				end
			end
		end
	end
end
local base = Padded.moveCursorToValidLocation
function Padded:moveCursorToValidLocation()
	-- We need the algorithm to use the unpadded width (or else there might be 1 pixel left but the padding for the object will take up more than that)
	-- To do this we modify self.width -- this only works because the base function doesn't invoke anything that uses self.width
	local width = self.width
	self.width -= self.padding
	base(self)
	self.width = width
end

return PageSpaceTracker