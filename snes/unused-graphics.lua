-- Tracks VRAM tile graphics that are loaded but never displayed,
-- and saves them to disk when they are overwritten.

prev_vram = {}
unconfirmed_tiles = {}  -- [vram_byte_offset] = {data={}, bpp=N, frame=N}
confirmed_tiles   = {}  -- [vram_byte_offset] = true
save_counter      = 0

function init()
    memory.usememorydomain("VRAM")
    prev_vram = memory.read_bytes_as_array(0, 65536)
    unconfirmed_tiles = {}
    confirmed_tiles   = {}
    save_counter      = 0
    console.log("unused-graphics: initialized, VRAM snapshot taken")
end

-- Returns a table of all current PPU layout registers.
-- Switches to System Bus domain to read, then back to VRAM.
function read_ppu_registers()
    memory.usememorydomain("System Bus")

    local bgmode = memory.read_u8(0x2105)
    local obsel  = memory.read_u8(0x2101)
    local bg1sc  = memory.read_u8(0x2107)
    local bg2sc  = memory.read_u8(0x2108)
    local bg3sc  = memory.read_u8(0x2109)
    local bg4sc  = memory.read_u8(0x210A)
    local nba12  = memory.read_u8(0x210B)
    local nba34  = memory.read_u8(0x210C)

    -- BGxSC: bits 7-2 = tilemap base in 2KB steps; bits 1-0 = map size
    local function parse_bgsc(reg)
        local base  = bit.band(bit.lshift(bit.rshift(reg, 2), 11), 0xFFFF)
        local map_w = (bit.band(reg, 0x01) ~= 0) and 64 or 32
        local map_h = (bit.band(reg, 0x02) ~= 0) and 64 or 32
        return base, map_w, map_h
    end

    local bg1_map_base, bg1_map_w, bg1_map_h = parse_bgsc(bg1sc)
    local bg2_map_base, bg2_map_w, bg2_map_h = parse_bgsc(bg2sc)
    local bg3_map_base, bg3_map_w, bg3_map_h = parse_bgsc(bg3sc)
    local bg4_map_base, bg4_map_w, bg4_map_h = parse_bgsc(bg4sc)

    local ppu = {
        bg_mode         = bit.band(bgmode, 0x07),
        bg3_priority    = bit.band(bit.rshift(bgmode, 3), 0x01),
        bg1_large_tiles = bit.band(bit.rshift(bgmode, 4), 0x01),
        bg2_large_tiles = bit.band(bit.rshift(bgmode, 5), 0x01),
        bg3_large_tiles = bit.band(bit.rshift(bgmode, 6), 0x01),
        bg4_large_tiles = bit.band(bit.rshift(bgmode, 7), 0x01),

        obsel              = obsel,
        -- Sprite name base: bits 2-0 in 8KB steps (byte offset)
        sprite_base        = bit.band(bit.lshift(bit.band(obsel, 0x07), 13), 0xFFFF),
        -- Second name table byte offset from sprite_base: (namesel+1) * 4096
        sprite_name_select = bit.band(bit.rshift(obsel, 3), 0x03),
        sprite_size_sel    = bit.band(bit.rshift(obsel, 5), 0x07),

        bg1_map_base = bg1_map_base, bg1_map_w = bg1_map_w, bg1_map_h = bg1_map_h,
        bg2_map_base = bg2_map_base, bg2_map_w = bg2_map_w, bg2_map_h = bg2_map_h,
        bg3_map_base = bg3_map_base, bg3_map_w = bg3_map_w, bg3_map_h = bg3_map_h,
        bg4_map_base = bg4_map_base, bg4_map_w = bg4_map_w, bg4_map_h = bg4_map_h,

        -- BG12NBA/BG34NBA: each nibble = tile base in 4KB steps
        bg1_tile_base = bit.lshift(bit.band(nba12, 0x0F), 12),
        bg2_tile_base = bit.lshift(bit.band(bit.rshift(nba12, 4), 0x0F), 12),
        bg3_tile_base = bit.lshift(bit.band(nba34, 0x0F), 12),
        bg4_tile_base = bit.lshift(bit.band(bit.rshift(nba34, 4), 0x0F), 12),

        -- 8-bit approximation of scroll (full 10-bit value needs two-write tracking)
        bg1_hscroll = memory.read_u8(0x210D),
        bg1_vscroll = memory.read_u8(0x210E),
        bg2_hscroll = memory.read_u8(0x210F),
        bg2_vscroll = memory.read_u8(0x2110),
        bg3_hscroll = memory.read_u8(0x2111),
        bg3_vscroll = memory.read_u8(0x2112),
        bg4_hscroll = memory.read_u8(0x2113),
        bg4_vscroll = memory.read_u8(0x2114),
    }

    memory.usememorydomain("VRAM")
    return ppu
