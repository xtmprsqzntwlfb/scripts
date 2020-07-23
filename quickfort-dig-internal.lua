-- dig-related logic for the quickfort script
--[[
In general, this file designates tiles with the same rules as the in-game UI.
For example, if the tile is hidden, we designate blindly to avoid spoilers. If
it's visible, the shape and material of the target tile affects whether the
designation has any effect.
]]

local _ENV = mkmodule('hack.scripts.quickfort-dig-internal')

local quickfort_common = require('hack.scripts.quickfort-common-internal')
local log = quickfort_common.log

local function is_construction(tileattrs)
    return tileattrs.material == df.tiletype_material.CONSTRUCTION
end

local function is_floor(tileattrs)
    return tileattrs.shape == df.tiletype_shape.FLOOR or
            tileattrs.shape == df.tiletype_shape.BOULDER or
            tileattrs.shape == df.tiletype_shape.PEBBLES
end

local function is_wall(tileattrs)
    return tileattrs.shape == df.tiletype_shape.WALL
end

local function is_up_stair(tileattrs)
    return tileattrs.shape == df.tiletype_shape.STAIR_UP
end

local function is_removable_shape(tileattrs)
    return tileattrs.shape == df.tiletype_shape.RAMP or
            tileattrs.shape == df.tiletype_shape.STAIR_UP or
            tileattrs.shape == df.tiletype_shape.STAIR_UPDOWN
end

local function is_gatherable(tileattrs)
    return tileattrs.shape == df.tiletype_shape.SHRUB
end

local hard_natural_materials = utils.invert({
    df.tiletype_material.STONE,
    df.tiletype_material.FEATURE,
    df.tiletype_material.LAVA_STONE,
    df.tiletype_material.MINERAL,
    df.tiletype_material.FROZEN_LIQUID,
})

local function is_smoothable_material(tileattrs)
    return hard_natural_materials[tileattrs.material]
end

-- these functions return whether a designation was made
local function do_mine(flags, _, tileattrs)
    if not flags.hidden then
        if is_construction(tileattrs) or not is_wall(tileattrs) then
            return false
        end
    end
    flags.dig = df.tile_dig_designation.Default
    return true
end

local function do_channel(flags, _, tileattrs)
    if not flags.hidden then
        if is_construction(tileattrs) or
                (not is_wall(tileattrs) and not is_floor(tileattrs)) then
            return false
        end
    end
    flags.dig = df.tile_dig_designation.Channel
    return true
end

local function do_up_stair(flags, _, tileattrs)
    if not flags.hidden then
        if is_construction(tileattrs) or not is_wall(tileattrs) then
            return false
        end
    end
    flags.dig = df.tile_dig_designation.UpStair
    return true
end

local function do_down_stair(flags, _, tileattrs)
    if not flags.hidden then
        if is_construction(tileattrs) or
                (not is_wall(tileattrs) and not is_floor(tileattrs)) then
            return false
        end
    end
    flags.dig = df.tile_dig_designation.DownStair
    return true
end

local function do_up_down_stair(flags, _, tileattrs)
    if not flags.hidden then
        if is_construction(tileattrs) or
                (not is_wall(tileattrs) and not is_up_stair(tileattrs)) then
            return false
        end
    end
    if is_up_stair(tileattrs) then
        flags.dig = df.tile_dig_designation.DownStair
    else
        flags.dig = df.tile_dig_designation.UpDownStair
    end
    return true
end

local function do_ramp(flags, _, tileattrs)
    if not flags.hidden then
        if is_construction(tileattrs) or not is_wall(tileattrs) then
            return false
        end
    end
    flags.dig = df.tile_dig_designation.Ramp
    return true
end

local function do_remove_ramps(flags, _, tileattrs)
    if flags.hidden then return false end
    if is_construction(tileattrs) or not is_removable_shape(tileattrs) then
        return false
    end
    flags.dig = df.tile_dig_designation.Default
    return true
end

local function do_gather(flags, _, tileattrs)
    if flags.hidden then return false end
    if not is_gatherable(tileattrs) then return false end
    flags.dig = df.tile_dig_designation.Default
    return true
end

