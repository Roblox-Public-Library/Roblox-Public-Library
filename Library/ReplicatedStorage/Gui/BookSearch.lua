local MAX_TEXT_BOX_LENGTH = 50
local SEEN_TIME = 7 -- seconds after which a result is considered "seen"
local BG_PADDING_BOTTOM = 5
local SPACE_BENEATH_RESULTS = 70 -- provide room for toolbar

--[[Command-bar code for updating gradients (horizontal ones only)

co = 0.85; co = Color3.new(co, co, co) -- note: using ~0.76 for major buttons (things not named "Result" and not in GenresScroll)
function BlendGradient(parent, parentGradient, child, childGradient)
	if not childGradient then childGradient = parentGradient:Clone() childGradient.Parent = child end
	childGradient.Transparency = parentGradient.Transparency
	child.BackgroundColor3 = co
	local x1 = (child.AbsolutePosition.X - parent.AbsolutePosition.X) / parent.AbsoluteSize.X
	local x2 = (child.AbsolutePosition.X + child.AbsoluteSize.X - parent.AbsolutePosition.X) / parent.AbsoluteSize.X
	local keys = parentGradient.Color.Keypoints
	local function getColor(t)
		for i, k in keys do
			local k2 = keys[i + 1]
			if k.Time <= t and k2.Time >= t then
				return k.Value:Lerp(k2.Value, (t - k.Time) / (k2.Time - k.Time))
			end
		end
	end
	childGradient.Color = ColorSequence.new(getColor(x1), getColor(x2))
end

function undoable(name, action, ...)
	game:GetService("ChangeHistoryService"):SetWaypoint("Pre" .. name)
	local success, msg = xpcall(action, function(msg) return debug.traceback(msg, 2) end, ...)
	game:GetService("ChangeHistoryService"):SetWaypoint(name)
	if not success then error(msg) end
end

-- 1. Copy/paste the above
-- 2. Select the parent of the background gradient:
bg = game.Selection:Get()[1]

-- 3. Select ancestor to have buttons inherit a gradient from 'bg' (Horizontal Gradient only)
--	Note that this moves any text to a TextLabel because otherwise the gradient will apply to the text as well
undoable("Gradients", function()
	for _, c in game.Selection:Get()[1]:GetDescendants() do
		if c:IsA("TextButton") and c.AutoButtonColor then
			if c.Text ~= "" then
				local x = convertObj(c:Clone(), "TextLabel")
				x.Size = UDim2.new(1, 0, 1, 0)
				x.Position = UDim2.new()
				x.BackgroundTransparency = 1
				x.Active = false
				x.Name = "TextLabel"
				x.Parent = c
				c.Text = ""
			end
			BlendGradient(bg, bg.UIGradient, c, c:FindFirstChild("UIGradient"))
		end
	end
end)

-- Alternatively, if you just want to apply to the selected button:
c = game.Selection:Get()[1]
if not (c:IsA("TextButton") and c.AutoButtonColor) then
	print(c:GetFullName(), "not eligible")
	return
end
undoable("Gradients", function()
	if c.Text ~= "" then
		local x = convertObj(c:Clone(), "TextLabel")
		x.Size = UDim2.new(1, 0, 1, 0)
		x.Position = UDim2.new()
		x.BackgroundTransparency = 1
		x.Active = false
		x.Name = "TextLabel"
		x.Parent = c
		c.Text = ""
	end
	BlendGradient(bg, bg.UIGradient, c, c:FindFirstChild("UIGradient"))
end)
--]]

local module = {}

local TweenService = game:GetService("TweenService")
local tweenInfo = TweenInfo.new(0.3)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dropdown = require(ReplicatedStorage.Gui.Dropdown)

local BookMetrics = require(ReplicatedStorage.Library.BookMetricsClient)
local BookPathfinder = require(ReplicatedStorage.Library.BookPathfinder)
local BookSearch = require(ReplicatedStorage.Library.BookSearch)
local Genres = require(ReplicatedStorage.Library.Genres)
local profile = require(ReplicatedStorage.Library.ProfileClient)
local	searchProfile = profile.Search
local	searchConfig = searchProfile.Config
local	booksProfile = profile.Books
local	bookPouch = profile.BookPouch

local Event = require(ReplicatedStorage.Utilities.Event)
local EventUtilities = require(ReplicatedStorage.Utilities.EventUtilities)
local Functions = require(ReplicatedStorage.Utilities.Functions)
local String = require(ReplicatedStorage.Utilities.String)
local ObjectPool = require(ReplicatedStorage.Utilities.ObjectPool)
local Value = require(ReplicatedStorage.Utilities.Value)

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local BookGui = require(ReplicatedStorage.Gui.BookGui)
BookGui.BookOpened:Connect(BookPathfinder.Clear)

