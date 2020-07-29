-- common logic for the quickfort modules
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local utils = require('utils')

-- the module jump table is maintained in the top-level quickfort.lua script
modules = {}

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
