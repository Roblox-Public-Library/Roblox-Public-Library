-- RobloxRichTextRenderer
local p = script.Parent
local Format = require(p.Format)
local Colors = require(p.Colors)
local Cursor = require(p.Cursor)
local Elements = require(p.Elements)
local Sizes = require(p.Sizes)
local ReaderConfig = require(p.ReaderConfig)
local SpaceLeft = require(p.SpaceLeft)

local Utilities = game:GetService("ReplicatedStorage").Utilities
local Table = require(Utilities.Table)
local Algorithms = require(Utilities.Algorithms)
local Text = require(Utilities.Text)

-- TODO Merge these classes into Rendering


local RenderLabel = {}
RenderLabel.__index = RenderLabel
function RenderLabel.new(availSpace, parent, config)
	local s = os.clock()
	local obj = Instance.new("TextLabel")
	config:ApplyDefaultsToLabel(obj)
	obj.RichText = true
	obj.TextWrapped = true
	obj.Parent = parent
	return setmetatable({
		ct = os.clock() - s,
		obj = obj,
		availSpace = availSpace,
		config = config,

		content = {},
		nContent = 0,
		unchangedFormat = {}, -- [key] = value for first character *if* the format hasn't been changed and *if* that formatting type is in formatKeyToProp
		format = {}, -- [key] = value -- current format
		formatStack = {}, -- formatStack is a list of tags from formatTags in the order applied
		--	Roblox forbids <b><i></b></i>, so this lets us figure out which formatting to temporarily drop
	}, RenderLabel)
end
local keyToDefault = {
	Face = "DefaultFont",
	Color = "DefaultColor",
	-- Size already won't ever use the default
}
function RenderLabel:handleFormatting(newFormat)
	--	formats need not have the Format metatable on them
	local s, ns = self.content, self.nContent
	local config = self.config
	local format = self.format
	local formatStack = self.formatStack
	local nFormatStack = #formatStack
	local unchangedFormat = self.unchangedFormat
	local minDropRequired = nFormatStack + 1
	local function getNewFormatValue(key)
		local value = newFormat[key]
		return (not value or value ~= config[keyToDefault[key]]) and value or nil
	end
	for i = 1, nFormatStack do
		local key = formatStack[i].Key
		if format[key] ~= getNewFormatValue(key) then
			minDropRequired = i
			break
		end
	end
	for i = nFormatStack, minDropRequired, -1 do
		local tag = formatStack[i]
		unchangedFormat[tag.Key] = nil
		ns += 1
		s[ns] = tag.Close(config, format[tag.Key]) or error("Close nil")
		format[tag.Key] = nil
		formatStack[i] = nil
	end
	nFormatStack = minDropRequired - 1
	for _, tag in ipairs(formatTags) do
		local key = tag.Key
		local newValue = getNewFormatValue(key)
		if newValue and not format[key] then -- format[key] being truthy means they're already the same
			ns += 1
			s[ns] = tag.Open(config, newValue) or error("Open nil")
			nFormatStack += 1
			formatStack[nFormatStack] = tag
			format[key] = newValue
		end
	end
	if not unchangedFormat then -- This only happens for the first text, when no formatting exists and so it's okay that unchangedFormat is nil in the above code
		self.unchangedFormat = Table.Clone(format)
	end
	self.nContent = ns
end
local TextService = game:GetService("TextService")
local localPlayer = game:GetService("Players").LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local measuringGui = Instance.new("ScreenGui")
measuringGui.Name = "MeasuringGui"
measuringGui.Parent = playerGui
local measuringLabel = Instance.new("TextLabel")
measuringLabel.Name = "MeasuringLabel"
measuringLabel.RichText = true
measuringLabel.BackgroundTransparency = 1
measuringLabel.TextTransparency = 1
measuringLabel.TextWrapped = true
measuringLabel.Parent = measuringGui
local function measureText(text, maxWidth)
	measuringLabel.Size = UDim2.new(0, maxWidth, 1, 0)
	measuringLabel.Text = text
	return measuringLabel.TextBounds
