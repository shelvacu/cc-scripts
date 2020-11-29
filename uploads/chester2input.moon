require("paranoidLogger")("chester2input")
common = require("chestercommon")

my_id = 55

input_thread = (db) ->
  print("input thread running")
  while true
    os.sleep(5)
    names = db\query("select name from chest where computer = $1 and ty = 'input';", {ty: "int4", val: my_id})
    for _,row in ipairs(names)
      name = row[1].val
      paraLog.log("iter on chest",{:name})
      p = peripheral.wrap(name)
      if not p
        print("WARN: chest disappeared " .. name)
        continue
      items = p.list() --does *not* return a sequence
      paraLog("item list count",#items)
      for from_slot,v in pairs(items)
        --meta = p.getItemMeta(from_slot)
        meta = paraLog.loggedCall("get details", name, "getItemMeta", from_slot)
        --print(meta.name .. " x" .. meta.count .. " " .. from_slot)
        item_id = common.insertOrGetId(db, meta)
        remaining = meta.count
        while remaining > 0
          paraLog.log("remaining",remaining)
          db\query("start transaction")
          local res
          if remaining < meta.maxCount
            paraLog.log("move substack")
            res = db\query(
              "select chest_name, slot, count from stack where (item_id = $1 or item_id is null) and count < $2 and chest_computer = $3 order by count desc limit 1 for no key update ;"
              {ty: "int4", val: item_id},
              {ty: "int4", val: meta.maxCount},
              {ty: "int4", val: my_id}
            )
          else --full stack, move it all at once
            paraLog.log("move full stack")
            res = db\query(
              "select chest_name, slot, count from stack where item_id is null and count = 0 and chest_computer = $1 order by count desc limit 1 for no key update"
              {ty: "int4", val: my_id}
            )

          if #res == 0
            paraLog.die("no space available!")
          elseif #res ~= 1
            paraLog.die("expected exactly 1 result",res)
          row = res[1]
          chest_name = row[1].val
          to_slot = row[2].val
          count = row[3].val
          quantity = math.min(remaining, meta.maxCount - count)
          paraLog.log("updating stack",{:row, :chest_name, :to_slot, :count, :quantity})
          db\query(
            "update stack set count = $1, item_id = $2 where chest_computer = $3 and chest_name = $4 and slot = $5",
            {ty: "int4", val: count + quantity},
            {ty: "int4", val: item_id},
            {ty: "int4", val: my_id},
            {ty: "text", val: chest_name},
            {ty: "int2", val: to_slot}
          )
          --transferred = p.pushItems(chest_name, from_slot, quantity, to_slot)
          transferred = paraLog.loggedCall("do the input", name, "pushItems", chest_name, from_slot, quantity, to_slot)
          if quantity ~= transferred
            db\query("rollback")
            paraLog.die("Transfer failed! Expected "..quantity.." items pushed, instead "..transferred.." were pushed. Item#"..item_id..", from "..from_slot.." to " .. chest_name .. ":" .. to_slot .. ". Rescan needed.")
          remaining = remaining - quantity
          db\query("commit")
common.with_db(input_thread)()