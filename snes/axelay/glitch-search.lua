-- After you select your weapon loadout, the game plays a short sound clip that
-- says "Arms installation is complete. Good luck." However, very rarely, the
-- clip is cut short, and it sounds like it says "Arms install-ood luck." I've
-- seen it happen once on console and twice on emulator, but I've never seen it
-- while recording. This is an attempt to try to recreate it - unsuccessful so
-- far.
function main()
	console.clear();
	client.speedmode(1600);

	local all_counts = {};
	for i=1,10000 do
		savestate.loadslot(0);
		for j=1,i do
			emu.frameadvance();
		end
		joypad.set({Start=true}, 1);
		emu.frameadvance();
		joypad.set({}, 1);

		local count = 0;
		while mainmemory.read_u8(0) ~= 0xF0 do
			count = count + 1;
			emu.frameadvance();
		end

		if count ~= 146 then
			console.log(string.format('%d took %d frames!', i, count));
		end

		if all_counts[count] == nil then
			all_counts[count] = 1;
		else
			all_counts[count] = all_counts[count] + 1;
		end
	end

	console.log(all_counts);
end

main()
