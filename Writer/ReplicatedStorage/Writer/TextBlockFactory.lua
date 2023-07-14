local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage.Utilities
local Assert = require(Utilities.Assert)
local Class = require(Utilities.Class)
local String = require(Utilities.String)

local Writer = script.Parent
local Elements = require(Writer.Elements)
local Format = require(Writer.Format)
local ReaderConfig = require(Writer.ReaderConfig)
local RichText = require(Writer.RichText)
local Sizes = require(Writer.Sizes)

local MAX_LABEL_CHARS = 16384 -- Maximum characters a TextLabel can handle (confirmed 2022-01-31)

local TBF_MERGES_BLOCKS = false
-- NOTE: TBF_MERGES_BLOCKS should be false for now because:
--	1. For whitespace indentation, we move the textbox over without checking to see if the block is more than 1 line or not
--	2. To avoid a newline-after-alignment bug (that didn't occur if there was a nonwhitespace paragraph indent)
--		I'm guessing that the problem is that the textBlock advanced to the next line in a condition where an implicit newline was approaching
--		(The concat table had an explicit newline to prepare for the oncoming line; perhaps that'd need to be a special "needNewlineToContinue" sort of variable)
-- If these bugs are fixed, TBF_MERGES_BLOCKS can be set to true (and even removed entirely)

local TextBlockFactory = Class.New("TextBlockFactory")
TextBlockFactory.TBF_MERGES_BLOCKS = TBF_MERGES_BLOCKS
function TextBlockFactory.new(availSpace, preRender, config, RichTextOverride)
	config = config or ReaderConfig.Default
	local self = setmetatable({
		config = config,
		availSpace = availSpace,
		preRender = preRender,
		startOfParagraph = true,
		alignment = Enum.TextXAlignment.Left,
		-- line = List of TextBlock on current line (only for non-multi-line TextBlocks)
		lastPos = availSpace:GetPos(), -- used to determine if availSpace has moved outside of TextBlockFactory usage, implying we need a new block
		-- inOperation -- if true, already in a TextBlockFactory operation, so don't need to check to see if availSpace has moved again
		concat = {}, -- used to concatenate the text for the latest element in the current textBlock
		size0Newline = if config.DisableSize0Newline then "\n" else '<font size="0">\n</font>',
		RichText = RichTextOverride or RichText,
		-- ensureWrappedPos : Vector2 -- keeps track of the position for which the text has wrapped to a new line (nil or treated as nil if wrapping has not occurred or if the position no longer matches)
		-- needNewParagraph -- nil or the y-position for which a paragraph was ended (indicating that no more text should be on the same height and a new paragraph should be started)
	}, TextBlockFactory)
	if config.DisableSize0Newline then
		function self:resizeTrailingNewline(s) return s end
	end
	return self
end
local function finishBlockSubSuper(block)
	local subOrSuper = block.SubOrSuperScript
	if not subOrSuper then return end
	local sizeMult = Sizes[subOrSuper] or error("Unknown subOrSuper: " .. tostring(subOrSuper))
	local lineHeight = block.Size.Y / sizeMult
	-- block is left at the top of lineHeight
	local extra = lineHeight * 0.1 -- we want it beyond the top/bottom of the line by 10% (as the bottom and top 20% of the line is empty space for most fonts for characters other than 'p'/'g')
	if subOrSuper == "Sub" then
		block.Position += Vector2.new(0, lineHeight - block.Size.Y + extra)
	else
		block.Position -= Vector2.new(0, extra)
	end
end
function TextBlockFactory:finishBlock()
	local textBlock = self.textBlock
	if not textBlock then return end
	self.textBlock = nil -- cannot be used anymore
	self.elements = nil
	local concat = self.concat
	local elements = textBlock.Elements
	if concat[1] then
		elements[#elements].Text = table.concat(concat)
		table.clear(concat)
	elseif #elements == 0 then
		self.preRender:removeFromPage(textBlock)
		return
	end
	textBlock.RichText, textBlock.TextSize = self.RichText.FromTextElements(elements, self.config, true)
	if #textBlock.RichText > MAX_LABEL_CHARS then
		error("RichText compiled into " .. #textBlock.RichText .. " characters and only " .. MAX_LABEL_CHARS .. " are supported!")
	end
	textBlock.multiline = nil
	textBlock.Alignment = self.alignment
	if self.line then
		table.insert(self.line, textBlock)
	else
		finishBlockSubSuper(textBlock)
	end
end
function TextBlockFactory:finishLineAndBlock()
	self:finishBlock()
	self.lineHeight = nil
	local line = self.line
	if not line then return end
	self.line = nil
	local sizes = table.create(#line)
	local alignment = self.alignment
	local totalWidth = 0
	local maxHeight = 0
	-- Note: TextBlock.Size is still the size assigned by GetWidthRemaining; we don't update it until after we deal with alignment as it's sometimes used to determine the leftmost edge of an object on the right, in addition to the line height
	local RichText = self.RichText
	for i, textBlock in ipairs(line) do
		local size = RichText.MeasureTextWithSize(self.config, textBlock.RichText, nil, textBlock.TextSize)
		totalWidth += size.X
		sizes[i] = size
		if textBlock.Size.Y > maxHeight then
			maxHeight = textBlock.Size.Y
		end
	end
	-- Now update the X position of everything in the line based on the alignment
	-- Limitation: This algorithm can fail for non-left alignment cases that have images beneath the current line if the current line has varying heights
	--	This occurs because both PreRender and the page space tracker assumes for simplicity that all text is left-aligned (up until this point)
	if alignment == Enum.TextXAlignment.Left then
		local x = line[1].Position.X
		for i, textBlock in ipairs(line) do
			textBlock.Position = Vector2.new(x, textBlock.Position.Y)
			x += sizes[i].X
		end
	elseif alignment == Enum.TextXAlignment.Right then
		local n = #line
		local last = line[n]
		local x = last.Position.X + last.Size.X
		for i = n, 1, -1 do
			local textBlock = line[i]
			x -= sizes[i].X
			textBlock.Position = Vector2.new(x, textBlock.Position.Y)
		end
	else
		local last = line[#line]
		local x = (line[1].Position.X + last.Position.X + last.Size.X) / 2 - totalWidth / 2
		for i, textBlock in ipairs(line) do
			textBlock.Position = Vector2.new(x, textBlock.Position.Y)
			x += sizes[i].X
		end
	end
	-- Update everything else
	for i, textBlock in ipairs(line) do
		local dif = maxHeight - textBlock.Size.Y
		if dif > 0 then
			textBlock.Position += Vector2.new(0, dif * 0.8) -- 80% is the estimated bottom of the text (for letters like 'm' but not 'p'); this is correct for most fonts and works well enough for the rest
		end
		textBlock.Size = sizes[i]
		finishBlockSubSuper(textBlock) -- further adjusts position and size if necessary
	end
end
function TextBlockFactory:lineFinished()
	if self.line then
		self:finishLineAndBlock()
	end
end
function TextBlockFactory:Finish()
	self:finishLineAndBlock()
end
function TextBlockFactory:newBlock(lineHeight, suppressInit)
	self:finishBlock()
	local textBlock = Elements.TextBlock()
	local pr = self.preRender
	if not suppressInit then
		textBlock.Position = pr:newPageIfNil(function() return self.availSpace:Place(0, lineHeight) end)
		textBlock.Size = Vector2.new(self.availSpace:GetWidthRemaining(lineHeight), lineHeight) -- must always have textBlocks be the full width so that alignment will work properly. If this ends up on the same line as another block, finishLineAndBlock takes care of it.
	end
	self.textBlock = textBlock
	self.elements = textBlock.Elements
	self.lineHeight = lineHeight
	pr:addToPage(textBlock)
	self.ensureWrappedPos = nil
	return textBlock
end
function TextBlockFactory:considerSubSuper(format, lineHeight)
	local textBlock = self.textBlock
	if format.SubOrSuperScript ~= (if textBlock then textBlock.SubOrSuperScript else nil) then
		self:splitLine(lineHeight) -- note: self.textBlock will likely be changed by this
		self.textBlock.SubOrSuperScript = format.SubOrSuperScript
	end
end
function TextBlockFactory:splitLine(lineHeight)
	-- Called when the formatting requires a new text block, possibly mid-line; it is called before the special text is added.
	if self.availSpace:AtStartOfLine() or self.line then
		self:newBlock(lineHeight)
		return
	end
	local textBlock = self.textBlock
	if not textBlock then
		self:newBlock(lineHeight)
		return
	end
	if textBlock.multiline then -- split into two
		local elements = textBlock.Elements
		local n = #elements
		local concat = self.concat
		if concat[1] then
			elements[n].Text = table.concat(concat)
			table.clear(concat)
		end
		for i = n, 1, -1 do
			local element = elements[i]
			local newText, rest = element.Text:match("(.*)\n([^\n]*)")
			if newText then -- newline found in this element
				-- If there's a "<font size=0>" tag, remove it (these are here as a work-around to a Roblox bug)
				local ignoreIndex = newText:find("<font size=.0.>$")
				if ignoreIndex then
					newText = newText:sub(1, ignoreIndex - 1)
					rest = rest:sub(8) -- skip 7 characters of "</font>"
				end
				local newElement = nil -- first element for newList (only if it's a brand new element)
				local moveIndex
				if newText == "" then -- just move the element
					moveIndex = i
				elseif rest == "" then -- keep the element; nothing to add
					moveIndex = i + 1
				else -- split
					newElement = Elements.Text(rest, element.Format)
					element.Text = newText
					moveIndex = i + 1
				end
				local newList = {newElement}
				if moveIndex <= n then
					table.move(elements, moveIndex, n, #newList + 1, newList)
					table.move(elements, n + 1, n + 1 + (n - moveIndex), moveIndex, elements)
				end
				local prev = textBlock
				textBlock = self:newBlock(self.lineHeight, true)
				textBlock.Position = Vector2.new(prev.Position.X, prev.Position.Y + prev.Size.Y - self.lineHeight)
				textBlock.Size = Vector2.new(prev.Size.X, self.lineHeight)
				prev.Size = Vector2.new(prev.Size.X, prev.Size.Y - self.lineHeight)
				textBlock.Elements = newList
				break
			end
		end
	end
	self.line = {} -- will have textBlock added to it after :newBlock
	self:newBlock(lineHeight)
end
function TextBlockFactory:EndOfPage()
	self:finishLineAndBlock()
end
function TextBlockFactory:startingNewLine()
	self.ensureWrappedPos = nil
end
function TextBlockFactory:NewPage() -- to be called whenever a new page is reached. If it is also a new paragraph, call :StartingNewParagraph()
	self:startingNewLine()
	self.needNewParagraph = nil
end
function TextBlockFactory:StartingNewParagraph()
	--	Calling this indicates that a new paragraph is about to be started
	--	It is safe to call this multiple times in a row
	--	not needed after alignment, chapters, or text that explicitly has newlines
	self:EnsureParagraphEnded()
	self:startingNewLine()
	self.availSpace:ResetImplicitNewLine()
end
function TextBlockFactory:NewChapter(chapter, element, centered) -- to be called whenever a new chapter is reached (NewPage should also be called, if appropriate).
	self:EnsureParagraphEnded()
	local alignment = self.alignment
	if centered then
		self:NewAlignment(Enum.TextXAlignment.Center)
	end
	local lineHeight = self.config:GetSize("Chapter")
	for _, e in chapter.TextElements do
		self:Extend(e.Text, e.Format, lineHeight, true)
	end
	self:EnsureParagraphEnded()
	if centered then
		self:NewAlignment(alignment)
	end
end
function TextBlockFactory:EnsureParagraphEnded()
	--	Calling this ensures that any prior paragraphs/text blocks have been ended
	self:finishLineAndBlock()
	if self.availSpace:AtStartOfLine() then
		self.startOfParagraph = true
	else
		self.needNewParagraph = self.availSpace:GetPos().Y
	end
end
function TextBlockFactory:NewAlignment(alignment)
	alignment = if alignment
		then Assert.Enum(alignment, Enum.TextXAlignment, "alignment")
		else Enum.TextXAlignment.Left
	if alignment == self.alignment then return end
	self:EnsureParagraphEnded()
	self.alignment = alignment
end
function TextBlockFactory:considerLineHeight(lineHeight)
	if not self.textBlock then
		self:newBlock(lineHeight)
		return
	end
	local dif = lineHeight - self.lineHeight
	if dif <= 0 then return end
	local availSpace = self.availSpace
	local textBlock = self.textBlock
	if availSpace:GetWidthRemaining(lineHeight) > 0 then
		textBlock.Size = Vector2.new(textBlock.Size.X, textBlock.Size.Y + dif)
		availSpace:Place(0, lineHeight)
		self.lineHeight = lineHeight
	else
		self:newBlock(lineHeight)
	end
end
function TextBlockFactory:prepareText(lineHeight, text)
	if self.availSpace:AtStartOfLine() and not self.startOfParagraph then -- we've wrapped to a new line
		text = String.LTrim(text)
	end
	return text
end
function TextBlockFactory:GetLastFormat()
	local elements = self.elements
	local last = elements and elements[#elements]
	return if last then last.Format else Format.Plain
end
function TextBlockFactory:newElement(text, format) -- assumes textBlock already exists
	local elements = self.elements
	local last = elements[#elements]
	local concat = self.concat
	if last and concat[1] then
		last.Text = table.concat(concat)
		table.clear(concat)
	end
	table.insert(elements, Elements.Text(text, format))
	concat[1] = text
end
function TextBlockFactory:resizeTrailingNewline(s) -- helps work around a Roblox bug, https://devforum.roblox.com/t/richtext-property-ignores-the-first-space-after-br-or-n-characters/1537936/6
	return if s:sub(-1, -1) == "\n"
		then s:sub(1, -2) .. '<font size="0">\n</font>'
		else s
end
function TextBlockFactory:extend(lineHeight, text, format, size)
	--	text may not have newlines, is assumed to have 1+ characters in it, and is assumed to have a non-whitespace character in it if `startOfLine` is true
	local availSpace = self.availSpace
	if not self.textBlock then
		self:newBlock(lineHeight)
	end
	local last = self.elements[#self.elements]
	local concat = self.concat
	if last and last.Format == format then
		if availSpace:CurrentlyImplicitNewLine() then
			table.insert(concat, self.size0Newline)
			self.textBlock.multiline = true
		elseif self.availSpace:AtStartOfLine() and self.textBlock.multiline then
			local n = #concat
			concat[n] = self:resizeTrailingNewline(concat[n])
		end
		table.insert(concat, text)
	else
		if self.availSpace:AtStartOfLine() and last then -- check for a newline at the end of the previous element
			local n = #concat
			concat[n] = self:resizeTrailingNewline(concat[n])
		end
		self:newElement(text, format)
	end
	if not availSpace:Place(size.X, size.Y) then
		error("availSpace:Place didn't return pos despite algorithm assuming it should fit")
	end
	self.startOfParagraph = false
end
local sizesToResetForIndentation = {
	Header = true,
	LargeHeader = true,
	Chapter = true,
}
local function getFormatToUseForNewLine(format)
	return if format and sizesToResetForIndentation[format.Size]
		then format:With("Size", nil)
		else format
end
function TextBlockFactory:considerNewLineIndent(format)
	--	Assumes that we're at the start of a paragraph
	-- Consider adding any newlines from the indent
	-- Note that we don't want to to add newline indents when already at the top of the page
	if self.availSpace:AtTopOfPage() then return end
	local formatToUse = getFormatToUseForNewLine(format)
	local fullIndent = self.preRender:GetParagraphIndent()
	local numNewLines = #fullIndent:match("\n*")
	self:explicitNewLines(formatToUse, numNewLines)
end
function TextBlockFactory:ConsiderNewLineIndent(format)
	--	Outside of TextBlockFactory, should only be called when not using Extend when at the start of something that should respect newlines in indentation
	self:EnsureParagraphEnded()
	-- todo similar code exists in :Extend
	-- (we don't check y coordinate of needNewParagraph because it could only be set in EnsureParagraphEnded and current position can't have changed since then)
	if self.needNewParagraph then
		self:explicitNewLines(getFormatToUseForNewLine(self.lastFormat or format), 1)
	end
	self.needNewParagraph = nil

	self:considerNewLineIndent(format)
end
function TextBlockFactory:extendReturnRemaining(text, format, lineHeight, skipInlineIndent)
	--	text may not have newlines
	local config = self.config
	local pr = self.preRender
	local RichText = self.RichText
	local originalText = RichText.HandleEscapes(text)
	local indent = ""
	if self.startOfParagraph and not skipInlineIndent and self.alignment == Enum.TextXAlignment.Left then
		local fullIndent = pr:GetParagraphIndent()
		indent = fullIndent:match("\n*(.*)")
	end
	local availSpace = self.availSpace
	-- If indent is all whitespace, we just measure its width. Otherwise we treat it like the rest of the text.
	-- We don't add pure whitespace because the rest of the line might be a small font (meaning small line height, so the spaces that will fit in that height will be forced to be small), but we want the indent to appear consistent across all lines, regardless of size
	local indentWidth, indentSize
	local whitespaceIndent
	if indent ~= "" then
		whitespaceIndent = indent:match("^[ \t]+$")
		if whitespaceIndent then
			indentWidth = RichText.MeasureTextWithSize(config, indent, math.huge, config:GetSize("Normal")).X
		else
			indentSize = RichText.MeasureTextWithSize(config, indent, math.huge, config:GetSize(format.Size, format.SubOrSuperScript))
			indentWidth = indentSize.X
		end
	else
		indentWidth = 0
	end
	local preparedText = self:prepareText(lineHeight, originalText)
	local function attempt(skipInlineIndent, allowPartialWord, errOnFailure)
		--	If successful, returns text left
		--	Otherwise, either errors (if errOnFailure) or else returns nil
		local effectiveIndent = if skipInlineIndent then "" else indent
		if effectiveIndent == "" and preparedText == "" then return "" end
		local widthLeft = availSpace:GetWidthRemaining(lineHeight) - (if skipInlineIndent then 0 else indentWidth)
		local fits, rest, size = RichText.GetFittingText(config, preparedText, format, widthLeft, not allowPartialWord)
		if #fits > 0 then
			if effectiveIndent ~= "" then
				if whitespaceIndent then
					-- Tell availSpace to move over proper amount
					availSpace:PlaceUnpadded(indentWidth, 1)
					-- Move existing textBlock over
					local textBlock = self.textBlock
					if textBlock then
						local adjust = Vector2.new(indentWidth, 0)
						textBlock.Position += adjust
						textBlock.Size -= adjust
					end
				else
					self:extend(lineHeight, effectiveIndent, format, indentSize)
				end
			end
			self:extend(lineHeight, fits, format, size)
			if rest == "" then
				return ""
			else
				self:ensureWrappedToNewLine(format)
				return rest
			end
		end
		if errOnFailure then
			print("'" .. effectiveIndent .. preparedText .. "'", format, widthLeft, "|", fits, rest, size)
			error("Failed to place text on blank page")
		end
	end
	local v
	v = attempt(false, false); if v then return v end
	if not self.availSpace:AtStartOfLine() then
		local changed = self:ensureWrappedToNewLine(format)
		if changed then
			preparedText = self:prepareText(lineHeight, originalText)
			v = attempt(false, false); if v then return v end
		end
	end
	-- We're at the start of a new line
	-- Try accepting a partial word
	v = attempt(false, true); if v then return v end
	if indentWidth > 0 then -- try even without the indent
		v = attempt(true, true)
	end
	-- Now move past bottom of next object while one exists
	while availSpace:GetBottomOfNextObject() do
		availSpace:AdvanceToBottomOfNextObject()
		v = attempt(false, true) or attempt(true, true); if v then return v end
	end
	-- Last attempt: move to new page
	pr:NewPage()
	return attempt(false, true) or attempt(true, true, true)
end
function TextBlockFactory:Extend(text, format, lineHeight, skipInlineIndent)
	--	skipInlineIndent can be true to skip any non-newline characters in the indentation (only relevant if at the start of a new paragraph)
	if self.needNewParagraph == self.availSpace:GetPos().Y then
		self:explicitNewLines(getFormatToUseForNewLine(self.lastFormat or format), 1)
	end
	self.needNewParagraph = nil
	if self.startOfParagraph then
		self:considerNewLineIndent(format) -- note: we could have this in the while loop below, except we want the first indent to use the previous line size (which may be modified when we call considerLineHeight)
	end
	local nextParagraph = text:gmatch("(\n*)([^\n]*)")
	local newLines
	newLines, text = nextParagraph()

	self:considerSubSuper(format, lineHeight)
	self:considerLineHeight(lineHeight)
	while true do
		self:explicitNewLines(format, #newLines)
		while text ~= "" do
			local before = text
			text = self:extendReturnRemaining(text, format, lineHeight, skipInlineIndent)
			if before == text then
				print("Text:", text)
				error("extendReturnRemaining did not use any text")
			end
		end
		newLines, text = nextParagraph()
		if not newLines then break end
		if newLines ~= "" then -- this is the start of a new paragraph (though we don't bother to record it in the startOfParagraph variable)
			self:ensureWrappedToNewLine(format) -- ensure that we are implicitly on a new line
			self:considerNewLineIndent(format)
		end
	end
	self.lastFormat = format
end
function TextBlockFactory:newLine(format)
	local lineHeight = self.config:GetSize(format.Size)
	if self.availSpace:NewLine(self.lineHeight or lineHeight) then -- note that :NewLine expects the previous line's height, not the new line height
		local textBlock = self.textBlock
		self:postNewLine(lineHeight)
		if textBlock and textBlock == self.textBlock then
			if self:GetLastFormat().Size == format.Size then
				table.insert(self.concat, "\n")
			else
				self:newElement("\n", format)
			end
		end
	else
		self.preRender:NewPage()
	end
end
function TextBlockFactory:ensureWrappedToNewLine(format) -- returns true if something changed
	local availSpace = self.availSpace
	if self.ensureWrappedPos == availSpace:GetPos() then return false end
	self:lineFinished()
	local lineHeight = self.config:GetSize(format.Size)
	if availSpace:EnsureWrappedToNewLine(lineHeight) then
		self:postNewLine(lineHeight)
	else
		self.preRender:NewPage()
	end
	self.ensureWrappedPos = availSpace:GetPos()
	return true
end
function TextBlockFactory:postNewLine(lineHeight) -- what to do after a new line has been reached
	local availSpace = self.availSpace
	local textBlock = self.textBlock
	if TBF_MERGES_BLOCKS then
		-- If the available width or starting x is not the same as before, we want a new text block.
		local pos = availSpace:GetPos()
		if not textBlock or availSpace:GetX() ~= textBlock.Position.X or availSpace:GetWidthRemaining(lineHeight) ~= textBlock.Size.X then
			self:newBlock(lineHeight)
		else
			-- increase height for next line
			textBlock.Size += Vector2.new(0, lineHeight)
			self.lineHeight = lineHeight
			textBlock.multiline = true
		end
	else
		self:finishLineAndBlock() -- TODO this is debug; used to be next line -- but with it enabled, we can end up with an empty textbox on a new line (especially problematic if it's a new page) -- I'm trying to figure out how to not create it in the first place. (Note: error occurs atm because 'concat' has a value, but there's no textBlock anywhere...)
		--self:newBlock(lineHeight)
	end
end
function TextBlockFactory:explicitNewLines(format, num)
	--	Adds the specified number of new lines
	--	Starts a new paragraph
	if num == 0 then return end
	num = num or 1
	self:lineFinished()
	if self.availSpace:CurrentlyImplicitNewLine() then -- if we just wrapped to a new line implicitly, ignore a single explicit newline
		self:ensureWrappedToNewLine(format)
		num -= 1
		self.availSpace:ResetImplicitNewLine()
	end
	for i = 1, num do
		self:newLine(format)
	end
	self.startOfParagraph = true
	self:postNewLine(self.config:GetSize(format.Size))
end

local function exitOperation(self, ...)
	self.inOperation = false
	self.lastPos = self.availSpace:GetPos()
	return ...
end
local function wrapOperation(fn)
	return function(self, ...)
		if self.inOperation then
			return fn(self, ...)
		else
			self.inOperation = true
			local curPos = self.availSpace:GetPos()
			local lastPos = self.lastPos
			if lastPos ~= curPos then
				if lastPos.Y ~= curPos.Y then
					self:finishLineAndBlock()
				else
					self:finishBlock()
				end
				-- self.startOfParagraph = false
				--if self.availSpace:CurrentlyImplicitNewLine() then
				if self.availSpace:CurrentlyImplicitNewLine() then
					self.ensureWrappedPos = curPos
				end
			end
			return exitOperation(self, fn(self, ...))
		end
	end
end
-- For every public function that has the power to change where availSpace is (that doesn't just call finishLineAndBlock like :Finish), wrap it in an operation check:
for _, name in {"NewPage", "NewChapter", "Extend", "ConsiderNewLineIndent"} do
	TextBlockFactory[name] = wrapOperation(TextBlockFactory[name])
end

return TextBlockFactory