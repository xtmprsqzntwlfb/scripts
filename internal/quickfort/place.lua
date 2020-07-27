-- place-related logic for the quickfort script
--@ module = true
--[[
stockpiles data structure:
  list of {type, cells, pos, width, height, extent_grid}
- type: letter from stockpile designation screen
- cells: list of source spreadsheet cell labels (for debugging)
- pos: target map coordinates of upper left corner of extent (or nil if invalid)
- width, height: number between 1 and 31 (could be 0 if pos == nil)
- extent_grid: [x][y] -> boolean where 1 <= x <= width and 1 <= y <= height
]]

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

require('dfhack.buildings') -- loads additional functions into dfhack.buildings
local quickfort_common = reqscript('internal/quickfort/common')
local log = quickfort_common.log
local logfn = quickfort_common.logfn

local stockpile_types = {
    a='Animal',
    f='Food',
    u='Furniture',
    n='Coins',
    y='Corpses',
    r='Refuse',
    s='Stone',
    w='Wood',
    e='Gem',
    b='Bar/Block',
    h='Cloth',
    l='Leather',
    z='Ammo',
    S='Sheets',
    g='Finished Goods',
    p='Weapons',
    d='Armor',
}

-- maps stockpile boundaries, returns number of invalid keys seen
-- populates seen_grid coordinates with the stockpile id so we can build an
-- extent_grid later. spreadsheet cells that define extents (e.g. a(5x5)) create
-- stockpiles separate from adjacent cells, even if they have the same type.
local function flood_fill(grid, x, y, seen_grid, id, data)
    if seen_grid[x] and seen_grid[x][y] then return 0 end
    if not grid[y] or not grid[y][x] then return 0 end
    local cell, text = grid[y][x].cell, grid[y][x].text
    local keys, extent = quickfort_common.parse_cell(text)
    if not stockpile_types[keys] then
        if not seen_grid[x] then seen_grid[x] = {} end
        seen_grid[x][y] = true -- seen, but not part of any stockpile
        print(string.format('invalid key sequence in cell %s: "%s"',
                            cell, text))
        return 1
    end
    if data.type and (data.type ~= keys or extent.specified) then return 0 end
    log('mapping spreadsheet cell %s with text "%s"', cell, text)
    if not data.type then data.type = keys end
    table.insert(data.cells, cell)
    for target_x=x,x+extent.width-1 do
        for target_y=y,y+extent.height-1 do
            if not seen_grid[target_x] then seen_grid[target_x] = {} end
            -- this may overwrite another pile, but we'll remove empties later
            seen_grid[target_x][target_y] = id
            if target_x < data.x_min then data.x_min = target_x end
            if target_x > data.x_max then data.x_max = target_x end
            if target_y < data.y_min then data.y_min = target_y end
            if target_y > data.y_max then data.y_max = target_y end
        end
    end
    if not extent.specified then
        return flood_fill(grid, x-1, y, seen_grid, id, data) +
                flood_fill(grid, x+1, y, seen_grid, id, data) +
                flood_fill(grid, x, y-1, seen_grid, id, data) +
                flood_fill(grid, x, y+1, seen_grid, id, data)
    end
    return 0
end

-- returns nil if no tiles are actually set. this can happen when piles overlap
local function build_extent_grid(seen_grid, data, id)
    local extent_grid, has_tile = {}, false
    for x=data.x_min,data.x_max do
        local extent_x = x - data.x_min + 1
        extent_grid[extent_x] = {}
        for y=data.y_min,data.y_max do
            local extent_y = y - data.y_min + 1
            extent_grid[extent_x][extent_y] = seen_grid[x][y] == id
            has_tile = has_tile or extent_grid[extent_x][extent_y]
        end
    end
    return has_tile and extent_grid or nil
end

local function get_digit_count(num)
    local num_digits = 1
    while num >= 10 do
        num = num / 10
        num_digits = num_digits + 1
    end
    return num_digits
