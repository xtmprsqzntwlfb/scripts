-- trigger commands based on attacks with certain items
--author expwnent
--based on itemsyndrome by Putnam
--equipment modes and combined trigger conditions added by AtomicChicken
local usage = [====[

modtools/item-trigger
=====================
This powerful tool triggers DFHack commands when a unit equips, unequips, or
attacks another unit with specified item types, specified item materials, or
specified item contaminants.

Arguments::

    -clear
        clear all registered triggers
    -checkAttackEvery n
        check the attack event at least every n ticks
    -checkInventoryEvery n
        check inventory event at least every n ticks
    -itemType type
        trigger the command for items of this type
        examples:
            ITEM_WEAPON_PICK
            RING
    -onStrike
        trigger the command on appropriate weapon strikes
    -onEquip mode
        trigger the command when someone equips an appropriate item
        Optionally, the equipment mode can be specified
        Possible values for mode:
            Hauled
            Weapon
            Worn
            Piercing
            Flask
            WrappedAround
            StuckIn
            InMouth
            Pet
            SewnInto
            Strapped
        multiple values can be specified simultaneously
        example: -onEquip [ Weapon Worn Hauled ]
    -onUnequip mode
        trigger the command when someone unequips an appropriate item
        see above note regarding 'mode' values
    -material mat
        trigger the commmand on items with the given material
        examples
            INORGANIC:IRON
            CREATURE:DWARF:BRAIN
            PLANT:OAK:WOOD
    -contaminant mat
        trigger the command for items with a given material contaminant
        examples
            INORGANIC:GOLD
            CREATURE:HUMAN:BLOOD
            PLANT:MUSHROOM_HELMET_PLUMP:DRINK
            WATER
    -command [ commandStrs ]
        specify the command to be executed
        commandStrs
            \\ATTACKER_ID
            \\DEFENDER_ID
            \\ITEM_MATERIAL
            \\ITEM_MATERIAL_TYPE
            \\ITEM_ID
            \\ITEM_TYPE
            \\CONTAMINANT_MATERIAL
            \\CONTAMINANT_MATERIAL_TYPE
            \\CONTAMINANT_MATERIAL_INDEX
            \\MODE
            \\UNIT_ID
            \\anything -> \anything
            anything -> anything
]====]
local eventful = require 'plugins.eventful'
local utils = require 'utils'

itemTriggers = itemTriggers or {}
eventful.enableEvent(eventful.eventType.UNIT_ATTACK,1) -- this event type is cheap, so checking every tick is fine
eventful.enableEvent(eventful.eventType.INVENTORY_CHANGE,5) -- this is expensive, but you might still want to set it lower
eventful.enableEvent(eventful.eventType.UNLOAD,1)

eventful.onUnload.itemTrigger = function()
 itemTriggers = {}
end

function processTrigger(command)
 local command2 = {}
 for i,arg in ipairs(command.command) do
  if arg == '\\ATTACKER_ID' then
   command2[i] = '' .. command.attacker.id
  elseif arg == '\\DEFENDER_ID' then
   command2[i] = '' .. command.defender.id
  elseif arg == '\\ITEM_MATERIAL' then
   command2[i] = command.itemMat:getToken()
  elseif arg == '\\ITEM_MATERIAL_TYPE' then
   command2[i] = command.itemMat['type']
  elseif arg == '\\ITEM_MATERIAL_INDEX' then
   command2[i] = command.itemMat.index
  elseif arg == '\\ITEM_ID' then
   command2[i] = '' .. command.item.id
  elseif arg == '\\ITEM_TYPE' then
   command2[i] = command.itemType
  elseif arg == '\\CONTAMINANT_MATERIAL' then
   command2[i] = command.contaminantMat:getToken()
  elseif arg == '\\CONTAMINANT_MATERIAL_TYPE' then
   command2[i] = command.contaminantMat['type']
  elseif arg == '\\CONTAMINANT_MATERIAL_INDEX' then
   command2[i] = command.contaminantMat.index
  elseif arg == '\\MODE' then
   command2[i] = command.mode
  elseif arg == '\\UNIT_ID' then
   command2[i] = command.unit.id
  elseif string.sub(arg,1,1) == '\\' then
   command2[i] = string.sub(arg,2)
  else
   command2[i] = arg
  end
 end
 dfhack.run_command(table.unpack(command2))
