-- DFHack-native implementation of the classic Quickfort utility (PRE-RELEASE)
--[====[

quickfort
=========
Processes Quickfort-style blueprint files. This is a pre-release -- not all
features are implemented yet.

Quickfort blueprints record what you want at each map coordinate in a
spreadsheet, storing the keys in a spreadsheet cell that you would press to make
something happen at that spot on the DF map. Quickfort runs in one of four
modes: ``dig``, ``build``, ``place``, or ``query``. ``dig`` designates tiles for
digging, ``build`` builds buildings and constructions, ``place`` places
stockpiles, and ``query`` changes building or stockpile settings. The mode is
determined by a marker in the upper-left cell of the spreadsheet (e.g.: ``#dig``
in cell ``A1``).

You can create these blueprints by hand or by using any spreadsheet application,
saving them as ``.xlsx`` or ``.csv`` files. You can also build your plan "for
real" in Dwarf Fortress, and then export your map using the DFHack
`blueprint plugin`_ for later replay in a different fort. Blueprint files should
go in the ``blueprints`` subfolder in the main DF folder.

You can read more about how to create blueprint files in the
`blueprints/README.txt`_ file, and there are ready-to-use examples of blueprints
in each of the four modes in the `blueprints/library`_ folder.

Usage:

**quickfort set [<key> <value>]**
    Allows you to modify the active quickfort configuration. Just run
    ``quickfort set`` to show current settings. See the Configuration section
    below for available keys and values.
**quickfort reset**
    Resets quickfort script state and re-reads all configuration files.
**quickfort list [-l|--library]**
    Lists blueprints in the ``blueprints`` folder. Blueprints are ``.csv`` files
    or sheets within ``.xlsx`` files that contain a ``#<mode>`` comment in the
    upper-left cell. By default, blueprints in the ``blueprints/library/``
    subfolder are not included. Specify ``-l`` to include library blueprints.
**quickfort <command> <list_num> [<options>]**
    Applies the blueprint with the number from the list command.
**quickfort <command> <filename> [-s|--sheet <sheet_num>] [<options>]**
    Applies the blueprint from the named file. If it is an ``.xlsx`` file,
    the ``-s`` (or ``--sheet``) parameter is required to identify the sheet
    number (the first sheet is ``-s 1``).

**<command>** can be one of:

:run:     applies the blueprint at your current active cursor position.
:orders:  uses the manager interface to queue up orders for the specified
          build-mode blueprint.
:undo:    applies the inverse of the specified blueprint, depending on its type.
          Dig tiles are undesignated, buildings are canceled or removed
          (depending on their construction status), and stockpiles are removed.
          No effect for query blueprints.

**<options>** can be zero or more of:

``-q``, ``--quiet``
    Don't report on what actions were taken (error messages are still shown).
``-v``, ``--verbose``
    Output extra debugging information.

Configuration:

The quickfort script reads its startup configuration from the
``dfhack-config/quickfort/quickfort.txt`` file, which you can customize. The
following settings may be dynamically modified by the ``quickfort set`` command
(note that settings changed with the ``quickfort set`` command will not change
the configuration stored in the file):

``blueprints_dir`` (default: 'blueprints')
    Can be set to an absolute or relative path. If set to a relative path,
    resolves to a directory under the DF folder.
``force_marker_mode`` (default: 'false')
    Set to "true" or "false". If true, will designate dig blueprints in marker
    mode. If false, only cells with dig codes prefixed with ``m`` will be
    designated in marker mode.
``force_interactive_build`` (default: 'false')
    Allows you to manually select building materials for each
    building/construction when running (or creating orders for) build
    blueprints. Materials in selection dialogs are ordered according to
    preferences in ``materials.txt`` (see below). If false, will only prompt for
    materials that have :labels. See `original Quickfort documentation`_ for
    details.

There are also two other configuration files in the ``dfhack-config/quickfort``
folder: ``aliases.txt`` and ``materials.txt``. ``aliases.txt`` defines keycode
shortcuts for query blueprints, and ``materials.txt`` defines forbidden
materials and material preferences for build blueprints. The formats for these
files are described in the files themselves.

.. _blueprint plugin: https://docs.dfhack.org/en/stable/docs/Plugins.html#blueprint
.. _blueprints/README.txt: https://github.com/DFHack/dfhack/tree/develop/data/blueprints/README.txt
.. _blueprints/library: https://github.com/DFHack/dfhack/tree/develop/data/blueprints/library
.. _original Quickfort documentation: https://github.com/joelpt/quickfort#manual-material-selection
]====]