end

local function left_pad(num, width)
    local num_digit_count = get_digit_count(num)
    local ret = ''
    for i=num_digit_count,width do
        ret = ret .. ' '
    end
    return ret .. tostring(num)
end

-- pretty-prints the populated range of the seen_grid
local function dump_seen_grid(args)
    local seen_grid, max_id = args[1], args[2]
    local x_min, x_max, y_min, y_max = 30000, -30000, 30000, -30000
    for x, row in pairs(seen_grid) do
        if x < x_min then x_min = x end
        if x > x_max then x_max = x end
        for y, _ in pairs(row) do
            if y < y_min then y_min = y end
            if y > y_max then y_max = y end
        end
    end
    print('stockpile extent map:')
    local field_width = get_digit_count(max_id)
    local blank = string.rep(' ', field_width+1)
    for y=y_min,y_max do
        local line = ''
        for x=x_min,x_max do
            if seen_grid[x] and tonumber(seen_grid[x][y]) then
                line = line .. left_pad(seen_grid[x][y], field_width)
            else
                line = line .. blank
            end
        end
        print(line)
    end
end

-- build extent maps from blueprint grid input
local function init_stockpiles(zlevel, grid, stockpiles)
    local invalid_keys = 0
    local piles = {} -- list of stockpile data tables
    local seen_grid = {} -- [x][y] -> id
    for y, row in pairs(grid) do
        for x, cell_and_text in pairs(row) do
            if seen_grid[x] and seen_grid[x][y] then goto continue end
            local data = {
                type=nil, cells={},
                x_min=30000, x_max=-30000, y_min=30000, y_max=-30000
            }
            invalid_keys = invalid_keys +
                    flood_fill(grid, x, y, seen_grid, #piles+1, data)
            if data.type then table.insert(piles, data) end
            ::continue::
        end
    end
    for id, data in ipairs(piles) do
        local extent_grid = build_extent_grid(seen_grid, data, id)
        if extent_grid then
            table.insert(stockpiles,
                         {type=data.type,
                          cells=data.cells,
                          pos=xyz2pos(data.x_min, data.y_min, zlevel),
                          width=data.x_max-data.x_min+1,
                          height=data.y_max-data.y_min+1,
                          extent_grid=extent_grid})
        else
            log('all tiles are overwritten by other stockpiles for pile' ..
                ' defined from spreadsheet cells: %s',
                table.concat(data.cells, ', '))
        end
    end
    logfn(dump_seen_grid, seen_grid, #piles)
    return invalid_keys
end

local function is_on_map_x(x)
    return quickfort_common.is_within_map_bounds_x(x) or
            quickfort_common.is_on_map_edge_x(x)
end

local function is_on_map_y(y)
    return quickfort_common.is_within_map_bounds_y(y) or
            quickfort_common.is_on_map_edge_y(y)
end

local function is_on_map_xz(pos)
    return is_on_map_x(pos.x) and quickfort_common.is_within_map_bounds_z(pos.z)
end

local function is_on_map_yz(pos)
    return is_on_map_y(pos.y) and quickfort_common.is_within_map_bounds_z(pos.z)
end

-- check bounds against stockpile size limits and map edges, adjust pos, width,
-- height, and extent_grid accordingly
local function crop_to_bounds(stockpiles)
    local stockpile_too_big_tiles = 0
    local out_of_bounds_tiles = 0
    for _, s in ipairs(stockpiles) do
        if s.width > 31 or s.height > 31 then
            log('a single stockpile cannot extend beyond a 31x31 tile' ..
                ' square; cropping stockpile defined from spreadsheet cells %s',
                table.concat(s.cells, ', '))
        end
        -- if pos is off the map, crop and move pos until we're ok (or empty)
        while s.pos and s.width > 0 and not is_on_map_xz(s.pos) do
            for extent_y=1,s.height do
                if s.extent_grid[1][extent_y] then
                    out_of_bounds_tiles = out_of_bounds_tiles + 1
                end
            end
            -- change extent_grid to a linked list if this gets too slow
            table.remove(s.extent_grid, 1)
            s.width = s.width - 1
            s.pos.x = s.pos.x + 1
            if s.width == 0 then s.pos = nil end
        end
        while s.pos and s.height > 0 and not is_on_map_yz(s.pos) do
            for extent_x=1,s.width do
                if s.extent_grid[extent_x][1] then
                    out_of_bounds_tiles = out_of_bounds_tiles + 1
                end
                table.remove(s.extent_grid[extent_x], 1)
            end
            s.height = s.height - 1
            s.pos.y = s.pos.y + 1
            if s.height == 0 then s.pos = nil end
        end
        -- if stockpile is too big or off map to bottom or right, just crop
        while s.pos and
                (s.width > 31 or
                 (s.width > 0 and not is_on_map_x(s.pos.x+s.width-1))) do
            for extent_y=1,s.height do
                if s.extent_grid[s.width][extent_y] then
                    if s.width > 31 then
                        stockpile_too_big_tiles = stockpile_too_big_tiles + 1
                    else
                        out_of_bounds_tiles = out_of_bounds_tiles + 1
                    end
                end
            end
            s.extent_grid[s.width] = nil
            s.width = s.width - 1
            if s.width == 0 then s.pos = nil end
        end
        while s.pos and
                (s.height > 31 or
                 (s.height > 0 and not is_on_map_y(s.pos.y+s.height-1))) do
            for extent_x=1,s.width do
                if s.extent_grid[extent_x][s.height] then
                    if s.height > 31 then
                        stockpile_too_big_tiles = stockpile_too_big_tiles + 1
                    else
                        out_of_bounds_tiles = out_of_bounds_tiles + 1
                    end
                end
                s.extent_grid[extent_x][s.height] = nil
            end
            s.height = s.height - 1
            if s.height == 0 then s.pos = nil end
        end
        if not s.pos then
            log('stockpile completely off map, defined from spreadsheet' ..
                ' cells: %s', table.concat(s.cells, ', '))
        end
    end
    return stockpile_too_big_tiles, out_of_bounds_tiles
end

local function can_place_stockpile(pos)
    local flags, occupancy = dfhack.maps.getTileFlags(pos)
    if flags.hidden or occupancy.building ~= 0 then return false end
    local shape = df.tiletype.attrs[dfhack.maps.getTileType(pos)].shape
    return shape == df.tiletype_shape.FLOOR or
            shape == df.tiletype_shape.BOULDER or
            shape == df.tiletype_shape.PEBBLES or
            shape == df.tiletype_shape.STAIR_UP or
            shape == df.tiletype_shape.STAIR_DOWN or
            shape == df.tiletype_shape.STAIR_UPDOWN or
            shape == df.tiletype_shape.RAMP or
            shape == df.tiletype_shape.TWIG or
            shape == df.tiletype_shape.SAPLING or
            shape == df.tiletype_shape.SHRUB
end

-- check tiles for validity, adjust extent_grid
local function mask_occupied_tiles(stockpiles)
    local occupied_tiles = 0
    for _, s in ipairs(stockpiles) do
        for extent_x, col in ipairs(s.extent_grid) do
            for extent_y, in_extent in ipairs(col) do
                if not s.extent_grid[extent_x][extent_y] then goto continue end
                local pos =
                        xyz2pos(s.pos.x+extent_x-1, s.pos.y+extent_y-1, s.pos.z)
                if not can_place_stockpile(pos) then
                    log('tile occupied: (%d, %d, %d)', pos.x, pos.y, pos.z)
                    s.extent_grid[extent_x][extent_y] = false
                    occupied_tiles = occupied_tiles + 1
                end
                ::continue::
            end
        end
    end
    return occupied_tiles
end

-- allocate and initialize stockpile extents structure from the extents_grid
local function make_extents(s)
    local area = s.width * s.height
    local extents = df.new('uint8_t', area)
    local num_tiles = 0
    for i=1,area do
        local extent_x = (i-1) % s.width + 1
        local extent_y = math.floor((i-1) / s.width) + 1
        local is_in_stockpile = s.extent_grid[extent_x][extent_y]
        extents[i-1] = is_in_stockpile and 1 or 0
        if is_in_stockpile then num_tiles = num_tiles + 1 end
    end
    return extents, num_tiles
end

local function init_stockpile_settings(bld, type)
    print('TODO: initialize stockpile settings')
end

local function create_stockpile(s)
    log('creating %s stockpile at map coordinates (%d, %d, %d), defined' ..
        ' from spreadsheet cells: %s',
        stockpile_types[s.type], s.pos.x, s.pos.y, s.pos.z,
        table.concat(s.cells, ', '))
    local extents, ntiles = make_extents(s)
    if ntiles == 0 then
        log('no valid tiles; not creating stockpile')
        df.delete(extents)
        return 0
    end
    local room = {x=s.pos.x, y=s.pos.y, width=s.width, height=s.height}
    local bld, err = dfhack.buildings.constructBuilding{
        type=df.building_type.Stockpile, abstract=true, pos=s.pos,
        width=s.width, height=s.height, fields={room=room}}
    if not bld then
        error(string.format('unable to place stockpile: %s', err))
    end
    -- constructBuilding deallocates extents, so we have to assign it after
    bld.room.extents = extents
    init_stockpile_settings(bld, s.type)
    return ntiles
end

function do_run(zlevel, grid)
    local stats = {
        piles_designated={label='Stockpiles designated', value=0, always=true},
        tiles_designated={label='Tiles designated', value=0},
        occupied={label='Tiles skipped (tile occupied)', value=0},
        too_big={label='Tiles skipped (stockpile too large)', value=0},
        out_of_bounds={label='Tiles skipped (outside map boundary)', value=0},
        invalid_keys={label='Invalid key sequences', value=0},
    }

    local stockpiles = {}
    stats.invalid_keys.value = init_stockpiles(zlevel, grid, stockpiles)
    stats.too_big.value, stats.out_of_bounds.value = crop_to_bounds(stockpiles)
    stats.occupied.value = mask_occupied_tiles(stockpiles)

    for _, s in ipairs(stockpiles) do
        if s.pos then
            local ntiles = create_stockpile(s)
            stats.tiles_designated.value = stats.tiles_designated.value + ntiles
            if ntiles > 0 then
                stats.piles_designated.value = stats.piles_designated.value + 1
            end
        end
    end
    return stats
end

function do_orders(zlevel, grid)
    log('nothing to do for blueprints in mode: place')
    return nil
end

function do_undo(zlevel, grid)
    local stats = {
        piles_removed={label='Stockpiles removed', value=0, always=true},
        invalid_keys={label='Invalid key sequences', value=0},
    }

    local stockpiles = {}
    stats.invalid_keys.value = init_stockpiles(zlevel, grid, stockpiles)

    for _, s in ipairs(stockpiles) do
        for extent_x, col in ipairs(s.extent_grid) do
            for extent_y, in_extent in ipairs(col) do
                if not s.extent_grid[extent_x][extent_y] then goto continue end
                local pos =
                        xyz2pos(s.pos.x+extent_x-1, s.pos.y+extent_y-1, s.pos.z)
                local bld = dfhack.buildings.findAtTile(pos)
                if bld and
                        bld.stockpile_number and bld.stockpile_number > 0 then
                    dfhack.buildings.deconstruct(bld)
                    stats.piles_removed.value = stats.piles_removed.value + 1
                end
                ::continue::
            end
        end
    end
    return stats
end
