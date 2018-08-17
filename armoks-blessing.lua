-- Adjust all attributes of all dwarves to an ideal
-- by vjek
--[====[

armoks-blessing
===============
Runs the equivalent of `rejuvenate`, `elevate-physical`, `elevate-mental`, and
`brainwash` on all dwarves currently on the map.  This is an extreme change,
which sets every stat and trait to an ideal easy-to-satisfy preference.

Without providing arguments, only attributes, age, and personalities will be adjusted.
Adding arguments allows for skills or classes to be adjusted to legendary (maximum).

Arguments::
    list
        Prints list of all skills
        example:
            armoks-blessing list

    classes
        Prints list of all classes
        example:
            armoks-blessing classes

    all
        Set all skills, for all Dwarves, to legendary
        example:
            armoks-blessing all

    <skill name>
        Set a specific skill, for all Dwarves, to legendary
        example:
            armoks-blessing RANGED_COMBAT
                All Dwarves become a Legendary Archer

    <class name>
        Set a specific class (group of skills), for all Dwarves, to legendary
        example:
            armoks-blessing Medical
                All Dwarves will have all medical related skills set to legendary

List of Skills::
    ALCHEMY for Alchemy
    SNEAK for Ambush
    ANIMALCARE for Animal Caretaking
    DISSECT_VERMIN for Animal Dissection
    ANIMALTRAIN for Animal Training
    APPRAISAL for Appraisal
    RANGED_COMBAT for Archery
    ARMOR for Armor
    FORGE_ARMOR for Armorsmithing
    ASTRONOMY for Astronomy
    AXE for Axe
    BALANCE for Balance
    BEEKEEPING for Beekeeping
    BITE for Biting
    BLOWGUN for Blowgun
    BONECARVE for Bone Carving
    SET_BONE for Bone Setting
    BOOKBINDING for Bookbinding
    BOW for Bow
    BOWYER for Bowmaking
    BREWING for Brewing
    DESIGNBUILDING for Building Design
    BUTCHER for Butchery
    CARPENTRY for Carpentry
    CHEESEMAKING for Cheese Making
    CHEMISTRY for Chemistry
    CLIMBING for Climbing
    CLOTHESMAKING for Clothes Making
    COMEDY for Comedy
    CONCENTRATION for Concentration
    CONSOLE for Consoling
    CONVERSATION for Conversation
    COOK for Cooking
    COORDINATION for Coordination
    CRITICAL_THINKING for Critical Thinking
    CROSSBOW for Crossbow
    CRUTCH_WALK for Crutch-walking
    DANCE for Dance
    DIAGNOSE for Diagnostics
    DISCIPLINE for Discipline
    DODGING for Dodging
    DYER for Dyeing
    DETAILSTONE for Engraving
    MELEE_COMBAT for Fighting
    PROCESSFISH for Fish Cleaning
    DISSECT_FISH for Fish Dissection
    FISH for Fishing
    FLATTERY for Flattery
    FLUID_ENGINEER for Fluid Engineer
    SMELT for Furnace Operation
    GELD for Gelding
    CUTGEM for Gem Cutting
    ENCRUSTGEM for Gem Setting
    GEOGRAPHY for Geography
    GLASSMAKER for Glassmaking
    GLAZING for Glazing
    PLANT for Growing
    HAMMER for Hammer
    HERBALISM for Herbalism
    INTIMIDATION for Intimidation
    JUDGING_INTENT for Judging Intent
    PLAY_KEYBOARD_INSTRUMENT for Keyboard Instrument
    STANCE_STRIKE for Kicking
    KNAPPING for Knapping
    DAGGER for Knife
    WHIP for Lash
    LEADERSHIP for Leadership
    LEATHERWORK for Leatherworkering
    LOGIC for Logic
    LYE_MAKING for Lye Making
    LYING for Lying
    MACE for Mace
    MECHANICS for Machinery
    MASONRY for Masonry
    MATHEMATICS for Mathematics
    METALCRAFT for Metal Crafting
    FORGE_FURNITURE for Metalsmithing
    MILITARY_TACTICS for Military Tactics
    MILK for Milking
    MILLING for Milling
    MINING for Mining
    MISC_WEAPON for Misc. Object
    MAKE_MUSIC for Music
    MAGIC_NATURE for Nature
    NEGOTIATION for Negotiation
    SITUATIONAL_AWARENESS for Observation
    OPTICS_ENGINEER for Optics Engineer
    ORGANIZATION for Organization
    PACIFY for Pacification
    PAPERMAKING for Papermaking
    PLAY_PERCUSSION_INSTRUMENT for Percussion Instrument
    PERSUASION for Persuasion
    PIKE for Pike
    POETRY for Poetry
    POTASH_MAKING for Potash Making
    POTTERY for Pottery
    PRESSING for Pressing
    PROSE for Prose
    OPERATE_PUMP for Pump Operation
    READING for Reading
    RECORD_KEEPING for Record Keeping
    SHEARING for Shearing
    SHIELD for Shield
    SIEGECRAFT for Siege Engineering
    SIEGEOPERATE for Siege Operation
    SING_MUSIC for Singing
    SOAP_MAKING for Soap Making
    SPEAKING for Speaking
    SPEAR for Spear
    SPINNING for Spinning
    STONECRAFT for Stone Crafting
    EXTRACT_STRAND for Strand Extraction
    GRASP_STRIKE for Striking
    PLAY_STRINGED_INSTRUMENT for Stringed Instrument
    KNOWLEDGE_ACQUISITION for Studying
    SURGERY for Surgery
    SUTURE for Suturing
    SWIMMING for Swimming
    SWORD for Sword
    TANNER for Tanning
    TEACHING for Teaching
    PROCESSPLANTS for Threshing
    THROW for Throwing
    TRACKING for Tracking
    TRAPPING for Trapping
    WAX_WORKING for Wax Working
    FORGE_WEAPON for Weaponsmithing
    WEAVING for Weaving
    PLAY_WIND_INSTRUMENT for Wind Instrument
    WOOD_BURNING for Wood Burning
    WOODCRAFT for Wood Crafting
    WOODCUTTING for Wood Cutting
    DRESS_WOUNDS for Wound Dressing
    WRESTLING for Wrestling
    WRITING for Writing

List of Classes::
    Normal
    Medical
    Personal
    Social
    Cultural
    MilitaryWeapon
    MilitaryUnarmed
    MilitaryAttack
    MilitaryDefense
    MilitaryMisc


]====]
local utils = require 'utils'
function rejuvenate(unit)
    if unit==nil then
        print ("No unit available!  Aborting with extreme prejudice.")
        return
    end

    local current_year=df.global.cur_year
    local newbirthyear=current_year - 20
    if unit.birth_year < newbirthyear then
        unit.birth_year=newbirthyear
    end
    if unit.old_year < current_year+100 then
        unit.old_year=current_year+100
    end

