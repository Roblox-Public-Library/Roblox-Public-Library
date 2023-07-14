local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assert = require(ReplicatedStorage.Utilities.Assert)
local	Validate = Assert.Validate
local String = require(ReplicatedStorage.Utilities.String)

local BookSearch = {}

local Always, Never = 1, 0
BookSearch.Always = Always
BookSearch.Never = Never
BookSearch.Optional = nil
function BookSearch.ValidateIsOption(v)
	return if v == nil or v == 0 or v == 1 then v else nil
end
local isOption = BookSearch.ValidateIsOption
function BookSearch.ValidateIsTableOfOptions(t)
	t = Validate.Table(t)
	if not t then return nil end
	for k, v in t do
		if type(k) ~= "string" or not isOption(v) then
			t[k] = nil
		end
	end
	return t
end

local typeToSortData = {}
BookSearch.typeToSortData = typeToSortData
do
	BookSearch.SortTypes = {
		-- {.Type, .Name, .AscendingAllowed}
		--	AscendingAllowed can be false or {[false] = descending text, [true] = ascending text, .Default = true/false}
		-- (Name is filled in below)
		{Type = "Recommended", AscendingAllowed = false},
		{Type = "WellLiked", AscendingAllowed = false},
		{Type = "Random", AscendingAllowed = false},
	}
	local alphaAscending = {[true] = "A-Z", [false] = "Z-A", Default = true}
	local numericAscending = {[true] = "0-9", [false] = "9-0", Default = false}
	for _, v in {"Title", "Author", "Genre"} do
		table.insert(BookSearch.SortTypes, {Type = v, AscendingAllowed = alphaAscending})
	end
	for _, v in {"Published", "Pages", "Likes", "Reads"} do
		table.insert(BookSearch.SortTypes, {Type = v, AscendingAllowed = numericAscending})
	end
	for _, st in BookSearch.SortTypes do
		typeToSortData[st.Type] = st
		st.Name = String.CamelCaseToEnglish(st.Type)
	end
end

function BookSearch.ValidateSortType(v)
	return if typeToSortData[v] then v else "Recommended"
end
return BookSearch