--thorough miner v0.1 by shelvacu

require"shellib"
local af = require"atomicFile"
local inspect = require"inspect"

local digNames = {
  up = "digUp",
  forward = "dig",
  down = "digDown"
}

local placeNames = {
  up = "placeUp",
  forward = "place",
  down = "placeDown"
}

local inspectNames = {
  up = "inspectUp",
  forward = "inspect",
  down = "inspectDown"
}

local params = af.read("tmparams")

local function xor(a, b)
  if a and b then
    return false
  elseif a or b then
    return true
  else
    return false
  end
end

local function moveToY(yPos)
  local glob = globalPosition()
  local go
  if yPos < glob.y then
    go = down
  else
    go = up
  end
  while yPos ~= globalPosition().y do
    go()
  end
end

local function moveToXZ(spot)
  local glob = globalPosition()
  local dirs = {}
  if spot.x < glob.x then
    dirs.x = 3 
  elseif spot.x > glob.x then
    dirs.x = 1
  else
    dirs.x = nil
  end
  if spot.z > glob.z then
    dirs.z = 2
  elseif spot.z < glob.z then
    dirs.z = 0
  else
    dirs.z = nil
  end
  --print(inspect(dirs))

  if dirs.x or dirs.z then
    if dirs.x and dirs.z then
      --print("x and z")
      local go
      local a
      if mod(glob.facing, 2) == 0 then --facing along z axis
        a = "z"
      else
        a = "x"
      end
      if glob.facing == dirs[a] then
        go = forward
      else
        go = back
        assert(glob.facing == facingPlus(dirs[a], 2))
      end
      while spot[a] ~= globalPosition()[a] do
        go()
      end
      dirs[a] = nil
      --print("moved "..a.." axis, next one")
    end
    local a
    local go
    local glob = globalPosition()
    if dirs.x then
      a = "x"
    else
      a = "z"
    end
    if facingDistance(spot.facing, dirs[a]) > facingDistance(spot.facing, facingPlus(dirs[a], 2)) then
      --print("go = forward")
      go = forward
      turnToFace(dirs[a])
    else
      --print("go = back")
      go = back
      turnToFace(facingPlus(dirs[a], 2))
    end
    --print("about to move "..a.." axis until "..spot[a])
    while true do
      local glob = globalPosition()
      --print("testing spot "..spot[a].." == "..glob[a].." glob")
      if spot[a] == glob[a] then
        break
      end
      go()
    end
  end
  turnToFace(spot.facing)
  local newGlob = globalPosition()
  assert(newGlob.x == spot.x)
  assert(newGlob.z == spot.z)
  assert(newGlob.facing == spot.facing)
end

local function inventoryHasEmptySlot()
  for i=1,16 do
    if turtle.getItemCount(i) == 0 then
      return true
    end
  end
  return false
end

local function inventoryFull()
  return not inventoryHasEmptySlot()
end

local function distanceToStart(glob)
  if not glob then
    glob = globalPosition()
  end
  return math.abs(params.startingPos.x - glob.x) + math.abs(params.startingPos.y - glob.y) + math.abs(params.startingPos.z - glob.z)
end

local function makeInventoryNotFull()
  if inventoryHasEmptySlot() and turtle.getFuelLevel() > (distanceToStart() + 5) then return end
  print("making inventory not full")
  local oldSpot = globalPosition()
  local chestPos = {
    x = params.startingPos.x,
    y = params.startingPos.y,
    z = params.startingPos.z,
    facing = facingPlus(params.startingPos.facing, 2),
  }
  turnToFace(xFactor == 1 and 3 or 1)
  moveToXZ(chestPos)
  moveToY(chestPos.y)
  for i=2,16 do
    turtle.select(i)
    local first = true
    while not (turtle.drop() or turtle.getItemCount() == 0) do
      if first then
        print("chest full!")
      end
      sleep(1)
      first = false
    end
  end
  while turtle.getFuelLevel() < turtle.getFuelLimit() - 1000 do
    moveToY(chestPos.y + 1)
    turtle.select(2)
    turtle.suck()
    if not turtle.refuel() then
      error"That's not fuel!"
    else
      if turtle.getItemCount(2) > 0 then
        down()
        turnRight()
        turtle.drop()
        turnLeft()
        up()
      end
    end
  end
  moveToY(chestPos.y)

  if turtle.getItemCount(1) < 16 then
    turnRight()
    turtle.select(1)
    local max = 16 - turtle.getItemCount(1)
    turtle.suck(max)
  end
  moveToY(oldSpot.y)
  moveToXZ(oldSpot)
end

