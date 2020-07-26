-- common logic for the quickfort modules
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

settings = {
    blueprints_dir = 'blueprints',
    force_marker_mode = false,
    force_interactive_build = false,
}

verbose = false

function log(...)
    if verbose then print(string.format(...)) end
end

function logfn(target_fn, ...)
    if verbose then target_fn{...} end
end

local map_limits = {
    x={min=0, max=df.global.world.map.x_count-1},
    y={min=0, max=df.global.world.map.y_count-1},
    z={min=0, max=df.global.world.map.z_count-1},
}

function is_within_map_bounds_x(x)
    return x > map_limits.x.min and
            x < map_limits.x.max
end

function is_within_map_bounds_y(y)
    return y > map_limits.y.min and
            y < map_limits.y.max
end

function is_within_map_bounds_z(z)
    return z >= map_limits.z.min and
            z <= map_limits.z.max
end

function is_within_map_bounds(pos)
    return is_within_map_bounds_x(pos.x) and
            is_within_map_bounds_y(pos.y) and
            is_within_map_bounds_z(pos.z)
end

function is_on_map_edge(pos)
    return (pos.x == map_limits.x.min or
            pos.x == map_limits.x.max) and
            (pos.y == map_limits.y.min or
             pos.y == map_limits.y.max)
end

-- returns a tuple of keys, extent where keys is a string and extent is of the
-- format: {width, height, specified}, where width and height are numbers and
-- specified is true when an extent was explicitly specified
function parse_cell(text)
    local _, _, keys, width, height =
            string.find(text, '^%s*(.-)%s*%(?%s*(%d*)%s*x?%s*(%d*)%s*%)?$')
    width = tonumber(width)
    height = tonumber(height)
    local specified = width and height and true
    if not width or width <= 0 then width = 1 end
    if not height or height <= 0 then height = 1 end
    return keys, {width=width, height=height, specified=specified}
end
