return function(tests, t)


local Writer = game:GetService("ReplicatedStorage").Writer
local PageSpaceTracker = require(Writer.PageSpaceTracker)

local w, h = 100, 150
local function new(name, test, args)
	args = args or {}
	args.test = function(...)
		test(PageSpaceTracker.new(w, h), ...)
	end
	tests[name] = args
end
local function newPadded(name, padding, test, args)
	local args = args or {}
	args.test = function(...)
		test(PageSpaceTracker.Padded.new(w, h, padding), ...)
	end
	tests[name] = args
end
local function equals(actual, eX, eY, ...)
	t.truthy(actual, "Return value of Placement function must not be nil", ...)
	t.equals(("%.2f, %.2f"):format(actual.X, actual.Y),
			("%.2f, %.2f"):format(eX, eY), ...)
end

new("WrapLeft", function(p)
	equals(p:PlaceLeft(30, 30), 0, 0)
	t.equals(p:GetWidthRemaining(), w - 30)
	t.equals(p:GetHeightRemaining(), h, "full height available during wrap left")

	equals(p:Place(w - 40, 10), 30, 0)
	equals(p:Place(w - 40, 10), 30, 10)
	equals(p:Place(w - 40, 10), 30, 20)
	equals(p:Place(w - 40, 10), 0, 30, "After image, text goes back to far left")
end)

new("WrapLeftUnalignedLine", function(p)
	equals(p:PlaceLeft(30, 30), 0, 0)
	equals(p:Place(w - 40, 25), 30, 0)
	equals(p:Place(w - 40, 10), 30, 25, "Allow hanging past image")
	--equals(p:Place(w - 40, 10), 0, 30, "Do not hang partially past image - skip to next full line")
end)

new("WrapRight", function(p)
	equals(p:PlaceRight(30, 30), w - 30, 0)
	t.equals(p:GetWidthRemaining(), w - 30)
	t.equals(p:GetHeightRemaining(), h, "full height available during wrap right")

	equals(p:Place(w - 40, 10), 0, 0, "Can place text on same line as right-wrapped image")
	t.equals(p:GetWidthRemaining(), 10)
	equals(p:Place(w - 40, 10), 0, 10)
	t.equals(p:GetWidthRemaining(), 10)
	equals(p:Place(w - 40, 10), 0, 20)
	equals(p:Place(w - 40, 10), 0, 30)
	t.equals(p:GetWidthRemaining(), 40)
end)

new("WrapBothEqualSize", function(p)
	equals(p:PlaceLeft(30, 30), 0, 0)
	equals(p:PlaceRight(30, 30), w - 30, 0, "Can place left & right image on same line")
	equals(p:Place(w - 60, 15), 30, 0, "Can put text in between left & right images")
	equals(p:Place(w - 60, 15), 30, 15)
	equals(p:Place(10, 10), 0, 30, "After both")
	equals(p:Place(w - 10, 10), 10, 30, "Full width available")
end)

new("WrapBothUnequalSize", function(p)
	equals(p:PlaceLeft(30, 30), 0, 0)
	equals(p:PlaceRight(30, 15), w - 30, 0, "Can place left & right image on same line")
	equals(p:Place(w - 60, 5), 30, 0, "Can put text in between left & right images")
	equals(p:Place(w - 30, 5), 30, 15, "For wide element, skip to where it can be placed")
end)

new("OutOfSpace", function(p)
	t.truthy(p:Place(w, h), "Should have room to place page-sized element")
	t.equals(p:OutOfSpace(), true, "Should not have room for more")
	t.falsy(p:Place(1, 1), "Should therefore not be able to place anything")
end)

new("RunOutOfSpace", function(p)
	equals(p:Place(w, h - 10), 0, 0)
	t.falsy(p:Place(w, 11), "Should run out of room")
	t.falsy(p:OutOfSpace(), "State should not be changed")
	equals(p:Place(w, 10), 0, h - 10, "Smaller object should still fit")
end)

local function testGetBottomOfNextObject(p, tests)
	--	tests are a list of {yMin, yMax, expected}
	for _, test in ipairs(tests) do
		for y = test[1], test[2] do
			local expected = test[3]
			if expected then
				t.equals(p:GetBottomOfNextObject(y), expected, "when y =", y)
			else
				t.falsy(p:GetBottomOfNextObject(y), "when y =", y)
			end
		end
	end