-- only initialize our globals once
if not initialized then

local guidm = require('gui.dwarfmode')
local utils = require('utils')
local quickfort_common = reqscript('internal/quickfort/common')
local quickfort_dig = reqscript('internal/quickfort/dig')
local quickfort_build = reqscript('internal/quickfort/build')
local quickfort_place = reqscript('internal/quickfort/place')
local quickfort_query = reqscript('internal/quickfort/query')

local function do_reset()
    initialized = false
end

-- keep this in sync with the full help text above
local function print_short_help()
    print [[
Usage:

quickfort set [<key> <value>]
    Allows you to modify the active quickfort configuration. Just run
    "quickfort set" to show current settings.
quickfort reset
    Resets quickfort script state and re-reads all configuration files.
quickfort list [-l|--library]
    Lists blueprints in the "blueprints" folder. Specify -l to include library
    blueprints.
quickfort <command> <list_num> [<options>]
    Applies the blueprint with the number from the list command.
quickfort <command> <filename> [-s|--sheet <sheet_num>] [<options>]
    Applies the blueprint from the named file. If it is an .xlsx file, the -s
    parameter is required to identify the sheet (the first sheet is "-s 1").

<command> can be one of:

run     applies the blueprint at your current active cursor position.
orders  uses the manager interface to queue up orders for the specified
        build-mode blueprint.
undo    applies the inverse of the specified blueprint, depending on its type.
        Dig tiles are undesignated, buildings are canceled or removed
        (depending on their construction status), and stockpiles are removed.
        No effect for query blueprints.

<options> can be zero or more of:

-q, --quiet
    Don't report on what actions were taken (error messages are still shown).
-v, --verbose
    Output extra debugging information.

For more info, see: https://docs.dfhack.org/en/stable/docs/_auto/base.html#quickfort
]]
end

local function set_setting(key, value)
    if quickfort_common.settings[key] == nil then
        qerror(string.format('error: invalid setting: "%s"', key))
    end
    local val = value
    if type(quickfort_common.settings[key]) == 'boolean' then
        val = value == 'true'
    end
    quickfort_common.settings[key] = val
end

local function read_config(filename)
    for line in io.lines(filename) do
        local _, _, key, value = string.find(line, '^%s*([%a_]+)%s*=%s*(%S.*)')
        if (key) then
            set_setting(key, value)
        end
    end
end

local function do_set(args)
    if #args == 0 then
        print('active settings:')
        printall(quickfort_common.settings)
        return
    end
    if #args ~= 2 then
        qerror('error: expected "quickfort set [<key> <value>]"')
    end
    set_setting(args[1], args[2])
    print(string.format('successfully set %s to "%s"',
                        args[1], quickfort_common.settings[args[1]]))
end

-- adapted from example on http://lua-users.org/wiki/LuaCsv
function tokenize_csv_line(line)
    local tokens = {}
    local pos = 1
    local sep = ','
    while true do
        local c = string.sub(line, pos, pos)
        if (c == "") then break end
        if (c == '"') then
            -- quoted value (ignore separator within)
            local txt = ""
            repeat
                local startp, endp = string.find(line, '^%b""', pos)
                txt = txt..string.sub(line, startp+1, endp-1)
                pos = endp + 1
                c = string.sub(line, pos, pos)
                if (c == '"') then txt = txt..'"' end
                -- check first char AFTER quoted string, if it is another
                -- quoted string without separator, then append it
                -- this is the way to "escape" the quote char in a quote.
                -- example: "blub""blip""boing" -> blub"blip"boing
            until (c ~= '"')
            table.insert(tokens,txt)
            assert(c == sep or c == "")
            pos = pos + 1
        else
            -- no quotes used, just look for the first separator
            local startp, endp = string.find(line, sep, pos)
            if (startp) then
                table.insert(tokens, string.sub(line, pos, startp-1))
                pos = endp + 1
            else
                -- no separator found -> use rest of string and terminate
                table.insert(tokens, string.sub(line, pos))
                break
            end
        end
    end
    return tokens
end

local mode_switch = {
    dig=quickfort_dig,
    build=quickfort_build,
    place=quickfort_place,
    query=quickfort_query,
}

