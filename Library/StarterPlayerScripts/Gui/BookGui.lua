local module = {}
local bookOpened = Instance.new("BindableEvent")
module.BookOpened = bookOpened.Event
local bookClosed = Instance.new("BindableEvent")
module.BookClosed = bookClosed.Event
-- Exporting the bindables is a patch to let the book script trigger them
module.bookOpened = bookOpened
module.bookClosed = bookClosed
return module