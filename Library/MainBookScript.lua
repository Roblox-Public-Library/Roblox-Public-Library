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
local specialScreen = script.Parent.Parent:WaitForChild("SpecialScreen")
local initialSilenceDuration = 5 -- for GoCrazy

local pageSet = 1
local pageUp = 1
local pageParity = 1
local page = 3
local pageDiv = 1
local imageLength = 0
local debounce = false
local first = true
local line = 1
local currLine = 1
local words = {}
local currText = ""
local SFX = ReplicatedStorage.SFX
local frame = {}
for i = 1, 100 do
	frame[i] = script.Parent:WaitForChild("Pg" .. i)
end
local kill = false

local function sizeChange()
	if not debounce then
		debounce = true
--- FIX THE BOOK ---
		page = 3
		pageParity = 2
		pageSet = 1
		line = 1
		for _, v in pairs(script.Parent:GetChildren()) do
			if string.sub(v.Name, 1, 2) == "Pg" then
				v.Visible = false
			end
		end
		frame[1].Visible = true
		frame[2].Visible = true
		if first then
			frame[3].Visible = true
			frame[4].Visible = true
		else
			frame[3].Visible = false
			frame[4].Visible = false
		end
		script.Parent.BottomFrame.Minus.BackgroundTransparency = 1
		script.Parent.BottomFrame.Minus.Text = ""
		script.Parent.BottomFrame.Plus.BackgroundTransparency = 0
		script.Parent.BottomFrame.Plus.Text = ">"
		script.Parent.BottomFrame.Plus.TextLabel.Text = "Notes"
		script.Parent.BottomFrame.Minus.TextLabel.Text = "Cover"
--- SIZE THE BOOK ---
		script.Parent.Size = UDim2.new(0, 0, .75 ,0)
		local SizeY = script.Parent.AbsoluteSize.Y
		local Ratio = 8.5/11
		local SizeX = SizeY*Ratio
		script.Parent.Size = UDim2.new(0, SizeX*2, .75 ,0)
		script.Parent.Position = UDim2.new(.5, -SizeX, .5,-SizeY/2)
		local fontVal = (SizeY/20)*.6
		wait()
		for _,v in pairs(frame) do
			for _,w in pairs(v:GetChildren()) do
				if v ~= frame[1] and v ~= frame[2] and w:IsA("ImageLabel") then
					if w then w:Destroy() end
				elseif v ~= frame[1] and v ~= frame[2] then
					w.Text = ""
				end
			end
		end
		for i,v in pairs(frame) do
			for _,w in pairs(v:GetChildren()) do
				if v ~= frame[1] and v ~= frame[2] and w:IsA("TextLabel") then
					w.TextSize = fontVal
				end
			end
		end
		for i,v in pairs(words) do
---Line Function---
			if v == "/next" or v == "/line" then
				if line < 20 then
					line = line + 1
				else
					line = 1
					page = page + 1
					pageDiv = page
					if pageDiv % 2 == 0 then
						pageParity = page / 2
					else
						pageParity = page + 1
						pageParity = pageParity / 2
					end
				end
---Double Line Function---
			elseif v == "/dline" then
				if line < 20 and line + 1 < 20 and line + 2 <= 20 then
					line = line + 2
				else
					line = 1
					page = page + 1
					pageDiv = page
					if pageDiv % 2 == 0 then
						pageParity = page / 2
					else
						pageParity = page + 1
						pageParity = pageParity / 2
					end
				end
---Page Function---
			elseif v == "/page" then
				line = 1
				page = page + 1
				pageDiv = page
				if pageDiv % 2 == 0 then
					pageParity = page / 2
				else
					pageParity = page + 1
					pageParity = pageParity / 2
				end
			elseif v == "/kill" then
				kill = true
---Turn Function---
			elseif v == "/turn" then
				line = 1
				pageDiv = page
				if pageDiv % 2 == 0 then
					page = page + 1
				else
					page = page + 2
				end
				pageDiv = page
				if pageDiv % 2 == 0 then
					pageParity = page / 2
				else
					pageParity = page + 1
					pageParity = pageParity / 2
				end
