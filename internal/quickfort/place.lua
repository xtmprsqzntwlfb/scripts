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
local quickfort_building = reqscript('internal/quickfort/building')
local log = quickfort_common.log

local function is_valid_stockpile_tile(pos)
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

local function is_valid_stockpile_extent(s)
    for extent_x, col in ipairs(s.extent_grid) do
        for extent_y, in_extent in ipairs(col) do
            if in_extent then return true end
        end
    end
    return false
end

local stockpile_db = {
    a={label='Animal'},
    f={label='Food'},
    u={label='Furniture'},
    n={label='Coins'},
    y={label='Corpses'},
    r={label='Refuse'},
    s={label='Stone'},
    w={label='Wood'},
    e={label='Gem'},
    b={label='Bar/Block'},
    h={label='Cloth'},
    l={label='Leather'},
    z={label='Ammo'},
    S={label='Sheets'},
    g={label='Finished Goods'},
    p={label='Weapons'},
    d={label='Armor'},
}
for _, v in pairs(stockpile_db) do
    v.has_extents = true
    v.min_width = 1
    v.max_width = 31
    v.min_height = 1
    v.max_height = 31
    v.is_valid_tile_fn = is_valid_stockpile_tile
    v.is_valid_extent_fn = is_valid_stockpile_extent
end

local function init_stockpile_settings(bld, type)
    print('stockpile settings initialization not yet implemented')
end

local function create_stockpile(s)
    log('creating %s stockpile at map coordinates (%d, %d, %d), defined' ..
        ' from spreadsheet cells: %s',
        stockpile_db[s.type].label, s.pos.x, s.pos.y, s.pos.z,
        table.concat(s.cells, ', '))
    local extents, ntiles = quickfort_building.make_extents(s, stockpile_db)
    local room = {x=s.pos.x, y=s.pos.y, width=s.width, height=s.height}
    local bld, err = dfhack.buildings.constructBuilding{
        type=df.building_type.Stockpile, abstract=true, pos=s.pos,
        width=s.width, height=s.height, fields={room=room}}
    if not bld then
        if extents then df.delete(extents) end
        -- this is an error instead of a qerror since our validity checking
        -- is supposed to prevent this from ever happening
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
        out_of_bounds={label='Tiles skipped (outside map boundary)', value=0},
        invalid_keys={label='Invalid key sequences', value=0},
    }

    local stockpiles = {}
    stats.invalid_keys.value = quickfort_building.init_buildings(
        zlevel, grid, stockpiles, stockpile_db)
    stats.out_of_bounds.value = quickfort_building.crop_to_bounds(
        stockpiles, stockpile_db)
    stats.occupied.value = quickfort_building.check_tiles_and_extents(
        stockpiles, stockpile_db)

    for _, s in ipairs(stockpiles) do
        if s.pos then
            local ntiles = create_stockpile(s)
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
    local stats = {
        piles_removed={label='Stockpiles removed', value=0, always=true},
        invalid_keys={label='Invalid key sequences', value=0},
    }

    local stockpiles = {}
    stats.invalid_keys.value = quickfort_building.init_buildings(
        zlevel, grid, stockpiles, stockpile_db)

    for _, s in ipairs(stockpiles) do
        for extent_x, col in ipairs(s.extent_grid) do
            for extent_y, in_extent in ipairs(col) do
                if not s.extent_grid[extent_x][extent_y] then goto continue end
                local pos =
                        xyz2pos(s.pos.x+extent_x-1, s.pos.y+extent_y-1, s.pos.z)
                local bld = dfhack.buildings.findAtTile(pos)
                if bld and bld:getType() == df.building_type.Stockpile then
                    dfhack.buildings.deconstruct(bld)
                    stats.piles_removed.value = stats.piles_removed.value + 1
                end
                ::continue::
            end
        end
    end
    return stats
end
