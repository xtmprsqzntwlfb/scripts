-- ungelds animals
-- Written by Josh Cooper(cppcooper) on 2019-12-10, last modified: 2020-02-23
utils ={}
utils = require('utils')
local validArgs = utils.invert({
    'unit',
    'help'

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
    do return end
end

unit=nil

if args.unit then
    id=tonumber(args.unit)
    if id then
        for _,unit_ in pairs (df.global.world.units.active) do
            if unit_ and unit_.id == id then
                unit=unit_
            end
        end
    else
        qerror("Invalid id provided.")
    end
else
    unit = dfhack.gui.getSelectedUnit()
end

if not unit then
    qerror("Invalid unit selection.")
end

unit.flags3.gelded = false
function FindBodyPart(unit)
    bfound=false
    for i,wound in ipairs(unit.body.wounds) do
        for j,part in ipairs(wound.parts) do
            if type(unit.body.wounds[i].parts[j].flags2.gelded) ~= "nil" then
                bfound=true
                unit.body.wounds[i].parts[j].flags2.gelded=false
            else
                --print("no body part found")
            end
        end
    end
    return bfound
end
if not FindBodyPart(unit) then
    qerror("something went wrong")
end

print("unit ungelded.")