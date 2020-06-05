# Coding Style

Please maintain a consistent style throughout the project ([here's why](https://stackoverflow.com/a/1325617)).

* Never do anything that will trigger a warning in Roblox's Script Analysis window
* Never create "global" variables (always use the `local` keyword)
* Use `camelCase` for variables (in the same way that Roblox offers `workspace`/`game`) unless you're mimicking a Roblox service or ModuleScript name
  * ex, `local MessagingService = game:GetService("MessagingService")`
* Use `PascalCase` for public functions/fields, mimicking Roblox's capitalization
* Document the type of variables where they are defined when their name doesn't make it obvious
  * Prefer to use variable names that describe their type
  * `local playerToProfile = {}` is clearly a table that maps players to some profile table, so no documentation required
  * `local profiles = {}` is fine if it's a list of profiles, but not preferred if it's the same type as the previous example. You could document this with `Dictionary<player, profile>` or `profiles[player] = profile`
  * For nested tables: `local friends = {} -- Dictionary<player, List<friend:Profile>>`
* Indent with tabs, so everyone can use a different tab spacing if they want
  * If you wish to align something (ex in a multiline comment), you may mix tabs (to get in line with the rest of the code) and spaces for the alignment so that it will look the same regardless of tab spacing.
* Don't line up variables like this:
```lua
	local someVar    = 1
	local anotherVar = 2
	-- Doing this looks nicer but requires time to create and update them
```
* Never use deprecated functions (ex use `:Connect` instead of `:connect`)
* Group related functions together; they do not need a blank line between them (but put a blank line before/after them).
* Declare variables that are only used in one block just above that block. A "block" can be one or more related loops, functions, classes, etc.

For other guidelines, refer to <https://roblox.github.io/lua-style-guide/>, but with these changes:
* Allow guard statements on one line. They give the example `if valueIsInvalid then return end`.
* Allow very short functions on one line, such as getters/setters/simple comparison functions (ex for `table.sort`)
* No space after `{` for tables. ex, use `local list = {1, 2, 3}`, not `local list = { 1, 2, 3 }`
* Do not add `function MyClass.isMyClass(instance)` if the class may be inherited from.
  * Try to avoid checking whether something "is" of a particular class except for when validating arguments.
  * It's better to have a function defined on a class, like "MyClass:CanSave()", or just check to see whether the function is defined before using it; this way other classes can be passed in as well.
  * For custom classes which support `:IsA` functionality, see `game.ReplicatedStorage.Utilities.Class`. Note that `:Is` is used to ensure the Script Analysis window does not complain.
* Allow mixed tables (but be cautious with them - you can't send them to any Remote/Bindable Event/Function, nor the data stores)
* There is nothing wrong with using `workspace` or `game.Players`. Use `GetService` for any service that is not visible in the Explorer window.
* Use `local funcName = function() end` instead of `local function funcName() end` to emphasize that `funcName` is a variable and changes in the code.
* Use your editor's text wrapping instead of manually entering newlines in code or comments.
  * There's nothing wrong with having multiple lines of comments (ex one line per concept).
  * If your code is getting very wide, consider breaking it up for clarity

```lua
--[[MyModule
This is an optional block comment to describe what MyModule does and anything you need to know about using it. ex, if it establishes an interface (a list of functions/fields that an object sent into this module must contain), that can be documented here like so:
Movement interface:
	.Name:string
	:GetSpeed() -> number
	:AccelFromMode(mode:integer) -> accel:number -- returns nil for invalid modes
		-- Extra explanation of each argument and the return value can show up here
	:IsPartInModel(part:Instance) -> bool
]]
local MessagingService = game:GetService("MessagingService")

local RS = game.ReplicatedStorage
local Assert = require(RS.Utilities.Assert)
local Resources = require(RS.Resources)
local OtherModule = require(script.Parent.OtherModule)

local MyModule = {}

function MyModule.DoSomething(arg) -- optional brief summary; can include argument/return value descriptions if very brief.
	--	Notice the tab after the '--'. Additional descriptions of arguments/return value(s) here.
	--	Asserting an argument's type/value counts as documentation so long as it is done before non-assertion code (see LineEquation for an example)
end
function MyModule.LineEquation(m, x, b)
	--	Returns the result of m*x + b
	Assert.Number(m) -- slope
	assert(type(x) == "number") -- (this is okay too, but the Assert library gives more information) 
	b = b or 0
	-- The above 3 lines document the arguments. ex, in "b = b or 0", we're making it clear the type & default value.
	--	More information about the arguments can be added as a comment beside each.
	--	Assertions are recommended for values that are not immediately used to catch `nil` being passed in. Thus, the assertions in this function are not needed, since the return statement will error if anything is wrong. (In this particular case, allowing 'm' and 'b' to be Vector3s is also handy.)
	return m * x + b
end

for _, c in ipairs(workspace:GetChildren()) do -- "_" is fine for variables you don't use
	-- Short variables like "c" are fine for smaller loops, but be more descriptive for more complex code
end

return MyModule
```
