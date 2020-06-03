# Roblox-Public-Library

# Recommended Tools for Contributing

* [Rojo 0.5.4](https://github.com/rojo-rbx/rojo/releases/tag/v0.5.4)
  * If you ensure that the executable is in your system path, you can simply run any of the `start rojo.bat` files to start Rojo running with the appropriate project.
* [Nexus Unit Testing Plugin](https://www.roblox.com/library/4735386072/Nexus-Unit-Testing-Plugin)
  * You can make it easy to run this in Roblox by going to `FILE` > `Advanced` > `Customize Shortcuts...`, searching by `Run Unit Tests`, and binding the one that shows up that mentions "Nexus" to a convenient hotkey.

# Unit Testing Process

1. Start rojo. If you use the most specific configuration's "start rojo.bat" file in a place without unit tests, you'll avoid having to wait for irrelevant unit tests to run.
2. Open a Roblox place with any necessary resources (if none are needed, an empty baseplate will do).
3. Run the place (without a character). Doing this ensures that tests cannot permanently modify the place.
4. Activate Rojo within Roblox.
5. Use your shortcut to `Run Unit Tests`. If you can't see the Unit Tests window, (re)select "Unit Tests" in the Plugins bar.
6. You can now modify scripts and Rojo will update them, even if their location has been moved by an installer script. Save your script(s), alt+tab to Roblox, `Run Unit Tests`, and see the results!
7. If a bug occurs and a test damages the game, preventing unit tests from functioning properly, simply stop the simulation and repeat steps 3+ when you're ready to test again.