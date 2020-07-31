-- building-related logic for the quickfort build and place modules
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local quickfort_common = reqscript('internal/quickfort/common')
local log = quickfort_common.log
local logfn = quickfort_common.logfn

-- maps building boundaries, returns number of invalid keys seen
-- populates seen_grid coordinates with the building id so we can build an
-- extent_grid later. spreadsheet cells that define extents (e.g. a(5x5)) create
-- buildings separate from adjacent cells, even if they have the same type.
local function flood_fill(grid, x, y, seen_grid, data, db)
    if seen_grid[x] and seen_grid[x][y] then return 0 end
    if not grid[y] or not grid[y][x] then return 0 end
    local cell, text = grid[y][x].cell, grid[y][x].text
    local keys, extent = quickfort_common.parse_cell(text)
    if not db[keys] then
        if not seen_grid[x] then seen_grid[x] = {} end
        seen_grid[x][y] = true -- seen, but not part of any stockpile
        print(string.format('invalid key sequence in cell %s: "%s"',
                            cell, text))
        return 1
    end
    if data.type and (data.type ~= keys or extent.specified) then return 0 end
    log('mapping spreadsheet cell %s with text "%s"', cell, text)
    if not data.type then data.type = keys end
    table.insert(data.cells, cell)
    for target_x=x,x+extent.width-1 do
        for target_y=y,y+extent.height-1 do
            if not seen_grid[target_x] then seen_grid[target_x] = {} end
            -- this may overlap with another building, but that's handled later
            seen_grid[target_x][target_y] = data.id
            if target_x < data.x_min then data.x_min = target_x end
            if target_x > data.x_max then data.x_max = target_x end
            if target_y < data.y_min then data.y_min = target_y end
            if target_y > data.y_max then data.y_max = target_y end
        end
    end
    if not extent.specified then
        return flood_fill(grid, x-1, y, seen_grid, data, db) +
                flood_fill(grid, x+1, y, seen_grid, data, db) +
                flood_fill(grid, x, y-1, seen_grid, data, db) +
                flood_fill(grid, x, y+1, seen_grid, data, db)
    end
    return 0
end

local function swap_id(data, seen_grid, from_id)
    for x=data.x_min,data.x_max do
        for y=data.y_min,data.y_max do
            if seen_grid[x][y] == from_id then
                seen_grid[x][y] = data.id
            end
        end
    end
end

-- split extents that are larger than their max_width into parts
local function split_by_width(data_tables, seen_grid, db)
    local trimmings = {}
    for _, data in ipairs(data_tables) do
        local width = data.x_max - data.x_min + 1
        local max_width = db[data.type].max_width
        local cuts = 0
        while width > max_width do
            cuts = cuts + 1
            local data_copy = copyall(data)
            data_copy.id = #data_tables + #trimmings + 1
            data_copy.x_max = data.x_min + max_width - 1
            data.x_min = data_copy.x_max + 1
            swap_id(data_copy, seen_grid, data.id)
            table.insert(trimmings, data_copy)
            width = width - max_width
        end
        if cuts > 0 then
            log('building/stockpile too wide; splitting into %d parts ' ..
                '(defined in spreadsheet cells %s)',
                cuts+1, table.concat(data.cells, ', '))
        end
    end
    for _, v in ipairs(trimmings) do table.insert(data_tables, v) end
end

-- split extents that are larger than their max_height into parts
local function split_by_height(data_tables, seen_grid, db)
    trimmings = {}
    for _, data in ipairs(data_tables) do
        local height = data.y_max - data.y_min + 1
        local max_height = db[data.type].max_height
        local cuts = 0
        while height > max_height do
            cuts = cuts + 1
            local data_copy = copyall(data)
            data_copy.id = #data_tables + #trimmings + 1
            data_copy.y_max = data.y_min + max_height - 1
            data.y_min = data_copy.y_max + 1
            swap_id(data_copy, seen_grid, data.id)
            table.insert(trimmings, data_copy)
            height = height - max_height
        end
        if cuts > 0 then
            log('building/stockpile too tall; splitting into %d parts ' ..
                '(defined in spreadsheet cells %s)',
                cuts+1, table.concat(data.cells, ', '))
        end
    end
    for _, v in ipairs(trimmings) do table.insert(data_tables, v) end
end

