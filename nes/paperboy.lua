-- Searches for good RNG patterns in Paperboy

messages = {};  -- List of pairs of frame count and message
message_count = 0;
rng_8a = 0;
rng_8b = 0;
rng_call_count = 0;

FCEUX = emu['speedmode'] ~= nil;
fceux_save_states = {};  -- FCEUX Lua doesn't use slots like BizHawk does
BIZHAWK = emu['islagged'] ~= nil;

function main()
	--event.onmemoryexecute(rng_start_callback, 0x8151);
	--event.onmemoryexecute(rng_end_callback, 0x8177);
	--event.onmemoryexecute(rng_reset, 0x813E);

	normal_speed();
	clear_log();

	if FCEUX then
		emu.poweron()
		-- I don't think BizHawk lets you reset
	end

	max_speed();

	-- Give the game some time to reset the PPU, etc.
	for i=1,10 do
		every_frame();
		emu.frameadvance();
	end

	for week=1,5 do
		start_game();
		local week_frames = play_week();
		print(string.format('Week %d took %d frames', week, week_frames));
		wait_for_demo_to_finish();
	end

	while not is_paused() do
		every_frame();
		emu.frameadvance();
	end
end

function play_day()
	local CURRENT_DAY = read_byte(0xAF);
	-- We have to use 2 save slots in case we save right before hitting an
	-- obstacle
	local SAVE_SLOTS = {8, 9};
	local current_save_slot_index = 1;
	local save_frame_counts = {};
	local save_lag_frame_counts = {};
	local MAX_X = 220;
	local MIN_X = 10;
	local STEP_X = 20;
	local current_x = MAX_X;

	-- Wait for day to start, this is a countdown timer
	while read_byte(0x519) > 0 do
		every_frame();
		emu.frameadvance();
	end

	local day_frame_count = 0;
	local day_lag_frame_count = 0;

	-- Start by getting up to max speed
	-- We save a few frames by going fast before going left
	while get_speed() ~= 0xFF do
		set_joypad({up=true});
		every_frame();
		emu.frameadvance();
		day_frame_count = day_frame_count + 1;
		if is_lagged() then
			day_lag_frame_count = day_lag_frame_count + 1;
		end
	end

	set_x_position(current_x);

	-- We could look up each enemy type and position and then dodge the enemies
	-- manually, but save scumming is easier
	for _, slot in ipairs(SAVE_SLOTS) do
		save_state(slot);
		save_frame_counts[slot] = day_frame_count;
		save_lag_frame_counts[slot] = day_lag_frame_count;
	end

	local frame_count = 0;
	local crash_count = 0;
	while true do
		set_joypad({up=true});
		every_frame();
		emu.frameadvance();
		day_frame_count = day_frame_count + 1;
		if is_lagged() then
			day_lag_frame_count = day_lag_frame_count + 1;
		end

		-- Check if we have crashed by looking at crash timer
		if read_byte(0x519) > 0 then
			load_state(SAVE_SLOTS[current_save_slot_index]);
			day_frame_count = save_frame_counts[current_save_slot_index];
			day_lag_frame_count = save_lag_frame_counts[current_save_slot_index];
			frame_count = 0;
			current_x = current_x - STEP_X;
			if current_x < MIN_X then
				current_x = MAX_X;
			end
			set_x_position(current_x);
			crash_count = crash_count + 1;
			if crash_count > 100 then
				log_message('Unable to get past obstacle');
				load_state(SAVE_SLOTS[current_save_slot_index]);
				normal_speed();
				emu.pause();
				return;
			elseif crash_count % 20 == 0 then
				current_save_slot_index = current_save_slot_index % #SAVE_SLOTS + 1;
			end
		end

		-- Save scum every few seconds
		frame_count = frame_count + 1;
		if frame_count > 60 then
			frame_count = 0;
			current_save_slot_index = current_save_slot_index % #SAVE_SLOTS + 1;
			save_state(SAVE_SLOTS[current_save_slot_index]);
			save_frame_counts[current_save_slot_index] = day_frame_count;
			save_lag_frame_counts[current_save_slot_index] = day_lag_frame_count;
			crash_count = 0;
		end

		-- Are we at the end of the level yet?
		if read_byte(0xC0) > 22 then
			log_message(
				string.format(
					'Day %d took %d frames (%d lag)',
					CURRENT_DAY,
					day_frame_count,
					day_lag_frame_count));
			-- Set all the houses as delivered
			local HOUSE = 0x05B8;
			for i=0,20 do
				write_byte(HOUSE + i, 1);
			end
			return day_frame_count;
		end
	end
end

function play_week()
	local frame_count = 0;
	for day=1,7 do
		start_day();
		frame_count = frame_count + play_day();
		wait_for_subscriber_report_to_finish();
	end
	return frame_count;
end

function start_day()
	-- Wait for day of week black screen
	while read_byte(0) ~= 0x39 do
		every_frame();
		emu.frameadvance();
	end

	-- Wait for game to start
	while read_byte(0) ~= 0x20 do
		every_frame();
		emu.frameadvance();
	end
end

function start_game()
	-- Go to player count menu
	if read_byte(0) ~= 0x08 then
		set_joypad({start=true});
		for i=1,10 do
			every_frame();
			emu.frameadvance();
		end
	end

	-- Start game
	set_joypad({start=true});
	for i=1,10 do
		every_frame();
		emu.frameadvance();
	end
