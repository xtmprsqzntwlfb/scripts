--rename items or units with the native interface
--[====[

names
=====

Rename units or items.  Usage:
:-help:    print this help message
:-if a first name is desired press f, leave blank to clear current first name
:-if viewing an artifact you can rename it
:-if viewing a unit you can rename them

]====]

local gui = require 'gui'
local dlg = require 'gui.dialogs'
local widgets = require 'gui.widgets'
local utils = require 'utils'

validArgs = validArgs or utils.invert({
    'help',
})
local args = utils.processArgs({...}, validArgs)
if args.help then
    print(
[[names.lua
arguments:
    -help
        print this help message
    if a first name is desired press f, leave blank to clear current first name
    if viewing an artifact you can rename it
    if viewing a unit you can rename them
]])
    return
end
namescr = defclass(namescr, gui.Screen)
namescr.focus_path = 'names'
function namescr:init()
    self:addviews{
        widgets.Label{
            view_id='namescr',
            frame = {b=4, l=1},
            text = {
                {text = "Press f to Change First Name"},NEWLINE,
                {text = "Press Esc to Set Name and Exit"},
            },
        }
    }

    local parent = dfhack.gui.getCurViewscreen()
    local trg = dfhack.gui.getAnyUnit(parent)
    if trg then
        -- ok
    elseif df.viewscreen_itemst:is_instance(parent) then
        fact = dfhack.items.getGeneralRef(parent.item, df.general_ref_type.IS_ARTIFACT)
        if fact then
            trg = df.artifact_record.find(fact.artifact_id)
        end
    elseif df.viewscreen_dungeon_monsterstatusst:is_instance(parent) then
        uid = parent.unit.id
        trg = df.unit.find(uid)
    elseif df.global.ui_advmode.menu == df.ui_advmode_menu.Look then
        local t_look = df.global.ui_look_list.items[df.global.ui_look_cursor]
        if t_look.type == df.ui_look_list.T_items.T_type.Unit then
            trg = t_look.unit
        end
    else
        qerror('Could not find valid target')
    end
    if trg.name.language == -1 then
        qerror("Target's name does not have a language")
    end
    self.trg = trg
    local choices = df.viewscreen_setupadventurest:new()
    choices.page = df.viewscreen_setupadventurest.T_page.Background
    local tn = choices.adventurer
    utils.assign(tn.name, trg.name)
    gui.simulateInput(choices, 'A_CUST_NAME')
end
function namescr:setName()
    local parent = self._native.parent
    for k = 0,6 do
        self.trg.name.words[k] = parent.name.words[k]
        self.trg.name.parts_of_speech[k] = parent.name.parts_of_speech[k]
        self.trg.name.language = parent.name.language
        self.trg.name.has_name = parent.name.has_name
    end
end
function namescr:setFirst()
    dlg.showInputPrompt("Set First Name?","First: ",COLOR_WHITE,'',
        function(str)
            self._native.parent.name.first_name = str
            self.trg.name.first_name = str
        end)
end
function namescr:onRenderBody(dc)
    self._native.parent:render()
end
function namescr:onInput(keys)
    if keys.SELECT then
        self:setName()
    end
    if keys.CUSTOM_F then
        self:setFirst()
    end
    if keys.LEAVESCREEN then
        self:setName()
        self:dismiss()
        dfhack.screen.dismiss(self._native.parent)
    end
    return self:sendInputToParent(keys)
end

if dfhack.gui.getViewscreenByType(df.viewscreen_layer_choose_language_namest, 0) then
    qerror('names screen already shown')
else
    namescr():show()
end
