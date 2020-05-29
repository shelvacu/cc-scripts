-- chest to item
-- item to chests

-- itemSpecificDamageInfo:
--   name: string minecraft id
--   damage: int
--   stackSize: int
--   hasNBT: bool

-- chestInfo:
--   count: int
--   location: {x,y,z}
--   customName: string|nil

-- itemInfo:
--   name: minecraft id, like "minecraft:stone"
--   stackSize: int
--   hasNBT: bool, really a bad name for "has properties that the turtle API can't detect that differ even when stackSize, item id, and damage are all the same"
--     if true, customName is used and queried for every item deposited
--   damageDiffers: bool, an indicator that stackSize and/or hasNBT may be different for different damage values. If true, the upper level stackSize and hasNBT are just a template.

-- some data dir
-- /items/
-- /items/minecraft:stone.i - information about stone; stack size and such
-- /items/minecraft:stone/
-- /items/minecraft:stone/5.c - {info: itemSpecificDamageInfo, chests: arr of chestInfos with andesite in them and how many}
-- /chests/
-- /chests/5,-1,4 - {count: int, location: {x,y,z}, name: id|nil, damage: int|nil, customName: string|nil}. If the chest doesn't exist, no file should exist. Coordinates are not relative, they are absolute and can be negative. Same ordering as minecraft.
-- /empty_chests - list of empty chestInfo's
-- /wal - write ahead log
-- /params - various things like starting position, size/boundaries, etc

-- allocation:
-- * figure out/query user for information, fill in /items/<name>.i
-- * allocate an empty chest (in memory, nothing written to disk yet)
-- * move to the given chest
-- * write in WAL: type: deposit, location:, name:, damage:, slot:, chestCountBefore: 0
-- * place item in chest [turtle.dropItem()]. This is the comittal action, this chest is now allocated.
-- * write /chests/<location>
-- * write /items/<name>/<damage>.c
-- * write /empty_chests
-- * write WAL to mark transaction finished/complete/whatever

-- allocation recovery:
-- * read record from WAL
-- * check if slot is empty. If it's full, retry allocation
-- * check /chests/<location>
-- * check /items/<name>/<damage>.c
-- * check /empty_chests
-- * write WAL

-- new item, already allocated:
-- * find a chest to put it in
-- * move to chest
-- * for every stack or lesser:
--   * write in WAL: type: deposit, location:, item:, damage:, slot:, count:, chestCountBefore:
--   * turtle.dropItem() comittal
--   * write /chests/<location>
--   * write /items/<name>/<damage>.c
--   * write WAL finished

-- withdraw:
-- * find and move to relevant chest
-- * for every stack or lesser:
--   * write in WAL: type: withdraw, location:, item:, damage:, slot:, count:, chestCountBefore:
--   * turtle.suck() comittal
--   * write /chests/<location>
--   * write /items/<name>/<damage>.c
--   * write WAL finished

-- Known bugs:
-- When withdrawing more than one stack, only one stack is marked in inventory (or something like that)
-- When chests fill up, the last chest is not correctly allocated.

--[[
local debug = dofile"cooldebug.lua"
debug.override()
--]]

require "shellib"
local inspect = require"inspect"
Settings.ensureFuel = true
local mp = require "mp"
local af = require "atomicFile"

local stateMachine = {
  v_startPos = {
    v_itemInfo = {},
    v_itemList = {},
    v_queryQuantity = {},
    v_queryItem = {}
  },
  v_forEvery = {},
  searchResults = {},
  slotNames = {},
  itemCanNames = {},
  itemCanNameToInfo = {}
}

local params
local function clear()
  term.clear()
  term.setCursorPos(1,1)
end

local function boundingBox(params)
  local startingPos = params.startingPos
  local f = params.forwards
  local r = params.rights
  local z
  local x
  if startingPos.facing == 0 then
    z = -f
    x =  r
  elseif startingPos.facing == 1 then
    z = r
    x = f
  elseif startingPos.facing == 2 then
    z = f
    x = -r
  elseif startingPos.facing == 3 then
    z = -r
    x = f
  end
  local res = {}
  res.lnw = { --lower north-west corner
    x = math.min(x, startingPos.x),
    y = startingPos.y - (1 + params.downs),
    z = math.min(z, startingPos.z)
  }
  res.use = { --upper south-east corner
    x = math.max(x, startingPos.x),
    y = startingPos.y - 1,
    z = math.max(z, startingPos.z)
  }
  return res
end

local function locationEq(a, b)
  return a.x == b.x and a.y == b.y and a.z == b.z and a.facing == b.facing
end

local function locationAddInto(a, b)
  a.x = a.x + b.x
  a.y = a.y + b.y
  a.z = a.z + b.z
end

-- this code just pretends back() doesn't exist, lol
local function moveTo(spot)
  --print("moving to ")--.. spot.x .. "," .. spot.y .. "," .. spot.z)
  --print(inspect({spot, verticalFirst}))
  local glob = globalPosition()
  if glob.x == spot.x and glob.z == spot.z then
    --we only need to move up and down
    while true do
      local glob = globalPosition()
      if glob.y < spot.y then
        up()
      elseif glob.y > spot.y then
        down()
      else
        break
      end
    end
    turnToFace(spot.facing)
    return
  end

  while true do
    local glob = globalPosition()
    if glob.y < params.startingPos.y then
      up()
    elseif glob.y > params.startingPos.y then
      down()
    else
      break
    end
  end
  local glob = globalPosition()
  local dirs = {}
  if spot.x > glob.x then
    dirs.x = 1
  elseif spot.x < glob.x then
    dirs.x = 3
  else
    dirs.x = nil
  end
  if spot.z > glob.z then
    dirs.z = 2
  elseif spot.z < glob.z then
    dirs.z = 0
  else
    dirs.z = nil
  end

  if dirs.x or dirs.z then
    if dirs.x and dirs.z then
      local a
      if math.fmod(glob.facing, 2) == 0 then --north or south
        if glob.facing == dirs.z then
          a = "z"
        else
          a = "x"
        end
      else --west or east
        if glob.facing == dirs.x then
          a = "x"
        else
          a = "z"
        end
      end
      turnToFace(dirs[a])
      while spot[a] ~= globalPosition()[a] do
        forward()
      end
      dirs[a] = nil
    end
    local a
    if dirs.x then
      a = "x"
    else
      a = "z"
    end
    turnToFace(dirs[a])
    while spot[a] ~= globalPosition()[a] do
      forward()
    end
  end

  while true do
    local glob = globalPosition()
    if glob.y < spot.y then
      up()
    elseif glob.y > spot.y then
      down()
    else
      break
    end
  end
  turnToFace(spot.facing)