end
--REALIZATION: AvailSpace cannot be reduced by RenderLabels until the RenderLabel finishes!
--	Alternate path: if we measure each word so we know exactly which words are on what line
--	IS THIS A PROBLEM? YES. If we wanted emoticons, when we want superscript/subscript, etc, we need to know.
--	Therefore we must go line-by-line - we can still use a single label, though we might optionally use \n to control it
--		Tested: *do not* put in extra newlines. Instead, detect when Roblox is going to wrap it using TextBounds

function RenderLabel:useSpaceForText(text)
	--	Returns textThatFits, textThatDoesNotFit/nil if it all fit. Consumes availSpace.
	--[[Objectives:
	1. Use self.format to generate a format string that will produce formatting
	ex if bold and italics, we want "<b><i>%s</i></b>"
	2. Keep adding words until it exceeds the available space, then undo one step
	Note: Roblox will eat arbitrary amounts of spaces and tabs at the division between text-wrapped lines unless preceded by an explicit newline
	]]
	-- TODO This algorithm needs to work for PreRender state as well
	--	This means that generateFormatStringForFormatting needs to be based on a TextElement's format
	local formatString = self:generateFormatStringForFormatting():format("%s%s%s")
	local textThatFits = ""
	local prevTextSize, prevNew
	for word, spacing in Text.IterWords(text) do
		local new, textSize
		while true do
			prevTextSize = textSize -- todo here or only on success below?
			prevNew = new
			new = string.format(formatString, textThatFits, word, spacing)
			textSize = measureText(new, self.availSpace.X)
			if textSize.Y > lineHeight then -- NOTE: could use first bounds.Y result if we don't have lineHeight
				if spacing ~= "" then
					new = string.format(formatString, textThatFits, word, "")
					textSize = measureText(new, self.availSpace.X)
					if textSize.Y > lineHeight then
						-- content so far fits on current line (excluding word/spacing)
						if prevNew then
							textThatFits = prevNew
							error("todo")
						else
							error("nothing new on this line so we need to forcefully split 'word'")
						end
					else
						-- content so far (including word) fits on current line
						-- this means that if spacing is just spaces & tabs, we can ignore it (as Roblox will too)
						local leftover = spacing:match("^[ \t]+$") and "" or spacing:match("^[ \t]*(.*\n)")
						if leftover ~= "" then
							error("todo - deal with leftover")
						else
							break -- nothing more to do
						end
					end
				end
				-- content so far fits on current line (excluding word/spacing)
			else
				-- add word/spacing to content for this line
			end
		end
	end
	return textThatFits, textThatDoesNotFit
end
function RenderLabel:AppendText(text, formatting)
	if #text == 0 then return end
	self:handleFormatting(formatting)
	self.nContent += 1
	local nonDisplayedText
	self.content[self.nContent], nonDisplayedText = self:useSpaceForText(text)
	if not self.content[self.nContent] then print(text, nonDisplayedText) error("AppendText nil") end
	return nonDisplayedText
