-- common logic for the quickfort modules
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local utils = require('utils')

valid_modes = utils.invert({
    'dig',
    'build',
    'place',
    'query'
})

settings = {
    blueprints_dir = 'blueprints',
    force_marker_mode = false,
    force_interactive_build = false,
}

verbose = false

function log(...)
    if verbose then print(string.format(...)) end
end

-- blueprint_name is relative to the blueprints dir
function get_blueprint_filepath(blueprint_name)
    return string.format("%s/%s", settings['blueprints_dir'], blueprint_name)
end

local map_limits = {
    x={min=0, max=df.global.world.map.x_count-1},
    y={min=0, max=df.global.world.map.y_count-1},
    z={min=0, max=df.global.world.map.z_count-1},
}

function is_within_map_bounds(pos)
    return pos.x > map_limits.x.min and
            pos.x < map_limits.x.max and
            pos.y > map_limits.y.min and
            pos.y < map_limits.y.max and
            pos.z >= map_limits.z.min and
            pos.z <= map_limits.z.max
end

function is_on_map_edge(pos)
    return (pos.x == map_limits.x.min or
            pos.x == map_limits.x.max) and
            (pos.y == map_limits.y.min or
             pos.y == map_limits.y.max)
end

-- returns a tuple of keys, extent where keys is a string and extent is of the
-- format: {width, height}, where width and height are numbers
function parse_cell(text)
    local _, _, keys, width, height =
            string.find(text, '^%s*(.-)%s*%(?%s*(%d*)%s*x?%s*(%d*)%s*%)?$')
    width = tonumber(width)
    height = tonumber(height)
    if not width or width <= 0 then width = 1 end
    if not height or height <= 0 then height = 1 end
    return keys, {width=width, height=height}
end
