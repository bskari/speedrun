-- BizHawk Lua script for U.N. Squadron
-- Shows boss health, shows time to kill bosses, saves boss kill times, draws
-- a square over your aircraft whenever there is lag, and allows cheating.
-- Pause the game and press:
--   Up/Down to change difficulty
--   Left/Right to change weapon level
--   Y to reset health
--   B to increase current special weapon count

message_display_counter = 0;
message = '';
message_x_position = 0;
previous_buttons = joypad.get(1);
boss_appear_frame = nil;
statistics = {};
stage = nil;

last_memory_write_frame = 0;
last_lag_frame = 0;

function main()
	console.clear();

	event.onloadstate(on_load_state);
	event.onsavestate(on_save_state);

	local statistics_file = io.open('un_squadron_stats.txt', 'r');
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

	stage = mainmemory.read_u8(0xAF);

	indicate_lag();
	show_boss_health();
	cheat();
end

function on_save_state(state_name)
	local difficulty_table = {[0]='Easy', 'Normal', 'Hard', 'Gamer'};
	local difficulty = difficulty_table[mainmemory.read_u8(0xFFD6)];
	if statistics[difficulty] == nil then
		statistics[difficulty] = {};
	end
	if statistics[difficulty][stage] == nil then
		statistics[difficulty][stage] = {};
	end
	statistics[difficulty][stage][state_name] = boss_appear_frame;
end

function on_load_state(state_name)
	write_message('Loaded state', 30);
	last_lag_frame = 0;
	if (
		statistics[difficulty] ~= nil
		and statistics[difficulty][stage] ~= nil
		and statistics[difficulty][stage][state_name] ~= nil
	) then
		boss_appear_frame = statistics[difficulty][stage][state_name];
		console.log(string.format('Set boss appear frame to %d', boss_appear_frame));
	else
		boss_appear_frame = nil;
	end
end

function write_message(msg, frame_count, x)
	if frame_count == nil then
		frame_count = 60;
	end
	if x == nil then
		message_x_position = 0;
	else
		message_x_position = x;
	end
	message = msg;
	message_display_counter = frame_count;
end

function indicate_lag()
	-- Draw a square over your plane if the game is lagging
	if emu.islagged() then
		ship_x = mainmemory.read_u8(0x1011) / 2;
		ship_y = mainmemory.read_u8(0x1014);
		gui.drawRectangle(ship_x * 2 - 3, ship_y - 3, 6, 6, 'yellow', 'yellow');
	end
end


function show_boss_health()
	-- Don't overwrite other messages
	if message_display_counter > 1 then
		return;
	end

	local hp_address = nil;
	local hp = 0;

	-- This appears to be the same for all bosses
	hp_address = 0x14C8;

	if hp_address ~= nil then
		hp = mainmemory.read_u16_le(hp_address);

		local boss_dead = false;
		if hp > 65000 then
			-- Sometimes when you kill the boss it rolls over
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
			save_statistics(kill_frames);
		end
	end
end

