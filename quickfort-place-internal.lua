-- place-related logic for the quickfort script

local _ENV = mkmodule('hack.scripts.quickfort-place-internal')

local quickfort_common = require('hack.scripts.quickfort-common-internal')
local log = quickfort_common.log

function do_run(zlevel, grid)
    local stats = nil
    print('"quickfort run" not yet implemented for mode: place')
    return stats
end

function do_orders(zlevel, grid)
    log('nothing to do for blueprints in mode: place')
    return nil
end

function do_undo(zlevel, grid)
    local stats = nil
    print('"quickfort undo" not yet implemented for mode: place')
    return stats
end

return _ENV
