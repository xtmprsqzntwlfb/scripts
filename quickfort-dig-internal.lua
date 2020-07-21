-- dig-related logic for the quickfort script

local _ENV = mkmodule('hack.scripts.quickfort-dig-internal')

function do_run(zlevel, grid, verbose)
    stats = nil
    print('"quickfort run" not yet implemented for mode: dig')
    return stats
end

function do_orders(zlevel, grid, verbose)
    if verbose then print('nothing to do for blueprints in mode: dig') end
    return nil
end

function do_undo(zlevel, grid, verbose)
    stats = nil
    print('"quickfort undo" not yet implemented for mode: dig')
    return stats
end

return _ENV
