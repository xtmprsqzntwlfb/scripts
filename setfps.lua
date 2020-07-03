-- Set the FPS cap at runtime.
--[====[

setfps
======
Sets the FPS cap at runtime. Useful in case you want to speed up the game or
watch combat in slow motion.

Usage::

    setfps <number>

]====]

local cap = ...
local capnum = tonumber(cap)

if not capnum or capnum < 1 then
    qerror('Invalid FPS cap value: '..cap)
end

df.global.enabler.fps = capnum