local italicsFont = Font.new("Source Sans Pro", Enum.FontWeight.Regular, Enum.FontStyle.Italic)
local normalFont = Font.new("Source Sans Pro", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

local Always, Never, Optional, Mixed = BookSearch.Always, BookSearch.Never, BookSearch.Optional, "Mixed" -- State Constants
local Checkbox = {} do
	local stateToField = {
		[Always] = "check",
		[Never] = "x",
		[Mixed] = "mixed",
	}
	local stateToNext = {
		["Optional"] = Always, -- must use "Optional" as a string since Optional const is 'nil'
		[Always] = Never,
		[Never] = Optional,
		[Mixed] = Always,
	}
	Checkbox.__index = Checkbox
	function Checkbox.new(button, checkbox, disallowAlways)
		checkbox = checkbox or button:FindFirstChild("Checkbox")
		local self = setmetatable({
			button = button,
			checkbox = checkbox,
			State = Optional,
			mixed = checkbox:FindFirstChild("Neither"),
			x = checkbox.X,
			check = checkbox.Check,
			Changed = Event.new(),
		}, Checkbox)
		self.button.Activated:Connect(function()
			local newState = stateToNext[if self.State == Optional then "Optional" else self.State]
			if disallowAlways and newState == Always then
				newState = stateToNext[Always]
			end
			self:SetState(newState)
		end)
		return self
	end
	function Checkbox:SetStateSilent(newState) -- newState must be one of the state constants
		if self.State == newState then return true end
		local prev = self[stateToField[self.State]]
		if prev then
			prev.Visible = false
		end
		self.State = newState
		local obj = self[stateToField[newState]]
		if obj then
			obj.Visible = true
		end
	end
	function Checkbox:SetState(newState) -- newState must be one of the state constants
		if self:SetStateSilent(newState) then return true end
		self.Changed:Fire(newState)
	end
end

local function genAutoSizeYOffset(size, parent1, parent2, update)
	local sizeX = size.X
	local sizeY = size.Y
	local scale = sizeY.Scale
	local baseOffset = sizeY.Offset
	while parent1 ~= parent2 do
		scale *= parent1.Size.Y.Scale
		parent1 = parent1.Parent
	end
	local function onChange()
		update(UDim2.new(sizeX, UDim.new(0, baseOffset + parent2.AbsoluteSize.Y * scale)), baseOffset, sizeX, scale)
	end
	return function()
		onChange()
		return parent2:GetPropertyChangedSignal("AbsoluteSize"):Connect(onChange)
	end
end
local function genAutoSizeYOffsetInstance(obj, parent, postUpdate)
	return genAutoSizeYOffset(obj.Size, obj.Parent, parent, function(size, baseOffset, sizeX, scale)
		obj.Size = UDim2.new(sizeX, UDim.new(0, baseOffset + parent.AbsoluteSize.Y * scale))
		if postUpdate then
			postUpdate(obj.Size, baseOffset)
		end
	end)
end

local gui = ReplicatedStorage.Guis.BookSearch
gui.Enabled = false
gui.Parent = localPlayer.PlayerGui

local bg = gui.Background
local optionsFrame = gui.Options
local resultsParent = gui.Results
local bottomOfOptions = Value.new(0) -- absolute y position of bottom of options frame (updated later)

local monthNames = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
local getPrettyDate = function(t)
	local d = os.date("!*t", t)
	return string.format("%s %d, %d", monthNames[d.month], d.day, d.year)
end
local bookToNumericDateOrDefault = Functions.Cache(function(book)
	local t = BookSearch.GetDateTime(book.PublishDate)
	if not t then return book.PublishDate end
	local d = os.date("!*t", t)
	return string.format("%02d/%02d/%04d", d.month, d.day, d.year)
end)
local bookToPrettyDate = Functions.Cache(function(book)
	local t = BookSearch.GetDateTime(book.PublishDate)
	return if t then getPrettyDate(t) else false
end)

local handleSortTypeChange

local recordSeenEligible
local shrunk = false
local shrinkSizeY
local stopPathfind
local Results = {}
do
	local RESULT_TRANSPARENCY_EVEN = 0.7
	local RESULT_TRANSPARENCY_ODD = 0.8

	local ResultsTable = {} do
		ResultsTable.HeaderClicked = Event.new()
		local bookFields = {
			-- [controlName] = bookField
			Title = "Title",
			Author = "AuthorLine",
			Genre = "GenreLine",
		}
		local metricsFields = {
			Likes = "Likes",
			Reads = "EReads",
		}
		local customFields = {
			-- [controlName] = function(book, metrics) -> string
			Pages = function(book) return if book.PageCount then tostring(book.PageCount - 2) else "" end,
			Published = bookToNumericDateOrDefault,
		}
		function ResultsTable.UpdateRow(row, book, metrics)
			for name, field in bookFields do
				row[name].Text = book[field]
			end
			for name, field in metricsFields do
				row[name].Text = metrics[field]
			end
			for name, fn in customFields do
				row[name].Text = fn(book, metrics)
			end
		end
		local fieldToHeader = {}
		local fHeaders = resultsParent.Headers
		fHeaders.Visible = false
		for _, c in fHeaders:GetChildren() do
			if c:IsA("Frame") then
				local b = c:FindFirstChildOfClass("TextButton")
				fieldToHeader[b.Name] = b
				b.Activated:Connect(function()
					if shrunk then return end
					ResultsTable.HeaderClicked:Fire(b.Name)
				end)
			end
		end
		local prevHeader
		local headerCon
		function ResultsTable:SortTypeChanged(sortType, sortAscending)
			if headerCon then headerCon:Disconnect() end
			local header = fieldToHeader[sortType]
			if prevHeader then
				prevHeader.Text = prevHeader.Name
			end
			if header then
				if sortAscending == nil then
					sortAscending = BookSearch.GetAscendingDataForSortType(sortType).Default
				end
				local function update()
					local size = math.floor(header.AbsoluteSize.Y * 0.8 + 0.5)
					header.Text = string.format('<font size="%d">%s</font> %s', size, if sortAscending then "▲" else "▼", header.Name)
				end
				update()
				headerCon = header:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
			end
			prevHeader = header
		end

		local resultsFrame = resultsParent.ResultsTable
		resultsFrame.Visible = false
		local resultRowTemplate = resultsFrame.Entry
		ResultsTable.RowTemplate = resultRowTemplate
		resultRowTemplate.Parent = nil

		local rowSize = Value.new() -- all rows change their size when this does
		local percent = 0.95
		local baseRowOffset = resultRowTemplate.Size.Y.Offset
		local cons
		local fHeadersOrigSize = fHeaders.Size
		local autoSize = genAutoSizeYOffsetInstance(fHeaders, gui, function(size, baseOffset)
			local y = (size.Y.Offset - baseOffset) * percent + baseRowOffset
			rowSize:Set(UDim2.new(1, 0, 0, y))
			local padding = resultsParent.UIListLayout.Padding.Offset
			shrinkSizeY = size.Y.Offset + y + padding
			resultsFrame.Size = UDim2.new(1, 0, 1, -size.Y.Offset - padding)
			for _, h in fieldToHeader do
				h.TextSize = h.AbsoluteSize.Y
				for i = 1, h.AbsoluteSize.Y / 2 do
					if h.TextFits then break end
					h.TextSize -= 1
				end
			end
		end)
		function ResultsTable:Install()
			if cons then return end
			fHeaders.Size = fHeadersOrigSize
			cons = {autoSize()}
			resultsFrame.Visible = true
			fHeaders.Visible = true
		end
		function ResultsTable:Uninstall()
			if not cons then return end
			for _, con in cons do con:Disconnect() end
			cons = nil
			resultsFrame.Visible = false
			fHeaders.Visible = false
		end
		ResultsTable.ResultsFrame = resultsFrame
		ResultsTable.RowSize = rowSize
	end
	local ResultsList = {} do
		ResultsList.HeaderClicked = Event.new()
		local metricsFields = {
			Likes = "Likes",
			Reads = "EReads",
		}
		local customFields = {
			-- [controlName] = function(book, metrics) -> string
			Pages = function(book) return if book.PageCount then tostring(book.PageCount - 2) else "" end,
		}
		function ResultsList.UpdateRow(row, book, metrics)
			row.TitleByAuthor.Text = string.format("<b>%s</b> by %s", book.Title, book.AuthorLine)
			local v = bookToPrettyDate(book)
			row.Published.Text = if v then "Published " .. v else book.PublishDate
			local frame = row.Frame
			frame.Genre.Text = book.GenreLine
			for name, field in metricsFields do
				frame[name].Text = metrics[field] .. " " ..
					(if metrics[field] == 1 then name:sub(1, -2) else name)
			end
			for name, fn in customFields do
				local num = fn(book, metrics)
				frame[name].Text = num .. " " ..
					(if num == 1 then name:sub(1, -2) else name)
			end
		end
		function ResultsList:SortTypeChanged() end

		local resultsFrame = resultsParent.ResultsList
		resultsFrame.Visible = false
		local resultRowTemplate = resultsFrame.Entry
		ResultsList.RowTemplate = resultRowTemplate
		resultRowTemplate.Parent = nil

		local rowSize = Value.new(resultRowTemplate.Size) -- all rows change their size when this does
		local baseRowOffset = resultRowTemplate.Size.Y.Offset
		local cons
		local autoSize = genAutoSizeYOffset(resultRowTemplate.Size, resultsFrame, gui, function(size, baseOffset)
			rowSize:Set(size)
			shrinkSizeY = size.Y.Offset
		end)
		function ResultsList:Install()
			if cons then return end
			cons = {autoSize()}
			resultsFrame.Visible = true
		end
		function ResultsList:Uninstall()
			if not cons then return end
			for _, con in cons do con:Disconnect() end
			cons = nil
			resultsFrame.Visible = false
		end
		ResultsList.ResultsFrame = resultsFrame
		ResultsList.RowSize = rowSize
	end

	local curMode
	local spareRows
	local rowTemplate, resultsFrame, rowSize, padding
	local modeToSpareRows = {}
	Results.List = ResultsList
	Results.Table = ResultsTable

	local results
	local nResults
	local cons = {}
	local function clearCons()
		for _, con in cons do
			con:Disconnect()
		end
		table.clear(cons)
	end
	local getYPos, yToRowIndex
	local bookToRow = {}
	local function updateCanvasSize()
		-- Resize canvas size based on # results and rowSize.Value.Y.Offset
		local rowHeight = rowSize.Value.Y.Offset

		local sizeY = math.max(nResults * rowHeight + (nResults - 1) * padding, resultsFrame.AbsoluteWindowSize.Y)
		resultsFrame.CanvasSize = UDim2.new(0, 0, 0, sizeY)
		local paddedRowHeight = rowHeight + padding
		getYPos = function(i)
			return (i - 1) * paddedRowHeight
		end
		yToRowIndex = function(y)
			return math.floor(y / paddedRowHeight) + 1
		end
	end
	local function calcVisibleRows()
		-- calc which results should be even partially on screen (even 1 pixel overlapping with top/bottom)
		if nResults == 0 then
			for _, row in bookToRow do
				spareRows:Release(row)
			end
			return
		end
		local top = resultsFrame.CanvasPosition.Y
		local bottom = top + resultsFrame.AbsoluteWindowSize.Y
		local topRowI = math.min(yToRowIndex(top), nResults)
		local bottomRowI = math.min(yToRowIndex(bottom), nResults)
		-- Note: rows clear themselves when they are offscreen, we just need to show the new ones (and potentially update existing ones)
		local allMetrics = BookMetrics.Get()
		local shouldBeThere = {}
		for i = topRowI, bottomRowI do
			local book = results[i]
			shouldBeThere[book] = true
			local row = bookToRow[book]
			if not row then
				row = spareRows:Get()
				-- Note: Row:SetData assigns to bookToRow
				row:SetData(book, allMetrics[book.Id])
			end
			row:Show(i, getYPos(i))
		end
		for book, row in bookToRow do
			if not shouldBeThere[book] then
				spareRows:Release(row)
			end
		end
	end
	local calcVisibleRowsDeferred = Functions.DeferWithDebounce(calcVisibleRows)
	function Results:SetResults(_results)
		results = _results
		nResults = #results
		clearCons()

		resultsFrame.CanvasPosition = Vector2.new(0, 0)

		updateCanvasSize()
		table.insert(cons, rowSize.Changed:Connect(updateCanvasSize))

		calcVisibleRows()
		table.insert(cons, resultsFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(calcVisibleRows))
		table.insert(cons, rowSize.Changed:Connect(calcVisibleRowsDeferred))
		table.insert(cons, resultsFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(calcVisibleRowsDeferred))
	end

	local Row

	local modeCon
	function Results:Install(mode)
		if curMode == mode then return end
		if curMode then
			curMode:Uninstall()
			for book, row in bookToRow do
				spareRows:Release(row)
			end
			clearCons()
		end
		curMode = mode
		rowTemplate = mode.RowTemplate
		resultsFrame = mode.ResultsFrame
		rowSize = mode.RowSize

		mode:Install()

		local sr = modeToSpareRows[mode]
		if not sr then -- perform first-time setup for this mode
			sr = ObjectPool.new({
				create = Row.new,
				max = 20,
				release = function(row) row:Release() end,
			})
			modeToSpareRows[mode] = sr
			-- Rows setup
			local ui = resultsFrame.UIListLayout
			mode.uiPadding = ui.Padding.Offset
			ui:Destroy()
			while true do
				local entry = resultsFrame:FindFirstChild("Entry")
				if not entry then break end
				sr:Release(Row.new(entry))
			end
		end
		padding = mode.uiPadding
		spareRows = sr

		if modeCon then modeCon:Disconnect() end
		modeCon = curMode.HeaderClicked:Connect(function(name)
			if searchConfig.SortType == name then
				-- alternate ascending
				local cur = searchConfig.SortAscending
				if cur == nil then
					cur = BookSearch.GetAscendingDataForSortType(name).Default
				end
				searchConfig.SortAscending = not cur
			else
				searchConfig.SortType = name
			end
			handleSortTypeChange(searchConfig.SortType)
		end)

		-- Update other features
		Results:SortTypeChanged(searchConfig.SortType, searchConfig.SortAscending)
		if results and nResults > 0 then
			Results:SetResults(results)
		end
	end

	function Results:SortTypeChanged(sortType, sortAscending)
		curMode:SortTypeChanged(sortType, sortAscending)
	end

	Results.AnyRowActivated = Event.new() -- (book, row, resultNum) -- fires when any row is clicked on
	Row = {}
	Row.__index = Row
	function Row.new(row)
		row = row or rowTemplate:Clone()
		local self
		-- These connections will be destroyed with 'row:Destroy()' so don't need to store them:
		row:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			if self.visible then
				self:checkVisibility()
			end
		end)
		row.Activated:Connect(function()
			Results.AnyRowActivated:Fire(self.book, self, self.resultNum)
		end)
		row.Size = rowSize.Value
		self = setmetatable({
			row = row,
			visible = false,
			fullyVisible = false,
			num = 0, -- event number to help detect when record seen should be fired
			cons = {
				rowSize.Changed:Connect(function(size)
					row.Size = size
				end),
			},
		}, Row)
		return self
	end
	function Row:Release()
		self.num += 1
		if self.book then
			bookToRow[self.book] = nil
			self.book = nil
		end
		self.row.Parent = nil
		if self.updateCon then
			self.updateCon:Disconnect()
		end
	end
	function Row:Destroy()
		self:Release()
		for _, con in self.cons do
			con:Disconnect()
		end
	end
	function Row:recordVisible(visible, fullyVisible)
		if self.visible and not visible then
			self.visible = false
			self.fullyVisible = false
			spareRows:Release(self)
		elseif not self.fullyVisible and fullyVisible then
			-- start timer for recording seen
			self.fullyVisible = true
			if not self.seen and recordSeenEligible then
				local cur = self.num
				task.delay(SEEN_TIME, function()
					if cur == self.num then
						self.seen = true
						booksProfile:RecordSeen(self.book.Id)
					end
				end)
			end
		elseif self.fullyVisible and not fullyVisible then
			self.num += 1
			self.fullyVisible = false
		end
	end
	local function isResultsFrameVisible()
		return resultsFrame.Visible
			and resultsFrame.AbsoluteSize.Y >= 50
			and gui.Enabled
	end
	function Row:checkVisibility()
		local row = self.row
		if isResultsFrameVisible() and row.Visible and row.Parent then
			local yTop = row.AbsolutePosition.Y
			local yBottom = yTop + row.AbsoluteSize.Y
			local parent = row.Parent
			local y1 = parent.AbsolutePosition.Y
			local y2 = y1 + parent.AbsoluteSize.Y
			local visible = yTop + yBottom >= y1 and yTop <= y2
			if visible then
				self:recordVisible(true, yTop >= y1 and yBottom <= y2)
				return
			end
		end
		self:recordVisible(false)
	end

	function Row:SetData(book, metrics)
		self.book = book
		bookToRow[book] = self
		self.seen = booksProfile:GetSeen(book.Id)
		self.num += 1
		if self.updateCon then self.updateCon:Disconnect() end
		local function updateData()
			curMode.UpdateRow(self.row, book, metrics)
		end
		updateData()
		self.updateCon = BookMetrics.Changed:Connect(function(allMetrics)
			metrics = allMetrics[book.Id]
			updateData()
		end)
		if not book.PageCount then
			self.updateCon = EventUtilities.CombineConnections({
				self.updateCon,
				book.PageCountReady:Connect(updateData),
			})
		end
	end
	function Row:Show(resultNum, yPos)
		self.resultNum = resultNum
		local row = self.row
		row.Position = UDim2.new(0, 0, 0, yPos)
		row.BackgroundTransparency = if resultNum % 2 == 0 then RESULT_TRANSPARENCY_EVEN else RESULT_TRANSPARENCY_ODD
		row.Parent = resultsFrame
		self:checkVisibility()
	end

	local tween, tween2
	local function newTween(props, instant, canvasPos)
		if tween then
			tween:Cancel()
			if tween2 then
				tween2:Cancel()
			end
		end
		if instant then
			for k, v in props do
				resultsParent[k] = v
			end
			if canvasPos then
				resultsFrame.CanvasPosition = canvasPos
			end
		else
			tween = TweenService:Create(resultsParent, tweenInfo, props)
			tween:Play()
			if canvasPos then
				tween2 = TweenService:Create(resultsFrame, tweenInfo, {CanvasPosition = canvasPos})
				tween2:Play()
			end
		end
	end
	local prevCanvasPos
	local function shrink(toIndex)
		shrunk = true
		local targetY = getYPos(toIndex)
		prevCanvasPos = resultsFrame.CanvasPosition
		newTween({
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.new(1, 0, 0, shrinkSizeY),
		}, false, Vector2.new(0, targetY))
	end

	local function expand(instant)
		shrunk = false
		newTween({
			Position = UDim2.new(0.5, 0, 0, bottomOfOptions.Value),
			Size = UDim2.new(1, 0, 0, gui.AbsoluteSize.Y - bottomOfOptions.Value),
		}, instant, prevCanvasPos)
		prevCanvasPos = nil
	end

	local function pathfindToBook(book, row, i)
		bg.Visible = false
		optionsFrame.Visible = false
		calcVisibleRows()
		shrink(i)
		BookPathfinder.PathfindTo(book)
	end
	stopPathfind = function(instant)
		bg.Visible = true
		optionsFrame.Visible = true
		expand(instant)
		BookPathfinder.Clear()
	end
	Results.AnyRowActivated:Connect(function(book, row, i)
		if shrunk then
			stopPathfind()
		else
			pathfindToBook(book, row, i)
		end
	end)
