-- common logic for the quickfort modules

local _ENV = mkmodule('hack.scripts.internal.quickfort.common')

settings = {
    blueprints_dir = 'blueprints',
    force_marker_mode = false,
    force_interactive_build = false,
}

verbose = false

function log(...)
    if verbose then print(string.format(...)) end
end

return _ENV
