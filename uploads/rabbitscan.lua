local modules = peripheral.wrap("back")
local canvas = modules.canvas()
canvas.clear()
local text = canvas.addText({5,5}, "No rabbits :(")
text.setScale(1)
--rednet.open("front")
while true do
  local entities = modules.sense()
  for _,val in ipairs(entities) do
    if val.name == "Rabbit" or val.displayName == "Rabbit" then
      text.setText("Rabbit! " .. val.x .. " " .. val.y .. " " .. val.z)
      --rednet.broadcast("Rabbit! " .. val.x .. " " .. val.y .. " " .. val.z, "rabbitscan")
    end
  end
  os.sleep()
end