-- expand multi-tile buildings that are less than their min dimensions around
-- their current center
local function expand_buildings(data_tables, seen_grid, db)
    for _, data in ipairs(data_tables) do
        if db[data.type].has_extents then goto continue end
        local width = data.x_max - data.x_min + 1
        local height = data.y_max - data.y_min + 1
        local min_width = db[data.type].min_width
        local min_height = db[data.type].min_height
        if width < min_width then
            local center_x = math.floor((data.x_min + data.x_max) / 2)
            data.x_min = math.ceil(center_x - min_width / 2)
            data.x_max = data.x_min + min_width - 1
        end
        if height < min_height then
            local center_y = math.floor((data.y_min + data.y_max) / 2)
            data.y_min = math.ceil(center_y - min_height / 2)
            data.y_max = data.y_min + min_height - 1
        end
        for x=data.x_min,data.x_max do
            if not seen_grid[x] then seen_grid[x] = {} end
            for y=data.y_min,data.y_max do
                -- expand into unclaimed tiles
                if not seen_grid[x][y] then seen_grid[x][y] = data.id end
            end
        end
        ::continue::
    end
end

local function get_digit_count(num)
    local num_digits = 1
    while num >= 10 do
        num = num / 10
        num_digits = num_digits + 1
    end
    return num_digits
end

local function left_pad(num, width)
    local num_digit_count = get_digit_count(num)
    local ret = ''
    for i=num_digit_count,width do
        ret = ret .. ' '
    end
    return ret .. tostring(num)
end

-- pretty-prints the populated range of the seen_grid
local function dump_seen_grid(args)
    local seen_grid, max_id = args[1], args[2]
    local x_min, x_max, y_min, y_max = 30000, -30000, 30000, -30000
    for x, row in pairs(seen_grid) do
        if x < x_min then x_min = x end
        if x > x_max then x_max = x end
        for y, _ in pairs(row) do
            if y < y_min then y_min = y end
            if y > y_max then y_max = y end
        end
    end
    print('building/stockpile boundary map:')
    local field_width = get_digit_count(max_id)
    local blank = string.rep(' ', field_width+1)
    for y=y_min,y_max do
        local line = ''
        for x=x_min,x_max do
            if seen_grid[x] and tonumber(seen_grid[x][y]) then
                line = line .. left_pad(seen_grid[x][y], field_width)
            else
                line = line .. blank
            end
        end
        print(line)
    end
end

local function build_extent_grid(seen_grid, data)
    local extent_grid, num_tiles = {}, 0
    for x=data.x_min,data.x_max do
        local extent_x = x - data.x_min + 1
        extent_grid[extent_x] = {}
        for y=data.y_min,data.y_max do
            local extent_y = y - data.y_min + 1
            extent_grid[extent_x][extent_y] = seen_grid[x][y] == data.id
            if extent_grid[extent_x][extent_y] then
                num_tiles = num_tiles + 1
            end
        end
    end
    local width = data.x_max - data.x_min + 1
    local height = data.y_max - data.y_min + 1
    return num_tiles > 0 and extent_grid or nil,
            num_tiles == width * height
end