--[[
parses a Quickfort 2.0 modeline
example: '#dig (start 4;4;center of stairs) dining hall'
where all elements other than the initial #mode are optional (though if the
'start' block exists, the offsets must also exist)
returns a table in the format {mode, startx, starty, start_comment, comment}
or nil if the modeline is invalid
]]
local function parse_modeline(line)
    if not line then return nil end
    local _, mode_end, mode = string.find(line, '^#([%l]+)')
    if not mode or not mode_switch[mode] then
        print(string.format('invalid mode: %s', mode))
        return nil
    end
    local _, start_str_end, start_str = string.find(
        line, '%s+start(%b())', mode_end + 1)
    local startx, starty, start_comment = 1, 1, nil
    if start_str then
        _, _, startx, starty, start_comment = string.find(
            start_str, '^%(%s*(%d+)%s*;%s*(%d+)%s*;?%s*(.*)%)$')
        if not startx or not starty then
            print(string.format('invalid start offsets: %s', start_str))
            return nil
        end
    else
        start_str_end = mode_end
    end
    local _, _, comment = string.find(line, '%s*(.*)', start_str_end + 1)
    return {
        mode=mode,
        startx=startx,
        starty=starty,
        start_comment=start_comment,
        comment=comment
    }
end

local function get_modeline(filepath)
    local file = io.open(filepath)
    local first_line = file:read()
    file:close()
    if (not first_line) then return nil end
    return parse_modeline(tokenize_csv_line(first_line)[1])
end

-- filename is relative to the blueprints dir
local function get_blueprint_filepath(filename)
    return string.format("%s/%s",
                         quickfort_common.settings['blueprints_dir'], filename)
end

local blueprint_cache = {}

local function scan_blueprint(path)
    local filepath = get_blueprint_filepath(path)
    local hash = dfhack.internal.md5File(filepath)
    if not blueprint_cache[path] or blueprint_cache[path].hash ~= hash then
        blueprint_cache[path] = {modeline=get_modeline(filepath), hash=hash}
    end
    return blueprint_cache[path].modeline
end

local blueprint_files = {}

