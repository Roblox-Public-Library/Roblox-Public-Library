local p = script.Parent
local Sizes = require(p.Sizes)
local ReaderConfig = {}
ReaderConfig.__index = ReaderConfig
function ReaderConfig.new(defaultFont, normalSize, defaultColor, colors)
	return setmetatable({
		DefaultFont = typeof(defaultFont) == "string" and defaultFont or error("defaultFont must be a string", 2),
		NormalSize = normalSize,
		DefaultColor = defaultColor, --:Color3
		Colors = colors or error("Colors is mandatory", 2),
	}, ReaderConfig)
end
function ReaderConfig:ApplyDefaultsToLabel(label)
	label.Font = Enum.Font[self.DefaultFont]
	label.TextSize = self.NormalSize
	label.TextColor3 = self.DefaultColor
end
function ReaderConfig:GetSizeFor(size)
	--	size must be "large" or "small"
	return math.floor(self.NormalSize * Sizes[size] + 0.5)
end
return ReaderConfig