end
-- ---------------------------------------------------------------------------
function brainwash_unit(unit)
    if unit==nil then
        print ("No unit available!  Aborting with extreme prejudice.")
        return
    end

    local profile ={75,25,25,75,25,25,25,99,25,25,25,50,75,50,25,75,75,50,75,75,25,75,75,50,75,25,50,25,75,75,75,25,75,75,25,75,25,25,75,75,25,75,75,75,25,75,75,25,25,50}
    local i

    for i=1, #profile do
        unit.status.current_soul.personality.traits[i-1]=profile[i]
    end

end
-- ---------------------------------------------------------------------------
function elevate_attributes(unit)
    if unit==nil then
        print ("No unit available!  Aborting with extreme prejudice.")
        return
    end

    if unit.status.current_soul then
        for k,v in pairs(unit.status.current_soul.mental_attrs) do
            v.value=v.max_value
        end
    end

    for k,v in pairs(unit.body.physical_attrs) do
        v.value=v.max_value
    end
end
-- ---------------------------------------------------------------------------
-- this function will return the number of elements, starting at zero.
-- useful for counting things where #foo doesn't work
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
-- ---------------------------------------------------------------------------
function make_legendary(skillname,unit)
    local skillnamenoun,skillnum

    if unit==nil then
        print ("No unit available!  Aborting with extreme prejudice.")
        return
    end

    if (df.job_skill[skillname]) then
        skillnamenoun = df.job_skill.attrs[df.job_skill[skillname]].caption_noun
    else
        print ("The skill name provided is not in the list.")
        return
    end

    if skillnamenoun ~= nil then
        skillnum = df.job_skill[skillname]
        utils.insert_or_update(unit.status.current_soul.skills, { new = true, id = skillnum, rating = 20 }, 'id')
        print (unit.name.first_name.." is now a Legendary "..skillnamenoun)
    else
        print ("Empty skill name noun, bailing out!")
        return
    end
