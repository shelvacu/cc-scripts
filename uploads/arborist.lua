--0: north, 1: east, 2: south, 3: west
local facing
local waitTime = 300
local targs = { ... }
--if #targs ~= 1 then
--  print( "needs one parameter, direction" )
--end
facing = 0
--if targs[1] == "north" or targs[1] == "n" then
--  facing = 0
--elseif targs[1] == "east" or targs[1] == "e" then
--  facing = 1
--elseif targs[1] == "south" or targs[1] == "s" then
--  facing = 2
--elseif targs[1] == "west" or targs[1] == "w" then
--  facing = 3
--else
--  print( "unrecognized direction" )
--  return
--end

local numtoname = {
  [0] = "north"; -- neg Z
  [1] = "east"; -- pos X
  [2] = "south"; -- pos Z
  [3] = "west" -- neg X
}

local x = 0
local y = 0
local z = 0

local function ensurefuel()
  if turtle.getFuelLevel() == 0 then
    if not turtle.refuel() then
      print("need fuel!")
      while not turtle.refuel() do 
        sleep(1)
      end
    end
  end
end

local function up()
  ensurefuel()
  if turtle.up() then
    y = y + 1
  end
end

local function down()
  ensurefuel()
  if turtle.down() then
    y = y - 1
  end
end

local function forward()
  ensurefuel()
  if turtle.forward() then
    if facing == 0 then
      z = z - 1
    elseif facing == 1 then
      x = x + 1
    elseif facing == 2 then
      z = z + 1
    elseif facing == 3 then
      x = x - 1
    else
      print( "FUCK" )
    end
    return true
  else
    return false
  end
end

local function turnLeft()
  ensurefuel()
  if turtle.turnLeft() then
    facing = math.fmod(facing+3,4)
    return true
  else
    return false
  end
end

local function turnRight()
  ensurefuel()
  if turtle.turnRight() then
    facing = math.fmod(facing+1,4)
    return true
  else
    return false
  end
end

local function outOfSaplings()
  local deets = turtle.getItemDetail(1)
  if not deets then
    return true
  end
  if deets.name == "minecraft:sapling" and deets.count > 0 then
    return false
  end
  
  return true
end

while true do
  turtle.select(1)
  turtle.suckDown()
  local success, bi = turtle.inspect()
  if not success then
    forward()
  else
    if bi.name == "minecraft:stone" and bi.state.variant == "granite" then
      turnRight()
    elseif bi.name == "minecraft:dirt" then
      turnLeft()
    elseif bi.name == "minecraft:chest" then
      local slot = 2
      while slot <= 16 do 
        turtle.select(slot)
        turtle.drop()
        slot = slot + 1
      end
      turnLeft()
      turnLeft()
      print("waiting to start")
      sleep(waitTime)
      print("starting next round")
    elseif bi.name == "minecraft:log" then
      if outOfSaplings() then
        print("out of saplings!")
        while outOfSaplings() do
          sleep(1)
        end
        print("starting again, thanks for the saplings bro")
      end
      turtle.select(2)
      turtle.dig()
      forward()
      turtle.digDown()
      --local deets = turtle.getItemDetail()
      if outOfSaplings() then
        print("out of saplings!")
        while outOfSaplings() do
          sleep(1)
        end
        print("starting again, thanks for the saplings bro")
      end
      turtle.select(1)
      turtle.placeDown()
      while true do 
        local suc, bi = turtle.inspectUp()
        if suc and bi.name == "minecraft:log" then
          turtle.digUp()
          up()
        else
          break
        end
      end
      while y > 0 do 
        down()
      end
    else
      print("unrecognized block " .. bi.name)
      return
    end
  end
end

while true do
  local success, bi = turtle.inspectUp()
  if success and bi.name == "minecraft:birch_fence" then
    print("facing")
    print(facing)
    print(math.fmod(facing+1, 4))
    print(numtoname[math.fmod(facing+1, 4)])
    if bi.state[numtoname[math.fmod(facing+3,4)]] then
      turnLeft()
    elseif bi.state[numtoname[facing]] then
      --do nothing, go straight
    elseif bi.state[numtoname[math.fmod(facing+1, 4)]] then
      turnRight()
    elseif bi.state[numtoname[math.fmod(facing+2, 4)]] then
      turnRight()
      turnRight()
    else
      print("not pointing anywheres")
    end
  end
  if turtle.detect() then
    turtle.dig()
  end
    
  forward()
  
  if x == 0 and y == 0 and z == 0 then
    print("done")
    break
  end
  if false then
    print( "debig")
    break
  end
end
