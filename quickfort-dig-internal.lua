-- dig-related logic for the quickfort script
--[[
This file designates tiles with the same rules as the in-game UI. For example,
if the tile is hidden, we designate blindly to avoid spoilers. If it's visible,
the shape and material of the target tile affects whether the designation has
any effect.
]]

local _ENV = mkmodule('hack.scripts.quickfort-dig-internal')

local utils = require('utils')
local quickfort_common = require('hack.scripts.quickfort-common-internal')
local log = quickfort_common.log

local function is_construction(tileattrs)
    return tileattrs.material == df.tiletype_material.CONSTRUCTION
end

local function is_floor(tileattrs)
    return tileattrs.shape == df.tiletype_shape.FLOOR
end

local function is_diggable_floor(tileattrs)
    return is_floor(tileattrs) or
            tileattrs.shape == df.tiletype_shape.BOULDER or
            tileattrs.shape == df.tiletype_shape.PEBBLES
end

local function is_wall(tileattrs)
    return tileattrs.shape == df.tiletype_shape.WALL
end

local function is_fortification(tileattrs)
    return tileattrs.shape == df.tiletype_shape.FORTIFICATION
end

local function is_up_stair(tileattrs)
    return tileattrs.shape == df.tiletype_shape.STAIR_UP
end

local function is_down_stair(tileattrs)
    return tileattrs.shape == df.tiletype_shape.STAIR_DOWN
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

local function is_hard(tileattrs)
    return hard_natural_materials[tileattrs.material]
end

local function is_smooth(tileattrs)
    return tileattrs.special == df.tiletype_special.SMOOTH
end

local function get_engraving(pos)
    -- scan through engravings until we find the one at this pos
    -- super inefficient; is there a better way to do this?
    for _, engraving in ipairs(df.global.world.engravings) do
        if same_xyz(pos, engraving.pos) then
            return engraving
        end
    end
    return nil
end

local function has_designation(flags, occupancy)
    return flags.dig ~= df.tile_dig_designation.No or
            flags.smooth ~= 0 or
            occupancy.carve_track_north ~= 0 or
            occupancy.carve_track_east ~= 0 or
            occupancy.carve_track_south ~= 0 or
            occupancy.carve_track_west ~= 0
end

local function clear_designation(flags, occupancy)
    flags.dig = df.tile_dig_designation.No
    flags.smooth = 0
    occupancy.carve_track_north = 0
    occupancy.carve_track_east = 0
    occupancy.carve_track_south = 0
    occupancy.carve_track_west = 0
end

local values = nil

local values_run = {
    dig_default=df.tile_dig_designation.Default,
    dig_channel=df.tile_dig_designation.Channel,
    dig_upstair=df.tile_dig_designation.UpStair,
    dig_downstair=df.tile_dig_designation.DownStair,
    dig_updownstair=df.tile_dig_designation.UpDownStair,
    dig_ramp=df.tile_dig_designation.Ramp,
    dig_no=df.tile_dig_designation.No,
    smooth=1,
    engrave=2,
    track=1,
    traffic_normal=0,
    traffic_low=1,
    traffic_high=2,
    traffic_restricted=3,
}

local values_undo = {
    dig_default=df.tile_dig_designation.No,
    dig_channel=df.tile_dig_designation.No,
    dig_upstair=df.tile_dig_designation.No,
    dig_downstair=df.tile_dig_designation.No,
    dig_updownstair=df.tile_dig_designation.No,
    dig_ramp=df.tile_dig_designation.No,
    dig_no=df.tile_dig_designation.No,
    smooth=0,
    engrave=0,
    track=0,
    traffic_normal=0,
    traffic_low=0,
    traffic_high=0,
    traffic_restricted=0,
}

-- these functions return whether a designation was made
local function do_mine(ctx)
    if ctx.on_map_edge then return false end
    if not ctx.flags.hidden then -- always designate if the tile is hidden
        if is_construction(ctx.tileattrs) or
                (not is_wall(ctx.tileattrs) and
                 not is_fortification(ctx.tileattrs)) then
            return false
        end
    end
    ctx.flags.dig = values.dig_default
    return true
end

local function do_channel(ctx)
    if ctx.on_map_edge then return false end
    if not ctx.flags.hidden then -- always designate if the tile is hidden
        if is_construction(ctx.tileattrs) or
                (not is_wall(ctx.tileattrs) and
                 not is_fortification(ctx.tileattrs) and
                 not is_diggable_floor(ctx.tileattrs) and
                 not is_down_stair(ctx.tileattrs) and
                 not is_removable_shape(ctx.tileattrs)) then
            return false
        end
    end
    ctx.flags.dig = values.dig_channel
    return true
end

