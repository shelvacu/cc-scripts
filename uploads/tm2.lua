--thorough miner v0.2 by shelvacu

--require"shellib"
function die(msg)
  error("ERROR: "..(msg or "unspecified error"))
  while true do
    sleep(1)
  end
end

function mod(a, b)
  return math.fmod(math.fmod(a,b) + b, b)
end

local function facingPlus(h, amt)
  return mod(h + amt, 4)
end

if not starNav then
  if not os.loadAPI('sn/starNav.lua') then
    error("failed to load starNav")
  end
end
local af = require"atomicFile"
local inspect = require"inspect"

starNav.setMap('map')

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

local function globalPosition() --mimics the API of shellib using starNav
  local coords = {starNav.getPosition()}
  return {
    x = coords[1],
    y = coords[2],
    z = coords[3],
    facing = math.fmod(coords[4] + 2, 4),
  }
end

local function distanceToStart(glob)
  if not glob then
    glob = globalPosition()
  end
  return math.abs(params.startingPos.x - glob.x) + math.abs(params.startingPos.y - glob.y) + math.abs(params.startingPos.z - glob.z)
end

local function turnToFace(facing)
  local h = math.fmod(facing + 2, 4)
  local pos = globalPosition()
  starNav.goto(pos.x, pos.y, pos.z, 1, h)
end

local function moveToY(y)
  local pos = globalPosition()
  starNav.goto(pos.x, y, pos.z, math.abs(y - pos.y)*2, math.fmod(pos.facing + 2, 4))
end

local function turnRight()
  local coords = {starNav.getPosition()}
  starNav.goto(coords[1], coords[2], coords[3], 3, math.fmod(coords[4] + 1, 4))
end

local function turnLeft()
  local coords = {starNav.getPosition()}
  starNav.goto(coords[1], coords[2], coords[3], 3, math.fmod(coords[4] + 3, 4))
end

local function forward()
  local coords = {starNav.getPosition()}
  local xOff = 0
  local zOff = 0
  if coords[4] == 0 then
    zOff = 1
  elseif coords[4] == 1 then
    xOff = -1
  elseif coords[4] == 2 then
    zOff = -1
  elseif coords[4] == 3 then
    xOff = 1
  else
    error("Wasn't expecting h "..coords[4])
  end
  starNav.goto(coords[1] + xOff, coords[2], coords[3] + zOff, 3, coords[4])
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
  --turnToFace(xFactor == 1 and 3 or 1)
  --moveToXZ(chestPos)
  --moveToY(chestPos.y)
  local maxDistance = distanceToStart()*2
  starNav.goto(chestPos.x, chestPos.y, chestPos.z, maxDistance, math.fmod(chestPos.facing+2, 4))
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
  while turtle.getFuelLevel() < turtle.getFuelLimit() - 10000 do
    moveToY(chestPos.y + 1)
    turtle.select(2)
    turtle.suck()
    if turtle.getItemCount() == 0 then
      print"No fuel in fuel chest"
      -- Now we wonder, do we have enough fuel to get where we need to go back to?
      local returnDistance = math.abs(chestPos.x - oldSpot.x) + math.abs((chestPos.y + 1) - oldSpot.y) + math.abs(chestPos.z - oldSpot.z)
      -- the absolute minimum would be returnDistance*2, but the turtle will return when fuel is less than distance*2 to account for starNav... inefficiencies
      -- therefor we do distance*3 here, which should theoretically be enough to mine one block and then come back. Thus, the turtle will dutifully use all
      -- the fuel it can.
      local minFuel = returnDistance*3
      if turtle.getFuelLevel() < minFuel then
        error"Not enough fuel to continue"
      else
        break
      end
    elseif not turtle.refuel() then
      error"That's not fuel!"
    else
      if turtle.getItemCount(2) > 0 then
        local coords = {starNav.getPosition()}
        --down()
        --turnRight()
        starNav.goto(coords[1], coords[2]-1, coords[3], 3, math.fmod(coords[4] + 1, 4))
        turtle.drop()
        starNav.goto(coords[1], coords[2], coords[3], 3, coords[4])
        --turnLeft()
        --up()
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
  starNav.goto(oldSpot.x, oldSpot.y, oldSpot.z, maxDistance, math.fmod(oldSpot.facing + 2, 4))
  --moveToY(oldSpot.y)
  --moveToXZ(oldSpot)
end

