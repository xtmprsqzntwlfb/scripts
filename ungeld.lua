-- ungelds animals
-- Written by Josh Cooper(cppcooper) on 2019-12-10, last modified: 2020-02-23
utils = require('utils')
local validArgs = utils.invert({
    'unit',
    'help',
})
local args = utils.processArgs({...}, validArgs)
local help = [====[

ungeld
======
It sets the geld status to false.

Valid options:

    unit <id> - Performs action on the provided unit id, this is optional.
                If this argument is not given, the highlighted unit is
                used instead.

]====]

if args.help then
    print(help)
    return
end

local geld_args = {'-ungeld'}

if args.unit then
    table.insert(geld_args, '-unit')
    table.insert(geld_args, args.unit)
end

dfhack.run_script('geld', table.unpack(geld_args))
