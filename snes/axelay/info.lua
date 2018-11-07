-- Lua script for EmuHawk emulator for Axelay
-- Features:
-- Draws a yellow box around your ship during lag frames
-- Shows lag frame count per level
-- Displays the health for bosses and mini bosses
-- Times boss kill time and compares against best
-- Displays second boss's current action
-- Press select on weapon selection screen to choose level
-- Pause and press select to add lives
-- Pause and press left/right to change difficulty
-- Pause and press up/down to change trigger speed
-- Pause and press L/R to change the currently selected weapon's loadout

previous_stage = 0;
message_display_counter = 0;
message = '';
message_x_position = 0;
stage = -1;
previous_buttons = joypad.get(1);
boss_appear_frame = nil;
statistics = {};
save_state_to_boss_appear_frame = {};

last_memory_write_frame = 0;
backtrace = {{}, {}};


function main()
	console.clear();

	event.onloadstate(on_load_state);
	event.onsavestate(on_save_state);

	--register_backtrace();

	local statistics_file = io.open('axelay_stats.txt', 'r');
	if statistics_file == nil then
		console.log('Unable to load statistics file');
	else
		local info_string = statistics_file:read('*all');
		if string.len(info_string) ~= 0 then
			info_string = string.gsub(info_string, '\n', '');
			local func = loadstring('return ' .. info_string);
			statistics = func();
			get_record_count(statistics);
			message = string.format(
				'Loaded %d records',
				get_record_count(statistics));
			message_display_counter = 60;
		end
		statistics_file:close();
	end

	while true do
		every_frame();
		emu.frameadvance();
	end
end

function every_frame()
	
	if message_display_counter > 0 then
		gui.drawString(message_x_position, 0, message);
		message_display_counter = message_display_counter - 1;
	end

	stage = mainmemory.read_u8(0x1E62);

	indicate_lag();
	show_boss_health();
	show_second_boss_action();
	cheat();
end

function on_save_state(state_name)
	local boss_id = get_boss_id();
	if boss_id == nil then
		console.log('boss_id is nil');
		return;
	end
	local difficulty_table = {[0]='Easy', 'Normal', 'Hard', 'Monkey'};
	local difficulty = difficulty_table[mainmemory.read_u8(0x1E3A)];
	if statistics[difficulty] == nil then
		statistics[difficulty] = {};
	end
	if statistics[difficulty][stage] == nil then
		statistics[difficulty][stage] = {};
	end
	if statistics[difficulty][stage][boss_id] == nil then
		statistics[difficulty][stage][boss_id] = {};
	end
	statistics[difficulty][stage][boss_id][state_name] = boss_appear_frame;
end

function on_load_state(state_name)
	write_message('Loaded state', 30);
	previous_stage = mainmemory.read_u8(0x1E62);
	local boss_id = get_boss_id();
	if (
		statistics[difficulty] ~= nil
		and statistics[difficulty][stage] ~= nil
		and boss_id ~= nil
		and statistics[difficulty][stage][boss_id] ~= nil
		and statistics[difficulty][stage][boss_id][state_name] ~= nil
	) then
		boss_appear_frame = statistics[difficulty][stage][boss_id][state_name];
		console.log(string.format('Set boss appear frame to %d', boss_appear_frame));
	else
		boss_appear_frame = nil;
	end
end

function write_message(msg, frame_count, x)
	if x == nil then
		message_x_position = 0;
	else
		message_x_position = x;
	end
	message = msg;
	message_display_counter = frame_count;
end

