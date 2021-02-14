-- Todo use AutomaticSize & AutomaticCanvasSize when Roblox releases it
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiUtils = require(ReplicatedStorage.Gui.Utilities)
local TextService = game:GetService("TextService")

local gui = workspace.CommunityBoards.ContributionsBoard.ContributionsBoard
gui.Adornee = gui.Parent
gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

local content = gui.Content

content.Visible = false
local entries = require(ReplicatedStorage.CommunityBoards.ContributionsInterpreter)(
	require(ReplicatedStorage["Community Boards Config"].Contributions))
content.Visible = true

local sf = content.ScrollingFrame
local template = sf.Contribution
local padding = template.NonImage.UIPadding
local maxXSpace = template.AbsoluteSize.X
local paddingOffset = -(padding.PaddingRight.Offset + padding.PaddingLeft.Offset)
local function genGetTextSizeY(textSize, font, space)
	return function(text)
		return TextService:GetTextSize(text, textSize, font, space).Y
	end
end
local descTemplate = template.NonImage.Description
descTemplate.Parent = nil
local getDescSizeYNoImage = genGetTextSizeY(descTemplate.TextSize, descTemplate.Font, Vector2.new(maxXSpace + paddingOffset, 9999))
local getDescSizeYImage = genGetTextSizeY(descTemplate.TextSize, descTemplate.Font, Vector2.new(maxXSpace + template.NonImage.Size.X.Offset + paddingOffset, 9999))
local credits = template.NonImage.LCredits
local creditsX = credits.Size.X
local getCreditsSizeYNoImage = genGetTextSizeY(credits.TextSize, credits.Font, Vector2.new(maxXSpace * creditsX.Scale + creditsX.Offset + paddingOffset, 9999))
local getCreditsSizeYImage = genGetTextSizeY(credits.TextSize, credits.Font, Vector2.new((maxXSpace + template.NonImage.Size.X.Offset + paddingOffset) * creditsX.Scale + creditsX.Offset, 9999))
template.Parent = nil
local nonImageTemplate = template.NonImage:Clone()
nonImageTemplate.Size = UDim2.new(1, 0, 0, nonImageTemplate.Title.TextSize)
local frames = {}
local credits = entries.Credits
for i, entry in ipairs(entries) do
	local top, f, getDescSizeY, getCreditsSizeY
	if entry.Image then
		top = template:Clone()
		top.Image.Image = entry.Image
		f = top.NonImage
		getDescSizeY = getDescSizeYImage
		getCreditsSizeY = getCreditsSizeYImage
	else
		top = nonImageTemplate:Clone()
		f = top
		getDescSizeY = getDescSizeYNoImage
		getCreditsSizeY = getCreditsSizeYNoImage
	end
	f.Title.Text = entry.Title
	f.Date.Text = entry.Date

	local descSize
	if entry.Description then
		descTemplate:Clone().Parent = f
		f.Description.Text = entry.Description
		descSize = getDescSizeY(entry.Description)
		f.Description.Size = UDim2.new(1, 0, 0, descSize)
	else
		descSize = 0
	end
	f.LCredits.Position = UDim2.new(0, 0, 0, 40 + descSize)
	f.RCredits.Position = UDim2.new(1, 0, 0, 40 + descSize)

	-- Distribute credits to both columns (taking up an equal amount of space)
	local iForward, iBackward = 1, #credits
	local left, right = {}, {}
	local leftY, rightY = 0, 0 -- size of each credits so far
	local function addCredit(credit, toList)
		--	Returns textSizeY (defaults to 0 if nothing added)
		local list = entry[credit.Key]
		local text
		if list then
			text = string.format("<b>%s</b> - %s", credit.Desc, table.concat(list, ", "))
			toList[#toList + 1] = text
			return getCreditsSizeY(text)
		end
		return 0
	end
	while iForward <= iBackward do
		if leftY <= rightY then
			leftY += addCredit(credits[iForward], left)
			iForward += 1
		else
			rightY += addCredit(credits[iBackward], right)
			iBackward -= 1
		end
	end
	local n = #right
	if n > 0 then
		-- Reverse the right
		for i = 1, n / 2 do
			right[i], right[n - i + 1] = right[n - i + 1], right[i]
		end
		f.RCredits.Text = table.concat(right, "\n")
		f.RCredits.Size = UDim2.new(f.RCredits.Size.X, UDim.new(0, rightY))
	else
		f.RCredits:Destroy()
	end
	f.LCredits.Text = table.concat(left, "\n")
	f.LCredits.Size = UDim2.new(f.LCredits.Size.X, UDim.new(0, leftY))
	f.Size = UDim2.new(f.Size.X, UDim.new(0, math.max(f.Size.Y.Offset, f.LCredits.Position.Y.Offset + math.max(leftY, rightY))))
	if top ~= f then
		top.Size = UDim2.new(top.Size.X, UDim.new(0, math.max(top.Size.Y.Offset, f.Size.Y.Offset)))
	end
	top.LayoutOrder = entry.LayoutOrder
	top.Parent = sf
	frames[i] = top
end
GuiUtils.HandleVerticalScrollingFrame(sf)
template:Destroy()
nonImageTemplate:Destroy()
local optionsFrame = content.Options
local building = optionsFrame.Builds
local scripting = optionsFrame.Scripts
local gfx = optionsFrame.GFX
local ui = optionsFrame.UI
local options = {building, scripting, gfx, ui}
local buttonToFilter = {
	-- Button -> function(entry):bool
	[building] = function(entry) return entry.Builders end,
	[scripting] = function(entry) return entry.Scripters end,
	[gfx] = function(entry) return entry.GFX end,
	[ui] = function(entry) return entry.UI end,
}
local function optionEnabled(button) return button.Font == Enum.Font.SourceSansBold end
local function optionsAllTheSame()
	for i = 2, #options do
		if options[i].Font ~= options[1].Font then return false end
	end
	return true
end
local search = optionsFrame.Search
local function updateFilters()
	local filters = {}
	if not optionsAllTheSame() then
		for _, button in ipairs(options) do
			if optionEnabled(button) then
				filters[#filters + 1] = buttonToFilter[button]
			end
		end
	end
	local msg = search.Text:lower()
	if msg ~= "" then
		filters[#filters + 1] = function(entry)
			for k, v in pairs(entry) do
				if k == "Image" then
					continue
				elseif type(v) == "string" and v:lower():find(msg, 1, true) then
					return true
				elseif type(v) == "table" then
					for _, person in ipairs(v) do
						-- We check the type just in case another table comes along that isn't a list of people
						if type(person) == "string" and person:lower():find(msg, 1, true) then
							return true
						end
					end
				end
			end
			return false
		end
	end
	for i, f in ipairs(frames) do
		local okay = true
		for _, filter in ipairs(filters) do
			if not filter(entries[i]) then
				okay = false
				break
			end
		end
		f.Visible = okay
	end
end
for _, filter in ipairs(options) do
	filter.Font = Enum.Font.SourceSans
	filter.Activated:Connect(function()
		filter.Font = filter.Font == Enum.Font.SourceSans and Enum.Font.SourceSansBold or Enum.Font.SourceSans
		updateFilters()
	end)
end
search:GetPropertyChangedSignal("Text"):Connect(function()
	search.Font = search.Text == "" and Enum.Font.SourceSansItalic or Enum.Font.SourceSans
	updateFilters()
end)