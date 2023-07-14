local ParallelTasks = require(script.Parent.findParallelTasks)
local PageCounter = {}
function PageCounter.CountAsync(content, contentTable)
	return ParallelTasks.RunAsync(script, "_calculatePageCount", content, contentTable)
end

local CustomMarkdown = require(script.Parent.CustomMarkdown)
local PreRender = require(script.Parent.PreRender)
function PageCounter._calculatePageCount(content, contentTable)
	local elements = CustomMarkdown.ParseText(content, contentTable)
	local count = PreRender.CountPagesDesync(elements)
	return count
end
return PageCounter