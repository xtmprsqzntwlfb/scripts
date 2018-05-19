--copy.lua
--[====[
    copy is a gui program designed to make designating easier.
]====]
--[[
 Author's Note:
 
 shoutout to twitch.tv/keupo
 created by flavorstreet
 
 pipicaca.
]]
local utils = require 'utils'
local gui = require 'gui'
local guidm = require 'gui.dwarfmode'
local dlg = require 'gui.dialogs'
local build = require 

CopyUI = defclass(CopyUI, guidm.MenuOverlay)

CopyUI.ATTRS {
    state='none',
    buffer=nil,
    offsetDirection=0,
    cull=true,
    blink=false,
    option='normal'
}
local digSymbols={' ', 'X', '_', 30, '>', '<'}
function CopyUI:init()
    self.saved_mode = df.global.ui.main.mode
end

function CopyUI:onShow()
    df.global.ui.main.mode = df.ui_sidebar_mode.Stockpiles
end

function CopyUI:onDestroy()
    df.global.ui.main.mode = self.saved_mode
end

local function getTileType(cursor)
    local block = dfhack.maps.getTileBlock(cursor)
    if block then
        return block.tiletype[cursor.x%16][cursor.y%16]
    else
        return 0
    end
end

local function paintMapTile(dc, vp, cursor, pos, ...)
    if not same_xyz(cursor, pos) then
        local stile = vp:tileToScreen(pos)
        if stile.z == 0 then
            dc:map(true):seek(stile.x,stile.y):char(...):map(false)
        end
    end
end

local function minToMax(...)
    local args={...}
    table.sort(args,function(a,b) return a < b end)
    return table.unpack(args)
    
end

local function cullBuffer(data) --there's probably a memory saving way of doing this
    local lowerX=math.huge
    local lowerY=math.huge
    local upperX=-math.huge
    local upperY=-math.huge
    for x=0,data.xlen do
        for y=0,data.ylen do
            if data[x][y].dig>0 then
                lowerX=math.min(x,lowerX)
                lowerY=math.min(y,lowerY)
                upperX=math.max(x,upperX)
                upperY=math.max(y,upperY)
            end
        end
    end
    if lowerX==math.huge then lowerX=0 end
    if lowerY==math.huge then lowerY=0 end
    if upperX==-math.huge then upperX=data.xlen end
    if upperY==-math.huge then upperY=data.ylen end
    local buffer={}
    for x=lowerX,upperX do
        buffer[x-lowerX]={}
        for y=lowerY,upperY do
            buffer[x-lowerX][y-lowerY]=data[x][y]
        end
    end
    buffer.xlen=upperX-lowerX
    buffer.ylen=upperY-lowerY
    return buffer
end
local function getTiles(p1,p2,cull)
    if cull==nil then cull=true end
    local x1,x2=minToMax(p1.x,p2.x)
    local y1,y2=minToMax(p1.y,p2.y)
    local xlen=x2-x1
    local ylen=y2-y1
    assert(p1.z==p2.z, "only tiles from the same Z-level can be copied")
    local z=p1.z
    local data={}
    for k, block in ipairs(df.global.world.map.map_blocks) do
      if block.map_pos.z==z then
         for block_x, row in ipairs(block.designation) do
            local x=block_x+block.map_pos.x
            if x>=x1 and x<=x2 then
                if not data[x-x1] then
                    data[x-x1]={}
                end
                for block_y, tile in ipairs(row) do
                    local y=block_y+block.map_pos.y
                    if y>=y1 and y<=y2 then
                        data[x-x1][y-y1]=copyall(tile)
                    end
                end
            end
         end
      end
    end
    data.xlen=xlen
    data.ylen=ylen
    if cull then
        return cullBuffer(data)
    end
    return data
end