end

local function walRecover(actualRecovery) -- actualRecovery: bool, whether or not we're actually recovering from an unexpected shutdown
  local wal = af.read("db/wal")
  if not wal.empty then
    local chestFn = "db/chests/"..wal.location.x..","..wal.location.y..","..wal.location.z
    local itemCFn = "db/items/"..wal.name.."/"..wal.damage..".c"
    if wal.type == "deposit" then
      --textutils.pagedPrint(inspect(wal))
      --print("actualRecovery:")
      --print(actualRecovery)
      if turtle.getItemCount(wal.slot) > 0 then
        turtle.select(wal.slot)
        turtle.drop(wal.count)
      end
      local chestInfo
      if af.exists(chestFn) then
        chestInfo = af.read(chestFn)
        assert(chestInfo.count == wal.chestCountBefore or actualRecovery)
      else
        error("Chest does not exist!")
      end
      
      if chestInfo.count == wal.chestCountBefore then
        chestInfo.count = chestInfo.count + wal.count
        if wal.chestCountBefore == 0 then --allocation
          chestInfo.name = wal.name
          chestInfo.damage = wal.damage
          chestInfo.customName = wal.customName
        end
        af.write(chestFn, chestInfo)
      end
      if not af.exists(itemCFn) then
        error("ItemCInfo does not exist")
      end
      local itemCInfo = af.read(itemCFn)
      local modified = false
      local found = false
      for i, ci in ipairs(itemCInfo.chests) do
        if locationEq(ci.location, wal.location) then
          found = true
          if ci.count == wal.chestCountBefore then
            ci.count = ci.count + wal.count
            modified = true
          end
        end
      end
      if not found then
        local chestInfo = {
          count = wal.count,
          location = wal.location,
          customName = wal.customName
        }
        itemCInfo.chests[#itemCInfo.chests + 1] = chestInfo
        modified = true
      end
      if modified then
        af.write(itemCFn, itemCInfo)
        stateMachine:updateSpecificCanName("db/items/"..wal.name..".i")
      end
      if wal.chestCountBefore == 0 then
        -- this is an allocation
        local emptys = af.read("db/empty_chests")
        local foundIdx
        for i,v in ipairs(emptys) do
          if locationEq(v.location, wal.location) then
            foundIdx = i
            break
          end
        end
        if foundIdx then
          table.remove(emptys, foundIdx)
        end
        af.write("db/empty_chests", emptys)
      end
      af.write("db/wal", {empty = true})
    elseif wal.type == "withdraw" then
      --print(inspect(wal))
      assert((turtle.getItemCount(wal.slot) == 0) or actualRecovery)
      assert((wal.count <= wal.chestCountBefore) or actualRecovery)
      if turtle.getItemCount(wal.slot) == 0 then
        turtle.select(wal.slot)
        turtle.suck(wal.count)
      end
      local actualCount = turtle.getItemCount(wal.slot)
      local chestInfo = af.read(chestFn)
      --print(chestInfo.count)
      assert((chestInfo.count == wal.chestCountBefore) or actualRecovery)
      if chestInfo.count == wal.chestCountBefore then
        chestInfo.count = chestInfo.count - actualCount
        if chestInfo.count == 0 then --this is a deallocation
          chestInfo.name = nil
          chestInfo.damage = nil
          chestInfo.customName = nil
        end
        af.write(chestFn, chestInfo)
      end
      local itemCInfo = af.read(itemCFn)
      local found = false
      local foundIdx = -1
      for i, ci in ipairs(itemCInfo.chests) do
        if
          locationEq(ci.location, wal.location) and
          ci.count == wal.chestCountBefore
        then
          --ci.count = ci.count - actualCount
          foundIdx = i
          found = true
        end
      end
      if found then
        if chestInfo.count == 0 then
          table.remove(itemCInfo.chests, foundIdx)
        else
          itemCInfo.chests[foundIdx] = chestInfo
        end
        af.write(itemCFn, itemCInfo)
        stateMachine:updateSpecificCanName("db/items/"..wal.name..".i")
      end
      if chestInfo.count == 0 then --this is a deallocation
        local emptys = af.read("db/empty_chests")
        local found = false
        for i, ci in pairs(emptys) do
          if locationEq(chestInfo, ci) then
            found = true
            break
          end
        end
        if not found then
          table.insert(emptys, chestInfo)
          af.write("db/empty_chests", emptys)
        end
      end
      af.write("db/wal", {empty = true})
    else
      die("unrecognized WAL type")
    end
  end
end

-- return the index of the line in the info screen that should ask for the customName
local function customName(info)
  if (info.damageDiffers and info.damageInfo.hasNBT) or ((not info.damageDiffers) and info.hasNBT) then
    if info.damageDiffers then
      return 6
    else
      return 4
    end
  else
    return nil
  end
end

local function bool2str(b, y, n)
  local y = y or "y"
  local n = n or "n"
  if b then
    return y
  else
    return n
  end
end

local function printItemInfo(info, selected)
  print(info.name)
  print(bool2str(selected==0,">"," ") .. "[commit]")
  print(bool2str(selected==1,">"," ") .. "stackSize:     " .. info.stackSize)
  print(bool2str(selected==2,">"," ") .. "hasNBT:        " .. bool2str(info.hasNBT))
  print(bool2str(selected==3,">"," ") .. "damageDiffers: " .. bool2str(info.damageDiffers))
  local idx = 4
  if info.damageDiffers then
    print(info.name .. " d" .. info.damage)
    -- 4
    print(bool2str(selected==idx,">"," ") .. "hasNBT:        " .. bool2str(info.damageInfo.hasNBT))
    idx = idx + 1
    -- 5
    print(bool2str(selected==idx,">"," ") .. "stackSize:     " .. info.damageInfo.stackSize)
    idx = idx + 1
  end
  if customName(info) then
    --4 or 6
    print(bool2str(selected==idx,">"," ") .. "customName:    " .. info.customName)
    idx = idx + 1
  end
end

local function selectionsCount(info)
  local count = 4
  if info.damageDiffers then
    count = count + 2
  end
  if customName(info) then
    count = count + 1
  end
  return count
end

local function getCharFromNumeralKeyCode(key)
  if key == keys.zero or key == keys.numPad0 then
    return "0"
  elseif key == keys.one or key == keys.numPad1 then
    return "1"
  elseif key == keys.two or key == keys.numPad2 then
    return "2"
  elseif key == keys.three or key == keys.numPad3 then
    return "3"
  elseif key == keys.four or key == keys.numPad4 then
    return "4"
  elseif key == keys.five or key == keys.numPad5 then
    return "5"
  elseif key == keys.six or key == keys.numPad6 then
    return "6"
  elseif key == keys.seven or key == keys.numPad7 then
    return "7"
  elseif key == keys.eight or key == keys.numPad8 then
    return "8"
  elseif key == keys.nine or key == keys.numPad9 then
    return "9"
  else
    return nil
  end
end

local function isNumeralKeyCode(key)
  return not not getCharFromNumeralKeyCode(key)
end

function stateMachine:s_startPos(ev, key)
  if ev == "start" then
    self:s_startPos_waiting("start")
  elseif ev == "key" and key == keys.period then
    self:s_startPos_waiting("start")
  end
end

function stateMachine:s_startPos_waiting(ev, key, ...)
  if ev == "start" then
    self.currState = self.s_startPos_waiting
    clear()
    print("[d]eposit")
    print("[w]ithdraw")
    print()
    print("fuel: " .. turtle.getFuelLevel())
    print("chests free: " .. (#af.read("db/empty_chests")))
  elseif ev == "key" and key == keys.d then
    self:s_startPos_deposit("start")
  --elseif ev == "key" and key == keys.w then
  elseif ev == "char" and key == "w" then
    self:s_startPos_queryItem("start")
  elseif ev == "turtle_inventory" then
    local haveEvery, itemInfos = self:checkInv()
    while not haveEvery do
      turnLeft()
      for idx, info in ipairs(itemInfos) do
        if info.empty or info.haveAllInfo then
          --no dothing
        else
          turtle.select(idx)
          turtle.drop()
        end
      end
      turnRight()
      haveEvery, itemInfos = self:checkInv()
    end
    if self.autoInvTimer then
      os.cancelTimer(self.autoInvTimer)
    end
    os.autoInvTimer = os.startTimer(2)
  elseif ev == "timer" and key == os.autoInvTimer then
    os.autoInvTimer = nil
    self:s_forEvery("start", "deposit")
  else
    self:s_startPos(ev, key, ...)
  end
end

function chestAccessLocation(chestLocation)
  local destLocation = {
    y = chestLocation.y
  }
  local bound = boundingBox(params)
  if chestLocation.x == bound.lnw.x then
    destLocation.x = chestLocation.x + 1
    destLocation.z = chestLocation.z
    destLocation.facing = 3 --west, -x
  elseif chestLocation.z == bound.lnw.z then
    destLocation.x = chestLocation.x
    destLocation.z = chestLocation.z + 1
    destLocation.facing = 0 --north, -z
  else
    destLocation.x = chestLocation.x - 1
    destLocation.z = chestLocation.z
    destLocation.facing = 1 --east, +x
  end
  return destLocation
end

function stateMachine:withdraw(howMany, v, slot)
  local chestLocation
  local chestCountBefore
  local count
  local slot = slot or 1
  assert(howMany == 1 or not v.info.ci)
  clear()
  print("working...")
  if v.info.ci then -- if .ci is set then this is a hasNBT/customName item, and the chest should only have one and we can only grab one at a time
    chestLocation = v.info.ci.location
    chestCountBefore = 1
    count = 1
  else
    assert(#v.cInfo.chests > 0)
    chestLocation = v.cInfo.chests[1].location
    chestCountBefore = v.cInfo.chests[1].count
    count = math.min(chestCountBefore, howMany, v.stackSize)
  end
  local destLocation = chestAccessLocation(chestLocation)
  moveTo(destLocation)
  --oh my god, we did it
  --we're in front of the chest, ready.
  --about to deposit the master's glorious items.
  --stack of cobblestone #7,853 may you be deposited well
  --in today and in tommorow, forever organized
  --for our master
  --amen
  local wal = {
    type = "withdraw",
    --location = globalPosition(),
    location = chestLocation,
    name = v.info.name,
    damage = v.info.damage,
    slot = slot,
    count = count,
    chestCountBefore = chestCountBefore,
    customName = v.info.customName,
    empty = false
  }
  assert(wal.damage)
  assert(wal.name)
  assert(turtle.getItemCount(wal.slot) == 0)
  af.write("db/wal", wal)
  -- I don't know if this is genius or idiotic, but recovering from the wal is nearly the same as performing some action normally, so...
  walRecover(false)
  self:updateSpecificCanName("db/items/" .. v.info.name .. ".i")
  assert(self.itemCanNameToInfo[v.canName])
  v.info = self.itemCanNameToInfo[v.canName]
  v.cInfo = v.info.cInfo
  v.stackSize = v.info.stackSize
  if howMany > count and slot < 16 then
    -- need to update v's chestInfos!
    self:withdraw(howMany - count, v, slot + 1)
  else
    moveTo(params.startingPos)
  end
end

function forEveryDeposit(slotNames)
  for slot=1,16 do
    local turtleItemInfo = turtle.getItemDetail(slot)
    if turtleItemInfo then --normally I'd do `if not turtleItemInfo then continue end` but lua doesn't have continue because fuck lua
      local itemInfo  = af.read("db/items/" .. turtleItemInfo.name .. ".i")
      local itemCInfo = af.read("db/items/" .. turtleItemInfo.name .. "/" .. turtleItemInfo.damage .. ".c")
      local chestIdx = nil
      local stackSize
      local hasNBT
      if itemInfo.damageDiffers then
        stackSize = itemCInfo.info.stackSize
        hasNBT = itemCInfo.info.hasNBT
      else
        stackSize = itemInfo.stackSize
        hasNBT = itemInfo.hasNBT
      end
      local maxCount = 9 * 3 * stackSize
      local customName = nil
      if hasNBT then
        if slotNames then
          customName = slotNames[slot]
        else
          assert(false)
        end
      end
      local chestLocation
      local chestCountBefore
      if not hasNBT then
        for i, val in ipairs(itemCInfo.chests) do
          --todo: potentially split a deposit into multiple pieces
          if val.count + turtleItemInfo.count <= maxCount then
            chestLocation = val.location
            chestCountBefore = val.count
            break
          end
        end
      end
      if not chestLocation then
        local emptys = af.read("db/empty_chests")
        if #emptys == 0 then
          moveTo(params.startingPos)
          error("no chests available!")
        end
        chestLocation = emptys[1].location
        chestCountBefore = 0
      end
      local destLocation = chestAccessLocation(chestLocation)
      moveTo(destLocation)
      --oh my god, we did it
      --we're in front of the chest, ready.
      --about to deposit the master's glorious items.
      --stack of cobblestone #7,853 may you be deposited well
      --in today and in tommorow, forever organized
      --for our master
      --amen
      local wal = {
        type = "deposit",
        --location = globalPosition(),
        location = chestLocation,
        name = turtleItemInfo.name,
        damage = turtleItemInfo.damage,
        slot = slot,
        count = turtleItemInfo.count,
        chestCountBefore = chestCountBefore,
        customName = customName,
        empty = false
      }
      af.write("db/wal", wal)
      -- I don't know if this is genius or idiotic, but recovering from the wal is the same as performing some action normally, so...
      walRecover(false)
    end
  end
end
      
function stateMachine:s_forEvery(ev, direction, ...)
  if ev == "start" then
    self.currState = self.s_forEvery
    clear()
    assert(direction == "deposit")
    print("working...")
    forEveryDeposit(self.slotNames)
    moveTo(params.startingPos)
    self.slotsNames = {}
    self:s_startPos("start")
  end
end
   
function stateMachine:s_startPos_deposit(ev, key, ...)
  if ev == "start" then
    self.currState = self.s_startPos_deposit
    clear()
    print("Place your items in the inventory, and fill out the information when prompted. Press d again when done.")
    local haveEverySlotInfo, _ = self:checkInv()
    if not haveEverySlotInfo then
      return self:s_startPos_itemInfo("start")
    end
  elseif ev == "turtle_inventory" then
    local haveEverySlotInfo, _ = self:checkInv()
    if not haveEverySlotInfo then
      return self:s_startPos_itemInfo("start")
    end
  elseif ev == "key" and key == keys.d then
    return self:s_forEvery("start","deposit")
  else
    return self:s_startPos(ev, key, ...)
  end
end

function stateMachine:s_startPos_itemInfo(ev, key, ...)
  local info = self.v_startPos.v_itemInfo.info
  local selIdx = self.v_startPos.v_itemInfo.selectedIdx
  if ev == "start" then
    self.currState = self.s_startPos_itemInfo
    clear()
    local haveEverySlotInfo, slotsInfo = self:checkInv()
    if haveEverySlotInfo then
      die("haveEverySlotInfo")
    end
    local idx
    for i=1,16 do
      if (not slotsInfo[i].empty) and (not slotsInfo[i].haveAllInfo) then
        idx = i
        break
      end
    end
    --[[
    local info = {
      name = slotsInfo[idx].name,
      damage = slotsInfo[idx].damage,
      customName = ""
    }
    --]]
    local info = slotsInfo[idx]
    info.customName = ""
    print(idx)
    print(inspect(slotsInfo[idx]))
    assert(info.damage)
    info.stackSize = turtle.getItemCount(idx) + turtle.getItemSpace(idx)
    info.damageInfo = {
      hasNBT = info.hasNBT,
      stackSize = info.stackSize
    }
    self.v_startPos.v_itemInfo.info = info
    self.v_startPos.v_itemInfo.selectedIdx = 1
    self.v_startPos.v_itemInfo.forSlot = idx
    printItemInfo(info, self.v_startPos.v_itemInfo.selectedIdx)
  elseif ev == "key" and key == keys.backspace then
    if selIdx == 1 then
      info.stackSize = tonumber(string.sub((info.stackSize) .. "", 1, -2)) or 0
    elseif selIdx == 5 then
      info.damageInfo.stackSize = tonumber(string.sub((info.damageInfo.stackSize).."", 1, -2)) or 0
    elseif customName(info) == selIdx then
      info.customName = string.sub(info.customName, 1, -2)
    else
      --todo: show error somehow?
    end
    clear()
    printItemInfo(info, self.v_startPos.v_itemInfo.selectedIdx)
  elseif ev == "key" and isNumeralKeyCode(key) and (selIdx == 1 or selIdx == 5) then
    local info = self.v_startPos.v_itemInfo.info
    if selIdx == 1 then
      info.stackSize = tonumber((info.stackSize) .. getCharFromNumeralKeyCode(key))
    else
      info.damageInfo.stackSize = tonumber((info.damageInfo.stackSize) .. getCharFromNumeralKeyCode(key))
    end
    clear()
    printItemInfo(info, self.v_startPos.v_itemInfo.selectedIdx)
  elseif ev == "key" and (key == keys.y or key == keys.n) and (selIdx == 2 or selIdx == 3 or (info.damageDiffers and selIdx == 4)) then
    local set = key == keys.y
    if selIdx == 2 then
      info.hasNBT = set
    elseif selIdx == 3 then
      info.damageDiffers = set
    elseif selIdx == 4 then
      info.damageInfo.hasNBT = set
    end
    clear()
    printItemInfo(info, self.v_startPos.v_itemInfo.selectedIdx)
  elseif ev == "key" and (key == keys.up or key == keys.down or key == keys.tab) then
    local dir
    if key == keys.up then
      dir = -1
    else
      dir = 1
    end
    local count = selectionsCount(info)
    selIdx = math.fmod(selIdx + dir + count, count)
    self.v_startPos.v_itemInfo.selectedIdx = selIdx
    clear()
    printItemInfo(info, selIdx)
  elseif ev == "key" and (key == keys.enter or key == keys.numPadEnter or key == keys.space) and self.v_startPos.v_itemInfo.selectedIdx == 0 then
    --commit
    local slot = self.v_startPos.v_itemInfo.forSlot
    local itemInfoFn  = "db/items/" .. info.name .. ".i"
    local itemCInfoFn = "db/items/" .. info.name .. "/" .. info.damage .. ".c"
    if customName(info) then
      self.slotNames[slot] = info.customName
    else
      self.slotNames[slot] = nil
    end
    local cInfo
    if af.exists(itemCInfoFn) then
      cInfo = af.read(itemCInfoFn)
    else
      cInfo = {info = {}, chests = {}}
    end
    cInfo.info.name = info.name
    cInfo.info.damage = info.damage
    if info.damageDiffers then
      cInfo.info.stackSize = info.damageInfo.stackSize
      cInfo.info.hasNBT = info.damageInfo.hasNBT
    else
      cInfo.info.stackSize = info.stackSize
      cInfo.info.hasNBT = info.hasNBT
    end
    local infoData = {}
    infoData.name = info.name
    infoData.stackSize = info.stackSize
    infoData.hasNBT = info.hasNBT
    infoData.damageDiffers = info.damageDiffers
    assert(infoData.name)
    assert(infoData.stackSize)
    af.write(itemCInfoFn, cInfo)
    af.write(itemInfoFn, infoData)
    self:updateSpecificCanName(itemInfoFn)
    self:s_startPos_deposit("start")
  elseif ev == "char" and selIdx == customName(info) then
  --elseif ev == "ch" .. "ar" then
    info.customName = info.customName .. key
    clear()
    printItemInfo(info, selIdx)
  else
    self:s_startPos(ev, key, ...)
  end
end

local function canNameList()
  local itemCanNames = {}
  local itemCanNameToInfo = {}
  local infos = {}
  local infofs = fs.list("db/items")
  for _, name in ipairs(infofs) do
    local fullName = "db/items/"..name
    if not fs.isDir(fullName) then
      local info = af.read(string.sub(fullName,1,-5))
      infos[#infos+1] = info
    end
  end
  for _, info in ipairs(infos) do
    --print(inspect(info))
    for _, name in ipairs(fs.list("db/items/" .. info.name)) do
      assert(info.name)
      local damageInfo = {
        name = info.name,
        stackSize = info.stackSize,
        hasNBT = info.hasNBT
      }
      local fullName = "db/items/" .. info.name .. "/" .. name
      local afName = string.sub(fullName, 1, -5)
      local fileInfo = af.read(afName)
      if info.damageDiffers then
        damageInfo.stackSize = fileInfo.info.stackSize
        damageInfo.hasNBT = fileInfo.info.hasNBT
      end
      damageInfo.damage = fileInfo.info.damage
      damageInfo.cInfo = fileInfo
      if damageInfo.hasNBT then
        for _, ci in ipairs(fileInfo.chests) do
          if ci.count ~= 0 then
            local customInfo = mp.clone(damageInfo)
            customInfo.customName = ci.customName
            customInfo.ci = ci
            customInfo.count = 1
            assert(ci.customName)
            local canName = customInfo.name .. ":" .. customInfo.damage .. ":" .. customInfo.customName
            itemCanNames[#itemCanNames+1] = canName
            itemCanNameToInfo[canName] = customInfo
          end
        end
      else
        local count = 0
        for _, ci in ipairs(fileInfo.chests) do
          count = count + ci.count
        end
        damageInfo.count = count
        local canName = damageInfo.name .. ":" .. damageInfo.damage .. ":"
        itemCanNames[#itemCanNames+1] = canName
        itemCanNameToInfo[canName] = damageInfo
      end
    end
  end
  --print("sorting")
  table.sort(itemCanNames)
  --print("finished sorting")
  return itemCanNames, itemCanNameToInfo
end

local function sortedTableContains(tbl, el, fn)
  if not fn then
    fn = (function(a,b) return a == b end)
  end
  local startIncl = 1
  local endExcl = #tbl + 1
  while startIncl < endExcl do
    local half = startIncl + math.floor((endExcl - startIncl)/2)
    local item = tbl[half]
    if fn(item, el) then
      return half
    elseif item < el then
      startIncl = half+1
    else
      endExcl = half
    end
  end
  return nil
end

function stateMachine:updateSpecificCanName(infoFn)
  local itemCanNames = self.itemCanNames
  local itemCanNameToInfo = self.itemCanNameToInfo
  local canNamesToAdd = {}

  local info = af.read(infoFn)
  assert(info.name)

  local prefix = info.name .. ":"
  local findIdx = sortedTableContains(itemCanNames, prefix, startsWith)
  if findIdx then
    local s = findIdx
    local e = findIdx+1
    while s > 1 do
      if not startsWith(itemCanNames[s-1], prefix) then
        break
      else
        itemCanNameToInfo[itemCanNames[s-1]] = nil
      end
      s = s - 1
    end
    local icnLen = #itemCanNames
    while e < icnLen do
      if startsWith(itemCanNames[e], prefix) then
        itemCanNameToInfo[itemCanNames[e]] = nil
      else
        break
      end
      e = e + 1
    end
  end
  for _, name in ipairs(fs.list("db/items/" .. info.name)) do
    local damageInfo = {
      name = info.name,
      stackSize = info.stackSize,
      hasNBT = info.hasNBT
    }
    local fullName = "db/items/" .. info.name .. "/" .. name
    local afName = string.sub(fullName, 1, -5)
    local fileInfo = af.read(afName)
    if info.damageDiffers then
      damageInfo.stackSize = fileInfo.info.stackSize
      damageInfo.hasNBT = fileInfo.info.hasNBT
    end
    damageInfo.damage = fileInfo.info.damage
    damageInfo.cInfo = fileInfo
    if damageInfo.hasNBT then
      for _, ci in ipairs(fileInfo.chests) do
        if ci.count ~= 0 then
          local customInfo = mp.clone(damageInfo)
          customInfo.customName = ci.customName
          customInfo.ci = ci
          customInfo.count = 1
          assert(ci.customName)
          local canName = customInfo.name .. ":" .. customInfo.damage .. ":" .. customInfo.customName
          if not sortedTableContains(itemCanNames, canName) then
            canNamesToAdd[#canNamesToAdd + 1] = canName
          end
          itemCanNameToInfo[canName] = customInfo
        end
      end
    else
      local count = 0
      for _, ci in ipairs(fileInfo.chests) do
        count = count + ci.count
      end
      damageInfo.count = count
      local canName = damageInfo.name .. ":" .. damageInfo.damage .. ":"
      if not sortedTableContains(itemCanNames, canName) then
        canNamesToAdd[#canNamesToAdd + 1] = canName
      end
      itemCanNameToInfo[canName] = damageInfo
    end
  end
  
  local i = #itemCanNames + 1
  for _, val in ipairs(canNamesToAdd) do
    itemCanNames[i] = val
    i = i + 1
  end
  table.sort(itemCanNames)
end

function stateMachine:updateCanNames()
  sleep(0)
  --print("calling...")
  local itemCanNames, itemCanNameToInfo = canNameList()
  --print("finished call")
  sleep(0)
  self.itemCanNames = itemCanNames
  self.itemCanNameToInfo = itemCanNameToInfo
end

function stateMachine:s_startPos_queryItem(ev, key, ...)
  local v = self.v_startPos.v_queryItem
  if ev == "start" then
    self.currState = self.s_startPos_queryItem
    v.searchStr = "minecraft:"
    clear()
    local the_err = (self.err or "")
    print(the_err)
    self.err = nil
    print("search: " .. v.searchStr)
  elseif ev == "key" and key == keys.enter then
    --do the search

    --okay, I just came up with this "canonical name"
    --minecraftid:damage:customname
    local itemCanNames = self.itemCanNames
    local itemCanNameToInfo = self.itemCanNameToInfo
    local results = {}
    local startIncl = 1
    local icnLen = #itemCanNames
    local endExcl = icnLen + 1
    while startIncl ~= endExcl do
      local halfwayIdx = startIncl + math.floor((endExcl-startIncl)/2)
      --print("searching between "..startIncl.." and "..endExcl.." at "..halfwayIdx)
      local item = itemCanNames[halfwayIdx]
      if starts_with(item, v.searchStr) then
        --we found it! search back and forth
        --print("found it, "..item)
        if itemCanNameToInfo[item] then results[#results + 1] = item end
        local idx = halfwayIdx -1
        while true do
          --print("loop1 idx", idx)
          if idx < 1 then break end
          local item = itemCanNames[idx]
          if starts_with(item, v.searchStr) then
            if itemCanNameToInfo[item] then results[#results + 1] = item end
          else
            break
          end
          idx = idx - 1
        end
        local idx = halfwayIdx + 1
        while true do
          --print("loop2 idx", idx)
          if idx > icnLen then break end
          local item = itemCanNames[idx]
          if starts_with(item, v.searchStr) then
            if itemCanNameToInfo[item] then results[#results + 1] = item end
          else
            break
          end
          idx = idx + 1
        end
        break
      elseif startIncl + 1 == endExcl then
        break
      elseif v.searchStr < item then
        endExcl = halfwayIdx
      else
        startIncl = halfwayIdx
      end
    end
    --for _, canName in ipairs(itemCanNames) do
    --  if starts_with(canName, v.searchStr) then
    --    results[#results + 1] = canName
    --  end
    --end
    self.searchResults = results
    print("found "..#results.." results")
    if #results == 0 then
      self.err = "No items found for " .. v.searchStr
      self:s_startPos_queryItem("start")
    elseif #results == 1 then
      self:s_startPos_queryQuantity("start")
    else
      self:s_startPos_itemList("start")
    end
  elseif ev == "key" and key == keys.backspace then
    v.searchStr = string.sub(v.searchStr, 1, -2)
    clear()
    print()
    print("search: " .. v.searchStr)
  elseif ev == "char" then
    v.searchStr = v.searchStr .. key
    clear()
    print()
    print("search: " .. v.searchStr)
  else
    self:s_startPos(ev, key, ...)
  end
end

function stateMachine:drawItemList(selIdx)
  local _, height = term.getSize()
  local middle = math.floor(height/2)
  for lineNum=1,height do
    local relNum = lineNum - middle
    local idx = selIdx - relNum
    if idx < 1 or idx > #self.searchResults then
      print()
    else
      print(bool2str(idx == selIdx, ">", " ") .. self.searchResults[idx] .. "-" .. self.itemCanNameToInfo[self.searchResults[idx]].count)
    end
  end
end

function stateMachine:s_startPos_itemList(ev, key, ...)
  local v = self.v_startPos.v_itemList
  if ev == "start" then
    assert(#self.searchResults >= 2)
    self.currState = self.s_startPos_itemList
    v.selIdx = 1
    self:drawItemList(v.selIdx)
  elseif ev == "key" and key == keys.up then
    if v.selIdx > 1 then
      v.selIdx = v.selIdx - 1
    end
    self:drawItemList(v.selIdx)
  elseif ev == "key" and key == keys.down then
    if v.selIdx < #self.searchResults then
      v.selIdx = v.selIdx + 1
    end
    self:drawItemList(v.selIdx)
  elseif ev == "key" and (key == keys.enter or key == keys.space) then
    self.searchResults = {self.searchResults[v.selIdx]}
    self:s_startPos_queryQuantity("start")
  else
    self:s_startPos(ev, key, ...)
  end
end

function stateMachine:displayQuantity(v)
  clear()
  print(v.info.name .. " d" .. v.info.damage)
  print("stack: " .. v.stackSize)
  --if v.stackSize > 1 and v.info.count > v.stackSize then
  --  local
  --  print("have: " .. v.info.count .. " / "
  print("have: " .. v.info.count)
  print("qty: " .. v.selectedQuantity)
  print("chests allocated: " .. #v.info.cInfo.chests)
end

function stateMachine:s_startPos_queryQuantity(ev, key, ...)
  local v = self.v_startPos.v_queryQuantity
  if ev == "start" then
    assert(#self.searchResults == 1)
    self.currState = self.s_startPos_queryQuantity
    v.selectedQuantity = 0
    v.canName = self.searchResults[1]
    --print(inspect(self.itemCanNameToInfo))
    --for k,v in pairs(self.itemCanNameToInfo) do
    --  print(k)
    --end
    --print(v.canName)
    assert(self.itemCanNameToInfo[v.canName])
    v.info = self.itemCanNameToInfo[v.canName]
    v.cInfo = v.info.cInfo
    v.stackSize = v.info.stackSize
    --print(inspect(v))
    assert(v.info.stackSize)
    self:displayQuantity(v)
  elseif ev == "key" and (key == keys.space or key == keys.enter) then
    if v.selectedQuantity > 0 then
      self:withdraw(v.selectedQuantity, v)
    end
    self:s_startPos_waiting("start")
  elseif ev == "key" and (key == keys.up or key == keys.right or key == keys.equals) then
    v.selectedQuantity = v.selectedQuantity + 1
    self:displayQuantity(v)
  elseif ev == "key" and (key == keys.down or key == keys.left or key == keys.minus) then
    if v.selectedQuantity >= 1 then
      v.selectedQuantity = v.selectedQuantity - 1
    end
    self:displayQuantity(v)
  elseif ev == "key" and key == keys.s then
    v.selectedQuantity = v.selectedQuantity * v.stackSize
    self:displayQuantity(v)
  elseif ev == "key" and isNumeralKeyCode(key) then
    local char = getCharFromNumeralKeyCode(key)
    v.selectedQuantity = tonumber(v.selectedQuantity .. char)
    self:displayQuantity(v)
  elseif ev == "key" and key == keys.backspace then
    v.selectedQuantity = tonumber(string.sub(v.selectedQuantity.."",1,-2)) or 0
    self:displayQuantity(v)
  else
    self:s_startPos(ev, key, ...)
  end
end

function stateMachine:checkInv()
  local res = {}
  local haveEverySlotInfo = true
  for slot=1,16 do
    res[slot] = {haveAllInfo = false}
    local deets = turtle.getItemDetail(slot)
    if deets then
      --print("checking item "..slot)
      --print("deets are")
      --print(deets)
      local itemInfoFn  = "db/items/" .. deets.name .. ".i"
      local itemCInfoFn = "db/items/" .. deets.name .. "/" .. deets.damage .. ".c"
      if af.exists(itemInfoFn) then
        local itemInfo = af.read(itemInfoFn)
        res[slot] = itemInfo
        if itemInfo.damageDiffers then
          if not af.exists(itemCInfoFn) then
            res[slot].haveAllInfo = false
          else
            local itemCInfo = af.read(itemCInfoFn)
            res[slot] = itemCInfo.info
            if res[slot].hasNBT then
              res[slot].haveAllInfo = not not self.slotNames[slot]
            else
              res[slot].haveAllInfo = true
            end
          end
        else
          if not af.exists(itemCInfoFn) then
            af.write(itemCInfoFn, {
              info = {
                name = itemInfo.name,
                damage = deets.damage,
                stackSize = itemInfo.stackSize,
                hasNBT = itemInfo.hasNBT
              },
              chests = {}
            })
            self:updateSpecificCanName(itemInfoFn)
          end
          if itemInfo.hasNBT then
            res[slot].haveAllInfo = not not self.slotNames[slot]
          else
            res[slot].haveAllInfo = true
          end
        end
      end
      res[slot].empty = (deets.count == 0)
      res[slot].name = deets.name
      res[slot].damage = deets.damage
      --print("haveallinfo: " .. bool2str(res[slot].haveAllInfo))
    else
      res[slot].empty = true
    end
    haveEverySlotInfo = haveEverySlotInfo and ( res[slot].empty or res[slot].haveAllInfo )
  end
  --print("haveevery: "..bool2str(haveEverySlotInfo))
  return haveEverySlotInfo, res
end
        
local function chestDig()
  local suc, bi = turtle.inspect()
  if suc and bi.name == "minecraft:chest" then
    --do nothing
  else
    while turtle.dig() do end
    local deets = turtle.getItemDetail()
    if (not deets) or deets.name ~= "minecraft:chest" then
      local found = false
      for i=1,16 do
        local deets = turtle.getItemDetail(i)
        if deets and deets.name == "minecraft:chest" then
          turtle.select(i)
          found = true
          break
        end
      end
      if not found then
        error("ran out of chests!")
      end
    end
    turtle.place()
  end
end

local function writeChests(forwards, rights, downs, startingPos)
  local emptyChests = {}
  for f=0,forwards do
    for r=0,rights do
      if math.fmod(f+r, 2) == 0 then --checkerboard pattern of chests
        for d=1,downs do
          local x,y,z
          if startingPos.facing == 0 then
            z = -f
            x =  r
          elseif startingPos.facing == 1 then
            z = r
            x = f
          elseif startingPos.facing == 2 then
            z = f
            x = -r
          elseif startingPos.facing == 3 then
            z = -r
            x = f
          end
          y = -d
          local chestLocation = {x = x, y = y, z = z}
          locationAddInto(chestLocation, startingPos)
          local chestInfo = {count = 0, location = chestLocation}
          local chestFn = "db/chests/"..chestLocation.x..","..chestLocation.y..","..chestLocation.z
          if not af.exists(chestFn) then
            af.write("db/chests/"..chestLocation.x..","..chestLocation.y..","..chestLocation.z, chestInfo)
            table.insert(emptyChests, chestInfo)
          end
        end
      end
    end
  end

  af.write("db/empty_chests", emptyChests)
  return emptyChests
end




local tArgs = { ... }

if #tArgs == 0 then
   print("Usage:")
   print("  chester startup")
   print("  chester init <forwards> <rights> <downs>")
   return
end

if tArgs[1] == "init" then
  if not tArgs[4] then
    print("3 arguments required for 'init' (4 total)")
    return
  end
  local forwards = tonumber(tArgs[2])
  local rights = tonumber(tArgs[3])
  local downs = tonumber(tArgs[4])
  if not (forwards and rights and downs) then
    print("all arguments must be numbers")
    return
  end

  --local startX, startY, startZ = gps.locate(5, true)
  print("attempting to determine global offset")
  if not getGlobalOffset(nil, 5, true) then
    print("could not get gps coordinates")
    return
  end

  local startingPos = globalPosition()

  fs.makeDir("db")
  fs.makeDir("db/items")
  fs.makeDir("db/chests")

  writeChests(forwards, rights, downs, startingPos)
  if not af.exists("db/wal") then
    af.write("db/wal", {empty = true})
  end

  local params = {
    startingPos = startingPos,
    forwards = forwards,
    rights = rights,
    downs = downs
  }
  af.write("db/params", params)
  print("Init finished.")
  return
elseif tArgs[1] == "audit" then -- !!! WARNING !!! destructive command
  local params = af.read("db/params")
  local oldAuditNumber = params.auditNumber or 0
  local newAuditNumber = oldAuditNumber + 1
  for _,fn1 in ipairs(fs.list("db/items")) do
    local fullFn = "db/items/" .. fn1
    if fs.isDir(fullFn) then
      for _,fn2 in ipairs(fs.list(fullFn)) do
        local fullFn = "db/items/" .. fn1 .. "/" .. fn2
        local afName = string.sub(fullFn,1,-5)
        local itemCInfo = af.read(afName)
        itemCInfo.chests = {}
        af.write(afName, itemCInfo)
      end
    end
  end

  params.auditNumber = newAuditNumber
  params.doAudit = true
  af.write("db/params", params)
  return
elseif tArgs[1] == "expand" then
  if not tArgs[4] then
    print("3 arguments required for 'expand' (4 total)")
    return
  end
  local forwards = tonumber(tArgs[2])
  local rights = tonumber(tArgs[3])
  local downs = tonumber(tArgs[4])
  if not (forwards and rights and downs) then
    print("all arguments must be numbers")
    return
  end
  local params = af.read("db/params")
  if forwards < params.forwards or rights < params.rights or downs < params.downs then
    print("size must be same or larger in all directions")
    return
  end
  local startingPos = params.startingPos
  getGlobalOffset()
  for f=0,forwards do
    for r=0,rights do
      if math.fmod(f+r, 2) == 1 then --all the empty spaces between chests
        local x
        local y
        local z
        if startingPos.facing == 0 then
          z = -f
          x =  r
        elseif startingPos.facing == 1 then
          z = r
          x = f
        elseif startingPos.facing == 2 then
          z = f
          x = -r
        elseif startingPos.facing == 3 then
          z = -r
          x = f
        end
        local destLocation = {x = x, y = 0, z = z, facing = params.startingPos.facing}
        locationAddInto(destLocation, startingPos)
        moveTo(destLocation)
        for d=1,downs do
          while turtle.digDown() do end
          down()
          -- right now we're facing "forward", relative to starting position
          if f < forwards then
            chestDig()
          end
          turnRight()
          if r < rights then
            chestDig()
          end
          turnRight()
          if f > 0 then
            chestDig()
          end
          turnRight()
          if r > 0 then
            chestDig()
          end
          turnRight()
        end
        while globalPosition().y < startingPos.y do
          up()
        end
      end
    end
  end
  params.forwards = forwards
  params.rights = rights
  params.downs = downs
  writeChests(params.forwards, params.rights, params.downs, params.startingPos)
  af.write("db/params", params)
  moveTo(startingPos)
  return
elseif tArgs[1] ~= "startup" and tArgs[1] ~= "s" then
  print("Unknown subcommand "..(tArgs[1] or ""))
  return
end

-- tArgs[1] == "startup"

params = af.read("db/params")

walRecover(true)

-- todo: return to spot maybe

local _, yPos, _ = gps.locate(10)
if not yPos then
  die("cant gps")
end

while yPos + Location.y < params.startingPos.y do
  up()
end

getGlobalOffset()

moveTo(params.startingPos)

stateMachine:updateCanNames()
if params.doAudit then
  --precondition for audit: Must clear chest assignments in db/items/*/*.c
  assert(params.auditNumber)
  assert(turtle.getItemCount() == 0)
  local auditNumber = params.auditNumber
  local emptys = af.read("db/empty_chests")
  local newEmptys = {}
  for _,cInfo in ipairs(emptys) do
    if cInfo.audit == nil or cInfo.audit < auditNumber then
      moveTo(chestAccessLocation(cInfo.location))
      local suc, data = turtle.inspect()
      assert(suc and data.name == "minecraft:chest")
      local suc, err = turtle.suck()
      if suc then
        --fail! This chest is not empty
        turtle.drop() --put back what we just took out
        --don't add it to newEmptys
      elseif not suc and err == "No items to take" then
        --good, chest is empty as expected
        local newChestInfo = {
          audit = auditNumber,
          count = 0,
          location = cInfo.location
        }

        af.write("db/chests/" .. cInfo.location.x .. "," .. cInfo.location.y .. "," .. cInfo.location.z, newChestInfo)
        newEmptys[#newEmptys + 1] = newChestInfo
      else
        --other error we didn't expect
        print(err)
        assert(false)
      end
    else
      newEmptys[#newEmptys + 1] = cInfo
    end
  end

  af.write("db/empty_chests", newEmptys)
  emptys = newEmptys
  if #emptys == 0 then
    error("No empty chests available")
  end
  local chestFns = fs.list("db/chests")
  local chestFnsLen = #chestFns
  for i,fn in ipairs(chestFns) do
    print(i .. "/" .. chestFnsLen)
    local afn = "db/chests/" .. string.sub(fn,1,-5) --remove the ".old" or ".new" at the end
    local cInfo = af.read(afn)
    if cInfo.audit == nil or cInfo.audit < auditNumber then
      local chestEmpty = false
      local accLocation = chestAccessLocation(cInfo.location)
      while not chestEmpty do
        moveTo(accLocation)
        while true do
          local suc, err = turtle.suck()
          if suc then
            --do nothing
          elseif not suc and err == "No space for items" then
            break
          elseif not suc and err == "No items to take" then
            chestEmpty = true
            break
          else
            print(err)
            assert(false)
          end
        end
        for i=1,16 do
          turtle.select(i)
          if turtle.getItemCount() ~= 0 then
            local turtleInfo = turtle.getItemDetail()
            local itemFn = "db/items/" .. turtleInfo.name .. ".i"
            local damageFn = "db/items/" .. turtleInfo.name .. "/" .. turtleInfo.damage .. ".c"
            local itemInfo   = af.exist(itemFn)   and af.read(itemFn)
            local damageInfo = af.exist(damageFn) and af.read(damageFn)
            --print(inspect(itemInfo))
            --print(inspect(damageInfo))
            local keepItem = itemInfo and damageInfo and (not itemInfo.hasNBT) and (not damageInfo.hasNBT)
            if not keepItem then
              local disposalChestLocation = {
                x = params.startingPos.x,
                y = params.startingPos.y,
                z = params.startingPos.z,
                facing = facingPlus(params.startingPos.facing, 3)
              }
              moveTo(disposalChestLocation)
              while true do --drop all items in this slot
                local suc, err = turtle.drop()
                if suc then
                  --do nothing, keep going
                elseif err == "No items to drop" then
                  break
                else 
                  error(err)
                end
              end
            end
          end
        end
        forEveryDeposit(false)
      end
      -- chest is now definitely empty
      local newChestInfo = {
        audit = auditNumber,
        count = 0,
        location = cInfo.location
      }
      af.write("db/chests/" .. cInfo.location.x .. "," .. cInfo.location.y .. "," .. cInfo.location.z, newChestInfo)
      local emptys = af.read("db/empty_chests")
      emptys[#emptys + 1] = newChestInfo
      af.write("db/empty_chests", emptys)
    end
  end
  print("AUDIT FINISHED!")
  params.doAudit = false
  af.write("db/params", params)
  return
end

stateMachine:s_startPos_waiting("start")
while true do
  local ev, r1, r2, r3, r4, r5 = os.pullEvent()

  stateMachine:currState(ev, r1, r2, r3, r4, r5)
end
