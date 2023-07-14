local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage.Utilities
local Class = require(Utilities.Class)
local ObjectPool = require(Utilities.ObjectPool)

local Writer = script.Parent
local PreRender = require(Writer.PreRender)
local ReaderConfig = require(Writer.ReaderConfig)

local TextService = game:GetService("TextService")

local function u2ToV2(u2) return Vector2.new(u2.X.Scale, u2.Y.Scale) end
local function v2ToU2(v2) return UDim2.fromScale(v2.X, v2.Y) end

local objToPool = {}
local function releaseObj(obj)
	local pool = objToPool[obj]
	if pool then
		pool:Release(obj)
	end
end
local function newPool(className, max, init)
	local pool; pool = ObjectPool.new({
		create = function()
			local obj = Instance.new(className)
			objToPool[obj] = pool
			init(obj)
			return obj
		end,
		max = max,
		release = function(obj) obj.Parent = nil end,
		destroy = function(obj)
			objToPool[obj] = nil
			obj:Destroy()
		end,
	})
	pool.name = className .. "*" .. max
	return pool
end
local innerPageSize = PreRender.InnerPageSize
local innerPagePool; innerPagePool = ObjectPool.new({
	create = function()
		local obj = Instance.new("Frame")
		objToPool[obj] = innerPagePool
		obj.Position = UDim2.new(PreRender.OuterMargin.Left, 0, PreRender.OuterMargin.Top, 0)
		obj.Size = innerPageSize
		obj.BackgroundTransparency = 1
		return obj
	end,
	max = 2,
	release = function(obj) obj.Parent = nil end,
	destroy = function(obj)
		objToPool[obj] = nil
		for _, c in obj:GetChildren() do -- children may still be being reused
			c.Parent = nil
		end
		obj:Destroy()
	end,
})
local pageNumPool = newPool("TextLabel", 4, function(label)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextScaled = true
	label.AnchorPoint = Vector2.new(0, 1)
	label.AutoLocalize = false
	Instance.new("UITextSizeConstraint", label)
end)

local Render = Class.New("Render")
function Render.new(pageFrame, config, preRenderPageSize, imageHandler)
	--	preRenderPageSize of 'true' means "use default"
	local preRenderWidth, preRenderHeight
	local innerSize = PreRender.GetInnerPageSize(pageFrame.AbsoluteSize)
	if preRenderPageSize then
		if preRenderPageSize == true then
			preRenderPageSize = PreRender.DefaultPageSize
		end
		local preRenderInnerSize = PreRender.GetInnerPageSize(preRenderPageSize)
		preRenderWidth, preRenderHeight = preRenderInnerSize.X, preRenderInnerSize.Y
	else
		preRenderWidth, preRenderHeight = innerSize.X, innerSize.Y
	end
	local self = setmetatable({
		outerPage = pageFrame,
		-- innerPage initialized at the beginning of RenderPage
		config = config or ReaderConfig.Default,
		-- Note about convert functions: very often limited precision will cause things to be, for instance, 49.99 pixels rather than 50 (or even 49.5), which is why we have the "* 1.001" (to try to help compensate) so we add a full 1 pixel to counteract that
		convertPos = function(v2) return UDim2.fromScale(v2.X / preRenderWidth * 1.001, v2.Y / preRenderHeight * 1.002) end,
		convertSize = function(v2) return UDim2.fromScale(v2.X / preRenderWidth * 1.001, v2.Y / preRenderHeight * 1.002) end,
		convertThickness = function(t) return t * innerSize.Y / preRenderHeight end,
		--convertSize = function(v2) return UDim2.new(v2.X / preRenderWidth * 1.001, 1, v2.Y / preRenderHeight * 1.002, 1) end, -- very often limited precision will cause things to be, for instance, 49.99 pixels rather than 50 (or even 49.5), which is why we make the so we add a full 1 pixel to counteract that
		imageHandler = imageHandler,
		imageHandlerCleanups = {},
	}, Render)
	self.baseConvertPos = self.convertPos
	self.baseConvertSize = self.convertSize
	return self
end
function Render:setConvertDivisor(div)
	if div and div ~= Vector2.new(1, 1) then
		self.convertPos = function(v2)
			return self.baseConvertPos(v2 / div)
		end
		self.convertSize = function(v2)
			return self.baseConvertSize(v2 / div)
		end
	else
		self.convertPos = self.baseConvertPos
		self.convertSize = self.baseConvertSize
	end
end
function Render:ClearPage() -- call to clear the page and reuse the elements. After this, the page can be reused. Only elements created by Render will be removed.
	for _, obj in ipairs(self.outerPage:GetDescendants()) do
		releaseObj(obj)
	end
	for _, fn in ipairs(self.imageHandlerCleanups) do
		fn()
	end
	table.clear(self.imageHandlerCleanups)
end
function Render:TransferTo(otherPage) -- Transfers this Render to another page.
	for _, obj in ipairs(self.outerPage:GetChildren()) do
		if objToPool[obj] then
			obj.Parent = otherPage
		end
	end
	self.outerPage = otherPage
