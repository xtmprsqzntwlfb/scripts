-- query-related logic for the quickfort script

local _ENV = mkmodule('hack.scripts.quickfort-query-internal')

function do_run(zlevel, grid, verbose)
    stats = nil
    print('"quickfort run" not yet implemented for mode: query')
    return stats
end

function do_orders(zlevel, grid, verbose)
    if verbose then print('nothing to do for blueprints in mode: query') end
    return nil
end

function do_undo(zlevel, grid, verbose)
    print('cannot undo blueprints for mode: query')
    return nil
end

return _ENV
