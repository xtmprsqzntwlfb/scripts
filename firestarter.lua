--Use while viewing an item, unit inventory, or tile to start fires.
--[====[

firestarter
===========
Lights things on fire, items, locations, entire inventories even!

]====]
local tinder
if dfhack.gui.getCurFocus() == 'item' then
    tinder=dfhack.gui.getCurViewscreen().item
    tinder.flags.on_fire=true
elseif dfhack.gui.getSelectedUnit(true) then
    tinder=dfhack.gui.getSelectedUnit(true).inventory
        for k,v in ipairs(tinder) do
            tinder[k].item.flags.on_fire=true
        end
elseif df.global.cursor.x ~= -30000 then
    local curpos = xyz2pos(pos2xyz(df.global.cursor))
    df.global.world.fires:insert('#', {
        new=df.fire,
        timer=1000,
        pos=curpos,
        temperature=60000,
        temp_unk1=60000,
        temp_unk2=60000,
        temp_unk3=60000,
    })
end
