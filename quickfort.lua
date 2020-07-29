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

local quickfort_common = reqscript('internal/quickfort/common')

-- set up the module table. we have to do this here instead of just using
-- reqscript in each internal file since transitive dependencies don't get
-- reloaded automatically when files change. we have to be careful here to
-- initialize modules in order so that dependencies are initialized before they
-- are used. we also need to be careful not to introduce circular dependencies
-- among the internal modules.
quickfort_common.modules = {
    set = reqscript('internal/quickfort/set'),
    parse = reqscript('internal/quickfort/parse'),
    list = reqscript('internal/quickfort/list'),
    dig = reqscript('internal/quickfort/dig'),
    build = reqscript('internal/quickfort/build'),
    place = reqscript('internal/quickfort/place'),
    query = reqscript('internal/quickfort/query'),
    command = reqscript('internal/quickfort/command'),
}

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

local action_switch = {
    set=quickfort_common.modules.set.do_set,
    reset=quickfort_common.modules.set.do_reset,
    list=quickfort_common.modules.list.do_list,
    run=quickfort_common.modules.command.do_command,
    orders=quickfort_common.modules.command.do_command,
    undo=quickfort_common.modules.command.do_command
}
setmetatable(action_switch, {__index=function() return print_short_help end})

local args = {...}
local action = table.remove(args, 1) or 'help'
args['action'] = action

action_switch[action](args)