local function do_smooth(flags, _, tileattrs)
    if flags.hidden then return false end
    if is_construction(tileattrs) or
            (not is_floor(tileattrs) and not is_wall(tileattrs)) or
            not is_smoothable_material(tileattrs)) then
        return false
    end
    flags.smooth = 1
    return true
end

local function do_engrave(flags, _, tileattrs)
    if flags.hidden or
            is_construction(tileattrs) or not is_smooth(tileattrs) then
        return false
    end
    flags.smooth = 2
    return true
end

local function do_fortification(flags, _, tileattrs)
    if flags.hidden then return false end
    if not is_wall(tileattrs) or not is_smooth(tileattrs) then return false end
    flags.smooth = 1
    return true
end

local function do_remove_designation(flags, _, tileattrs)
    if flags.dig == df.tile_dig_designation.No then return false end
    flags.dig = df.tile_dig_designation.No
    return true
end

-- add on the 'd' prefix to avoid spelling out reserved words (like 'or')
local designate_switch = {
    dd=do_mine,
    dh=do_channel,
    du=do_up_stair,
    dj=do_down_stair,
    di=do_up_down_stair,
    dr=do_ramp,
    dz=do_remove_ramps,
    dt=do_mine,
    dp=do_gather,
    ds=do_smooth,
    de=do_engrave,
    dF=do_fortification,
    --dT=nil,
    --dv=nil,
    --dM=nil,
    --dn=nil,
    dx=do_remove_designation,
    --dbc=nil,
    --dbf=nil,
    --dbm=nil,
    --dbM=nil,
    --dbd=nil,
    --dbD=nil,
    --dbh=nil,
    --dbH=nil,
    --doh=nil,
    --don=nil,
    --dol=nil,
    --dor=nil,
}

local function dig_tile(pos, code, marker_mode)
    local flags, occupancy = dfhack.maps.getTileFlags(pos)
    local tileattrs = df.tiletype.attrs[dfhack.maps.getTileType(pos)]
    if designate_switch[code](flags, occupancy, tileattrs) then
        if flags.dig == df.tile_dig_designation.No and flags.smooth == 0 then
            occupancy.dig_marked = false
        else
            occupancy.dig_marked = marker_mode
        end
        return true
    end
    return false
end

function do_run(zlevel, grid)
    local stats = {
        designated={label='Tiles designated for digging', value=0, always=true},
        out_of_bounds={label='Tiles skipped (outside map boundary)', value=0},
        invalid_keys={label='Invalid key sequence', value=0},
    }

    for y, row in pairs(grid) do
        for x, text in pairs(row) do
            local pos = xyz2pos(x, y, zlevel)
            log('designating (%d, %d, %d)="%s"', pos.x, pos.y, pos.z, text)
            if not quickfort_common.is_within_bounds(pos) then
                log('coordinates out of bounds; skipping')
                stats.out_of_bounds.value = stats.out_of_bounds.value + 1
                goto continue
            end
            local keys, extent = quickfort_common.parse_cell(text)
            log('parsed cell text: keys="%s", width=%d, height=%d',
                keys, extent.width, extent.height)
            local marker_mode = quickfort_common.settings['force_marker_mode']
            if keys:startswith('m') then
                keys = string.sub(keys, 2)
                marker_mode = true
            end
            local code = 'd'..keys
            if not designate_switch[code] then
                print(string.format('invalid key sequence: "%s"', text))
                stats.invalid_keys.value = stats.invalid_keys.value + 1
                goto continue
            end
            for extent_x=1,extent.width do
                for extent_y=1,extent.height do
                    local extent_pos = xyz2pos(
                        pos.x+extent_x-1,
                        pos.y+extent_y-1,
                        pos.z)
                    if dig_tile(extent_pos, code, marker_mode) then
                        stats.designated.value = stats.designated.value + 1
                    end
                end
            end
            ::continue::
        end
    end
    return stats
end

function do_orders(zlevel, grid)
    log('nothing to do for blueprints in mode: dig')
    return nil
end

function do_undo(zlevel, grid)
    local stats = nil
    print('"quickfort undo" not yet implemented for mode: dig')
    return stats
end

return _ENV
