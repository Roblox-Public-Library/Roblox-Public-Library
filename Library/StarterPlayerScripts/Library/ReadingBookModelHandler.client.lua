local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BookGui = require(ReplicatedStorage.Gui.BookGui)
local Books = require(ReplicatedStorage.Library.BooksClient)
local BookChildren = require(ReplicatedStorage.Library.BookChildren)
local BooksContentCache = require(ReplicatedStorage.Library.BooksContentCache)
local	imageHandler = BooksContentCache.ImageHandler
local profile = require(ReplicatedStorage.Library.ProfileClient)
local	bvs = profile.BookViewingSettings
local Event = require(ReplicatedStorage.Utilities.Event)
local Value = require(ReplicatedStorage.Utilities.Value)

local Players = game:GetService("Players")
local	localPlayer = Players.LocalPlayer

local DISABLE_DUAL_RENDER = false -- if true, will not render the book on the 3D model when the local player is using a 2D gui

local anim = game.ReplicatedStorage:FindFirstChild("Animations")
if anim then anim = anim:FindFirstChild("HoldBook") end
if anim and anim:IsA("AnimationClip") then
	local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
	local function createPreviewAnimation(keyframeSequence)
		local hashId = KeyframeSequenceProvider:RegisterKeyframeSequence(keyframeSequence)
		if hashId then
			local Animation = Instance.new("Animation")
			Animation.AnimationId = hashId
			return Animation
		end
	end
	anim = createPreviewAnimation(anim) or warn("Animation preview failed")
end
local holdingBook = Value.new(false)
if anim then
	local con
	local function onCharAdded(char)
		local animator = localPlayer.Character:WaitForChild("Humanoid"):WaitForChild("Animator")
		local track = animator:LoadAnimation(anim)
		if holdingBook.Value then
			track:Play()
		end
		if con then con:Disconnect() end
		con = holdingBook.Changed:Connect(function(value)
			if value then
				track:Play()
			else
				track:Stop()
			end
		end)
	end
	localPlayer.CharacterAdded:Connect(onCharAdded)
	if localPlayer.Character then onCharAdded(localPlayer.Character) end
end


local template = ReplicatedStorage.ReadingBook
local templateDefaultColor = template.Middle.Color
local templateDefaultTitleColor, templateDefaultTitleOutlineColor = Color3.new(), Color3.new(1, 1, 1)
local CollectionService = game:GetService("CollectionService")
local cd = Instance.new("ClickDetector")
CollectionService:AddTag(cd, "SelectableBookCD")
cd.Parent = template
local bookRef = Instance.new("ObjectValue")
bookRef.Name = "BookRef"
bookRef.Parent = cd

local remotes = ReplicatedStorage.Remotes
local SFX = ReplicatedStorage.SFX
local readingBookRemote = remotes.PlayerReadingBook

local playerToBookId, playerToPageNum = readingBookRemote.OnClientEvent:Wait()
-- note: book id can be false for "private"
if not playerToPageNum then
	warn("ReadingBookModel Remotes ran out of queue space")
	playerToBookId, playerToPageNum = {}, {}
end
local playerToModel = {}

local rotation = CFrame.Angles(math.rad(-35), 0, 0)
local dist = 1.9
local distDif = 0.38 - 0.3 * dist
local translation = CFrame.new(0, 2.4 + distDif, -dist) * CFrame.Angles(math.pi / 2 + math.rad((1.4 - dist) * 20), 0, math.pi / 2)

local Model = {}
Model.__index = Model
function Model.new()
	local obj = template:Clone()
	local pageObj = obj.Page
	pageObj.Parent = nil
	local leftPage = obj.Left.Page.Frame.LeftPage
	local rightPage = obj.Right.Page.Frame.RightPage
	local animLeftPage = pageObj.LeftPage.Frame.LeftPage
	local animRightPage = pageObj.RightPage.Frame.RightPage
	return setmetatable({
		frontGui = obj.Front.SurfaceGui,
		mainFrame = obj.Front.SurfaceGui.MainFrame,
		instance = obj,
		playerWeld = obj.PlayerWeld,
		cd = obj.ClickDetector,
		bookRef = obj.ClickDetector.BookRef,
		leftPage = leftPage,
		rightPage = rightPage,
		leftPrivate = leftPage.Private,
		rightPrivate = rightPage.Private,
		front = obj.Front,
		titles = {
			obj.Middle.BookNameSide.BookName,
			obj.Left.BookNameFront.BookName,
		},
		pageObj = pageObj,
		animLeftPage = animLeftPage,
		animRightPage = animRightPage,
	}, Model)
