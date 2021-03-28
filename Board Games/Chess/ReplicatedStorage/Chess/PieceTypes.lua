-- todo are these pieces instead of types?
local PieceTypes = {}
local pieceTypes = {}
local teams = {"White", "Black"}
local teamToPieceTypes = {}
for _, team in ipairs(teams) do
	local toPieceTypes = {}
	teamToPieceTypes[team] = toPieceTypes
	for _, type in ipairs({"King", "Queen", "Rook", "Bishop", "Knight", "Pawn"}) do
		local id = #pieceTypes + 1
		local pieceType = {
			Id = id,
			Team = team,
			Type = type,
		}
		pieceTypes[id] = pieceType
		toPieceTypes[type] = pieceType
	end
end
function PieceTypes.GetId(team, type)
	return teamToPieceTypes[team][type].Id
end
function PieceTypes.FromId(id)
	return pieceTypes[id]
end
return PieceTypes