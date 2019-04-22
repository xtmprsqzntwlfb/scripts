-- Adjust all preferences of one or all dwarves in play
-- by vjek
--[====[

pref-adjust
===========
``pref-adjust all`` removes/changes preferences from all dwarves, and
``pref-adjust one`` which works for a single currently selected dwarf.
For either, the script inserts an 'ideal' set which is easy to satisfy::

    ... likes iron, steel, weapons, armor, shields/bucklers and plump helmets
    for their rounded tops.  When possible, she prefers to consume dwarven
    wine, plump helmets, and prepared meals (quarry bush). She absolutely
    detests trolls, buzzards, vultures and crundles.

Additionally, ``pref-adjust goth`` will insert a less than ideal set, which
is quite challenging, for a single dwarf::

    ... likes dwarf skin, corpses, body parts, remains, coffins, the color
    black, crosses, glumprongs for their living shadows and snow demons for
    their horrifying features.  When possible, she prefers to consume sewer
    brew, gutter cruor and bloated tubers.  She absolutely detests elves,
    humans and dwarves.

To see what values can be used with each type of preference, use
``pref-adjust list``.  Optionally, a single dwarf or all dwarves can have
their preferences cleared manually with the use of ``pref-adjust clear_one``
and ``pref-adjust clear_all``, respectively. Existing preferences are
automatically cleared, normally.

]====]
-- ---------------------------------------------------------------------------
function insert_preference(unit,mytype,val1)

    if mytype == 0 then
        utils.insert_or_update(unit.status.current_soul.preferences, { new = true, type = 0 , item_type = -1 , poetic_form_id = -1, musical_form_id = -1, dance_form_id = -1, mattype = dfhack.matinfo.find(val1).type , mat_state = 0, matindex = dfhack.matinfo.find(val1).index , active = true, prefstring_seed = pss_counter }, 'prefstring_seed')
        -- mattype for some is non zero, those non-iorganice like creature:gazelle:hoof is 42,344
    end

    if mytype == 2 then
        consumable_type=val1[1]
        consumable_name=val1[2]
        utils.insert_or_update(unit.status.current_soul.preferences, { new = true, type = 2 , item_type = consumable_type , poetic_form_id = consumable_type, musical_form_id = df.consumable_type, dance_form_id = consumable_type, item_subtype = dfhack.matinfo.find(consumable_name).subtype , mattype = dfhack.matinfo.find(consumable_name).type , mat_state = 0, matindex = dfhack.matinfo.find(consumable_name).index , active = true, prefstring_seed = pss_counter }, 'prefstring_seed')
    end

    if mytype == 1 or (mytype >= 3 and mytype <= 11) then
        utils.insert_or_update(unit.status.current_soul.preferences, { new = true, type = mytype , item_type = val1 , creature_id = val1 , color_id = val1 , shape_id = val1 , plant_id = val1 , poetic_form_id = val1, musical_form_id = val1, dance_form_id = val1, item_subtype = -1 , mattype = -1 , mat_state = 0, matindex = -1 , active = true, prefstring_seed = pss_counter }, 'prefstring_seed')
    end

pss_counter = pss_counter + 1
end
-- ---------------------------------------------------------------------------
function brainwash_unit(unit,profile)
    if unit==nil then
        print ("No unit available!  Aborting with extreme prejudice.")
        return
    end

if profile == "IDEAL" then
    -- Type 0: Material Likes: IRON(0),STEEL(8),ADAMANTINE(25)
    insert_preference(unit,0,"IRON")
    insert_preference(unit,0,"STEEL")
--  insert_preference(unit,0,"ADAMANTINE")

    -- Type 4: Item likes: (WEAPON, ARMOR, SHIELD)
    insert_preference(unit,4,df.item_type.WEAPON)
    insert_preference(unit,4,df.item_type.ARMOR)
    insert_preference(unit,4,df.item_type.SHIELD)

    -- Type 5: Plant Likes: "Likes plump helmets for their rounded tops"
    insert_preference(unit,5,dfhack.matinfo.find("MUSHROOM_HELMET_PLUMP:STRUCTURAL").index)
--  insert_preference(unit,5,dfhack.matinfo.find("PEACH").index)

    -- Type 2: Prefers to consume drink: (From plump helmets we get dwarven wine)
    insert_preference(unit,2,{df.item_type.DRINK,"MUSHROOM_HELMET_PLUMP:DRINK"})
    -- Type 2: Prefers to consume food: (plump helmets, mushrooms)
    insert_preference(unit,2,{df.item_type.PLANT,"MUSHROOM_HELMET_PLUMP:MUSHROOM"})
    -- Type 2: Prefers to consume prepared meals: (quarry bush)
    insert_preference(unit,2,{df.item_type.FOOD,"BUSH_QUARRY"})

    -- Type 3: Creature detests (TROLL, BIRD_BUZZARD, BIRD_VULTURE, CRUNDLE)
    insert_preference(unit,3,list_of_creatures.TROLL)
    insert_preference(unit,3,list_of_creatures.BIRD_BUZZARD)
    insert_preference(unit,3,list_of_creatures.BIRD_VULTURE)
    insert_preference(unit,3,list_of_creatures.CRUNDLE)
