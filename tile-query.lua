-- Tile is a script useful reading fields for a highlighted tile. It can be used to query specific fields also.
-- Written by Josh Cooper(cppcooper) on 2017-12-21, last modified: 2020-02-20
local utils=require('utils')
local validArgs = utils.invert({
    'query',
    'querykeys',
    'help'
})

local args = utils.processArgs({...}, validArgs)
local help = [====[

tile-query
==========
Tile Query is a script useful for finding and reading fields for a highlighted
tile. I've found it useful in conjunction with 'settile' for turning dirt walls
into smooth walls, or at least so that they share the same sprite.

This script can recursively search tables for fields matching the input query.
Any matching fields will be printed alongside their value.
If a match has sub-fields(keys) they too will be printed.

When performing table queries, use dot notation to denote sub-tables.
The script has to parse the input string and separate each table.

Examples:
  [DFHack]# tile-query
  [DFHack]# tile-query -query type
  [DFHack]# tile-query -querykeys temp
  [DFHack]# tile-query -query designation -querykeys liquid

]====]
space_field="   "
space_key="     "
fN=70
--kN=25

--print(args.query,args.querykeys)

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
function Query(t, query, parent)
    cur_depth = cur_depth + 1
    if not parent then
        parent = ""
    end
    if cur_depth == 0 and (args.listkeys or args.querykeys) then
        list_keys(nil,nil,t,parent)
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
            if not args.query and args.querykeys then
                --print keys and their parent field
                print_keys(string.format("%s.%s",parent,k),v,true)
            elseif not args.query or string.find(tostring(k), query) then
                --print field and keys
                print_field(string.format("%s.%s",parent,k),v)
                print_keys(string.format("%s.%s",parent,k),v,true)
            end
        end
    end
    cur_depth = cur_depth - 1
end

function print_field(field,v,ignoretype)
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
    if not args.querykeys or string.find(tostring(k), args.querykeys) then
        if not bprinted and bprint then
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
    --print(t,k,type(v),parent)
    if type(v) == "userdata" then
        if v._kind == "container" then
            --print("A")
            for ix,v2 in ipairs(v) do
                if ix == x and type(v2) == "userdata" and v2._kind == "container" then
                    for iy,v3 in ipairs(v2) do
                        if iy == y then
                            --print("A.1")
                            if type(v3) == "userdata" then
                                for k4,v4 in pairs(v3) do
                                    print_key(k4,v4,true,parent,v3)
                                end
                            elseif type(v3) ~= nil and (not args.querykeys or string.find(tostring(k3),args.querykeys)) then
                                print_field(string.format("%s[%d][%d]",parent,x,y),v3,true)
                            end
                        end
                    end
                end
            end
        elseif v._kind == "bitfield" then
        end
    end
end

pos = copyall(df.global.cursor)
x = pos.x%16
y = pos.y%16
block = dfhack.maps.ensureTileBlock(pos.x,pos.y,pos.z)
Query(block, args.query, string.format("dfhack.maps.ensureTileBlock(%d,%d,%d)",pos.x,pos.y,pos.z))
print(string.format("   tile type (tileset): %d",block.tiletype[x][y]))
