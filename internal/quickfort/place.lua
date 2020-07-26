-- place-related logic for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

require('dfhack.buildings') -- loads additional functions into dfhack.buildings
local quickfort_common = reqscript('internal/quickfort/common')
local log = quickfort_common.log

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

-- build desired extent maps from blueprint grid
local function init_stockpiles(grid, stockpiles)
    local invalid_keys = 0
    return invalid_keys
end

-- check bounds, adjust pos, width, height, and extent_grid
local function crop_to_bounds(stockpiles)
    local out_of_bounds_tiles = 0
    local stockpile_too_big_tiles = 0
    return out_of_bounds_tiles, stockpile_too_big_tiles
end

-- check tiles for validity, adjust extent_grid
local function mask_occupied_tiles(stockpiles)
    local occupied_tiles = 0
    return occupied_tiles
end

-- allocate and initialize stockpile extents structure from the extents_grid
local function make_extents(s)
    local area = s.width * s.height
    local extents = df.new('uint8_t', area)
    local num_tiles = 0
    for i=1,area do
        local is_in_stockpile = s.extent_grid[i%s.width][math.floor(i/s.height)]
        extents[i-1] = is_in_stockpile and 1 or 0
        if is_in_stockpile then num_tiles = num_tiles + 1 end
    end
    return extents, num_tiles
end

function do_run(zlevel, grid)
    local stats = {
        tiles_designated={label='Tiles designated', value=0, always=true},
        piles_designated={label='Stockpiles designated', value=0, always=true},
        occupied={label='Tiles skipped (tile occupied)', value=0},
        too_big={label='Tiles skipped (stockpile too large)', value=0},
        out_of_bounds={label='Tiles skipped (outside map boundary)', value=0},
        invalid_keys={label='Invalid key sequence', value=0},
    }

    -- data structure:
    --   [y][x] -> {type, cells, width, height, extent_grid}
    -- keys are target map coordinates
    -- type: letter from stockpile designation screen
    -- cells: list of source spreadsheet cell labels
    -- pos: xyz map coordinates
    -- width, height: number between 1 and 31
    -- extent_grid: [x][y] -> boolean where 1 <= x <= width and 1 <= y <= height
    local stockpiles = {}
    stats.invalid_keys.value = init_stockpiles(grid, stockpiles)
    stats.out_of_bounds.value, stats.too_big.value = crop_to_bounds(stockpiles)
    stats.occupied.value = mask_occupied_tiles(stockpiles)

    -- place stockpiles
    for y, row in pairs(stockpiles) do
        for x, s in pairs(row) do
            log('creating %s stockpile at map coordinates (%d, %d, %d),' ..
                ' defined in cells: %s',
                stockpile_types[s.type], s.pos.x, s.pos.y, s.pos.z, s.cells)
            local extents, ntiles = make_extents(s)
            local room = {x=s.pos.x, y=s.pos.y, width=s.width, height=s.height}
            local bld, err = dfhack.buildings.constructBuilding{
                type=df.building_type.Stockpile, abstract=true, pos=s.pos,
                width=s.width, height=s.height, fields={room=room}}
            if not bld then
                error(string.format('unable to place stockpile: %s', err))
            end
            -- constructBuilding deallocates extents, so we have to assign it
            -- after the call
            bld.room.extents=s.extents
            stats.tiles_designated.value = stats.tiles_designated.value + ntiles
            stats.piles_designated.value = stats.piles_designated.value + 1
        end
    end
    return stats
end

function do_orders(zlevel, grid)
    log('nothing to do for blueprints in mode: place')
    return nil
end

function do_undo(zlevel, grid)
    local stats = nil
    print('"quickfort undo" not yet implemented for mode: place')
    return stats
end