function CopyUI:getOffset()
    --todo: convert offset directions to enums?
    --counter clockwise
    if self.offsetDirection==0 then --southeast
        return 0, 0
    elseif self.offsetDirection==1 then --northeast
        return 0, -self.buffer.ylen
    elseif self.offsetDirection==2 then --northwest
        return -self.buffer.xlen, -self.buffer.ylen
    elseif self.offsetDirection==3 then --southwest
        return -self.buffer.xlen, 0
    else
        error'out of range'
    end
end

function CopyUI:setBuffer(tiles)
    self.buffer=tiles
end

function CopyUI:transformBuffer(callback)
    local newBuffer={}
    local xlen=0
    local ylen=0
    for x=0, self.buffer.xlen do
        for y=0, self.buffer.ylen do
            local x2,y2=callback(x,y,self.buffer.xlen,self.buffer.ylen,self.buffer[x][y])
            xlen=math.max(x2,xlen)
            ylen=math.max(y2,ylen)
            if not newBuffer[x2] then
                newBuffer[x2]={}
            end
            if not newBuffer[x2][y2] then
                newBuffer[x2][y2]=self.buffer[x][y]
            end
        end
    end
    newBuffer.xlen=xlen
    newBuffer.ylen=ylen
    return newBuffer
end

function CopyUI:pasteBuffer(position,option)
    local z=position.z
    local offsetX,offsetY=self:getOffset()
    local x1=position.x+offsetX
    local x2=position.x+self.buffer.xlen+offsetX
    local y1=position.y+offsetY
    local y2=position.y+self.buffer.ylen+offsetY
    for k, block in ipairs(df.global.world.map.map_blocks) do
      if block.map_pos.z==z then
         for block_x, row in ipairs(block.designation) do
            local x=block_x+block.map_pos.x
            if x>=x1 and x<=x2 then
                for block_y, tile in ipairs(row) do
                    local y=block_y+block.map_pos.y
                    if y>=y1 and y<=y2 and self.buffer[x-x1][y-y1].dig>0 then
                        if self.option=="erase" then
                            tile.dig=0
                        elseif self.option=="construction" then
                            dfhack.constructions.designateRemove(x,y,z)
                        else
                            tile.dig=self.buffer[x-x1][y-y1].dig
                        end
                    end
                end
            end
         end
      end
    end
end
function CopyUI:invertBuffer() --this modifies the buffer instead of copying it
    self:transformBuffer(function(x,y,xlen,ylen,tile) if tile.dig>0 then tile.dig=0 else tile.dig=1 end return x,y end)
end
function CopyUI:renderOverlay(cursor)
    local dc = gui.Painter.new(self.df_layout.map)
    local visible = gui.blink_visible(500)
--   paintMapTile(dc, vp, cursor, startp, 240, COLOR_LIGHTGREEN, COLOR_GREEN)
    
    if gui.blink_visible(120) and self.marking then
        paintMapTile(dc, vp, cursor, self.mark, '+', COLOR_LIGHTGREEN)
        --perhaps draw a rectangle to the point
    elseif not marking and (gui.blink_visible(750) or not self.blink) and self.buffer~=nil and (self.state=='paste' or self.state=='convert') then
        --draw over cursor in these circumstances
        local offsetX,offsetY=self:getOffset()
        for x=0, self.buffer.xlen do
            for y=0, self.buffer.ylen do
                local tile=self.buffer[x][y]
                if tile.dig>0 then
                    local cursor2=cursor
                    if not (gui.blink_visible(750) and x==-offsetX and y==-offsetY) then
                        local fg=COLOR_BLACK
                        local bg=COLOR_CYAN
                        if self.option=='erase' then
                            bg=COLOR_RED
                            fg=COLOR_BLACK
                        elseif self.option=='construction' then
                            bg=COLOR_GREEN
                            fg=COLOR_BLACK
                        end
                        local symbol=digSymbols[tile.dig]
                        if self.option~='normal' then
                            symbol=' '
                        end
                        dc:pen(fg,bg)
                        paintMapTile(dc, vp, cursor2, xyz2pos(df.global.cursor.x+x+offsetX,df.global.cursor.y+y+offsetY,df.global.cursor.z), symbol, fg)
                    end
                
                    
                    --
                end
            end
        end
        
    end
