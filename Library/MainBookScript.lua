local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Books = require(ReplicatedStorage.BooksClient)
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

local mainFrame = script.Parent
local specialScreen = mainFrame.Parent:WaitForChild("SpecialScreen")
local bottomFrame = mainFrame:WaitForChild("BottomFrame")

local SFX = ReplicatedStorage.SFX
local initialSilenceDuration = 5 -- for GoCrazy

local pagePair = 1
local numPagePairs = 1
local page = 3
local line = 1
local words = {}
local numWords
local lastWord
local kill = false
local leftPage, rightPage -- The frame/page that is visible on the left/right side
local fontSize
local frames = {}
for i = 1, 4 do
	frames[i] = mainFrame:WaitForChild("Pg" .. i)
end
local target = #game.StarterGui.BookGui.MainFrame:GetDescendants()
while #mainFrame:GetDescendants() < target do wait() end
local leftPageTemplate = frames[3]:Clone()
leftPageTemplate.Visible = false
local rightPageTemplate = frames[4]:Clone()
rightPageTemplate.Visible = false
local function getFrame(page)
	local frame = frames[page]
	if not frame then
		frame = (page % 2 == 1 and leftPageTemplate or rightPageTemplate):Clone()
		frame.Name = "Pg" .. page
		for _, v in ipairs(frame:GetChildren()) do
			if v:IsA("TextLabel") then
				v.TextSize = fontSize
			end
		end
		frame.Parent = mainFrame
		frames[page] = frame
	end
	return frame
end
local function setPagePair(pair)
	pagePair = pair
	local pageFind = pagePair * 2
	if pagePair == 1 then
		bottomFrame.Minus.BackgroundTransparency = 1
		bottomFrame.Minus.Text = ""
		bottomFrame.Plus.TextLabel.Text = "Notes"
		bottomFrame.Minus.TextLabel.Text = "Cover"
	else
		bottomFrame.Minus.BackgroundTransparency = 0
		bottomFrame.Minus.Text = "<"
		bottomFrame.Plus.TextLabel.Text = "Page " .. pageFind - 2
		bottomFrame.Minus.TextLabel.Text = "Page " .. pageFind - 3
	end
	if pagePair == numPagePairs then
		bottomFrame.Plus.BackgroundTransparency = 1
		bottomFrame.Plus.Text = ""
	else
		bottomFrame.Plus.BackgroundTransparency = 0
		bottomFrame.Plus.Text = ">"
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
	return line == 1 and getFrame(page)["1"].Text == ""
end
local function displayImage(imageLength, image)
	--	Does not position the image or handle page/line counts
	local label = Instance.new("ImageLabel")
	label.Size = UDim2.new(1, 0, 0.05 * imageLength, 0)
	label.Image = image
	label.ZIndex = 5
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Parent = getFrame(page)
	return label
end
local function displayImageOnLine(imageLength, image)
	if getFrame(page)[tostring(line)].Text ~= "" then
		advanceLine()
	end
	if line > 1 and line + imageLength - 1 > 20 then
		advancePage()
	end
	local label = displayImage(imageLength, image)
	label.Position = UDim2.new(0, 0, 0.05 * line - 0.05, 0)
	if not lastWord then
		advanceLine(imageLength)
	end
	return label
end

local ratio = 8.5 / 11
local function sizeMainFrame()
	mainFrame.Size = UDim2.new(UDim.new(0, mainFrame.AbsoluteSize.Y * ratio * 2 + 32), mainFrame.Size.Y) -- * 2 because there are 2 pages and + 12 due to space between pages in middle of screen and + 20 due to page margins (5 on each side * 2 pages)
end

