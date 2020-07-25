local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage.Utilities
local Assert = require(Utilities.Assert)
local ObjectList = require(Utilities.ObjectList)
local ButtonList = setmetatable({}, ObjectList)
ButtonList.__index = ButtonList
function ButtonList.new(initButton, ...)
	--	initButton:function(i):button
	local isEnabled = {}
	local event = Instance.new("BindableEvent")
	local function init(i)
		local button = initButton(i)
		return button, button.Activated:Connect(function()
			event:Fire(i, button, isEnabled[i])
		end)
	end
	local self = setmetatable(ObjectList.new(init, ...), ButtonList)
	self.isEnabled = isEnabled
	self.Activated = event.Event --(i, button, enabled)
	return self
end
local base = ButtonList.destroy
function ButtonList:destroy(i)
	base(self, i)
	self.isEnabled[i] = nil
end
function ButtonList:SetEnabled(i, value)
	Assert.Integer(i, 1)
	value = not not value
	self:get(i).AutoButtonColor = value
	self.isEnabled[i] = value
end
function ButtonList:AdaptToList(newList, adaptButtonReturnEnabled)
	for i, item in ipairs(newList) do
		self:SetEnabled(i, adaptButtonReturnEnabled(self:get(i), item))
	end
	self:destroyRest(#newList + 1)
end
return ButtonList