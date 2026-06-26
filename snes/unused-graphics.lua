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

-- ── Step 4: bpp_for_bg ────────────────────────────────────────────────────────

-- bpp per BG layer indexed by [mode][bg_index]; 0 = layer not active in mode
local BPP_PER_MODE = {
    [0] = {2, 2, 2, 2},
    [1] = {4, 4, 2, 0},
    [2] = {4, 4, 0, 0},
    [3] = {8, 4, 0, 0},
    [4] = {8, 2, 0, 0},
    [5] = {4, 2, 0, 0},
    [6] = {4, 0, 0, 0},
}

function bpp_for_bg(ppu, bg_index)
    local t = BPP_PER_MODE[ppu.bg_mode]
    if t == nil then return 0 end
    return t[bg_index] or 0
end

-- Returns per-BG attribute sub-table for BG index 1-4
local function bg_info(ppu, n)
    if n == 1 then return {
        tile_base=ppu.bg1_tile_base, map_base=ppu.bg1_map_base,
        map_w=ppu.bg1_map_w, map_h=ppu.bg1_map_h,
        hscroll=ppu.bg1_hscroll, vscroll=ppu.bg1_vscroll,
        large_tiles=ppu.bg1_large_tiles, bpp=bpp_for_bg(ppu,1),
    } elseif n == 2 then return {
        tile_base=ppu.bg2_tile_base, map_base=ppu.bg2_map_base,
        map_w=ppu.bg2_map_w, map_h=ppu.bg2_map_h,
        hscroll=ppu.bg2_hscroll, vscroll=ppu.bg2_vscroll,
        large_tiles=ppu.bg2_large_tiles, bpp=bpp_for_bg(ppu,2),
    } elseif n == 3 then return {
        tile_base=ppu.bg3_tile_base, map_base=ppu.bg3_map_base,
        map_w=ppu.bg3_map_w, map_h=ppu.bg3_map_h,
        hscroll=ppu.bg3_hscroll, vscroll=ppu.bg3_vscroll,
        large_tiles=ppu.bg3_large_tiles, bpp=bpp_for_bg(ppu,3),
    } else return {
        tile_base=ppu.bg4_tile_base, map_base=ppu.bg4_map_base,
        map_w=ppu.bg4_map_w, map_h=ppu.bg4_map_h,
        hscroll=ppu.bg4_hscroll, vscroll=ppu.bg4_vscroll,
        large_tiles=ppu.bg4_large_tiles, bpp=bpp_for_bg(ppu,4),
    } end
end

-- ── Step 8: mark_confirmed ────────────────────────────────────────────────────

function mark_confirmed(vram_offset)
    unconfirmed_tiles[vram_offset] = nil
    confirmed_tiles[vram_offset]   = true
end

-- ── Step 10: decode_tile ─────────────────────────────────────────────────────
-- Returns a 1-indexed array of 64 palette indices (8 rows × 8 cols, row-major).
-- data is 0-indexed (as stored in entry.data); bpp is 2, 4, or 8.

function decode_tile(data, bpp)
    local pixels = {}
    -- Bitplane pairs: 2bpp has 1 pair, 4bpp has 2, 8bpp has 4.
    -- Each pair is 16 bytes (8 rows × 2 bytes). Pairs are at offsets 0, 16, 32, 48.
    for row = 0, 7 do
        for col = 0, 7 do
            local bit_pos = 7 - col  -- MSB = leftmost pixel
            local index   = 0

            local num_pairs = bpp / 2
            for pair = 0, num_pairs - 1 do
                local pair_base = pair * 16 + row * 2
                local bp_lo = data[pair_base + 0] or 0
                local bp_hi = data[pair_base + 1] or 0
                local b0 = bit.band(bit.rshift(bp_lo, bit_pos), 1)
                local b1 = bit.band(bit.rshift(bp_hi, bit_pos), 1)
                index = index + bit.lshift(b0, pair * 2) + bit.lshift(b1, pair * 2 + 1)
            end

            pixels[row * 8 + col + 1] = index  -- 1-indexed output
        end
    end
    return pixels