end

local mode = if searchProfile:GetResultsViewList() then Results.List else Results.Table
Results:Install(mode)

local search = BookSearch.NewSearch(searchConfig, booksProfile, bookPouch)
local function searchSortChanged()
	Results:SetResults(search())
end
local function searchFiltersChanged()
	search = BookSearch.NewSearch(searchConfig, booksProfile, bookPouch)
	recordSeenEligible = not searchConfig.Title -- if a title has been typed in, most likely the user is looking for something specific
	searchSortChanged()
end

local content = optionsFrame.Content
local checkboxes = content.Checkboxes
local checkboxData = {
	Read = "MarkedRead",
	Liked = "Liked",
	Bookmarked = "Bookmarked",
	Audio = "Audio",
	InBookPouch = "InBookPouch",
}
for name, configField in checkboxData do
	local c = Checkbox.new(checkboxes[name])
	c:SetStateSilent(searchConfig[configField])
	c.Changed:Connect(function(state)
		searchConfig[configField] = state
		searchFiltersChanged()
	end)
end

local TextBox = {}
TextBox.__index = TextBox
function TextBox.new(box, validateInProgress, validateFinal)
	--	validate : function(text) -> return true to confirm, new text to replace, or false to reject and go to previous valid text/value. It will not be invoked for the empty string.
	validateInProgress = validateInProgress or function() return true end
	validateFinal = validateFinal or validateInProgress
	local self = setmetatable({
		-- "text" is whatever is currently in the box
		-- "value" is the last value validated by validateFinal
		box = box,
		prevText = box.Text,
		prevValue = box.Text,
		Value = box.Text,
		ValueChanged = Event.new(), --(value) -- only fires when focus lost, if value is changed
		ignoreChange = false,
	}, TextBox)
	local function callValidate(validate)
		local s = String.Trim(box.Text)
		return if s ~= "" then validate(s) else "", s
	end
	box:GetPropertyChangedSignal("Text"):Connect(function()
		box.FontFace = if box.Text == "" then italicsFont else normalFont
		if self.ignoreChange then return end
		local value, s = callValidate(validateInProgress)
		if value then
			if value ~= true then
				self:setText(value)
			end
			-- Try to validate with final and update the Value, though don't change the text
			value, s = callValidate(validateFinal)
			if value then
				local newValue = if value == true then s else value
				if self.Value ~= newValue then
					self.Value = newValue
					self.ValueChanged:Fire(newValue)
				end
			end
		else
			self:setText(self.prevText)
		end
	end)
	local startColor = box.TextColor3
	box.Focused:Connect(function()
		box.TextColor3 = startColor
	end)
	box.FocusLost:Connect(function(enterPressed)
		local newValue = callValidate(validateFinal)
		if newValue then
			self:SetValue(if newValue == true then box.Text else newValue)
		elseif enterPressed then
			self:setText(self.prevValue)
		else
			box.TextColor3 = Color3.new(1, 0, 0)
		end
	end)
	return self
