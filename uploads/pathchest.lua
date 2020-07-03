require"shellib"
local path = require"path"

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

while not getGlobalOffset() do
  if not tryUp() then
    error("couldn't get facing")
  end
end
while true do
  for i=(#path),1,-1 do
    local val = path[i]
    local pos = globalPosition()
    local xMatch = pos.x == val[1]
    local yMatch = pos.y == val[2]
    local zMatch = pos.z == val[3]
    if xMatch and yMatch and zMatch then
      --ez pz
    elseif xMatch and yMatch then
      local facing
      if val[3] > pos.z then
        facing = 2
      else
        facing = 0
      end
      turnToFace(facing)
      while globalPosition().z ~= val[3] do
        forward()
      end
    elseif yMatch and zMatch then
      local facing
      if val[1] < pos.x then
        facing = 3
      else
        facing = 1
      end
      turnToFace(facing)
      while globalPosition().x ~= val[1] do
        forward()
      end
    elseif zMatch and xMatch then
      local go
      if val[2] > pos.y then
        go = up
      else
        go = down
      end
      while globalPosition().y ~= val[2] do
        --turtle[dir]()
        go()
      end
    else
      print("warn: bad path or not on the path")
    end
  end
  
  turnToFace(path[1][4])
  
  for i=1,16 do
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
  
  for _,val in ipairs(path) do
    --local val = path[i]
    local pos = globalPosition()
    local xMatch = pos.x == val[1]
    local yMatch = pos.y == val[2]
    local zMatch = pos.z == val[3]
    if xMatch and yMatch and zMatch then
      --ez pz
    elseif xMatch and yMatch then
      local facing
      if val[3] > pos.z then
        facing = 2
      else
        facing = 0
      end
      turnToFace(facing)
      while globalPosition().z ~= val[3] do
        forward()
      end
    elseif yMatch and zMatch then
      local facing
      if val[1] < pos.x then
        facing = 3
      else
        facing = 1
      end
      turnToFace(facing)
      while globalPosition().x ~= val[1] do
        forward()
      end
    elseif zMatch and xMatch then
      local go
      if val[2] > pos.y then
        go = up
      else
        go = down
      end
      while globalPosition().y ~= val[2] do
        go()
      end
    else
      error"bad path or not on the path"
    end
  end
  
  turnToFace(path[#path][4])
  while inventoryHasEmptySlot() do
    turtle.suckDown()
    sleep(1)
  end
end
