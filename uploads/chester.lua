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
-- /chests/5,-1,4 - {count: int, location: {x,y,z}, name: id|nil, damage: int|nil, customName: string|nil}. If the chest doesn't exist, no file should exist. Coordinates relative, and can be negative. Same ordering as minecraft, and so y should always be negative
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

--[[
local debug = dofile"cooldebug.lua"
debug.override()
--]]

require "shellib"
Settings.ensureFuel = true
local af = require "atomicFile"

local stateMachine = {
  v_startPos = {
    v_itemInfo = {}
  },
  v_forEvery = {},
  slotNames = {}
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

-- this code just pretends back() doesn't exist, lol
local function moveTo(spot, verticalFirst)
  if verticalFirst then
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

  if not verticalFirst then
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
  end
  turnToFace(spot.facing)
end

local function walRecover()
  local wal = af.read("db/wal")
  if not wal.empty then
    local chestFn = "db/chests/"..wal.location.x..","..wal.location.y..","..wal.location.z
    local itemCFn = "db/items/"..wal.name.."/"..wal.damage..".c"
    if wal.type == "deposit" then
      if turtle.getItemCount(wal.slot) > 0 then
        turtle.select(wal.slot)
        turtle.drop(wal.count)
      end
      local chestInfo
      if af.exists(chestFn) then
        chestInfo = af.read(chestFn)
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
      for i, ci in ipairs(itemCInfo.chests) do
        if
          locationEq(ci.location, wal.location) and
          ci.count == wal.chestCountBefore
        then
          ci.count = ci.count + wal.count
          modified = true
        end
      end
      if modified then
        af.write(itemCFn, itemCInfo)
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
      if turtle.getItemCount(wal.slot) == 0 then
        turtle.select(wal.slot)
        turtle.suck(wal.count)
      end
      local chestInfo = af.read(chestFn)
      if chestInfo.count == wal.chestCountBefore then
        chestInfo.count = chestInfo.count - wal.count
        if wal.chestCountBefore == wal.count then --this is a deallocation
          chestInfo.name = nil
          chestInfo.damage = nil
          chestInfo.customName = nil
        end
        af.write(chestFn, chestInfo)
      end
      local itemCInfo = af.read(itemCFn)
      local modified = false
      for i, ci in ipairs(itemCInfo.chests) do
        if
          locationEq(ci.location, wal.location) and
          ci.count == wal.chestCountBefore
        then
          ci.count = ci.count - wal.count
          modified = true
        end
      end
      if modified then
        af.write(itemCFn, itemCInfo)
      end
      if wal.chestCountBefore == wal.count then --this is a deallocation
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

local function isNumeralKeyCode(key)
  return false or
    key == keys.zero or
    key == keys.one or
    key == keys.two or
    key == keys.three or
    key == keys.four or
    key == keys.five or
    key == keys.six or
    key == keys.seven or
    key == keys.eight or
    key == keys.nine or
    key == keys.numPad0 or
    key == keys.numPad1 or
    key == keys.numPad2 or
    key == keys.numPad3 or
    key == keys.numPad4 or
    key == keys.numPad5 or
    key == keys.numPad6 or
    key == keys.numPad7 or
    key == keys.numPad8 or
    key == keys.numPad9
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
  elseif ev == "key" and key == keys.d then
    self:s_startPos_deposit("start")
  elseif ev == "key" and key == keys.w then
    die("not implemented")
    --self:s_startPos_queryItem("start")
  elseif ev == "turtle_inventory" then
    local haveEvery, itemInfos = self:checkInv()
    if not haveEvery then
      turnLeft()
      for idx, info in ipairs(itemInfos) do
        if info.empty or info.haveAllInfo then
          --no dothing
        else
          turtle.select(idx)
          turtle.drop()
        end
      end
    end
    if self.autoInvTimer then
      os.cancelTimer(self.autoInvTimer)
    end
    os.autoInvTimer = os.startTimer(2)
  elseif ev == "timer" and key == os.autoInvTimer then
    os.autoInvTimer = nil
    self:s_forEvery("start")
  else
    self:s_startPos(ev, key, ...)
  end
end

function stateMachine:s_forEvery(ev, key, ...)
  if ev == "start" then
    self.currState = self.s_forEvery
    --self.v_forEvery.idx = 1
    for slot=1,16 do
      local turtleItemInfo = turtle.getItemDetail(slot)
      if not turtleItemInfo then
        break
      end
      local itemInfo  = af.read("db/items/" .. turtleItemInfo.name .. ".i")
      local itemCInfo = af.read("db/items/" .. turtleItemInfo.name .. "/" .. turtleItemInfo.damage .. ".c")
      local chestIdx = nil
      local stackSize
      local hasNBT
      if itemInfo.damageDiffers then
        stackSize = itemCInfo.stackSize
        hasNBT = itemCInfo.hasNBT
      else
        stackSize = itemInfo.stackSize
        hasNBT = itemInfo.hasNBT
      end
      local maxCount = 9 * 3 * stackSize
      local customName = nil
      if hasNBT then
        customName = self.slotName[slot]
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
          error("no chests available!")
        end
        chestLocation = emptys[1].location
        chestCountBefore = 0
      end
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
      moveTo(destLocation, false)
      --oh my god, we did it
      --we're in front of the chest, ready.
      --about to deposit the master's glorious items.
      --stack of cobblestone #7,853 may you be deposited well
      --in today and in tommorow, forever organized
      --for our master
      --amen
      local wal = {
        type = "deposit",
        location = globalPosition(),
        name = turtleItemInfo.name,
        damage = turtleItemInfo.damage,
        slot = slot,
        chestCountBefore = chestCountBefore,
        customName = customName,
        empty = false
      }
      af.write("db/wal", wal)
      -- I don't know if this is genius or idiotic, but recovering from the wal is the same as performing some action normally, so...
      walRecover()
      while true do
        local glob = globalLocation()
        if glob.y == params.startingPos.y then
          break
        elseif glob.y > params.startingPos.y then
          down()
        elseif glob.y < params.startingPos.y then
          up()
        end
      end
    end
    moveTo(params.startingPos)
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
    self.mode = "deposit"
    return self:s_forEvery("start")
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
    local info = {
      name = slotsInfo[idx].name,
      damage = slotsInfo[idx].damage,
      customName = ""
    }
    assert(info.damage)
    info.stackSize = turtle.getItemCount(idx) + turtle.getItemSpace(idx)
    info.hasNBT = false
    info.damageDiffers = false
    info.damageInfo = {
      hasNBT = false,
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
      cInfo = af.read(itemFInfoFn)
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
    infoData.name = info.data
    infoData.stackSize = info.stackSize
    infoData.hasNBT = info.hasNBT
    infoData.damageDiffers = info.damageDiffers
    af.write(itemCInfoFn, cInfo)
    af.write(itemInfoFn, infoData)
    self:s_startPos_deposit("start")
  elseif ev == "char" and selIdx == customName(info) then
    info.customName = info.customName .. key
    clear()
    printItemInfo(info, selIdx)
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
      res[slot].empty = (deets.count == 0)
      res[slot].name = deets.name
      res[slot].damage = deets.damage
      if af.exists(itemInfoFn) then
        local itemInfo = af.read(itemInfoFn)
        res[slot] = itemInfo
        if itemInfo.damageDiffers then
          if not af.exists(itemCInfoFn) then
            res[slot].haveAllInfo = false
          else
            local itemCInfo = af.read(itemCInfoFn)
            res[slot] = itemCInfo
            if itemCInfo.hasNBT then
              res[slot].haveAllInfo = not not self.slotNames[slot]
            else
              res[slot].haveAllInfo = true
            end
          end
        else
          if itemInfo.hasNBT then
            res[slot].haveAllInfo = not not self.slotNames[slot]
          else
            res[slot].haveAllInfo = true
          end
        end
      end
      print("haveallinfo: " .. bool2str(res[slot].haveAllInfo))
    else
      res[slot].empty = true
    end
    haveEverySlotInfo = haveEverySlotInfo and ( res[slot].empty or res[slot].haveAllInfo )
  end
  print("haveevery: "..bool2str(haveEverySlotInfo))
  return haveEverySlotInfo, res
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

  local emptyChests = {}
  for f=0,forwards-1 do
    for r=0,rights-1 do
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
          local chestInfo = {count = 0, location = {x = x, y = y, z = z}}
          af.write("db/chests/"..x..","..y..","..z, chestInfo)
          --emptyChests[#emptyChests + 1] = chestInfo
          table.insert(emptyChests, chestInfo)
        end
      end
    end
  end

  af.write("db/empty_chests", emptyChests)
  af.write("db/wal", {empty = true})
  local params = {
    startingPos = startingPos,
    forwards = forwards,
    rights = rights,
    downs = downs
  }
  af.write("db/params", params)
  print("Init finished.")
  return
elseif tArgs[1] ~= "startup" then
  print("Unknown subcommand "..(tArgs[1] or ""))
  return
end

-- tArgs[1] == "startup"

params = af.read("db/params")

walRecover()

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

stateMachine:s_startPos_waiting("start")
while true do
  local ev, r1, r2, r3, r4, r5 = os.pullEvent()

  stateMachine:currState(ev, r1, r2, r3, r4, r5)
end
