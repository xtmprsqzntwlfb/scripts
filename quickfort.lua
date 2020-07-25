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
        error(string.format('error: invalid setting: "%s"', key))
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
        error('error: expected "quickfort set [<key> <value>]"')
    end
    set_setting(args[1], args[2])
    print(string.format('successfully set %s to "%s"',
                        args[1], quickfort_common.settings[args[1]]))
end

local valid_list_args = utils.invert({
    'l',
    '-library',
})

local function do_list(in_args)
    local args = utils.processArgs(in_args, valid_list_args)
    local show_library = args['l'] ~= nil or args['-library'] ~= nil
    print('NOT YET IMPLEMENTED')
    print(string.format(
        'would call "list" with show_library="%s"', tostring(show_library)))
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
        error(string.format('invalid command: "%s"', command))
    end

    local filename = table.remove(in_args, 1)
    if not filename or filename == '' then
        error("expected <list_num> or <filename> parameter")
    end
    local list_num = tonumber(filename)
    if list_num then
        print('NOT YET IMPLEMENTED')
        print(string.format('would convert "%d" into blueprint filename',
                            list_num))
    end

    local args = utils.processArgs(in_args, valid_command_args)
    local quiet = args['q'] ~= nil or args['-quiet'] ~= nil
    local verbose = args['v'] ~= nil or args['-verbose'] ~= nil
    local sheet = tonumber(args['s']) or tonumber(args['-sheet'])

    if command ~= 'orders' and df.global.cursor.x == -30000 then
        error('please position the game cursor at the blueprint start location')
    end

    quickfort_common.verbose = verbose

    print('NOT YET IMPLEMENTED')
    print(string.format(
        'would call "%s" with filename="%s", quiet=%s, verbose=%s, sheet=%s',
        command, filename, tostring(quiet), tostring(verbose), sheet))
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