end -- end IDEAL profile

if profile == "GOTH" then
    insert_preference(unit,0,"CREATURE:DWARF:SKIN")
    insert_preference(unit,4,df.item_type.CORPSE)
    insert_preference(unit,4,df.item_type.CORPSEPIECE)
    insert_preference(unit,4,df.item_type.REMAINS)
    insert_preference(unit,4,df.item_type.COFFIN)
    insert_preference(unit,7,list_of_colors.BLACK)
    insert_preference(unit,8,list_of_shapes.CROSS)
    insert_preference(unit,5,dfhack.matinfo.find("GLUMPRONG").index)
    insert_preference(unit,2,{df.item_type.DRINK,"WEED_RAT:DRINK"})
    insert_preference(unit,2,{df.item_type.DRINK,"SLIVER_BARB:DRINK"})
    insert_preference(unit,2,{df.item_type.PLANT,"TUBER_BLOATED:STRUCTURAL"})
    insert_preference(unit,3,list_of_creatures.ELF)
    insert_preference(unit,3,list_of_creatures.HUMAN)
    insert_preference(unit,3,list_of_creatures.DWARF)
    if list_of_creatures.DEMON_1 and df.global.world.raws.creatures.all[list_of_creatures.DEMON_1].prefstring[0] then
        insert_preference(unit,1,list_of_creatures.DEMON_1)
    end
    if #df.global.world.poetic_forms.all then
        insert_preference(unit,9,0) -- this just inserts the first song out of typically many.
    end
    if #df.global.world.musical_forms.all then
        insert_preference(unit,10,0) -- same goes for music
    end
    if #df.global.world.dance_forms.all then
        insert_preference(unit,11,0) -- and dancing
    end
end -- end GOTH profile

    prefcount = #(unit.status.current_soul.preferences)
    print ("After adjusting, unit "..dfhack.TranslateName(dfhack.units.getVisibleName(unit)).." has "..prefcount.." preferences")
end -- end of function brainwash_unit
-- ---------------------------------------------------------------------------
function clear_preferences(v)
    local unit=v
    local prefs=unit.status.current_soul.preferences
    for index,pref in ipairs(prefs) do
        pref:delete()
    end
    prefs:resize(0)
end
-- ---------------------------------------------------------------------------
function clearpref_all_dwarves()
    for _,v in ipairs(df.global.world.units.active) do
        if v.race == df.global.ui.race_id then
            print("Clearing Preferences for "..dfhack.TranslateName(dfhack.units.getVisibleName(v)))
            clear_preferences(v)
        end
    end
end
-- ---------------------------------------------------------------------------
function adjust_all_dwarves(profile)
    for _,v in ipairs(df.global.world.units.active) do
        if v.race == df.global.ui.race_id then
            print("Adjusting "..dfhack.TranslateName(dfhack.units.getVisibleName(v)))
            brainwash_unit(v,profile)
        end
    end
end
-- ---------------------------------------------------------------------------
function build_all_lists(printflag)
    list_of_inorganics={} -- Type 0 "Likes iron.."
    list_of_inorganics_string=""
    vec=df.global.world.raws.inorganics -- also df.global.world.raws.inorganics_subset[0].id available
    for k=0,#vec-1 do
        name=vec[k].id
        list_of_inorganics[name]=k
        list_of_inorganics_string=list_of_inorganics_string..name..","
    end
    if printflag==1 then
        print("\nTYPE 0 INORGANICS:"..list_of_inorganics_string) --    printall(list_of_inorganics)
    end
-- ------------------------------------
    list_of_creatures={} --dict[name]=number, Type 1/3 "Likes them for.." / "Detests .."
    vec=df.global.world.raws.creatures.all
    list_of_creatures_string=""
    for k=0,#vec-1 do
        name=vec[k].creature_id
        list_of_creatures[name]=k
        list_of_creatures_string=list_of_creatures_string..name..","
    end
    if printflag==1 then
        print("\nTYPE 1,3 CREATURES:"..list_of_creatures_string) --    printall(list_of_creatures)
    end
-- ------------------------------------
    list_of_plants={} -- Type 2 "Prefers to consume.." and Type 5 "Likes Plump Helmets for their rounded tops"
    -- (TODO could have edible only, and/or a different list for each-all edible meat/plants/drinks)
    list_of_plants_string=""
    vec=df.global.world.raws.plants.all
    for k=0,#vec-1 do
        name=vec[k].id
        list_of_plants[name]=k
        list_of_plants_string=list_of_plants_string..name..","
    end
    if printflag==1 then
        print("\nTYPE 2,5 PLANTS:"..list_of_plants_string) --    printall(list_of_plants)
    end
-- ------------------------------------
    list_of_items={} -- Type 4 "Likes armor.." (TODO need recursive material decode lists?)
    list_of_items_string=""
    -- [lua]# @dfhack.matinfo.decode(31,1)
    -- <material 31:1 CREATURE:TOAD_MAN:GUT>
    -- [lua]# @dfhack.matinfo.decode(0,1)
    -- <material 0:1 INORGANIC:GOLD>
    for k,v in ipairs(df.item_type) do
        list_of_items[v]=k
        list_of_items_string=list_of_items_string..v..","
    end
    if printflag==1 then
        print("\nTYPE 4 ITEMS:"..list_of_items_string) --    printall(list_of_items)
    end
