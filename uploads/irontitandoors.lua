require("shellib")
local western_x = -283
local door_xs = {
  -352,
  -321,
  -305,
  -297,
  -293,
  -291,
  -289,
  -288
}
local my_forward
my_forward = function()
  local flag, dat = turtle.inspect()
  if dat ~= nil and dat.name == "minecraft:snow_layer" then
    turtle.dig()
  end
  return forward()
end
local mf = my_forward
local place_door
place_door = function()
  turnToFace(0)
  mf()
  turnToFace(3)
  turtle.place()
  sleep(7)
  turnToFace(2)
  return mf()
end
local pd = place_door
getGlobalOffset()
assert(globalPosition().facing == 3)
assert(globalPosition().x == western_x + 1)
turtle.select(1)
while turtle.getItemCount() >= 3 do
  turtle.place()
  sleep(7)
  turnToFace(2)
  mf()
  mf()
  turnToFace(3)
  while globalPosition().x > (door_xs[1] + 1) do
    mf()
  end
  pd()
  turnToFace(1)
  while globalPosition().x < (door_xs[2] + 1) do
    mf()
  end
  pd()
  turnToFace(3)
  local pivot = 2
  while pivot < #door_xs do
    while globalPosition().x > door_xs[pivot - 1] do
      mf()
    end
    turnToFace(0)
    turtle.dig()
    turnToFace(1)
    while globalPosition().x < (door_xs[pivot + 1] + 1) do
      mf()
    end
    pd()
    turnToFace(3)
    pivot = pivot + 1
  end
  while globalPosition().x > door_xs[pivot - 1] do
    mf()
  end
  turnToFace(0)
  turtle.dig()
  turnToFace(1)
  while globalPosition().x < (western_x) do
    mf()
  end
  turnToFace(0)
  mf()
  turtle.dig()
  turnToFace(3)
  back()
end
