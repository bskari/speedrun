-- The final boss releases a pair of balls that it scans your ship with, but
-- you can indefinitely dodge that by just flying in circles. The mini bosses
-- in the game will eventually kill themselves after some timeout if you don't
-- attack them, and I was curious if that happened on the final boss too. This
-- script just flies Axelay in a circle to dodge the scanner. It turns out that
-- there is no timeout on the boss - you can dodge it forever.

function dodge()
	console.log(joypad.get(1));
	joypad.set({Start='True'}, 1);
	emu.frameadvance();
	local directions = {'Left', 'Up', 'Right', [0]='Down'};
	local current = 1;
	while true do
		local new_buttons = {[directions[current]]=true, Y=true, B=true};
		for _=1,15 do
			joypad.set(new_buttons, 1);
			emu.frameadvance();
		end
		new_buttons = {
			[directions[current]]=true,
			[directions[(current + 1) % 4]]=true,
			Y=true,
			B=true
		};
		for _=1,15 do
			joypad.set(new_buttons, 1);
			emu.frameadvance();
		end
		current = (current + 1) % 4;
	end
end

dodge();