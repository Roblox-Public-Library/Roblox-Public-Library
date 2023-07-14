local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage.Utilities
local Assert = require(Utilities.Assert)
local Class = require(Utilities.Class)
local Event = require(Utilities.Event)

local BookmarkLayout = Class.New("BookmarkLayout")
function BookmarkLayout.new(template, bg, fg, indexToFormattedPageNumber)
	return setmetatable({
		template = Assert.IsA(template, "GuiBase2d"),
		scaleSize = template.Size.Y.Scale,
		bg = Assert.IsA(bg, "GuiBase2d"),
		fg = Assert.IsA(fg, "GuiBase2d"),
		indexToFormattedPageNumber = Assert.Function(indexToFormattedPageNumber),
		bookmarks = {},
		pgToUI = {},
		curPage = 1,
		numPages = 1,
		Clicked = Event.new(),
	}, BookmarkLayout)
end
function BookmarkLayout:Add(pg)
	if self.pgToUI[pg] then return end
	table.insert(self.bookmarks, pg)
	table.sort(self.bookmarks)
	local ui = self.template:Clone()
	self.pgToUI[pg] = ui
	ui.Page.Text = self.indexToFormattedPageNumber(pg)
	ui.Image.Activated:Connect(function()
		self.Clicked:Fire(pg)
	end)
	self:update()
end
function BookmarkLayout:Remove(pg)
	local ui = self.pgToUI[pg]
	if not ui then return end
	ui:Destroy()
	self.pgToUI[pg] = nil
	table.remove(self.bookmarks, table.find(self.bookmarks, pg))
	self:update()
end
function BookmarkLayout:HasBookmark(pg)
	return self.pgToUI[pg]
end
function BookmarkLayout:GetBookmarkPages() return self.bookmarks end
function BookmarkLayout:Num() return #self.bookmarks end
function BookmarkLayout:NewBook(numPages, bookmarks) -- bookmarks is optional
	self.numPages = numPages
	table.clear(self.bookmarks)
	self:clearPgToUI()
	self.curPage = 1
	if bookmarks then
		self:DisableUpdates()
		for _, pg in bookmarks do
			self:Add(pg)
		end
		self:EnableUpdates()
	end
end
function BookmarkLayout:SetCurrentPage(curPage)
	self.curPage = curPage
	self:updateZIndex()
end
local function disabledUpdate(self) self.updatesMissed = true end
function BookmarkLayout:DisableUpdates()
	self.update = disabledUpdate
	self.updateZIndex = disabledUpdate
end
function BookmarkLayout:EnableUpdates()
	self.update = nil -- restore enabled version
	self.updateZIndex = nil
	if self.updatesMissed then
		self.updatesMissed = nil
		self:update()
	end
end
function BookmarkLayout:Destroy()
	self:clearPgToUI()
	self.Clicked:Destroy()
end
function BookmarkLayout:clearPgToUI()
	for pg, ui in self.pgToUI do
		ui:Destroy()
	end
	table.clear(self.pgToUI)
end
function BookmarkLayout:update()
	-- Calculate preferred spot for each
	local spot = {} -- [pg] = y scale position
	local numPages = self.numPages
	local bookmarks = self.bookmarks
	for i, pg in self.bookmarks do
		-- page index 1 should be at top (position 0)
		-- page index numPages should be at bottom (position 1 - scale)
		spot[pg] = (pg - 1) / (numPages - 1) * (1 - self.scaleSize)
	end
	-- Move them forward so no overlapping in that direction
	local n = #bookmarks
	local scaleSize = self.scaleSize
	for i = 2, n do
		local cur, prev = bookmarks[i], bookmarks[i - 1]
		if spot[prev] + scaleSize > spot[cur] then
			spot[cur] = spot[prev] + scaleSize
		end
	end
	-- Same thing backwards
	for i = n - 1, 1, -1 do
		local cur, prev = bookmarks[i], bookmarks[i + 1]
		-- 'prev' is from perspective of iterating backwards
		if spot[cur] + scaleSize > spot[prev] then
			spot[cur] = spot[prev] - scaleSize
		end
	end
	-- Update ui
	local curPage = self.curPage
	for pg, ui in self.pgToUI do
		ui.Position = UDim2.new(0, 0, spot[pg], 0)
	end
	self:updateZIndex()
end
function BookmarkLayout:updateZIndex()
	local curPage = self.curPage
	for pg, ui in self.pgToUI do
		ui.ZIndex = curPage - pg
		ui.Parent = if pg == curPage then self.fg else self.bg
	end
end
return BookmarkLayout