-- Command-line script to color an 8x8 board with tiles named 1 through 64 (select one tile before running)
local dark = Color3.fromRGB(62, 62, 62) -- Black
local light = Color3.fromRGB(220, 0, 40) -- Red
local dark = Color3.fromRGB(130, 255, 120) -- Green
local light = Color3.fromRGB(255, 255, 255) -- White
local dark = Color3.fromRGB(82, 45, 16) -- Dark Brown
local dark = Color3.fromRGB(111, 60, 21) -- Brown
local light = Color3.fromRGB(222, 178, 82) -- Light Brown
for _, v in ipairs(game.Selection:Get()[1].Parent:GetChildren()) do
	local n = tonumber(v.Name)
	if not n then continue end
	local row = math.floor((n - 1) / 8)
	v.Color = if n % 2 == row % 2 then dark else light
end