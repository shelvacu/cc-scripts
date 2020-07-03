require "shellib"
local inspect = require "inspect"

local tArgs = {...}
local fh
if #tArgs > 0 then
  fh = assert(io.open(tArgs[1], "a"))
end

local function help()
  print("WASD: horizontal movement and turning")
  print("Q/E: Up/Down")
  print("R/F/V: Dig up/forward/down")
  print("I/K/M: inspect up/forward/down")
  print("J: inspect item in inventory")
  print("L: location data")
  print("P: print location to file")
  print(".: quit")
  print("?: this help message")
end
help()
while true do
  local ev, key = os.pullEvent("char")
  if key == "w" then
    tryForward()
  elseif key == "a" then
    turnLeft()
  elseif key == "s" then
    tryBack()
  elseif key == "d" then
    turnRight()
  elseif key == "q" then
    tryUp()
  elseif key == "e" then
    tryDown()
  elseif key == "r" then
    turtle.digUp()
  elseif key == "f" then
    turtle.dig()
  elseif key == "v" then
    turtle.digDown()
  elseif key == "i" then
    print(inspect({turtle.inspectUp()}))
  elseif key == "k" then
    print(inspect({turtle.inspect()}))
  elseif key == "m" or key == "," then
    print(inspect({turtle.inspectDown()}))
  elseif key == "j" then
    print(inspect(turtle.getItemDetail(1, true)))
  elseif key == "p" then
    if not fh then
      print("specify fn")
      return
    end
    local globalPos = globalPosition()
    fh:write("  {" .. globalPos.x .. "," .. globalPos.y .. "," .. globalPos.z .. "," .. globalPos.facing .. "},\n")
    print("written")
  elseif key == "." then
    if fh then fh:close() end
    return
  elseif key == "l" then
    print("Local coords:")
    print("  x:" .. Location.x .. " y:" .. Location.y .. " z:" .. Location.z .. " facing:" .. FacingToString[Location.facing])
    print("Global coords: (from offset)")
    if getGlobalOffset() then
      local globalPos = globalPosition()
      print("  x:" .. globalPos.x .. " y:" .. globalPos.y .. " z:" .. globalPos.z .. " facing:" .. FacingToString[globalPos.facing])
    else
      print("  (not avail)")
    end
    local xPos, yPos, zPos = gps.locate()
    print("Global coords: (from gps)")
    if xPos then
      print("  x:" .. xPos .. " y:" .. yPos .. " z:" .. zPos) --gps does not provide facing direction
    else
      print("  (not avail)")
    end
  elseif key == "?" or key == "h" then
    help()
  else
    print("Unrecognized key " .. key)
  end
end