local diggablesArr = {
  "minecraft:grass_block",
  "minecraft:stone",
  "minecraft:cobblestone",
  "minecraft:coal_ore",
  "minecraft:iron_ore",
  "minecraft:gold_ore",
  "minecraft:redstone_ore",
  "minecraft:lapis_lazuli_ore",
  "minecraft:lapis_ore",
  "minecraft:diamond_ore",
  "minecraft:emerald_ore",
  "minecraft:fence",
  "minecraft:planks",
  "minecraft:rail",
  "minecraft:water",
  "minecraft:lava",
  "minecraft:flowing_lava",
  "minecraft:dirt",
  "minecraft:gravel",
  "minecraft:obsidian",
  "minecraft:monster_egg", -- blocks that spawn endermites
  "minecraft:torch",
  "minecraft:wall_torch",
  "minecraft:end_stone",
  "minecraft:deepslate",
  "minecraft:andesite",
  "minecraft:granite",
  "minecraft:diorite",
  "minecraft:marble",
  "minecraft:sandstone",
  "minecraft:deepslate",
  "minecraft:small_amethyst_bud",
  "minecraft:medium_amethyst_bud",
  "minecraft:large_amethyst_bud",
  "minecraft:amethyst_cluster",
  "minecraft:amethyst_block",
  "minecraft:budding_amethyst",
  "minecraft:calcite",
  "minecraft:cobbled_deepslate",
  "minecraft:copper_ore",
  "minecraft:coal_ore",
  "minecraft:iron_ore",
  "minecraft:gold_ore",
  "minecraft:redstone_ore",
  "minecraft:lapis_lazuli_ore",
  "minecraft:lapis_ore",
  "minecraft:diamond_ore",
  "minecraft:emerald_ore",
  "minecraft:deepslate_copper_ore",
  "minecraft:deepslate_coal_ore",
  "minecraft:deepslate_iron_ore",
  "minecraft:deepslate_gold_ore",
  "minecraft:deepslate_redstone_ore",
  "minecraft:deepslate_lapis_lazuli_ore",
  "minecraft:deepslate_lapis_ore",
  "minecraft:deepslate_diamond_ore",
  --"minecraft:deepslate_emerald_ore", --one of the rarest blocks, reserve for a silk touch
  "minecraft:dripstone_block",
  "minecraft:glow_lichen",
  "minecraft:hanging_roots",
  "minecraft:raw_iron_block",
  "minecraft:raw_gold_block",
  "minecraft:raw_copper_block",
  "minecraft:moss_block",
  "minecraft:pointed_dripstone",
  "minecraft:basalt",
  "minecraft:tuff",

  "minecraft:oak_fence", --mineshafts
  "minecraft:oak_planks"
}

local diggablesMap = {}

for _,name in ipairs(diggablesArr) do
  diggablesMap[name] = true
end

local function doTheDig(dir)
  while true do
    makeInventoryNotFull()
    --print("doing the dig "..dir)
    local suc, bi = turtle[inspectNames[dir]]()
    if suc and (bi.name == "minecraft:lava" or bi.name == "minecraft:flowing_lava") and bi.state.level == 0 then --lava source block
      turtle.select(1)
      turtle[placeNames[dir]]()
      starNav.update[dir]()
    -- TODO elseif suc and (bi.name == "minecraft:water" or bi.name == "minecraft:flowing_water") and bi.state.level == 0 then
      --remove the water
    elseif (not suc) or bi.name == "minecraft:lava" or bi.name == "minecraft:flowing_lava" or bi.name == "minecraft:water" or bi.name == "minecraft:flowing_water" then
      break
    elseif diggablesMap[bi.name] then
      turtle[digNames[dir]]()
      starNav.update[dir]()
    elseif bi.name == "minecraft:bedrock" and dir == "down" then
      --we can ignore bedrock below, this will be the last layer
      starNav.update[dir]()
      break
    else
      print("unrecognized block " .. bi.name)
      --moveToXZ(params.startingPos)
      --moveToY(params.startingPos.y)
      starNav.goto(params.startingPos.x, params.startingPos.y, params.startingPos.z)
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

local location = {gps.locate()}
print("telling starnav to go to "..inspect(location))
starNav.goto(location[1], location[2], location[3]) --force starNav to figure out its location and facing
print("figured")

local startX = params.startingPos.x
local startY = params.startingPos.y
local startZ = params.startingPos.z

local xFactor = (params.startingPos.facing <= 1) and 1 or -1
local zFactor = (params.startingPos.facing == 1 or params.startingPos.facing == 2) and 1 or -1
local dimsDiff = params.dims - 1
local destX = startX + (dimsDiff * xFactor)
local destY = startY + params.down
local destZ = startZ + (dimsDiff * zFactor)

local startingFacing = facingPlus(params.startingPos.facing, math.fmod(params.startingPos.facing, 2) == 1 and 1 or 0)

--must have buckets
local deets = turtle.getItemDetail(1)
if not deets or deets.name ~= "minecraft:bucket" then
  die("must have buckets!")
end

--recovery
if params.finished then
  return
end
--moveToXZ(params.startingPos)
--moveToY(params.gotToY)
--starNav.goto(params.startingPos.x, params.gotToY, params.startingPos.z, nil, math.fmod(params.startingPos.facing+2, 4))

local recovXZ = {}
recovXZ.x = params.gotToX-- - (mod(params.gotToX, 2) == 0 and 2 or 1)
recovXZ.z = params.startingPos.z
recovXZ.facing = startingFacing

--moveToXZ(recovXZ)
print("moving to recovXZ")
starNav.goto(recovXZ.x, params.gotToY, recovXZ.z, nil, math.fmod(recovXZ.facing + 2, 4))

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
      --moveToXZ(params.startingPos)
      --moveToY(params.startingPos.y)
      starNav.goto(params.startingPos.x, params.startingPos.y, params.startingPos.z, nil, facingPlus(params.startingPos.facing,2))
      print("finished!")
      params.finished = true
      af.write("tmparams", params)
      return
    else
      --moveToXZ{x = startX, z = startZ, facing = startingFacing}
      starNav.goto(startX, glob.y, startZ, nil, math.fmod(startingFacing + 2, 4))
      for i=1,3 do
        doTheDig("down")
        starNav.update["down"]()
        starNav.goto(startX, glob.y-i, startZ, nil, math.fmod(startingFacing + 2, 4))
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
      error("unexpected mod " .. mod .. " from facing " .. glob.facing .. " xFactor " .. xFactor)
    end
  else
    --print("norm condition")
    doTheMultiDigFwd()
  end
end
