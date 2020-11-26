require "shellib"

getGlobalOffset()

--assert(globalPosition().facing == 2)
facing = globalPosition().facing
for i=1,32
    turtle.place()
    turnToFace(2)
    forward()
    turnToFace(facing)