-- build boundaries and extent maps from blueprint grid input
function init_buildings(zlevel, grid, buildings, db)
    local invalid_keys = 0
    local data_tables = {}
    local seen_grid = {} -- [x][y] -> id
    for y, row in pairs(grid) do
        for x, cell_and_text in pairs(row) do
            if seen_grid[x] and seen_grid[x][y] then goto continue end
            local data = {
                id=#data_tables+1, type=nil, cells={},
                x_min=30000, x_max=-30000, y_min=30000, y_max=-30000
            }
            invalid_keys = invalid_keys +
                    flood_fill(grid, x, y, seen_grid, data, db)
            if data.type then table.insert(data_tables, data) end
            ::continue::
        end
    end
    split_by_width(data_tables, seen_grid, db)
    split_by_height(data_tables, seen_grid, db)
    expand_buildings(data_tables, seen_grid, db)
    logfn(dump_seen_grid, seen_grid, #data_tables)
    for _, data in ipairs(data_tables) do
        local extent_grid, is_solid = build_extent_grid(seen_grid, data)
        if not extent_grid then
            log('building/stockpile completely overwritten by other elements' ..
                ' (defined in spreadsheet cells %s)',
                table.concat(data.cells, ', '))
        elseif not db[data.type].has_extents and not is_solid then
            log('building partially overwritten by other buildings, and it ' ..
                ' cannot be built unless all tiles are free (defined in ' ..
               'spreadsheet cells %s)', table.concat(data.cells, ', '))
        else
            table.insert(buildings,
                         {type=data.type,
                          cells=data.cells,
                          pos=xyz2pos(data.x_min, data.y_min, zlevel),
                          width=data.x_max-data.x_min+1,
                          height=data.y_max-data.y_min+1,
                          extent_grid=extent_grid})
        end
    end
    return invalid_keys
end

local function is_on_map_x(x)
    return quickfort_common.is_within_map_bounds_x(x) or
            quickfort_common.is_on_map_edge_x(x)
end

local function is_on_map_y(y)
    return quickfort_common.is_within_map_bounds_y(y) or
            quickfort_common.is_on_map_edge_y(y)
end

local is_on_map_z = quickfort_common.is_within_map_bounds_z

-- check bounds against size limits and map edges, adjust pos, width, height,
-- and extent_grid accordingly. marks invalid buildings that are cropped below
-- their minimum dimensions
-- assumes b.width and b.height > 0 if b.pos is not nil
function crop_to_bounds(buildings, db)
    local out_of_bounds_tiles = 0
    for _, b in ipairs(buildings) do
        if not b.pos then goto continue end
        -- if pos is off the map, crop and move pos until we're ok (or empty)
        while b.pos and
                (not is_on_map_x(b.pos.x) or not is_on_map_z(b.pos.z)) do
            for extent_y=1,b.height do
                if b.extent_grid[1][extent_y] then
                    out_of_bounds_tiles = out_of_bounds_tiles + 1
                end
            end
            -- change extent_grid to a linked list if this gets too slow
            table.remove(b.extent_grid, 1)
            b.width = b.width - 1
            b.pos.x = b.pos.x + 1
            if b.width < db[b.type].min_width then b.pos = nil end
        end
        while b.pos and not is_on_map_y(b.pos.y) do
            for extent_x=1,b.width do
                if b.extent_grid[extent_x][1] then
                    out_of_bounds_tiles = out_of_bounds_tiles + 1
                end
                table.remove(b.extent_grid[extent_x], 1)
            end
            b.height = b.height - 1
            b.pos.y = b.pos.y + 1
            if b.height < db[b.type].min_height then b.pos = nil end
        end
        -- if building extends off map to bottom or right, just crop
        while b.pos and not is_on_map_x(b.pos.x+b.width-1) do
            for extent_y=1,b.height do
                if b.extent_grid[b.width][extent_y] then
                    out_of_bounds_tiles = out_of_bounds_tiles + 1
                end
            end
            b.extent_grid[b.width] = nil
            b.width = b.width - 1
            if b.width < db[b.type].min_width then b.pos = nil end
        end
        while b.pos and not is_on_map_y(b.pos.y+b.height-1) do
            for extent_x=1,b.width do
                if b.extent_grid[extent_x][b.height] then
                    out_of_bounds_tiles = out_of_bounds_tiles + 1
                end
                b.extent_grid[extent_x][b.height] = nil
            end
            b.height = b.height - 1
            if b.height < db[b.type].min_height then b.pos = nil end
        end
        if not b.pos then
            log('building/stockpile not within map bounds, defined from ' ..
                'spreadsheet cells: %s', table.concat(b.cells, ', '))
        end
        ::continue::
    end
    return out_of_bounds_tiles
end

-- check tiles for validity, adjust the extent_grid, and checks the validity of
-- the adjusted extent_grid. marks building as invalid if the extent_grid is
-- invalid.
function check_tiles_and_extents(buildings, db)
    local occupied_tiles = 0
    for _, b in ipairs(buildings) do
        if not b.pos then goto continue end
        for extent_x, col in ipairs(b.extent_grid) do
            for extent_y, in_extent in ipairs(col) do
                if not b.extent_grid[extent_x][extent_y] then goto continue end
                local pos =
                        xyz2pos(b.pos.x+extent_x-1, b.pos.y+extent_y-1, b.pos.z)
                if not db[b.type].is_valid_tile_fn(pos) then
                    log('tile occupied: (%d, %d, %d)', pos.x, pos.y, pos.z)
                    b.extent_grid[extent_x][extent_y] = false
                    occupied_tiles = occupied_tiles + 1
                end
                ::continue::
            end
        end
        if not db[b.type].is_valid_extent_fn(b) then
            log('no room for %s at (%d, %d, %d)',
                db[b.type].label, b.pos.x, b.pos.y, b.pos.z)
            b.pos = nil
        end
        ::continue::
    end
    return occupied_tiles
end

-- allocate and initialize extents structure from the extents_grid
-- returns extents, num_tiles
-- we assume by this point that the extent is valid and non-empty
function make_extents(b, db)
    local area = b.width * b.height
    local extents = df.new('uint8_t', area)
    local num_tiles = 0
    for i=1,area do
        local extent_x = (i-1) % b.width + 1
        local extent_y = math.floor((i-1) / b.width) + 1
        local is_in_stockpile = b.extent_grid[extent_x][extent_y]
        extents[i-1] = is_in_stockpile and 1 or 0
        if is_in_stockpile then num_tiles = num_tiles + 1 end
    end
    return extents, num_tiles
end