end

new("GetBottomOfNextObject Just Left", function(p)
	p:PlaceLeft(10, 10)
	p:PlaceLeft(10, 10)
	testGetBottomOfNextObject(p, {
		--{yMin, yMax, expected}
		{0, 9, 10},
		{10, 19, 20},
		{20, 20},
	})
end)

new("GetBottomOfNextObject Both Sides", function(p)
	p:PlaceLeft(10, 10)
	p:PlaceLeft(10, 10)
	p:Place(w - 10, 5)
	p:PlaceRight(10, 10) -- will start at y = 5 due to text placement
	testGetBottomOfNextObject(p, {
		--{yMin, yMax, expected}
		{0, 9, 10},
		{10, 14, 15},
		{15, 19, 20},
		{20, 20},
	})
end)

new("RunOutOfSpaceWithImages", function(p)
	equals(p:PlaceLeft(w - 10, h - 10), 0, 0)
	t.falsy(p:Place(11, 11), "Should run out of room")
	t.falsy(p:OutOfSpace(), "State should not be changed")
	equals(p:Place(10, 10), w - 10, 0, "Smaller object should still fit beside image")
	equals(p:Place(11, 10), 0, h - 10, "Smaller object should still fit beneath image")
end)

new("QueueWrapLeft", function(p)
	equals(p:PlaceLeft(30, 30), 0, 0)
	equals(p:PlaceLeft(30, 30), 0, 30)
	equals(p:Place(w - 30, 20), 30, 0)
	equals(p:Place(w - 30, 20), 30, 20)
	equals(p:Place(w - 30, 20), 30, 40, "Queued image respected")
	equals(p:Place(w - 30, 20), 0, 60, "After queued image works")
end)

new("CanPlaceRightLast", function(p)
	equals(p:PlaceLeft(30, 30), 0, 0)
	equals(p:Place(w - 60, 25), 30, 0)
	equals(p:PlaceRight(30, 30), w - 30, 0)
end)

new("PlaceLeft2ndWiderTextWorks", function(p)
	equals(p:PlaceLeft(30, 30), 0, 0)
	equals(p:PlaceLeft(60, 30), 0, 30)
	equals(p:Place(w - 30, 20), 30, 0)
	equals(p:Place(10, 20), 60, 20, "Allow text hanging above top of wide image")
end)

new("PlaceRight2ndWiderTextWorks", function(p)
	equals(p:PlaceRight(30, 30), 70, 0)
	equals(p:PlaceRight(60, 30), 40, 30)
	equals(p:Place(w - 30, 20), 0, 0)
	equals(p:Place(10, 20), 0, 20)
end)

new("PlaceRight must consider slightly offset object", function(p)
	equals(p:Place(10, 10), 0, 0)
	equals(p:PlaceLeft(50, 20), 0, 10, "PlaceLeft must go after text")
	equals(p:PlaceRight(60, 20), 40, 30, "PlaceRight considers left object that's down a bit")
	equals(p:Place(10, 10), 10, 0, "Placement still on top row")
end)

new("Left, wide text, then Right", function(p)
	equals(p:PlaceLeft(50, 10), 0, 0)
	equals(p:Place(60, 10), 0, 10, "Wrap to 2nd line")
	equals(p:PlaceRight(40, 1), 60, 10, "PlaceRight doesn't go before current line")
end)

new("Left & Right text slalom", function(p)
	equals(p:PlaceLeft(60, 10), 0, 0)
	equals(p:PlaceRight(60, 10), 40, 10)
	equals(p:PlaceLeft(60, 10), 0, 20)
	equals(p:Place(10, 10), 60, 0, "Text has room at top")
	equals(p:Place(10, 11), 60, 20, "Tall text must go below right object")
end)

new("Check for spikes", function(p)
	p:PlaceLeft(10, 10)
	p:PlaceLeft(60, 10)
	p:PlaceLeft(10, 10)
	equals(p:PlaceRight(50, 30), 50, 20, "PlaceRight must notice the middle Left object")
end)

new("PlaceRight when tall text ended with wide left image", function(p)
	p:PlaceLeft(20, 10)
	equals(p:Place(20, 20), 20, 0)
	equals(p:PlaceRight(40, 10), 60, 0)
	equals(p:PlaceLeft(60, 10), 0, 20, "PlaceLeft must go beneath tall text")
	equals(p:PlaceLeft(20, 10), 0, 30)
	equals(p:PlaceRight(60, 1), 40, 10, "PlaceRight still fits on current line")
	equals(p:PlaceRight(60, 20), 40, 30, "PlaceRight must notice wide left-object after text")
end)

