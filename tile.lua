pos = copyall(df.global.cursor)
x = pos.x%16
y = pos.y%16

block = dfhack.maps.ensureTileBlock(pos.x,pos.y,pos.z)
print(block.tiletype[x][y])
--block.tiletype[x][y] = 491