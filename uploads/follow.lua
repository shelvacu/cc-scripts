local bla = peripheral.wrap("back")
local tArgs = {...}
bla.disableAI()
function follow()
  while true do
    local entities = bla.sense()
    for _,v in ipairs(entities) do
      if v.displayName == tArgs[1] and (math.abs(v.x) + math.abs(v.z)) > 2 then
        bla.walk(v.x, v.y, v.z)
      end
    end
  end
end

function remoteDrop()
  rednet.open("front")
  rednet.receive("dropit")
  bla.getEquipment().drop(6)
end

parallel.waitForAll(follow, remoteDrop)
