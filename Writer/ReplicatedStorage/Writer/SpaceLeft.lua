local SpaceLeft = {}
SpaceLeft.__index = SpaceLeft
function SpaceLeft.new(widthAvail, heightAvail)
	return setmetatable({
		WidthAvail = widthAvail, -- Treat these as read-only outside of this class (modify them only through the available functions)
		HeightAvail = heightAvail,
		X = widthAvail,
		Y = heightAvail,
		heightUsedCurRow = 0,
	}, SpaceLeft)
end
function SpaceLeft:IsOutOfSpace()
	return self.Y <= 0
end
function SpaceLeft:DoesItFit(width, height)
	--	returns true (same line), "newline", or false (no height left)
	return height <= self.Y
		and (width <= self.X
			and true
			or width <= self.WidthAvail and height * 2 <= self.Y and "newline")
end
function SpaceLeft:DoesItFitFullWidth(height)
	return height <= self.Y
end
function SpaceLeft:FullWidthAvailable()
	return self.X >= self.WidthAvail
end
function SpaceLeft:UseHeight(height)
	--	Uses the specified amount of height, returning the previous y-coordinate of available space
	--	Does not alter .X. Use :EnsureNewLine first if the element takes up the full line width and must start on an empty line.
	local startHeight = self.Y
	self.Y -= height
	return self.HeightAvail - startHeight
end
-- TODO is spaceBetweenLines something defined per page? How/when does it change?
--	(perhaps it belongs in constructor?)
function SpaceLeft:NewLine(spaceBetweenLines)
	--	Note: if no space has been used on the current line, it will have height 0
	self.X = self.WidthAvail
	self.Y -= self.heightUsedCurRow + (spaceBetweenLines or 0)
	self.heightUsedCurRow = 0
end
function SpaceLeft:EnsureNewLine(spaceBetweenLines)
	if self.X < self.WidthAvail then
		self:NewLine(spaceBetweenLines)
	end
end
function SpaceLeft:UseSpace(width, height)
	if width > self.X then error("width must be <= spaceLeft.X", 2) end
	if height > self.Y then error("height must be <= spaceLeft.Y", 2) end
	self:useSpace(width, height)
end
function SpaceLeft:useSpace(width, height)
	self.X -= width
	self.heightUsedCurRow = self.heightUsedCurRow > height and self.heightUsedCurRow or height
end
function SpaceLeft:TryFitOnOneLine(width, height) -- todo not used
	--	Returns true if successful (the space will be recorded as used in this case only)
	if self:DoesItFit(width, height) == true then
		self.X -= width
		return true
	end
end
function SpaceLeft:TryFit(width, height, spaceBetweenLines) -- todo not used
	--	Will try to use as much space on the current line as possible.
	--	Returns allFits, widthAvail (widthAvail is for newline case only; it's the width that can be used on the first line)
	local result = self:DoesItFit(width, height)
	if result == true then
		self:useSpace(width, height)
		return true
	elseif result == "newline" then
		local widthAvail = self.X
		self.X = self.WidthAvail
		self.Y -= height + (spaceBetweenLines or 0)
		return false, widthAvail
	else
		self.X = self.WidthAvail
		self.Y -= height + (spaceBetweenLines or 0)
		return false
	end
end
function SpaceLeft:Clone()
	return setmetatable({
		WidthAvail = self.WidthAvail,
		X = self.X,
		Y = self.Y,
		heightUsedCurRow = self.heightUsedCurRow,
	}, SpaceLeft)
end
return SpaceLeft