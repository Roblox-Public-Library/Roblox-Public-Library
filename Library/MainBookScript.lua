local ContentProvider = game:GetService("ContentProvider")
local TextService = game:GetService("TextService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Books = require(ReplicatedStorage.Library.BooksClient)
local musicClientScript = ReplicatedStorage:FindFirstChild("MusicClient")
local music = musicClientScript and require(musicClientScript) or {GoCrazy = function() end} -- Allows this script to be used in workshops without the music system
local localPlayer = game:GetService("Players").LocalPlayer
local events
if musicClientScript then
	events = require(localPlayer:WaitForChild("PlayerScripts"):WaitForChild("Gui"):WaitForChild("BookGui")) -- temporary patch to new menu system
else -- workshop support
	local function fakeEvent()
		return {Fire = function() end}
	end
	events = {
		bookOpened = fakeEvent(),
		bookClosed = fakeEvent(),
	}
end

local UnlimitedTextSpace = Vector2.new(32767, 32767)
local function getFittingString(text, textSize, font, textWidth, availableTextWidth, minFittingChars, minFittingCharsWidth)
	--	Returns textThatFits, remainingText (if any)
	--		Note that at least one character will always be returned, even if it doesn't fit
	--	textSize: as in label.TextSize
	--	textWidth: how many pixels wide `text` is
	--	availableTextWidth: in pixels
	--	minFittingChars: optional number of characters that are known to fit (defaults to 0, the minimum characters returned)
	--	minFittingCharsWidth: if minFittingChars is provided, must be the width of minFittingChars
	if textWidth <= availableTextWidth then return text end
	--[[Algorithm:
	1. Get estimate of what fits and measure it
	2. Lower the search area based on the estimate width until we get perfect width
	3. Backtrack if needed so we don't split up the middle of a word, unless no non-letter-character is within 8 characters
	]]
	local lower, upper -- the minimum/maximum number of characters that might fit
	local smallChars, smallWidth -- smallest # of chars for which we have a measurement (but as close to 'lower' as possible)
	local largeChars, largeWidth -- same idea
	local numChars = #text
	if minFittingChars then
		lower, smallChars, smallWidth = minFittingChars < 1 and 1 or minFittingChars, minFittingChars, minFittingCharsWidth or error("minFittingCharsWidth is not optional if minFittingChars is provided", 2)
	else
		lower, smallChars, smallWidth = 1, 0, 0
	end
	upper = numChars - 1
	largeChars, largeWidth = numChars, textWidth
	while lower < upper do
		local widthAvailable = availableTextWidth - smallWidth
		local estimate = lower + math.floor(widthAvailable / (largeWidth - smallWidth) * (largeChars - smallChars))
		-- we want estimate to be within the valid values but never to retest a measurement
		estimate = estimate <= lower and (lower == smallChars and lower + 1 or lower)
			or estimate >= upper and (upper == largeChars and upper - 1 or upper)
			or estimate
		-- Note: original estimate calculation code was `estimate = math.clamp(lower + math.ceil((upper - lower) ^ 0.5), lower, upper) -- empirically found to be the most efficient algorithm considering how expense with GetTextSize works` - but note that in the original algorithm it calculates the potential error based on the specific font used and other details
		-- 	Therefore, it may be more efficient to always subtract one from the estimate before clamping, or even to lower it by a fraction (but Roblox improved efficiency in many areas since that original testing was done)
		local estimateWidth = TextService:GetTextSize(text:sub(lower + 1, lower + estimate), textSize, font, UnlimitedTextSpace).X
		if estimateWidth > availableTextWidth then
			upper, largeChars, largeWidth = estimate - 1, estimate, estimateWidth
		elseif estimateWidth < availableTextWidth then
			if estimate == upper then
				lower = estimate
				break
			end
			lower, smallChars, smallWidth = estimate + 1, estimate, estimateWidth
		else -- Estimate was the perfect width
			lower += estimate
			break
		end
	end
	lower = text:sub(math.max(lower - 20, 1), lower):find("%W%w+$") or lower -- if the final letter is a word character, don't break up the word unless it's a really long word
	return text:sub(1, lower), text:sub(lower + 1)
end
local function fitStringToLabel(text, label)
	--	If the current line already has content, appends text to it with a space between
	--	Returns the text that didn't fit (if any)
	local prevText = label.Text
	local prevBounds = label.TextBounds
	label.Text = prevText == "" and text or prevText .. " " .. text
	if label.TextFits then return end
	label.Text, text = getFittingString(label.Text, label.TextSize, label.Font, label.TextBounds.X, label.AbsoluteSize.X, #prevText, prevBounds.X)
	return text
end

local mainFrame = script.Parent
-- Wait for all descendants to be added so no need for WaitForChild
local target = #game.StarterGui.BookGui.MainFrame:GetDescendants()
while #mainFrame:GetDescendants() < target do wait() end

local specialScreen = mainFrame.Parent.SpecialScreen
local bottomFrame = mainFrame.BottomFrame

local SFX = ReplicatedStorage.SFX
local initialSilenceDuration = 5 -- for GoCrazy

local fontSize
local frames = {}
for i = 1, 4 do
	frames[i] = mainFrame["Pg" .. i]
end
local leftPageTemplate = frames[3]:Clone()
leftPageTemplate.Visible = true
local rightPageTemplate = frames[4]:Clone()
rightPageTemplate.Visible = true
local page = #frames -- The current frame index while processing a book, otherwise it equals #pages
local line = 1 -- Only used while processing a book
local kill = false
local pagePair = 1
local numPagePairs = 1
local leftPage, rightPage -- The frame/page that is visible on the left/right side
local function getFrame(page)
	local frame = frames[page]
	if not frame then
		for framePage = #frames + 1, page do -- Sometimes commands skip over pages and leave them empty, but the rest of the script assumes we have a continuous list of frames with no gaps, so ensure we generate all the pages we need
			frame = (framePage % 2 == 1 and leftPageTemplate or rightPageTemplate):Clone()
			frame.Name = "Pg" .. framePage
			for _, v in ipairs(frame:GetChildren()) do
				if v:IsA("TextLabel") then
					v.TextSize = fontSize
				end
			end
			frame.Parent = mainFrame
			frames[framePage] = frame
		end
	end
	return frame
end
local function setPagePair(pair)
	pagePair = pair
	local pageFind = pagePair * 2
	if pagePair == 1 then
		bottomFrame.Minus.BackgroundTransparency = 1
		bottomFrame.Minus.Text = ""
		bottomFrame.Minus.Active = false
		bottomFrame.Minus.PageCount.Text = string.format("%d Page%s", page - 2, page == 3 and "" or "s")
		bottomFrame.Minus.TextLabel.Text = "Cover"
		bottomFrame.Plus.TextLabel.Text = "Notes"
	else
		bottomFrame.Minus.BackgroundTransparency = 0
		bottomFrame.Minus.Text = "<"
		bottomFrame.Minus.Active = true
		bottomFrame.Minus.PageCount.Text = ""
		bottomFrame.Minus.TextLabel.Text = "Page " .. pageFind - 3
		bottomFrame.Plus.TextLabel.Text = "Page " .. pageFind - 2
	end
	if pagePair == numPagePairs then
		bottomFrame.Plus.BackgroundTransparency = 1
		bottomFrame.Plus.Text = ""
		bottomFrame.Plus.Active = false
	else
		bottomFrame.Plus.BackgroundTransparency = 0
		bottomFrame.Plus.Text = ">"
		bottomFrame.Plus.Active = true
	end
	if leftPage then
		leftPage.Visible = false
	end
	if rightPage then
		rightPage.Visible = false
	end
	leftPage = frames[pageFind - 1]
	rightPage = frames[pageFind]
	if leftPage then
		leftPage.Visible = true
	end
	if rightPage then
		rightPage.Visible = true
	end
end
local function setPage(value)
	page = value
	line = 1
end
local function advancePage(amount)
	setPage(page + (amount or 1))
end
local function advanceLine(amount)
	amount = amount or 1
	if line + amount <= 20 then
		line += amount
	else
		advancePage()
	end
end
local function onEmptyPage()
	return line == 1 and (not frames[page] or frames[page]["1"].Text == "")
end
local function onEmptyLine()
	return not frames[page] or frames[page][tostring(line)].Text == ""
end
local function onLeftPage()
	return page % 2 == 1
end
local function imageFitsOnPage(imageLength)
	return line == 1 or (onEmptyLine() and line or line + 1) + imageLength - 1 <= 20
end
local function canPutImageOnRightWithoutTurningPage(imageLength) -- returns true if can place an image on the right page without requiring the reader to turn past a blank page
	return onLeftPage() or imageFitsOnPage(imageLength)
end
local loadedImages = {} -- [image] = success (so can be false)
local loadingImageWaitingThreads = {} -- for each image, the list of threads to resume when it's done loading (but it's nil if the image isn't being loaded)
local errMsg = Instance.new("TextLabel") do
	errMsg.Text = "Image failed to load"
	errMsg.Size = UDim2.new(1, 0, 1, 0)
	errMsg.TextScaled = true
	errMsg.BackgroundTransparency = 1
	errMsg.TextColor3 = Color3.fromRGB(106, 0, 0)
	errMsg.ZIndex = 5
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 20
	constraint.Parent = errMsg
end
local function preloadImageOnLabelAsync(image, label)
	label.BackgroundTransparency = 0.8
	local function imageLabelLoaded(success)
		if success then
			label.BackgroundTransparency = 1
			label.Image = image
		else
			errMsg:Clone().Parent = label
		end
	end
	if loadedImages[image] ~= nil then
		imageLabelLoaded(loadedImages[image])
		return
	end
	if loadingImageWaitingThreads[image] then
		table.insert(loadingImageWaitingThreads[image], coroutine.running())
		imageLabelLoaded(coroutine.yield())
	else
		local list = {}
		loadingImageWaitingThreads[image] = list
		ContentProvider:PreloadAsync({image}, function(_, status)
			loadingImageWaitingThreads[image] = nil
			local success = status == Enum.AssetFetchStatus.Success
			loadedImages[image] = success
			imageLabelLoaded(success)
			for _, thread in ipairs(list) do
				coroutine.resume(thread, success)
			end
		end)
	end
end
local function displayImage(imageLength, image)
	--	Does not position the image or handle page/line counts
	local label = Instance.new("ImageLabel")
	label.Size = UDim2.new(1, 0, 0.05 * imageLength, 0)
	label.ZIndex = 5
	label.BorderSizePixel = 0
	task.spawn(preloadImageOnLabelAsync, image, label)
	label.Parent = getFrame(page)
	return label
end
local function displayImageOnLine(imageLength, image)
	if not onEmptyLine() then
		advanceLine()
	end
	if not imageFitsOnPage(imageLength) then
		advancePage()
	end
	local label = displayImage(imageLength, image)
	label.Position = UDim2.new(0, 0, 0.05 * line - 0.05, 0)
	advanceLine(imageLength)
	return label
end
local function fitStringToLine(text)
	--	If the current line already has content, appends text to it with a space between
	--	Returns the text that didn't fit or nil if it all fit
	return fitStringToLabel(text, getFrame(page)[tostring(line)])
end
local function fitStringToLineAllOrNothing(text)
	--	If the current line already has content, appends text to it with a space between, but only if all of text fits
	--	If the current line is empty, acts like fitStringToLine
	--	In either case, text not added will be returned (if there is any)
	local frame = getFrame(page)
	local label = frame[tostring(line)]
	if label.Text == "" then
		return fitStringToLabel(text, label)
	end
	local prevText = label.Text
	label.Text = prevText .. " " .. text
	if label.TextFits then return end
	label.Text = prevText
	return text
end

local ratio = 8.5 / 11
local function sizeMainFrame()
	mainFrame.Size = UDim2.new(UDim.new(0, mainFrame.AbsoluteSize.Y * ratio * 2 + 32), mainFrame.Size.Y) -- * 2 because there are 2 pages and + 12 due to space between pages in middle of screen and + 20 due to page margins (5 on each side * 2 pages)
end

local function colorsSimilar(a, b)
	return math.abs(a.R - b.R) < 0.2
		and math.abs(a.G - b.G) < 0.2
		and math.abs(a.B - b.B) < 0.2
end
local black = Color3.new()
local white = Color3.new(1, 1, 1)
local function oppositeBlackWhite(c)
	return (c.R > 0.5 or c.G > 0.5 or c.B > 0.5) and black or white
end
local function handleStrokeColor(textColor, strokeColor)
	return colorsSimilar(textColor, strokeColor)
		and oppositeBlackWhite(textColor)
		or strokeColor
end

local originalMainFramePosition = mainFrame.Position
local function getWordsFromBookWords(bookWords)
	local words = {}
	for _, v in ipairs(bookWords) do
		if v ~= "" then
			for word in string.gmatch(v, "%S+") do
				table.insert(words, word)
			end
		end
	end
	return words
end

local open = Instance.new("BindableFunction")
open.Name = "OpenBook"
open.Parent = ReplicatedStorage
local invokeNum = 0
open.OnInvoke = function(model, cover, authorsNote, bookWords)
	SFX.BookOpen:Play()
	local book = Books:FromObj(model)
	local titleTextColor = model.TitleColor.Value
	local titleStrokeColor = handleStrokeColor(titleTextColor, model.TitleOutlineColor.Value)
	events.bookOpened:Fire()
	mainFrame.Position = UDim2.new(-2, 0, 0, 0) -- Put it off screen while we load it
	sizeMainFrame()
	mainFrame.Visible = true
	mainFrame.Pg1.Cover.Image = cover
	mainFrame.Pg1.BackgroundColor3 = model.Color
	mainFrame.Pg2.Title.Text = book.Title
	mainFrame.Pg2.Title.TextColor3 = titleTextColor
	mainFrame.Pg2.Title.TextStrokeColor3 = titleStrokeColor
	mainFrame.Pg2.Author.Text = "By: " .. book.AuthorLine
	mainFrame.Pg2.Author.TextColor3 = titleTextColor
	mainFrame.Pg2.Author.TextStrokeColor3 = titleStrokeColor
	mainFrame.Pg2.PublishedOn.Text = "Published On: " .. book.PublishDate
	mainFrame.Pg2.Librarian.Text = "Librarian: " .. book.Librarian
	mainFrame.Pg2.AuthorsNote.Text = authorsNote

	fontSize = (mainFrame.AbsoluteSize.Y / 20) * 0.6
	for i = 3, #frames do
		for _, w in ipairs(frames[i]:GetChildren()) do
			if w:IsA("ImageLabel") then
				w:Destroy()
			elseif w:IsA("TextLabel") then
				w.TextSize = fontSize
				w.Text = ""
			end
		end
		frames[i].Visible = true -- Ensure sizes are updated
	end
	local words = getWordsFromBookWords(bookWords)
	local numWords = #words
	page = 3
	line = 1
	kill = false
	for i, v in ipairs(words) do
		local isText
		if string.sub(v, 1, 1) == "/" then
			-- Note: In the if/elseif branches below, related commands are grouped together and otherwise sorted based on approximate usage frequency (but with quick-to-check commands like "/line" first, except for "/kill", which is put last as that's only used in one book).
			if v == "/line" then
				advanceLine()
			elseif v == "/dline" then
				advanceLine(2)
			elseif v == "/page" then
				advancePage()
			elseif v == "/turn" then
				advancePage(onLeftPage() and 2 or 1)
			elseif string.sub(v, 1, 6) == "/image" then
				local imageLength = math.min(20, tonumber(string.sub(v, 7, 8)))
				local image = string.sub(v, 9)
				displayImageOnLine(imageLength, image)
			elseif string.sub(v, 1, 12) == "/retainImage" then
				local imageLength = math.min(15, tonumber(string.sub(v, 13, 14)))
				local image = string.sub(v, 15)
				local startLine = line
				local label = displayImageOnLine(imageLength, image)
				local sizeY = label.AbsoluteSize.Y
				label.Size = UDim2.new(0, sizeY, 0.05 * imageLength, 0)
				label.Position = UDim2.new(0.5, -sizeY / 2, 0.05 * startLine - 0.05, 0)
			elseif string.sub(v, 1, 9) == "/endImage" then
				if i == numWords then
					local imageLength = tonumber(string.sub(v, 10, 11))
					if canPutImageOnRightWithoutTurningPage(imageLength) then
						if onLeftPage() then
							advancePage()
						end
						local image = string.sub(v, 12)
						displayImage(imageLength, image)
					end
				end
			elseif string.sub(v, 1, 10) == "/fillImage" then
				local imageLength = tonumber(string.sub(v, 11, 12))
				if canPutImageOnRightWithoutTurningPage(imageLength) then
					if onLeftPage() then
						advancePage()
					end
					local image = string.sub(v, 13)
					displayImage(imageLength, image)
				end
				advancePage()
			elseif string.sub(v, 1, 6) == "/hline" then
				if not onEmptyLine() then
					advanceLine()
				end
				fitStringToLine(string.rep(string.sub(v, 7, 7), 120))
			elseif v == "/kill" then
				kill = true
			else
				isText = true
			end
		else
			isText = true
		end
		if isText then
			local textLeft = fitStringToLineAllOrNothing(v)
			while textLeft do
				advanceLine()
				textLeft = fitStringToLine(textLeft)
			end
		end
	end
	if onEmptyPage() then
		page -= 1
	end
	numPagePairs = math.ceil(page / 2)

	-- Force update of frame positions/sizes (Roblox bug workaround)
	local correctSize = mainFrame.Size
	mainFrame.Size = UDim2.new(UDim.new(0, correctSize.X.Offset - 1), correctSize.Y)

	-- if we've started processing another book, don't restore the gui (using invokeNum to keep track)
	invokeNum += 1
	local num = invokeNum
	task.spawn(function() -- This is a work-around for how Roblox doesn't position/size things correctly sometimes
		wait() -- Note: Heartbeat:Wait() is not long enough
		if num ~= invokeNum then return end
		mainFrame.Size = correctSize
		for i = 3, #frames do
			frames[i].Visible = false
		end
		leftPage, rightPage = nil, nil
		setPagePair(1)
		mainFrame.Position = originalMainFramePosition -- Restore it to correct position now that everything has the correct size
	end)
end

bottomFrame.Minus.Activated:Connect(function()
	if pagePair > 1 then
		SFX.PageTurn:Play()
		setPagePair(pagePair - 1)
	end
end)
bottomFrame.Plus.Activated:Connect(function()
	if pagePair < numPagePairs then
		SFX.PageTurn:Play()
		setPagePair(pagePair + 1)
	end
end)

bottomFrame.X.Activated:Connect(function()
	SFX.BookClose:Play()
	mainFrame.Visible = false
	for i = 3, page do
		for _, w in ipairs(frames[i]:GetChildren()) do
			if w:IsA("ImageLabel") then
				w:Destroy()
			elseif w:IsA("TextLabel") then
				w.Text = ""
			end
		end
	end
	page = 1
	line = 1
	events.bookClosed:Fire()
	if kill then
		kill = false
		music:GoCrazy(initialSilenceDuration)
		specialScreen.Visible = true
		wait(initialSilenceDuration)
		specialScreen.Visible = false
		local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
		local con1, con2
		con1 = game["Run Service"].RenderStepped:Connect(function()
			SFX.PageTurn:Play()
		end)
		con2 = game.Players.LocalPlayer.CharacterAdded:Connect(function()
			con1:Disconnect()
			con2:Disconnect()
		end)
	end
end)

sizeMainFrame()
mainFrame.Visible = false
mainFrame.BGL.Visible = true
mainFrame.BGR.Visible = true
mainFrame.BottomFrame.Visible = true