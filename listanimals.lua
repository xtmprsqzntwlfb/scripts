local Units = df.global.world.units.active
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
for k,v in safe_pairs(Units) do
    if v.flags1.tame and v.civ_id == df.global.ui.civ_id and v.sex == 1 then
        print(k,v.race,v.flags3.gelded)
        v.flags3.gelded = true
    end
end
print("id      race    geld-status")