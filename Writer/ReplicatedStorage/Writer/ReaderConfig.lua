local Utilities = game:GetService("ReplicatedStorage").Utilities
local Assert = require(Utilities.Assert)
local p = script.Parent
local Sizes = require(p.Sizes)
local ReaderConfig = {}
ReaderConfig.__index = ReaderConfig
function ReaderConfig.new(defaultFont, normalSize, colors)
	if not colors then error("Colors is mandatory", 2) end
	return setmetatable({
		DefaultFont = Assert.String(defaultFont),
		NormalSize = Assert.Integer(normalSize),
		Colors = colors,
	}, ReaderConfig)
end
function ReaderConfig:ApplyDefaultsToLabel(label)
	label.Font = Enum.Font[self.DefaultFont]
	label.TextSize = self.NormalSize
	label.TextColor3 = self.DefaultColor
end
function ReaderConfig:GetSize(sizeKey)
	--	sizeKey must be "Normal", "Large", "Small", or nil for default
	return if sizeKey then math.floor(self.NormalSize * Sizes[sizeKey] + 0.5)
		else self.NormalSize
end
function ReaderConfig:GetColor(colorKey)
	return if colorKey then self.Colors[colorKey]
		else self.Colors.Default
end
function ReaderConfig:GetHexColor(colorKey)
	return if colorKey then self.Colors.Hex[colorKey]
		else self.Colors.Hex.Default
end
function ReaderConfig:GetFontFace(font) -- Here for future, to support reader preferences
	return font
end
return ReaderConfig