local enabled = (redstone.getInput("back") and redstone.getInput("bottom"))
os.queueEvent("tick")
print("start")

local function hopper()
  while true do
    os.sleep()
    turtle.suckUp()
    turtle.suck()
    if enabled then
      turtle.dropDown()
      if turtle.getItemCount() == 0 then
        local selected = turtle.getSelectedSlot()
        if selected == 16 then
          turtle.select(1)
        else
          turtle.select(selected + 1)
        end
      end
    end
  end
end

local function watchRedstone()
  while true do
    os.sleep()
    os.pullEvent("redstone")
    enabled = (redstone.getInput("back") and redstone.getInput("bottom"))
  end
end

parallel.waitForAll(hopper, watchRedstone)

--[[
while true do
  local ev, r1, r2, r3, r4, r5 = os.pullEvent()
  if not ev == "tick" then print("event "..ev) end

  if ev == "redstone" then
    enabled = (redstone.getInput("right") and redstone.getInput("bottom"))
    os.queueEvent("tick")
  elseif ev == "tick" then
    turtle.suckUp()
    if enabled then
      turtle.dropDown()
      if turtle.getItemCount() == 0 then
        local selected = turtle.getSelectedSlot()
        if selected == 16 then
          turtle.select(1)
        else
          turtle.select(selected + 1)
        end
      end
    end
    os.queueEvent("tick")
  end
end
--]]
