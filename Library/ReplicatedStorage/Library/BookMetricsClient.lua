local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = require(ReplicatedStorage.Utilities)
local Event = Utilities.Event

local BookMetrics = require(script.Parent.BookMetrics)

local metrics
function BookMetrics.Get()
	return metrics or BookMetrics.GetFromData(nil)
end
function BookMetrics.GetAsync() -- yields if none available yet
	return metrics or BookMetrics.Changed:Wait()
end
BookMetrics.Changed = Event.new()

local bmc = ReplicatedStorage.Remotes:WaitForChild("BookMetricsChanged")
bmc.OnClientEvent:Connect(function(data)
	metrics = BookMetrics.GetFromData(data)
	BookMetrics.Changed:Fire(metrics)
end)
bmc:FireServer()

return BookMetrics