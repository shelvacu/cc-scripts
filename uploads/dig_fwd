local blocks_to_go = 100
local traveled = 0
while blocks_to_go > 0 do 
  turtle.dig()
  turtle.digUp()
  turtle.digDown()
  turtle.forward()

  if math.fmod(blocks_to_go, 10) == 1 and traveled > 2 then
    turtle.turnRight()
    turtle.dig()
    turtle.turnLeft()
  end
  if math.fmod(blocks_to_go, 10) == 0 and traveled > 2 then
    turtle.turnLeft()
    turtle.turnLeft()
    turtle.select(1)
    turtle.place()
    turtle.turnLeft()
    turtle.turnLeft()
  end
  
  blocks_to_go = blocks_to_go - 1
  traveled = traveled + 1
end