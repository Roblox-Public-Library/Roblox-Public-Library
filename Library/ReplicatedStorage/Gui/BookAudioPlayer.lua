return function(audioFrame)

local BookAudioPlayer = {}

local TIME_INCREMENT = 10

local ContentProvider = game:GetService("ContentProvider")
local localPlayer = game:GetService("Players").LocalPlayer

local audioToggle = audioFrame.Audio
local back = audioFrame.Back
local forward = audioFrame.Forward
local togglePause = audioFrame.TogglePause
local speed = audioFrame.Speed
local stop = audioFrame.Stop
local audioControls = {back, forward, togglePause, speed, stop}

local audioSound = Instance.new("Sound")
audioSound.Name = "AudioBook"
audioSound.Parent = localPlayer

local pitchShift1 = Instance.new("PitchShiftSoundEffect")
pitchShift1.Octave = 1
pitchShift1.Parent = audioSound
local pitchShift2 = Instance.new("PitchShiftSoundEffect")
pitchShift2.Octave = 1
pitchShift2.Parent = audioSound
local function setSpeed(s)
	audioSound.PlaybackSpeed = s
	if s < 0.5 then
		pitchShift1.Octave = 0.5
		s *= 2
	elseif s > 2 then
		pitchShift1.Octave = 2
		s /= 2
	else
		pitchShift1.Octave = 1 / s
		pitchShift2.Octave = 1
		return
	end
	pitchShift2.Octave = 1 / s
end
local function setAudioControlsVisible(visible)
	for _, button in ipairs(audioControls) do
		button.Visible = visible
	end
end
setAudioControlsVisible(false)
audioToggle.Activated:Connect(function()
	setAudioControlsVisible(not back.Visible)
end)
back.Number.Text = TIME_INCREMENT
forward.Number.Text = TIME_INCREMENT
back.Activated:Connect(function()
	audioSound.TimePosition = math.max(0, audioSound.TimePosition - TIME_INCREMENT)
end)
forward.Activated:Connect(function()
	audioSound.TimePosition = math.min(audioSound.TimeLength, audioSound.TimePosition + TIME_INCREMENT)
end)
local playRectOffset = Vector2.new(764, 244)
local pauseRectOffset = Vector2.new(804, 124)
togglePause.Activated:Connect(function()
	if audioSound.IsPlaying then
		audioSound:Pause()
	else
		audioSound:Resume()
	end
end)
audioSound:GetPropertyChangedSignal("Playing"):Connect(function()
	togglePause.ImageRectOffset = if audioSound.IsPlaying
		then pauseRectOffset
		else playRectOffset
end)
stop.Activated:Connect(function()
	audioSound:Stop()
end)

local prevSpeed = 1
local function formatSpeed(s)
	return if s % 1 == 0
		then string.format("%.1f", s)
		else string.format("%.2f", s)
end
speed.FocusLost:Connect(function(submitted)
	if not submitted then
		speed.Text = formatSpeed(prevSpeed)
		return
	end
	local s = tonumber(speed.Text)
	if not s then
		speed.Text = formatSpeed(prevSpeed)
		return
	end
	s = math.clamp(math.floor(s * 100 + 0.5) / 100, 0.25, 4)
	speed.Text = formatSpeed(s)
	prevSpeed = s
	setSpeed(s)
end)

local function idToSoundId(id)
	return "rbxassetid://" .. id
end

local audioIds -- list of ids as formatted by idToSoundId
local index
function BookAudioPlayer:SetBookAudioList(audioIdNums) -- should be nil when book has no audio
	if audioIdNums then
		audioIds = table.create(#audioIdNums)
		for i, id in ipairs(audioIdNums) do
			audioIds[i] = idToSoundId(id)
		end
		ContentProvider:PreloadAsync(audioIds)
		index = 1
		audioSound.SoundId = audioIds[1]
		audioFrame.Visible = true
	else
		audioFrame.Visible = false
	end
end
audioSound.Ended:Connect(function()
	if index < #audioIds then
		index += 1
		audioSound.SoundId = audioIds[index]
		audioSound.TimePosition = 0
		audioSound:Play()
	end
end)
function BookAudioPlayer:GetBookmarkTime()
	return {Index = index, Time = math.floor(audioSound.TimePosition)}
end
function BookAudioPlayer:RestoreBookmarkTime(bookmark)
	if bookmark.Index > #audioIds then print("Invalid bookmark", bookmark, "- only", #audioIds, "tracks") return end
	index = bookmark.Index
	audioSound.SoundId = audioIds[index]
	audioSound.TimePosition = bookmark.Time
end
function BookAudioPlayer:BookmarkTimeToString(bookmark)
	local indexString
	if bookmark.Index == 1 and #audioIds == 1 then
		indexString = ""
	else
		indexString = "#" .. bookmark.Index .. " - "
	end
	local min = math.floor(bookmark.Time / 60)
	local sec = bookmark.Time % 60
	return string.format("(%s%d:%02d", indexString, min, sec)
end
function BookAudioPlayer:BookClosed()
	audioSound:Stop()
	audioIds = nil
end
return BookAudioPlayer


end