local tArgs = {...}

local inDir = tArgs[1]
local outDir = tArgs[2]

local directions = { up = true, forward = true, down = true }

local suck = { up = turtle.suckUp, forward = turtle.suck, down = turtle.suckDown }
local drop = { up = turtle.dropUp, forward = turtle.drop, down = turtle.dropDown }
local detect = { up = turtle.detectUp, forward = turtle.detect, down = turtle.detectDown }

if not directions[inDir] then error"invalid inDir" end
if not directions[outDir] then error"invalid outDir" end

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

while true do
  if inventoryHasEmptySlot() then
    --print"suck"
    suck[inDir]()
  end
  if detect[outDir]() then
    --print"drop"
    if not drop[outDir]() then
      --print"sleep"
      sleep(5)
    end
    if turtle.getItemCount() == 0 then
      --print"inc"
      local selected = turtle.getSelectedSlot()
      if selected == 16 then
        turtle.select(1)
      else
        turtle.select(selected + 1)
      end
    end
  end
end
