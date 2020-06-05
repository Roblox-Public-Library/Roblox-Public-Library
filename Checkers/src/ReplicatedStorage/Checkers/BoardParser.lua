local Board = require(script.Parent.Board)

local module = {}
function module.Parse(s, redOnTop)
	local grid = {}
	for x = 1, 8 do grid[x] = {} end
	local y = 0
	for row in string.gmatch(s, "([^\n]+)") do
		y = y + 1
		for x = 1, 8 do
			local c = row:sub(x, x)
			grid[x][y] = c ~= "." and c or false
		end
	end
	return Board.fromGrid(grid, redOnTop)
end
function module.ToString(board)
	local s = {}
	for y = 1, 8 do
		for x = 1, 8 do
			s[#s + 1] = board:Get(Vector2.new(x, y)) or "."
		end
		s[#s + 1] = "\n"
	end
	return table.concat(s)
end

return module