end
function Model:TakeFromBookGui()
	if self.takenFromBookGui then return end
	self.takenFromBookGui = true
	BookGui.TransferToModel(self.instance, self.frontGui, self.mainFrame)
end
function Model:GiveBackToBookGui()
	if not self.takenFromBookGui then return end
	self.takenFromBookGui = false
	BookGui.TransferFromModel()
end
function Model:UpdatePageColor()
	local color = BookGui.GetPageColorFromLightMode(bvs.LightMode:Get())
	if self.leftPage.BackgroundColor3 == color then return end
	self.leftPage.BackgroundColor3 = color
	self.rightPage.BackgroundColor3 = color
	self.animLeftPage.BackgroundColor3 = color
	self.animRightPage.BackgroundColor3 = color
	self.rerenderRequired = true
end
function Model:UpdatePos(player, root)
	local model = self.instance
	local playerWeld = self.playerWeld
	playerWeld.Parent = model -- sometimes gets deparented
	playerWeld.Enabled = false
	model:PivotTo(root.CFrame * rotation * translation)
	playerWeld.Part1 = player.Character.HumanoidRootPart
	playerWeld.Enabled = true
end
function Model:ClearRender()
	-- todo if anim underway, delete
	if self.animating then
		if self.animationQueued then -- must be cleared before calling 'animating'
			self.animationQueued:Destroy()
			self.animationQueued = nil
		end
		self.animating() -- cleans animation up
	end
	if self.leftRender then
		self.leftRender:ClearPage()
		self.leftRender = nil
	end
	if self.rightRender then
		self.rightRender:ClearPage()
		self.rightRender = nil
	end
end
function Model:updateTitle(title)
	for _, t in self.titles do
		t.Text = title
	end
end
function Model:IsActive() return self.instance.Parent end
function Model:applyColors(color)
	self.instance.Left.Color = color
	self.instance.Middle.Color = color
	self.instance.Right.Color = color
end
function Model:applyTitleColors(color, outlineColor)
	for _, obj in ipairs({self.instance.Left.BookNameFront.BookName, self.instance.Middle.BookNameSide.BookName}) do
		obj.TextColor3 = color
		obj.TextStrokeColor3 = outlineColor
	end
end
function Model:simpleRenderAsync(player, id, curPage)
	self.rerenderRequired = false
	self:ClearRender()

	local private = id == false
	self.leftPrivate.Visible = private
	self.rightPrivate.Visible = private
	if private then
		self:updateTitle("~~~~~")
		self.leftPage.Header.Text = ""
		self.rightPage.Header.Text = ""
		self:applyColors(templateDefaultColor)
		self:applyTitleColors(templateDefaultTitleColor, templateDefaultTitleOutlineColor)
		self.instance.Left.Cover.Texture = ""
		self.cd.Parent = nil
	else
		local content, data = BooksContentCache:GetContentDataAsync(id)
		local summary = Books:FromId(id)
		local origModel = summary.Models[1]
		self:applyColors(origModel.Color)
		local scr = BookChildren.GetBookScript(origModel)
		self:applyTitleColors(BookChildren.GetAttribute(scr, "TitleColor"), BookChildren.GetAttribute(scr, "TitleOutlineColor"))
		local cover = origModel:FindFirstChild("Cover")
		self.instance.Left.Cover.Texture = if cover then cover.Texture else ""
		self:updateTitle(summary.Title)
		self.leftRender, self.rightRender = BookGui.RenderPages(nil, nil, self.leftPage, self.rightPage, summary, content, curPage)
		if player ~= localPlayer then
			self.cd.Parent = self.instance
		end
	end
	self.id = id
	self.curPage = curPage