end

-- ── Step 11: write_bmp ───────────────────────────────────────────────────────
-- Writes an 8×8, 8bpp indexed BMP.
-- pixels: 1-indexed array of 64 palette indices.
-- cgram:  0-indexed 512-byte CGRAM array (256 × 15-bit BGR words, little-endian).

function write_bmp(pixels, cgram, filename)
    local function le32(n)
        return string.char(
            bit.band(n,                0xFF),
            bit.band(bit.rshift(n,  8), 0xFF),
            bit.band(bit.rshift(n, 16), 0xFF),
            bit.band(bit.rshift(n, 24), 0xFF))
    end
    local function le16(n)
        return string.char(
            bit.band(n,               0xFF),
            bit.band(bit.rshift(n, 8), 0xFF))
    end

    local pixel_offset = 14 + 40 + 256 * 4  -- 1078
    local file_size    = pixel_offset + 64   -- 1142

    local f = io.open(filename, 'wb')
    if f == nil then
        console.log("write_bmp: could not open " .. filename)
        return
    end

    -- File header (14 bytes)
    f:write('BM')
    f:write(le32(file_size))
    f:write(le16(0))          -- reserved
    f:write(le16(0))          -- reserved
    f:write(le32(pixel_offset))

    -- DIB header (40 bytes)
    f:write(le32(40))         -- header size
    f:write(le32(8))          -- width
    f:write(le32(-8))         -- height: negative = top-down
    f:write(le16(1))          -- color planes
    f:write(le16(8))          -- bits per pixel
    f:write(le32(0))          -- compression: none
    f:write(le32(64))         -- image data size
    f:write(le32(2835))       -- X pixels/meter (~72 DPI)
    f:write(le32(2835))       -- Y pixels/meter
    f:write(le32(256))        -- colors in table
    f:write(le32(0))          -- important colors

    -- Color table (256 × 4 bytes, BGRA)
    for i = 0, 255 do
        local lo   = cgram[i * 2]     or 0
        local hi   = cgram[i * 2 + 1] or 0
        local word = lo + hi * 256
        -- SNES 15-bit: bits 4-0=R, 9-5=G, 14-10=B; expand 5-bit to 8-bit with << 3
        local r = bit.lshift(bit.band(word,                0x1F), 3)
        local g = bit.lshift(bit.band(bit.rshift(word,  5), 0x1F), 3)
        local b = bit.lshift(bit.band(bit.rshift(word, 10), 0x1F), 3)
        f:write(string.char(b, g, r, 0))  -- BGRA
    end

    -- Pixel data (64 bytes, 8 rows × 8 cols)
    for i = 1, 64 do
        f:write(string.char(pixels[i] or 0))
    end

    f:close()
end

-- ── Step 9: save_unconfirmed_tile ────────────────────────────────────────────

function save_unconfirmed_tile(vram_offset)
    local entry = unconfirmed_tiles[vram_offset]
    if entry == nil or confirmed_tiles[vram_offset] then
        unconfirmed_tiles[vram_offset] = nil
        return
    end

    local pixels = decode_tile(entry.data, entry.bpp)

    memory.usememorydomain("CGRAM")
    local cgram = memory.read_bytes_as_array(0, 512)
    memory.usememorydomain("VRAM")

    local filename = string.format('unused_%04d_f%06d.bmp', save_counter, entry.frame)
    write_bmp(pixels, cgram, filename)
    console.log(string.format(
        "saved %s  (tile 0x%04X, bpp=%d)", filename, vram_offset, entry.bpp))

    unconfirmed_tiles[vram_offset] = nil
    save_counter = save_counter + 1
end

-- ── Step 5: detect_vram_changes ───────────────────────────────────────────────

