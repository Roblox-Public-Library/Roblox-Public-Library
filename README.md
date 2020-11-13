# Roblox-Public-Library

All the major code and plugins in <https://www.roblox.com/games/331780620/ROBLOX-Library-2020>.

## Recommended Tools for Contributing

* [Rojo 0.5.4](https://github.com/rojo-rbx/rojo/releases/tag/v0.5.4)
  * If you ensure that the executable is in your system path, you can simply run any of the `start rojo.bat` files to start Rojo running with the appropriate project. For instance, if its path is `C:\Rojo\rojo.exe`, add `C:\Rojo` [to the system path](https://www.architectryan.com/2018/03/17/add-to-the-path-on-windows-10/).
  * Also install its Roblox Studio [plugin](https://www.roblox.com/library/1997686364/Rojo-0-5-4)
* [GitHub Desktop](https://desktop.github.com/)
* [Visual Studio Code](https://code.visualstudio.com/), if you wish to collaborate with other team members in real time, with these extensions:
  * [Live Share](https://marketplace.visualstudio.com/items?itemName=MS-vsliveshare.vsliveshare), by Microsoft

  Completely Optional:
  * [Todo+](https://marketplace.visualstudio.com/items?itemName=fabiospampinato.vscode-todo-plus) by Fabio Spampinato
  * [Roblox LSP](https://marketplace.visualstudio.com/items?itemName=Nightrains.robloxlsp) by Nightrains or [Luau](https://marketplace.visualstudio.com/items?itemName=UnderMyWheel.roblox-lua) by UnderMyWheel
  * [Roblox Lua Autocompletes](https://marketplace.visualstudio.com/items?itemName=Kampfkarren.roblox-lua-autofills) by Kampfkarren
  * [Roblox API Explorer](https://marketplace.visualstudio.com/items?itemName=evaera.roblox-api-explorer) by evaera
  * [Select part of word](https://marketplace.visualstudio.com/items?itemName=mlewand.select-part-of-word) by Marek Lewandowski
* [Nexus Unit Testing Plugin Async](https://www.roblox.com/library/5056111603/NexusUnitTestingPluginAsync)
  * You can make it easy to run this in Roblox by going to `FILE` > `Advanced` > `Customize Shortcuts...`, searching by `Run Unit Tests`, and binding the one that shows up that mentions "Nexus" to a convenient hotkey.

## Making Changes

### First-Time Setup

* Read through our style guide in [CONTRIBUTING.md](CONTRIBUTING.md)
* Using GitHub Desktop, clone this project

### What To Change

* If you find a bug, feel free to fix it
* Available tasks are at <https://trello.com/b/xcNHUhQE/roblox-library-development>. Ensure you're communicating with the rest of the team (or at least the lead scripter) so that no one's doing any duplicate work

### Making Your Changes

* Open a Roblox Studio place (the [Scripting Development](https://www.roblox.com/games/5018214687/Roblox-Library-Scripting-Development) place or an empty baseplate if you don't need any assets)
* Run Rojo (ex by running the appropriate `.bat` file and activating the plugin)
* Modify files
* Test them out in Studio (including running Unit Tests, if applicable)
* Using GitHub Desktop (or any git tool), commit your changes to the appropriate branch (named based on the feature you are working on), creating a new one if necessary
* Push your work to GitHub when you want others to be able to see it
* When you're ready, create a pull request so we can review and merge your changes into the master branch and ultimately update the library!

## Unit Testing Process

1. Start rojo. If you use the most specific configuration's "start rojo.bat" file in a place without unit tests, you'll avoid having to wait for irrelevant unit tests to run.
2. Open a Roblox place with any necessary resources (if none are needed, an empty baseplate will do).
3. Run the place (without a character). Doing this ensures that tests cannot permanently modify the place.
4. Activate Rojo within Roblox.
5. Use your shortcut to `Run Unit Tests`. If you can't see the Unit Tests window, (re)select "Unit Tests" in the Plugins bar.
6. You can now modify scripts and Rojo will update them, even if their location has been moved by an installer script. Save your script(s), alt+tab to Roblox, `Run Unit Tests`, and see the results!
7. If a bug occurs and a test damages the game, preventing unit tests from functioning properly, simply stop the simulation and repeat steps 3+ when you're ready to test again.
