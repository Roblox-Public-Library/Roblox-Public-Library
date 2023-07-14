local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Class = require(ReplicatedStorage.Utilities.Class)
local Event = require(ReplicatedStorage.Utilities.Event)

local ContentProvider = game:GetService("ContentProvider")

local ImageHandler = Class.New("ImageHandler")
ImageHandler.DefaultStyle = {
	BackgroundTransparency_Loading = 0.8,
	BackgroundTransparency_Result = 1,
}
function ImageHandler.new(style)
	return setmetatable({
		style = if style then setmetatable(style, {__index = ImageHandler.DefaultStyle}) else ImageHandler.DefaultStyle,
		imageToSuccess = {}, -- [image] = success (so can be true/false or nil if no results yet)
		imageToEvent = {}, -- [image] = Event
	}, ImageHandler)
end
function ImageHandler:Preload(image)
	local imageToSuccess = self.imageToSuccess
	local result = imageToSuccess[image]
	if result ~= nil then return end
	local imageToEvent = self.imageToEvent
	if imageToEvent[image] then return end -- it's already being preloaded
	local event = Event.new()
	imageToEvent[image] = event
	task.spawn(function()
		ContentProvider:PreloadAsync({image}, function(_, status)
			imageToEvent[image] = nil
			local success = status == Enum.AssetFetchStatus.Success
			imageToSuccess[image] = success
			event:Fire(success)
			event:Destroy()
		end)
	end)
end
function ImageHandler:onResult(image, fn)
	--	May return an event connection that can be disconnected to cancel 'fn'
	local result = self.imageToSuccess[image]
	if result == nil then
		local event = self.imageToEvent[image]
		if event then
			return event:Connect(fn)
		else
			self:Preload(image)
			return self:onResult(image, fn)
		end
	else
		task.spawn(fn, result)
		return nil
	end
end
function ImageHandler:Clear() -- clears memory entirely
	for _, e in self.imageToEvent do
		e:Destroy()
	end
	table.clear(self.imageToEvent)
	table.clear(self.imageToSuccess)
end
ImageHandler.Destroy = ImageHandler.Clear

local errMsg = Instance.new("TextLabel") do
	errMsg.Text = "Image failed to load"
	errMsg.Size = UDim2.new(1, 0, 1, 0)
	errMsg.TextScaled = true
	errMsg.BackgroundTransparency = 1
	errMsg.TextColor3 = Color3.fromRGB(106, 0, 0)
	errMsg.ZIndex = 5
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 20
	constraint.Parent = errMsg
end
function ImageHandler:Handle(imageObj, image)
	--	imageObj is an ImageLabel or ImageButton
	--	Returns an 'cancel/destroy' function that cancels handling the imageObj and clears modifications (except for background transparency)
	image = image or imageObj.Image
	--imageObj.Image = ""
	local destroyed = false
	imageObj.BackgroundTransparency = self.style.BackgroundTransparency_Loading
	local clone
	local con = self:onResult(image, function(success)
		if success then
			imageObj.BackgroundTransparency = self.style.BackgroundTransparency_Result
			imageObj.Image = image
		else
			clone = errMsg:Clone()
			clone.Parent = imageObj
		end
	end)
	local function cleanup()
		if con then con:Disconnect() end
		if clone then clone:Destroy() end
		imageObj.Image = image
	end
	return cleanup
end
function ImageHandler:PreloadElements(elements)
	for _, element in ipairs(elements) do
		if element.Type == "Image" then
			self:Preload("rbxassetid://" .. element.ImageId)
		end
	end
end
function ImageHandler.FromElements(elements)
	local self = ImageHandler.new()
	self:PreloadElements(elements)
	return self
end

return ImageHandler