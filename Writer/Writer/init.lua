local module = {}
local children = {
	"Colors",
	"Cursor",
	"Elements",
	--"Font",
	"Format",
	--"Formats",
	"CustomMarkdown",
	"ReaderConfig",
	"RobloxRichTextRenderer",
	"SpaceLeft",
}
for _, name in ipairs(children) do
	module[name] = require(script:WaitForChild(name))
end
return module