-- workorder allows queuing manager jobs; it's smart about shear and milk creature jobs.
-- place this file in your /df/hack/scripts folder.

-- This script is inspired by stockflow.
-- It wouldn't've been possible w/o the df-ai by jjyg (https://github.com/jjyg/df-ai)
-- which is a great place to look up stuff like "How the hell do I find out if
-- a creature can be sheared?!!"

local function print_help()
    print [====[
workorder
=============
workorder is a script to queue work orders as in j-m-q menu.
It can automatically count how many creatures can be milked or sheared.

It doesn't set any materials in the orders.

Example usage:
    workorder ShearCreature 10
        queues a job to shear 10 creatures
    workorder ShearCreature
        queues a job to shear all creatures currently needing shearing
    workorder MilkCreature 10
        queues a job to milk 10 creatures
    workorder MilkCreature
        queues a job to milk all creatures currently needing milking
    workorder --listtypes
        prints a list of all job types in the game; not all of them may be
        valid for manager.

workorder [-? | --help | --listtypes | <jobtype> [<amount>]]
    -?, --help     this help
    --listtypes    print all possible values for <jobtype>
    <jobtype>      number or name from df.job_type
                   (use `workorder --listtypes` to get all possible types
    <amount>       optional number; if omitted, the script will try to
                   determine amount automatically for some jobs. Currently
                   supported are MilkCreature and ShearCreature jobs.
]====]
end

local function print_job_types()
    print "All possible jobtypes:"
    for i,v in ipairs( df.job_type ) do print (i,v) end
end

-- [[ from stockflow.lua:

-- is a manager assigned in the fortress?
local function has_manager()
    return #df.historical_entity
        .find(df.global.ui.group_id)
        .assignments_by_type
        .MANAGE_PRODUCTION > 0
end

-- Compare the job specification of two orders.
local function orders_match(a, b)
    local fields = {
        "job_type",
        "item_subtype",
        "reaction_name",
        "mat_type",
        "mat_index",
    }

    for _, fieldname in ipairs(fields) do
        if a[fieldname] ~= b[fieldname] then
            return false
        end
    end

    local subtables = {
        "item_category",
        "material_category",
    }

    for _, fieldname in ipairs(subtables) do
        local aa = a[fieldname]
        local bb = b[fieldname]
        for key, value in ipairs(aa) do
            if bb[key] ~= value then
                return false
            end
        end
    end

    return true
end

-- Reduce the quantity by the number of matching orders in the queue.
local function order_quantity(order, quantity)
    local amount = quantity
    for _, managed in ipairs(df.global.world.manager_orders) do
        if orders_match(order, managed) then
            amount = amount - managed.amount_left
            if amount < 0 then
                return 0
            end
        end
    end

    return amount
end
-- ]]

local function queue_manager_job(jobtype, amount, reduce)
    local order = df.manager_order:new()
    order.job_type = jobtype
    -- more to probably come

    reduced_amount = reduce and order_quantity(order, amount) or amount
    if reduced_amount <= 0 then
        order:delete()
        --print ( df.job_type[jobtype].." NOT queued: amount reduced from "
        --        .. amount .. " to " .. reduced_amount
        --        .. " because of active jobs.")
        return
    end

    order.amount_left = reduced_amount
    order.amount_total = reduced_amount

    order.id = df.global.world.manager_order_next_id
    df.global.world.manager_order_next_id = df.global.world.manager_order_next_id + 1
    df.global.world.manager_orders:insert('#', order)

    print("Queued " .. df.job_type[jobtype] .. " x" .. reduced_amount)
end

local function default_action(...)
    --local args = {...}
    local v, n = ...
    local jobtype = df.job_type[tonumber(v)] and tonumber(v) or df.job_type[ v ]
    if not jobtype then
        print ("Unknown jobtype: " .. tostring(v))
        return
    end

    local amount = tonumber(n)
    local reduce = false
    if not amount then
        reduce = true
        local fn = _ENV[ "calcAmountFor_" .. df.job_type[ jobtype ] ]
        if fn and type(fn)=="function" then
            local args = {...}
            table.remove(args, 1)
            table.remove(args, 1)
            amount = fn(table.unpack(args))
        end
    end

    if not amount then
        print ("Missing amount (got "..tostring(n)..")")
        return
    end

    if not has_manager() then
        print "You should assign a manager first."
        return
    end

    queue_manager_job(jobtype, amount, reduce)
end

-- see https://github.com/jjyg/df-ai/blob/master/ai/population.rb
-- especially `update_pets`

local world = df.global.world
local uu = dfhack.units
local function isValidUnit(u)
    return uu.isOwnCiv(u)
        and uu.isAlive(u)
        and uu.isAdult(u)
        and u.flags1.tame -- no idea if this is needed...
        and not u.flags1.merchant
        and not u.flags1.forest -- no idea what this is
        and not u.flags2.for_trade
        and not u.flags2.slaughter
end

local MilkCounter = df.misc_trait_type["MilkCounter"]
calcAmountFor_MilkCreature = function ()
    local cnt = 0
    --print "Milkable units:"
    for i, u in pairs(world.units.active) do
        if isValidUnit(u)
        and uu.isMilkable(u)
        and uu.getMiscTrait(u, MilkCounter, false) -- aka "was milked"; but we could use its .value for something.
        then
            cnt = cnt + 1

            -- debug:
            --local mt_milk = uu.getMiscTrait( u, MilkCounter, false ) and uu.getMiscTrait( u, MilkCounter, false )
            --local mt_milk_val = mt_milk and mt_milk.value or "not milked recently"
            --print(i,uu.getRaceName(u),mt_milk_val)
            --if not mt_milk then cnt = cnt + 1 end
        end
    end
    --print ("Milking jobs needed: " .. cnt)
    return cnt
end

-- true/false or nil if no shearable_tissue_layer with length > 0.
local function canShearCreature(u)
    local stls = world.raws.creatures
            .all[u.race]
            .caste[u.caste]
            .shearable_tissue_layer

    local any = false
    for _, stl in ipairs(stls) do
        if stl.length > 0 then
            any = true

            for _, bpi in ipairs(stl.bp_modifiers_idx) do
                if u.appearance.bp_modifiers[bpi] >= stl.length then
                    return true
                end
            end

        end
    end

    if any then return false end
    -- otherwise: nil
end

calcAmountFor_ShearCreature = function ()
    local cnt = 0
    --print "Shearable units:"
    for i, u in pairs(world.units.active) do
        if isValidUnit(u)
        and canShearCreature(u)
        then
            cnt = cnt + 1

            -- debug:
            --local can = canShearCreature(u)
            --if (can ~= nil) then
                --print(i, uu.getRaceName(u), can)
                --if can then cnt = cnt + 1 end
            --end
        end
    end
    --print ("Shearing jobs needed: " .. cnt)

    return cnt
end


local actions = {
    ["-?"] = print_help,
    ["?"] = print_help,
    ["--help"] = print_help,
    ["help"] = print_help,
    --
    ["--listtypes"] = print_job_types,
    ["listtypes"] = print_job_types,
    ["l"] = print_job_types,
    ["-l"] = print_job_types,
    --
}

-- Lua is beautiful.
(actions[ (...) or "?" ] or default_action)(...)
