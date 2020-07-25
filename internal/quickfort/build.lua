-- build-related logic for the quickfort script

local _ENV = mkmodule('hack.scripts.internal.quickfort.build')

local quickfort_common = require('hack.scripts.internal.quickfort.common')
local log = quickfort_common.log

function do_run(zlevel, grid)
    local stats = nil
    print('"quickfort run" not yet implemented for mode: build')
    return stats
end

function do_orders(zlevel, grid)
    local stats = nil
    print('"quickfort orders" not yet implemented for mode: build')
    return stats
end

function do_undo(zlevel, grid)
    local stats = nil
    print('"quickfort undo" not yet implemented for mode: build')
    return stats
end

return _ENV
