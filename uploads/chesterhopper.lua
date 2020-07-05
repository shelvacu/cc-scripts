local stateMachine = {}

function stateMachine:off(ev, r1, r2)
  if ev == "tick" then
    turtle.suckUp()
  elseif ev == "redstone" then
    if redstone.getInput("right") and redstone.getInput("bottom") then
      self.currState = self.on
    end
  end
end

function stateMachine:on(ev)
  if ev == "tick" then
    turtle.suckUp()
    turtle.dropDown() 
    if turtle.getItemCount() == 0 then
      local selected = turtle.getSelectedSlot()
      if selected == 16 then
        turtle.select(1)
      else
        turtle.select(selected + 1)
      end
    end
  elseif ev == "redstone" then
    if not (redstone.getInput("right") and redstone.getInput("bottom")) then
      self.currState = self.off
    end
  end
end

stateMachine.currState = stateMachine.off

local timerId = os.startTimer(0)
while true do
  local ev, r1, r2, r3, r4, r5 = os.pullEvent()
  if ev == "timer" and r1 == timerId then
    ev = "tick"
  end

  stateMachine:currState(ev, r1, r2, r3, r4, r5)

  if ev == "tick" then
    timerId = os.startTimer(0)
  end
end