---Image Turn Function---
			elseif string.sub(v, 1, 10) == "/fillImage" then
				line = 1
				pageDiv = page
				if pageDiv % 2 == 0 then
					page = page + 1
				else
					page = page + 1
					imageLength = tonumber(string.sub(v, 11, 12))
					local label = Instance.new("ImageLabel")
					label.Parent = frame[page]
					label.Size = UDim2.new(1, 0, 0.05 * imageLength, 0)
					label.Image = string.sub(v, 13)
					label.ZIndex = 5
					label.BackgroundTransparency = 1
					label.BorderSizePixel = 0
					page = page + 1
				end
				pageDiv = page
				if pageDiv % 2 == 0 then
					pageParity = page / 2
				else
					pageParity = page + 1
					pageParity = pageParity / 2
				end
---Image End Function---
			elseif string.sub(v, 1, 9) == "/endImage" then
				if i == #words then
					pageDiv = page
					if pageDiv % 2 == 0 then
					else
						line = 1
						page = page + 1
						imageLength = tonumber(string.sub(v, 10, 11))
						local label = Instance.new("ImageLabel")
						label.Parent = frame[page]
						label.Size = UDim2.new(1, 0, 0.05 * imageLength, 0)
						label.Image = string.sub(v, 12)
						label.ZIndex = 5
						label.BackgroundTransparency = 1
						label.BorderSizePixel = 0
					end
				end
---Image Function---
			elseif string.sub(v, 1, 6) == "/image" then
				if frame[page]:WaitForChild(tostring(line)).Text ~= "" and frame[page]:WaitForChild(tostring(line)).Text ~= [[]] and frame[page]:WaitForChild(tostring(line)).Text ~= '' then
					if line < 20 then
						line = line + 1
					else
						line = 1
						page = page + 1
						pageDiv = page
						if pageDiv % 2 == 0 then
							pageParity = page / 2
						else
							pageParity = page + 1
							pageParity = pageParity / 2
						end
					end
				end
				imageLength = tonumber(string.sub(v, 7, 8))
				if imageLength > 20 then imageLength = 20 end
				if 20 - tonumber(line-1) >= imageLength then
					currLine = line
					local label = Instance.new("ImageLabel")
					label.Parent = frame[page]
					label.Size = UDim2.new(1, 0, 0.05 * imageLength, 0)
					label.Position = UDim2.new(0, 0, 0.05 * currLine - 0.05, 0)
					label.Image = string.sub(v, 9)
					label.ZIndex = 5
					label.BackgroundTransparency = 1
					label.BorderSizePixel = 0
					if line + imageLength <= 20 then
						line = line + imageLength
					elseif i ~= #words then
						line = 1
						page = page + 1
						pageDiv = page
						if pageDiv % 2 == 0 then
							pageParity = page / 2
						else
							pageParity = page + 1
							pageParity = pageParity / 2
						end
					end
				else
					if line ~= 1 then
						line = 1
						page = page + 1
						pageDiv = page
						if pageDiv % 2 == 0 then
							pageParity = page / 2
						else
							pageUp = page + 1
							pageParity = pageUp / 2
						end
					end
					currLine = line
					local label = Instance.new("ImageLabel")
					label.Parent = frame[page]
					label.Size = UDim2.new(1, 0, 0.05 * imageLength, 0)
					label.Position = UDim2.new(0, 0, 0.05 * currLine - 0.05, 0)
					label.Image = string.sub(v, 9)
					label.ZIndex = 5
					label.BackgroundTransparency = 1
					label.BorderSizePixel = 0
					if line + imageLength <= 20 then
						line = line + imageLength
					elseif i ~= #words then
						line = 1
						page = page + 1
						pageDiv = page
						if pageDiv % 2 == 0 then
							pageParity = page / 2
						else
							pageParity = page + 1
							pageParity = pageParity / 2
						end
					end
				end
