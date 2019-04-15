-- Optimize dwarves for fort-mode work. Buff your dwarves and make your life easier in managing labours.
-- written by josh cooper(cppcooper) [created: 12-2017 | last edited: 12-2018]
--[====[
dwarf-op
========
Optimize dwarves for fort-mode work.
The core function takes dwarves and allocates a "job" to each dwarf.
This decision takes into account current counts for each job, in
relation to how many should be allocated based on the working population
size. Jobs involve required professions, tertiary professions (may or
may not be applied), and types which come along with attribute buffs
and characteristics (eg. strength, speed, focus, dodging, etc)

Usage: ``dwarf-op -help`` or ``dwarf-op -select <sel-opt> -<command> <args>``

:help:               Highly detailed help documentation.
:select <option>:    Indicates the next parameter will be indicate which dwarves to select
]====]

print("v1.2")
utils ={}
utils = require('utils')
json = require('json')
local rng = require('plugins.cxxrandom')
local engineID = rng.MakeNewEngine()
local dorf_tables = reqscript('dorf_tables')
cloned = {} --assurances I'm sure
cloned = {
    distributions = utils.clone(dorf_tables.job_distributions, true),
    attrib_levels = utils.clone(dorf_tables.attrib_levels, true),
    types = utils.clone(dorf_tables.types, true),
    jobs = utils.clone(dorf_tables.jobs, true),
    professions = utils.clone(dorf_tables.professions, true),
}
print("Done.")
local validArgs = utils.invert({
    'help',
    'debug',
    'show',
    'reset',
    'resetall',

    'select', --highlighted --all --named --unnamed --employed --optimized --unoptimized --protected --unprotected --drunks --jobs
    'clear',
    'reroll',
    'optimize',

    'applyjobs',
    'applyprofessions',
    'applytypes'
})
local args = utils.processArgs({...}, validArgs)
if args.debug and tonumber(args.debug) >= 0 then print("Debug info [ON]") end
protected_dwarf_signals = {'.', 'c', 'j', 'p'}
if args.select and args.select == 'optimized' then
    if args.optimize and not args.clear then
        error("Invalid arguments detected. You've selected only optimized dwarves, and are attempting to optimize them without clearing them. This will not work, so I'm warning you about it with this lovely error.")
    end
end

--[[--
The persistent data contains information on current allocations

FileData: {
    Dwarves : {
        id : {
            job : dorf_table.dorf_jobs[job],
            professions : [
                dorf_table.professions[prof],
            ]
        },
    },
    dorf_table.dorf_jobs[job] : {
        count : int,
        profs : {
            dorf_table.professions[prof] : {
                count : int,
                p : float  --intended ratio of profession in job
            },
        }
    }
}
--]]--
function LoadPersistentData()
    local gamePath = dfhack.getDFPath()
    local fortName = dfhack.TranslateName(df.world_site.find(df.global.ui.site_id).name)
    local savePath = dfhack.getSavePath()
    local fileName = fortName .. ".json.dat"
    local file_cur = gamePath .. "/data/save/current/" .. fileName
    local file_sav = savePath .. "/" .. fileName
    local cur = json.open(file_cur)
    local saved = json.open(file_sav)
    if saved.exists == true and cur.exists == false then
        print("Previous session save data found. [" .. file_sav .. "]")
        cur.data = saved.data
    elseif saved.exists == false then
        print("No session data found. All dwarves will be treated as non-optimized.")
        --saved:write()
    elseif cur.exists == true then
        print("Existing session data found. [" .. file_cur .. "]")
    end
    OpData = cur.data
end

function SavePersistentData()
    local gamePath = dfhack.getDFPath()
    local fortName = dfhack.TranslateName(df.world_site.find(df.global.ui.site_id).name)
    local fileName = fortName .. ".json.dat"
    local cur = json.open(gamePath .. "/data/save/current/" .. fileName)
    local newDwfTable = {}
    for k,v in pairs(OpData.Dwarves) do
        if v~=nil then
            newDwfTable[k] = v
        end
    end
    OpData.Dwarves = newDwfTable
    cur.data = OpData
    cur:write()
end

function ClearPersistentData(all)
    local gamePath = dfhack.getDFPath()
    local fortName = dfhack.TranslateName(df.world_site.find(df.global.ui.site_id).name)
    local savePath = dfhack.getSavePath()
    local fileName = fortName .. ".json.dat"
    local file_cur = gamePath .. "/data/save/current/" .. fileName
    local file_sav = savePath .. "/" .. fileName
    print("Deleting " .. file_cur)
    os.remove(file_cur)
    if all then
        print("Deleting " .. file_sav)
        os.remove(file_sav)
    end
end

function safecompare(a,b)
    if a == b then
        return 0
    elseif tonumber(a) and tonumber(b) then
        if a < b then
            return -1
        elseif a > b then
            return 1
        end
    elseif tonumber(a) then
        return 1
    else
        return -1
    end