function indicate_lag()
	-- Draw a square over Axelay if the game is lagging
	if emu.islagged() then
		axelay_x = mainmemory.read_u8(0x9B);
		axelay_y = mainmemory.read_u8(0x9D);
		-- This calculation doesn't quite work on vertical scrolling stages,
		-- because of the parallax effect when you're at the top of the screen
		if stage % 2 == 0 then
			-- We need to double these values on vertical scrolling stages and offset
			gui.drawRectangle(axelay_x * 2 - 3, axelay_y * 2 - 160 - 3, 6, 6, 'yellow', 'yellow');
		else
			gui.drawRectangle(axelay_x * 2 - 3, axelay_y - 3, 6, 6, 'yellow', 'yellow');
		end
	end

	-- Show the number of lag frames this stage
	if previous_stage ~= stage then
		-- If this happened because of stage select, then ignore it
		if message_display_counter == 0 and emu.lagcount() > 0 then
			previous_stage = stage;
			write_message(string.format('Stage lag frames: %d', emu.lagcount()), 300);
		end

	-- The game "lags" when it's loading assets for the next stage. That's
	-- nothing we care about because there's nothing we can do to avoid it,
	-- so wait until the stage has finished loading and the player has control
	-- before starting counting lag frames again.
	elseif mainmemory.read_u8(0x18C53) == 1 then
		emu.setlagcount(0);
	end
end

function get_boss_id()
	local enemy_id;
	if stage == 0 then
		enemy_id = mainmemory.read_u8(0x15B8);
		if enemy_id == 0x2B or enemy_id == 0x3A then
			return enemy_id;
		end
	elseif stage == 1 and mainmemory.read_u8(0x1630) == 0x71 then
		return 0x71;
	elseif stage == 2 then
		enemy_id = mainmemory.read_u8(0x15B8);
		if enemy_id == 0x92 or enemy_id == 0x41 then
			return enemy_id;
		end
	elseif stage == 3 and mainmemory.read_u8(0x600) == 0x7E then
		return 0x7E;
	elseif stage == 4 and mainmemory.read_u8(0x15B8) == 0x5B then
		return 0x5B;
	elseif stage == 5 then
		enemy_id = mainmemory.read_u8(0x15B8);
		if enemy_id == 0x24 or enemy_id == 0xBA then
			return enemy_id;
		end
	end
	return nil;
end

function show_boss_health()
	-- Don't overwrite other messages
	if message_display_counter > 1 then
		return;
	end

	local hp_address = nil;
	local two_bytes = false;
	local enemy_id = get_boss_id();
	local hp = 0;
	if enemy_id == nil then
		return;
	end

	if stage == 0 then
		hp_address = 0x15BC;
	elseif stage == 1 then
		hp_address = 0x1634;
	elseif stage == 2 then
		hp_address = 0x15BC;
	elseif stage == 3 then
		hp_address = 0x60C;
		two_bytes = true;
		enemy_id = 0x7E;
	elseif stage == 4 then
		hp_address = 0x15BC;
		enemy_id = 0x5B;
	elseif stage == 5 then
		if enemy_id == 0x24 then
			hp_address = 0x1634;
		end
		if enemy_id == 0xBA then
			hp_address = 0x15BC;
		end
	end

	if hp_address ~= nil then
		if two_bytes then
			hp = mainmemory.read_u16_le(hp_address);
		else
			hp = mainmemory.read_u8(hp_address);
		end

		local boss_dead = false;
		-- Some bosses never reach exactly 0 health, it just rolls back over to
		-- 255, so we can't just use health to check if the boss is dead, but
		-- the value at 0x15C6 is the boss transformation state, so we'll use
		-- that
		if (
			(
				stage == 2
				and (
					(
						mainmemory.read_u8(0x15B8) == 0x92  -- enemy is mini boss
						and mainmemory.read_u8(0x15C6) >= 0x09  -- transformations state
					) or (
						mainmemory.read_u8(0x15B8) == 0x41  -- enemy is boss
						and mainmemory.read_u8(0x15BA) ~= 0x06  -- boss state?
					)
				)
			) or (
				stage == 3
				and hp > 65000
			)
		) then
			boss_dead = true;
		elseif hp > 0 then
			if message_display_counter <= 1 then
				local alive_frames = 0;
				if boss_appear_frame ~= nil then
					alive_frames = emu.framecount() - boss_appear_frame;
				end
				write_message(string.format('%d HP %.1f s', hp, alive_frames / 60), 1, 80);
			end
			if boss_appear_frame == nil then
				boss_appear_frame = emu.framecount();
				local best_kill_frames = get_best_kill_frames(enemy_id);
				write_message(string.format('Best time: %.2f', best_kill_frames / 60), 120, 70);
			end
		elseif boss_appear_frame ~= nil then
			boss_dead = true;
		end

		if boss_dead and boss_appear_frame ~= nil then
			-- This includes pause frames... sorry
			local kill_frames = emu.framecount() - boss_appear_frame;
			local best_kill_frames = get_best_kill_frames(enemy_id);
			-- kill_frames can get confused by save states
			if kill_frames > 3 * 60 and kill_frames < 60 * 60 * 10 then
				local sign = '';
				if kill_frames > best_kill_frames then
					sign = '+';
				end;
				write_message(
					string.format(
						'Killed in %.2f s (%s%.2f s)',
						kill_frames / 60,
						sign,
						(kill_frames - best_kill_frames) / 60),
					180);
			end
			boss_appear_frame = nil;
			-- The mini boss on stage 6 will cause the level to loop if it's
			-- not dead by a certain time, but when it checks for looping, it
			-- just reloads the boss health (0). These are bogus kill times, so
			-- don't save them.
			if stage ~= 5 or enemy_id ~= 0x24 or kill_frames > 5 * 60 then
				save_statistics(enemy_id, kill_frames);
			end
		end
	end
