-- ungelds animals
-- Written by Josh Cooper(cppcooper) on 2019-12-10, last modified: 2019-12-10
local help = [====[

ungeld
======
It sets the geld status to false.

]====]

unit = dfhack.gui.getSelectedUnit()
unit.flags3.gelded = false
print("unit ungelded.")