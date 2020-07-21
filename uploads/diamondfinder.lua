local mods = peripheral.wrap("back")
mods.canvas3d().clear()
local canvas = mods.canvas3d().create()

print("stand still")
canvas.recenter()
local center = {gps.locate()}
if not center[1] then
  error("no gps :(")
end


