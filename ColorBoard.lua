-- Command-line script to color an 8x8 board with tiles named 1 through 64 (select one tile before running)
local dark = Color3.fromRGB(62, 62, 62)
local light = Color3.fromRGB(220, 0, 40)
for _, v in ipairs(game.Selection:Get()[1].Parent:GetChildren()) do
	local n = tonumber(v.Name)
	if not n then continue end
	local row = math.floor((n - 1) / 8)
	v.Color = if n % 2 == row % 2 then dark else light
end