end

function wait_for_subscriber_report_to_finish()
	log_message('Waiting for subscriber report to finish');
	while read_byte(0xC0) ~= 2 do
		every_frame();
		emu.frameadvance();
	end
	log_message('Part 1');

	while read_byte(0xC0) ~= 1 do
		every_frame();
		emu.frameadvance();
	end
	log_message('Done waiting for subscriber report');
end

function wait_for_demo_to_finish()
	log_message('Waiting for demo to finish');
	while read_byte(0x20) ~= 0x20 do
		every_frame();
		emu.frameadvance();
	end

	while read_byte(0x20) ~= 0 do
		every_frame();
		emu.frameadvance();
	end
	log_message('Done waiting for demo to finish');
end

function every_frame()
	display_messages();
end

function add_message(message)
	-- The tornado causes a lot of calls to RNG, which each call add_message, so
	-- add a sane limit here
	local MAX_MESSAGE_COUNT = 10;
	if message_count < MAX_MESSAGE_COUNT then
		table.insert(messages, {emu.framecount() + 180, message});
		message_count = message_count + 1;
	elseif message_count == MAX_MESSAGE_COUNT then
		table.insert(messages, {emu.framecount() + 180, 'more...'});
		message_count = message_count + 1;
	end
end

function display_messages()
	-- First, delete expired messages
	-- This is an optimization; computing kept every time is really slow when
	-- there are a lot of messages, so check if we need to do anything first
	local need_to_remove = false;
	for _, pair in ipairs(messages) do
		local timeout = pair[1];
		if timeout <= emu.framecount() then
			need_to_remove = true;
			break;
		end
	end
	if need_to_remove then
		message_count = 0;
		local kept = {};
		for _, pair in ipairs(messages) do
			local timeout = pair[1];
			if timeout > emu.framecount() then
				table.insert(kept, pair);
				message_count = message_count + 1;
			end
		end
		messages = kept;
	end

	-- Show the messages
	local message_count = 0;
	for _, pair in ipairs(messages) do
		message = pair[2];
		if FCEUX then
			gui.text(0, message_count * 15 + 10, message);
		elseif BIZHAWK then
			gui.drawString(0, message_count * 15 + 10, message);
		end
		message_count = message_count + 1;
	end
end

function get_x_position()
	return read_byte(0x25);
end

function set_x_position(x_position)
	write_byte(0x25, x_position);
end

function get_speed()
	return read_byte(0xBA);
end

function rng_start_callback()
	rng_8a = read_byte(0x8a);
	rng_8b = read_byte(0x8b);
end

function rng_end_callback()
	-- Technically the RNG function returns the value in the A register, but
	-- the game saves it to 0x8C before returning, so reading 0x8C is the same
	rng_call_count = rng_call_count + 1;
	add_message(
		string.format(
			'%d 8a:%x 8b:%x ret:%x',
			rng_call_count,
			rng_8a,
			rng_8b,
			read_byte(0x8c)));
end

function rng_reset()
	rng_call_count = 0;
end

function max_speed()
	if FCEUX then
		emu.speedmode('maximum');
	elseif BIZHAWK then
		client.SetSoundOn(false);
		client.frameskip(5);
		client.speedmode(6399);  -- must be < 6400
	end
end

function normal_speed()
	if FCEUX then
		emu.speedmode('normal');
	elseif BIZHAWK then
		client.SetSoundOn(true);
		client.frameskip(0);
		client.speedmode(100);
	end
end

function is_lagged()
	if FCEUX then
		return emu.lagged();
	elseif BIZHAWK then
		return emu.islagged();
	end
end

function read_byte(address)
	if FCEUX then
		return memory.readbyte(address);
	elseif BIZHAWK then
		return mainmemory.read_u8(address);
	end
end

function write_byte(address, value)
	if FCEUX then
		return memory.writebyte(address, value);
	elseif BIZHAWK then
		return mainmemory.write_u8(address, value);
	end
end

function set_joypad(buttons)
	if FCEUX then
		local all_lower = {};
		for k, v in pairs(buttons) do
			all_lower[string.lower(k)] = v;
		end
		return joypad.set(1, all_lower);
	elseif BIZHAWK then
		-- Bizhawk requires each button to be capitalized
		local capitalized = {};
		for k, v in pairs(buttons) do
			local uppercase_key = string.gsub(
				string.lower(k),
				'^([a-z])',
				function(letter) return string.upper(letter); end);
			capitalized[uppercase_key] = v;
		end
		return joypad.set(capitalized, 1);
	end
end

function save_state(slot)
	if FCEUX then
		fceux_save_states[slot] = savestate.create();
		savestate.save(fceux_save_states[slot]);
	elseif BIZHAWK then
		return savestate.saveslot(slot);
	end
end

function load_state(slot)
	if FCEUX then
		savestate.load(fceux_save_states[slot]);
	elseif BIZHAWK then
		return savestate.loadslot(slot);
	end
end

function log_message(message)
	if FCEUX then
		emu.print(message);
	elseif BIZHAWK then
		console.log(message);
	end
end

function clear_log()
	if BIZHAWK then
		console.clear();
	end
end

function is_paused()
	if FCEUX then
		return emu.paused();
	elseif BIZHAWK then
		return client.ispaused();
	end
end


main();