end

function getitemType(item)
 if item:getSubtype() ~= -1 and dfhack.items.getSubtypeDef(item:getType(),item:getSubtype()) then
  itemType = dfhack.items.getSubtypeDef(item:getType(),item:getSubtype()).id
 else
  itemType = df.item_type[item:getType()]
 end
 return itemType
end

function compareInvModes(reqMode,itemMode)
 if reqMode == nil then
  return
 end
 if not tonumber(reqMode) and df.unit_inventory_item.T_mode[itemMode] == tostring(reqMode) then
  return true
 elseif tonumber(reqMode) == itemMode then
  return true
 end
end

function checkMode(triggerArgs,table)
 local mode = table.mode
 for _,argArray in ipairs(triggerArgs) do
  if argArray[tostring(mode)] then
   local modeType = table.modeType
   local reqModeType = argArray[tostring(mode)]
   if #reqModeType == 1 then
    if compareInvModes(reqModeType,modeType) or compareInvModes(reqModeType[1],modeType) then
     utils.fillTable(argArray,table)
     processTrigger(argArray)
     utils.unfillTable(argArray,table)
    end
   elseif #reqModeType > 1 then
    for _,r in ipairs(reqModeType) do
     if compareInvModes(r,modeType) then
      utils.fillTable(argArray,table)
      processTrigger(argArray)
      utils.unfillTable(argArray,table)
     end
    end
   else
    utils.fillTable(argArray,table)
    processTrigger(argArray)
    utils.unfillTable(argArray,table)
   end
  end
 end
end

function checkForTrigger(table)
 local itemTypeStr = table.itemType
 local itemMatStr = table.itemMat:getToken()
 local contaminantStr
 if table.contaminantMat then
  contaminantStr = table.contaminantMat:getToken()
 end
 for _,triggerBundle in ipairs(itemTriggers) do
  local count = 0
  local trigger = triggerBundle['triggers']
  local triggerCount = 0
  for _,t in pairs(trigger) do
   triggerCount = triggerCount+1
  end
  if itemTypeStr and trigger['itemType'] == itemTypeStr then
   count = count+1
  end
  if itemMatStr and trigger['material'] == itemMatStr then
   count = count+1
  end
  if contaminantStr and trigger['contaminant'] == contaminantStr then
   count = count+1
  end
  if count == triggerCount then
   checkMode(triggerBundle['args'],table)
  end
 end
end

function checkForDuplicates(args)
 for k,triggerBundle in ipairs(itemTriggers) do
  local count = 0
  local trigger = triggerBundle['triggers']
  if trigger['itemType'] == args.itemType then
   count = count+1
  end
  if trigger['material'] == args.material then
   count = count+1
  end
  if trigger['contaminant'] == args.contaminant then
   count = count+1
  end
  if count == 3 then--counts nil values too
   return k
  end
 end
end

function handler(table)
 local itemMat = dfhack.matinfo.decode(table.item)
 local itemType = getitemType(table.item)
 table.itemMat = itemMat
 table.itemType = itemType

 if table.item.contaminants and #table.item.contaminants > 0 then
  for _,contaminant in ipairs(table.item.contaminants or {}) do
   local contaminantMat = dfhack.matinfo.decode(contaminant.mat_type, contaminant.mat_index)
   table.contaminantMat = contaminantMat
   checkForTrigger(table)
   table.contaminantMat = nil
  end
 else
  checkForTrigger(table)
 end
end

