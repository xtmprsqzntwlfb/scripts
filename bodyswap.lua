-- Shifts player control over to another unit in adventure mode.
-- author: Atomic Chicken
-- based on "assumecontrol.lua" by maxthyme, as well as the defunct advtools plugin "adv-bodyswap"
-- nemesis and historical figure creation uses slightly modified functions from modtools/create-unit

--[====[

bodyswap
========

Shifts player control over to another unit (including wild animals) in adventure mode.
Usage:

:bodyswap:
    Swaps into the unit selected in the UI (for example, when viewing the unit's status screen or description).

:bodyswap -unit [unitId]:
    Swaps into the unit corresponding to the specified id.

]====]

local utils = require 'utils'
validArgs = validArgs or utils.invert({
'unit',
'help'
})
local args = utils.processArgs({...}, validArgs)

local usage = [====[

bodyswap
========
This script allows the player to gain control over a new unit in adventurer mode
whilst simultaneously loosing control over their current character.

To specify the target unit, simply select it in the user interface,
such as by opening the unit's status screen or viewing its description
and enter "bodyswap" in the DFHack console.

Alternatively, the target unit can be specified by its unit id as shown below.

Arguments::

    -unit id
        replace "id" with the unit id of your target
        example: 
            bodyswap -unit 42

]====]

if args.help then
 print(usage)
 return
end

if not dfhack.world.isAdventureMode() then
  qerror("This script can only be used in adventure mode!")
end

function setNewAdvNemFlags(nem)
  nem.flags.ACTIVE_ADVENTURER = true
  nem.flags.RETIRED_ADVENTURER = false
  nem.flags.ADVENTURER = true
end
function setOldAdvNemFlags(nem)
  nem.flags.ACTIVE_ADVENTURER = false
  nem.flags.RETIRED_ADVENTURER = true
  nem.unit.idle_area.x = nem.unit.pos.x
  nem.unit.idle_area.y = nem.unit.pos.y
  nem.unit.idle_area.z = nem.unit.pos.z
end

function clearNemesisFromSite(nem)
-- this is a workaround for a bug which tends to cause duplication of the unit entry in df.global.world.units.active when the site to which a historical figure is linked is reloaded with the unit present
-- appears to fix the problem without causing any noticeable issues
  if not nem.figure then
    return
  end
  for _,link in ipairs(nem.figure.site_links) do
    local site = df.world_site.find(link.site)
    for i = #site.unk_1.nemesis-1,0,-1 do
      if site.unk_1.nemesis[i] == nem.id then
        site.unk_1.nemesis:erase(i)
      end
    end
  end
end

function swapAdvUnit()

  local newUnit
  if args.unit then
    newUnit = df.unit.find(tonumber(args.unit))
  else
    newUnit = dfhack.gui.getSelectedUnit()
  end
  if not newUnit then
    print("Enter the following if you require assistance: bodyswap -help")
    if args.unit then
      qerror("Invalid unit id: "..args.unit)
    else
      qerror("Target unit not specified!")
    end
  end

  local oldUnit = df.nemesis_record.find(df.global.ui_advmode.player_id).unit
  if newUnit == oldUnit then
    return
  end

  local activeUnits = df.global.world.units.active
  local oldUnitIndex
  if activeUnits[0] == oldUnit then
    oldUnitIndex = 0
  else
    for i,u in pairs(activeUnits) do
      if u == oldUnit then
        oldUnitIndex = i
        break
      end
    end
  end
  local newUnitIndex
  for i,u in pairs(activeUnits) do
    if u == newUnit then
      newUnitIndex = i
      break
    end
  end

  if not newUnitIndex then
    qerror("Target unit index not found!")
  end

  activeUnits[newUnitIndex] = oldUnit
  activeUnits[oldUnitIndex] = newUnit

  local newNem = dfhack.units.getNemesis(newUnit) or createNemesis(newUnit)
  if newNem then
    local oldNem = dfhack.units.getNemesis(oldUnit)
    if oldNem then
      setOldAdvNemFlags(oldNem)
    end
    setNewAdvNemFlags(newNem)
    clearNemesisFromSite(newNem)
    df.global.ui_advmode.player_id = newNem.id
  end
end

local function allocateNewChunk(hist_entity)
  hist_entity.save_file_id = df.global.unit_chunk_next_id
  df.global.unit_chunk_next_id = df.global.unit_chunk_next_id+1
  hist_entity.next_member_idx = 0
end

local function allocateIds(nemesis_record,hist_entity)
  if hist_entity.next_member_idx == 100 then
    allocateNewChunk(hist_entity)
  end
  nemesis_record.save_file_id = hist_entity.save_file_id
  nemesis_record.member_idx = hist_entity.next_member_idx
  hist_entity.next_member_idx = hist_entity.next_member_idx+1
end

function createFigure(unit,he,he_group)
  local hf = df.historical_figure:new()
  hf.id = df.global.hist_figure_next_id
  hf.race = unit.race
  hf.caste = unit.caste
  hf.profession = unit.profession
  hf.sex = unit.sex
  df.global.hist_figure_next_id=df.global.hist_figure_next_id+1
  hf.appeared_year = df.global.cur_year

  hf.born_year = unit.birth_year
  hf.born_seconds = unit.birth_time
  hf.curse_year = unit.curse_year
  hf.curse_seconds = unit.curse_time
  hf.birth_year_bias = unit.birth_year_bias
  hf.birth_time_bias = unit.birth_time_bias
  hf.old_year = unit.old_year
  hf.old_seconds = unit.old_time
  hf.died_year = -1
  hf.died_seconds = -1
  hf.name:assign(unit.name)
  hf.civ_id = unit.civ_id
  hf.population_id = unit.population_id
  hf.breed_id = -1
  hf.unit_id = unit.id
  hf.unit_id2 = unit.id

  hf.flags.never_cull = true

  df.global.world.history.figures:insert("#",hf)

  hf.info = df.historical_figure_info:new()
  hf.info.unk_14 = df.historical_figure_info.T_unk_14:new()
  hf.info.unk_14.unk_18 = -1; hf.info.unk_14.unk_1c = -1
  hf.info.skills = {new=true}

  unit.flags1.important_historical_figure = true
  unit.flags2.important_historical_figure = true
  unit.hist_figure_id = hf.id
  unit.hist_figure_id2 = hf.id

  if he then
    he.histfig_ids:insert('#',hf.id)
    he.hist_figures:insert('#',hf)

    hf.entity_links:insert("#",{new=df.histfig_entity_link_memberst,entity_id=unit.civ_id,link_strength=100})

    local hf_event_id = df.global.hist_event_next_id
    df.global.hist_event_next_id = df.global.hist_event_next_id+1
    df.global.world.history.events:insert("#",{new=df.history_event_add_hf_entity_linkst,year=unit.birth_year,
    seconds=unit.birth_time,id = hf_event_id,civ=hf.civ_id,histfig=hf.id,link_type=0})
  end
  return hf
end

function createNemesis(unit)
  local id = df.global.nemesis_next_id
  local nem = df.nemesis_record:new()

  nem.id = id
  nem.unit_id = unit.id
  nem.unit = unit
  nem.flags:resize(4)
  nem.flags[4] = true
  nem.flags[5] = true
  nem.flags[6] = true
  nem.flags[7] = true
  nem.flags[8] = true
  nem.flags[9] = true
  nem.unk10 = -1
  nem.unk11 = -1
  nem.unk12 = -1
  df.global.world.nemesis.all:insert("#",nem)
  df.global.nemesis_next_id = id+1
  unit.general_refs:insert("#",{new=df.general_ref_is_nemesisst,nemesis_id=id})

  nem.save_file_id = -1

  local civ_id = unit.civ_id
  local he
  if civ_id ~= -1 then
    he = df.historical_entity.find(civ_id)
    he.nemesis_ids:insert("#",id)
    he.nemesis:insert("#",nem)
    allocateIds(nem,he)
  end
  nem.figure = createFigure(unit,he)
  return nem
end

swapAdvUnit()