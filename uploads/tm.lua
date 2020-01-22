--thorough miner v0.1 by shelvacu

require"shellib"
local af = require"atomicFile"

local digNames = {
  up = digUp,
  forward = dig,
  down = digDown
}

local placeNames = {
  up = placeUp,
  forward = place,
  down = placeDown
}

local inspectNames = {
  up = inspectUp,
  forward = inspect,
  down  = inspectDown
}

local function doTheDig(dir)
  while true do
    local suc, bi = turtle[inspectNames[dir]]()
    if suc and bi.name == "minecraft:lava" and bi.state.level == 0 then --lava source block
      local found = false
      for i=1,16 do
        local info = turtle.getItemDetails(i)
        if info and info.name = "minecraft:bucket" then
          turtle.select(i)
          turtle[placeNames[dir]]()
          found = true
          break
        end
      end
      if not found then
        error"no buckets to hold this lava!"
      end
    elseif not suc then
      break
    elseif --(not suc) or
      bi.name == "minecraft:stone" or
      bi.name == "minecraft:cobblestone" or
      bi.name == "minecraft:coal_ore" or
      bi.name == "minecraft:iron_ore" or
      bi.name == "minecraft:gold_ore" or
      bi.name == "minecraft:redstone_ore" or
      bi.name == "minecraft:lapis_lazuli_ore" or
      bi.name == "minecraft:diamond_ore" or
      bi.name == "minecraft:emerald_ore" or
      bi.name == "minecraft:fence" or
      bi.name == "minecraft:planks" or
      bi.name == "minecraft:rail" or
      bi.name == "minecraft:water" or
      bi.name == "minecraft:obsidian"
    then
      turtle[digNames[dir]]()
    else
      error("unrecognized block " .. bi.name)
    end
  end
end   

local tArgs = { ... }

local params = af.read(tArgs[1])

if not getGlobalOffset() then
  turnLeft()
  getGlobalOffset() or die("no position :(")
end