end
function Render:RenderPageNumber(page)
	local text = page:GetFormattedPageNumberForRender()
	if text == "" then return end
	local label = pageNumPool:Get()
	self.config:ApplyDefaultsToLabel(label)
	local xScale = PreRender.OuterMargin.Left / self.outerPage.AbsoluteSize.X
	label.Position = UDim2.new(xScale, 0, 1, 0)
	label.Size = UDim2.new(1 - 2 * xScale, 0, PreRender.OuterMargin.Bottom + 0.002, 0)
	label.Text = text
	label.UITextSizeConstraint.MaxTextSize = self.config:GetSize("Normal")
	--label.TextXAlignment = if page:IsLeftSidePage() then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
	label.Parent = self.outerPage
end
function Render:setupInnerPage()
	local innerPage = innerPagePool:Get()
	innerPage.Parent = self.outerPage
	self.innerPage = innerPage
end
function Render:setPosSizeParent(obj, element)
	obj.Position = self.convertPos(element.Position)
	obj.Size = self.convertSize(element.Size)
	obj.Parent = self.innerPage
end
function Render:addToPage(pool, element, fn)
	local obj = pool:Get()
	if fn then
		fn(obj)
	end
	self:setPosSizeParent(obj, element)
	return obj
end
local labelToCon = {}
local standardTextPool; standardTextPool = ObjectPool.new({
	create = function()
		local label = Instance.new("TextLabel")
		objToPool[label] = standardTextPool
		label.BackgroundTransparency = 1
		label.AutoLocalize = false
		return label
	end,
	max = 40,
	release = function(label)
		local con = labelToCon[label]
		if con then
			con:Disconnect()
			labelToCon[label] = nil
		end
		label.Parent = nil
	end,
	destroy = function(label)
		objToPool[label] = nil
		local con = labelToCon[label]
		if con then
			con:Disconnect()
			labelToCon[label] = nil
		end
		label:Destroy()
	end,
})
function Render:commonAddLabel(element, setup1, setup2)
	--	setup1 : function(label) is called before the label is parented/sized/etc
	--	setup2 : function(label) is called after the label is sized & parented. The function may return a connection from the label which will be cleaned up as appropriate.
	local label = standardTextPool:Get()
	self.config:ApplyNonSizeDefaultsToLabel(label)
	label.TextSize = element.TextSize
	setup1(label)
	self:setPosSizeParent(label, element)
	local con = setup2(label)
	if con then
		labelToCon[label] = con
	end
	return label
end
function Render:addLabel(element, setup)
	self:commonAddLabel(element, setup, function(label)
		-- TextScaled is blurry (Sep 2022), so we want to replace that with the appropriate TextSize where possible. In general, we can replace it for any label that doesn't use font size tags.
		local mustUseTextScaled = label.Text:match("<font[^>]-size=.[^0]") -- ignores the <font size="0"> tags (here due to a Roblox bug)
		if mustUseTextScaled then
			label.TextScaled = true
		end
		if not mustUseTextScaled then
			local function updateTextSize()
				label.TextScaled = true -- must set to 'true' so we can read the correct TextBounds
				local curSize = label.TextSize
				label.TextSize = 1 -- (Mar 2023) Need to do this before measuring TextBounds or else, if the screen shrinks, TextScaled won't scale down for some reason
				local correctBounds = label.TextBounds
				for i = 1, 3 do -- (Mar 2023) sometimes having a TextSize of 1 won't scale up all the way
					if label.TextSize == correctBounds.Y then break end
					label.TextSize = correctBounds.Y
					correctBounds = label.TextBounds
				end
				label.TextScaled = false
				label.TextSize = curSize
				local curBounds = label.TextBounds
				local min, max
				local usedEstimate = false
				local function getEstimate(min, max)
					if usedEstimate then
						if not max then
							return math.floor(curSize * 2)
						elseif not min then
							return math.floor(curSize / 2)
						else
							return math.floor((min + max) / 2)
						end
					else
						usedEstimate = true
						-- Note: element.Size.Y is not guaranteed to be the desired TextSize if there is larger text on the same line separated by some other element (though that has no impact here).
						if label.AbsoluteSize.Y == element.Size.Y then
							return math.floor(label.AbsoluteSize.X / element.Size.X * element.TextSize)
						else
							return math.floor(label.AbsoluteSize.Y / element.Size.Y * element.TextSize)
						end
					end
				end
				while curBounds ~= correctBounds do
					if curBounds.Y < correctBounds.Y or curBounds.Y == correctBounds.Y and curBounds.X < correctBounds.X then -- too small
						min = curSize + 1
					else -- curBounds.Y > correctBounds.Y or curBounds.Y == correctBounds.Y and curBounds.X > correctBounds.X then -- too large
						max = curSize - 1
						if max <= 1 then -- occurs if label is incredibly tiny (which is probably a bug)
							label.TextSize = max
							break
						end
					end
					if min and max and min >= max then
						label.TextSize = max
						break
					end
					curSize = getEstimate(min, max)
					label.TextSize = curSize
					curBounds = label.TextBounds
				end
			end
			updateTextSize()
			return label:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateTextSize)
		end
	end)
