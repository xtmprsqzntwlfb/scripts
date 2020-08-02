-- list-related logic for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local utils = require('utils')
local quickfort_common = reqscript('internal/quickfort/common')
local quickfort_parse = reqscript('internal/quickfort/parse')

local function get_modeline(filepath)
    local file = io.open(filepath)
    local first_line = file:read()
    file:close()
    if (not first_line) then return nil end
    return quickfort_parse.parse_modeline(
        quickfort_parse.tokenize_csv_line(first_line)[1])
end

local blueprint_cache = {}

local function scan_blueprint(path)
    local filepath = quickfort_common.get_blueprint_filepath(path)
    local mtime = dfhack.filesystem.mtime(filepath)
    if not blueprint_cache[path] or blueprint_cache[path].mtime ~= mtime then
        blueprint_cache[path] = {modeline=get_modeline(filepath), mtime=mtime}
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

function get_blueprint_by_number(list_num)
    if #blueprint_files == 0 then
        scan_blueprints()
    end
    local blueprint_file = blueprint_files[list_num]
    if not blueprint_file then
        qerror(string.format('invalid list index: %d', list_num))
    end
    return blueprint_file.path
end

local valid_list_args = utils.invert({
    'l',
    '-library',
})

function do_list(in_args)
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

