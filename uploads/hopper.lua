local function inventoryHasEmptySlot()
  for i=1,16 do
    if turtle.getItemCount(i) == 0 then
      return true
    end
  end
  return false
end

local function inventoryFull()
  return not inventoryHasEmptySlot()
end

while true do
  if inventoryHasEmptySlot() then
    turtle.suckUp()
  end
  if turtle.detectDown() then
    if not turtle.dropDown() then
      sleep(5)
    end
  end
end