end

local barPool = newPool("Frame", 2, function(bar)
	bar.BackgroundColor3 = Color3.new(0, 0, 0)
	bar.BorderSizePixel = 0
end)
local imagePool = newPool("ImageLabel", 4, function(image)
	image.BackgroundTransparency = 1
end)
local framePool = newPool("Frame", 6, function(frame)
	frame.BackgroundTransparency = 0.9
	Instance.new("UIPadding", frame)
	Instance.new("UIStroke", frame)
end)

local paddingKeys = {
	PaddingLeft = "X",
	PaddingRight = "X",
	PaddingTop = "Y",
	PaddingBottom = "Y",
}
local typeToHandle = {
	-- type = function(self, element)
	Bar = function(self, element)
		if element.Line == true then
			local bar = barPool:Get()
			local pos = self.convertPos(element.Position)
			local size = self.convertSize(element.Size)
			bar.Position = UDim2.new(pos.X, UDim.new(pos.Y.Scale + size.Y.Scale * 0.45, 0))
			bar.Size = UDim2.new(size.X, UDim.new(size.Y.Scale * 0.1, 0))
			bar.BackgroundColor3 = self.config.DefaultColor
			bar.Parent = self.innerPage
		elseif element.Line == "" then
			error('Bar cannot have a line of ""')
		else
			self:commonAddLabel(element, function(label)
				label.RichText = false
				label.TextXAlignment = Enum.TextXAlignment.Center
				label.Font = element.Font
			end, function(label)
				local function update()
					label.TextSize = label.AbsoluteSize.Y
					local width = TextService:GetTextSize(element.Line, label.TextSize, element.Font, Vector2.new(1e6, 1e6)).X
					label.Text = string.rep(element.Line, math.max(1, math.floor(label.AbsoluteSize.X / width)))
				end
				update()
				return label:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
			end)
		end
	end,
	Block = function(self, element)
		local frame = self:addToPage(framePool, element, function(frame)
			frame.BackgroundColor3 = self.config.DefaultColor
			frame.UIStroke.Thickness = if element.BorderThickness == 0 then 0
				else math.max(self.convertThickness(element.BorderThickness), 1)
			frame.UIStroke.Color = self.config.DefaultColor
		end)
		local prevInnerPage = self.innerPage
		self.innerPage = frame
		self:setConvertDivisor(Vector2.new(frame.Size.X.Scale, frame.Size.Y.Scale))
		-- problem: currently setting
		local padding = self.convertSize(Vector2.new(element.Padding, element.Padding))
		for key, paddingKey in paddingKeys do
			frame.UIPadding[key] = padding[paddingKey]
		end
		self:renderElements(element.Elements)
		self:setConvertDivisor()
		self.innerPage = prevInnerPage
	end,
	Chapter = function(self, element)
		self:addLabel(element, function(label)
			label.Text = element.Name
			label.RichText = false
			label.Font = element.Font
			label.TextXAlignment = Enum.TextXAlignment.Center
		end)
	end,
	Header = function(self, element)
		self:addLabel(element, function(label)
			label.Text = element.Name
			label.RichText = false
			label.Font = element.Font
			label.TextXAlignment = element.Alignment
		end)
	end,
	Image = function(self, element)
		local obj = imagePool:Get()
		local pos = self.convertPos(element.Position)
		local size = self.convertSize(element.Size)
		if element.AspectRatio then
			local imageSize = self.convertSize(element.ImageSize)
			if imageSize ~= size then -- update position
				pos = v2ToU2(u2ToV2(pos) + u2ToV2(size) / 2 - u2ToV2(imageSize) / 2)
				size = imageSize
			end
		end
		obj.Position = pos
		obj.Size = size
		obj.Image = "rbxassetid://" .. element.ImageId
		if self.imageHandler then
			table.insert(self.imageHandlerCleanups, self.imageHandler:Handle(obj))
		end
		obj.Parent = self.innerPage
	end,
	TextBlock = function(self, element)
		self:addLabel(element, function(label)
			label.RichText = true
			label.Text = element.RichText
			label.TextXAlignment = element.Alignment
		end)
	end,
	Alignment = function() end,
}
function Render:renderElements(elements)
	for _, element in ipairs(elements) do
		(typeToHandle[element.Type] or error("Unknown element type '" .. element.Type .. "'", 2))(self, element)
	end
end
function Render:RenderPage(page)
	self:setupInnerPage()
	self:renderElements(page.Elements)
	self:RenderPageNumber(page)
end

function Render.Page(page, pageFrame, config, preRenderPageSize)
	--	Returns the render instance (call :ClearPage to clean up the render for element reuse)
	local render = Render.new(pageFrame, config, preRenderPageSize)
	render:RenderPage(page)
	return render
end

return Render