end

-- Returns a list of {base, len} VRAM byte ranges used by BG tilemaps.
-- Multi-screen tilemaps produce one entry per 32x32 sub-screen.
function get_tilemap_regions(ppu)
    local regions = {}

    local function add_bg(map_base, map_w, map_h)
        local screens_h = math.floor(map_w / 32)  -- 1 or 2
        local screens_v = math.floor(map_h / 32)  -- 1 or 2
        for sv = 0, screens_v - 1 do
            for sh = 0, screens_h - 1 do
                local idx  = sv * screens_h + sh
                local base = bit.band(map_base + idx * 0x800, 0xFFFF)
                table.insert(regions, {base = base, len = 0x800})
            end
        end
    end

    add_bg(ppu.bg1_map_base, ppu.bg1_map_w, ppu.bg1_map_h)
    add_bg(ppu.bg2_map_base, ppu.bg2_map_w, ppu.bg2_map_h)
    add_bg(ppu.bg3_map_base, ppu.bg3_map_w, ppu.bg3_map_h)
    add_bg(ppu.bg4_map_base, ppu.bg4_map_w, ppu.bg4_map_h)

    return regions
end

-- ── Verification logging ──────────────────────────────────────────────────────

local last_log_frame = -300

local function log_ppu_state(ppu)
    console.log(string.format(
        "[frame %d] bg_mode=%d  sprite_base=0x%04X size_sel=%d",
        emu.framecount(), ppu.bg_mode, ppu.sprite_base, ppu.sprite_size_sel))
    console.log(string.format(
        "  BG1: tile=0x%04X  map=0x%04X (%dx%d)  large=%d  scroll=(%d,%d)",
        ppu.bg1_tile_base, ppu.bg1_map_base, ppu.bg1_map_w, ppu.bg1_map_h,
        ppu.bg1_large_tiles, ppu.bg1_hscroll, ppu.bg1_vscroll))
    console.log(string.format(
        "  BG2: tile=0x%04X  map=0x%04X (%dx%d)  large=%d  scroll=(%d,%d)",
        ppu.bg2_tile_base, ppu.bg2_map_base, ppu.bg2_map_w, ppu.bg2_map_h,
        ppu.bg2_large_tiles, ppu.bg2_hscroll, ppu.bg2_vscroll))
    console.log(string.format(
        "  BG3: tile=0x%04X  map=0x%04X (%dx%d)  large=%d",
        ppu.bg3_tile_base, ppu.bg3_map_base, ppu.bg3_map_w, ppu.bg3_map_h,
        ppu.bg3_large_tiles))
    console.log(string.format(
        "  BG4: tile=0x%04X  map=0x%04X (%dx%d)  large=%d",
        ppu.bg4_tile_base, ppu.bg4_map_base, ppu.bg4_map_w, ppu.bg4_map_h,
        ppu.bg4_large_tiles))

    local regions = get_tilemap_regions(ppu)
    for i, r in ipairs(regions) do
        console.log(string.format(
            "  tilemap region %d: 0x%04X-0x%04X (%d bytes)",
            i, r.base, r.base + r.len - 1, r.len))
    end
end

-- ── Main loop ─────────────────────────────────────────────────────────────────

init()

while true do
    local ppu = read_ppu_registers()

    -- Log PPU state every 5 seconds for verification (steps 1-3 only)
    if emu.framecount() - last_log_frame >= 300 then
        last_log_frame = emu.framecount()
        if ppu.bg_mode ~= 7 then
            log_ppu_state(ppu)
        else
            console.log(string.format("[frame %d] Mode 7 — skipping", emu.framecount()))
        end
    end

    emu.frameadvance()
end
