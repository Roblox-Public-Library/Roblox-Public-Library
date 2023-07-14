-- Examples and explanations start with '--'
local data = {
	Title = "John's Great Adventure",
	AuthorIds = {2, false},
	AuthorNames = {"John Doe", "Anonymous"},
	CustomAuthorLine = "John Doe (writer) & Anonymous (illustrator)",
	AuthorsNote = [=[Learn about John's __great__ adventure!]=],
	Genres = {"Adventure", "Horror"},
	Cover = 428733812,
	Librarian = "LibraryDrone",
	PublishDate = "6/15/2020",
	Image1 = 5230133461,

	UseLineCommands = false,

	Content = [=[
<chapter,Chapter 1: The Hike>
John Doe is an *adventurous* boy.
One day John decided to go <green>hiking</color>. <image1,30x30,left>An illustration of John hiking is to the <red>**left**</red>.
<clear>In his journal that morning he had written:<indent,		><cartoon>
<center><large>Today's Plans</large><left>
-Hike up the hill
-Find something ~~cool~~ rare <small>I <sub,really> hope</size>
-Hike up the hill
-Practice the Pythagorean Theorem:
	c<sup,2> = a<sup,2> + b<sup,2>
-<sup,Write> a <sub>good <small>poem</sub></small>
</font><bar,*>
Before long, he had hiked up the hill.
<chapter,Chapter 2: The Search>
Now to find something __rare__...
]=],
}





-- Never modify this line:
require(game:GetService("ServerScriptService"):WaitForChild("Books")):Register(script.Parent, data)