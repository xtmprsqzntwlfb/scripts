-- sets the selected tile's 'tiletype' ie. changes the tileset you see
args = {...}
pos = copyall(df.global.cursor)
x = pos.x%16
y = pos.y%16
v = tonumber(args[1])

local help = [====[

settile
=======
It sets the tiletype for the highlighted tile.

]====]

block = dfhack.maps.ensureTileBlock(pos.x,pos.y,pos.z)
print(block.tiletype[x][y])
block.tiletype[x][y] = v