end
-- ---------------------------------------------------------------------------
function BreathOfArmok(unit)

    if unit==nil then
        print ("No unit available!  Aborting with extreme prejudice.")
        return
    end
    local i

    local count_max = count_this(df.job_skill)
    for i=0, count_max do
        utils.insert_or_update(unit.status.current_soul.skills, { new = true, id = i, rating = 20 }, 'id')
    end
    print ("The breath of Armok has engulfed "..unit.name.first_name)
end
-- ---------------------------------------------------------------------------
function LegendaryByClass(skilltype,v)
    local unit=v
    if unit==nil then
        print ("No unit available!  Aborting with extreme prejudice.")
        return
    end

    local i
    local skillclass
    local count_max = count_this(df.job_skill)
    for i=0, count_max do
        skillclass = df.job_skill_class[df.job_skill.attrs[i].type]
        if skilltype == skillclass then
            print ("Skill "..df.job_skill.attrs[i].caption.." is type: "..skillclass.." and is now Legendary for "..unit.name.first_name)
            utils.insert_or_update(unit.status.current_soul.skills, { new = true, id = i, rating = 20 }, 'id')
        end
    end
end
-- ---------------------------------------------------------------------------
function PrintSkillList()
    local count_max = count_this(df.job_skill)
    local i
    for i=0, count_max do
        print("'"..df.job_skill.attrs[i].caption.."' "..df.job_skill[i].." Type: "..df.job_skill_class[df.job_skill.attrs[i].type])
    end
    print ("Provide the UPPER CASE argument, for example: PROCESSPLANTS rather than Threshing")
end
-- ---------------------------------------------------------------------------
function PrintSkillClassList()
    local i
    local count_max = count_this(df.job_skill_class)
    for i=0, count_max do
        print(df.job_skill_class[i])
    end
    print ("Provide one of these arguments, and all skills of that type will be made Legendary")
    print ("For example: Medical will make all medical skills legendary")
end
-- ---------------------------------------------------------------------------
function adjust_all_dwarves(skillname)
    for _,v in ipairs(df.global.world.units.all) do
        if v.race == df.global.ui.race_id then
            print("Adjusting "..dfhack.TranslateName(dfhack.units.getVisibleName(v)))
            brainwash_unit(v)
            elevate_attributes(v)
            rejuvenate(v)
            if skillname then
                if skillname=="Normal" or skillname=="Medical" or skillname=="Personal" or skillname=="Social" or skillname=="Cultural" or skillname=="MilitaryWeapon" or skillname=="MilitaryAttack" or skillname=="MilitaryDefense" or skillname=="MilitaryMisc" then
                    LegendaryByClass(skillname,v)
                elseif skillname=="all" then
                    BreathOfArmok(v)
                else
                    make_legendary(skillname,v)
                end
            end
        end
    end
end
-- ---------------------------------------------------------------------------
-- main script operation starts here
-- ---------------------------------------------------------------------------
local args = {...}
local opt = args[1]
local skillname

if opt then
    if opt=="list" then
        PrintSkillList()
        return
    end
    if opt=="classes" then
        PrintSkillClassList()
        return
    end
    skillname = opt
else
    print ("No skillname supplied, no skills will be adjusted.  Pass argument 'list' to see a skill list, 'classes' to show skill classes, or use 'all' if you want all skills legendary.")
end

adjust_all_dwarves(skillname)