function detect_vram_changes(curr_vram, ppu)
    local tilemap_regions = get_tilemap_regions(ppu)

    local function in_tilemap(offset)
        for _, r in ipairs(tilemap_regions) do
            if offset >= r.base and offset < r.base + r.len then return true end
        end
        return false
    end

    -- Build scan regions: each has {base, tile_bytes, count}
    local scan_regions = {}

    -- Sprite name table 1: 256 tiles × 32 bytes
    table.insert(scan_regions, {base=ppu.sprite_base, tile_bytes=32, count=256})

    -- Sprite name table 2 when name_select != 0: also 256 tiles × 32 bytes
    if ppu.sprite_name_select > 0 then
        local ns2 = bit.band(
            ppu.sprite_base + bit.lshift(ppu.sprite_name_select + 1, 12),
            0xFFFF)
        table.insert(scan_regions, {base=ns2, tile_bytes=32, count=256})
    end

    -- BG tile regions: scan up to 512 tiles each (conservative upper bound)
    for n = 1, 4 do
        local bpp = bpp_for_bg(ppu, n)
        if bpp > 0 then
            local tile_base = bg_info(ppu, n).tile_base
            table.insert(scan_regions, {
                base       = tile_base,
                tile_bytes = bpp * 8,
                count      = 512,
            })
        end
    end

    local processed = {}

    for _, region in ipairs(scan_regions) do
        for t = 0, region.count - 1 do
            local tile_off = bit.band(region.base + t * region.tile_bytes, 0xFFFF)

            if not processed[tile_off] and not in_tilemap(tile_off) then
                processed[tile_off] = true

                local changed     = false
                local any_nonzero = false
                for b = 0, region.tile_bytes - 1 do
                    local idx = bit.band(tile_off + b, 0xFFFF)
                    local cb  = curr_vram[idx]
                    if cb ~= prev_vram[idx] then changed = true end
                    if cb ~= 0             then any_nonzero = true end
                    if changed and any_nonzero then break end
                end

                if changed then
                    if unconfirmed_tiles[tile_off] then
                        save_unconfirmed_tile(tile_off)
                    end
                    if any_nonzero then
                        local data = {}
                        for b = 0, region.tile_bytes - 1 do
                            data[b] = curr_vram[bit.band(tile_off + b, 0xFFFF)]
                        end
                        unconfirmed_tiles[tile_off] = {
                            data  = data,
                            bpp   = region.tile_bytes / 8,
                            frame = emu.framecount(),
                        }
                    end
                end
            end
        end
    end
end

-- ── Step 6: check_bg_visibility ───────────────────────────────────────────────

-- How many BG layers are active per mode (1-indexed BG numbers)
local ACTIVE_BGS_PER_MODE = {
    [0]={1,2,3,4}, [1]={1,2,3}, [2]={1,2},
    [3]={1,2},     [4]={1,2},   [5]={1,2}, [6]={1},
}

function check_bg_visibility(curr_vram, ppu)
    local active = ACTIVE_BGS_PER_MODE[ppu.bg_mode]
    if active == nil then return end

    for _, n in ipairs(active) do
        local bg         = bg_info(ppu, n)
        local tile_bytes = bg.bpp * 8
        local tile_px    = (bg.large_tiles ~= 0) and 16 or 8

        -- Which tilemap columns/rows are currently in the 256×224 viewport
        local first_col = math.floor(bg.hscroll / tile_px) % bg.map_w
        local first_row = math.floor(bg.vscroll / tile_px) % bg.map_h
        local num_cols  = math.ceil(256 / tile_px) + 1
        local num_rows  = math.ceil(224 / tile_px) + 1
        local screens_h = math.floor(bg.map_w / 32)

        for r = 0, num_rows - 1 do
            for c = 0, num_cols - 1 do
                local col = (first_col + c) % bg.map_w
                local row = (first_row + r) % bg.map_h

                -- Map (col,row) to VRAM address, accounting for sub-screens
                local scr_c    = math.floor(col / 32)
                local scr_r    = math.floor(row / 32)
                local scr_idx  = scr_r * screens_h + scr_c
                local loc_col  = col % 32
                local loc_row  = row % 32
                local entry_off = bit.band(
                    bg.map_base + scr_idx * 0x800 + (loc_row * 32 + loc_col) * 2,
                    0xFFFF)

                local lo         = curr_vram[entry_off]
                local hi         = curr_vram[bit.band(entry_off + 1, 0xFFFF)]
                local entry_word = lo + hi * 256
                local tile_index = bit.band(entry_word, 0x3FF)
                local tile_off   = bg.tile_base + tile_index * tile_bytes

                if bg.large_tiles ~= 0 then
                    -- 16×16 tile: top-left, top-right, bottom-left, bottom-right
                    -- in VRAM the "next row" is 16 tiles down the tile sheet
                    mark_confirmed(tile_off)
                    mark_confirmed(tile_off + tile_bytes)
                    mark_confirmed(tile_off + tile_bytes * 16)
                    mark_confirmed(tile_off + tile_bytes * 17)
                else
                    mark_confirmed(tile_off)
                end
            end
        end
    end
