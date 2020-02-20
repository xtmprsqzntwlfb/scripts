-- Query is a script useful for finding and reading values of data structure fields. Purposes will likely be exclusive to writing lua script code.
-- Written by Josh Cooper(cppcooper) on 2017-12-21, last modified: 2020-02-18
local utils=require('utils')
local validArgs = utils.invert({
 'help',
 'unit',
 'table',
 'query',
 'depth',
 'listkeys',
 'getkey',
 'set',
})
local args = utils.processArgs({...}, validArgs)
local help = [====[
devel/query
===========
Query is a script useful for finding and reading values of data structure fields.
Purposes will likely be exclusive to writing lua script code.

This script can recursively search tables for fields matching the input query.
The root table can be specified explicitly, or a unit can be searched instead.
Any matching fields will be printed alongside their value.
If a match has sub-fields they too can be printed.

When performing table queries, use dot notation to denote sub-tables.
The script has to parse the input string and separate each table.

Examples:
  [DFHack]# devel/query -table df -query dead
  [DFHack]# devel/query -table df.global.ui.main -depth 0
  [DFHack]# devel/query -unit -query STRENGTH
  [DFHack]# devel/query -unit -query physical_attrs -listkeys
  [DFHack]# devel/query -unit -getkey id
~~~~~~~~~~~~~
selection options:
  These options are used to specify where the query will run, or specifically what key to print inside a unit.
    unit <value>   - Selects the highlighted unit when no value is provided.
                     With a value provided, _G[value] must exist.
    table <value>  - Selects the specivied table (ie. 'value').
                     Must use dot notation to denot sub-tables. (eg. -table df.global.world)
    getkey <value> - Gets the specified key from the selected unit.
                     Note: Must use the 'unit' option and doesn't support the options below.
                     Useful if there would be several matching fields with the key as a substring (eg. 'id')
~~~~~~~~~~~~~
query options:
    query <value>  - Searches the selection for fields with substrings matching the specified value.
    depth <value>  - Limits the query to the specified recursion depth.
    listkeys       - Lists all keys in any fields matching the query.

command options:
    set            - *CAREFUL* You can use this to set the value of matches.
                     Be advised there is minimal safety when using this option.
    help           - Prints this help information.

]====]
newvalue=nil
depth=nil
if args.set then
    newvalue=tonumber(args.set)
    if type(newvalue) ~= 'number' then
        if args.set == 'true' then
            newvalue=true
        elseif args.set == 'false' then
            newvalue=false
        else
            newvalue=args.set
        end
    end
elseif args.depth then
    depth = tonumber(args.depth)
end

--thanks goes mostly to the internet for this function. thanks internet you da real mvp
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

cur_depth = -1
N=0
function Query(t, query, parent)
    cur_depth = cur_depth + 1
    if not parent then
        parent = ""
    end
    if cur_depth == 0 and args.listkeys then
        list_keys(nil,nil,t)
    end
    for k,v in safe_pairs(t) do
        -- avoid infinite recursion
        if not tonumber(k) and (type(k) ~= "table" or args.depth) and not string.find(tostring(k), 'script') then
            --print(parent .. "." .. k)
            if not string.find(parent, tostring(k)) then
                if not args.depth or (depth and cur_depth < depth) then
                    if parent then
                        N=Query(v, query, parent .. "." .. k)
                    else
                        N=Query(v, query, k)
                    end
                end
            end
            if string.find(tostring(k), query) then
                p=string.format("%s.%s: ",parent,k)
                cN=string.len(p)
                N = cN >= N and cN or N
                N = N >= 90 and 90 or N
                f="%-"..(N+5).."s"
                if (N - cN) >= 20 then
                    print(string.gsub(string.format(f,p),"   "," ~ ") .. tostring(v))
                else
                    print(string.format(f,p) .. tostring(v))
                end
                if args.listkeys then
                    list_keys(t,k,v,parent)
                elseif args.set and type(t[k]) == type(newvalue) then
                    t[k] = newvalue
                    print("new value:", newvalue)
                elseif args.set then
                    print("error: invalid type given")
                    print("given: " .. type(newvalue))
                    print("expected: " .. type(t[k]))
                end
            end
        end
    end
    cur_depth = cur_depth - 1
    return N
end

function list_keys(t,k,v,parent)
    if v ~= nil and type(v) == "table" and v._kind == "enum-type" then
        for i=0,400 do
            if type(v[i]) ~= "nil" then
                print(string.format(" %-3d %s",i,v[i]))
            end
        end
    elseif t ~= nil and k ~= nil then
        for k2,v2 in safe_pairs(t[k]) do
            p=string.format("%s.%s.%s:",parent,k,k2)
            cN=string.len(p)
            N = cN >= N and cN or N
            f="%-"..(N+5).."s"
            if (N - cN) >= 20 then
                print(string.gsub(string.format(f,p),"   "," ~ ") .. tostring(v2))
            else
                print(string.format(f,p) .. tostring(v2))
            end
        end
    end
end

function parseTableString(str)
    tableParts = {}
    for word in string.gmatch(str, '([^.]+)') do --thanks stack overflow
        table.insert(tableParts, word)
    end
    curTable = nil
    for k,v in pairs(tableParts) do
      if curTable == nil then
        if _G[v] ~= nil then
            curTable = _G[v]
        else
            qerror("Table" .. v .. " does not exist.")
        end
      else
        if curTable[v] ~= nil then
            curTable = curTable[v]
        else
            qerror("Table" .. v .. " does not exist.")
        end
      end
    end
    return curTable
end

function parseKeyString(t,str)
    curTable = t
    keyParts = {}
    for word in string.gmatch(str, '([^.]+)') do --thanks stack overflow
        table.insert(keyParts, word)
    end
    for k,v in pairs(keyParts) do
        if curTable[v] ~= nil then
            curTable = curTable[v]
        else
            qerror("Table" .. v .. " does not exist.")
        end
    end
    return curTable
end

local selection = nil
if args.help then
    print(help)
elseif args.unit then
    if _G[args.unit] ~= nil then
        selection = _G[args.unit]
    else
        selection = dfhack.gui.getSelectedUnit()
    end
    if args.getkey then
        print("selected-unit."..args.getkey..": ",parseKeyString(selection,args.getkey))
    else
        if selection == nil then
            qerror("Selected unit is null. Invalid selection.")
        elseif args.query ~= nil then
            Query(selection, args.query, 'selected-unit')
        else
            print("The query is empty, the output is probably gonna be large. Start your engines.")
            Query(selection, '', 'selected-unit')
        end
    end
elseif args.table then
    local t = parseTableString(args.table)
    if args.query ~= nil then
        Query(t, args.query, args.table)
    else
        print("The query is empty, the output is probably gonna be large. Start your engines.")
        Query(t, '', args.table)
    end
else
    print(help)
end
