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
    --print"suck"
    turtle.suckUp()
    sleep(0.1)
  end
  if turtle.detectDown() then
    --print"drop"
    if not turtle.dropDown() then
      --print"sleep"
      sleep(5)
    end
    if turtle.getItemCount() == 0 then
      --print"inc"
      local selected = turtle.getSelectedSlot()
      if selected == 16 then
        turtle.select(1)
      else
        turtle.select(selected + 1)
      end
    end
  end
end
