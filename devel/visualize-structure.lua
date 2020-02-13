-- Displays the raw memory of a structure, separated by field.
--author BenLubar
--
--[====[

devel/visualize-structure
=========================
Displays the raw memory of a structure, separated by field.
Useful for checking if structures are aligned.

]====]

local args = {...}

if #args ~= 1 then
    qerror([[Usage: devel/visualize-structure [path]

Displays the raw memory of a structure, separated by field.
Useful for checking if structures are aligned.]])
end

local utils = require('utils')

local ref = utils.df_expr_to_ref(args[1])
local size, baseaddr = ref:sizeof()

local ptrsz = dfhack.getArchitecture() / 8

local intptr = df.reinterpret_cast('uint' .. dfhack.getArchitecture() .. '_t', ref)
if intptr:_displace(-1).value & 0xffffffff == 0xdfdf4ac8 then
    local size2 = intptr:_displace(-2).value
    if size < size2 then
        size = size2
    end
end

local byteptr = df.reinterpret_cast('uint8_t', ref)
local offset = 0
local function bytes_until(target)
    while offset < target do
        dfhack.print(string.format('%02x', byteptr:_displace(offset).value))
        offset = offset + 1
        if offset % 4 == 0 then
            dfhack.print(' ')
        end
        if offset % 8 == 0 then
            dfhack.print(' ')
        end
    end
    print()
end
for k,v in pairs(ref) do
    local fsize, faddr = ref:_field(k):sizeof()
    local foff = faddr - baseaddr
    if offset < foff then
        print()
        if offset == 0 and foff == ptrsz then
            print('(vtable)')
        else
            print('(padding)')
        end
        bytes_until(foff)
    end

    print()
    print(tostring(ref:_field(k)._type) .. ' ' .. k)
    bytes_until(foff + fsize)
end

if offset < size then
    print()
    print('(padding)')
    bytes_until(size)
end