end
function Model:RenderAsync(player)
	local id = playerToBookId[player]
	local curPage = playerToPageNum[player] or 1
	if DISABLE_DUAL_RENDER and id and localPlayer == player and not bvs.ThreeD:Get() then
		id = false
	end
	if id ~= self.id then
		self:simpleRenderAsync(player, id, curPage)
	elseif id then -- animate page turn
		if self.animationQueued then return end
		task.spawn(function()
			-- if animation underway, queue
			if self.animating then
				self.animationQueued = Event.new()
				self.animationQueued:Wait()
				self.animationQueued:Destroy()
				self.animationQueued = nil
				curPage = playerToPageNum[player] or 1 -- in case it changed while we were waiting
			end
			if curPage == self.curPage then -- nothing to animate
				if self.rerenderRequired then
					self:simpleRenderAsync(player, id, curPage)
				end
				return
			end
			local cancel = false
			self.animating = function() cancel = true end -- we replace it with full cleanup function below but since fetching the content *can* be async we track whether we should cancel the animation or not
			local content, data = BooksContentCache:GetContentDataAsync(id)
			local summary = Books:FromId(id)
			if cancel then return end
			self.pageObj.Parent = self.instance -- must do this before rendering to ensure correct page size for rendering
			local fn = self[if curPage > self.curPage then "turnRightToLeft" else "turnLeftToRight"]
			local onDone = fn(self, summary, content, curPage)
			self.animating = function() -- cleanup function
				self:resetAnimCon()
				self.animating = nil
				self.pageObj.Parent = nil
				self.curPage = curPage
				onDone()
				if self.animationQueued then self.animationQueued:Fire() end
			end
		end)
	end -- else the book is (and was) private; nothing to do
end
function Model:SetupParent(player, id)
	if self.charAddedCon then
		self.charAddedCon:Disconnect()
	end
	self.cd.Parent = nil -- easier for SelectScript since this triggers cleanup
	self.bookRef.Value = if id then Books:FromId(id).Models[1] else nil
	if id and player ~= localPlayer then
		self.cd.Parent = self.instance
	end
	self.instance.Parent = workspace -- cannot be inside the player or else the gui won't work
	self.front.Parent = if player == localPlayer then self.instance else nil
	self.charAddedCon = player.CharacterAdded:Connect(function(char)
		self:UpdatePos(player, char:WaitForChild("HumanoidRootPart"))
	end)
end
function Model:Release()
	--self:ClearRender()
	if self.takenFromBookGui then
		self:GiveBackToBookGui()
	end
	self.instance.Parent = nil
	if self.charAddedCon then
		self.charAddedCon:Disconnect()
		self.charAddedCon = nil
	end
end
function Model:Destroy()
	self:Release()
	self.instance:Destroy()
end
-- Page Animation
local TweenService = game:GetService("TweenService")
local tweenInfo = TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)


local widthOver2 = template.Page.Size.X / 2
local relCFAdd = CFrame.new(widthOver2, 0, 0) -- the 0.01 corrects CFrame multiplication error from leftpagrec
local relCFSub = CFrame.new(-widthOver2, 0, 0)

local middleInverse = template.Middle.CFrame:Inverse()
local leftPageRelCF = middleInverse * template.Left.CFrame * CFrame.new(0.01, 0, 0) * relCFAdd -- the 0.01 CFrame puts the page in the correct spot (though I don't know why it's necessary)
--	The relCFAdd and (in the formula below, relCFSub) are responsible for moving the page's position to/from the center of the book so that the rotation works correctly
--local rightPageRelCF = middleInverse * template.Right.CFrame

local RenderStepped = game:GetService("RunService").RenderStepped
function Model:resetAnimCon()
	if self.animCon then
		self.animCon:Disconnect()
	end
end
local coverDepth_Div2 = template.Left.Size.Y / 2 + 0.005 -- 0.005 so that the animated page will be just slightly over top of the rest of the book
function Model:tween(reverse)
	local progress = 0
	local page = self.pageObj
	local model = self.instance
	self.animCon = RenderStepped:Connect(function(dt)
		progress += dt / tweenInfo.Time * (if self.animationQueued then 3 else 1)
		local n = TweenService:GetValue(progress, tweenInfo.EasingStyle, tweenInfo.EasingDirection)
		if reverse then n = 1 - n end
		local cf = model:GetPivot()
		page.CFrame = cf * leftPageRelCF * CFrame.Angles(0, 0, -math.rad(n * 170)) * relCFSub
			+ cf.RightVector * coverDepth_Div2 -- used to get the page in front of the book rather than inside it
		if progress >= 1 then
			self.animating()
		end
	end)
