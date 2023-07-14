local module = {}
local PRIVATE = false -- to make it easier to see at a glance which children are private in following table
local childrenToExport = {
	BookContent = true,
	Chapter = true,
	Colors = true,
	CustomMarkdown = true,
	Elements = true,
	findParallelTasks = PRIVATE,
	Format = true,
	ImageHandler = true,
	Page = true,
	PageCounter = true,
	PageSpaceTracker = true,
	PreRender = true,
	ReaderConfig = true,
	Render = true,
	RichText = true,
	RichTextCompiler = PRIVATE,
	RomanNumerals = true,
	Sizes = true,
	Styles = true,
	TextBlockFactory = true,
}
for name, export in childrenToExport do
	if export then
		module[name] = script:WaitForChild(name)
	else
		script:WaitForChild(name)
	end
end
for name, child in module do
	module[name] = require(child)
end
return module