-- Pause and then press:
--   Up/Down to change difficulty
--   Left/Right to change weapon level
--   Y to reset health
--   B to increase special weapon count
function cheat()
	local buttons = joypad.get(1);
	
	if emu.islagged() then
		last_lag_frame = emu.framecount();
	end

	-- Plane and weapon select screen
	if mainmemory.read_u8(0x1) == 208 or mainmemory.read_u8(0x1) == 210 then
		if (buttons['Select'] and not previous_buttons['Select']) then
			-- Okay, so check this shit out. The game stores the 10,000 value
			-- in 0xD8. Easy so far, right? But, it uses the hex value as the
			-- decimal value. So like, if you have 0x24 in there, it means it's
			-- literally 24 decimal. WTF what is this I guess BCD should more
			-- accurately be called byte encoded decimal, so this shit is nibble
			-- encoded decimal?
			local ten_thousands_money = mainmemory.read_u16_le(0xD8);
			local new_ten_thousands_money = ten_thousands_money + 10;
			while string.match(string.format('%x', new_ten_thousands_money), '[abcdef]') do
				new_ten_thousands_money = new_ten_thousands_money + 10;
			end
			mainmemory.write_u16_le(0xD8, new_ten_thousands_money);
			write_message(
				string.format(
					'Money set to $%x%x00 probably',
					new_ten_thousands_money,
					mainmemory.read_u8(0xD7)),
				60);
		end
	end

	-- Paused
	if (
		-- I'm not sure what these represent, but they're both set when the
		-- game is paused, as well as when it lags, so just ignore the lag.
		-- Unfortunately this also triggers after beating a boss/level, so
		-- that's the additional 0xF08 check.
		mainmemory.read_u8(0x39) == 1
		and mainmemory.read_u8(0x68) == 16
		and emu.framecount() - last_lag_frame > 3
		and mainmemory.read_u16_le(0xF06) == 0  -- Bonus points
		and mainmemory.read_u16_le(0xF08) == 0  -- Weapon money
	) then
		-- Change difficulty
		if (
			(buttons['Up'] and not previous_buttons['Up'])
			or (buttons['Down'] and not previous_buttons['Down'])
		) then
			local step = 1;
			if buttons['Down'] then
				step = -1;
			end
			local new_difficulty = (mainmemory.read_u8(0xFFD6) + step) % 4;
			mainmemory.write_u8(0xFFD6, new_difficulty);
			difficulty_string = {};
			difficulty_string[0] = 'Easy';
			difficulty_string[1] = 'Normal';
			difficulty_string[2] = 'Hard';
			difficulty_string[3] = 'Gamer';
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
			local new_weapon_level = (mainmemory.read_u8(0xD6) + step);
			if new_weapon_level < 0 then
				new_weapon_level = 0;
			elseif new_weapon_level > 7 then  -- This is probably too high...
				new_weapon_level = 7;
			end
			mainmemory.write_u8(0xD6, new_weapon_level);
			write_message(string.format('Weapon level set to %d', new_weapon_level + 1), 60);
		elseif (
			(buttons['Y'] and not previous_buttons['Y'])
		) then
			-- Reset health
			mainmemory.write_u8(0x1008, 8);
			write_message('Max health', 60);
		elseif (
			(buttons['B'] and not previous_buttons['B'])
		) then
			-- Add special weapon
			-- 0xD4 appears to be currently selected weapon, 0 = Cluster
			-- 0xDD is weapon 0 count, each byte after is next weapon count
			local current_weapon = mainmemory.read_u8(0xD4);
			if current_weapon ~= 255 then
				local weapon_count_address = 0xDD + current_weapon;
				local current_count = mainmemory.read_u8(weapon_count_address);
				mainmemory.write_u8(weapon_count_address, current_count + 1);
				write_message(
					string.format(
						'Set weapon %d to %d',
						current_weapon + 1,
						current_count + 1),
					60);
			end
		end
	end

	previous_buttons = buttons;
end

function save_statistics(frames)
	if frames > 60 * 60 * 10 then
		return;
	end
	local difficulty_table = {[0]='Easy', 'Normal', 'Hard', 'Gamer'};
	local difficulty = difficulty_table[mainmemory.read_u8(0xFFD6)];
	if statistics[difficulty] == nil then
		statistics[difficulty] = {};
	end
	if statistics[difficulty][stage] == nil then
		statistics[difficulty][stage] = {};
	end
	table.insert(statistics[difficulty][stage], frames);

	local statistics_file = io.open('un_squadron_stats.txt', 'w+');
	if statistics_file == nil then
		console.log('Unable to open statistics file for saving');
		return;
	end
	statistics_file:write(get_formatted_statistics(statistics));
	statistics_file:close();
end

function get_best_kill_frames()
	local difficulty_table = {[0]='Easy', 'Normal', 'Hard', 'Gamer'};
	local difficulty = difficulty_table[mainmemory.read_u8(0xFFD6)];
	if statistics[difficulty] == nil then
		return -1;
	end
	if statistics[difficulty][stage] == nil then
		return -1;
	end
	if #statistics[difficulty][stage] == 0 then
		return -1;
	end
	return min(statistics[difficulty][stage]);
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
	for level, times in pairs(levels) do
		result = result .. '  [' .. tostring(level)
			.. string.format(']={ --[[ level %d --]] ', level + 1)
			.. get_formatted_times(times) .. ' \n';
	end
	return result;
end

function get_formatted_times(times)
	local result = '';
	for _, t in pairs(times) do
		result = result .. tostring(t) .. ',';
	end
	result = result .. '},\n';
	return result;
end

function get_record_count(tbl)
	local count = 0;
	for difficulty, stages in pairs(tbl) do
		for stage, records in pairs(stages) do
			count = count + #records;
		end
	end
	return count;
end

main()