---Retain Image Function---
			elseif string.sub(v, 1, 12) == "/retainImage" then
				if frame[page]:WaitForChild(tostring(line)).Text ~= "" and frame[page]:WaitForChild(tostring(line)).Text ~= [[]] and frame[page]:WaitForChild(tostring(line)).Text ~= '' then
					if line < 20 then
						line = line + 1
					else
						line = 1
						page = page + 1
						pageDiv = page
						if pageDiv % 2 == 0 then
							pageParity = page / 2
						else
							pageParity = page + 1
							pageParity = pageParity / 2
						end
					end
				end
				imageLength = tonumber(string.sub(v, 13, 14))
				if imageLength > 15 then imageLength = 15 end
				if 20 - tonumber(line-1) >= imageLength then
					currLine = line
					local label = Instance.new("ImageLabel")
					label.Parent = frame[page]
					label.Size = UDim2.new(1, 0, 0.05 * imageLength, 0)
					label.Position = UDim2.new(0, 0, 0.05 * currLine - 0.05, 0)
					local ekksu = label.AbsoluteSize.Y
					label.Size = UDim2.new(0, ekksu, 0.05 * imageLength, 0)
					label.Position = UDim2.new(0.5, -ekksu/2, 0.05 * currLine - 0.05, 0)
					label.Image = string.sub(v, 15)
					label.ZIndex = 5
					label.BackgroundTransparency = 1
					label.BorderSizePixel = 0
					if line + imageLength <= 20 then
						line = line + imageLength
					elseif i ~= #words then
						line = 1
						page = page + 1
						pageDiv = page
						if pageDiv % 2 == 0 then
							pageParity = page / 2
						else
							pageParity = page + 1
							pageParity = pageParity / 2
						end
					end
				else
					if line ~= 1 then
						line = 1
						page = page + 1
						pageDiv = page
						if pageDiv % 2 == 0 then
							pageParity = page / 2
						else
							pageUp = page + 1
							pageParity = pageUp / 2
						end
					end
					currLine = line
					local label = Instance.new("ImageLabel")
					label.Parent = frame[page]
					label.Size = UDim2.new(1, 0, 0.05 * imageLength, 0)
					label.Position = UDim2.new(0, 0, 0.05 * currLine - 0.05, 0)
					local ekksu = label.AbsoluteSize.Y
					label.Size = UDim2.new(0, ekksu, 0.05 * imageLength, 0)
					label.Position = UDim2.new(0.5, -ekksu/2, 0.05 * currLine - 0.05, 0)
					label.Image = string.sub(v, 15)
					label.ZIndex = 5
					label.BackgroundTransparency = 1
					label.BorderSizePixel = 0
					if line + imageLength <= 20 then
						line = line + imageLength
					elseif i ~= #words then
						line = 1
						page = page + 1
						pageDiv = page
						if pageDiv % 2 == 0 then
							pageParity = page / 2
						else
							pageParity = page + 1
							pageParity = pageParity / 2
						end
					end
				end
---Text Function---
			else
				frame[page]:WaitForChild(tostring(line)).Text = tostring(frame[page]:WaitForChild(tostring(line)).Text.." "..v)
				if frame[page]:WaitForChild(tostring(line)).TextFits == true then
					currText = frame[page]:FindFirstChild(tostring(line)).Text
				else
					frame[page]:FindFirstChild(tostring(line)).Text = currText
					if line < 20 then
						line = line + 1
					else
						line = 1
						page = page + 1
						pageDiv = page
						if pageDiv % 2 == 0 then
							pageParity = page / 2
						else
							pageParity = page + 1
							pageParity = pageParity / 2
						end
					end
					if line > 20 then
						line = 1
						page = page + 1
						pageDiv = page
						if pageDiv % 2 == 0 then
							pageParity = page / 2
						else
							pageParity = page + 1
							pageParity = pageParity / 2
						end
					end
					frame[page]:WaitForChild(tostring(line)).Text = frame[page]:WaitForChild(tostring(line)).Text.." "..v
				end
			end
		end
		wait()
		debounce = false
	end
end

script.Parent.BottomFrame.Minus.Activated:Connect(function()
	if not debounce and pageSet > 1 then
		debounce = true
		SFX.PageTurn:Play()
		script.Parent.BottomFrame.Plus.BackgroundTransparency = 0
		script.Parent.BottomFrame.Minus.Text = "<"
		script.Parent.BottomFrame.Plus.BackgroundTransparency = 0
		script.Parent.BottomFrame.Plus.Text = ">"
		pageSet = pageSet - 1
		for _, v in pairs(script.Parent:GetChildren()) do
			if string.sub(v.Name, 1, 2) == "Pg" then
				v.Visible = false
			end
		end
		local pageFind = pageSet * 2
		script.Parent:WaitForChild("Pg"..pageFind-1).Visible = true
		script.Parent:WaitForChild("Pg"..pageFind).Visible = true
		if pageSet == 1 then
			script.Parent.BottomFrame.Plus.TextLabel.Text = "Notes"
			script.Parent.BottomFrame.Minus.TextLabel.Text = "Cover"
		else
			script.Parent.BottomFrame.Plus.TextLabel.Text = "Page "..pageFind - 2
			script.Parent.BottomFrame.Minus.TextLabel.Text = "Page "..pageFind - 3
		end
		if pageSet == 1 then
			script.Parent.BottomFrame.Minus.BackgroundTransparency = 1
			script.Parent.BottomFrame.Minus.Text = ""
		end
		wait()
		debounce = false
	end
end)