end

-- Pause and then press:
--   Select for extra life
--   L/R to change weapon
--   Up/Down to change difficulty
--   Left/Right to change trigger speed
-- At weapon menu, press Select to change stage
function cheat()
	local buttons = joypad.get(1);

	-- At weapon screen, press Select to change stage
	if (
		mainmemory.read_u8(0xE02) ~= 3 -- How many weapons have been selected
		and mainmemory.read_u8(0x18C53) == 0 -- Gameplay status?
		and buttons['Select'] and not previous_buttons['Select']
	) then
		local new_stage = (stage + 1) % 6;
		mainmemory.write_u8(0x1E62, new_stage);
		write_message(string.format('Stage %d', new_stage + 1), 60);
	end

	-- Paused
	if mainmemory.read_u8(0x4E) == 1 then
		-- Add extra life
		if buttons['Select'] and not previous_buttons['Select'] then
			local new_lives = mainmemory.read_u8(0x5E) + 1;
			mainmemory.write_u8(0x5E, new_lives);
			-- The lives display doesn't update until you die or earn an extra
			-- life, so just print out a message so the player isn't confused
			write_message(string.format('Life added, lives is now %d', new_lives), 60);

		-- Change difficulty
		elseif (
			(buttons['Up'] and not previous_buttons['Up'])
			or (buttons['Down'] and not previous_buttons['Down'])
		) then
			local step = 1;
			if buttons['Down'] then
				step = -1;
			end
			local new_difficulty = (mainmemory.read_u8(0x1E3A) + step) % 10;
			-- It appears that there are two memory addresses that need to be set...
			mainmemory.write_u8(0x1E3A, new_difficulty);
			mainmemory.write_u8(0x1E5A, new_difficulty);
			difficulty_string = {};
			difficulty_string[0] = 'Easy';
			difficulty_string[1] = 'Normal';
			difficulty_string[2] = 'Hard';
			difficulty_string[3] = 'Monkey (Very Hard)';
			-- I was experimenting with difficulty levels above 3, which isn't
			-- possible normally
			if difficulty_string[new_difficulty] == nil then
				difficulty_string[new_difficulty] = new_difficulty;
			end
			write_message(
				string.format('Difficulty set to %s', difficulty_string[new_difficulty]),
				60);

		elseif (
			(buttons['Left'] and not previous_buttons['Left'])
			or (buttons['Right'] and not previous_buttons['Right'])
		) then
			local step = 1;
			if buttons['Left'] then
				step = -1;
			end
			local new_trigger_speed = (mainmemory.read_u8(0x1E58) + step) % 5;
			-- It appears that there are two memory addresses that need to be set...
			mainmemory.write_u8(0x1E38, new_trigger_speed);
			mainmemory.write_u8(0x1E58, new_trigger_speed);
			write_message(string.format('Trigger speed set to %d', new_trigger_speed), 60);

		elseif (
			(buttons['L'] and not previous_buttons['L'])
			or (buttons['R'] and not previous_buttons['R'])
		) then
			-- Change current weapon
			local weapon_description = {
				'default',  -- Heat Blaster
				'Straight Laser',
				'Round Vulcan',
				'default',  -- Flare Grenade
				'Wind Laser',
				'Explosion Bombs',
				'Macro Missiles',
				'crash',  -- Homing Missile
				'Cluster Bombs',
				'Morning Star',
				'Needle Cracker'
			};
			local weapon_list = {
				[2]=11, [11]=5, [5]=2,  -- Pod
				[3]=10, [10]=3,  -- Side
				[7]=6, [6]=9, [9]=7  -- Bay
			};
			-- Note that any slot can hold any weapon, you can even have 3
			-- copies of the same weapon
			local current_slot = mainmemory.read_u8(0x100E);
			if current_slot == 0 then
				weapon_memory = 0x330; -- Pod
			elseif current_slot == 1 then
				weapon_memory = 0x332; -- Side
			else
				weapon_memory = 0x334; -- Bay
			end

			local new_weapon = -1;
			local current_weapon = mainmemory.read_u8(weapon_memory);
			if current_weapon == 1 or current_weapon == 4 or current_weapon > 11 then  -- Disabled
				if weapon_memory == 0x330 then
					new_weapon = 2;
				elseif weapon_memory == 0x332 then
					new_weapon = 3;
				else
					new_weapon = 6;
				end
			else
				for index, item in pairs(weapon_list) do
					if index == current_weapon then
						new_weapon = item;
						break;
					end
				end
			end
			mainmemory.write_u8(weapon_memory, new_weapon);
			-- The screen won't update until we unpause, so just print out a
			-- message so the user isn't confused
			--write_message(weapon_description[new_weapon], 30);
			write_message(weapon_description[new_weapon], 30);
		end
	end

	previous_buttons = buttons;
