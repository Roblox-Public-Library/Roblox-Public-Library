local function newColors(colors)
	colors.Grey = colors.Gray
	colors.Purple = colors.Violet
	local hex = {}
	for name, color in pairs(colors) do
		hex[name] = string.format("#%.2X%.2X%.2X",
			color.R * 255,
			color.G * 255,
			color.B * 255)
	end
	colors.Hex = hex
	return colors
end
local light = {
	Red = Color3.fromRGB(255, 0, 0),
	Orange = Color3.fromRGB(255, 127, 0),
	Yellow = Color3.fromRGB(255, 255, 0),
	Green = Color3.fromRGB(0, 255, 0),
	Blue = Color3.fromRGB(0, 0, 255),
	Indigo = Color3.fromRGB(46, 43, 95),
	Violet = Color3.fromRGB(139, 0, 255),
	Pink = Color3.fromRGB(255, 192, 203),
	Gray = Color3.fromRGB(119, 119, 119),
	Black = Color3.fromRGB(0, 0, 0),
}
light.Default = light.Black
light = newColors(light)
return {
	-- Light and Dark mode
	Light = light,
	Dark = light, -- todo
}