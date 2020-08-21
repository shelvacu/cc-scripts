export os, turtle, pocket, peripheral, term, multishell
print "make connection"
db = require("db")\default!
mp = require "mp"
common = require "chestercommon"

wired_modem = nil

print "find wired modem"
for _,mod in ipairs {peripheral.find "modem"}
  if not mod.isWireless!
    wired_modem = mod
if not wired_modem
  error"Could not find any wired modem"

my_id = os.getComputerID!

golden = not not multishell

local ty

if turtle
  ty = "turtle"
elseif pocket
  ty = "pocket"
elseif select(2, term.getSize()) == 13 and golden
  ty = "neural"
else
  ty = "computer"

process = -> db\process!

output_thread = ->
  db\query("listen withdrawal_rescan")
  print("listening for withdrawal_rescan")
  while true
    evName, id, parsed = os.pullEvent("database_notification")
    continue if id ~= db.id
    continue if parsed.channel ~= "withdrawal_rescan"
    print("withdrawal rescan")
    withdrawals = db\query(
      "select id, item_id, output_chest, slot, count from withdrawal where computer = $1 and not finished",
      {ty: "int4", val: my_id}
    )
    print("found "..#withdrawals.." withdrawals")
    for _, row in ipairs(withdrawals)
      withdrawal_id = row[1].val
      item_id = row[2].val
      output_chest = row[3].val
      to_slot = row[4].val --maybe nil
      count = row[5].val
      remaining = count
      if type(to_slot) == "table"
        to_slot = nil
      while remaining > 0
        print(remaining .. " remaining")
        --find a suitable slot to withdraw from
        res = db\query(
          "select chest_name, slot, count from stack where item_id = $1 and chest_computer = $2 and count > 0 order by count asc limit 1",
          {ty: "int4", val: item_id},
          {ty: "int4", val: my_id}
        )
        if #res == 0
          print("ERR: no items to withdraw for req#"..withdrawal_id)
          remaining = 0
          break
        row = res[1]
        chest_name = row[1].val
        from_slot = row[2].val
        stack_count = row[3].val
        sc = peripheral.wrap(chest_name)
        print(textutils.serialise({output_chest, from_slot, remaining, to_slot}))
        pushed = sc.pushItems(output_chest, from_slot, remaining, to_slot)
        if pushed == 0
          error "Pushed 0 items in withdrawal process"
        remaining -= pushed
        stack_count -= pushed
        local new_item_id
        if stack_count == 0
          new_item_id = nil
        else
          new_item_id = item_id
        db\query(
          "update stack set count = $1, item_id = $2 where chest_computer = $3 and chest_name = $4 and slot = $5",
          {ty: "int4", val: stack_count},
          {ty: "int4", val: new_item_id},
          {ty: "int4", val: my_id},
          {ty: "text", val: chest_name},
          {ty: "int2", val: from_slot}
        )
      db\query(
        "update withdrawal set finished = true where id = $1",
        {ty: "int4", val: withdrawal_id}
      )


input_thread = ->
  while true
    os.sleep(5)
    names = db\query("select name from chest where computer = $1 and ty = 'input';", array({ty: "int4", val: my_id}))
    for _,row in ipairs(names)
      name = row[1].val
      p = peripheral.wrap(name)
      if not p
        print("WARN: chest disappeared " .. name)
        continue
      items = p.list() --does *not* return a sequence
      for from_slot,v in pairs(items)
        meta = p.getItemMeta(from_slot)
        print(meta.name .. " x" .. meta.count .. " " .. from_slot)
        item_id = common.insertOrGetId(db, meta)
        remaining = meta.count
        while remaining > 0
          db\query("start transaction")
          local res
          if remaining < meta.maxCount
            res = db\query(
              "select chest_name, slot, count from stack where (item_id = $1 or item_id is null) and count < $2 and chest_computer = $3 order by count desc limit 1;"
              {ty: "int4", val: item_id},
              {ty: "int4", val: meta.maxCount},
              {ty: "int4", val: my_id}
            )
          else --full stack, move it all at once
            res = db\query(
              "select chest_name, slot, count from stack where item_id is null and count = 0 and chest_computer = $1 order by count desc limit 1;"
              {ty: "int4", val: my_id}
            )

          if #res == 0
            error"no space available!"
          elseif #res ~= 1
            error"expected exactly 1 result"
          row = res[1]
          chest_name = row[1].val
          to_slot = row[2].val
          count = row[3].val
          quantity = math.min(remaining, meta.maxCount - count)
          db\query(
            "update stack set count = $1, item_id = $2 where chest_computer = $3 and chest_name = $4 and slot = $5",
            {ty: "int4", val: count + quantity},
            {ty: "int4", val: item_id},
            {ty: "int4", val: my_id},
            {ty: "text", val: chest_name},
            {ty: "int2", val: to_slot}
          )
          transferred = p.pushItems(chest_name, from_slot, quantity, to_slot)
          if quantity ~= transferred
            db\query("rollback")
            error("Transfer failed! Expected "..quantity.." items pushed, instead "..transferred.." were pushed. Item#"..item_id..", from "..from_slot.." to " .. chest_name .. ":" .. to_slot .. ". Rescan needed.")
          remaining = remaining - quantity
          db\query("commit")

main = ->
  print "about to query"
  res = db\query(
    "insert into computer (id, ty, is_golden) values ($1, $2, $3) on conflict (id) do update set ty = $2, is_golden = $3",
    {ty: "int4", val: my_id},
    {ty: "text", val: ty},
    {ty: "bool", val: golden}
  )
  print "res is "..textutils.serialise(res)
  connecteds = wired_modem.getNamesRemote()
  --chest_map = {} --maps name to ty
  --chest_ty_map = {input: {}, output: {}, storage: {}, unknown: {}}
  for _,name in ipairs(connecteds)
    res = db\query(
      "select ty from chest where computer = $1 and name = $2;",
      {ty: "int4", val: my_id},
      {ty: "text", val: name}
    )
    if #res == 0
      print("warn: unrecognized chest "..name)
    elseif false
      size = wired_modem.callRemote(name, "size")
      print("adding "..name)
      db\query("start transaction")
      db\query(
        "insert into chest (computer, name, ty, slots) VALUES ($1, $2, $3, $4)",
        {ty: "int4", val: my_id},
        {ty: "text", val: name},
        {ty: "text", val: "unknown"},
        {ty: "int4", val: size}
      )
      for i=1,size
        db\query(
          "insert into stack (chest_computer, chest_name, slot, count) VALUES ($1, $2, $3, 0)",
          {ty: "int4", val: my_id},
          {ty: "text", val: name},
          {ty: "int2", val: i}
        )
      db\query("commit")
  print("all chests added")
  parallel.waitForAll input_thread, output_thread

parallel.waitForAll process, main
