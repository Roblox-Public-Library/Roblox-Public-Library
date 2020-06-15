local Combination = {
	-- Note: combinations are put in alphabetical order (ex AltCtrl not CtrlAlt)
	None = 0,
	Shift = 1,
	Ctrl = 2,
	CtrlShift = 3,
	Alt = 4,
	AltShift = 5,
	AltCtrl = 6,
	AltCtrlShift = 7,
	Meta = 8,
	-- Expand to have Meta combinations if needed
}
local function get(shift, ctrl, alt, meta)
	--	returns a key suitable for a table that represents the combination of shift/etc
	-- Roblox's ModifierKey has shift at 0, ctrl at 1, alt at 2, meta at 3
	return (shift and 1 or 0)
		+ (ctrl and 2 or 0)
		+ (alt and 4 or 0)
		+ (meta and 8 or 0)
end
Combination.Get = get
function Combination.Contains(combination, modifierKey)
	return bit32.btest(combination, 2^modifierKey.Value)
end

local Shift = Enum.ModifierKey.Shift
local Ctrl = Enum.ModifierKey.Ctrl
local Alt = Enum.ModifierKey.Alt
local Meta = Enum.ModifierKey.Meta
function Combination.FromInput(input, ignoreShift)
	return get(
		not ignoreShift and input:IsModifierKeyDown(Shift),
		input:IsModifierKeyDown(Ctrl),
		input:IsModifierKeyDown(Alt),
		input:IsModifierKeyDown(Meta))
end

return Combination