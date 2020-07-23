-- query-related logic for the quickfort script

local _ENV = mkmodule('hack.scripts.quickfort-query-internal')

local quickfort_common = require('hack.scripts.quickfort-common-internal')
local log = quickfort_common.log

function do_run(zlevel, grid)
    local stats = nil
    print('"quickfort run" not yet implemented for mode: query')
    return stats
end

function do_orders(zlevel, grid)
    log('nothing to do for blueprints in mode: query')
    return nil
end

function do_undo(zlevel, grid)
    print('cannot undo blueprints for mode: query')
    return nil
end

return _ENV
