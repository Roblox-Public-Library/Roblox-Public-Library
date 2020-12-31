local ReplicatedStorage = game:GetService("ReplicatedStorage")
local events = require(ReplicatedStorage.CommunityBoards.UpcomingEvents)

local timeFormat = "%a %b %d, %Y at %I:%M%p" -- Fri Dec 31, 2020 at 5:30pm

local gui = workspace.CommunityBoards.UpcomingEvents.SurfaceGui
gui.Adornee = gui.Parent
gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local sf = gui.Frame.ScrollingFrame
local eventFrame = sf.Event
eventFrame.Parent = nil
local eventFrames = {}
for i, event in ipairs(events) do
	local eventFrame = i == 1 and eventFrame or eventFrame:Clone()
	eventFrame.Parent = sf
	eventFrame.Title.Text = ("<b>%s</b> - <i>Hosted by</i> %s"):format(event.Name, event.HostedBy)
	eventFrame.Desc.Text = event.Desc
	eventFrames[i] = eventFrame
end
do -- Note: following unnecessary when Roblox's AutomaticCanvasSize feature goes live
	local last = eventFrames[#eventFrames]
	sf.CanvasSize = UDim2.new(0, 0, 0, last.AbsolutePosition.Y + last.AbsoluteSize.Y)
end

local box = gui.Frame.TimeZone
local prevValue = "not updated"
local function descUTC(timeZoneOffset)
	return "UTC" .. (timeZoneOffset >= 0 and "+" or "") .. timeZoneOffset
end
local function updateBoxDescForTime(timeZoneOffset)
	box.Text = timeZoneOffset and "Timezone: " .. descUTC(timeZoneOffset)
		or os.date("Timezone: %Z (" .. descUTC(events.LocalTimeZoneOffset) .. ")", os.time())
end
local function updateEventTimesLocal(timeZoneOffset)
	if timeZoneOffset == prevValue then return end
	prevValue = timeZoneOffset
	for i, event in ipairs(events) do
		eventFrames[i].When.Text = event:GetTime(timeFormat, timeZoneOffset)
	end
end
box:GetPropertyChangedSignal("Text"):Connect(function()
	box.Font = box.Text == "" and Enum.Font.SourceSansItalic or Enum.Font.SourceSans
	updateEventTimesLocal(tonumber(box.Text) or prevValue)
end)
box.FocusLost:Connect(function(enterPressed)
	local timeZoneOffset = tonumber(box.Text)
	updateBoxDescForTime(timeZoneOffset)
	updateEventTimesLocal(timeZoneOffset)
end)
updateBoxDescForTime()
updateEventTimesLocal()