local function scan_blueprints()
    local paths = dfhack.filesystem.listdir_recursive(
        quickfort_common.settings['blueprints_dir'], nil, false)
    blueprint_files = {}
    local library_files = {}
    for _, v in ipairs(paths) do
        if not v.isdir and
                (string.find(v.path, '[.]csv$') or
                 string.find(v.path, '[.]xlsx$')) then
            if string.find(v.path, '[.]xlsx$') then
                print(string.format(
                        'skipping "%s": .xlsx files not supported yet', v.path))
                goto skip
            end
            local modeline = scan_blueprint(v.path)
            if not modeline then
                print(string.format(
                        'skipping "%s": no #mode marker detected', v.path))
                goto skip
            end
            if string.find(v.path, '^library/') ~= nil then
                table.insert(
                    library_files,
                    {path=v.path, modeline=modeline, is_library=true})
            else
                table.insert(
                    blueprint_files,
                    {path=v.path, modeline=modeline, is_library=false})
            end
            ::skip::
        end
    end
    -- tack library files on to the end so user files are contiguous
    for i=1, #library_files do
        blueprint_files[#blueprint_files + 1] = library_files[i]
    end
end

local valid_list_args = utils.invert({
    'l',
    '-library',
})

local function do_list(in_args)
    local args = utils.processArgs(in_args, valid_list_args)
    local show_library = args['l'] ~= nil or args['-library'] ~= nil
    scan_blueprints()
    for i, v in ipairs(blueprint_files) do
        if show_library or not v.is_library then
            local comment = ')'
            if #v.modeline.comment > 0 then
                comment = string.format(': %s)', v.modeline.comment)
            end
            local start_comment = ''
            if v.modeline.start_comment and #v.modeline.start_comment > 0 then
                start_comment = string.format('; place cursor: %s',
                                              v.modeline.start_comment)
            end
            print(string.format('%d) "%s" (%s%s%s',
                                i, v.path, v.modeline.mode, comment,
                                start_comment))
        end
    end
end

local function get_col_name(col)
  if col <= 26 then
    return string.char(string.byte('A') + col - 1)
  end
  local div, mod = math.floor(col / 26), math.floor(col % 26)
  if mod == 0 then
      mod = 26
      div = div - 1
  end
  return get_col_name(div) .. get_col_name(mod)
end

local function make_cell_label(col_num, row_num)
    return get_col_name(col_num) .. tostring(math.floor(row_num))
end

-- returns a grid representation of the current section and the next z-level
-- modifier, if any. See process_file for grid format.
local function process_section(file, start_line_num, start_coord)
    local grid = {}
    local y = start_coord.y
    while true do
        local line = file:read()
        if not line then return grid, y-start_coord.y end
        for i, v in ipairs(tokenize_csv_line(line)) do
            if i == 1 then
                if v == '#<' then return grid, y-start_coord.y, 1 end
                if v == '#>' then return grid, y-start_coord.y, -1 end
            end
            if string.find(v, '^#') then break end
            if not string.find(v, '^[`~%s]*$') then
                -- cell has actual content, not just spaces or comment chars
                if not grid[y] then grid[y] = {} end
                local x = start_coord.x + i - 1
                local line_num = start_line_num + y - start_coord.y
                grid[y][x] = {cell=make_cell_label(i, line_num), text=v}
            end
        end
        y = y + 1
    end
end

--[[
returns the following logical structure:
  map of target map z coordinate ->
    list of {modeline, grid} tables
Where the structure of modeline is defined as per parse_modeline and grid is a:
  map of target y coordinate ->
    map of target map x coordinate ->
      {cell=spreadsheet cell, text=text from spreadsheet cell}
Map keys are numbers, and the keyspace is sparse -- only elements that have
contents are non-nil.
]]
local function process_file(filepath, start_cursor_coord)
    local file = io.open(filepath)
    if not file then
        error(string.format('failed to open blueprint file: "%s"', filepath))
    end
    local line = file:read()
    local modeline = parse_modeline(tokenize_csv_line(line)[1])
    local cur_line_num = 2
    local x = start_cursor_coord.x - modeline.startx + 1
    local y = start_cursor_coord.y - modeline.starty + 1
    local z = start_cursor_coord.z
    local zlevels = {}
    while true do
        local grid, num_section_rows, zmod =
                process_section(file, cur_line_num, xyz2pos(x, y, z))
        for _, _ in pairs(grid) do
            -- apparently, the only way to tell if a sparse array is not empty
            if not zlevels[z] then zlevels[z] = {} end
            table.insert(zlevels[z], {modeline=modeline, grid=grid})
            break;
        end
        if zmod == nil then break end
        cur_line_num = cur_line_num + num_section_rows + 1
        z = z + zmod
    end
    file:close()
    return zlevels
end

local command_switch = {
    run='do_run',
    orders='do_orders',
    undo='do_undo',
}

local valid_command_args = utils.invert({
    'q',
    '-quiet',
    'v',
    '-verbose',
    's',
    '-sheet',
})

local function do_command(in_args)
    local command = in_args.action
    if not command or not command_switch[command] then
        qerror(string.format('invalid command: "%s"', command))
    end

    local filename = table.remove(in_args, 1)
    if not filename or filename == '' then
        qerror("expected <list_num> or <filename> parameter")
    end
    local list_num = tonumber(filename)
    if list_num then
        if #blueprint_files == 0 then
            scan_blueprints()
        end
        blueprint_file = blueprint_files[list_num]
        if not blueprint_file then
            qerror(string.format('invalid list index: %d', list_num))
        end
        filename = blueprint_files[list_num].path
    end

    local args = utils.processArgs(in_args, valid_command_args)
    local quiet = args['q'] ~= nil or args['-quiet'] ~= nil
    local verbose = args['v'] ~= nil or args['-verbose'] ~= nil
    local sheet = tonumber(args['s']) or tonumber(args['-sheet'])
    local cursor = guidm.getCursorPos()

    if command ~= 'orders' and not cursor then
        qerror('please position the game cursor at the blueprint start location')
    end

    quickfort_common.verbose = verbose

    local filepath = get_blueprint_filepath(filename)
    local data = process_file(filepath, cursor)
    for zlevel, section_data_list in pairs(data) do
        for _, section_data in ipairs(section_data_list) do
            local modeline = section_data.modeline
            local stats = mode_switch[modeline.mode][command_switch[command]](
                zlevel,
                section_data.grid)
            if stats and not quiet then
                print(string.format('%s on z-level %d', modeline.mode, zlevel))
                for _, stat in pairs(stats) do
                    if stat.always or stat.value > 0 then
                        print(string.format('  %s: %d', stat.label, stat.value))
                    end
                end
            end
        end
    end
    print(string.format('%s "%s" successfully completed', command, filename))
end


-- initialize script
read_config('dfhack-config/quickfort/quickfort.txt')

action_switch = {
    reset=do_reset,
    set=do_set,
    list=do_list,
    run=do_command,
    orders=do_command,
    undo=do_command,
    }
setmetatable(action_switch, {__index=function () return print_short_help end})

initialized = true
end -- if not initialized


-- main
local args = {...}
local action = table.remove(args, 1) or 'help'
args['action'] = action

action_switch[action](args)
