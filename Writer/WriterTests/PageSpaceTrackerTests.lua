return function(tests, t)

local Writer = game:GetService("ReplicatedStorage").Writer
local PageSpaceTracker = require(Writer.PageSpaceTracker)

local w, h = 100, 150
local function new(name, test)
	tests[name] = function()
		test(PageSpaceTracker.new(w, h))
	end
end
local function equals(actual, eX, eY, ...)
	t.truthy(actual, "Return value of Placement function must not be nil", ...)
	t.equals(("%.2f, %.2f"):format(actual.X.Offset, actual.Y.Offset),
			("%.2f, %.2f"):format(eX, eY), ...)
	-- t.multi((desc and desc .. "." or "") .. "UDim2", function(m)
	-- 	m.equals("X", actual.X.Offset, eX)
	-- 	m.equals("Y", actual.Y.Offset, eY)
	-- end)
end

new("WrapLeft", function(p)
	equals(p:PlaceLeft(30, 30), 0, 0)
	t.equals(p:GetWidthRemaining(), w - 30)
	t.equals(p:GetHeightRemaining(), h, "full height available during wrap left")
	--t.equals(p:GetBlockHeightRemaining(), 30)

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

new("RunOutOfSpaceWithImages", function(p)

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
	equals(p:Place(10, 20), 60, 30)
end)
new("PlaceLeft2ndWiderTallText", function(p)
	equals(p:PlaceLeft(30, 30), 0, 0)
	equals(p:PlaceLeft(60, 30), 0, 30)
	equals(p:Place(10, 40), 60, 0)
end)

new("PlaceCenter", function(p)
	equals(p:PlaceCenter(h / 2, 10), h / 4, 0)
	equals(p:Place(10, 10), 0, 10, "Placement should be after center")
end)
new("PlaceFullWidth", function(p)
	equals(p:PlaceFullWidth(10), 0, 0)
	equals(p:Place(10, 10), 0, 10, "Placement should be after full width")
end)


end