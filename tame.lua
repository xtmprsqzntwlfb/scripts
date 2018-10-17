-- tame and train animals {set animals as Wild through to Masterfully Trained}

local help=[====[
tame
====
Tame and train animals.

Usage: tame -set <level>

:0: wild
:1: trained
:2: well-trained
:3: skillfully trained
:4: expertly trained
:5: exceptionally trained
:6: masterfully trained
:7: tame
:8: semi-wild
]====]

local utils = require('utils')
local selected = dfhack.gui.getSelectedUnit()
local validArgs = utils.invert({'set'})
local args = utils.processArgs({...}, validArgs)
--[
if args.set and tonumber(args.set) then
    local level = tonumber(args.set)
    if level < 0 or level > 8 then
        print(help)
        error("range must be 0 to 9")
    end
    selected.flags1.tame = level ~= 0
    selected.training_level = level
else
    print(help)
end
--]]

