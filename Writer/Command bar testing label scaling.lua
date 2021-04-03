-- Command bar testing label scaling
--[[CONCLUSIONS:
It is best to cap the text size.Y to math.ceil(originalY * scalingMultiplier)
Although the worst case can have some lines dramatically smaller than others (up to even 30% or 50% different),
if most lines are normal English (rather than the same character repeated), I don't expect it'll be too bad
Most fonts, even in the worst case, are in the range of 10% - 20% different.
]]


local widthToHeightRatio = 2
function create(parent, name, type)
	local child = Instance.new(type or name)
	child.Name = name
	child.Parent = parent
	return child
end
local gui = create(game.Players.LocalPlayer.PlayerGui, "TestGui", "ScreenGui")
local sf = create(gui, "ScrollingFrame")
sf.Size = UDim2.new(1, -100, 1, 0)
sf.CanvasSize = UDim2.new(0, 0, 0, 0)
sf.AutomaticCanvasSize = "Y"
--local ui = create(sf, "UIListLayout")
--ui.SortOrder = "LayoutOrder"
local button = create(gui, "Continue", "TextButton")
button.AnchorPoint = Vector2.new(1, 1)
button.Position = UDim2.new(1, 0, 1, 0)
button.Size = UDim2.new(0, 100, 0, 40)
button.Text = "Continue"
button.ZIndex = 2
button.TextScaled = true
--local frame = create(gui, "Frame", "Frame")
--[[local textLabel_ = create(frame, "TextLabel_", "TextLabel")

-- Make some labels at different texts (same size, not scaled) that all fit in uniform size
-- trim sizes to fit their TextBounds
-- set label scaling to true
function resize(obj)
    -- Not permanent and probably won't even work, but just for testing for now
    local minWidth, maxWidth = 10, 100
    obj.Size = UDim2.new(
		0, math.min(minWidth, textBox.TextBounds.X),
		0, math.max(maxWidth, textBox.TextBounds.X)
	)
    --return obj[TextScaled]
end

function createLabel(text)
    local Label = Instance.new("TextLabel", frame)
    ---------------------------------
    Label.Name = "TextLine"
    Label.Parent = frame -- extra check for the corect parent
    Label.Text = tostring(text)
    ---------------------------------
    wait(0.01)
    resize(Label) -- resize the label
end

-- textLabel_:GetPropertyChangedSignal("TextBounds"):Connect(resize(textLabel_)) -- test the resizing function if it works or errors or even does anything
]]
local function createLabel(text, i)
	local label = create(sf, text:sub(1, 1), "TextLabel")
	label.TextSize = 25
	label.TextScaled = false
	label.Text = text
	label.TextXAlignment = "Left"
	label.TextYAlignment = "Top"
	label.Position = UDim2.new(0, 0, 0, (i - 1) * 35)
	return label
end

local labels = {}
local ranges = {{48, 57}, {65, 90}, {97, 122}} -- don't use 32 as Roblox measures all whitespace as if it weren't there
local i = 0
for _, r in ipairs(ranges) do
	for c = r[1], r[2] do
		i += 1
		labels[i] = createLabel(string.rep(string.char(c), 40), i)
	end
end

local origSize = {}
local function changeFont(font)
	for i, label in ipairs(labels) do
		label.TextScaled = false
		label.Font = font
		label.Size = UDim2.new(0, 10000, 0, 1000)
		origSize[i] = label.TextBounds
		label.Size = UDim2.new(0, label.TextBounds.X, 0, 1000)
		label.TextScaled = true
	end
	--print(font, unpack(origSize))
	--[[
	button.Activated:Wait()
	for i, label in ipairs(labels) do
		label.TextScaled = true
		if label.TextBounds ~= origSize[i] then
			print(i, ":", origSize[i], label.TextBounds)
		end
	end
	button.Activated:Wait()
	--]]
end

-- For every size we want to try out (every few pixels or every pixel between 100 wide and 400)
-- Test & return maximum font size difference between all labels (based on TextBounds.Y)
-- Compile max font size difference for all different sizes
function measureDif(multiplier) -- return the highest TextBounds.Y - lowest
	local size = {}
	local best, worst, bestChar, worstChar
	for i, label in ipairs(labels) do
		local orig = origSize[i]
		label.Size = UDim2.new(0, orig.X * multiplier, 0, math.ceil(orig.Y * multiplier)) --1000)
		--size[i] =
		local size = label.TextBounds.Y
		if not best or size > best then
			best = size
			bestChar = label.Name
		end
		if not worst or size < worst then
			worst = size
			worstChar = label.Name
		end
	end
	return worst, best, worstChar, bestChar
	--return math.min(unpack(size)), math.max(unpack(size)), size
end
--[[
What we need to know

If the server figures out a size
ex it uses font size 25 as normal
so it determines that some amount of text can fit on the first line

then the client will receive this and we want to know how badly it can be different when it attempts to scale it up
	ex, receives: "some text" is to fit in 100x25
	but display is 110 wide so we want to put it at a height of 110/100*25 = 27.5
	then we TextScale it and see what size Roblox actually chooses for this
	we ALSO want to know how much horizontal space is missing
		ex, if "some text" fits in 100x27 then there are 10 pixels of space to the right of it that needn't be there (because the font size isn't perfect)
	OR we set the Y size of the label to be large enough that it always fills the horizontal space

]]

for i, font in ipairs(Enum.Font:GetEnumItems()) do
	local worstSpread = nil
	local worstSize, spread, worstMultiplier, list, worstList, worstChar, bestChar, wChar, bChar
	changeFont(font)
	for multiplier = 80, 140, 10 do
		small, large, wChar, bChar = measureDif(multiplier / 100)
		spread = (large - small) / small
		if not worstSpread or spread > worstSpread then
			worstSpread = spread
			worstMultiplier = multiplier
			--worstSize = labels[51].TextBounds
			worstSize = Vector2.new(small, large)
			--worstList = list
			worstChar = wChar
			bestChar = bChar
		end
		--if multiplier == 100 then button.Activated:Wait() end
	end
	print(("%.3f"):format(worstSpread*100), font, worstMultiplier/100 .. "x", "|", worstSize, worstChar, bestChar, "||")--, unpack(worstList))
	if i % 20 == 0 then wait() end
end