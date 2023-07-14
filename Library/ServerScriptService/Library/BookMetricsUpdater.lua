--[[BookMetricsUpdater
This module manages the book metrics update queue and global key. It also automatically loads metrics.
.GetMetrics() -> [bookId] = {.Likes .EReads etc}. If metrics have not been loaded, will return all 0s.
.MetricsChanged : Event
.WaitForInitialMetrics() -- same as GetMetrics but guarantees that metrics will have been loaded at least once
.OnlineTracker : OnlineTracker
.IsShuttingDown : ShutdownMonitor
.Update class
	.new()
	:Add(bookId, deltas)
	:Send(onRejected) -- onRejected is called if the update failed to be added to the Memory Store queue; put it in the player's profile instead (and try again later)
This module is also responsible for the creation of Remotes.BookMetricsChanged.
	The client is to call this RemoteEvent to signify initialization
	and then listen to it for updates to book metrics.
	It will receive data that can be interpreted via BookMetrics.GetFromData
]]
return require(game:GetService("ServerScriptService").BookMetricsUpdater.BookMetricsUpdater)