new("PlaceCenter", function(p)
	equals(p:PlaceCenter(w / 2, 10), w / 4, 0)
	equals(p:Place(10, 10), 0, 10, "Placement should be after center")
end)

new("PlaceFullWidth", function(p)
	equals(p:PlaceFullWidth(10), 0, 0)
	equals(p:Place(10, 10), 0, 10, "Placement should be after full width")
end)

new("PlaceLeftNoWrap", function(p)
	p:PlaceLeft(60, 20)
	p:PlaceRight(60, 20)
	p:PlaceLeft(60, 20)
	p:PlaceRight(60, 20)
	equals(p:Place(10, 10), 60, 0)
	equals(p:PlaceLeftNoWrap(20, 20), 0, 80)
	equals(p:Place(10, 10), 0, 100, "Text should go after NoWrap")
end)

new("WidthRemaining checks for left image below", function(p)
	p:PlaceLeft(10, 10)
	p:PlaceLeft(100, 5)
	equals(p:Place(10, 10), 10, 0)
	t.equals(p:GetWidthRemaining(10), 80)
	t.equals(p:GetWidthRemaining(15), 0)
end)
new("WidthRemaining checks for right image below", function(p)
	p:PlaceRight(10, 10)
	p:PlaceRight(100, 5)
	equals(p:Place(10, 10), 0, 0)
	t.equals(p:GetWidthRemaining(10), 80)
	t.equals(p:GetWidthRemaining(15), 0)
end)
new("WidthRemaining checks for page height", function(p)
	p:PlaceRight(100, 140)
	t.equals(p:GetWidthRemaining(10), 100)
	t.equals(p:GetWidthRemaining(15), 0)
end)
new("HeightRemaining checks for page width", function(p)
	t.equals(p:GetHeightRemaining(101), 0)
end)
new("HeightRemaining checks for image to right side", function(p)
	p:PlaceRight(50, 50)
	t.equals(p:GetHeightRemaining(51), 0)
end)

new("Place jumps to location where height fits", function(p)
	p:PlaceLeftNoWrap(20, 10)
	equals(p:PlaceRight(10, 10), 90, 10)
	equals(p:Place(10, 10), 0, 10)
	equals(p:PlaceLeft(40, 20), 0, 20)
	equals(p:PlaceRight(1, 5), 99, 20)
	equals(p:PlaceRight(40, 10), 60, 25)
	t.equals(p:GetHeightRemaining(10), 10)
	equals(p:Place(10, 15), 40, 10)
	t.equals(p:GetHeightRemaining(15), 15)
end)

new("Left then center aligned images doesn't fail", function(p)
	p:PlaceLeft(20, 20)
	p:PlaceCenter(20, 20)
end)

newPadded("WrapBothEqualSizePadded", 2, function(p)
	equals(p:PlaceLeft(30, 30), 0, 0)
	equals(p:PlaceRight(30, 30), w - 30, 0, "Can place left & right image on same line & padding doesn't affect position")
	equals(p:Place(w - 64, 15), 32, 0, "Can put text in between left & right images; text is moved over") -- todo if this fails maybe because coords are returning topleft?
	equals(p:Place(w - 64, 15), 32, 15)
	equals(p:Place(10, 10), 0, 30, "After both")
	equals(p:Place(w - 12, 10), 12, 30, "Full width available")
end)

newPadded("PaddedText", 2, function(p)
	t.equals(p:GetWidthRemaining(), w, "GetWidthRemaining is correct")
	t.equals(p:GetHeightRemaining(), h, "GetHeightRemaining is correct")
	equals(p:Place(10, 10), 0, 0)
	equals(p:Place(10, 10), 12, 0)
	equals(p:Place(10, 10), 24, 0)
	equals(p:Place(w - 3, 10), 0, 10)
	t.equals(p:GetWidthRemaining(), 1)
	equals(p:Place(1, 10), 99, 10)
	equals(p:Place(w - 1, 10), 0, 20)
	t.equals(p:GetWidthRemaining(), w, "Place moved to full new line due to padding")
end)


end