script.Parent.BottomFrame.Plus.Activated:Connect(function()
	if not debounce and pageSet < pageParity then
		debounce = true
		SFX.PageTurn:Play()
		script.Parent.BottomFrame.Minus.BackgroundTransparency = 0
		script.Parent.BottomFrame.Minus.Text = "<"
		script.Parent.BottomFrame.Plus.BackgroundTransparency = 0
		script.Parent.BottomFrame.Plus.Text = ">"
		pageSet = pageSet + 1
		for _, v in pairs(script.Parent:GetChildren()) do
			if string.sub(v.Name, 1, 2) == "Pg" then
				v.Visible = false
			end
		end
		local pageFind = pageSet * 2
		script.Parent:WaitForChild("Pg"..pageFind-1).Visible = true
		script.Parent:WaitForChild("Pg"..pageFind).Visible = true
		if pageSet == 1 then
			script.Parent.BottomFrame.Plus.TextLabel.Text = "Notes"
			script.Parent.BottomFrame.Minus.TextLabel.Text = "Cover"
		else
			script.Parent.BottomFrame.Plus.TextLabel.Text = "Page "..pageFind - 2
			script.Parent.BottomFrame.Minus.TextLabel.Text = "Page "..pageFind - 3
		end
		if pageSet >= pageParity then
			script.Parent.BottomFrame.Plus.BackgroundTransparency = 1
			script.Parent.BottomFrame.Plus.Text = ""
		end
		wait()
		debounce = false
	end
end)

script.Parent.BottomFrame.X.Activated:Connect(function()
	if not debounce then
		debounce = true
		page = 1
		line = 1
		for _,v in pairs(frame) do
			for _,w in pairs(v:GetChildren()) do
				if v ~= frame[1] and v ~= frame[2] and w:IsA("ImageLabel") then
					if w then w:Destroy() end
				elseif v ~= frame[1] and v ~= frame[2] then
					w.Text = ""
				end
			end
		end
		events.bookClosed:Fire()
		SFX.BookClose:Play()
		script.Parent.Visible = false
		if kill then
			music:GoCrazy(initialSilenceDuration)
			specialScreen.Visible = true
			wait(initialSilenceDuration)
			specialScreen.Visible = false
			game.Players.LocalPlayer.Character.Humanoid.Health = 0
			local con1, con2
			con1 = game["Run Service"].RenderStepped:Connect(function()
				SFX.PageTurn:Play()
			end)
			con2 = game.Players.LocalPlayer.CharacterAdded:Connect(function()
				con1:Disconnect()
				con2:Disconnect()
			end)
		end
		debounce = false
	end
end)

wait(1)

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
			for i in string.gmatch(v, "%S+") do
				table.insert(words, #words+1, i)
			end
		end
	end
	script.Parent.Pg1.Cover.Image = cover
	script.Parent.Pg1.BackgroundColor3 = model.Color
	script.Parent.Pg2.Title.Text = book.Title
	script.Parent.Pg2.Title.TextColor3 = titleTextColor
	script.Parent.Pg2.Title.TextStrokeColor3 = titleStrokeColor
	script.Parent.Pg2.Author.Text = "By: "..book.AuthorLine
	script.Parent.Pg2.Author.TextColor3 = titleTextColor
	script.Parent.Pg2.Author.TextStrokeColor3 = titleStrokeColor
	script.Parent.Pg2.PublishedOn.Text = "Published On: "..book.PublishDate
	script.Parent.Pg2.Librarian.Text = "Librarian: "..book.Librarian
	script.Parent.Pg2.AuthorsNote.Text = authorsNote
	SFX.BookOpen:Play()
	script.Parent.Visible = true
	sizeChange()
	wait()
	first = false
	sizeChange()
end

script.Parent.Size = UDim2.new(0, 0, .75 ,0)
local SizeY1 = script.Parent.AbsoluteSize.Y
local Ratio1 = 8.5/11
local SizeX1 = SizeY1*Ratio1
script.Parent.Size = UDim2.new(0, SizeX1*2, .75 ,0)
script.Parent.Position = UDim2.new(.5, -SizeX1, .5,-SizeY1/2)
script.Parent.Visible = false
script.Parent:WaitForChild("BGL").Visible = true
script.Parent:WaitForChild("BGR").Visible = true
script.Parent:WaitForChild("BottomFrame").Visible = true