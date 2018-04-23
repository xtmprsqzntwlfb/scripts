-- Adjusts properties of caravans
--[====[

caravan
=======

Adjusts properties of caravans on the map. See also `force` to create caravans.

This script has multiple subcommands. Commands listed with the argument
``[IDS]`` can take multiple caravan IDs (see ``caravan list``). If no IDs are
specified, then the commands apply to all caravans on the map.

**Subcommands:**

- ``list``: lists IDs and information about all caravans on the map.
- ``extend [DAYS] [IDS]``: extends the time that caravans stay at the depot by
  the specified number of days (defaults to 7 if not specified). Also causes
  caravans to return to the depot if applicable.
- ``happy [IDS]``: makes caravans willing to trade again (after seizing goods,
  annoying merchants, etc.). Also causes caravans to return to the depot if
  applicable.
- ``leave [IDS]``: makes caravans pack up and leave immediately.

]====]

--@ module = true

INTERESTING_FLAGS = {
    casualty = 'Casualty',
    hardship = 'Encountered hardship',
    seized = 'Goods seized',
    offended = 'Offended'
}
caravans = df.global.ui.caravans

function caravans_from_ids(ids)
    if not ids or #ids == 0 then
        return pairs(caravans)
    end
    local i = 0
    return function()
        i = i + 1
        local id = tonumber(ids[i])
        if id then
            return id, caravans[id]
        end
        return nil
    end
end

function bring_back(car)
    if car.trade_state ~= df.caravan_state.T_trade_state.AtDepot then
        car.trade_state = df.caravan_state.T_trade_state.Approaching
    end
end

commands = {}

function commands.list()
    for id, car in pairs(caravans) do
        print(dfhack.df2console(('%d: %s caravan from %s'):format(
            id,
            df.creature_raw.find(df.historical_entity.find(car.entity).race).name[2], -- adjective
            dfhack.TranslateName(df.historical_entity.find(car.entity).name)
        )))
        print('  ' .. (df.caravan_state.T_trade_state[car.trade_state] or 'Unknown state: ' .. car.trade_state))
        print(('  %d day(s) remaining'):format(math.floor(car.time_remaining / 120)))
        for flag, msg in pairs(INTERESTING_FLAGS) do
            if car.flags[flag] then
                print('  ' .. msg)
            end
        end
    end
end

function commands.extend(days, ...)
    days = tonumber(days or 7) or qerror('invalid number of days: ' .. days)
    for id, car in caravans_from_ids{...} do
        car.time_remaining = car.time_remaining + (days * 120)
        bring_back(car)
    end
end

function commands.happy(...)
    for id, car in caravans_from_ids{...} do
        -- all flags default to false
        car.flags.whole = 0
        bring_back(car)
    end
end

function commands.leave(...)
    for id, car in caravans_from_ids{...} do
        car.trade_state = df.caravan_state.T_trade_state.Leaving
    end
end

function main(...)
    args = {...}
    command = table.remove(args, 1)
    commands[command](table.unpack(args))
end

if not dfhack_flags.module then
    main(...)
end