end
function TextBox:setText(text)
	self.ignoreChange = true
	self.box.Text = text
	self.prevText = text
	self.ignoreChange = false
end
function TextBox:SetValue(value)
	self:setText(value)
	if self.Value == value then return true end
	self.Value = value
	self.ValueChanged:Fire(value)
end


local function wrapMaxSize(validate)
	validate = validate or function() return true end
	return function(value)
		return #value <= MAX_TEXT_BOX_LENGTH and validate(value)
	end
end
local function addBox(control, configField, validateInProgress, validateFinal, textToValue, valueToText)
	local prevValue = searchConfig[configField]
	if prevValue then
		control.Text = if valueToText then valueToText(prevValue) else prevValue
	else
		control.Text = ""
	end
	local box = TextBox.new(control, wrapMaxSize(validateInProgress), wrapMaxSize(validateFinal or validateInProgress))
	box.ValueChanged:Connect(function(value)
		value = if textToValue then textToValue(value) else value
		if searchConfig[configField] == value then return end
		searchConfig[configField] = value
		searchFiltersChanged()
	end)
end

addBox(content.TitleAuthor.Title.TitleSearch, "Title")
addBox(content.TitleAuthor.Author.AuthorSearch, "Author")

local function validateDateInProgress(value)
	return not not value:match("^[-%d%w ,'/]*$")
