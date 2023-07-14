local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Writer = ReplicatedStorage.Writer
local Format = require(Writer.Format)
local RichTextCompiler = require(Writer.RichTextCompiler)
local	formatKeyToTag = RichTextCompiler.FormatKeyToTag

local ServerStorage = game:GetService("ServerStorage")

local RichText = {
	HandleEscapes = RichTextCompiler.HandleEscapes, -- function(text)
	--	Escape user text to avoid conflict with Roblox's RichText formatting
	Unescape = RichTextCompiler.Unescape, -- function(text)
	--	Useful if you want to measure the size of unformatted text quickly (TextService:GetTextSize is much faster than RichText.MeasureText)
	FromTextElements = RichTextCompiler.FromTextElements, -- function(elements, config, alreadyEscaped) -> richText, textSize
}

local TextService = game:GetService("TextService")
local measuringGui = Instance.new("ScreenGui")
measuringGui.Name = "MeasuringGui"
measuringGui.Parent = ServerStorage
local measuringLabel = Instance.new("TextLabel")
measuringLabel.Name = "MeasuringLabel"
measuringLabel.RichText = true
measuringLabel.BackgroundTransparency = 1
measuringLabel.TextTransparency = 1
measuringLabel.TextWrapped = true
measuringLabel.Parent = measuringGui
local prevConfig
local prevConfigSizeOverride
function RichText.MeasureText(config, text, maxWidth)
	if config ~= prevConfig then
		prevConfig = config
		prevConfigSizeOverride = config.NormalSize
		config:ApplyDefaultsToLabel(measuringLabel)
	end
	measuringLabel.Size = UDim2.new(0, maxWidth or 1e6, 0, 1e6)
	measuringLabel.Text = text
	return measuringLabel.TextBounds
end
local measureText = RichText.MeasureText
function RichText.MeasureTextWithSize(config, text, maxWidth, defaultSize)
	if config ~= prevConfig or prevConfigSizeOverride ~= (defaultSize or error("defaultSize not optional", 2)) then
		prevConfig = config
		prevConfigSizeOverride = defaultSize
		config:ApplyNonSizeDefaultsToLabel(measuringLabel)
		measuringLabel.TextSize = defaultSize
	end
	measuringLabel.Size = UDim2.new(0, maxWidth or 1e6, 0, 1e6)
	measuringLabel.Text = text
	return measuringLabel.TextBounds
end

local unescape = RichText.Unescape
local sizeAffectingKeys = Format.SizeAffectingKeys
local unlimitedSpace = Vector2.new(1e6, 1e6)
function RichText.GenerateMeasureRichText(config, format)
	--	This is useful for measuring RichText (of uniform format)
	if format:SizeEqualsBesidesSize(Format.Plain) then
		-- TextService:GetTextSize is a bit faster (both to set up and to run)
		local font = config:GetFont(format.Font)
		local size = config:GetSize(format.Size, format.SubOrSuperScript)
		return function(text, maxWidth)
			return TextService:GetTextSize(unescape(text), size, font, if maxWidth then Vector2.new(maxWidth, 1e6) else unlimitedSpace)
		end
	end
	local formatString = {}
	local stack = {}
	local n = 0
	for _, key in sizeAffectingKeys do
		local value = format[key]
		if value then
			local tag
			if key == "SubOrSuperScript" then
				if format.Size then continue end
				tag = formatKeyToTag.Size
				value = "Normal" -- Size tag wants a value of Normal/Small/Large
			else
				tag = formatKeyToTag[key]
			end
			n += 1
			formatString[n] = tag.Open(config, value, format)
			stack[n] = tag
		end
	end
	n += 1; formatString[n] = "%s"
	for i = #stack, 1, -1 do
		local tag = stack[i]
		n += 1; formatString[n] = tag.Close(config, format[tag.Key])
	end
	local formatString = table.concat(formatString)
	return function(text, maxWidth)
		return measureText(config, formatString:format(text), maxWidth)
	end
