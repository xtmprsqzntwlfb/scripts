-- Gelds animals by default. Optional args: -toggle or -ungeld
-- Written by Josh Cooper(cppcooper) on 2019-12-10, last modified: 2020-02-23
utils ={}
utils = require('utils')
local validArgs = utils.invert({
    'unit',
    'toggle',
    'ungeld',
    'help',
    'find'

})
local args = utils.processArgs({...}, validArgs)
local help = [====[

geld
====
Geld allows the user to geld and ungeld animals.

Valid options:
    unit <id> - Performs action on the provided unit id, this is optional.
                If this argument is not given, the highlighted unit is
                used instead.

    toggle    - Changes the geld status to the opposite of its current state
    ungeld    - Sets the geld status to false
    help      - Shows this help information

]====]

unit=nil

if args.unit then
    id=tonumber(args.unit)
    if id then
        for _,unit_ in pairs (df.global.world.units.active) do
            if unit.id == id then
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

oldstate = unit.flags3.gelded

if unit.sex == 0 then
    qerror("cannot geld female animals")
    return
end

function exists(thing)
    if thing then return true else return false end
end

function FindBodyPart(unit,newstate)
    bfound=false
    for i,wound in ipairs(unit.body.wounds) do
        for j,part in ipairs(wound.parts) do
            if type(unit.body.wounds[i].parts[j].flags2.gelded) ~= "nil" then
                bfound=true
                if type(newstate) ~= "nil" then
                    unit.body.wounds[i].parts[j].flags2.gelded=newstate
                end
            else
                --print("no body part found")
            end
        end
    end
    return bfound
end

function AddParts(unit)
    for i,wound in ipairs(unit.body.wounds) do
        if wound.id == 1 and #wound.parts == 0 then
            utils.insert_or_update(unit.body.wounds[i].parts,{ new = true, body_part_id = 1 }, 'body_part_id')
        end
    end
end

function Geld(unit)
    if not FindBodyPart(unit,true) then
        utils.insert_or_update(unit.body.wounds,{ new = true, id = 1 }, 'id')
        AddParts(unit)
        if not FindBodyPart(unit,true) then
            error("sorry, don't know what went wrong.. but the command didn't work")
        end
    end
end

function Ungeld(unit)
    FindBodyPart(unit,false)
end

if args.find then
    FindBodyPart(unit)
    return
end

if args.help then
    print(help)
elseif args.toggle then
    newstate = not oldstate
    unit.flags3.gelded = newstate
    print(string.format("gelded unit %s: %s => %s\n", unit.id, state(oldstate), state(newstate)))
elseif args.ungeld then
    unit.flags3.gelded = false
    print(string.format("unit %s ungelded.",unit.id))
else
    unit.flags3.gelded = true
    print(string.format("unit %s gelded.",unit.id))
end

if unit.flags3.gelded then
    Geld(unit)
else
    Ungeld(unit)
end

function state(st)
    if st then
        return "true"
    else
        return "false"
    end
end
