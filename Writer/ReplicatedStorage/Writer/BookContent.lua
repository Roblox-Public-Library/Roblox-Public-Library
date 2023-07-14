local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage.Utilities
local Class = require(Utilities.Class)

local Writer = ReplicatedStorage.Writer
local Styles = require(Writer.Styles)
local 	PageNumbering = Styles.PageNumbering
local	PageNumberingSemiFormatted = Styles.PageNumberingSemiFormatted
local RomanNumerals = require(Writer.RomanNumerals)

local BookContent = Class.New("BookContent")
function BookContent.new()
	return setmetatable({
		--[[
		.PageNumbering = List<{
			.StartingPageIndex
			.Style : string from Styles.PageNumbering
			.Invisible : true/nil
			.StartingNumber
		}>,
		.Chapters : List<Chapter>
		.Pages : List<Page>
		(These values do not need to be initialized immediately to allow pages/chapters to reference this instance.)
		]]
		flags = {}, -- flags defined by the book (they don't mean anything to the Writer system but can be used externally) (note: they're all lower-cased)
	}, BookContent)
end
function BookContent:HasFlag(flag)
	return self.flags[flag:lower()]
end
function BookContent:GetSemiFormattedPageNumber(index)
	local pn
	local pns = self.PageNumbering
	for i, v in ipairs(pns) do
		if v.StartingPageIndex > index then
			pn = pns[i - 1]
			break
		end
	end
	if not pn then pn = pns[#pns] end
	local num = index - pn.StartingPageIndex + pn.StartingNumber
	return PageNumberingSemiFormatted[pn.Style](num)
end
function BookContent:GetFormattedPageNumberForRender(index)
	local pn
	local pns = self.PageNumbering
	for i, v in ipairs(pns) do
		if v.StartingPageIndex > index then
			pn = pns[i - 1]
			break
		end
	end
	if not pn then pn = pns[#pns] end
	local relPageIndex = index - pn.StartingPageIndex + 1
	if pn.Invisible == true or pn.Invisible and relPageIndex <= pn.Invisible then
		return ""
	else
		local num = index - pn.StartingPageIndex + pn.StartingNumber
		return PageNumbering[pn.Style](num)
	end
end
function BookContent:getLastPageIndex(i)
	local pn = self.PageNumbering[i + 1]
	return if pn then pn.StartingPageIndex - 1 else #self.Pages
end
function BookContent:GetPageIndexFromNumber(semiFormattedPgNum)
	--	will return the first page index that it could refer to (nil if none found)
	local num = tonumber(semiFormattedPgNum:match("%d+"))
	if not num then
		num = RomanNumerals.ToNumber(semiFormattedPgNum)
	end
	local pns = self.PageNumbering
	if not num then -- try every one
		for i, pn in ipairs(pns) do
			if pn.Style == "invisible" then continue end
			local fn = PageNumberingSemiFormatted[pn.Style]
			for pg = pn.StartingPageIndex, self:getLastPageIndex(i) do
				if fn(pg) == semiFormattedPgNum then
					return pg
				end
			end
		end
		return nil
	end
	for i, pn in ipairs(pns) do
		if pn.Style == "invisible" then continue end
		-- ex, if I go to page 2
		-- but the pages are i,ii,1,2
		-- then I want page 4
		-- to get that, I need the 2nd pn which has StartIndex 3, StartNumber 1
		-- 2 is the page number (num = 2), so to get the page index, we want StartIndex + (num - startingNum)
		if num < pn.StartingNumber then continue end
		local index = pn.StartingPageIndex + (num - pn.StartingNumber)
		if index <= self:getLastPageIndex(i) and PageNumberingSemiFormatted[pn.Style](num) == semiFormattedPgNum then
			return index
		end
	end
end
function BookContent:GetChapterForPageIndex(index)
	local chapters = self.Chapters
	local n = #chapters
	for i = 2, n do
		if chapters[i].StartingPageIndex > index then
			return chapters[i - 1]
		end
	end
	return chapters[n]
end
function BookContent:ChapterStartsOnPage(index)
	local chapters = self.Chapters
	for _, chapter in ipairs(self.Chapters) do
		if chapter.StartingPageIndex == index then
			return true
		end
	end
end
return BookContent