end

local okayToSplitChars = "[%s%c]"
local txtToBounds = {} -- (this is for efficiency; it's cleared at the beginning of GetFittingText)
local function genGetFittingText(generateMeasureRichText)
	return function(config, text, format, maxWidth, okayToReturnNothing)
		--	text must be entirely of 'format' (it must not contain any rich text tags)
		--	Returns fits, rest, size
		--		'fits' is the largest substring of text that fits on one line within maxWidth pixels
		--		'rest' is anything that doesn't fit (or "" if it all fits)
		--		'size' is the Vector2 pixel size of 'fits'
		--	Supports utf8
		--	If 'okayToReturnNothing', if 'text' should not be broken up (for example, because it's all one word) an empty string will be returned instead of returning a partial word
		local measure = generateMeasureRichText(config, format)

		local numChars = utf8.len(text)
		local minCharWidth = measure(" ").X
		local lower, upper = 0, math.min(numChars, math.floor(maxWidth / minCharWidth) + 1) -- the minimum/maximum number of characters that might fit, except that 'upper' is to be out of range (except in the beginning, if it equals numChars, the string *might* fit -- we check this first)
		if upper <= lower then return "", text, Vector2.new() end
		local textBounds = measure(if upper >= numChars
			then text
			else text:sub(1, utf8.offset(text, upper + 1) - 1)) -- see utf8.offset comment below
		local lowerWidth, upperWidth = 0, textBounds.X
		if upper == numChars and upperWidth <= maxWidth then -- entire string fits
			return text, "", textBounds
		end
		table.clear(txtToBounds)
		local lowerText = ""
		while lower + 1 < upper do
			local widthAvailable = maxWidth - lowerWidth
			local estimate = lower + math.floor(widthAvailable / (upperWidth - lowerWidth) * (upper - lower))
			estimate = if estimate <= lower then lower + 1
				elseif estimate >= upper then upper - 1
				else estimate
			local estimateText = text:sub(1, utf8.offset(text, estimate + 1) - 1) -- uft8.offset returns where the codepoint starts; we want where 'estimate' ends
			local bounds = measure(estimateText)
			local estimateWidth = bounds.X
			txtToBounds[estimateText] = bounds
			if estimateWidth > maxWidth then
				upper, upperWidth = estimate, estimateWidth
			elseif estimateWidth < maxWidth then
				lower, lowerWidth = estimate, estimateWidth
				lowerText = estimateText
			else -- Estimate was the perfect width
				lower, lowerWidth = estimate, estimateWidth
				lowerText = estimateText
				break
			end
		end
		-- Don't split up words unless they're really long
		local n = #lowerText -- due to uft8, `n` may not equal `lower`
		local twoChars = text:sub(n, n + 1)
		-- if there's not one of our okay-to-splits we must find a split point
		-- can't do utf8 because of curly quotes
		if not twoChars:find(okayToSplitChars) then
			local subStart = math.max(n - 20, 1)
			local reversed = text:sub(subStart, n):reverse()
			local i = reversed:find(okayToSplitChars)
			if i then
				local reversedLength = n - subStart + 1
				i = subStart + reversedLength - i
				lowerText = text:sub(1, i)
				return lowerText, text:sub(i + 1), txtToBounds[lowerText] or measure(lowerText)
			elseif okayToReturnNothing then
				return "", text
			end
		end
		return lowerText, text:sub(n + 1), Vector2.new(lowerWidth, textBounds.Y)
	end
end
RichText.GetFittingText = genGetFittingText(RichText.GenerateMeasureRichText) -- function(config, text, format, maxWidth, okayToReturnNothing) -- see genGetFittingText for details


-- Desync section (for use in actors)
-- Note that the Desync measurements are *approximations*
--	Sometimes fonts will put certain combinations of characters closer together (such as `,"`).
local Desync = {}
local ParallelTasks = require(ReplicatedStorage.Writer.findParallelTasks) -- note: may be nil if on client side, in which case the Desync functionality is not usable
if ParallelTasks then
	local function defaultDictionary(new)
		return setmetatable({}, {__index = function(self, key)
			local value = new()
			self[key] = value
			return value
		end})
	end
	local charSize -- [family][textSize][category][character] = width, unless `character` is "" [for "no character" (as some fonts have a base size for some categories)] in which case the value is a Vector2
	-- Note that, technically, some fonts have combinations of characters that are quite different
	charSize = defaultDictionary(function() -- [family] = ...
		return {} --[textSize] = (see newTextSizeValue)
	end)
	local charSize_newTextSizeValue = function()
		return defaultDictionary(function() -- [category] = ...
			return {} -- [character] = width (or Vector2 for "")
		end)
	end

	local chars = {}
	for i = 32, 126 do
		table.insert(chars, string.char(i))
	end
	local categoryToWeight = {
		Normal = Enum.FontWeight.Regular,
		Italics = Enum.FontWeight.Regular,
		Bold = Enum.FontWeight.Bold,
		BoldItalics = Enum.FontWeight.Bold,
	}
	local categoryToStyle = {
		Normal = Enum.FontStyle.Normal,
		Italics = Enum.FontStyle.Italic,
		Bold = Enum.FontStyle.Normal,
		BoldItalics = Enum.FontStyle.Italic,
	}
	-- local uniqueSizes = {} do
	-- 	local uniqueSizesSet = {}
	-- 	for _, size in require(script.Parent.Sizes) do
	-- 		if not uniqueSizesSet[size] then
	-- 			uniqueSizesSet[size] = true
	-- 			table.insert(uniqueSizes, size)
	-- 		end
	-- 	end
	-- end

	local HttpService = game:GetService("HttpService")
	local n = (script:GetAttribute("n") or 0) + 1
	script:SetAttribute("n", n)
	local parent = if game:GetService("RunService"):IsServer() then ServerStorage else ReplicatedStorage
	local fillInSizesFor
	local waitForCharSizeReady = parent:FindFirstChild("Writer_RichText_WaitForCharSizeReady")
	if not waitForCharSizeReady then
		waitForCharSizeReady = Instance.new("BindableFunction")
		waitForCharSizeReady.Name = "Writer_RichText_WaitForCharSizeReady"
		waitForCharSizeReady.Parent = parent
		local function getChild(name)
			local obj = waitForCharSizeReady:FindFirstChild(name)
			if not obj then
				obj = Instance.new("Folder")
				obj.Name = name
				obj.Parent = waitForCharSizeReady
			end
			return obj
		end
		local threads = {}
		local processing = false
		fillInSizesFor = function(family, textSize)
			-- Note: we are in synchronized mode for the duration of the BindableFunction call
			if processing then
				threads[coroutine.running()] = true
				coroutine.yield()
				ParallelTasks.ConsiderSyncYield()
			end
			local familyTable = charSize[family]
			local sizeTable = familyTable[textSize]
			if not sizeTable then
				processing = true
			-- [disabled] While we're synchronized, we get all the characters for each size that could be used with default textSize and for each category
			-- for i, mult in uniqueSizes do
			-- 	if i ~= 1 then ParallelTasks.ConsiderSyncYield() end
			-- 	local size = math.floor(textSize * mult + 0.5)
			-- 	if familyTable[size] then continue end -- this size already done. Note that familyTable[size] is not connected to a default dictionary.
				sizeTable = charSize_newTextSizeValue()
				familyTable[textSize] = sizeTable
				measuringLabel.TextSize = textSize
				for category, weight in categoryToWeight do
					local t = sizeTable[category]
					measuringLabel.Size = UDim2.new(0, 1e6, 0, 1e6)
					measuringLabel.FontFace = Font.fromName(family, weight, categoryToStyle[category])
					for _, c in chars do
						measuringLabel.Text = c
						t[c] = measuringLabel.TextBounds.X
					end
					measuringLabel.Text = ""
					t[""] = {X = measuringLabel.TextBounds.X, Y = measuringLabel.TextBounds.Y} -- Vector2 doesn't transmit via JSONEncode
				end
				-- now export the cache for other vms
				getChild(family):SetAttribute(tostring(textSize), HttpService:JSONEncode(sizeTable))
				processing = false
			end
			local co = next(threads)
			if co then
				threads[co] = nil
				task.spawn(co)
			end
			return sizeTable
		end
		function waitForCharSizeReady.OnInvoke(family, textSize)
			fillInSizesFor(family, textSize) -- importantly we don't return anything
		end
	else
		fillInSizesFor = function(family, textSize)
			-- See if it's already been done
			local ch = waitForCharSizeReady:FindFirstChild(family)
			local attr = ch and ch:GetAttribute(tostring(textSize))
			if attr then
				local result = HttpService:JSONDecode(attr)
				charSize[family][textSize] = result
				return result
			else
				local id = {}
				task.synchronize()
				waitForCharSizeReady:Invoke(family, textSize)
				task.desynchronize()
				return charSize[family][textSize] or fillInSizesFor(family, textSize)
			end
		end
	end
	waitForCharSizeReady.AncestryChanged:Connect(function(child, parent)
		if parent then return end
		table.clear(charSize)
	end)
	function Desync.ClearMemory() -- if Desync is only used in initialization, call this to clear a lot of unnecessary memory usage
		waitForCharSizeReady:Destroy()
	end

	local function getCharSize(family, textSize, category)
		textSize = math.floor(textSize)
		return (charSize[family][textSize] or fillInSizesFor(family, textSize))[category]
	end
	local function desyncMeasureText(charSize, text, maxWidth)
		local baseLineWidth = charSize[""].X
		local lineHeight = charSize[""].Y
		local sizeX = baseLineWidth
		local sizeY = lineHeight
		if maxWidth and maxWidth < 1e6 then
			for i = 1, #text do
				local width = charSize[text:sub(i, i)] or charSize["W"] -- W is a wide character; may approximate non-standard character sizes
				local newSizeX = sizeX + width
				if sizeX > maxWidth then -- new line
					sizeY += lineHeight
					sizeX = baseLineWidth + width
				else
					sizeX = newSizeX
				end
			end
		else
			for i = 1, #text do
				sizeX += charSize[text:sub(i, i)] or charSize["W"] -- W is a wide character; may approximate non-standard character sizes
			end
		end
		ParallelTasks.ConsiderYield()
		return Vector2.new(sizeX, sizeY)
	end
	function Desync.MeasureText(config, text, maxWidth)
		local font = config.Font
		local charSize = getCharSize(config.DefaultFont.Name, config.NormalSize, "Normal")
		return desyncMeasureText(charSize, text, maxWidth)
	end
	function Desync.MeasureTextWithSize(config, text, maxWidth, defaultSize)
		local font = config.Font
		local charSize = getCharSize(config.DefaultFont.Name, defaultSize, "Normal")
		return desyncMeasureText(charSize, text, maxWidth)
	end
	local function formatToCategory(format)
		return if format.Bold
			then if format.Italics
				then "BoldItalics"
				else "Bold"
			elseif format.Italics then "Italics"
			else "Normal"
	end
	function Desync.GenerateMeasureRichText(config, format)
		local charSize = getCharSize(
			config:GetFont(format.Font).Name,
			config:GetSize(format.Size, format.SubOrSuperScript),
			formatToCategory(format))
		return function(text, maxWidth)
			return desyncMeasureText(charSize, text, maxWidth)
		end
	end
	Desync.GetFittingText = genGetFittingText(Desync.GenerateMeasureRichText)
	for k, v in RichText do
		if Desync[k] == nil then
			Desync[k] = v
		end
	end
	RichText.Desync = Desync
end -- end of Desync section


return RichText