end
function RenderLabel:removeConsistentFormatting()
	local unchangedFormat = self.unchangedFormat
	if next(unchangedFormat) == nil then return end
	-- ex, if <font face="Arial"> is applied everywhere, delete that tag whenever it's found
	-- ORIGINAL PLAN:
	--	Create a set of open and close tags to be removed
	--	Since we need to know the dif between </font> for face vs color etc, replace the closing tags with </face> not </font>
	--	Then correct that in compileContent with a simple conversion dictionary (defaulting to original content).
	--	Only then do we use table.concat -- otherwise we'd have to determine what tags are escaped!
	local new = {}
	local n = 0
	-- todo go through unchangedFormat and remove anything we can't deal with
	--	ex we can't make the entire label
	for _, v in ipairs(self.content) do
		-- todo only if it's a label...
		for tag, value in pairs(unchangedFormat) do
			-- todo remove unchanged formatting from label
		end
	end
	for tag, value in pairs(unchangedFormat) do
		-- todo apply to self.obj (ex if it's )
	end
end
function RenderLabel:compileContent()
	self:removeConsistentFormatting()
	self.obj.Text = table.concat(self.content) -- todo - probably not keeping this as we need to know the size as we go along
end
function RenderLabel:Finish()
	self:handleFormatting({})
	self:compileContent()
	return self.obj, self.availSpace
end

function PreRender(elements, pageSpace)
	--	pageSpace:SpaceLeft -- todo from standardResolution
	--	Returns a list of pages, each page being a list of elements
	-- Keep adding elements (or segments of elements) on the current page until they don't fit (or we run out)
	--	be prepared to split up an element over several pages
	local cursor = Cursor.PreRender.new(pageSpace)
	for _, element in ipairs(elements) do
		element:Handle(cursor)
	end
	return cursor:FinishAndGetPages()
end
function RenderPage(elements, pageSpace, pageInstance)
	--	pageSpace:SpaceLeft
	--	Attaches new instances to pageInstance
	-- todo maybe return a function to invalidate all controls so they can be reused
	--	probably need to receive an object pool manager
	local cursor = Cursor.Render.new(pageSpace, nil, pageInstance)
	for _, element in ipairs(elements) do
		element:Handle(cursor)
	end
	cursor:Finish()
end

do -- MANUAL TEST
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Writer = ReplicatedStorage.Writer
	local parse = require(Writer.CustomMarkdown).ParseText
	local elements = parse(string.rep([[
Test text *some* of which is **bolded** or __underlined__, but most of which is not.
Newline!
<Arial>Varying<Cartoon> fonts<arial, red> should <small>be</font><green><large>okay!</large></green> Before line <line>After line
]], 10))
	--local elements = table.create(10, Elements.HLine.new())
	local x, y = 200, 200
	local space = SpaceLeft.new(x, y)
	local pages = PreRender(elements, space)
	local page = Instance.new("Frame")
	page.Size = UDim2.new(0, x, 0, y)
	page.Position = UDim2.new(.5, 0, .5, 0)
	page.AnchorPoint = Vector2.new(.5, .5)
	local sg = game.StarterGui:FindFirstChild("ScreenGui")
	if not sg then
		sg = Instance.new("ScreenGui")
		sg.Parent = game.StarterGui
	end
	page.Name = "ManualPageRenderTest"
	local obj = sg:FindFirstChild(page.Name)
	if obj then
		obj:Destroy()
	end
	page.Parent = sg
	RenderPage(elements, space, page)
end


local RobloxRichTextRenderer = {}
RobloxRichTextRenderer.__index = RobloxRichTextRenderer
function RobloxRichTextRenderer.new(pageSize, parent, config, colors)
	return setmetatable({
		pageSize = pageSize, --:SpaceLeft
		availSpace = pageSize:Clone(),
		parent = parent, --:Instance
		config = config, --:ReaderConfig
		--currentLabel

		--debug
		ct = 0,
	}, RobloxRichTextRenderer)
end
function RobloxRichTextRenderer:HandleText(text, formatting)
	while true do
		local currentLabel = self.currentLabel
		if not currentLabel then
			currentLabel = RenderLabel.new(self.availSpace, self.parent, self.config)
			self.currentLabel = currentLabel
			self.ct += currentLabel.ct
		end
		local nonDisplayedText = currentLabel:AppendText(text, formatting)
		if nonDisplayedText then
			-- todo get new availSpace.
			--	ex's:
			--		if we're at the bottom of the page, then go to the next page
			--		else, maybe we're half-way down the page and we just got more space on the left due to an image ending
			if self.availSpace.Y < lineHeight then -- todo will availSpace.Y be consumed by AppendText when we're about to move on to the final line (ex image ended just before) or only when we add more text? (if it's advanced, we should check .X vs .AvailWidth as well)
				-- bottom of page
				error("new page") -- easier when we switch this code to cursor
			else
				error("todo how to figure out availSpace after image ended")
			end
			text = nonDisplayedText
		else
			break
		end
	end
end
function RobloxRichTextRenderer:Finish()
	if self.currentLabel then
		self.currentLabel:Finish()
	end
	return self.ct
end
return RobloxRichTextRenderer