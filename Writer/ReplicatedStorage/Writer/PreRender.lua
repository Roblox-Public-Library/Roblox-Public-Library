local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage.Utilities
local Class = require(Utilities.Class)

local Writer = script.Parent
local BookContent = require(Writer.BookContent)
local Chapter = require(Writer.Chapter)
local Elements = require(Writer.Elements)
local Format = require(Writer.Format)
local Page = require(Writer.Page)
local PageSpaceTracker = require(Writer.PageSpaceTracker)
local ReaderConfig = require(Writer.ReaderConfig)
local RichText = require(Writer.RichText)
local TextBlockFactory = require(Writer.TextBlockFactory)

local PreRender = Class.New("PreRender")

local defaultPageSize = Vector2.new(350, 453) -- Based on 8.5 x 11 ratio
--	Note: default *inner* page size is therefore 340, 406
PreRender.DefaultPageSize = defaultPageSize

local coverElement = Elements.Text("Cover", Format.new({Size = "Chapter", Bold = true}))

local defaultStartingPageNumbering = {
	StartingPageIndex = 1,
	Style = "number",
	StartingNumber = 1,
}
PreRender.DefaultStartingPageNumbering = defaultStartingPageNumbering

PreRender.DefaultParagraphIndent = string.rep(" ", 5)

local outerMargin = {Top = 0.035*1.5, Left = 0.015, Right = 0.015, Bottom = 0.035*1.5} -- scale
-- TODO probably will need minOuterMargin AND a way to disable margins entirely!
-- local minOuterMargin = {Top = 12, Left = 2, Right = 2, Bottom = 12}
local innerScaleX = 1 - outerMargin.Left - outerMargin.Right
local innerScaleY = 1 - outerMargin.Top - outerMargin.Bottom
PreRender.OuterMargin = outerMargin
PreRender.InnerPageSize = UDim2.new(innerScaleX, 0, innerScaleY, 0)
function PreRender.GetOuterPageSize(innerPageSize)
	return Vector2.new(
		math.floor(innerPageSize.X / innerScaleX),
		math.floor(innerPageSize.Y / innerScaleY))
end
--[[Undoing GetOuterPageSize:
math.floor(innerX * 1.1) = outerX
innerX = math.unfloor(outerX) / 1.1
ex, if outerX is 100
	'unfloor' means it was 100 -> 100.99 before being floored
	/ 1.1 is 90.9 -> 91.8
	we can then conclude it was 91
in general, since scale is >= 1, we can safely just 'ceiling' `outer / scale`
]]
function PreRender.GetInnerPageSize(outerPageSize)
	return Vector2.new(
		math.ceil(outerPageSize.X * innerScaleX),
		math.ceil(outerPageSize.Y * innerScaleY))
end

function PreRender.new(pageSize, config, RichTextOverride, disablePadding)
	pageSize = pageSize or defaultPageSize
	local innerPageSize = PreRender.GetInnerPageSize(pageSize)
	local self = setmetatable({
		pageSize = pageSize,
		innerPageSize = innerPageSize,
		config = config or ReaderConfig.Default,
		alignment = Enum.TextXAlignment.Left,
		disablePadding = disablePadding,
		availSpace = (if disablePadding then PageSpaceTracker.new else PageSpaceTracker.Padded.new)(innerPageSize.X, innerPageSize.Y, 2), -- without the padding, elements overlap each other/are too close (in part because Render adds (1, 1) to all sizes)
		curPage = {}, -- List of elements for the current page
		pages = {}, -- List of pages so far
		chapters = {},
		pageNumbering = {},
		paragraphIndent = PreRender.DefaultParagraphIndent,
		chapterNamingStyle = "custom",
		book = BookContent.new(),
		explicitNewPage = true, -- true if a NewPage was explicitly requested (or for first page)
		RichText = RichTextOverride or RichText,
	}, PreRender)
	self.textBlockFactory = TextBlockFactory.new(self.availSpace, self, config, RichTextOverride)
	return self
end
function PreRender:GetParagraphIndent() return self.paragraphIndent end
function PreRender:SetParagraphIndent(indent)
	self.paragraphIndent = indent or ""
	self.textBlockFactory:EnsureParagraphEnded()
end
function PreRender:NewPage()
	if self.explicitNewPage then
		self:newPage()
	else
		self:ensureOnBlankPage()
		self.explicitNewPage = true
	end
end

-- Handle end of current page and create new page
function PreRender:newPage()
	self.textBlockFactory:EndOfPage()
	local n = #self.pages + 1
	self.pages[n] = Page.new(self.book, n, self.curPage)
	self.curPage = {}
	self.availSpace:Reset()
	self.textBlockFactory:NewPage()
