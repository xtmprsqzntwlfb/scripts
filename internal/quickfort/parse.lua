-- file parsing logic for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local quickfort_common = reqscript('internal/quickfort/common')

-- adapted from example on http://lua-users.org/wiki/LuaCsv
function tokenize_csv_line(line)
    line = string.gsub(line, '[\r\n]*$', '')
    local tokens = {}
    local pos = 1
    local sep = ','
    while true do
        local c = string.sub(line, pos, pos)
        if c == '' then break end
        if c == '"' then
            -- quoted value (ignore separator within)
            local txt = ''
            repeat
                local startp, endp = string.find(line, '^%b""', pos)
                txt = txt .. string.sub(line, startp+1, endp-1)
                pos = endp + 1
                c = string.sub(line, pos, pos)
                if (c == '"') then txt = txt .. '"' end
                -- check first char AFTER quoted string, if it is another
                -- quoted string without separator, then append it
                -- this is the way to "escape" the quote char in a quote.
                -- example: "blub""blip""boing" -> blub"blip"boing
            until c ~= '"'
            table.insert(tokens, txt)
            assert(c == sep or c == '')
            pos = pos + 1
        else
            -- no quotes used, just look for the first separator
            local startp, endp = string.find(line, sep, pos)
            if startp then
                table.insert(tokens, string.sub(line, pos, startp-1))
                pos = endp + 1
            else
                -- no separator found -> use rest of string and terminate
                table.insert(tokens, string.sub(line, pos))
                break
            end
        end
    end
    return tokens
end

--[[
parses a Quickfort 2.0 modeline
example: '#dig (start 4;4;center of stairs) dining hall'
where all elements other than the initial #mode are optional (though if the
'start' block exists, the offsets must also exist)
returns a table in the format {mode, startx, starty, start_comment, comment}
or nil if the modeline is invalid
]]
function parse_modeline(modeline)
    if not modeline then return nil end
    local _, mode_end, mode = string.find(modeline, '^#([%l]+)')
    if not mode or not quickfort_common.valid_modes[mode] then
        print(string.format('invalid mode: %s', mode))
        return nil
    end
    local _, start_str_end, start_str = string.find(
        modeline, '%s+start(%b())', mode_end + 1)
    local startx, starty, start_comment = 1, 1, nil
    if start_str then
        _, _, startx, starty, start_comment = string.find(
            start_str, '^%(%s*(%d+)%s*;%s*(%d+)%s*;?%s*(.*)%)$')
        if not startx or not starty then
            print(string.format('invalid start offsets: %s', start_str))
            return nil
        end
    else
        start_str_end = mode_end
    end
    local _, _, comment = string.find(modeline, '%s*(.*)', start_str_end + 1)
    return {
        mode=mode,
        startx=startx,
        starty=starty,
        start_comment=start_comment,
        comment=comment
    }
end

local function get_col_name(col)
  if col <= 26 then
    return string.char(string.byte('A') + col - 1)
  end
  local div, mod = math.floor(col / 26), math.floor(col % 26)
  if mod == 0 then
      mod = 26
      div = div - 1
  end
  return get_col_name(div) .. get_col_name(mod)
end

local function make_cell_label(col_num, row_num)
    return get_col_name(col_num) .. tostring(math.floor(row_num))
end

-- returns a grid representation of the current section, the number of lines
-- read from the input, and the next z-level modifier, if any. See process_file
-- for grid format.
local function process_section(file, start_line_num, start_coord)
    local grid = {}
    local y = start_coord.y
    while true do
        local line = file:read()
        if not line then return grid, y-start_coord.y end
        for i, v in ipairs(tokenize_csv_line(line)) do
            if i == 1 then
                if v == '#<' then return grid, y-start_coord.y, 1 end
                if v == '#>' then return grid, y-start_coord.y, -1 end
            end
            if string.find(v, '^#') then break end
            if not string.find(v, '^[`~%s]*$') then
                -- cell has actual content, not just spaces or comment chars
                if not grid[y] then grid[y] = {} end
                local x = start_coord.x + i - 1
                local line_num = start_line_num + y - start_coord.y
                grid[y][x] = {cell=make_cell_label(i, line_num), text=v}
            end
        end
        y = y + 1
    end
end

--[[
returns the following logical structure:
  map of target map z coordinate ->
    list of {modeline, grid} tables
Where the structure of modeline is defined as per parse_modeline and grid is a:
  map of target y coordinate ->
    map of target map x coordinate ->
      {cell=spreadsheet cell, text=text from spreadsheet cell}
Map keys are numbers, and the keyspace is sparse -- only elements that have
contents are non-nil.
]]
function process_file(filepath, start_cursor_coord)
    local file = io.open(filepath)
    if not file then
        qerror(string.format('failed to open blueprint file: "%s"', filepath))
    end
    local line = file:read()
    local modeline = parse_modeline(tokenize_csv_line(line)[1])
    local cur_line_num = 2
    local x = start_cursor_coord.x - modeline.startx + 1
    local y = start_cursor_coord.y - modeline.starty + 1
    local z = start_cursor_coord.z
    local zlevels = {}
    while true do
        local grid, num_section_rows, zmod =
                process_section(file, cur_line_num, xyz2pos(x, y, z))
        for _, _ in pairs(grid) do
            -- apparently, the only way to tell if a sparse array is not empty
            if not zlevels[z] then zlevels[z] = {} end
            table.insert(zlevels[z], {modeline=modeline, grid=grid})
            break;
        end
        if zmod == nil then break end
        cur_line_num = cur_line_num + num_section_rows + 1
        z = z + zmod
    end
    file:close()
    return zlevels
end

