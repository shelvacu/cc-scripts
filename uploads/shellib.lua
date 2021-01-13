function starts_with(str, start)
   return str:sub(1, #start) == start
end

function ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

function mod(a, b)
  return math.fmod(math.fmod(a,b) + b, b)
end

function facingPlus(a, b)
  return mod(a + b,4)
end

function die(msg)
  error("ERROR: "..(msg or "unspecified error"))
  while true do
    sleep(1)
  end
end

if not backupTurtle then
  backupTurtle = turtle
end
turtle = {}
local s = "Use shellib"
local turtleForward = backupTurtle.forward
turtle.forward = s
local turtleBack = backupTurtle.back
turtle.back = s
local turtleUp = backupTurtle.up
turtle.up = s
local turtleDown = backupTurtle.down
turtle.down = s
local turtleTurnLeft = backupTurtle.turnLeft
turtle.turnLeft = s
local turtleTurnRight = backupTurtle.turnRight
turtle.turnRight = s
setmetatable(turtle, {__index = backupTurtle})

Location = {x = 0, y = 0, z = 0, facing = 0}
GlobalOffset = {known = false, posPairs = {}}

Settings = {ensureFuel = false, retry = 20}

local function retry(fn, ...)
  for _=1,Settings.retry+1 do
    if fn(...) then
      return true
    end
    sleep(1)
  end
  return false
end

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
      error("unexpect Location.facing value")
    end
  end
  return res
end

function forward()
  if not retry(tryForward) then
    error("unable to move forward")
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
      error("unexpect Location.facing value")
    end
  end
  return res
end

function back()
  if not retry(tryBack) then
    error("unable to move back")
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
  if not retry(tryUp) then
   error("unable to move up")
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
  if not retry(tryDown) then
    error("unable to move down")
  end
end

function ensureFuel()
  if turtle.getFuelLevel() == 0 then
    error("need fuel!")
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
  Location.facing = facingPlus(Location.facing, -1)
  turtleTurnLeft()
end

function turnRight()
  -- from the docs http://www.computercraft.info/wiki/Turtle.turnRight
  -- "Output 	true - the turtle cannot fail to turn right"
  Location.facing = facingPlus(Location.facing, 1)
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
   error("unexpected offset")
  end
  return translatedLocation
end

local function locationEq(a, b)
  return a.x == b.x and a.y == b.y and a.z == b.z and a.facing == b.facing
end

-- returns bool success
function recordPositionPair(timeout, gps_debug)
  local timeout = timeout or 2
  local gps_debug = gps_debug or false
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
function getGlobalOffset(facing, timeout, gps_debug)
  local timeout = timeout or 2
  local gps_debug = gps_debug or false
  if GlobalOffset.known then
    return true
  end
  local xPos, yPos, zPos = gps.locate(timeout, gps_debug)
  if not xPos then
    return false
  end
  local first = {x = xPos, y = yPos, z = zPos}
  if not facing then
    local dir
    if tryForward() then
      dir = 1
    elseif tryBack() then
      dir = -1
    else
      return false
    end
    local xPos, yPos, zPos = gps.locate(timeout, gps_debug)
    if dir == 1 then
      back()
    elseif dir == -1 then
      forward()
    else
      assert(false)
    end
    local second = {x = xPos, y = yPos, z = zPos}
    if not xPos then
      return false
    end
    
    local globalFacing
    if first.y ~= second.y then
      error("expected y coordinate to stay the same, got "..first.y.." and "..second.y)
    elseif (first.z - dir) == second.z and first.x == second.x then
      globalFacing = 0
    elseif (first.x + dir) == second.x and first.z == second.z then
      globalFacing = 1
    elseif (first.z + dir) == second.z and first.x == second.x then
      globalFacing = 2
    elseif (first.x - dir) == second.x and first.z == second.z then
      globalFacing = 3
    else
      error("unexpected coordinates "..first.x..","..first.z.." "..second.x..","..second.z)
    end
    facing = globalFacing
  end

  assert(facing)
  assert(Location.facing)
  local facingOffset = facingPlus(facing, -Location.facing)
  assert(facingOffset)
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
    error("Global offset not known")
  end
  assert(GlobalOffset.facing)
  assert(Location.facing)
  
  local translatedLocation = translatePosition(GlobalOffset.facing)
  local globalPos = {}

  globalPos.facing = facingPlus(Location.facing, GlobalOffset.facing)
  globalPos.x = translatedLocation.x + GlobalOffset.x
  globalPos.y = translatedLocation.y + GlobalOffset.y
  globalPos.z = translatedLocation.z + GlobalOffset.z

  return globalPos
end

function facingDistance(a, b)
  local mod = facingPlus(a, -b)
  if mod == 3 then
    return 1
  else
    return mod
  end
end

function turnToFace(newFacing, preferLeft)
  if type(preferLeft) == "nil" then
    preferLeft = true
  end
  local glob = globalPosition()
  local f = glob.facing
  local mod = facingPlus(newFacing, -f)
  if mod == 0 then
    --do nothing
  elseif mod == 1 then
    turnRight()
  elseif mod == 2 then
    if preferLeft then
      turnLeft()
      turnLeft()
    else
      turnRight()
      turnRight()
    end
  elseif mod == 3 then
    turnLeft()
  end
  return true
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
