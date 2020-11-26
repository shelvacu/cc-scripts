require("shellib")
getGlobalOffset()
local facing = globalPosition().facing
for i = 1, 32 do
  turtle.place()
  turnToFace(2)
  forward()
  turnToFace(facing)
end
