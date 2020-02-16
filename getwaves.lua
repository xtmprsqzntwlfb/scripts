utils ={}
utils = require('utils')
local validArgs = utils.invert({
    'unit',
    'all',
    'show_wave_uids'
})
local args = utils.processArgs({...}, validArgs)

local ticks_per_day = 1200;
local ticks_per_month = 28 * ticks_per_day;
local ticks_per_season = 3 * ticks_per_month;
local ticks_per_year = 12 * ticks_per_month;
local current_tick = df.global.cur_year_tick
local seasons = {
    'spring',
    'summer',
    'autumn',
    'winter',
}
function TableLength(table)
    local count = 0
    for i,k in pairs(table) do
        count = count + 1
    end
    return count
end
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
--sorted pairs
function spairs(t, cmp)
    -- collect the keys
    local keys = {}
    for k,v in pairs(t) do
        table.insert(keys,k)
    end

    utils.sort_vector(keys, nil, cmp)
    
    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end
function isDwarfCitizen(dwf)
    return dfhack.units.isCitizen(dwf)
end



waves={}
function getWave(dwf)
    arrival_time = current_tick - dwf.curse.time_on_site;
    --print(string.format("Current year %s, arrival_time = %s, ticks_per_year = %s", df.global.cur_year, arrival_time, ticks_per_year))
    arrival_year = df.global.cur_year + (arrival_time // ticks_per_year);
    arrival_season = (arrival_time % ticks_per_year) // ticks_per_season;
    wave = 10 * arrival_year + arrival_season
    day = (wave % 100) + 1;
    month = (wave // 100) % 100;
    season = (wave // 10000) % 10;
    year = wave // 100000;
    if waves[wave] == nil then
        waves[wave] = {}
    end
    table.insert(waves[wave],dwf)
    --print(string.format("Arrived in the %s of the year %s. Wave %s, arrival time %s",seasons[season+1],year, wave, arrival_month))
end

selected = dfhack.gui.getSelectedUnit()
Units = df.global.world.units.active

for k,v in safe_pairs(Units) do
    if isDwarfCitizen(v) then
        getWave(v)
    end
end

zwaves = {}
i = 0
for k,v in spairs(waves, utils.compare) do
    if args.show_wave_uids then
        print(string.format("zwave[%s] = wave[%s]",i,k))
    end
    zwaves[i] = waves[k]
    i = i + 1
    for _,dwf in spairs(v, utils.compare) do
        if args.unit and dwf == selected then
            print(string.format("Unit belongs to wave %d",i))
        end
    end
end
    
if args.all then
    for i = 0, TableLength(zwaves)-1 do
        print(string.format("Wave %s has %d dwarves.", i, TableLength(zwaves[i])))
    end
end