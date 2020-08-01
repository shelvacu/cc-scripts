db = require("db")\default!
mp = require("mp")

array = (...) -> mp.configWrapper(setmetatable({...}, {isSequence: true}), {recode: true, convertNull: true})

local wired_modem

print "find wired modem"
for _,mod in ipairs {peripheral.find "modem"}
  if not mod.isWireless!
    wired_modem = mod
if not wired_modem
  error"Could not find any wired modem"

my_id = os.getComputerID!

tArgs = {...}

process = ->
  db\process!

main = ->
  chests = db\query("select name, ty from chest where computer = $1;", array({ty: "int4", val: my_id}))
  for i,row in ipairs chests
    print("chest " .. i .. " of " .. #chests)
    name = row[1].val
    chest_ty = row[2].val
    stacks = db\query(
      "select stack.slot, stack.count, item.name, item.damage, item.nbtHash from stack left join item on stack.item_id = item.id where stack.chest_computer = $1 and stack.chest_name = $2",
      array(
        {ty: "int4", val: my_id},
        {ty: "text", val: name}
      )
    )
    for _,row in ipairs stacks
      if chest_ty ~= 'storage' -- and has more than 0 stacks
        print(name .. " is ty " .. chest_ty .. " but has stacks associated!")
        break
      slot = row[1].val
      dbCount = row[2].val
      item_name = row[3].val
      item_damage = row[4].val
      item_nbtHash = row[5].val

      meta = peripheral.call(name, "getItemMeta", slot)
      local chestCount
      chest_nbtHash = ""
      if not meta
        chestCount = 0
      else
        chestCount = meta.count
        if meta.nbtHash
          chest_nbtHash = meta.nbtHash

      needsFix = false
      if dbCount != chestCount
        print(name.." count mismatch! " .. dbCount .. " vs " .. chestCount)
        needsFix = true
      elseif chestCount != 0
        if not (meta.name == item_name and meta.damage == item_damage and chest_nbtHash == item_nbtHash)
          ms = (s) ->
            if not s
              "nil"
            else
              s
          print(name .. " meta mismatch "..ms(meta.name)..":"..ms(item_name).." "..ms(meta.damage)..":"..ms(item_damage).." "..ms(meta.nbtHash)..":"..ms(item_nbtHash))
          needsFix = true
      
      if needsFix and tArgs[1] == "fix"
        if meta
          res = db\query(
            "insert into item (name, damage, maxDamage, rawName, nbtHash, fullMeta) values ($1, $2, $3, $4, $5, $6) on conflict (name, damage, nbtHash) do nothing returning id",
            array(
              {ty: "text", val: meta.name},
              {ty: "int" , val: meta.damage},
              {ty: "int" , val: meta.maxDamage},
              {ty: "text", val: meta.rawName},
              {ty: "text", val: (meta.nbtHash or "")},
              {ty: "jsonb", val: meta}
            )
          )
          --print textutils.serialise(res)
          local item_id
          if #res > 0
            item_id = res[1][1].val
          else
            res = db\query(
              "select id from item where name = $1 and damage = $2 and nbtHash = $3",
              array(
                {ty: "text", val: meta.name},
                {ty: "int" , val: meta.damage},
                {ty: "text", val: (meta.nbtHash or "")}
              )
            )
            if #res ~= 1
              error"expected 1 result"
            item_id = res[1][1].val
          db\query(
            "update stack set count = $1, item_id = $2 where chest_computer = $3 and chest_name = $4 and slot = $5",
            array(
              {ty: "int4", val: chestCount},
              {ty: "int4", val: item_id},
              {ty: "int4", val: my_id},
              {ty: "text", val: name},
              {ty: "int2", val: slot}
            )
          )
        else
          db\query(
            "update stack set count = 0, item_id = NULL where chest_computer = $1 and chest_name = $2 and slot = $3",
            array(
              {ty: "int4", val: my_id},
              {ty: "text", val: name},
              {ty: "int2", val: slot}
            )
          )

        

parallel.waitForAny(process, main)