end

-- ── Step 7: check_sprite_visibility ──────────────────────────────────────────

-- {small, large} pixel dimensions indexed by sprite_size_sel
local SPRITE_SIZES = {
    [0]={{8,8},{16,16}}, [1]={{8,8},{32,32}}, [2]={{8,8},{64,64}},
    [3]={{16,16},{32,32}}, [4]={{16,16},{64,64}}, [5]={{32,32},{64,64}},
}

function check_sprite_visibility(ppu)
    memory.usememorydomain("OAM")
    local oam = memory.read_bytes_as_array(0, 544)
    memory.usememorydomain("VRAM")

    local size_pair = SPRITE_SIZES[ppu.sprite_size_sel] or SPRITE_SIZES[0]
    local sprite_name2_base = bit.band(
        ppu.sprite_base + bit.lshift(ppu.sprite_name_select + 1, 12),
        0xFFFF)

    for i = 0, 127 do
        local base4 = i * 4
        local b0 = oam[base4 + 0]  -- X low 8 bits
        local b1 = oam[base4 + 1]  -- Y
        local b2 = oam[base4 + 2]  -- tile number (0-255 within name table)
        local b3 = oam[base4 + 3]  -- vhpp pppN (N = name table select)

        local extra     = oam[512 + math.floor(i / 4)]
        local bit_shift = (i % 4) * 2
        local x_high    = bit.band(bit.rshift(extra, bit_shift),     0x01)
        local size_sel  = bit.band(bit.rshift(extra, bit_shift + 1), 0x01)

        local x = b0 + x_high * 256
        if x > 255 then x = x - 512 end
        local y = b1

        local dim = size_pair[size_sel + 1]
        local w, h = dim[1], dim[2]

        -- Hidden when y >= 240; skip if fully off the 256×224 screen
        if y < 240 and x + w > 0 and x < 256 and y < 224 then
            local nt_bit     = bit.band(b3, 0x01)
            local name_base  = (nt_bit == 0) and ppu.sprite_base or sprite_name2_base
            local tile_vram  = bit.band(name_base + b2 * 32, 0xFFFF)

            -- Mark every 8×8 sub-tile; sprite grid is 16 tiles wide (512 bytes/row)
            local sub_cols = math.floor(w / 8)
            local sub_rows = math.floor(h / 8)
            for dr = 0, sub_rows - 1 do
                for dc = 0, sub_cols - 1 do
                    local sub_off = bit.band(tile_vram + dc * 32 + dr * 512, 0xFFFF)
                    mark_confirmed(sub_off)
                end
            end
        end
    end
end

-- ── Step 12: draw_hud ────────────────────────────────────────────────────────

local function count_table(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function draw_hud()
    gui.drawString(0, 0, string.format(
        'Unconfirmed: %d  Saved: %d',
        count_table(unconfirmed_tiles), save_counter))
end

-- ── Step 13: main loop ────────────────────────────────────────────────────────

init()

while true do
    local ppu = read_ppu_registers()

    if ppu.bg_mode ~= 7 then
        local curr_vram = memory.read_bytes_as_array(0, 65536)

        detect_vram_changes(curr_vram, ppu)
        check_bg_visibility(curr_vram, ppu)
        check_sprite_visibility(ppu)

        prev_vram = curr_vram
    end

    draw_hud()
    emu.frameadvance()
end