local function do_up_stair(ctx)
    if ctx.on_map_edge then return false end
    if not ctx.flags.hidden then -- always designate if the tile is hidden
        if is_construction(ctx.tileattrs) or
                (not is_wall(ctx.tileattrs) and
                 not is_fortification(ctx.tileattrs)) then
            return false
        end
    end
    ctx.flags.dig = values.dig_upstair
    return true
end

local function do_down_stair(ctx)
    if ctx.on_map_edge then return false end
    if not ctx.flags.hidden then -- always designate if the tile is hidden
        if is_construction(ctx.tileattrs) or
                (not is_wall(ctx.tileattrs) and
                 not is_fortification(ctx.tileattrs) and
                 not is_diggable_floor(ctx.tileattrs) and
                 not is_removable_shape(ctx.tileattrs)) then
            return false
        end
    end
    ctx.flags.dig = values.dig_downstair
    return true
end

local function do_up_down_stair(ctx)
    if ctx.on_map_edge then return false end
    if not ctx.flags.hidden then -- always designate if the tile is hidden
        if is_construction(ctx.tileattrs) or
                (not is_wall(ctx.tileattrs) and
                 not is_fortification(ctx.tileattrs) and
                 not is_up_stair(ctx.tileattrs)) then
            return false
        end
    end
    if is_up_stair(ctx.tileattrs) then
        ctx.flags.dig = values.dig_downstair
    else
        ctx.flags.dig = values.dig_updownstair
    end
    return true
end

local function do_ramp(ctx)
    if ctx.on_map_edge then return false end
    if not ctx.flags.hidden then -- always designate if the tile is hidden
        if is_construction(ctx.tileattrs) or
                (not is_wall(ctx.tileattrs) and
                 not is_fortification(ctx.tileattrs)) then
            return false
        end
    end
    ctx.flags.dig = values.dig_ramp
    return true
end

local function do_remove_ramps(ctx)
    if ctx.on_map_edge or ctx.flags.hidden then return false end
    if is_construction(ctx.tileattrs) or
            not is_removable_shape(ctx.tileattrs) then
        return false
    end
    ctx.flags.dig = values.dig_default
    return true
end

local function do_gather(ctx)
    if ctx.flags.hidden then return false end
    if not is_gatherable(ctx.tileattrs) then return false end
    ctx.flags.dig = values.dig_default
    return true
end

local function do_smooth(ctx)
    if ctx.flags.hidden then return false end
    if is_construction(ctx.tileattrs) or not is_hard(ctx.tileattrs) or
            (not is_floor(ctx.tileattrs) and not is_wall(ctx.tileattrs)) then
        return false
    end
    ctx.flags.smooth = values.smooth
    return true
end

local function do_engrave(ctx)
    if ctx.flags.hidden or
            is_construction(ctx.tileattrs) or
            not is_smooth(ctx.tileattrs) or
            get_engraving(ctx.pos) ~= nil then
        return false
    end
    ctx.flags.smooth = values.engrave
    return true
end

local function do_fortification(ctx)
    if ctx.flags.hidden then return false end
    if not is_wall(ctx.tileattrs) or
            not is_smooth(ctx.tileattrs) then return false end
    ctx.flags.smooth = values.smooth
    return true
end

local function do_track(ctx)
    if ctx.on_map_edge or
            ctx.flags.hidden or
            is_construction(ctx.tileattrs) or
            not is_floor(ctx.tileattrs) or
            not is_hard(ctx.tileattrs) then
        return false
    end
    local extent_adjacent = ctx.extent_adjacent
    if not extent_adjacent.north and not  extent_adjacent.south and
            not extent_adjacent.east and not extent_adjacent.west then
        print('ambiguous direction for track; please use T(width x height)' ..
              ' syntax (specify both width > 1 and height > 1 for a' ..
              ' track that extends both South and East from this corner')
        return false
    end
    if extent_adjacent.north and extent_adjacent.west then
        -- we're in the "empty" interior of a track extent - tracks can only be
        -- built in lines along the top or left of an extent.
        return false
    end
    -- don't overwrite all directions, only 'or' in the new bits. we could be
    -- adding to a previously-designated track.
    local occupancy = ctx.occupancy
    if extent_adjacent.north then occupancy.carve_track_north = values.track end
    if extent_adjacent.east then occupancy.carve_track_east = values.track end
    if extent_adjacent.south then occupancy.carve_track_south = values.track end
    if extent_adjacent.west then occupancy.carve_track_west = values.track end
    return true
end

local function do_toggle_engravings(ctx)
    if ctx.flags.hidden then return false end
    local engraving = get_engraving(ctx.pos)
    if engraving == nil then return false end
    engraving.flags.hidden = not engraving.flags.hidden
    return true
end

