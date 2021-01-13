local data = fs.open("goldfarm.schematic.uz","rb").readAll()
local nbt = require"nbt"
nbt(data)