end

function twofield_compare(t,v1,v2,f1,f2,cmp1,cmp2)
    local a = t[v1]
    local b = t[v2]
    local c1 = cmp1(a[f1],b[f1])
    local c2 = cmp2(a[f2],b[f2])
    if c1 == 0 then
        return c2
    end
    return c1
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

--random pairs
function rpairs(t, gen)
    -- collect the keys
    local keys = {}
    for k,v in pairs(t) do
        table.insert(keys,k)
    end
    
    -- return the iterator function
    return function()
        local i = gen:next()
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function GetChar(str,i)
    return string.sub(str,i,i)
end

function DisplayTable(t,recursion)
    if recursion == nil then
        print('###########################')
        print(t)
        print('######')
        recursion = 0
    elseif recursion == 1 then
        print('-------------')
    elseif recursion == 2 then
        print('-------')
    elseif recursion == 3 then
        print('---')
    end
    for i,k in pairs(t) do
        if type(k) ~= "table" then
            print(i,k)
        end
    end
    for i,k in pairs(t) do
        if type(k) == "table" then
            print(i,k)
            DisplayTable(k,recursion+1)
            if recursion >= 2 then
                print('')
            elseif recursion == 0 then
                print('######')
            end
        end
    end
    if recursion == nil then
        print('###########################')
    end
end

function TableToString(t)
    local s = '['
    local n=0
    for k,v in pairs(t) do
        n=n+1
        if n ~= 1 then
            s = s .. ", "
        end
        s = s .. tostring(v)
    end
    s = s .. ']'
    return s
end

function count_this(to_be_counted)
    local count = -1
    local var1 = ""
    while var1 ~= nil do
        count = count + 1
        var1 = (to_be_counted[count])
    end
    count=count-1
    return count
end

function ArrayLength(t)
    local count = 0
    for i,k in pairs(t) do
        if tonumber(i) then
            count = count + 1
        end
    end
    return count
end

function TableLength(table)
    local count = 0
    for i,k in pairs(table) do
        count = count + 1
    end
    return count
end

function FindValueKey(t, value)
    for k,v in pairs(t) do
        if v == value then
            return k
        end
    end
end

function FindKeyValue(t, key)
    for k,v in pairs(t) do
        if k == key then
            return v
        end
    end
end

function GetRandomTableEntry(gen, t)
    -- iterate over whole table to get all keys
    local keyset = {}
    for k in pairs(t) do
        table.insert(keyset, k)
    end
    -- now you can reliably return a random key
    local N = TableLength(t)
    local i = gen:next()
    local key = keyset[i]
    local R = t[key]
    if args.debug and tonumber(args.debug) >= 3 then print(N,i,key,R) end
    return R
end

local attrib_seq = rng.num_sequence:new(1,TableLength(cloned.attrib_levels))
function GetRandomAttribLevel() --returns a randomly generated value for assigning to an attribute
    local gen = rng.crng:new(engineID,false,attrib_seq)
    gen:shuffle()
    while true do
        local level = GetRandomTableEntry(gen, cloned.attrib_levels)
        if rng.rollBool(engineID, level.p) then
            return level
        end
    end
    return nil
end

function isValidJob(job)
    if job ~= nil and job.req ~= nil then
        local jobName = FindValueKey(cloned.jobs, job)
        local jd = cloned.distributions[jobName]
        if not jd then
            error("Job distribution not found. Job: " .. jobName)
        end
        if OpData[jobName].count < jd.max then
            return true
        end
    end
    return false
end

--Gets the skill table for a skill id from a particular dwarf
function GetSkillTable(dwf, skill)
    local id = df.job_skill[skill]
    assert(id, "Invalid skill - GetSkillTable(" .. skill .. ")")
    for _,skillTable in pairs(dwf.status.current_soul.skills) do
        if skillTable.id == id then
            return skillTable
        end
    end
    if args.debug and tonumber(args.debug) >= 0 then print("Could not find skill: " .. skill) end
    return nil
end

function GenerateStatValue(stat, atr_lvl)
    atr_lvl = atr_lvl == nil and GetRandomAttribLevel() or cloned.attrib_levels[atr_lvl]
    if args.debug and tonumber(args.debug) >= 4 then print(atr_lvl, atr_lvl[1], atr_lvl[2]) end
    local R = rng.rollNormal(engineID, atr_lvl[1], atr_lvl[2])
    local value = math.floor(R)
    value = value < 0 and 0 or value
    value = value > 5000 and 5000 or value
    stat.value = stat.value < value and value or stat.value
    if args.debug and tonumber(args.debug) >= 3 then print(R, stat.value) end
end

function LoopStatsTable(statsTable, callback)
    local ok,f,t,k = pcall(pairs,statsTable)
    if ok then
        for k,v in f,t,k do
            callback(v)
        end
    end
end