end

-- If current line not empty, creates empty line (on new page if needed)
function PreRender:EnsureFullNewLine()
	if not self.availSpace:EnsureFullNewLine(true) then
		self:newPage()
	end
end
function PreRender:finishPage()
	self.textBlockFactory:Finish()
	if self.curPage and #self.curPage > 0 then
		local n = #self.pages + 1
		self.pages[n] = Page.new(self.book, n, self.curPage)
		self.curPage = nil
	end
end
function PreRender:FinishAndGetBookContent()
	self:finishPage()
	local first = self.pageNumbering[1]
	if not first or first.StartingPageIndex ~= 1 then
		table.insert(self.pageNumbering, 1, defaultStartingPageNumbering)
	end
	first = self.chapters[1]
	if not first or first.StartingPageIndex ~= 1 then
		self:addChapter(Chapter.new(0, 1, {coverElement}, {}, "custom"), 1)
	end
	local book = self.book
	book.PageNumbering = self.pageNumbering
	book.Chapters = self.chapters
	book.Pages = self.pages
	return book
end
function PreRender:addToPage(element)
	table.insert(self.curPage, element)
	self.explicitNewPage = false
end
function PreRender:removeFromPage(element)
	table.remove(self.curPage, table.find(self.curPage, element) or error(print(self.curPage, element) or "element not in page"))
end

-- Positions element on the next page that it fits. 'fn' must return the position to place the element at (nil for new page)
function PreRender:addFn(element, size, fn)
	local pos = fn()
	if not pos then
		self:NewPage()
		pos = fn()
		if not pos then
			print(element)
			error("element does not fit on a new page")
		end
	end
	element.Position = pos
	element.Size = size
	self:addToPage(element)
end

--	fnName is the function name with which to index 'availSpace' (only valid if the function takes in 'width, height' as arguments; otherwise use 'addFn')
function PreRender:add(element, size, fnName)
	local availSpace = self.availSpace
	self:addFn(element, size, function()
		return availSpace[fnName](availSpace, size.X, size.Y)
	end)
end

--	Add a full-page-width element (that cannot be broken up) to the next page it fits on
function PreRender:addFullWidthElement(element, height)
	self:addFn(element, Vector2.new(self.innerPageSize.X, height), function()
		return self.availSpace:PlaceFullWidth(height)
	end)
end
function PreRender:getTextElementHeight(element)
	return self.config:GetSize(element.Format.Size) -- we don't consider SubOrSuperScript because this is used to calculate the line height
end
function PreRender:newPageIfNil(fn)
	local v = fn()
	if v then
		return v
	else
		self:NewPage()
		return fn() or error("NewPage did not change the result of the function", 2)
	end
end

-- Creates blank page if not currently on one
function PreRender:ensureOnBlankPage()
	if #self.curPage > 0 then
		self:newPage()
	else -- Sometimes we aren't at the top of the page, so reset availSpace. (This can happen if we don't have an official text element on the current page but have moved down 1+ lines due to newlines.)
		self.availSpace:Reset()
	end
end

