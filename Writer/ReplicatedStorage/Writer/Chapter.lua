local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage.Utilities
local Assert = require(Utilities.Assert)
local Class = require(Utilities.Class)

local Writer = script.Parent
local Styles = require(Writer.Styles)
local ChapterNaming = Styles.ChapterNaming
local Elements = require(Writer.Elements)
local Format = require(Writer.Format)
local CustomMarkdown = require(Writer.CustomMarkdown)

local chapterFormat = Format.new({Size = "Chapter"})

local Chapter = Class.New("Chapter")
function Chapter.new(number, startingPageIndex, nameElements, textElements, namingStyle, inheritedFormatting)
	local self = setmetatable({
		Number = number,
		StartingPageIndex = Assert.Integer(startingPageIndex),
		rawNameElements = nameElements,
		rawTextElements = textElements or nameElements,
		-- NameElements and TextElements are constructed below (they are always a list of Text elements) and are to be compiled into Name and Text by PreRender
		chapterNaming = ChapterNaming[namingStyle] or error("No chapter naming style: " .. tostring(namingStyle), 2),
	}, Chapter)
	self:assembleNameTextElements(inheritedFormatting)
	return self
end
local function updateFormat(elements)
	for _, e in ipairs(elements) do
		e.Format = e.Format:WithSizeMult("Chapter"):With("Bold", true)
	end
end
function Chapter:compile(rawElements, inheritedFormatting)
	local cn = self.chapterNaming
	local elements = {}
	local function parseAndAdd(txt)
		local new = CustomMarkdown.ParseTextErrOnIssue(txt, nil, nil, inheritedFormatting)
		updateFormat(new)
		table.move(new, 1, #new, #elements + 1, elements)
	end
	if rawElements then
		for _, txt in ipairs(cn[2]) do
			if txt == true then
				updateFormat(rawElements)
				table.move(rawElements, 1, #rawElements, #elements + 1, elements)
			else
				parseAndAdd(txt:gsub("$Num", tostring(self.Number)))
			end
		end
	else
		for _, txt in ipairs(cn[1]) do
			parseAndAdd(txt:gsub("$Num", tostring(self.Number)))
		end
	end
	return elements
end
function Chapter:assembleNameTextElements(inheritedFormatting)
	-- Combine name/text elements with naming style
	local rawNameElements = self.rawNameElements
	self.NameElements = self:compile(rawNameElements, inheritedFormatting)
	local rawTextElements = self.rawTextElements
	self.TextElements = if not rawTextElements or rawTextElements == rawNameElements
		then self.NameElements
		else self:compile(rawTextElements, inheritedFormatting)
end
function Chapter:GetName() return self.Name end
function Chapter:GetText() return self.Text end
-- function Chapter:GetName()
-- 	local naming = ChapterNaming[self.namingStyle]
-- 	if self.Name then
-- 		if naming.IgnoreNumber then
-- 			return string.format(naming[2], self.Name)
-- 		else
-- 			return string.format(naming[2], self.Number, self.Name)
-- 		end
-- 	else
-- 		return string.format(naming[1], self.Number)
-- 	end
-- end
-- function Chapter:GetText()
-- 	local naming = ChapterNaming[self.namingStyle]
-- 	if self.Text then
-- 		if naming.IgnoreNumber then
-- 			return string.format(naming[2], self.Text)
-- 		else
-- 			return string.format(naming[2], self.Number, self.Text)
-- 		end
-- 	else
-- 		return string.format(naming[1], self.Number)
-- 	end
-- end
return Chapter