function ApplyType(dwf, dwf_type)
    local type = cloned.types[dwf_type]
    assert(type, "Invalid dwarf type.")
    for attribute, atr_lvl in pairs(type.attribs) do
        if args.debug and tonumber(args.debug) >= 3 then print(attribute, atr_lvl[1]) end
        if
        attribute == 'STRENGTH' or
        attribute == 'AGILITY' or
        attribute == 'TOUGHNESS' or
        attribute == 'ENDURANCE' or
        attribute == 'RECUPERATION' or
        attribute == 'DISEASE_RESISTANCE'
        then
            GenerateStatValue(dwf.body.physical_attrs[attribute], atr_lvl[1])
        elseif
        attribute == 'ANALYTICAL_ABILITY' or
        attribute == 'FOCUS' or
        attribute == 'WILLPOWER' or
        attribute == 'CREATIVITY' or
        attribute == 'INTUITION' or
        attribute == 'PATIENCE' or
        attribute == 'MEMORY' or
        attribute == 'LINGUISTIC_ABILITY' or
        attribute == 'SPATIAL_SENSE' or
        attribute == 'MUSICALITY' or
        attribute == 'KINESTHETIC_SENSE' or
        attribute == 'EMPATHY' or
        attribute == 'SOCIAL_AWARENESS'
        then
            GenerateStatValue(dwf.status.current_soul.mental_attrs[attribute], atr_lvl[1])
        else
            error("Invalid stat:" .. attribute)
        end
    end
    if type.skills ~= nil then
        for skill, skillRange in pairs(type.skills) do
            local sTable = GetSkillTable(dwf, skill)
            if sTable == nil then
                --print("ApplyType()", skill, skillRange)
                utils.insert_or_update(dwf.status.current_soul.skills, { new = true, id = df.job_skill[skill], rating = 0 }, 'id')
                sTable = GetSkillTable(dwf, skill)
            end
            local points = rng.rollInt(engineID, skillRange[1], skillRange[2])
            sTable.rating = sTable.rating < points and points or sTable.rating
            sTable.rating = sTable.rating > 20 and 20 or sTable.rating
            sTable.rating = sTable.rating < 0 and 0 or sTable.rating
            if args.debug and tonumber(args.debug) >= 2 then print(skill .. ".rating = " .. sTable.rating) end
        end
    end
    return true
end

--Apply only after previously validating
function ApplyProfession(dwf, profession, min, max)
    local prof = cloned.professions[profession]
    --todo: consider counting total dwarves trained in a profession [currently counting total sub-professions, of a job]
    for skill, bonus in pairs(prof.skills) do
        local sTable = GetSkillTable(dwf, skill)
        if sTable == nil then
            utils.insert_or_update(dwf.status.current_soul.skills, { new = true, id = df.job_skill[skill], rating = 0 }, 'id')
            sTable = GetSkillTable(dwf, skill)
        end
        local points = rng.rollInt(engineID, min, max)
        sTable.rating = sTable.rating < points and points or sTable.rating
        sTable.rating = sTable.rating + bonus
        sTable.rating = sTable.rating > 20 and 20 or sTable.rating
        sTable.rating = sTable.rating < 0 and 0 or sTable.rating
        if args.debug and tonumber(args.debug) >= 2 then print(skill .. ".rating = " .. sTable.rating) end
    end
    return true
end

