local tArgs = {...}
--local fromcn = tArgs[1] or peripheral.find("minecraft:chest") or peripheral.find("minecraft:shulker_box")
--local toc = tArgs[2]
local function thing(fromcn, tocn)
  local fromc = peripheral.wrap(fromcn)
  while true do
    for k,_ in pairs(fromc.list()) do
      fromc.pushItems(tocn, k)
    end
  end
end

local function contains(arr, val)
  for k,v in ipairs(arr) do
    if v == val then return true end
  end
  return false
end

local funcs = {}

for i=1,(#tArgs/2) do
  funcs[i] = function()
    local fromcn = tArgs[(i-1)*2+1]
    local tocn = tArgs[(i-1)*2+2]
    while true do
      pcall(thing, fromcn, tocn)
      while (not peripheral.isPresent(fromcn)) or (not contains(peripheral.call(fromcn,"getTransferLocations"),tocn)) do
        os.sleep()
      end
    end
  end
end

parallel.waitForAll(table.unpack(funcs))
