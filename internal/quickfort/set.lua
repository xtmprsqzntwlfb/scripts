-- settings management logic for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local quickfort_common = reqscript('internal/quickfort/common')

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
    print(string.format('reading configuration from "%s"', filename))
    for line in io.lines(filename) do
        local _, _, key, value = string.find(line, '^%s*([%a_]+)%s*=%s*(%S.*)')
        if (key) then
            set_setting(key, value)
        end
    end
end

function do_set(args)
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

function do_reset()
    read_config('dfhack-config/quickfort/quickfort.txt')
end

if not initialized then
    -- this is the first time we're initializing the environment
    do_reset()
    initialized = true
end