--Apply only after previously validating
function ApplyJob(dwf, jobName) --job = dorf_jobs[X]
    local jd = cloned.distributions[jobName]
    local job = cloned.jobs[jobName]
    if args.debug and tonumber(args.debug) >= 3 then print(dwf,job,jobName, OpData[jobName]) end
    OpData[jobName].count = OpData[jobName].count + 1
    jd.cur = OpData[jobName].count
    local id = tostring(dwf.id)
    DwarvesData[id] = {}
    DwarvesData[id]['job'] = jobName
    DwarvesData[id]['professions'] = {}
    if not OpData[jobName] then
        OpData[jobName] = {}
    end
    dwf.custom_profession = jobName
    RollStats(dwf, job.types)
    
    -- Apply required professions
    local bAlreadySetProf2 = false
    local job_req_sequence = rng.num_sequence:new()
    for i=1,ArrayLength(job.req) do
        job_req_sequence:add(i)
    end
    local gen = rng.crng:new(engineID,false,job_req_sequence)
    --two required professions are set as the professional titles for a dwarf [prof1, prof2]
    --so when more than 2 are required it is necessary to randomize the iteration of their application to a dwarf
    --this is done with rpairs and the above RNG code
    gen:shuffle()
    job_req_sequence:add(0) --adding an out of bounds key (ie. 0) to ensure rpairs won't keep going forever
    --[note it is added after shuffling]
    local i = 0
    for _, prof in rpairs(job.req, gen) do
        --> Set Profession(s) (by #)
        i = i + 1 --since the key can't tell us what iteration we're on
        if i == 1 then
            dwf.profession = df.profession[prof]
        elseif i == 2 then
            bAlreadySetProf2 = true
            dwf.profession2 = df.profession[prof]
        end
        --These are required professions for this job class
        ApplyProfession(dwf, prof, 11, 17)
    end
        
    -- Loop tertiary professions
    -- Sort loop (asc)
    local points = 11
    local base_dec = 11 / job.max[1]
    local total = 0
    --We want to loop through professions according to need (ie. count & ratio(ie. p))
    for prof, t in spairs(OpData[jobName].profs,
    function(a,b)
        return twofield_compare(OpData[jobName].profs,
        a, b, 'count', 'p',
        function(f1,f2) return safecompare(f1,f2) end,
        function(f1,f2) return safecompare(f2,f1) end)
    end)
    do
        if total < job.max[1] then
            if args.debug and tonumber(args.debug) >= 1 then print("dwf id:", dwf.id, jobName, prof) end
            local ratio = job[prof]
            if ratio ~= nil then --[[not clear why this was happening, simple fix though
                (tried to reproduce the next day and couldn't,
                must have been a bad table lingering in memory between tests despite resetting persistent data and dwarves)
                --]]
                local max = math.ceil(points)
                local min = math.ceil(points - 5)
                min = min < 0 and 0 or min
                --Firsts are special
                if OpData[jobName].profs[prof].count < (ratio * OpData[jobName].count) and points > 7.7 then
                    ApplyProfession(dwf, prof, min, max)
                    table.insert(DwarvesData[id]['professions'], prof)
                    OpData[jobName].profs[prof].count = OpData[jobName].profs[prof].count + 1
                    if args.debug and tonumber(args.debug) >= 1 then print("count: ", OpData[jobName].profs[prof].count) end
                    
                    if not bAlreadySetProf2 then
                        bAlreadySetProf2 = true
                        dwf.profession2 = df.profession[prof]
                    end
                    points = points - base_dec
                    total = total + 1
                else
                    local p = OpData[jobName].profs[prof].count > 0 and (1 - (ratio / ((ratio*OpData[jobName].count) / OpData[jobName].profs[prof].count))) or ratio
                    p = p < 0 and 0 or p
                    p = p > 1 and 1 or p
                    --p = (p - math.floor(p)) >= 0.5 and math.ceil(p) or math.floor(p)
                    --> proc probability and check points
                    if points >= 1 and rng.rollBool(engineID, p) then
                        ApplyProfession(dwf, prof, min, max)
                        table.insert(DwarvesData[id]['professions'], prof)
                        OpData[jobName].profs[prof].count = OpData[jobName].profs[prof].count + 1
                        if args.debug and tonumber(args.debug) >= 1 then print("dwf id:", dwf.id, "count: ", OpData[jobName].profs[prof].count, jobName, prof) end
                        
                        if not bAlreadySetProf2 then
                            bAlreadySetProf2 = true
                            dwf.profession2 = df.profession[prof]
                        end
                        points = points - base_dec
                        total = total + 1
                    end
                end
            end
        end
    end
    if not bAlreadySetProf2 then
        dwf.profession2 = dwf.profession
    end
    return true
end

function RollStats(dwf, types)
    LoopStatsTable(dwf.body.physical_attrs, GenerateStatValue)
    LoopStatsTable(dwf.status.current_soul.mental_attrs, GenerateStatValue)
    for i, type in pairs(types) do
        if args.debug and tonumber(args.debug) >= 4 then print(i, type) end
        ApplyType(dwf, type)
    end
    for type, table in pairs(cloned.types) do
        local p = table.p
        if p ~= nil then
            if rng.rollBool(engineID, p) then
                ApplyType(dwf, type)
            end
        end
    end
end

--Returns true if a job was found and applied, returns false otherwise
function FindJob(dwf, recursive)
    if isDwarfOptimized(dwf) then
        return false
    end
    for jobName, jd in spairs(cloned.distributions,
    function(a,b)
        return twofield_compare(cloned.distributions,
        a, b, 'cur', 'max',
        function(a,b) return safecompare(a,b) end,
        function(a,b) return safecompare(b,a) end)
   end)
    do
        if args.debug and tonumber(args.debug) >= 4 then print("FindJob() ", jobName) end
        local job = cloned.jobs[jobName]
        if isValidJob(job) then
            if args.debug and tonumber(args.debug) >= 1 then print("Found a job!") end
            ApplyJob(dwf, jobName)
            return true
        end
    end
    --not recursive => not recursively called (yet~)
    if not recursive and TrySecondPassExpansion() then
        return FindJob(dwf, true)
    end
    print(":WARNING: No job found, that is bad?!")
    return false
end

function TrySecondPassExpansion() --Tries to expand distribution maximums
    local curTotal = 0
    for k,v in pairs(cloned.distributions) do
        if v.cur ~= nil then
            curTotal = curTotal + v.cur
        end
    end

    if curTotal < work_force then
        local I = 0
        for i, v in pairs(cloned.distributions.Thresholds) do
            if work_force >= v then
                I = i + 1
            end
        end

        local delta = 0
        for jobName, jd in spairs(cloned.distributions,
        function(a,b)
            return twofield_compare(cloned.distributions,
            a, b, 'max', 'cur',
            function(a,b) return safecompare(a,b) end,
            function(a,b) return safecompare(a,b) end)
        end)
        do
            if cloned.jobs[jobName] then
                if (curTotal + delta) < work_force then
                    delta = delta + jd[I]
                    jd.max = jd.max + jd[I]
                end
            end
        end
        return true
    end
    return false
end

function ZeroDwarf(dwf)
    LoopStatsTable(dwf.body.physical_attrs, function(attribute) attribute.value = 0 end)
    LoopStatsTable(dwf.status.current_soul.mental_attrs, function(attribute) attribute.value = 0 end)

    local count_max = count_this(df.job_skill)
    utils.sort_vector(dwf.status.current_soul.skills, 'id')
    for i=0, count_max do
        utils.erase_sorted_key(dwf.status.current_soul.skills, i, 'id')
    end

    dfhack.units.setNickname(dwf, "")
    dwf.custom_profession = ""
    dwf.profession = df.profession['DRUNK']
    dwf.profession2 = df.profession['DRUNK']

    for id, dwf_data in pairs(DwarvesData) do
        if next(dwf_data) ~= nil and id == tostring(dwf.id) then
            print("Clearing loaded dwf data for dwf id: " .. id)
            local jobName = dwf_data.job
            local job = cloned.jobs[jobName]
            OpData[jobName].count = OpData[jobName].count - 1
            for i, prof in pairs(dwf_data.professions) do
                OpData[jobName].profs[prof].count = OpData[jobName].profs[prof].count - 1
                if args.debug and tonumber(args.debug) >= 1 then print("dwf id:", dwf.id, "count: ", OpData[jobName].profs[prof].count, jobName, prof) end
            end
            DwarvesData[id] = nil
            --table.remove(DwarvesData,id)
        elseif next(dwf_data) == nil and id == tostring(dwf.id) then
            print(":WARNING: ZeroDwarf(dwf) - dwf was zeroed, but had never been optimized before")
            --error("this dwf_data shouldn't be nil, I think.. I guess maybe if you were clearing dwarves that weren't optimized")
        end
    end
    return true
end

function Reroll(dwf)
    local jobName = dwf.custom_profession
    if cloned.jobs[jobName] then
        if args.reroll ~= 'inclusive' then
            ZeroDwarf(dwf)
        end
        ApplyJob(dwf, jobName)
        return true
    end
    return false
end

function Show(dwf)
    local name_ptr = dfhack.units.getVisibleName(dwf)
    local name = dfhack.TranslateName(name_ptr)
    local numspaces = 26 - string.len(name)
    local spaces = ' '
    for i=1,numspaces do
        spaces = spaces .. " "
    end
    print('('..dwf.id..') - '..name..spaces..dwf.profession,dwf.custom_profession)
end

function LoopUnits(units, check, fn, checkoption, profmin, profmax) --cause nothing else will use arg 5 or 6
    local count = 0
    for _, unit in pairs(units) do
        if check ~= nil then
            if check(unit, checkoption, profmin, profmax) then
                if fn ~= nil then
                    if fn(unit) then
                        count = count + 1
                    end
                else
                    count = count + 1
                end
            end
        elseif fn ~= nil then
            if fn(unit) then
                count = count + 1
            end
        end
    end
    if args.debug and tonumber(args.debug) >= 1 then
        print("loop count: ", count)
    end
    return count
end

function LoopTable_Apply_ToUnits(units, apply, applytable, checktable, profmin, profmax) --cause nothing else will use arg 5 or 6
    local count = 0
    local temp = 0
    for _,tvalue in pairs(applytable) do
        if checktable[tvalue] then
            temp = LoopUnits(units, apply, nil, tvalue, profmin, profmax)
            count = count < temp and temp or count
        else
            error("\nInvalid option: " .. tvalue .. "\nLook-up table: " .. checktable)
        end
    end
    return count
end

------------
--CHECKERS--
------------

--Returns true if the DWARF has a user-given name
function isDwarfNamed(dwf)
    return dwf.status.current_soul.name.nickname ~= ""
end

--Returns true if the DWARF has a custom_profession
function isDwarfEmployed(dwf)
    return dwf.custom_profession ~= ""
end

--Returns true if the DWARF is in the DwarvesData table
function isDwarfOptimized(dwf)
    local id = tostring(dwf.id)
    local dorf = DwarvesData[id]
    return dorf ~= nil
end

--Returns true if the DWARF is not in the DwarvesData table
function isDwarfUnoptimized(dwf)
    return (not isDwarfOptimized(dwf))
end

--Returns true if the DWARF uses a protection signal in its name or profession
function isDwarfProtected(dwf)
    if dwf.custom_profession ~= "" then
        for _,signal in pairs(protected_dwarf_signals) do
            if GetChar(dwf.custom_profession, 1) == signal then
                return true
            end
        end
    end
    if dwf.status.current_soul.name.nickname ~= "" then
        for _,signal in pairs(protected_dwarf_signals) do
            if GetChar(dwf.status.current_soul.name.nickname, 1) == signal then
                return true
            end
        end
    end
    return false
end

--Returns true if the DWARF doesn't use a protection signal in its name or profession
function isDwarfUnprotected(dwf)
    return (not isDwarfProtected(dwf))
end

function isDwarfCitizen(dwf)
    return dfhack.units.isCitizen(dwf)
end

function CanWork(dwf)
    return dfhack.units.isCitizen(dwf) and dfhack.units.isAdult(dwf)
end

function CheckWorker(dwf, option)
    if CanWork(dwf) then
        --selection options
        if option == 'protected' then
            return isDwarfProtected(dwf)
        elseif isDwarfUnprotected(dwf) then
            if option == 'all' then
                return true
            elseif option == 'highlighted' then
                return dwf == dfhack.gui.getSelectedUnit()
            elseif option == 'named' then
                return isDwarfNamed(dwf)
            elseif option == 'unnamed' then
                return (not isDwarfNamed(dwf))
            elseif option == 'employed' then
                return isDwarfEmployed(dwf)
            elseif option == 'optimized' then
                return isDwarfOptimized(dwf)
            elseif option == 'unoptimized' then
                return isDwarfUnoptimized(dwf)
            elseif option == 'unprotected' then
                return isDwarfUnprotected(dwf)
            elseif option == 'drunks' or option == 'drunk' then
                return dwf.profession == df.profession['DRUNK'] and dwf.profession2 == df.profession['DRUNK']
            elseif type(option) == 'table' then
                if option[1] == 'job' or option[1] == 'jobs' then
                    n=0
                    for _,v in pairs(option) do
                        n=n+1
                        --print(dwf.custom_profession, v)
                        if n > 1 and dwf.custom_profession == v then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

----------------
--END CHECKERS--
----------------

function Prepare()
    print("Loading persistent data..")
    --Load /current/fort.json.dat or /world/fort.json.dat
    LoadPersistentData()
    if not OpData.Dwarves then
        OpData.Dwarves = {}
    end
    DwarvesData = OpData.Dwarves

    --[[ We need to validate the persistent data/
        Perhaps I/you/we updated the dorf_tables, so we should check.]]
    --Initialize OpData
    for jobName, job in pairs(cloned.jobs) do --should be looping the distribution table instead (probably a major refactor needed)
        PrepareDistributionMax(jobName)
        if not OpData[jobName] then
            OpData[jobName] = {}
            OpData[jobName].count = 0
            OpData[jobName].profs = {}
        end
        for prof, p in pairs(job) do
            if tonumber(p) then
                if not OpData[jobName].profs[prof] then
                    OpData[jobName].profs[prof] = {}
                    OpData[jobName].profs[prof].count = 0
                end
                OpData[jobName].profs[prof].p = p
            end
        end
    end
    if args.debug and tonumber(args.debug) >= 4 then
        print("OpData, job counts")
        DisplayTable(OpData) --this is gonna print out a lot of data, including the persistent data
    end
    --Count Professions from 'DwarvesData'
    --[[for id, dwf_data in pairs(DwarvesData) do
        local jobName = dwf_data.job
        local job = cloned.jobs[jobName]
        local profs = dwf_data.professions
        OpData[jobName].count = OpData[jobName].count + 1
        for i, prof in pairs(profs) do
            OpData[jobName].profs[prof].count = OpData[jobName].profs[prof].count + 1
        end
    end--]]

    --TryClearDwarf Loop (or maybe not)
    print("Data load complete.")
end

function PrepareDistributionMax(jobName)
    local jd = cloned.distributions[jobName]
    if not jd then
        error("Job distribution not found. Job: " .. jobName)
    elseif jd.max ~= nil then
        error("job distribution max is not nil - " .. jobName)
    end
    local IndexMax = 0
    for i, v in pairs(cloned.distributions.Thresholds) do
        if work_force >= v then
            IndexMax = i
        end
    end
    --print(cloned.distributions.Thresholds[IndexMax])
    local max = 0
    for i=1, IndexMax do
        max = max + jd[i]
    end
    jd.max = max
end

function SelectDwarf(dwf)
    table.insert(selection, dwf)
    return true
end

function ShowHelp()
    print([====[
usage: dwarf-op [-help|-select]
               -select <sel-opt> -<command> <args>
============
dwarf-op script
~~~~~~~~~~~~
To use this script, you need to select a subset of your dwarves. Then run commands on those dwarves.
Please report any bugs or crashes you experience here [https://github.com/cppcooper/dfhack-scripts/issues]
Examples:
  [DFHack]# dwarf-op -select [ jobs Trader Miner Leader Warden ] -applytype adaptable
  [DFHack]# dwarf-op -select all -clear -optimize
  [DFHack]# dwarf-op -select optimized -reroll
  [DFHack]# dwarf-op -select named -reroll inclusive -applyprofession RECRUIT
~~~~~~~~~~~~
 select options:
   (protected is the only option which will select PROTECTED dwarves)
    all         - selects all dwarves.
    highlighted - selects only the in-game highlighted dwarf (from any screen).
    named       - selects dwarves with user-given names.
    unnamed     - selects dwarves without user-given names.
    employed    - selects dwarves with custom professions. Excludes optimized dwarves.
    optimized   - selects dwarves based on session data. Dwarves who have been optimized, should be listed in this data.
    unoptimized - selects any dwarves that don't appear in session data.
    protected   - selects any dwarves which use protection signals in their name or profession. (ie. {'.', 'c', 'j', 'p'})
    unprotected - selects any dwarves which don't use protection signals in their name or profession.
    drunks      - selects any dwarves which are currently zeroed, or were originally drunks as their profession.
    jobs        - selects any dwarves with the listed jobs. This will only match with custom professions, or optimized dwarves (for optimized dwarves see: jobs in dorf_tables.lua).
                - usage `-select [ jobs job1 job2 etc. ]` eg. `-select [ jobs Miner Trader ]`
~~~~~~~~~~~~
Commands will run on the selected dwarves
 available commands:
    reset              - deletes json file containing session data
    resetall           - deletes both json files. session data and existing persistent data
    clear              - zeroes selected dwarves, or zeroes all dwarves if no selection is given. No attributes, no labours. Assigns 'DRUNK' profession.
    reroll <inclusive> - zeroes selected dwarves, then rerolls that dwarf based on its job. Ignores dwarves with unlisted jobs.
                       - optional argument: inclusive. Only performs the reroll, will no zero the dwarf first. Benefit: stats can only go higher, not lower.
    optimize           - performs a job search for unoptimized dwarves. Each dwarf will be found a job according to the job_distribution table in dorf_tables.lua
    applyjobs          - applies the listed jobs to the selected dwarves. list format: `[ job1 job2 jobn ]` brackets and jobs all separated by spaces.
                       - see jobs table in dorf_tables.lua for available jobs."
    applyprofessions   - applies the listed professions to the selected dwarves. list format: `[ prof1 prof2 profn ]` brackets and professions all separated by spaces.
                       - see professions table in dorf_tables.lua for available professions.
    applytypes         - applies the listed types to the selected dwarves. list format: `[ type1 type2 typen ]` brackets and types all separated by spaces.
                       - see dwf_types table in dorf_tables.lua for available types.
~~~~~~~~~~~~
    Other Arguments:
      help - displays this help information.
      debug - enables debugging print lines
      show - displays affected dwarves (id, name, primary job)

No dorfs were harmed in the building of this help screen.
]====])
end

function ShowHint()
    print("\n============\ndwarf-op script")
    print("~~~~~~~~~~~~")
    print("To use this script, you need to select a subset of your dwarves. Then run commands on those dwarves.")
    print("Examples:")
    print("  [DFHack]# dwarf-op -select [ jobs Trader Miner Leader Warden ] -applytype adaptable")
    print("  [DFHack]# dwarf-op -select all -clear -optimize")
    print("  [DFHack]# dwarf-op -select optimized -reroll")
    print("  [DFHack]# dwarf-op -select named -reroll inclusive -applyprofession RECRUIT")
end

local ActiveUnits = df.global.world.units.active
dwarf_count = LoopUnits(ActiveUnits, isDwarfCitizen)
work_force = LoopUnits(ActiveUnits, CanWork)
Prepare()
print('\nActive Units Population: ' .. ArrayLength(ActiveUnits))
print("Dwarf Population: " .. dwarf_count)
print("Work Force: " .. work_force)
print("Existing Optimized Dwarves: " .. ArrayLength(OpData.Dwarves))

function exists(thing)
    if thing then return true else return false end
end
args.b_clear = exists(args.clear) if args.debug and tonumber(args.debug) >= 0 then print(        "args.b_clear:    " .. tostring(args.b_clear)) end
args.b_optimize = exists(args.optimize) if args.debug and tonumber(args.debug) >= 0 then print(      "args.b_optimize:   " .. tostring(args.b_optimize)) end
args.b_reroll = exists(args.reroll) if args.debug and tonumber(args.debug) >= 0 then print(      "args.b_reroll:   " .. tostring(args.b_reroll)) end
args.b_applyjobs = exists(args.applyjobs) if args.debug and tonumber(args.debug) >= 0 then print("args.b_applyjob: " .. tostring(args.b_applyjobs)) end
if args.help then
    ShowHelp()
elseif not args.select and (args.reset or args.resetall or args.clear) then
    if args.reset or args.resetall then
        ClearPersistentData(exists(args.resetall))
    end
    if args.clear then
        selection = {}
        print("Selected Dwarves: " .. LoopUnits(ActiveUnits, CheckWorker, SelectDwarf, 'all'))
        print("\nResetting selected dwarves..")
        temp = LoopUnits(selection, nil, ZeroDwarf)
        print(temp .. " dwarves affected.")
        if args.show then
            print("Affected Dwarves: ")
            LoopUnits(selection, nil, Show)
        end
    end
elseif args.select and (args.debug or args.clear or args.optimize or args.reroll or args.applyjobs or args.applyprofessions or args.applytypes) then
    selection = {}
    count = 0
    print("Selected Dwarves: " .. LoopUnits(ActiveUnits, CheckWorker, SelectDwarf, args.select))
    
    if args.b_clear ~= args.b_reroll or not args.b_clear then
        --error("Clear is implied with Reroll. Choose one, not both.")
        if args.b_reroll and args.b_optimize then
            error("options: optimize, reroll. Choose one, and only one.")
        else
            --
            --Valid options were entered
            --
            local affected = 0
            local temp = 0
            if args.reset or args.resetall then
                ClearPersistentData(exists(args.resetall))
            end
            if args.clear then
                print("\nResetting selected dwarves..")
                temp = LoopUnits(selection, nil, ZeroDwarf)
                affected = affected < temp and temp or affected
            end
            
            if args.optimize then
                print("\nOptimizing selected dwarves..")
                temp = LoopUnits(selection, nil, FindJob)
                affected = affected < temp and temp or affected
            elseif args.reroll then
                print("\nRerolling selected dwarves..")
                temp = LoopUnits(selection, nil, Reroll)
                affected = affected < temp and temp or affected
            end

            if args.applyjobs then
                if type(args.applyjobs) == 'table' then
                    print("Applying jobs:" .. TableToString(args.applyjobs) .. ", to selected dwarves")
                    temp = LoopTable_Apply_ToUnits(selection, ApplyJob, args.applyjobs, cloned.jobs)
                else
                    print("Applying job:" .. args.applyjobs .. ", to selected dwarves")
                    if cloned.jobs[args.applyjobs] then
                        temp = LoopUnits(selection, ApplyJob, nil, args.applyjobs)
                    else
                        error("Invalid job: " .. args.applyjobs)
                    end
                end
                affected = affected < temp and temp or affected
            end
            if args.applyprofessions then
                if type(args.applyprofessions) == 'table' then
                    print("Applying professions:" .. TableToString(args.applyprofessions) .. ", to selected dwarves")
                    temp = LoopTable_Apply_ToUnits(selection, ApplyProfession, args.applyprofessions, cloned.professions,1,5)
                else
                    print("Applying professions:" .. args.applyprofessions .. ", to selected dwarves")
                    if cloned.professions[args.applyprofessions] then
                        temp = LoopUnits(selection, ApplyProfession, nil, args.applyprofessions,1,5)
                    else
                        error("Invalid profession: " .. args.applyprofessions)
                    end
                end
                affected = affected < temp and temp or affected
            end
            if args.applytypes then
                if type(args.applytypes) == 'table' then
                    print("Applying types:" .. TableToString(args.applytypes) .. ", to selected dwarves")
                    temp = LoopTable_Apply_ToUnits(selection, ApplyType, args.applytypes, cloned.types)
                else
                    print("Applying type:" .. args.applytypes .. ", to selected dwarves")
                    if cloned.types[args.applytypes] then
                        temp = LoopUnits(selection, ApplyType, nil, args.applytypes)
                    else
                        error("Invalid type: " .. args.applytypes)
                    end
                end
                affected = affected < temp and temp or affected
            end
            print(affected .. " dwarves affected.")

            if args.debug and tonumber(args.debug) >= 1 then
                print("\n")
                print("cur", "max", "job", "\n  ~~~~~~~~~")
                for k,v in pairs(cloned.distributions) do
                    print(v.cur, v.max, k)
                end
            end
            --
            --Valid options code block ending
            --
        end
    else
        error("Clear is implied with Reroll. Choose one, not both.")
    end
    if args.show then
        print("Affected Dwarves: ")
        LoopUnits(selection, nil, Show)
    end
else
    if args.show then
        selection = {}
        print("Selected Dwarves: " .. LoopUnits(ActiveUnits, CheckWorker, SelectDwarf, args.select))
        LoopUnits(selection, nil, Show)
    else
        ShowHint()
    end
end
SavePersistentData()
print('\n')

--Query(dfhack, '','dfhack')
--Query(OpData, '', 'pd')

attrib_seq = nil
rng.DestroyEngine(engineID)
collectgarbage()