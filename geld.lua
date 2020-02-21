-- Gelds animals by default. Optional args: -toggle or -ungeld
-- Written by Josh Cooper(cppcooper) on 2019-12-10, last modified: 2020-02-15
utils ={}
utils = require('utils')
local validArgs = utils.invert({
    'toggle',
    'ungeld',
    'help'

})
local args = utils.processArgs({...}, validArgs)
local help = [====[

geld
====
Geld allows the user to geld and ungeld animals.
Valid options:
    toggle  - Changes the geld status to the opposite of its current state
    ungeld  - Sets the geld status to false
    help    - Shows this help information

]====]

unit = dfhack.gui.getSelectedUnit()
oldstate = unit.flags3.gelded

if args.help then
    print(help)
elseif args.toggle then
    newstate = not oldstate
    unit.flags3.gelded = newstate
    print(string.format("gelded: %s => %s\n", state(oldstate), state(newstate)))
elseif args.ungeld then
    unit.flags3.gelded = false
    print("unit ungelded.")
else
    unit.flags3.gelded = true
    print("unit gelded.")
end

function state(st)
    if st then
        return "true"
    else
        return "false"
    end
end
