-- Search for hidden sound menu
id = nil;

function main()
	id = event.onmemorywrite(log_registers, 0xE00);
	id2 = event.onmemoryread(function () log_registers(); end, 0xF798A);
	console.log(id);
	count = 0;
	while id ~= nil do
		emu.frameadvance();
		count = count + 1;
		if count % 60 == 0 then
			console.log(mainmemory.read_u8(0xE00));
		end
	end
end

function log_registers()
	console.log('log_registers');
	console.log(emu.getregisters());
	event.unregisterbyid(id);
	id = nil;
end

main()
