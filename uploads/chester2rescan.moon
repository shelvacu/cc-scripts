require("paranoidLogger")("chester2rescan")
db = require("db")\default!
--mp = require("mp")

local wired_modem

print "find wired modem"
for _,mod in ipairs {peripheral.find "modem"}
  if not mod.isWireless!
    wired_modem = mod
if not wired_modem
  error"Could not find any wired modem"

my_id = 55

tArgs = {...}

process = ->
  db\process!

main = ->
  doFix = tArgs[1] == "fix" or tArgs[1] == "quickfix"
  doQuick = tArgs[1] == "quick" or tArgs[1] == "quickfix"
  chests = nil
  db\query("start transaction")
  db\query("LOCK chest")
  db\query("LOCK stack")
  if tArgs[2] == nil
    chests = db\query("select name, ty from chest where computer = $1;", {ty: "int4", val: my_id})
  elseif tArgs[2] == "cake"
    chests = db\query("select name, ty from chest where computer = $1 and name in (select chest_name from stack where item_id in (15429, 15674, 10764, 4128, 21405, 4110) group by chest_name)", {ty: "int4", val: my_id})
  else
    chests = {table.unpack(tArgs, 2, #tArgs)}
  --print(textutils.serialise(tArgs))
  --print(textutils.serialise(chests))
  for i,row in ipairs chests
    print("chest " .. i .. " of " .. #chests)
    name = nil
    chest_ty = nil
    if type(row) == "string"
      name = row
      chest_ty = "storage"
    else
      name = row[1].val
      chest_ty = row[2].val
    --print("called "..name)
    paraLog.log("scanning chest",{:name, :chest_ty})
    stacks = db\query(
      "select stack.slot, stack.count, item.name, item.damage, item.nbtHash from stack left join item on stack.item_id = item.id where stack.chest_computer = $1 and stack.chest_name = $2",
      {ty: "int4", val: my_id},
      {ty: "text", val: name}
    )
    --print("has "..#stacks.." stacks")
    quickList = peripheral.call(name, "list")
    for _,row in ipairs stacks
      if chest_ty ~= 'storage' -- and has more than 0 stacks
        print(name .. " is ty " .. chest_ty .. " but has stacks associated!")
        break
      slot = row[1].val
      dbCount = row[2].val
      item_name = row[3].val
      item_damage = row[4].val
      item_nbtHash = row[5].val

      local meta
      local chest_nbtHash
      local chestCount
      meta = quickList[slot]
      if meta == nil
        chestCount = 0
        chest_nbtHash = ""
      elseif not doQuick
        meta = peripheral.call(name, "getItemMeta", slot)
        chest_nbtHash = ""
        if not meta
          chestCount = 0
        else
          chestCount = meta.count
          if meta.nbtHash
            chest_nbtHash = meta.nbtHash
      else
        chestCount = meta.count

      needsFix = false
      if dbCount != chestCount
        print(name.." count mismatch! " .. dbCount .. " vs " .. chestCount)
        needsFix = true
      elseif chestCount != 0
        if not (meta.name == item_name and meta.damage == item_damage and (doQuick or chest_nbtHash == item_nbtHash))
          ms = (s) ->
            if not s
              "nil"
            else
              s
          print(name .. " meta mismatch "..ms(meta.name)..":"..ms(item_name).." "..ms(meta.damage)..":"..ms(item_damage).." "..ms(meta.nbtHash)..":"..ms(item_nbtHash))
          needsFix = true
      
      if needsFix and doFix
        if doQuick
          meta = peripheral.call(name, "getItemMeta", slot)
        if meta
          print textutils.serialise meta
          if meta.effects
            --print "setting meta.effects metatable"
            setmetatable(meta.effects, {isSequence: true})
          if meta.enchantments
            setmetatable(meta.enchantments, {isSequence: true})
          res = db\query(
            "insert into item (name, damage, maxDamage, rawName, nbtHash, fullMeta) values ($1, $2, $3, $4, $5, $6) on conflict (name, damage, nbtHash) do nothing returning id",
            {ty: "text", val: meta.name},
            {ty: "int" , val: meta.damage},
            {ty: "int" , val: meta.maxDamage},
            {ty: "text", val: meta.rawName},
            {ty: "text", val: (meta.nbtHash or "")},
            {ty: "jsonb", val: meta}
          )
          --print textutils.serialise(res)
          local item_id
          if #res > 0
            item_id = res[1][1].val
          else
            res = db\query(
              "select id from item where name = $1 and damage = $2 and nbtHash = $3",
              {ty: "text", val: meta.name},
              {ty: "int" , val: meta.damage},
              {ty: "text", val: (meta.nbtHash or "")}
            )
            if #res ~= 1
              error"expected 1 result"
            item_id = res[1][1].val
          db\query(
            "update stack set count = $1, item_id = $2 where chest_computer = $3 and chest_name = $4 and slot = $5",
            {ty: "int4", val: chestCount},
            {ty: "int4", val: item_id},
            {ty: "int4", val: my_id},
            {ty: "text", val: name},
            {ty: "int2", val: slot}
          )
        else
          db\query(
            "update stack set count = 0, item_id = NULL where chest_computer = $1 and chest_name = $2 and slot = $3",
            {ty: "int4", val: my_id},
            {ty: "text", val: name},
            {ty: "int2", val: slot}
          )
  db\query("commit")

        

parallel.waitForAny(process, main)
