local gui = require(script.Parent:WaitForChild("Gui"):WaitForChild("UpcomingEventsGui"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage.Remotes:WaitForChild("UpcomingEvents")
local countdown -- in seconds
local function setCountdown(seconds)
	if countdown then
		countdown = seconds
		return
	end
	countdown = seconds
	coroutine.wrap(function()
		while true do
			gui:SetStatus(string.format("Loading failed.\nRetrying in %d seconds.", countdown))
			local dt = wait(1)
			if not countdown then
				break
			else
				countdown -= dt
			end
		end
	end)()
end
remote.OnClientEvent:Connect(function(data)
	if data == false then
		gui:SetStatus("Loading failed")
		remote:Destroy()
	elseif data == true then
		gui:SetStatus("Loading...")
	elseif type(data) == "number" then
		setCountdown(data)
	else
		gui:SetEventsClass(require(ReplicatedStorage.CommunityBoards.UpcomingEventsInterpreter)(data))
		remote:Destroy()
	end
end)
remote:FireServer()