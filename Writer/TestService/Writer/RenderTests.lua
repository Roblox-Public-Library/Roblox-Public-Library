if false then return false end -- disable test
return function(tests, t)


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Writer = ReplicatedStorage.Writer
local RichText = require(Writer.RichText)
local ReaderConfig = require(Writer.ReaderConfig)
local PreRender = require(Writer.PreRender)
local Render = require(Writer.Render)
local CustomMarkdown = require(Writer.CustomMarkdown)

local config = ReaderConfig.new(Enum.Font.SourceSans, 20, require(Writer.Colors).Light)
local pageSizes = {Vector2.new(200, 100), Vector2.new(400, 200), Vector2.new(200, 200)}
local pageSize, pageSize2 = pageSizes[1], pageSizes[2]
local plainFormat = require(Writer.Format).new()

local sg = game.StarterGui:FindFirstChild("RenderVisualTest")
local columns = {}
local numColumns = 4
if sg then
	for i = 1, numColumns do
		columns[i] = sg["Column" .. i]
		columns[i]:ClearAllChildren()
	end
else
	sg = Instance.new("ScreenGui")
	sg.Name = "RenderVisualTest"
	sg.Parent = game.StarterGui
	local x = 0
	for i = 1, numColumns do
		local column = Instance.new("Frame")
		column.Name = "Column" .. i
		local pageSize = pageSizes[i] or pageSizes[#pageSizes]
		column.Position = UDim2.new(0, x, 0, 0)
		column.Size = UDim2.new(0, pageSize.X, 0, pageSize.Y)
		x += pageSize.X + 11
		column.AutomaticSize = Enum.AutomaticSize.Y
		column.Parent = sg
		columns[i] = column
	end
end
for i, column in columns do
	Instance.new("UIListLayout", column)
end
local column1, column2 = columns[1], columns[2]

local function preRenderText(text, pageSize)
	return PreRender.All(CustomMarkdown.ParseTextErrOnIssue(text), pageSize, config).Pages
end
tests.VisualTest = {
	test = function(column, text)
		local pageSize = PreRender.GetOuterPageSize(if column == column1 then pageSize else pageSize2)
		local page = preRenderText(text, pageSize)[1]
		local pageFrame = Instance.new("Frame")
		pageFrame.Size = UDim2.new(0, pageSize.X, 0, pageSize.Y)
		pageFrame.Parent = column
		Render.Page(page, pageFrame, config)
	end,
	argsLists = {
		{column1, "<green>**hi**</color> *there*\nline2<bar><bar,-!->"},
		{column1, "Line1<sub,s**u**b><small> Text<sub,sub></small>\nLine2<sup,2 sup>\nLine3\nLine4<sub>sub text **indeed**</sub>"},
		{column1, ("Before<image,132203618,20x20,left> After and a **lot** more text @ after that so that we can test the *wrapping* system @x@y@z"):gsub("@", "\240\159\152\128")},
		{column2, "<chapter,Chapter with really long name>Chapter text<indent><header,Header>Header <stroke,red,2,0.5>text"},
		{column1, [[<image,132203618,100x100>]]},
		{column2, [[
<indent,none><center><stroke,(50 255 0),1,0><header,large,Title: Name>
By: Author</stroke>
<large>Roblox Library Community</large>
<left>
Librarian: Lib
Published On: whenever

<color,(50 255 0)>hi there</color>

Author's note here]]},
		{column1, "text1\n<center>text2\n<left> \ntext3"},
		{column1, "<image,132203618,20x20,right><image,132203618,20x20,center>"}
	},
}

local column3, column4 = columns[3], columns[4]
function tests.MultiPageTest()
	local text = "<chapter,Chapter with really long name>Chapter text<indent><header,Header>Header <stroke,red,2,0.5>text!</stroke>" .. string.rep(" text", 50) .. string.rep(" text2", 50)
	local pageSize = PreRender.GetOuterPageSize(pageSizes[#pageSizes])
	local pages = preRenderText(text, pageSize)
	for i = 1, #pages do
		local column = if i % 2 == 1 then column3 else column4
		local pageFrame = Instance.new("Frame")
		pageFrame.Name = "Page " .. i
		pageFrame.Size = UDim2.new(0, pageSize.X, 0, pageSize.Y)
		pageFrame.Parent = column
		Render.Page(pages[i], pageFrame, config)
	end
end


end -- function(tests, t)