local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.CommunityBoards.UpcomingEvents)
local TimeZoneAbbreviations = require(ReplicatedStorage.TimeZoneAbbreviations)

local timeZoneFull = os.date("%Z", os.time())
local timeZoneDesc = " " .. (TimeZoneAbbreviations[timeZoneFull] or timeZoneFull:gsub("[a-z ]+", "")) -- gsub performs "Eastern Standard Time" -> "EST"

local function formatTime(event)
	return event.CustomWhen
		or event:GetTime("%a %b %d, %Y at %I:%M%p") -- Fri Dec 01, 2020 at 05:30PM
		:gsub("0(%d,)", "%1") -- 01 -> 1
		:gsub("0(%d:%d+%w+)", "%1") -- 05:30PM -> 5:30PM
		:gsub("AM", "am")
		:gsub("PM", "pm") .. timeZoneDesc
		-- At this point, it will be "Fri Dec 31, 2020 at 5:30pm EST"
end

local gui = workspace.CommunityBoards.UpcomingEvents.SurfaceGui
gui.Adornee = gui.Parent
gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local sf = gui.Frame.ScrollingFrame
local firstEventFrame = sf.Event
firstEventFrame.Parent = nil
local eventFrames = {firstEventFrame}
local descSizeX = firstEventFrame.Desc.Size.X
local eventToFrame
local function updateEvents(events)
	eventToFrame = {}
	for i, event in ipairs(events) do
		local eventFrame = eventFrames[i]
		if not eventFrame then
			eventFrame = firstEventFrame:Clone()
			eventFrames[i] = eventFrame
		end
		eventFrame.When.Text = formatTime(event)
		eventFrame.Title.Text = ("<b>%s</b> - <i>Hosted by</i> %s"):format(event.Name, event.HostedBy)
		local descObj = eventFrame.Desc
		descObj.Text = event.Desc
		eventFrame.Parent = sf -- Note: must parent before using AbsoluteSize/AbsolutePosition
		-- Note: Size manipulation based on AbsolutePosition/etc will be unnecessary when Roblox's AutomaticSize feature goes live
		eventFrame.Size = UDim2.new(descSizeX, UDim.new(0, descObj.AbsolutePosition.Y - eventFrame.AbsolutePosition.Y + descObj.AbsoluteSize.Y + 15))
	end
	for i = #events + 1, #eventFrames do
		eventFrames[i].Parent = nil -- High chance of re-use so won't Destroy (also mustn't destroy the firstEventFrame)
	end
	do -- Note: following unnecessary when Roblox's AutomaticCanvasSize feature goes live
		local last = eventFrames[#eventFrames]
		sf.CanvasSize = UDim2.new(0, 0, 0, last.AbsolutePosition.Y - sf.AbsolutePosition.Y + last.AbsoluteSize.Y)
	end
end
updateEvents(Events:GetCurrentEvents())

local box = gui.Frame.Search
local includePastButton = gui.Frame.IncludePast
local includePastCheckbox = includePastButton.Box
local function includePast()
	return includePastCheckbox.Text == "X"
end
local function update()
	if box.Text == "" then
		updateEvents(includePast() and Events:GetAllEvents() or Events:GetCurrentEvents())
	else
		updateEvents(Events:Search(box.Text, includePast(), formatTime))
	end
end
includePastButton.Activated:Connect(function()
	includePastCheckbox.Text = includePast() and "" or "X"
	update()
end)
box:GetPropertyChangedSignal("Text"):Connect(function()
	box.Font = box.Text == "" and Enum.Font.SourceSansItalic or Enum.Font.SourceSans
	update()
end)