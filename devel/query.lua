-- Query is a script useful for finding and reading values of data structure fields. Purposes will likely be exclusive to writing lua script code.
-- Written by Josh Cooper(cppcooper) on 2017-12-21, last modified: 2020-02-20
local utils=require('utils')
local validArgs = utils.invert({
 'help',
 'unit',
 'table',
 'query',
 'depth',
 'listkeys',
 'querykeys',
 'getkey',
 'set',
 'debug'
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
  [DFHack]# devel/query -table df.profession -querykeys WAR
  [DFHack]# devel/query -unit -query STRENGTH
  [DFHack]# devel/query -unit -query physical_attrs -listkeys
  [DFHack]# devel/query -unit -getkey id
~~~~~~~~~~~~~
selection options:
  These options are used to specify where the query will run,
  or specifically what key to print inside a unit.
    unit <value>       - Selects the highlighted unit when no value is provided.
                         With a value provided, _G[value] must exist.
    table <value>      - Selects the specivied table (ie. 'value').
                         Must use dot notation to denote sub-tables.
                         (eg. -table df.global.world)
    getkey <value>     - Gets the specified key from the selected unit.
                         Note: Must use the 'unit' option and doesn't support the
                         options below. Useful if there would be several matching
                         fields with the key as a substring (eg. 'id')
~~~~~~~~~~~~~
query options:
    query <value>      - Searches the selection for fields with substrings matching
                         the specified value.
    depth <value>      - Limits the query to the specified recursion depth.
    listkeys           - Lists all keys in any fields matching the query.
    querykeys <value>  - Lists only keys matching the specified value.

command options:
    set                - *CAREFUL* You can use this to set the value of matches.
                         Be advised there is minimal safety when using this option.
    help               - Prints this help information.

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
space_field="   "
space_key="     "
fN=0
--kN=25

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

function debugf(level,...)
    if args.debug and level <= tonumber(args.debug) then
        str=""
        for i = 1, select('#', ...) do
            str=string.format("%s\t%s",str,select(i, ...))
        end
        print(str)
    end
end

cur_depth = -1
N=0
function Query(t, query, parent)
    cur_depth = cur_depth + 1
    if not parent then
        parent = ""
    end
    if cur_depth == 0 and (args.listkeys or args.querykeys) then
        if not args.query or string.find(tostring(parent), args.query) then
            print_keys(parent,t,true)
        end
    end
    for k,v in safe_pairs(t) do
        -- avoid infinite recursion
        if not tonumber(k) and (type(k) ~= "table" or args.depth) and not string.find(tostring(k), 'script') then
            --print(parent .. "." .. k)
            if not string.find(parent, tostring(k)) then
                if not args.depth or (depth and cur_depth < depth) then
                    if parent then
                        Query(v, query, parent .. "." .. k)
                    else
                        Query(v, query, k)
                    end
                end
            end
            debugf(6,"main",parent,k,args.query)
            if not args.query or string.find(tostring(k), args.query) then
                if args.query or not args.querykeys then
                    debugf(5,"main->print_field")
                    print_field(string.format("%s.%s",parent,k),v,true)
                end
                if args.querykeys or args.listkeys then
                    debugf(3,"main->print_keys")
                    if not args.query and args.querykeys then
                        print_keys(string.format("%s.%s",parent,k),v,true)
                    else
                        print_keys(string.format("%s.%s",parent,k),v,false)
                    end
                end
            end
        end
    end
    cur_depth = cur_depth - 1
end

function print_field(field,v,ignoretype)
    debugf(5,"print_field")
    if ignoretype or not (type(v) == "userdata") then
        --print("Field","."..field)
        field=string.format("%s: ",field)
        cN=string.len(field)
        fN = cN >= fN and cN or fN
        fN = fN >= 90 and 90 or fN
        f="%-"..(fN+5).."s"
        print(space_field .. string.gsub(string.format(f,field),"   "," ~ ") .. tostring(v))
    end
end

bprinted=false
function print_key(k,v,bprint,parent,v0)
    debugf(5,"print_key")
    if not args.querykeys or string.find(tostring(k), args.querykeys) then
        debugf(4,k,v,bprint,parent,v0)
        if not bprinted and bprint then
            debugf(3,"print_key->print_field")
            print_field(parent,v0,true)
            bprinted=true
        end
        key=string.format("%s: ",k)
        -- cN=string.len(key)
        -- kN = cN >= kN and cN or kN
        -- kN = kN >= 90 and 90 or kN
        -- f="%-"..(kN+5).."s"
        print(space_key .. string.format("%s",key) .. tostring(v))
    end
end

function print_keys(parent,v,bprint)
    bprinted=false
    if type(v) == "table" and v._kind == "enum-type" then
        debugf(4,"keys.A")
        for i,e in ipairs(v) do
            if not args.querykeys or string.find(tostring(v[i]), args.querykeys) then
                if not bprinted and bprint then
                    print_field(parent,v,true)
                    bprinted=true
                end
                print(string.format("%s%-3d %s",space_key,i,e))
            end
        end
    elseif type(v) == "userdata" and not string.find(tostring(v),"userdata") and v._kind then
        --crash fix: string.find(...,"userdata") it seems that the crash was from hitting some ultra-primitive type (void* ?)
            --Not the best solution, but if duct tape works, why bother with sutures....
        --too much information, and it seems largely useless
        --todo: figure out a way to prune useless info OR add option (option suggestion: -floodconsole)
    else
        debugf(4,"keys.B",parent,v,type(v),bprint,bprinted)
        for k2,v2 in safe_pairs(v) do
            debugf(3,"keys.B.1")
            print_key(k2,v2,bprint,parent,v)
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
            Query(selection, '', 'selected-unit')
        end
    end
elseif args.table then
    local t = parseTableString(args.table)
    if args.query ~= nil then
        Query(t, args.query, args.table)
    else
        Query(t, '', args.table)
    end
else
    print(help)
end