end

function CopyUI:onRenderBody(dc)
    self:renderOverlay(cursor)
    

    dc:clear():seek(1,1):pen(COLOR_WHITE):string("Copy UI - "..self.state:gsub("^%a",function(x)return x:upper()end))
    dc:seek(2,3)
    local cursor = guidm.getCursorPos()
    
    

    
    if self.state=='paste' then
        dc:key('CUSTOM_S'):string(": Set Clipboard",COLOR_GREY)
        
--
        dc:newline():newline(1)
        dc:key('CUSTOM_H'):string(": Flip Horizontal",COLOR_GREY) dc:newline(1)
        dc:key('CUSTOM_V'):string(": Flip Vertical",COLOR_GREY) dc:newline(1)
        dc:key('CUSTOM_R'):string(": Rotate 90",COLOR_GREY) dc:newline(1)
        dc:key('CUSTOM_T'):string(": Rotate -90",COLOR_GREY) dc:newline(1)
        dc:key('CUSTOM_G'):string(": Cycle Corner",COLOR_GREY) dc:newline(1)
        dc:key('CUSTOM_I'):string(": Invert",COLOR_GREY) dc:newline(1)
        dc:key('CUSTOM_C'):string(": Convert to...",COLOR_GREY) dc:newline(1)
        dc:newline(1)
        dc:key('CUSTOM_E'):string(": "..(self.option=='erase' and "Erasing" or "Erase"),self.option=='erase' and COLOR_RED or COLOR_GREY) dc:newline(1) --make red
        dc:key('CUSTOM_X'):string(": "..(self.option=='construction' and "Canceling Contructions" or "Cancel Constructions"),self.option=='construction' and COLOR_GREEN or COLOR_GREY) dc:newline(1) --make red
        dc:newline():newline(1)
        dc:key('CUSTOM_B'):string(": Blink Clipboard",self.blink and COLOR_WHITE or COLOR_GREY) dc:newline(1)
        dc:newline()
    elseif self.state=='mark' then
        if self.buffer==nil then
            dc:string("Select two corners.")
        end
        dc:newline():newline(1)
        dc:key('CUSTOM_P'):string(": Cull Selections",self.cull and COLOR_WHITE or COLOR_GREY)
    elseif self.state=='convert' then
        dc:key('CUSTOM_D'):string(": Mine",COLOR_GREY) dc:newline(2)
        dc:key('CUSTOM_H'):string(": Channel",COLOR_GREY) dc:newline(2)
        dc:key('CUSTOM_U'):string(": Up Stair",COLOR_GREY) dc:newline(2)
        dc:key('CUSTOM_J'):string(": Up Stair",COLOR_GREY) dc:newline(2)
        dc:key('CUSTOM_I'):string(": U/D Stair",COLOR_GREY) dc:newline(2)
        dc:key('CUSTOM_R'):string(": Up Ramp",COLOR_GREY) dc:newline(2)
         dc:newline(1)
        dc:string("To undesignate use the erase command",COLOR_WHITE)
    end
    dc:newline(2)
    dc:newline(1)
    dc:key('LEAVESCREEN'):string(": Back")
    
