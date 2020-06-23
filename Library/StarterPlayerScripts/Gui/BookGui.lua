local module = {}
local bookOpened = Instance.new("BindableEvent")
module.BookOpened = bookOpened.Event
local bookClosed = Instance.new("BindableEvent")
module.BookClosed = bookClosed.Event
return module