end
function Model:turnLeftToRight(summary, content, newPageIndex)
	self:resetAnimCon()
	self:tween(false)
	-- Transfer left to animLeft
	self.leftRender:TransferTo(self.animLeftPage)
	self.animLeftRender = self.leftRender
	self.animLeftPage.Header.Text = self.leftPage.Header.Text
	-- Fill in pages that are currently hidden but will be shown
	self.leftRender, self.animRightRender = BookGui.RenderPages(nil, nil, self.leftPage, self.animRightPage, summary, content, newPageIndex)
	return function()
		-- Hide the pages that are now hidden
		self.animLeftRender:ClearPage()
		self.animLeftRender = nil
		if self.rightRender then
			self.rightRender:ClearPage()
		end
		-- Transfer animRight to Right
		self.animRightRender:TransferTo(self.rightPage)
		self.rightRender = self.animRightRender
		self.rightPage.Header.Text = self.animRightPage.Header.Text
		self.animRightRender = nil
	end
end
function Model:turnRightToLeft(summary, content, newPageIndex)
	self:resetAnimCon()
	self:tween(true)
	-- Transfer right to animRight
	self.rightRender:TransferTo(self.animRightPage)
	self.animRightRender = self.rightRender
	self.animRightPage.Header.Text = self.rightPage.Header.Text
	-- Fill in pages that are currently hidden but will be shown
	self.animLeftRender, self.rightRender = BookGui.RenderPages(nil, nil, self.animLeftPage, self.rightPage, summary, content, newPageIndex)
	return function()
		-- Hide the pages that are now hidden
		self.animRightRender:ClearPage()
		self.animRightRender = nil
		self.leftRender:ClearPage()
		-- Transfer animLeft to left
		self.animLeftRender:TransferTo(self.leftPage)
		self.leftRender = self.animLeftRender
		self.leftPage.Header.Text = self.animLeftPage.Header.Text
		self.animLeftRender = nil
	end
end

-- End of Page Animation

local models = require(ReplicatedStorage.Utilities.ObjectPool).new({
	create = Model.new,
	release = Model.Release,
	destroy = Model.Destroy,
	max = 5,
})
local function updateModelAsync(player)
	local id = playerToBookId[player]
	local model = playerToModel[player]
	if id == nil then
		if model then
			models:Release(model)
			playerToModel[player] = nil
		end
	else
		if not model then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not root then return end
			model = models:Get()
			playerToModel[player] = model
			model:UpdatePageColor()
			model:SetupParent(player, id)
			if localPlayer == player and bvs.ThreeD:Get() then
				model:TakeFromBookGui()
			end
			model:UpdatePos(player, root)
		end
		model:RenderAsync(player)
	end
end

bvs.ThreeD.Changed:Connect(function(value)
	local model = playerToModel[localPlayer]
	if model then
		if value then
			model:TakeFromBookGui()
		else
			model:GiveBackToBookGui()
		end
		model:RenderAsync(localPlayer)
	end
end)

bvs.LightMode.Changed:Connect(function()
	task.defer(function()
		for player, model in playerToModel do
			model:UpdatePageColor()
			model:RenderAsync(player)
		end
	end)
end)

readingBookRemote.OnClientEvent:Connect(function(player, id, pageNum)
	if id == playerToBookId[player] and pageNum == playerToPageNum[player] then return end
	playerToBookId[player] = id
	playerToPageNum[player] = pageNum
	updateModelAsync(player)
end)
Players.PlayerRemoving:Connect(function(player)
	playerToPageNum[player] = nil
	playerToBookId[player] = nil
	updateModelAsync(player)
end)

remotes.PageTurnSound.OnClientEvent:Connect(function(player)
	local model = playerToModel[player]
	if not model then return end
	local clone = SFX.PageTurn:Clone()
	clone.PlayOnRemove = true
	clone.Parent = model.instance.Middle
	clone:Destroy()
end)

local curPage = 1
BookGui.BookOpened:Connect(function(id)
	readingBookRemote:FireServer(id, curPage)
	playerToBookId[localPlayer] = id
	updateModelAsync(localPlayer)
	holdingBook:Set(true)
end)
BookGui.BookClosed:Connect(function()
	readingBookRemote:FireServer(nil)
	playerToBookId[localPlayer] = nil
	updateModelAsync(localPlayer)
	holdingBook:Set(false)
end)
BookGui.CurPageChanged:Connect(function(page)
	if page == curPage then return end
	playerToPageNum[localPlayer] = page
	curPage = page
	local bookId = BookGui.BookOpen
	if bookId then
		readingBookRemote:FireServer(bookId, curPage)
		updateModelAsync(localPlayer)
	end
end)

for player in playerToBookId do
	updateModelAsync(player)
end