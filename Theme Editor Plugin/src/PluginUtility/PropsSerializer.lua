local PropsSerializer = {}

function PropsSerializer.ColorToNum(c)
	local r = math.floor(c.R * 255 + 0.5)
	local g = math.floor(c.G * 255 + 0.5)
	local b = math.floor(c.B * 255 + 0.5)
	return bit32.replace(bit32.replace(b, g, 8, 8), r, 16, 8)
end
local colorToNum = PropsSerializer.ColorToNum
function PropsSerializer.NumToColor(n)
	local r = bit32.extract(n, 16, 8)
	local g = bit32.extract(n, 8, 8)
	local b = bit32.extract(n, 0, 8)
	return Color3.fromRGB(r, g, b)
end
local numToColor = PropsSerializer.NumToColor
local materialToNum = {}
local numToMaterial = {}
for i, v in ipairs(Enum.Material:GetEnumItems()) do
	materialToNum[v] = i - 1
	numToMaterial[i - 1] = v
end
local bitsNeeded = math.ceil(math.log(#Enum.Material:GetEnumItems()) / math.log(2))
if bitsNeeded > 8 then
	error("More materials than expected; algorithm no longer works")
end
function PropsSerializer.PropsToNum(transparency, reflectance, material, color)
	local n = bit32.replace(
		math.floor(reflectance * 1000 + 0.5), -- lower 10 bits,
		math.floor(transparency * 1000 + 0.5), -- upper 10 bits,
		10, 10)
	n *= 2^32
	local n2 = bit32.replace(
		colorToNum(color),
		materialToNum[material],
		24, bitsNeeded)
	return n2 + n
end
local propsToNum = PropsSerializer.PropsToNum
function PropsSerializer.PartToNum(part)
	return propsToNum(part.Transparency, part.Reflectance, part.Material, part.Color)
end
function PropsSerializer.NumToProps(n)
	--	returns transparency, reflectance, material, color
	local upper = math.floor(n / 2^32)
	return bit32.extract(upper, 10, 10) / 1000,
		bit32.extract(upper, 0, 10) / 1000,
		numToMaterial[bit32.extract(n, 24, bitsNeeded)],
		numToColor(bit32.extract(n, 0, 24))
end

return PropsSerializer