end

function save_statistics(boss_id, frames)
	if true then
		return;
	end
	if frames > 60 * 60 * 10 then
		return;
	end
	local difficulty_table = {[0]='Easy', 'Normal', 'Hard', 'Monkey'};
	local difficulty = difficulty_table[mainmemory.read_u8(0x1E3A)];
	if statistics[difficulty] == nil then
		statistics[difficulty] = {};
	end
	if statistics[difficulty][stage] == nil then
		statistics[difficulty][stage] = {};
	end
	if statistics[difficulty][stage][boss_id] == nil then
		statistics[difficulty][stage][boss_id] = {}
	end
	table.insert(statistics[difficulty][stage][boss_id], frames);

	local statistics_file = io.open('axelay_stats.txt', 'w+');
	if statistics_file == nil then
		console.log('Unable to open statistics file for saving');
		return;
	end
	statistics_file:write(get_formatted_statistics(statistics));
	statistics_file:close();
end

function get_best_kill_frames(boss_id)
	local difficulty_table = {[0]='Easy', 'Normal', 'Hard', 'Monkey'};
	local difficulty = difficulty_table[mainmemory.read_u8(0x1E3A)];
	if statistics[difficulty] == nil then
		return -1;
	end
	if statistics[difficulty][stage] == nil then
		return -1;
	end
	if statistics[difficulty][stage][boss_id] == nil then
		return -1;
	end
	if #statistics[difficulty][stage][boss_id] == 0 then
		return -1;
	end
	return min(statistics[difficulty][stage][boss_id]);
