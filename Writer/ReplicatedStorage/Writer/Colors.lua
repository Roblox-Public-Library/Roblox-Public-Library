local function newColors(colors)
	colors.Grey = colors.Gray
	colors.Default = colors.Black
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
local Colors = {
	-- Light and Dark mode
	Light = newColors({
		Red = Color3.fromRGB(236, 0, 0),
		Orange = Color3.fromRGB(255, 127, 0),
		Yellow = Color3.fromRGB(216, 208, 0),
		Green = Color3.fromRGB(0, 255, 0),
		Blue = Color3.fromRGB(0, 0, 255),
		Indigo = Color3.fromRGB(100, 0, 176),
		Purple = Color3.fromRGB(160, 0, 160),
		Violet = Color3.fromRGB(127, 0, 255),
		Pink = Color3.fromRGB(255, 100, 220),
		Brown = Color3.fromRGB(125, 95, 70),
		Gray = Color3.fromRGB(115, 115, 115),
		NearBlack = Color3.fromRGB(25, 25, 25),
		Black = Color3.fromRGB(0, 0, 0),
	}),
	Dark = newColors({
		Red = Color3.fromRGB(255, 0, 0),
		Orange = Color3.fromRGB(255, 127, 0),
		Yellow = Color3.fromRGB(255, 255, 0),
		Green = Color3.fromRGB(0, 255, 0),
		Blue = Color3.fromRGB(0, 85, 255),
		Indigo = Color3.fromRGB(100, 0, 176),
		Purple = Color3.fromRGB(160, 0, 160),
		Violet = Color3.fromRGB(127, 0, 255),
		Pink = Color3.fromRGB(255, 100, 220),
		Brown = Color3.fromRGB(125, 95, 70),
		Gray = Color3.fromRGB(140, 140, 140),
		NearBlack = Color3.fromRGB(230, 230, 230),
		Black = Color3.fromRGB(255, 255, 255),
	}),
}
function Colors.NearestColor(color) -- Given a Color3, returns the name of the nearest color in the set of Light colors
	local bestDif, bestName
	for name, c in pairs(Colors.Light) do
		if name == "Hex" then continue end
		local dif = (c.R - color.R) ^ 2 + (c.G - color.G) ^ 2 + (c.B - color.B) ^ 2
		if not bestDif or dif < bestDif then
			bestDif = dif
			bestName = name
		end
	end
	return bestName
end
return Colors