end
local curYear = os.date("*t", os.time()).year
local function genValidateDateFinal(isMin)
	return function(value)
		local m, d, y = value:match("^(%d+)/?(%d*)/?(%d*)")
		if not m then
			local t = BookSearch.GetDateTime(value)
			if not t then return false end
			return getPrettyDate(t)
		end
		if y == "" and #d > 2 then -- input was month/year
			y = d
			d = if isMin then "1" else "31"
		elseif y == "" and d == "" then -- input was just year
			y = m
			d = if isMin then "1" else "31"
			m = if isMin then "1" else "12"
		end
		if #m > 2 or #d > 2 or #y > 4 then return false end
		if tonumber(m) < 1 or tonumber(m) > 12 then return false end
		if tonumber(d) < 1 or tonumber(d) > 31 then return false end
		if y == "" then
			y = curYear
		elseif #y < 3 then
			y = tostring(tonumber(y) + math.floor(curYear / 100) * 100)
		end
		return string.format("%s/%s/%s", m, d, y)
	end
end
local function dateTextToValue(text)
	return if text == "" then nil else BookSearch.GetDateTime(text)
end
-- local function dateValueToText(value)
-- 	local t = os.date("!*t", value)
-- 	return string.format("%d/%d/%d", t.month, t.day, t.year)
-- end
local dateValueToText = getPrettyDate
local dateFrame = content.DatePages.Date
local function addDateBox(box, field, isMin)
	return addBox(box, field,
		validateDateInProgress,
		genValidateDateFinal(isMin),
		dateTextToValue,
		dateValueToText)
