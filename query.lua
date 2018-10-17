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

function Query(table, query, parent)
    if not parent then
        parent = ""
    end
    for k,v in safe_pairs(table) do
        if not tonumber(k) and type(k) ~= "table" and not string.find(tostring(k), 'script') then
            if string.find(tostring(k), query) then
                print(parent .. "." .. k)
            end
            --print(parent .. "." .. k)
            if not string.find(parent, tostring(k)) then
                if parent then
                    Query(v, query, parent .. "." .. k)
                else
                    Query(v, query, k)
                end
            end
        end
    end
end
local selectedUnit = dfhack.gui.getSelectedUnit()
Query(selectedUnit, 'level','selected-unit')
print(selectedUnit.flags1.tame)
print(selectedUnit.training_level)
--print(selectedUnit.following.flags1.tame)
--print(selectedUnit.job.hunt_target.flags1.tame)
--Query(PimpData, '', 'pd')