function equipHandler(unit, item, mode, modeType)
 local table = {}
 table.mode = tostring(mode)
 table.modeType = tonumber(modeType)
 table.item = df.item.find(item)
 table.unit = df.unit.find(unit)
 if table.item and table.unit then -- they must both be not nil or errors will occur after this point with instant reactions.
  handler(table)
 end
end

function modeHandler(unit, item, modeOld, modeNew)
 local mode
 local modeType
 if modeOld then
  mode = "onUnequip"
  modeType = modeOld
  equipHandler(unit, item, mode, modeType)
 end
 if modeNew then
  mode = "onEquip"
  modeType = modeNew
  equipHandler(unit, item, mode, modeType)
 end
end

eventful.onInventoryChange.equipmentTrigger = function(unit, item, item_old, item_new)
 local modeOld = (item_old and item_old.mode)
 local modeNew = (item_new and item_new.mode)
 if modeOld ~= modeNew then
  modeHandler(unit,item,modeOld,modeNew)
 end
end

eventful.onUnitAttack.attackTrigger = function(attacker,defender,wound)
 attacker = df.unit.find(attacker)
 defender = df.unit.find(defender)

 if not attacker then
  return
 end

 local attackerWeapon
 for _,item in ipairs(attacker.inventory) do
  if item.mode == df.unit_inventory_item.T_mode.Weapon then
   attackerWeapon = item.item
   break
  end
 end

 if not attackerWeapon then
  return
 end

 local table = {}
 table.attacker = attacker
 table.defender = defender
 table.item = attackerWeapon
 table.mode = 'onStrike'
 handler(table)
end

validArgs = validArgs or utils.invert({
 'clear',
 'help',
 'checkAttackEvery',
 'checkInventoryEvery',
 'command',
 'itemType',
 'onStrike',
 'onEquip',
 'onUnequip',
 'material',
 'contaminant',
})
local args = utils.processArgs({...}, validArgs)

if args.help then
 print(usage)
 return
end

if args.clear then
 itemTriggers = {}
end

if args.checkAttackEvery then
 if not tonumber(args.checkAttackEvery) then
  error('checkAttackEvery must be a number')
 end
 eventful.enableEvent(eventful.eventType.UNIT_ATTACK,tonumber(args.checkAttackEvery))
end

if args.checkInventoryEvery then
 if not tonumber(args.checkInventoryEvery) then
  error('checkInventoryEvery must be a number')
 end
 eventful.enableEvent(eventful.eventType.INVENTORY_CHANGE,tonumber(args.checkInventoryEvery))
end

if not args.command then
 if not args.clear then
  error 'specify a command'
 end
 return
end

if args.itemType and dfhack.items.findType(args.itemType) == -1 then
 local temp
 for _,itemdef in ipairs(df.global.world.raws.itemdefs.all) do
  if itemdef.id == args.itemType then
   temp = args.itemType--itemdef.subtype
   break
  end
 end
 if not temp then
  error 'Could not find item type.'
 end
 args.itemType = temp
end

local numConditions = (args.material and 1 or 0) + (args.itemType and 1 or 0) + (args.contaminant and 1 or 0)
if numConditions == 0 then
 error 'Specify at least one material, itemType or contaminant.'
end

local index
if #itemTriggers > 0 then
 index = checkForDuplicates(args)
end

if not index then
 index = #itemTriggers+1
 itemTriggers[index] = {}
 local triggerArray = {}
 if args.itemType then
  triggerArray['itemType'] = args.itemType
 end
 if args.material then
  triggerArray['material'] = args.material
 end
 if args.contaminant then
  triggerArray['contaminant'] = args.contaminant
 end
 itemTriggers[index]['triggers'] = triggerArray
end

if not itemTriggers[index]['args'] then
 itemTriggers[index]['args'] = {}
end
local triggerArgs = itemTriggers[index]['args']
table.insert(triggerArgs,args)
local argsArray = triggerArgs[#triggerArgs]
argsArray.itemType = nil
argsArray.material = nil
argsArray.contaminant = nil