end
addDateBox(dateFrame.DateLow, "PublishedMin", true)
addDateBox(dateFrame.DateHigh, "PublishedMax", false)

local function validatePages(text)
	local n = tonumber(text)
	if not n then return false end
	return if n < 1 then "1" else true
end
local function validatePagesFinal(text)
	local new = tostring(tonumber(text))
	return if new == "nil" then false
		elseif new == text then true
		else new
end
local function tonumberOffsetBy2(s)
	local n = tonumber(s)
	return if n then n + 2 else nil
end
local function tostringOffsetBy2(n)
	return if n then tostring(n - 2) else ""
end
local pagesFrame = content.DatePages.Pages
addBox(pagesFrame.PagesLow, "PagesMin", validatePages, validatePagesFinal, tonumberOffsetBy2, tostringOffsetBy2)
addBox(pagesFrame.PagesHigh, "PagesMax", validatePages, validatePagesFinal, tonumberOffsetBy2, tostringOffsetBy2)

local lower = content.Lower
local genres = lower.Left.Genres
local genresScroll = lower.Left.GenresScroll
local lists = lower.Right.Lists
local listsScroll = lower.Right.ListsScroll
local sortBy = lower.SortBy
local resultsView = lower.ResultsView

local function updateResultsParentPosSize()
	if shrunk then
		resultsParent.Size = UDim2.new(1, 0, 0, shrinkSizeY)
	else
		resultsParent.Position = UDim2.new(0.5, 0, 0, bottomOfOptions.Value)
		resultsParent.Size = UDim2.new(1, 0, 0, gui.AbsoluteSize.Y - bottomOfOptions.Value - SPACE_BENEATH_RESULTS)
	end
end
updateResultsParentPosSize()
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateResultsParentPosSize)
local function updateBgSize()
	bg.Size = UDim2.fromOffset(optionsFrame.AbsoluteSize.X, bottomOfOptions.Value + 1) -- +1 to compensate for -1 attached to bottomOfOptions elsewhere
end
optionsFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateBgSize)
local function updateBg()
	updateBgSize()
	updateResultsParentPosSize()
end
bottomOfOptions.Changed:Connect(updateBg)

do -- Move SortBy and ResultsView below lower of genres & lists (considering visibility)
	local objToMax = {}
	local max = -1
	local function updatePos()
		max = 0
		for obj, m in objToMax do
			if m > max then
				max = m
			end
		end
		sortBy.Position = UDim2.new(0, 0, 0, max - lower.Left.AbsolutePosition.Y + 3)
		resultsView.Position = sortBy.Position
		bottomOfOptions:Set(max + sortBy.AbsoluteSize.Y + BG_PADDING_BOTTOM - 1) -- -1 so that rounding doesn't leave a pixel between bg's bottom & result's top
	end
	local function changeMax(obj, m)
		if objToMax[obj] == m then return end
		local call = m >= max or objToMax[obj] == max
		objToMax[obj] = m
		if call then
			updatePos()
		end
	end
	for _, v in {genres, genresScroll, lists, listsScroll} do
		local function update()
			changeMax(v, if not v.Visible then 0
				else v.AbsolutePosition.Y + v.AbsoluteSize.Y)
		end
		update()
		v:GetPropertyChangedSignal("Visible"):Connect(update)
		v:GetPropertyChangedSignal("AbsolutePosition"):Connect(update)
		v:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	end
end

