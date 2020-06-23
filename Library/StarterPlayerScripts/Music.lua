-- TODO rewrite to work with Playlist.server
local oldMusic = {3, 2}
local newMusic = {3, 2}
local killed = false
local futMusic = {}
local oldTrack = nil
local newTrack = nil
local debounce = false
local switching = script:WaitForChild("Switching")
local currentTrack = script:WaitForChild("CurrentTrack")
local location = script:WaitForChild("Location")
local playlist = script.Parent:WaitForChild("BookGui"):WaitForChild("Playlist")
local volume = .3
local onOff = script.Parent:WaitForChild("BookGui"):WaitForChild("Music")
local songEndDebouce = false

local rnd = Random.new()
local function mostlyShuffle(list) -- todo use this instead of picking random music each time
	--	shuffles the list but prevents the last element from becoming first (to avoid repetition)
	local index
	local n = #list
	for i = 1, n - 1 do
		index = rnd:NextNumber(i, i == 1 and n - 1 or n)
		list[i], list[index] = list[index], list[i]
	end
end

local function playMusic()
	if oldTrack ~= nil and oldTrack.IsPlaying == true then
		oldTrack:Stop()
		oldTrack.Volume = 0
	end
	while true do
		newTrack = newMusic[math.random(#newMusic)]
		if newTrack ~= oldTrack then break end
		wait()
	end
	currentTrack.Value = newTrack
	oldTrack = newTrack
	newTrack.Volume = volume
	wait(.5)
	newTrack:Play()
end
local function musicEnder()
	if not songEndDebouce and oldMusic[1] ~= newMusic[1] then
	elseif not songEndDebouce then
		songEndDebouce = true
		wait(1)
		playMusic()
		wait(2)
		songEndDebouce = false
	end
end

local function setMusic(musicSet)
	futMusic = musicSet:GetChildren()
	if musicSet.Name == "Custom" then
		if musicSet:FindFirstChild("Sound") == nil then
		else
			if not debounce and not switching.Value and oldMusic[1] == 3 or not debounce and not switching.Value and futMusic[1].Parent ~= oldMusic[1].Parent then
				newMusic = futMusic
				if oldMusic[1] == 3 then
					oldMusic = newMusic
				else
					for _,v in pairs(oldMusic) do
						v:Stop()
						v.Volume = 0
					end
				end
				oldMusic = newMusic
				debounce = true
				switching.Value = true
				playMusic()
				wait()
				debounce = false
				for _,v in pairs(newMusic) do
					v.Ended:Connect(musicEnder)
				end
				wait(.5)
				switching.Value = false
			end
		end
	elseif musicSet.Name == "Temp" then
	else
		if not debounce and not switching.Value and oldMusic[1] == 3 or not debounce and not switching.Value and futMusic[1].Parent ~= oldMusic[1].Parent then
			newMusic = futMusic
			if oldMusic[1] == 3 then
				oldMusic = newMusic
			else
				for _,v in pairs(oldMusic) do
					v:Stop()
					v.Volume = 0
				end
			end
			oldMusic = newMusic
			debounce = true
			switching.Value = true
			playMusic()
			wait()
			debounce = false
			for _,v in pairs(newMusic) do
				v.Ended:Connect(musicEnder)
			end
			wait(.5)
			switching.Value = false
		end
	end
end
script:WaitForChild("MusicEvent").Event:Connect(setMusic)

game.Players.LocalPlayer.Chatted:Connect(function(mssgi)
	local telk = string.lower(mssgi)
	if telk == "/next" then
		newTrack:Stop()
		musicEnder()
	elseif telk == "/center" then
		setMusic(script:WaitForChild("Center"))
	elseif telk == "/gravity" then
		setMusic(script:WaitForChild("Gravity"))
	elseif telk == "/time" then
		setMusic(script:WaitForChild("Time"))
	elseif telk == "/space" then
		setMusic(script:WaitForChild("Space"))
	elseif telk == "/cafe" then
		setMusic(script:WaitForChild("Cafe"))
	elseif telk == "/hallse" then
		setMusic(script:WaitForChild("Halls"))
	end
end)

playlist.Changed:Connect(function()
	if playlist.Value == "Center" then
		setMusic(script:WaitForChild("Center"))
	elseif playlist.Value == "Mute" then
		volumeStop(script)
	elseif playlist.Value == "GOCRAZY" then
		print("GOCRAZY")
		killed = true
		for i,v in pairs(script:WaitForChild("Center"):GetChildren()) do
			v.Volume = .5
			v:Play()
		end
	elseif playlist.Value == "Main" then
		setMusic(script:WaitForChild("Main"))
	elseif playlist.Value == "Gravity" then
		setMusic(script:WaitForChild("Gravity"))
	elseif playlist.Value == "Time" then
		setMusic(script:WaitForChild("Time"))
	elseif playlist.Value == "Space" then
		setMusic(script:WaitForChild("Space"))
	elseif playlist.Value == "Cafe" then
		setMusic(script:WaitForChild("Cafe"))
	elseif playlist.Value == "Halls" then
		setMusic(script:WaitForChild("Halls"))
	elseif playlist.Value == "Custom Playlist" then
		setMusic(script:WaitForChild("Custom"))
	elseif playlist.Value == "Location Based" then
		if location.Value == "Main" then
			setMusic(script:WaitForChild("Main"))
		elseif location.Value == "Center" then
			setMusic(script:WaitForChild("Center"))
		elseif location.Value == "Gravity" then
			setMusic(script:WaitForChild("Gravity"))
		elseif location.Value == "Time" then
			setMusic(script:WaitForChild("Time"))
		elseif location.Value == "Space" then
			setMusic(script:WaitForChild("Space"))
		elseif location.Value == "Cafe" then
			setMusic(script:WaitForChild("Cafe"))
		elseif location.Value == "Halls" then
			setMusic(script:WaitForChild("Halls"))
		end
	end
end)

location.Changed:Connect(function()
	if playlist.Value == "Location Based" then
		if location.Value == "Main" then
			setMusic(script:WaitForChild("Main"))
		elseif location.Value == "Center" then
			setMusic(script:WaitForChild("Center"))
		elseif location.Value == "Gravity" then
			setMusic(script:WaitForChild("Gravity"))
		elseif location.Value == "Time" then
			setMusic(script:WaitForChild("Time"))
		elseif location.Value == "Space" then
			setMusic(script:WaitForChild("Space"))
		elseif location.Value == "Cafe" then
			setMusic(script:WaitForChild("Cafe"))
		elseif location.Value == "Halls" then
			setMusic(script:WaitForChild("Halls"))
		end
	end
end)

function volumeDown(items)
	for i, v in pairs(items:GetChildren()) do
		if v:IsA("Sound") then
			v.Volume = 0
		else
			volumeDown(v)
		end
	end
end

function volumeStop(items)
	for i, v in pairs(items:GetChildren()) do
		if v:IsA("Sound") then
			v.Volume = 0
			v:Stop()
		else
			volumeStop(v)
		end
	end
end

onOff.Changed:Connect(function()
	if onOff.Value == true then
		volume = .3
		currentTrack.Value.Volume = volume
	else
		volume = 0
		volumeDown(script)
	end
end)


setMusic(script:WaitForChild("Center"))

game.Players.LocalPlayer.CharacterAdded:Connect(function(char)
	char:WaitForChild("Humanoid").Died:Connect(function()
		if not killed then
		volumeStop(script)
		else
			wait(5)
			volumeStop(script)
		end
	end)
end)