end
local firstInput=true
local firstPos=copyall(df.global.cursor)
function CopyUI:onInput(keys)

    if df.global.cursor.x==-30000 then
        local vp=self:getViewport()
        df.global.cursor=xyz2pos(math.floor((vp.x1+math.abs((vp.x2-vp.x1))/2)+.5),math.floor((vp.y1+math.abs((vp.y2-vp.y1)/2))+.5), vp.z)
        return
    end
    
    if self.state=='paste' then
        if keys.CUSTOM_S then
            self.state='mark'
        elseif keys.CUSTOM_D then
            self.state='paste'
        elseif keys.CUSTOM_H then
            self.buffer=self:transformBuffer(function(x,y,xlen,ylen,tile) return xlen-x, y end)
        elseif keys.CUSTOM_V then
            self.buffer=self:transformBuffer(function(x,y,xlen,ylen,tile) return x, ylen-y end)            
        elseif keys.CUSTOM_R then
            self.buffer=self:transformBuffer(function(x,y,xlen,ylen,tile) return y, xlen-x end)
            self.offsetDirection=(self.offsetDirection+1)%4
        elseif keys.CUSTOM_T then
            self.buffer=self:transformBuffer(function(x,y,xlen,ylen,tile) return ylen-y,x  end)
            self.offsetDirection=(self.offsetDirection-1)%4
        elseif keys.CUSTOM_G then
            self.offsetDirection=(self.offsetDirection+1)%4
        elseif keys.CUSTOM_E then
            self.option=self.option=='erase' and 'normal' or 'erase'
        elseif keys.CUSTOM_X then
            self.option=self.option=='construction' and 'normal' or 'construction'
        elseif keys.CUSTOM_I then
            self:invertBuffer()
        elseif keys.CUSTOM_C then
            self.state='convert'
        elseif keys.CUSTOM_B then
            self.blink = not self.blink
        elseif keys.SELECT then
            self:pasteBuffer(copyall(df.global.cursor))
        end
    elseif self.state=='mark' then
        if keys.SELECT then
            if self.marking then
                --set the table
                self.state='paste'
                self.marking = false
                self:setBuffer(getTiles(self.mark,copyall(df.global.cursor),self.cull))
            else
                self.marking = true
                self.mark = copyall(df.global.cursor)
            end
        elseif keys.LEAVESCREEN then
                self.state='paste'
                return
        elseif keys.CUSTOM_P then
            self.cull = not self.cull            
        end
    elseif self.state=='convert' then
        if keys.LEAVESCREEN then
            self.state='paste'
            return
        elseif keys.CUSTOM_D then
            self:transformBuffer(function(x,y,xlen,ylen,tile) if tile.dig>0 then tile.dig=1 end return x,y end)
            self.state='paste'
        elseif keys.CUSTOM_H then
            self:transformBuffer(function(x,y,xlen,ylen,tile) if tile.dig>0 then tile.dig=3 end  return x,y end)
            self.state='paste'
        elseif keys.CUSTOM_U then
            self:transformBuffer(function(x,y,xlen,ylen,tile) if tile.dig>0 then tile.dig=6 end  return x,y end)
            self.state='paste'
        elseif keys.CUSTOM_J then
            self:transformBuffer(function(x,y,xlen,ylen,tile) if tile.dig>0 then tile.dig=5 end  return x,y end)
            self.state='paste'
        elseif keys.CUSTOM_I then
            self:transformBuffer(function(x,y,xlen,ylen,tile) if tile.dig>0 then tile.dig=2 end  return x,y end)
            self.state='paste'
        elseif keys.CUSTOM_R then
            self:transformBuffer(function(x,y,xlen,ylen,tile) if tile.dig>0 then tile.dig=4 end  return x,y end)
            self.state='paste'     
        end
        
    end
    if keys.LEAVESCREEN then
            self:dismiss()
    elseif self:propagateMoveKeys(keys) then
        return
    end
end

--------------------------WARNING: JANKY SHIT BELOW--------------------------
for i=1, 4 do
    if not string.match(dfhack.gui.getCurFocus(), '^dwarfmode/Default') then
        gui.simulateInput(dfhack.gui.getCurViewscreen(true),"LEAVESCREEN") 
    else
        break
    end
end
if not string.match(dfhack.gui.getCurFocus(), '^dwarfmode/Default') then
    qerror("failed to force exit menus, run this script again")
end
local list = CopyUI{state='mark', blink=false,cull=true}

if not list.df_layout.menu then
    gui.simulateInput(dfhack.gui.getCurViewscreen(true),"CHANGETAB") --sorry 
    for i=1, 2 do
        if not list.df_layout.menu then
            gui.simulateInput(dfhack.gui.getCurViewscreen(true),"CHANGETAB")
        else
            break
        end
    end
end
list:show()
