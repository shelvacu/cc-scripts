local mods = peripheral.wrap("back")
mods.canvas3d().clear()
local canvas = mods.canvas3d().create()

print("stand still")
canvas.recenter()
local center = {gps.locate()}
if not center[1] then
  error("no gps :(")
end

function seqEq(a,b)
  if #a ~= #b then
    return false
  end
  for i=1,#a do
    if a[i] ~= b[i] then
      return false
    end
  end
  return true
end

function floor(n)
  return math.floor(n)
end

function isNan(n)
  return n ~= n
end

function middleish(n)
  if isNan(n) then return false end
  return true
  --local frac = n % 1
  --return frac > 0.3 and frac < 0.8
end

local searchBlock = "minecraft:trapdoor"

local cache = {}
while true do
  os.sleep(1)
  local currPosBefore = {gps.locate()}
  local blocks-- = mods.scan()
  local currPos
  parallel.waitForAll(
    function()
      blocks = mods.scan()
    end,
    function()
      currPos = {gps.locate()}
    end
  )
  local currPosAfter = {gps.locate()}
  --[[local currPos = {
    (currPos1[1] + currPos2[1])/2,
    (currPos1[2] + currPos2[2])/2,
    (currPos1[3] + currPos2[3])/2
  }]]
  --if seqEq(currPos,currPos2) then
  if currPos[3] and middleish(currPos[1]) and middleish(currPos[2]) and middleish(currPos[3]) then
    for _, v in ipairs(blocks) do
      blockAbsPos = {floor(currPos[1]) + v.x, floor(currPos[2]) + v.y, floor(currPos[3]) + v.z}
      --local key = blockAbsPos[1] .. "," .. blockAbsPos[2] .. "," .. blockAbsPos[3]
      local key = table.concat(blockAbsPos, ",")
      if v.name == searchBlock and not cache[key] then
        print("found the searchblock "..key)
        local box = canvas.addBox(blockAbsPos[1] - center[1], blockAbsPos[2] - center[2], blockAbsPos[3] - center[3], 1, 1, 1, 0x0000DD44)
        box.setDepthTested(false)
        cache[key] = box
      elseif v.name ~= searchBlock and cache[key] then
        local box = cache[key]
        box.remove()
        cache[key] = nil
      end
    end
  end
end
