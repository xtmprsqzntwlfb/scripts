-- listanimals is a script useful in managing butchery and gelding of animals
-- Written by Josh Cooper(cppcooper) on 2020-02-18, last modified: 2020-02-18
local utils=require('utils')
local validArgs = utils.invert({
 'female',
 'male',
 'race',
 'showstats',
 'id',
 'markfor',
 'unmarkfor',
 'markedfor',
 'notmarkedfor',
 'gelded',
 'notgelded'
})
local args = utils.processArgs({...}, validArgs)
local help = [====[
listanimals
===========
List animals is a script developed for helping butcher and geld animals.
]====]

local Units = df.global.world.units.all
function safe_pairs(item, keys_only)
    if keys_only then
        local mt = debug.getmetatable(item)
        if mt and mt._index_table then
            local idx = 0
            return function()
                idx = idx + 1
                if mt._index_table[idx] then
                    return mt._index_table[idx]
                end
            end
        end
    end
    local ret = table.pack(pcall(function() return pairs(item) end))
    local ok = ret[1]
    table.remove(ret, 1)
    if ok then
        return table.unpack(ret)
    else
        return function() end
    end
end

count=0
if args.showstats then
    print(string.format("%-20s %-6s %-9s %-9s %-5s %-22s %-8s %-25s %-7s %-7s %-7s %-7s %-7s %-7s"
        , "animal type", "id", "unit id", "race id", "sex", "marked for slaughter", "gelded", "marked for gelding"
        ,"str","agi","tgh","endur","recup","disres"))
else
    print(string.format("%-20s %-6s %-9s %-9s %-5s %-22s %-8s %-25s"
        , "animal type", "id", "unit id", "race id", "sex", "marked for slaughter", "gelded", "marked for gelding"))
end
for k,v in safe_pairs(Units) do
    if v.civ_id == df.global.ui.civ_id and v.flags1.tame then
        if not (args.male or args.female) or args.male and v.sex == 1 or args.female and v.sex == 0 then
            if not args.race or tonumber(args.race) == v.race then
                if not args.markedfor or (args.markedfor == "slaughter" and v.flags2.slaughter) or (args.markedfor == "gelding" and v.flags3.marked_for_gelding) then
                    if not args.notmarkedfor or (args.notmarkedfor == "slaughter" and not v.flags2.slaughter) or (args.notmarkedfor == "gelding" and not v.flags3.marked_for_gelding) then
                        if not args.gelded or v.flags3.gelded then
                            if not args.notgelded or not v.flags3.gelded then
                                if not args.id or tonumber(args.id) == v.id then
                                    count = count + 1
                                    name = dfhack.units.isAdult(v) and df.global.world.raws.creatures.all[v.race].name[0] or dfhack.units.getRaceChildName(v)
                                    sex = v.sex == 1 and "M" or "F"
                                    if args.id and (args.markfor or args.unmarkfor) then
                                        if args.markfor then
                                            mark = args.markfor
                                            state = true
                                        else
                                            mark = args.unmarkfor
                                            state = false
                                        end

                                        if mark == "gelding" and sex == "M" then
                                            --print("geld",state)
                                            v.flags3.marked_for_gelding = state
                                        elseif mark == "slaughter" then
                                            --print("slaughter",state)
                                            v.flags2.slaughter = state
                                        end
                                    end
                                    attr = v.body.physical_attrs
                                    if v.sex == 1 then
                                        if args.showstats then
                                            print(string.format("%-20s %-6s %-9d %-9d %-5s %-22s %-8s %-25s %-7d %-7d %-7d %-7d %-7d %-7d"
                                                ,name,v.id,k,v.race,sex
                                                ,tostring(v.flags2.slaughter),tostring(v.flags3.gelded),tostring(v.flags3.marked_for_gelding)
                                                ,attr.STRENGTH.value,attr.AGILITY.value,attr.TOUGHNESS.value,attr.ENDURANCE.value,attr.RECUPERATION.value,attr.DISEASE_RESISTANCE.value))
                                        else
                                            print(string.format("%-20s %-6s %-9d %-9d %-5s %-22s %-8s %-25s"
                                                ,name,v.id,k,v.race,sex
                                                ,tostring(v.flags2.slaughter),tostring(v.flags3.gelded),tostring(v.flags3.marked_for_gelding)))
                                        end
                                    else
                                        if args.showstats then
                                            print(string.format("%-20s %-6s %-9d %-9d %-5s %-22s %-8s %-25s %-7d %-7d %-7d %-7d %-7d %-7d"
                                                ,name,v.id,k,v.race,sex
                                                ,tostring(v.flags2.slaughter),"-","-"
                                                ,attr.STRENGTH.value,attr.AGILITY.value,attr.TOUGHNESS.value,attr.ENDURANCE.value,attr.RECUPERATION.value,attr.DISEASE_RESISTANCE.value))
                                        else
                                            print(string.format("%-20s %-6s %-9d %-9d %-5s %-22s %-8s %-25s"
                                                ,name,v.id,k,v.race,sex
                                                ,tostring(v.flags2.slaughter),"-","-"))
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
if not args.id then
    if args.showstats then
        print(string.format("%-20s %-6s %-9s %-9s %-5s %-22s %-8s %-25s %-7s %-7s %-7s %-7s %-7s %-7s"
            , "animal type", "id", "unit id", "race id", "sex", "marked for slaughter", "gelded", "marked for gelding"
            ,"str","agi","tgh","endur","recup","disres"))
    else
        print(string.format("%-20s %-6s %-9s %-9s %-5s %-22s %-8s %-25s"
            , "animal type", "id", "unit id", "race id", "sex", "marked for slaughter", "gelded", "marked for gelding"))
    end
else
    print("")
end
print(string.format("total: %d", count))