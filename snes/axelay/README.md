Lua scripts for Axelay
======================

Diffferent Lua scripts for Axelay. Use these with BizHawk.

dodge-final-boss.lua
--------------------

During the final boss fight, the boss releases a scanner that scans you before releasing clones of your ship. However, the scanner moves slower than your ship, so you can avoid it indefinitely by flying in circles. I wanted to see if anything interesting would happen if you avoided it for a long itme, so this script just flies the ship in circles to avoid it. It turns out that nothing happens.

glitch-search.lua
-----------------

Rarely, when you do the wapon selection, the jingle "Arms intallation is complete. Good luck." will be cut short. I've only seen it happen 3 times: once on console, and twice on emulator. I've never been able to reproduce it. This script was an attempt to automatically search for it, but it was unsuccessful.

info.lua
--------

I used this when routing the game. It includes a lot of features to help in routing and trying different tactics, including:

- Draws a yellow box around your ship during lag frames
- Shows lag frame count per level
- Displays the health for bosses and mini bosses
- Times boss kill time and compares against best
- Displays second boss's current action
- Press select on weapon selection screen to choose level
- Pause and press select to add lives
- Pause and press left/right to change difficulty
- Pause and press up/down to change trigger speed
- Pause and press L/R to change the currently selected weapon's loadout

second-boss-behavior.asm
------------------------

Just an assembly dump of the second boss's behavior. Of note is that its health starts at 192, and it will try to fire its large laser if its health is below 128 after taking a step. It's not 100% assured though and I'm not sure why. I think it has to do with your ship's vertical subpixel position.

sound-test.lua
--------------

Axelay has a sound †est tthat was disabled, but it appears to be incomplete. This was an attempt to fix it, but it's not working.
