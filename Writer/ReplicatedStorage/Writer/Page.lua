local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage.Utilities
local Class = require(Utilities.Class)

local Page = Class.New("Page")
function Page.new(bookContent, index, elements)
	return setmetatable({
		bookContent = bookContent,
		Index = index,
		Elements = elements or {},
	}, Page)
end
function Page:IsLeftSidePage()
	return self.Index % 2 == 1
end
function Page:GetSemiFormattedPageNumber()
	return self.bookContent:GetSemiFormattedPageNumber(self.Index)
end
function Page:GetFormattedPageNumberForRender()
	return self.bookContent:GetFormattedPageNumberForRender(self.Index)
end
return Page