local function do_toggle_marker(ctx)
    if not has_designation(ctx.flags, ctx.occupancy) then return false end
    ctx.occupancy.dig_marked = not ctx.occupancy.dig_marked
    return true
end

local function do_remove_construction(ctx)
    if ctx.flags.hidden or not is_construction(ctx.tileattrs) then
        return false
    end
    ctx.flags.dig = values.dig_default
    return true
end

local function do_remove_designation(ctx)
    if not has_designation(ctx.flags, ctx.occupancy) then return false end
    clear_designation(ctx.flags, ctx.occupancy)
    return true
end

local function do_traffic_high(ctx)
    if ctx.flags.hidden then return false end
    ctx.flags.traffic = values.traffic_high
end

local function do_traffic_normal(ctx)
    if ctx.flags.hidden then return false end
    ctx.flags.traffic = values.traffic_normal
end

local function do_traffic_low(ctx)
    if ctx.flags.hidden then return false end
    ctx.flags.traffic = values.traffic_low
end

local function do_traffic_restricted(ctx)
    if ctx.flags.hidden then return false end
    ctx.flags.traffic = values.traffic_restricted
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
    dT=do_track,
    dv=do_toggle_engravings,
    dM=do_toggle_marker,
    dn=do_remove_construction,
    dx=do_remove_designation,
    --dbc=nil,
    --dbf=nil,
    --dbm=nil,
    --dbM=nil,
    --dbd=nil,
    --dbD=nil,
    --dbh=nil,
    --dbH=nil,
    doh=do_traffic_high,
    don=do_traffic_normal,
    dol=do_traffic_low,
    dor=do_traffic_restricted,
}

local function dig_tile(ctx, code, marker_mode)
    ctx.flags, ctx.occupancy = dfhack.maps.getTileFlags(ctx.pos)
    ctx.tileattrs = df.tiletype.attrs[dfhack.maps.getTileType(ctx.pos)]
    if designate_switch[code](ctx) then
        if not has_designation(ctx.flags, ctx.occupancy) then
            ctx.occupancy.dig_marked = false
        elseif code == "dM" then
            -- the semantics are a little unclear if the code is M (toggle
            -- marker mode) but m or force_marker_mode is also specified.
            -- for now, let either turn marker mode on
            ctx.occupancy.dig_marked = ctx.occupancy.dig_marked or marker_mode
        else
            ctx.occupancy.dig_marked = marker_mode
        end
        return true
    end
    return false
end

local function do_run_impl(zlevel, grid)
    local stats = {
        designated={label='Tiles designated', value=0, always=true},
        out_of_bounds={label='Tiles skipped (outside map boundary)', value=0},
        invalid_keys={label='Invalid key sequence', value=0},
    }

    for y, row in pairs(grid) do
        for x, text in pairs(row) do
            local pos = xyz2pos(x, y, zlevel)
            log('designating (%d, %d, %d)="%s"', pos.x, pos.y, pos.z, text)
            local keys, extent = quickfort_common.parse_cell(text)
            log('parsed cell: keys="%s", width=%d, height=%d',
                keys, extent.width, extent.height)
            local marker_mode = quickfort_common.settings['force_marker_mode']
            if keys:startswith('m') then
                keys = string.sub(keys, 2)
                marker_mode = true
            end
            local code = 'd'..keys
            if not designate_switch[code] then
                print(string.format('invalid key sequence: "%s"', text))
                stats.invalid_keys.value = stats.invalid_keys.value+1
                goto continue
            end
            for extent_x=1,extent.width do
                for extent_y=1,extent.height do
                    local extent_pos = xyz2pos(
                        pos.x+extent_x-1,
                        pos.y+extent_y-1,
                        pos.z)
                    local extent_adjacent = {
                        north=extent_y>1,
                        east=extent_x<extent.width,
                        south=extent_y<extent.height,
                        west=extent_x>1,
                    }
                    local ctx = {
                        pos=extent_pos,
                        extent_adjacent=extent_adjacent,
                        on_map_edge=quickfort_common.is_on_map_edge(extent_pos)
                    }
                    if not quickfort_common.is_within_map_bounds(ctx.pos) and
                            not ctx.on_map_edge then
                        log('coordinates out of bounds; skipping')
                        stats.out_of_bounds.value = stats.out_of_bounds.value+1
                    else
                        if dig_tile(ctx, code, marker_mode) then
                            stats.designated.value = stats.designated.value+1
                        end
                    end
                end
            end
            ::continue::
        end
    end
    return stats
end

function do_run(zlevel, grid)
    values = values_run
    return do_run_impl(zlevel, grid)
end

function do_orders(zlevel, grid)
    log('nothing to do for blueprints in mode: dig')
    return nil
end

function do_undo(zlevel, grid)
    values = values_undo
    return do_run_impl(zlevel, grid)
end

return _ENV
