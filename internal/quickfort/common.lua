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