-- ------------------------------------
    list_of_colors={} -- Type 7 "Likes the color.."
    list_of_colors_string = ""
    vec=df.global.world.raws.descriptors.colors
    for k=0,#vec-1 do
        name=vec[k].id
        list_of_colors[name]=k
        list_of_colors_string=list_of_colors_string..name..","
    end
    if printflag==1 then
        print("\nTYPE 7 COLORS:"..list_of_colors_string) --    printall(list_of_colors)
    end
-- ------------------------------------
    list_of_shapes={} -- Type 8 "Likes circles"
    list_of_shapes_string = ""
    vec=df.global.world.raws.descriptors.shapes
    for k=0,#vec-1 do
        name=vec[k].id
        list_of_shapes[name]=k
        list_of_shapes_string=list_of_shapes_string..name..","
    end
    if printflag==1 then
        print("\nTYPE 8 SHAPES:"..list_of_shapes_string) --    printall(list_of_shapes)
    end
-- ------------------------------------
    list_of_poems={} -- Type 9 "likes the words of.."
    list_of_poems_string = ""
    vec=df.global.world.poetic_forms.all
    for k=0,#vec-1 do
        name=dfhack.TranslateName(vec[k].name,true)
        list_of_poems[name]=k
        list_of_poems_string=list_of_poems_string..k..":"..name..","
    end
    if printflag==1 then
        print("\nTYPE 9 POEMS:"..list_of_poems_string) -- printall(list_of_poems)
    end
-- ------------------------------------
    list_of_music={} -- Type 10 "Likes the sound of.."
    list_of_music_string = ""
    vec=df.global.world.musical_forms.all
    for k=0,#vec-1 do
        name=dfhack.TranslateName(vec[k].name,true)
        list_of_music[name]=k
        list_of_music_string=list_of_music_string..k..":"..name..","
    end
    if printflag==1 then
        print("\nTYPE 10 MUSIC:"..list_of_music_string) --    printall(list_of_music)
    end
-- ------------------------------------
    list_of_dances={} -- Type 11
    list_of_dances_string = ""
    vec=df.global.world.dance_forms.all
    for k=0,#vec-1 do
        name=dfhack.TranslateName(vec[k].name,true)
        list_of_dances[name]=k
        list_of_dances_string=list_of_dances_string..k..":"..name..","
    end
    if printflag==1 then
        print("\nTYPE 11 DANCES:"..list_of_dances_string) --    printall(list_of_dances)
    end
end -- end func build_all_lists

-- ---------------------------------------------------------------------------
-- main script operation starts here
-- ---------------------------------------------------------------------------
pss_counter=31415926
utils = require 'utils'
printflag=0
build_all_lists(printflag)

local opt = ...

if opt and opt ~= "help" then
    if opt=="list" then
        printflag=1
        build_all_lists(printflag)
        return
    end
    if opt=="clear_one" then
        local unit = dfhack.gui.getSelectedUnit()
        if unit==nil then
            print ("No unit available!  Aborting with extreme prejudice.")
            return
        end
        clear_preferences(unit)
        prefcount = #(unit.status.current_soul.preferences)
        print ("After clearing, unit "..dfhack.TranslateName(dfhack.units.getVisibleName(unit)).." has "..prefcount.." preferences")
        return
    end
    if opt=="clear_all" then
        clearpref_all_dwarves()
        return
    end
    if opt=="goth" then
        local profile="GOTH"
        local unit = dfhack.gui.getSelectedUnit()
        if unit==nil then
            print ("No unit available!  Aborting with extreme prejudice.")
        return
        end
        clear_preferences(unit)
        brainwash_unit(unit,profile)
        return
    end
    if opt=="one" then
        local profile="IDEAL"
        local unit = dfhack.gui.getSelectedUnit()
        if unit==nil then
            print ("No unit available!  Aborting with extreme prejudice.")
        return
        end
        clear_preferences(unit)
        brainwash_unit(unit,profile)
        return
    end
    if opt=="all" then
        local profile="IDEAL"
        clearpref_all_dwarves()
        adjust_all_dwarves(profile)
        return
    end
    if opt=="goth_all" then
        local profile="GOTH"
        clearpref_all_dwarves()
        adjust_all_dwarves(profile)
        return
    end
else
    print ("Sets preferences of one dwarf, or of all dwarves, using profiles.")
    print ("Valid options:")
    print ("list       -- show available preference type lists")
    print ("clear_one  -- clear preferences of selected unit")
    print ("clear_all  -- clear preferences of all units")
    print ("goth       -- alter current dwarf preferences to Goth")
    print ("goth_all   -- alter all dwarf preferences to Goth")
    print ("one        -- alter current dwarf preferences to Ideal")
    print ("all        -- alter all dwarf preferences to Ideal")
end
