-- Naming things is hard. This is for the turtle that I'm using to move all the items from the old inventory system to the new.
-- it does suckUp() constantly and then moves any items to a remote chest connected by rednet wire

local remoteChest = peripheral.wrap("minecraft:chest_51")
local modem = peripheral.wrap("front")
local name = modem.getNameLocal()

local function suckThread()
  while true do
    turtle.suckUp() --ferengi rules of aquisition #33
  end
end

local function doThread()
  local i=0
  while true do
    i = i+1
    if i == 17 then os.sleep() i = 1 end
    if turtle.getItemCount(i) > 0 then
      if remoteChest.pullItems(name, i) == 0 then
        os.sleep(0.5)
      end
    end
  end
end

parallel.waitForAll(suckThread, doThread)
