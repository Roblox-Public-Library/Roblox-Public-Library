local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Writer = require(ReplicatedStorage.Writer)
local	CustomMarkdown = Writer.CustomMarkdown
local	PreRender = Writer.PreRender
local	ImageHandler = Writer.ImageHandler
local	ReaderConfig = Writer.ReaderConfig
local		lightConfig, darkConfig = ReaderConfig.Default, ReaderConfig.DefaultDark

local bvs = require(script.Parent.ProfileClient).BookViewingSettings
local getContent = ReplicatedStorage:WaitForChild("GetBookContent")

local BooksContentCache = {}

local idToData = {}
local idToBookContent = {}
local idsStored = {} -- list of ids whose content we've stored (first one is the oldest)
local MAX_CONTENT_TO_STORE = 20 -- we'll retain this many latest books in case the user reopens them (also used by ReadingBookModelHandler)
local readerConfig
local function updateReaderConfig()
	readerConfig = if bvs.LightMode:Get() then lightConfig else darkConfig
	table.clear(idToBookContent)
end
updateReaderConfig()
bvs.LightMode.Changed:Connect(updateReaderConfig)
function BooksContentCache:GetReaderConfig()
	return readerConfig
end
local function updateBookAccessed(id)
	--	Record that this book was accessed so we don't clear it from memory any time soon (user may keep coming back to it)
	local index = table.find(idsStored, id)
	if index then
		table.remove(idsStored, index)
		table.insert(idsStored, id)
	end
end
local function storeContent(id, content)
	idToData[id] = content
	-- content can be false to indicate an error, which we don't need to clear out of memory
	if not content then return false end
	if #idsStored == MAX_CONTENT_TO_STORE then
		local remove = table.remove(idsStored, 1)
		idToData[remove] = nil
		idToBookContent[remove] = nil
	end
	table.insert(idsStored, id)
	return content
end
local imageHandler = ImageHandler.new()
BooksContentCache.ImageHandler = imageHandler
local function getStorePRBook(id, content)
	local elements = CustomMarkdown.ParseText(content.Content, content)
	imageHandler:PreloadElements(elements)
	local book = PreRender.All(elements, nil, readerConfig)
	idToBookContent[id] = book
	return book
end
function BooksContentCache:GetContentDataAsync(id)
	--	returns bookContent, bookData
	--		(bookContent from Writer.BookContent, bookData from Books)
	--	returns false if book errored during initialization
	local content = idToData[id]
	if content == nil then
		content = storeContent(id, getContent:InvokeServer(id))
	elseif content then
		updateBookAccessed(id)
	end
	if content == false then return false end
	return idToBookContent[id] or getStorePRBook(id, content), content
end
return BooksContentCache