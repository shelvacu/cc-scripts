require "shellib"
local inspect = require "inspect"

local function help()
  print("WASD: horizontal movement and turning")
  print("Q/E: Up/Down")
  print("R/F/V: Dig up/forward/down")
  print("I/K/M: inspect up/forward/down")
  print("J: inspect item in inventory")
  print(".: quit")
  print("L: location data")
  print("?: this help message")
end
while true do
  help()
  local ev, key = os.pullEvent("char")
  if key == "w" then
    forward()
  elseif key == "a" then
    turnLeft()
  elseif key == "s" then
    back()
  elseif key == "d" then
    turnRight()
  elseif key == "q" then
    up()
  elseif key == "e" then
    down()
  elseif key == "r" then
    turtle.digUp()
  elseif key == "f" then
    turtle.dig()
  elseif key == "v" then
    turtle.digDown()
  elseif key == "i" then
    print(inspect(turtle.inspectUp()))
  elseif key == "k" then
    print(inspect(turtle.inspect()))
  elseif key == "m" then
    print(inspect(turtle.inspectDown()))
  elseif key == "j" then
    print(inspect(turtle.getItemDetail()))
  elseif key == "." then
    return
  elseif key == "l" then
    if not getGlobalOffset() then die() end
    print("Local coords:")
    print("  x:" .. Location.x .. " y:" .. Location.y .. " z:" .. Location.z .. " facing:" .. FacingToString[Location.facing])
    local globalpos = globalPosition()
    print("Global coords: (from offset)")
    print("  x:" .. globalPos.x .. " y:" .. globalPos.y .. " z:" .. globalPos.z .. " facing:" .. FacingToString[globalPos.facing])
    local gpsPos = gps.locate()
    print("Global coords: (from gps)")
    print("  x:" .. gpsPos.x .. " y:" .. gpsPos.y .. " z:" .. gpsPos.z) --gps does not provide facing direction
  elseif key == "?" or key == "h" then
    help()
  else
    print("Unrecognized key " .. key)
  end
end