local function doTheDig(dir)
  while true do
    makeInventoryNotFull()
    --print("doing the dig "..dir)
    local suc, bi = turtle[inspectNames[dir]]()
    if suc and bi.name == "minecraft:lava" and bi.state.level == 0 then --lava source block
      turtle.select(1)
      turtle[placeNames[dir]]()
    elseif not suc then
      break
    elseif --(not suc) or
      bi.name == "minecraft:stone" or
      bi.name == "minecraft:cobblestone" or
      bi.name == "minecraft:coal_ore" or
      bi.name == "minecraft:iron_ore" or
      bi.name == "minecraft:gold_ore" or
      bi.name == "minecraft:redstone_ore" or
      bi.name == "minecraft:lapis_lazuli_ore" or
      bi.name == "minecraft:lapis_ore" or
      bi.name == "minecraft:diamond_ore" or
      bi.name == "minecraft:emerald_ore" or
      bi.name == "minecraft:fence" or
      bi.name == "minecraft:planks" or
      bi.name == "minecraft:rail" or
      bi.name == "minecraft:water" or
      bi.name == "minecraft:lava" or
      bi.name == "minecraft:dirt" or
      bi.name == "minecraft:obsidian" or
      bi.name == "minecraft:monster_egg" or
      bi.name == "minecraft:torch"
    then
      turtle[digNames[dir]]()
    else
      print("unrecognized block " .. bi.name)
      moveToXZ(params.startingPos)
      moveToY(params.startingPos.y)
      error("unrecognized block")
    end
  end
end   

local function doTheMultiDigFwd()
  doTheDig("up")
  doTheDig("down")
  doTheDig("forward")
  forward()
end

if not getGlobalOffset() then
  turnLeft()
  if not getGlobalOffset() then die("no position :(") end
end

local startX = params.startingPos.x
local startY = params.startingPos.y
local startZ = params.startingPos.z

local xFactor = (params.startingPos.facing <= 1) and 1 or -1
local zFactor = (params.startingPos.facing == 1 or params.startingPos.facing == 2) and 1 or -1
local dimsDiff = params.dims - 1
local destX = startX + (dimsDiff * xFactor)
local destY = startY + params.down
local destZ = startZ + (dimsDiff * zFactor)

local startingFacing = facingPlus(params.startingPos.facing, mod(params.startingPos.facing, 2) == 1 and 1 or 0)

--must have buckets
local deets = turtle.getItemDetail(1)
if not deets or deets.name ~= "minecraft:bucket" then
  die("must have buckets!")
end

--recovery
if params.finished then
  return
end
moveToXZ(params.startingPos)
moveToY(params.gotToY)

local recovXZ = {}
recovXZ.x = params.gotToX - (mod(params.gotToX, 2) == 0 and 2 or 1)
recovXZ.z = params.startingPos.z
recovXZ.facing = startingFacing

moveToXZ(recovXZ)

--turnToFace(startingFacing)
print("destX "..destX)
print("destY "..destY)
print("destZ "..destZ)
print("startingFacing "..startingFacing)
--main
while true do
  local glob = globalPosition()
  if false then
  elseif
    (
      (glob.z == destZ  and mod(destX - startX, 2) == 0) or
      (glob.z == startZ and mod(destX - startX, 2) == 1)
    ) and glob.x == destX
  then
    print("layer fin condition")
    doTheDig("up")
    doTheDig("down")
    if glob.y <= destY then
      moveToXZ(params.startingPos)
      moveToY(params.startingPos.y)
      print("finished!")
      params.finished = true
      af.write("tmparams", params)
      return
    else
      moveToXZ{x = startX, z = startZ, facing = startingFacing}
      for i=1,3 do
        while not tryDown() do
          doTheDig("down")
        end
      end
      local newPos = globalPosition()
      params.gotToY = newPos.y
      params.gotToX = newPos.x
      af.write("tmparams", params)
    end
  elseif 
    (glob.z == destZ and glob.facing == startingFacing) or 
    (glob.z == startZ and glob.facing == facingPlus(startingFacing, 2))
  then
    local mod = facingPlus(xFactor == 1 and 1 or 3, -glob.facing)
    if mod == 1 then
      print("row condition, right")
      turnRight()
      doTheMultiDigFwd()
      turnRight()
      params.gotToX = globalPosition().x
      af.write("tmparams", params)
    elseif mod == 3 then
      print("row condition, left")
      turnLeft()
      doTheMultiDigFwd()
      turnLeft()
    else
      error("unexpected mod")
    end
  else
    print("norm condition")
    doTheMultiDigFwd()
  end
end
