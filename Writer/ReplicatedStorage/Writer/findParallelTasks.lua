local module
local _ = pcall(function()
	module = game:GetService("ServerScriptService").ParallelTasks
end) or pcall(function()
	module = game:GetService("ReplicatedStorage").ParallelTasks
end)
if not module then
	module = game:GetService("ServerScriptService"):FindFirstChild("ParallelTasks", true)
		or game:GetService("ReplicatedStorage"):FindFirstChild("ParallelTasks", true)
end
return if module then require(module) else false