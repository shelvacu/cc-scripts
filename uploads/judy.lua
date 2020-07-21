local test = false
local dims = 9
local waitTime = 600

local x = 0
local y = 0
local z = 0

local facing = 0

local function forward()
  if turtle.forward() then
    if facing == 0 then
      z = z - 1
    elseif facing == 1 then
      x = x + 1
    elseif facing == 2 then
      z = z + 1
    elseif facing == 3 then
      x = x - 1
    end
  end
end

local function turnLeft()
  if turtle.turnLeft() then
    facing = math.fmod(facing + 3, 4)
  end
end

local function turnRight()
  if turtle.turnRight() then
    facing = math.fmod(facing + 1, 4)
  end
end

local goalz = 0 - (dims - 1)
local goalx = dims - 1
print(goalz)
print(goalx)

turtle.select(1)
while true do
  --print("iter")
  --print(z)
  --print(x)
  --if z == goalz and x == goalx
  if not test then
    local suc, bi = turtle.inspectDown()
    if suc and bi.name == "minecraft:carrots" and bi.state.age == 7 then
      turtle.digDown()
      turtle.placeDown()
    end
    --if turtle.getItemCount() == 0 then
    --  turtle.select(turtle.getSelectedSlot() + 1)
    --end
    --turtle.placeDown()
  end
  if ((z == goalz and math.fmod(x,2) == 0) or (z == 0 and math.fmod(x,2) == 1)) and x == goalx then
    print("finished harvest round")
    turnLeft()
    for bla=1,(dims-1) do
      forward()
    end
    turnLeft()
    for bla=1,(dims-1) do
      forward()
    end
    if test then
      print("i think im in front of chest")
      read()
    end
    --should be in front of a chest
    for sel=1,16 do
      turtle.select(sel)
      turtle.drop()
    end
    turtle.select(1)
    turnLeft()
    turnLeft()
    sleep(waitTime)
  elseif z == goalz and math.fmod(x,2) == 0 then
    turnRight()
    forward()
    turnRight()
  elseif z == 0 and math.fmod(x,2) == 1 then
    turnLeft()
    forward()
    turnLeft()
  else
    forward()
  end
end
