-- one: The first argument
-- many: All other chests connected
local tArgs = {...}

local mod = peripheral.find("modem")
local theOne

if not mod or mod.isWireless() then
  error"nop"
end

if turtle and not tArgs[1] then
  theOne = mod.getNameLocal()
else
  theOne = tArgs[1]
end

turtle.select(1)
while true do
  os.sleep()
  local names = mod.getNamesRemote()
  for _,v in ipairs(names) do
    if string.sub(v,1,16) == "minecraft:chest_" and v ~= theOne then
      local suc, items = pcall(peripheral.call, v, "list")
      if suc and items then
        for k,_ in pairs(items) do
          local success, items = pcall(function()
            --theOne.pullItems(v, k)
            return peripheral.call(v, "pushItems", theOne, k)
          end)
          if not success then break end
          if items > 0 then
            turtle.dropDown()
          end
        end
      end
    end
  end
  -- if turtle then
  --   for i=1,16 do
  --     turtle.select(i)
  --     turtle.dropDown()
  --   end
  -- end
end
