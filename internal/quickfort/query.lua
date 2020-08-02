-- query-related logic for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local gui = require('gui')
local guidm = require('gui.dwarfmode')
local quickfort_common = reqscript('internal/quickfort/common')
local log = quickfort_common.log
local quickfort_aliases = reqscript('internal/quickfort/aliases')
local quickfort_keycodes = reqscript('internal/quickfort/keycodes')

local common_aliases_filename = 'hack/data/quickfort/aliases-common.txt'
local user_aliases_filename = 'dfhack-config/quickfort/aliases.txt'

local function move_cursor(screen, overlay, pos)
    overlay:moveCursorTo(pos)
    -- wiggle the cursor so the building under the cursor gets properly selected
    -- is there a better way to do this? I've tried:
    -- - DwarfOverlay:simulateCursorMovement
    -- - DwarfOverlay:selectBuilding
    -- - setting the ui.main.mode to something else then back to QueryBuilding
    if pos.y > 0 then
        gui.simulateInput(screen, 'CURSOR_UP')
        gui.simulateInput(screen, 'CURSOR_DOWN')
    else
        gui.simulateInput(screen, 'CURSOR_DOWN')
        gui.simulateInput(screen, 'CURSOR_UP')
    end
end

function do_run(zlevel, grid)
    local stats = {
        keystrokes={label='Keystrokes sent', value=0, always=true},
        tiles={label='Settings modified', value=0},
    }

    quickfort_aliases.reset_aliases()
    quickfort_aliases.push_aliases_csv_file(common_aliases_filename)
    quickfort_aliases.push_aliases_csv_file(user_aliases_filename)

    local saved_cursor = guidm.getCursorPos()
    local saved_mode = df.global.ui.main.mode
    df.global.ui.main.mode = df.ui_sidebar_mode.QueryBuilding
    local screen = dfhack.gui.getCurViewscreen(true)
    local overlay = guidm.DwarfOverlay{}
    for y, row in pairs(grid) do
        for x, cell_and_text in pairs(row) do
            local pos = xyz2pos(x, y, zlevel)
            -- TODO: verify that we're on top of a building?
            local cell, text = cell_and_text.cell, cell_and_text.text
            log('applying spreadsheet cell %s with text "%s" to map ' ..
                'coordinates (%d, %d, %d)', cell, text, pos.x, pos.y, pos.z)
            local tokens = quickfort_aliases.expand_aliases(text)
            local expanded_text = table.concat(tokens, '')
            if text ~= expanded_text then
                log('expanded aliases to: "%s"', expanded_text)
            end
            move_cursor(screen, overlay, pos)
            local modifiers = {} -- tracks ctrl, shift, and alt modifiers
            for _,token in ipairs(tokens) do
                local token_lower = token:lower()
                if token_lower == '{shift}' or
                        token_lower == '{ctrl}' or
                        token_lower == '{alt}' then
                    modifiers[token_lower] = true
                end
                -- TODO: pause briefly on '{wait}'
                local kcodes = quickfort_keycodes.get_keycodes(token, modifiers)
                modifiers = {}
                if not kcodes then
                    qerror(string.format('unknown key: "%s"', token))
                else
                    gui.simulateInput(screen, kcodes)
                    stats.keystrokes.value = stats.keystrokes.value + 1
                end
                ::continue::
            end
            -- TODO: verify that we're not stuck in a submenu, otherwise error
            stats.tiles.value = stats.tiles.value + 1
        end
    end
    df.global.ui.main.mode = saved_mode
    move_cursor(screen, overlay, saved_cursor)
    quickfort_aliases.reset_aliases()
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
