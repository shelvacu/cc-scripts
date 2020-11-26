require"shellib"
western_x = -283
door_xs = {
    -352,
    -321,
    -305,
    -297,
    -293,
    -291,
    -289,
    -288
}

my_forward = ->
    flag, dat = turtle.inspect()
    if dat != nil and dat.name == "minecraft:snow_layer"
        turtle.dig()
    forward()
mf = my_forward
place_door = ->
    turnToFace(0)
    mf()
    turnToFace(3)
    turtle.place()
    sleep(7)
    turnToFace(2)
    mf()

pd = place_door

getGlobalOffset()
assert(globalPosition().facing == 3)
assert(globalPosition().x == western_x + 1)
turtle.select(1)
while turtle.getItemCount() >= 3
    turtle.place()
    sleep(7)
    turnToFace(2)
    mf()
    mf()
    turnToFace(3)
    while globalPosition().x > (door_xs[1]+1)
        mf()
    pd()
    turnToFace(1)
    while globalPosition().x < (door_xs[2]+1)
        mf()
    pd()
    turnToFace(3)
    pivot = 2
    while pivot < #door_xs
        while globalPosition().x > door_xs[pivot-1]
            mf()
        turnToFace(0)
        turtle.dig()
        turnToFace(1)
        while globalPosition().x < (door_xs[pivot+1]+1)
            mf()
        pd()
        turnToFace(3)
        pivot = pivot + 1
    while globalPosition().x > door_xs[pivot-1]
        mf()
    turnToFace(0)
    turtle.dig()
    turnToFace(1)
    while globalPosition().x < (western_x)
        mf()
    turnToFace(0)
    mf()
    turtle.dig()
    turnToFace(3)
    back()
    