do -- Genres & Lists
	local expanded = true
	local genresHeader = genres.Header.TextLabel
	local listsHeader = lists.Header.TextLabel
	listsHeader.TextScaled = false
	local genresSearch = genres.Search
	local listsSearch = lists.Search
	local function getFilterForBox(box)
		local filter = Value.new()
		box:GetPropertyChangedSignal("Text"):Connect(function()
			local s = String.Trim(box.Text)
			filter:Set(if s == "" then nil else s:lower())
		end)
		return filter
	end
	local genreFilter = getFilterForBox(genresSearch)
	local listsFilter = getFilterForBox(listsSearch)

	local function toggleExpanded()
		expanded = not expanded
		local intro = string.format('<font size="14">%s</font> ', if expanded then "▼" else "►")
		genresHeader.Text = intro .. "Genres"
		listsHeader.Text = intro .. "Lists"

		genresScroll.Visible = expanded
		listsScroll.Visible = expanded
		lists.Status.Visible = not expanded
		lists.Search.Visible = expanded
		genres.Search.Visible = expanded
	end
	toggleExpanded()
	genres.Header.Activated:Connect(toggleExpanded)
	lists.Header.Activated:Connect(toggleExpanded)

	local function genreCategoryHasCommonValue(categoryName)
		local data = searchConfig.Genres
		local list = Genres.Categories[categoryName]
		local firstValue = data[list[1]]
		for i = 2, #list do
			if firstValue ~= data[list[i]] then
				return false
			end
		end
		return true, firstValue
	end
	local function getGenreCategoryState(categoryName)
		local allSame, commonV = genreCategoryHasCommonValue(categoryName)
		return if allSame then commonV else Mixed
	end
	local function simplifyGenresToCategories()
		-- clone searchConfig.Genres into data (but don't use table.clone due to metatables from SearchProfileClient)
		local data = {}
		for k, v in searchConfig.Genres do data[k] = v end
		for category, cList in Genres.Categories do
			local allSame, commonV = genreCategoryHasCommonValue(category)
			if allSame and commonV ~= nil then
				for _, genre in ipairs(cList) do
					data[genre] = nil
				end
				data[category] = commonV
			elseif data[category] == nil then -- for the Mixed case, don't overwrite a genre if it has the same name as a category
				data[category] = Mixed
			end
		end
		return data
	end

	local function genUpdateStatusLabel(label, getData)
		return function()
			local s = {}
			for name, v in getData() do
				if v == Always then
					table.insert(s, name)
				elseif v == Never then
					table.insert(s, "<s>" .. name .. "</s>")
				end
			end
			local num = #s
			if num == 0 then
				label.Text = "Any"
			else
				local min = math.min(3, num)
				for i = num, min, -1 do
					label.Text = if i == num
						then table.concat(s, ", ")
						else table.concat(s, ", ", 1, i) .. ", ..."
					if label.TextBounds.Y >= label.AbsoluteSize.Y - 1 then
						break
					end
				end
			end
		end
	end
	local updateGenresStatus = genUpdateStatusLabel(genres.Status, simplifyGenresToCategories)
	updateGenresStatus()
	local updateListsStatus = genUpdateStatusLabel(lists.Status, function() return searchConfig.Lists end)
	-- updateListsStatus is always called during initialization in redoRows

	local adjustSizeYControls = {} -- [control] = percent of genres size

	-- Categories
	local genreToCheckbox = {}
	local function wrapUpdateCheckbox(fn)
		return function(state)
			fn(state)
			updateGenresStatus()
			searchFiltersChanged()
		end
	end
	for _, fCategory in genresScroll:GetChildren() do
		if not fCategory:IsA("GuiBase2d") then continue end
		adjustSizeYControls[fCategory.CategoryName] = 0.85
		local categoryName = fCategory.Name
		local checkbox = Checkbox.new(fCategory.CategoryName, nil, true)
		checkbox:SetStateSilent(getGenreCategoryState(categoryName))
		checkbox.Changed:Connect(wrapUpdateCheckbox(function(state)
			for _, genre in ipairs(Genres.Categories[categoryName]) do
				searchConfig.Genres[genre] = state
				genreToCheckbox[genre]:SetStateSilent(state)
			end
		end))
		local fList = fCategory.GenreList
		local template = fList.Genre
		for i, genre in ipairs(Genres.Categories[categoryName]) do
			local row = if i == 1 then template else template:Clone()
			row.Name = genre
			row.Genre.Text = genre
			row.LayoutOrder = i
			adjustSizeYControls[row] = 0.8
			local cb = Checkbox.new(row)
			genreToCheckbox[genre] = cb
			cb:SetStateSilent(searchConfig.Genres[genre])
			cb.Changed:Connect(wrapUpdateCheckbox(function(state)
				searchConfig.Genres[genre] = state
				checkbox:SetStateSilent(getGenreCategoryState(categoryName))
			end))
			local genreLowered = genre:lower()
			local function checkFilter()
				local value = genreFilter.Value
				row.Visible = not value or not not genreLowered:find(value, 1, true)
			end
			checkFilter()
			genreFilter.Changed:Connect(checkFilter)
			row.Parent = fList
		end
	end

	local template = listsScroll.Result
	template.Parent = nil
	local listRows = {}
	local ListRow = {}
	ListRow.__index = ListRow
	function ListRow.new()
		local row = template:Clone()
		row.Parent = listsScroll
		local cb = Checkbox.new(row)
		adjustSizeYControls[row] = 0.8
		local self = setmetatable({
			row = row,
			title = row.Title,
			cb = cb,
			Changed = cb.Changed,
		}, ListRow)
		self.filterCon = listsFilter.Changed:Connect(function(value)
			self:checkFilter()
		end)
		return self
	end
	function ListRow:Destroy()
		self.row:Destroy()
		self.Changed:Destroy() -- technically belongs to checkbox but this works
		adjustSizeYControls[self.row] = nil
		self.filterCon:Disconnect()
		if self.con then self.con:Disconnect() end
	end
	function ListRow:Update(name) -- name is unfiltered
		if self.row.Name == name then return end
		if self.con then self.con:Disconnect() end
		self.row.Name = name
		self.rowNameLowered = name:lower()
		local filtered = booksProfile:GetFilteredListName(name)
		if filtered then
			self.title.Text = filtered
		else
			self.title.Text = string.rep(".", #name)
			self.con = booksProfile.FilteredNameAdded:Connect(function(raw, filtered)
				if raw == name then
					self.title.Text = filtered
					self.con:Disconnect()
				end
			end)
		end
		self.cb:SetStateSilent(searchConfig.Lists[name])
		self:checkFilter()
	end
	function ListRow:checkFilter()
		local value = listsFilter.Value
		self.row.Visible = not value or not not self.rowNameLowered:find(value, 1, true)
	end
	local function redoRows()
		local i = 1
		for name, list in booksProfile:GetAllLists() do
			local row = listRows[i]
			if not row then
				row = ListRow.new()
				listRows[i] = row
				row.Changed:Connect(function(state)
					searchConfig.Lists[name] = state
					updateListsStatus()
					searchFiltersChanged()
				end)
			end
			row:Update(name)
			i += 1
		end
		for j = i, #listRows do
			listRows[j]:Destroy()
			listRows[j] = nil
		end
		updateListsStatus()
	end
	redoRows()
	booksProfile.ListsChanged:Connect(redoRows)

	local function updateTextSize()
		local y = genresHeader.TextBounds.Y
		listsHeader.TextSize = y
		for control, percent in adjustSizeYControls do
			control.Size = UDim2.new(control.Size.X, UDim.new(0, math.floor(y * percent)))
		end
	end
	updateTextSize()
	genresHeader:GetPropertyChangedSignal("TextBounds"):Connect(updateTextSize)
end

--local curSortType = BookSearch.GetSortTypeData(searchConfig.SortType)
local sortTypeOptions = {}
for i, sortTypeData in ipairs(BookSearch.SortTypes) do
	sortTypeOptions[i] = sortTypeData.Name
end
local dropdownReposCon
local function connect(button, rightSide, getOptions, getCurValue, handleChange)
	local anchor = Vector2.new(if rightSide then 1 else 0, 0)
	button.Activated:Connect(function()
		local function getPos()
			local pos = button.AbsolutePosition + Vector2.new(if rightSide then button.AbsoluteSize.X else 0, button.AbsoluteSize.Y + 1)
			return UDim2.fromOffset(pos.X, pos.Y)
		end
		local con = button:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			Dropdown:SetPos(getPos())
		end)
		local value, index = Dropdown:OpenAsync(getPos(), anchor, getOptions(), getCurValue())
		if value then
			handleChange(value, index)
			button.TextLabel.Text = value
		end
	end)
	button.TextLabel.Text = getCurValue()
end
local sortByOrder = sortBy.Order
local startTransparency = sortByOrder.BackgroundTransparency
local function getOrderText(sortType, value)
	local data = BookSearch.GetAscendingDataForSortType(sortType)
	if not data then return "" end
	if value == nil then
		value = data.Default
	end
	return string.format("%s (%s)", if value then "Ascending" else "Descending", data[value])
end
handleSortTypeChange = function(sortType)
	local enabled = not not BookSearch.GetAscendingDataForSortType(sortType)
	sortByOrder.Active = enabled
	sortByOrder.AutoButtonColor = enabled
	sortBy.Type.TextLabel.Text = searchConfig.SortType -- in case changed not through sortBy.Type button
	if enabled then
		sortByOrder.TextLabel.Text = getOrderText(sortType, searchConfig.SortAscending)
		sortByOrder.BackgroundTransparency = startTransparency
	else
		sortByOrder.TextLabel.Text = ""
		sortByOrder.BackgroundTransparency = 1
	end
	searchSortChanged()
	Results:SortTypeChanged(sortType, searchConfig.SortAscending)
end
connect(sortBy.Type, true,
	function() return sortTypeOptions end,
	function() return String.CamelCaseToEnglish(searchConfig.SortType) end,
	function(value)
		value = value:gsub(" ", "")
		searchConfig.SortType = value
		searchConfig.SortAscending = nil -- reset to default
		handleSortTypeChange(value)
	end)
connect(sortByOrder, true,
	function() -- getOptions
		return {
			getOrderText(searchConfig.SortType, true),
			getOrderText(searchConfig.SortType, false),
		}
	end,
	function() -- getCurValue
		return getOrderText(searchConfig.SortType, searchConfig.SortAscending)
	end,
	function(value, i) -- handleChange
		searchConfig.SortAscending = i == 1
		handleSortTypeChange(searchConfig.SortType)
	end)
local resultsOptions = {"List", "Table"}
connect(resultsView.ResultsView, false,
	function() return resultsOptions end,
	function() return if searchProfile:GetResultsViewList() then "List" else "Table" end,
	function(value)
		searchProfile:SetResultsViewList(value == "List")
		local mode = if value == "List" then Results.List else Results.Table
		Results:Install(mode)
	end)

sortBy:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	Dropdown:SetRowSize(UDim2.new(0, 0, 0, sortBy.AbsoluteSize.Y))
end)

module.CloseOnCatchClick = false
local open = false
local hidden = false
local firstTime = true
function module:Open()
	open = true
	if not hidden then
		gui.Enabled = true
		if firstTime then
			firstTime = false
			handleSortTypeChange(searchConfig.SortType)
		end
	end
end
function module:Close()
	open = false
	BookPathfinder.Clear()
	gui.Enabled = false
	if shrunk then
		stopPathfind(true)
	end
end
function module:Hide()
	gui.Enabled = false
	hidden = true
end
function module:Unhide()
	hidden = false
	if open then
		gui.Enabled = true
	end
end

localPlayer.CharacterAdded:Connect(function()
	if gui.Enabled then
		module:Close()
	end
end)

return module