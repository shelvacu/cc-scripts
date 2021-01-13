require"shellib"

local returnSpot = {x = -275, y = 73, z = 296}


getGlobalOffset()

local fuelReq = 2
fuelReq = fuelReq + (254 - globalPosition().y) --fuel to go up
fuelReq = fuelReq + math.abs(returnSpot.x - globalPosition().x) + math.abs(returnSpot.z - globalPosition().z) + 10
fuelReq = fuelReq + (254 - returnSpot.y)

if turtle.getFuelLevel() < fuelReq then
    error("Not enough fuel! Have "..turtle.getFuelLevel()..", need an estimated "..fuelReq.." fuel")
end

function checkChest()
    local res, tbl = turtle.inspectDown()
    if not (res and (tbl.name == "minecraft:trapped_chest" or tbl.name == "minecraft:chest")) then
        error("no chest below! You sure I'm facing the right direction?")
    end
end

checkChest()
forward()
checkChest()
back()

function select()
    while turtle.getItemDetail() == nil or (turtle.getItemDetail().name ~= "minecraft:chest" and turtle.getItemDetail().name ~= "minecraft:trapped_chest") do
        local sel = turtle.getSelectedSlot()
        sel = sel + 1
        if sel == 17 then sel = 1 end
        turtle.select(sel)
    end
end

while globalPosition().y < 254 do
    select()
    while turtle.dig() do end
    turtle.place()
    while turtle.digUp() do end
    up()
    select()
    turtle.placeDown()
end

while returnSpot.x ~= globalPosition().x or returnSpot.z ~= globalPosition().z do
    --poor mans pathfinding
    while globalPosition().x < returnSpot.x and turnToFace(1) and tryForward() do end
    while globalPosition().x > returnSpot.x and turnToFace(3) and tryForward() do end
    while globalPosition().z < returnSpot.z and turnToFace(2) and tryForward() do end
    while globalPosition().z > returnSpot.z and turnToFace(0) and tryForward() do end
end

while returnSpot.y < globalPosition().y do
    down()
end