--	Adds/assembles a chapter (but doesn't add to textBlockFactory)
function PreRender:addChapter(chapter, insertIndex)
	local config = self.config
	chapter.Name = self.RichText.FromTextElements(chapter.NameElements, config)
	if chapter.NameElements == chapter.TextElements then
		chapter.Text = chapter.Name
	else
		chapter.Text = self.RichText.FromTextElements(chapter.TextElements, config)
	end
	if insertIndex then
		table.insert(self.chapters, insertIndex, chapter)
	else
		table.insert(self.chapters, chapter)
	end
end

local function getFnNameFromAlignment(alignment, noWrap)
	return if alignment == Enum.TextXAlignment.Center then "PlaceCenter"
		else (if alignment == Enum.TextXAlignment.Left then "PlaceLeft" else "PlaceRight")
			.. (if noWrap then "NoWrap" else "")
end

local blockMargin = 5
local blockPadding = 5

-- Type = function(self, element)
--	Each function is responsible for positioning, sizing, and adding to the current/next page(s) the element specified
local typeToHandle; typeToHandle = {
	Alignment = function(self, element)
		-- local availSpace = self.availSpace
		self:EnsureFullNewLine()
		self:addToPage(element)
		self.alignment = element.Alignment
		self.textBlockFactory:NewAlignment(element.Alignment)
	end,
	Bar = function(self, element)
		self.textBlockFactory:ConsiderNewLineIndent(Format.Plain)
		if element.Line ~= true then
			element.Font = self.config:GetFont(Format.Plain.Font)
			element.TextSize = self.config:GetSize()
		end
		self:addFullWidthElement(element, self.config:GetSize())
		self.availSpace:ResetImplicitNewLine()
	end,
	Block = function(self, element)
		local fullWidth = element.Width == 1 or element.NoWrap
		local availSpace = self.availSpace
		if fullWidth then
			self.textBlockFactory:finishLineAndBlock()
			if not availSpace:CurrentlyImplicitNewLine() and availSpace.x > 0 and availSpace.curLineHeight > 0 then
				if not availSpace:NewLine() then
					self:NewPage()
				end
			end
		end
		element.Alignment = element.Alignment or self.alignment
		local width = element.Width * self.innerPageSize.X
		local blockExtraSize = (element.BorderThickness + blockPadding + blockMargin) * 2
		local innerWidth = width - blockExtraSize
		local availHeight = availSpace:GetHeightAvailForObj(width, element.Alignment.Name)
		local blockPageSize = Vector2.new(innerWidth, availHeight - blockExtraSize)
		local blockSpaceTracker = PageSpaceTracker.new(blockPageSize.X, blockPageSize.Y)
		local tbf
		local blockPR = setmetatable({
			pages = {},
			curPage = {},
			innerPageSize = blockPageSize,
			availSpace = blockSpaceTracker,
			paragraphIndent = "", -- by default
			newPage = function(blockPR)
				blockSpaceTracker.height = availSpace.height - blockExtraSize
				PreRender.newPage(blockPR)
			end,
		}, {__index = self, __newindex = self})
		tbf = TextBlockFactory.new(blockSpaceTracker, blockPR, self.config, self.RichText)
		rawset(blockPR, "textBlockFactory", tbf)
		blockPR:Handle(element.Elements)
		blockPR:finishPage()
		self.textBlockFactory:Finish()

		-- Split the box into several based on what fit
		-- Go through each page and resize appropriately
		-- Then we have to add them to the real pages
		--	Possibly we could queue this? ie whenever we hit a new page, we immediately try this? except that could break assumptions that NewPage will get a completely blank one!
		local placeFn
		if fullWidth then
			placeFn = function(width, height)
				return availSpace:PlaceFullWidth(height)
			end
		else
			local fnName = getFnNameFromAlignment(element.Alignment, element.NoWrap)
			placeFn = function(width, height)
				return availSpace[fnName](availSpace, width, height)
			end
		end
		local outerBlock = blockMargin + element.BorderThickness
		local outerBlock2 = outerBlock * 2
		local outerBlockV2 = Vector2.new(outerBlock, outerBlock)
		local blockPadding2 = blockPadding * 2
		local n = #blockPR.pages
		for i, page in blockPR.pages do
			local e = if i == 1 then element else table.clone(element)
			e.Elements = page.Elements
			local sx, sy = 0, 0
			for _, x in e.Elements do
				if x.Size.X > sx then sx = x.Size.X end
				if x.Size.Y > sy then sy = x.Size.Y end
			end
			e.Size = Vector2.new(sx + blockPadding2, sy + blockPadding2)
			e.Padding = blockPadding -- todo render using UIPadding so that internal positions & sizes will still be as expected
			e.Margin = blockMargin
			local tsx = sx + blockPadding2 + outerBlock2
			local tsy = sy + blockPadding2 + outerBlock2
			if i > 1 then
				e.Position = placeFn(tsx, tsy)
					or print(i, e, blockPR)
					or error("block has content but failed to add to page")
			elseif sy > blockPadding2 or n == 1 then
				e.Position = placeFn(tsx, tsy)
				if not e.Position then
					if n == 1 then
						self:NewPage()
						e.Position = placeFn(tsx, tsy)
							or print(e)
							or error("block didn't fit on new page")
					else
						print(i, e, blockPR)
						error("block has content but failed to add to page")
					end
				end
			else -- block doesn't fit on first page so no content was added to it; skip it
				continue
			end
			e.Position += outerBlockV2
			self:addToPage(e)
			if i < n then
				self:NewPage()
			end
		end
		if fullWidth then -- must update textBlockFactory
			if n == 1 then
				self.textBlockFactory:NewPage() -- this resets some variables so that it's as if it's a new page (for whatever room availSpace reports it has left)
			end
			self.textBlockFactory:StartingNewParagraph()
		end
	end,
	Chapter = function(self, element)
		self:ensureOnBlankPage()
		typeToHandle.Section(self, element, self.chapterNamingStyle, true)
	end,
	Section = function(self, element, chapterNamingStyle, centered) -- just like a chapter but not necessarily on a new page and always with a custom naming style
		self.textBlockFactory:StartingNewParagraph()

		local last = self.chapters[#self.chapters]
		local curPageIndex = #self.pages + 1
		local chapter = Chapter.new(if last then last.Number + 1 else 1, curPageIndex, element.Name, element.Text, chapterNamingStyle or "custom", element.Format)
		element.Format = nil -- no longer needed since the chapter/section has Format in each element of its Name/Text (a list of elements)
		self:addChapter(chapter)
		self.textBlockFactory:NewChapter(chapter, element, centered)
	end,
	ChapterNamingStyle = function(self, element)
		self.chapterNamingStyle = element.Style
	end,
	Clear = function(self)
		self:EnsureFullNewLine()
		self.textBlockFactory:StartingNewParagraph()
	end,
	Header = function(self, element)
		local textBlockFactory = self.textBlockFactory
		textBlockFactory:StartingNewParagraph()
		for _, e in element.Text do
			local format = e.Format:With("Size", element.Size)
			local lineHeight = self.config:GetSize(format.Size)
			textBlockFactory:Extend(e.Text, format, lineHeight, true)
		end
		textBlockFactory:EnsureParagraphEnded()
	end,
	Image = function(self, element)
		local fnName = getFnNameFromAlignment(element.Alignment, element.NoWrap)
		local size = element.Size * self.innerPageSize
		if element.AspectRatio then
			local eitherProvided = element.WidthProvided or element.HeightProvided
			local bothProvided = element.WidthProvided and element.HeightProvided
			-- Note: if both provided, we want to keep the image using the specified space, even if it doesn't need it
			if eitherProvided and not bothProvided then -- only 1 provided
				if element.WidthProvided then
					size = Vector2.new(
						size.X,
						math.min(size.X / element.AspectRatio, self.innerPageSize.Y))
				else
					size = Vector2.new(
						math.min(size.Y * element.AspectRatio, self.innerPageSize.X),
						size.Y)
				end
				element.ImageSize = size
			else -- either both were provided or neither (in which case use 100% x 100%)
				-- 1. width is too wide
				-- 2. height is too tall
				-- (3. all is fine)
				-- Note: in this case we do not update 'size' (it is supposed to take up all of 'size' on the page, even though visually it will be smaller)
				element.ImageSize = Vector2.new(
					math.min(size.Y * element.AspectRatio, size.X),
					math.min(size.X / element.AspectRatio, size.Y))
			end
		end
		self:add(element, size, fnName)
	end,
	Page = function(self, element)
		self:NewPage()
		self.textBlockFactory:StartingNewParagraph()
	end,
	PageNumbering = function(self, element)
		local curPageIndex = #self.pages + 1
		local startingNumber = element.StartingNumber
		if not startingNumber then
			local last = self.pageNumbering[#self.pageNumbering]
			if last then
				startingNumber = last.StartingNumber + curPageIndex - last.StartingPageIndex
			else
				startingNumber = 1
			end
		end
		table.insert(self.pageNumbering, {
			Style = element.Style,
			StartingPageIndex = curPageIndex,
			StartingNumber = startingNumber,
			Invisible = element.Invisible,
		})
	end,
	ParagraphIndent = function(self, element)
		self:EnsureFullNewLine()
		self:SetParagraphIndent(element.Indent)
	end,
	Turn = function(self, element)
		self:NewPage()
		if self.pages[#self.pages]:IsLeftSidePage() then
			self:NewPage()
		end
		self.textBlockFactory:StartingNewParagraph()
	end,
	Text = function(self, element)
		local textHeight = self:getTextElementHeight(element)
		self.textBlockFactory:Extend(element.Text, element.Format, textHeight)
	end,
	Flag = function(self, element)
		self.book.flags[element.Name] = true
	end,
}
function PreRender:Handle(elements)
	for _, element in ipairs(elements) do
		(typeToHandle[element.Type] or error(tostring("Unknown element type '" .. element.Type .. "'", 2)))(self, element)
	end
end
function PreRender:HandleAll(elements)
	for _, element in ipairs(elements) do
		(typeToHandle[element.Type] or error(tostring("Unknown element type '" .. element.Type .. "'", 2)))(self, element)
	end
	return self:FinishAndGetBookContent()
end
function PreRender.All(elements, pageSize, config)
	return PreRender.new(pageSize, config):HandleAll(elements)
end
function PreRender.CountPagesDesync(elements, pageSize, config)
	--	For use by actors; prerenders the book and returns the page count
	-- TODO this could be made more efficient by not actually creating elements/pages
	return #PreRender.new(pageSize, config, RichText.Desync):HandleAll(elements).Pages
end
return PreRender