end

function min(tbl)
	local min_ = nil;
	for k, v in ipairs( tbl ) do
		min_ = v;
		break;
	end
	for k, v in ipairs( tbl ) do
		if min_ > v then
			min_ = v;
		end
	end
	return min_;
end

function get_formatted_statistics(stats)
	local result = '{\n';
	for difficulty, levels in pairs(stats) do	
		result = result .. " [\"" .. difficulty .. "\"]={\n" ..
			get_formatted_levels(levels) .. ' },\n';
	end
	return result .. '}';
end

function get_formatted_levels(levels)
	local result = '';
	for level, enemies in pairs(levels) do
		result = result .. '  [' .. tostring(level)
			.. string.format(']={ --[[ level %d --]] \n', level + 1)
			.. get_formatted_enemies(enemies) .. '  },\n';
	end
	return result;
end

function get_formatted_enemies(enemies)
	local result = '';
	for enemy_id, times in pairs(enemies) do
		if enemy_id == 0x58 or enemy_id == 0x92 or enemy_id == 0x24 then
			result = result .. '   [' .. tostring(enemy_id) .. ' --[[ mini boss --]] ]={';
		else
			result = result .. '   [' .. tostring(enemy_id) .. ']={';
		end
		for _, t in pairs(times) do
			result = result .. tostring(t) .. ',';
		end
		result = result .. '},\n';
	end
	return result;
end

function get_record_count(tbl)
	local count = 0;
	for difficulty, stages in pairs(tbl) do
		for stage, bosses in pairs(stages) do
			for boss, records in pairs(bosses) do
				count = count + #records;
			end
		end
	end
	return count;
end

function print_backtrace()
	local print_part = function(bt)
		for _, address in pairs(bt) do
			console.log(string.format('%x', address));
		end
	end

	print_part(backtrace[1]);
	print_part(backtrace[2]);
	client.pause();
end

function on_memory_write()
	local pc = emu.getregister('PC') + 0;
	local next_instruction = emu.disassemble(pc);
	local previous_instruction = emu.disassemble(pc - next_instruction.length);
	local opcode = string.sub(previous_instruction.disasm, 1, 3);
	local new_value = 0;
	if opcode == 'sta' then
		new_value = bit.band(emu.getregister('A'), 0xFF);
	elseif opcode == 'inc' then
		new_value = mainmemory.read_u8(0x15C7) + 1;
	elseif opcode == 'asl' then
		new_value = mainmemory.read_u8(0x15C7) * 2;
	end
	
	if emu.framecount() - last_memory_write_frame > 10 then
		console.log('');
	end

	console.log(
		string.format(
			'%d Wrote 0x15C7 = %d at %x: %s',
			emu.framecount(),
			new_value,
			pc - next_instruction.length,
			opcode));

	last_memory_write_frame = emu.framecount();
end

function poor_mans_backtrace(address)
	if #backtrace[2] > 100 then
		backtrace[1] = backtrace[2];
		backtrace[2] = {};
	end
	table.insert(backtrace[2], address);
end

function register_backtrace()
	event.onmemorywrite(on_memory_write, 0x15C7);
	event.onmemoryexecute(print_backtrace, 0x03ee6d);

	for address=0x03ee00,0x03efff do
		event.onmemoryexecute(function () poor_mans_backtrace(address); end, address);
	end
end

function show_second_boss_action()
	if stage ~= 1 or mainmemory.read_u8(0x15b8) ~= 113 then
		return;
	end

	-- Show the current action
	local actions = {
		[7]='chained',
		[8]='standing',
		[9]='start',
		[11]='walking',
		[13]='charging',
		[15]='laser',
		[20]='will bullet',
		[21]='bullet',
	};
	local act = actions[mainmemory.read_u8(0x15c7)];
	if act == nil then
		act = string.format('%d', mainmemory.read_u8(0x15c7));
	end
	gui.drawString(100, 20, act);
end

main()