local function processBook()
	page = 3
	line = 1
	kill = false
	sizeMainFrame()
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
	for i, v in ipairs(words) do
		lastWord = i == numWords
		if v == "/next" or v == "/line" then
			advanceLine()
		elseif v == "/dline" then
			advanceLine(2)
		elseif v == "/page" then
			advancePage()
		elseif v == "/kill" then
			kill = true
		elseif v == "/turn" then
			advancePage(page % 2 == 0 and 1 or 2)
		elseif string.sub(v, 1, 10) == "/fillImage" then -- Image Turn Function
			if page % 2 == 1 or onEmptyPage() then
				if page % 2 == 1 then
					advancePage()
				end
				local imageLength = tonumber(string.sub(v, 11, 12))
				local image = string.sub(v, 13)
				displayImage(imageLength, image)
			end
			advancePage()
		elseif string.sub(v, 1, 9) == "/endImage" then
			if lastWord and (page % 2 == 1 or onEmptyPage()) then
				if page % 2 == 1 then
					advancePage()
				end
				local imageLength = tonumber(string.sub(v, 10, 11))
				local image = string.sub(v, 12)
				displayImage(imageLength, image)
			end
		elseif string.sub(v, 1, 6) == "/image" then
			local imageLength = math.min(20, tonumber(string.sub(v, 7, 8)))
			local image = string.sub(v, 9)
			displayImageOnLine(imageLength, image)
		elseif string.sub(v, 1, 12) == "/retainImage" then
			local imageLength = math.min(15, tonumber(string.sub(v, 13, 14)))
			local image = string.sub(v, 15)
			local label = displayImageOnLine(imageLength, image)
			local sizeY = label.AbsoluteSize.Y
			label.Size = UDim2.new(0, sizeY, 0.05 * imageLength, 0)
			label.Position = UDim2.new(0.5, -sizeY / 2, 0.05 * line - 0.05, 0)
		else -- Text
			local frame = getFrame(page)
			local label = frame[tostring(line)]
			local prevText = label.Text
			if prevText == "" then
				label.Text = v
			else
				label.Text = prevText .. " " .. v
				if not label.TextFits then
					label.Text = prevText
					advanceLine()
					frame = getFrame(page)
					frame[tostring(line)].Text = v
				end
			end
		end
	end
	numPagePairs = math.ceil(page / 2)
	for i = 3, #frames do
		frames[i].Visible = false
	end
	leftPage, rightPage = nil, nil
	setPagePair(1)
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
	page = 1
	line = 1
	mainFrame.Visible = false
	for i = 3, #frames do
		for _, w in ipairs(frames[i]:GetChildren()) do
			if w:IsA("ImageLabel") then
				w:Destroy()
			elseif w:IsA("TextLabel") then
				w.Text = ""
			end
		end
	end
	events.bookClosed:Fire()
	SFX.BookClose:Play()
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

local firstTime = true
local open = Instance.new("BindableFunction")
open.Name = "OpenBook"
open.Parent = ReplicatedStorage
open.OnInvoke = function(model, cover, authorsNote, bookWords)
	local book = Books:FromObj(model)
	local titleTextColor = model.TitleColor.Value
	local titleStrokeColor = handleStrokeColor(titleTextColor, model.TitleOutlineColor.Value)
	events.bookOpened:Fire()
	words = {}
	for _, v in ipairs(bookWords) do
		if v ~= "" then
			for word in string.gmatch(v, "%S+") do
				table.insert(words, word)
			end
		end
	end
	numWords = #words
	mainFrame.Pg1.Cover.Image = cover
	mainFrame.Pg1.BackgroundColor3 = model.Color
	mainFrame.Pg2.Title.Text = book.Title
	mainFrame.Pg2.Title.TextColor3 = titleTextColor
	mainFrame.Pg2.Title.TextStrokeColor3 = titleStrokeColor
	mainFrame.Pg2.Author.Text = "By: "..book.AuthorLine
	mainFrame.Pg2.Author.TextColor3 = titleTextColor
	mainFrame.Pg2.Author.TextStrokeColor3 = titleStrokeColor
	mainFrame.Pg2.PublishedOn.Text = "Published On: "..book.PublishDate
	mainFrame.Pg2.Librarian.Text = "Librarian: "..book.Librarian
	mainFrame.Pg2.AuthorsNote.Text = authorsNote
	SFX.BookOpen:Play()
	mainFrame.Visible = true
	processBook()
	if firstTime then -- Force update of frame sizes (Roblox bug workaround)
		local correctSize = mainFrame.Size
		mainFrame.Size = UDim2.new(UDim.new(0, correctSize.X.Offset - 1), correctSize.Y)
		wait() -- Note: Heartbeat:Wait() is not long enough
		mainFrame.Size = correctSize
		firstTime = false
	end
end

sizeMainFrame()
mainFrame.Visible = false
mainFrame:WaitForChild("BGL").Visible = true
mainFrame:WaitForChild("BGR").Visible = true
mainFrame:WaitForChild("BottomFrame").Visible = true