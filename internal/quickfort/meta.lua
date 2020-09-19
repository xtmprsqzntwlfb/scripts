-- meta-blueprint logic for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local quickfort_common = reqscript('internal/quickfort/common')
local log = quickfort_common.log
local quickfort_command = reqscript('internal/quickfort/command')

-- blueprints referenced by meta blueprints must have a label, even if it's just
-- a default numeric label. this is so we can provide intelligent error messages
-- instead of an infinite loop when the blueprint author forgets a slash and
-- a string is interpreted as a sheet name instead of a label (which is ignored
-- for .csv files), the label defaults to "1", and the meta blueprint is the
-- first blueprint in the file.
local function get_section_name(cell, text, cur_sheet_name)
    local sheet_name, label = quickfort_command.parse_section_name(text)
    if not label then
        local cell_msg = string.format(
            'malformed blueprint section name in cell %s', cell)
        local suggestion = string.format('/%s', text:gsub('/*$', ''))
        if cur_sheet_name then
            suggestion = string.format('%s or %s/somelabel',
                                       suggestion, text:gsub('/*$', ''))
        end
        local label_msg = string.format(
                '(labels are required; did you mean "%s"?)', suggestion)
        qerror(string.format('%s %s: %s', cell_msg, label_msg, text))
    end
    if not sheet_name then sheet_name = cur_sheet_name or '' end
    return string.format('%s/%s', sheet_name, label)
end

local function do_meta(zlevel, grid, ctx)
    local stats = ctx.stats
    stats.meta_blueprints = stats.meta_blueprints or
            {label='Blueprints applied', value=0, always=true}

    -- ensure we process blueprints in the declared order
    local cells = quickfort_common.get_ordered_grid_cells(grid)
    local saved_zlevel = ctx.cursor.z
    for _, cell in ipairs(cells) do
        quickfort_command.do_command_internal(
            ctx, get_section_name(cell.cell, cell.text, ctx.sheet_name))
        ctx.cursor.z = saved_zlevel
        stats.meta_blueprints.value = stats.meta_blueprints.value + 1
    end
end

function do_run(zlevel, grid, ctx)
    do_meta(zlevel, grid, ctx)
end

function do_orders(zlevel, grid, ctx)
    do_meta(zlevel, grid, ctx)
end

function do_undo(zlevel, grid, ctx)
    do_meta(zlevel, grid, ctx)
end
