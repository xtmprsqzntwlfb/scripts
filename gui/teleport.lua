-- A front-end for the teleport script

--[====[

gui/teleport
============

A front-end for the `teleport` script that allows choosing a unit and destination
using the in-game cursor.

]====]

guidm = require 'gui.dwarfmode'
teleport = reqscript 'teleport'
widgets = require 'gui.widgets'

TeleportSidebar = defclass(TeleportSidebar, guidm.MenuOverlay)

function TeleportSidebar:init()
    self:addviews{
        widgets.Label{
            frame = {b=1, l=1},
            text = {
                {key = 'UNITJOB_ZOOM_CRE', text = ': Zoom to unit', on_activate = self:callback('zoom_unit'),
                    enabled = function() return self.unit end},
                NEWLINE,
                NEWLINE,
                {key = 'SELECT', text = ': Choose, ', on_activate = self:callback('choose')},
                {key = 'LEAVESCREEN', text = ': Back', on_activate = self:callback('back')},
                NEWLINE,
                {key = 'LEAVESCREEN_ALL', text = ': Exit to map', on_activate = self:callback('dismiss')},
            },
        },
    }
    self.in_pick_pos = false
end

function TeleportSidebar:onAboutToShow(parent)
    if not df.viewscreen_dwarfmodest:is_instance(parent) then
        qerror("This screen requires the main dwarfmode view")
    end

    self.old_mode = df.global.ui.main.mode
    if df.global.ui.main.mode == df.ui_sidebar_mode.Default then
        parent:feed_key(df.interface_key.D_VIEWUNIT)
    end

    local mode = df.global.ui.main.mode
    if mode ~= df.ui_sidebar_mode.LookAround and mode ~= df.ui_sidebar_mode.ViewUnits then
        qerror(("Use '%s' or '%s' to select a unit"):format(
            dfhack.screen.getKeyDisplay(df.interface_key.D_VIEWUNIT),
            dfhack.screen.getKeyDisplay(df.interface_key.D_LOOK)
        ))
    end
end

function TeleportSidebar:choose()
    if not self.in_pick_pos then
        self.in_pick_pos = true
        df.global.ui.main.mode = df.ui_sidebar_mode.LookAround
    else
        teleport.teleport(self.unit, xyz2pos(pos2xyz(df.global.cursor)))
        self:dismiss()
    end
end

function TeleportSidebar:back()
    if self.in_pick_pos then
        self.in_pick_pos = false
        df.global.ui.main.mode = self.old_mode
    else
        self:dismiss()
    end
end

function TeleportSidebar:zoom_unit()
    df.global.cursor:assign(xyz2pos(pos2xyz(self.unit.pos)))
    self:getViewport():centerOn(self.unit.pos):set()
end

function TeleportSidebar:onRenderBody(p)
    p:seek(1, 1)
    if self.in_pick_pos then
        p:string('Select destination'):newline(1):newline(1)

        local cursor = df.global.cursor
        local block = dfhack.maps.getTileBlock(pos2xyz(cursor))
        if block then
            p:string(df.tiletype[block.tiletype[cursor.x % 16][cursor.y % 16]], COLOR_CYAN)
        else
            p:string('Unknown tile', COLOR_RED)
        end
    else
        self.unit = dfhack.gui.getAnyUnit(self._native.parent)
        p:string('Select unit:'):newline(1):newline(1)
        if self.unit then
            p:string(dfhack.TranslateName(self.unit.name), COLOR_WHITE):newline(1)
        else
            p:string('No unit selected', COLOR_LIGHTRED)
        end
    end
end

function TeleportSidebar:onInput(keys)
    TeleportSidebar.super.onInput(self, keys)
    TeleportSidebar.super.propagateMoveKeys(self, keys)
end

function TeleportSidebar:onDismiss()
    df.global.ui.main.mode = self.old_mode
end

function TeleportSidebar:onGetSelectedUnit()
    return self.unit
end

TeleportSidebar():show()
