require"shellib"

while true do
  local _, yPos, _ = gps.locate()
  assert(yPos)
  if yPos <= 14 then
    break
  end
  turtle.digDown()
  back()
  turtle.select(2)
  turtle.place()
  turtle.select(1)
  turtle.placeUp()
  turtle.digDown()
  back()
  turtle.digDown()
  down()
  forward()
  forward()
end
