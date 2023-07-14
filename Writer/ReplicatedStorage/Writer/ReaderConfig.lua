local Utilities = game:GetService("ReplicatedStorage").Utilities
local Assert = require(Utilities.Assert)
local Class = require(Utilities.Class)

local Writer = script.Parent
local Colors = require(Writer.Colors)
local Sizes = require(Writer.Sizes)

local ReaderConfig = Class.New("ReaderConfig")
function ReaderConfig.new(defaultFont, normalSize, colors)
	if not colors then error("Colors is mandatory", 2) end
	return setmetatable({
		DefaultFont = Assert.Enum(defaultFont, Enum.Font),
		NormalSize = Assert.Integer(normalSize),
		Colors = colors,
		DefaultColor = colors.Default,
	}, ReaderConfig)
end
ReaderConfig.Default = ReaderConfig.new(Enum.Font.SourceSans, 18, Colors.Light)
ReaderConfig.DefaultDark = ReaderConfig.new(Enum.Font.SourceSans, 18, Colors.Dark)
function ReaderConfig:ApplyDefaultsToLabel(label)
	label.Font = self.DefaultFont
	label.TextSize = self.NormalSize
	label.TextColor3 = self.DefaultColor
end
function ReaderConfig:ApplyNonSizeDefaultsToLabel(label)
	label.Font = self.DefaultFont
	label.TextColor3 = self.DefaultColor
end
function ReaderConfig:GetSize(sizeKey, subOrSuperScript)
	--	sizeKey must be "Normal", "Large", "Small", or nil for default
	--	subOrSuperScript must be "Sub" or "Super"
	if sizeKey == "Sub" or sizeKey == "Super" then error("Cannot have Sub/Super as sizeKey", 2) end
	return (if sizeKey then math.floor(self.NormalSize * Sizes[sizeKey] + 0.5)
		else self.NormalSize) * (Sizes[subOrSuperScript] or 1)
end
function ReaderConfig:GetColor(colorKey)
	return if colorKey then self.Colors[colorKey]
		else self.Colors.Default
end
function ReaderConfig:GetHexColor(colorKey)
	return if colorKey then self.Colors.Hex[colorKey]
		else self.Colors.Hex.Default
end
function ReaderConfig:GetColorCode(colorCode) -- color code is like "rgb(255,125,0)"
	if self.Colors == Colors.Light then return colorCode end
	local r, g, b = colorCode:match("(%d+),(%d+),(%d+)")
	return string.format("rgb(%d,%d,%d)", 255 - r, 255 - g, 255 - b)
end
function ReaderConfig:GetFont(font)
	if font then
		-- TODO - can implement font blacklisting/whitelisting here
		return font
	else
		return self.DefaultFont
	end
end
function ReaderConfig:CloneWith(props)
	return setmetatable(props, {__index = function(clone, key)
		return ReaderConfig[key] or self[key]
	end})
end
return ReaderConfig