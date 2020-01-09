function starts_with(str, start)
   return str:sub(1, #start) == start
end

function ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

function die(msg)
  print("ERROR: "..msg)
  while true do
    sleep(1)
  end
end

local s = "Use shellib"
local turtleForward = turtle.forward
turtle.forward = s
local turtleBack = turtle.back
turtle.back = s
local turtleUp = turtle.up
turtle.up = s
local turtleDown = turtle.down
turtle.down = s
local turtleTurnLeft = turtle.turnLeft
turtle.turnLeft = s
local turtleTurnRight = turtle.turnRight
turtle.turnRight = s

Location = {x = 0, y = 0, z = 0, facing = 0}
GlobalOffset = {known = false, posPairs = {}}

Settings = {ensureFuel = false}

function tryForward()
  ensureFuelIf()
  local res = turtleForward()
  if res then
    local f = Location.facing
    if f == 0 then
      Location.z = Location.z - 1
    elseif f == 1 then
      Location.x = Location.x + 1
    elseif f == 2 then
      Location.z = Location.z + 1
    elseif f == 3 then
      Location.x = Location.x - 1
    else
      die("unexpect Location.facing value")
    end
  end
  return res
end

function forward()
  if not tryForward() then
    die("unable to move forward")
  end
end

function tryBack()
  ensureFuelIf()
  local res = turtleBack()
  if res then
    local f = Location.facing
    if f == 0 then
      Location.z = Location.z + 1
    elseif f == 1 then
      Location.x = Location.x - 1
    elseif f == 2 then
      Location.z = Location.z - 1
    elseif f == 3 then
      Location.x = Location.x + 1
    else
      die("unexpect Location.facing value")
    end
  end
  return res
end

function back()
  if not tryBack() then
    die("unable to move back")
  end
end

function tryUp()
  ensureFuelIf()
  local res = turtleUp()
  if res then
    Location.y = Location.y + 1
  end
  return res
end

function up()
  if not tryUp() then
    die("unable to move up")
  end
end

function tryDown()
  ensureFuelIf()
  local res = turtleDown()
  if res then
    Location.y = Location.y - 1
  end
  return res
end

function down()
  if not tryDown() then
    die("unable to move down")
  end
end

function ensureFuel()
  if turtle.getFuelLevel() == 0 then
    die("need fuel!")
  end
end

function ensureFuelIf()
  if Settings.ensureFuel then
    ensureFuel()
  end
end

function turnLeft()
  -- from the docs http://www.computercraft.info/wiki/Turtle.turnLeft
  -- "Output 	true - the turtle cannot fail to turn left"
  Location.facing = math.fmod(Location.facing + 3, 4)
  turtleTurnLeft()
end

function turnRight()
  -- from the docs http://www.computercraft.info/wiki/Turtle.turnRight
  -- "Output 	true - the turtle cannot fail to turn right"
  Location.facing = math.fmod(Location.facing + 1, 4)
  turtleTurnRight()
end

local function translatePosition(facingOffset)
  local translatedLocation = {y = Location.y}
  if facingOffset == 0 then
    --no translation needed
    translatedLocation.x =  Location.x
    translatedLocation.z =  Location.z
  elseif facingOffset == 1 then
    translatedLocation.x = -Location.z
    translatedLocation.z =  Location.x
  elseif facingOffset == 2 then
    translatedLocation.x = -Location.x
    translatedLocation.z = -Location.z
  elseif facingOffset == 3 then
    translatedLocation.x =  Location.z
    translatedLocation.z = -Location.x
  else
    die("unexpected offset")
  end
end

local function locationEq(a, b)
  return a.x == b.x and a.y == b.y and a.z == b.z and a.facing == b.facing
end

-- returns bool success
function recordPositionPair(timeout = 2, gps_debug = false)
  if GlobalOffset.known then
    return true
  end
  local xPos, yPos, zPos = gps.locate(timeout, gps_debug)
  if not xPos then
    return false
  end
  local pair = {
    localPos = {
      x = Location.x,
      z = Location.z
    },
    globalPos = {
      x = xPos,
      z = zPos
    }
  }
  local posPairsLen = #GlobalOffset.posPairs
  if posPairsLen > 0 and locationEq(GlobalOffset.posPairs[posPairsLen].localPos, pair.localPos) then
    return false
  end
  table.insert(GlobalOffset.posPairs, pair)
  return true, xPos, yPos, zPos
end

-- Tries to get an accurate offset for the turtle's global position. This needs *two* gps readings to do this, or one gps reading and an accurate facing direction.
-- Params: facing (optional)
--   if not provided, will try to move the turtle forward to get a second reading
-- Returns: boolean indicating success
function getGlobalOffset(facing = nil, timeout = 2, gps_debug = false)
  if GlobalOffset.known then
    return true
  end
  local xPos, yPos, zPos = gps.locate(timeout, gps_debug)
  if not xPos then
    return false
  end
  local first = {x = xPos, y = yPos, z = zPos}
  if not facing then
    forward()
    local xPos, yPos, zPos = gps.locate(timeout, gps_debug)
    back()
    local second = {x = xPos, y = yPos, z = zPos}
    if not xPos then
      return false
    end
    
    local globalFacing
    if first.y ~= second.y then
      die("expected y coordinate to stay the same")
    elseif (first.z - 1) == second.z and first.x == second.x then
      globalFacing = 0
    elseif (first.x + 1) == second.x and first.z == second.z then
      globalFacing = 1
    elseif (first.z + 1) == second.z and first.x == second.x then
      globalFacing = 2
    elseif (first.x - 1) == second.x and first.z == second.z then
      globalFacing = 3
    else
      die("unexpected coordinates")
    end
    facing = globalFacing
  end

  local facingOffset = math.fmod((facing - Location.facing) + 4, 4)
  GlobalOffset.facing = facingOffset

  local translatedLocation = translatePosition(facingOffset)

  GlobalOffset.x = first.x - translatedLocation.x
  GlobalOffset.y = first.y - translatedLocation.y
  GlobalOffset.z = first.z - translatedLocation.z
  GlobalOffset.known = true
  return true
end

--caller must ensure getGlobalOffset has been called and returned true before calling this
function globalPosition()
  if not GlobalOffset.known then
    die("Global offset not known")
  end
  
  local translatedLocation = translatePosition(facingOffset)
  local globalPos = {}

  globalPos.facing = math.fmod(Location.facing + GlobalOffset.facing)
  globalPos.x = translatedLocation.x + GlobalOffset.x
  globalPos.y = translatedLocation.y + GlobalOffset.y
  globalPos.z = translatedLocation.z + GlobalOffset.z

  return globalPos
end

StringToFacing = {
  n = 0,
  e = 1,
  s = 2,
  w = 3,
}

FacingToString = {
  [0] = "north",
  [1] = "east",
  [2] = "south",
  [3] = "west",
}
