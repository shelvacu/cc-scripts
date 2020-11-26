require("paranoidLogger")("chester2legacyoutput")
common = require("chestercommon")

my_id = 55

legacy_output_thread = (db) ->
  paraLog.log("legacy output running")
  db\query("listen withdrawal_rescan")
  while true
    evName, id, parsed = os.pullEvent("database_notification")
    continue if id ~= db.id
    continue if parsed.channel ~= "withdrawal_rescan"
    paraLog.log("withdrawal rescan", {:evName, :id, :parsed})
    db\query("start transaction")
    withdrawals = db\query(
      "select id, item_id, output_chest, slot, count from withdrawal where computer = $1 and not finished for no key update",
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
      paraLog.log("legacy withdrawal",{:withdrawal_id,:item_id,:output_chest,:to_slot,:count,:remaining})
      if type(to_slot) == "table"
        to_slot = nil
      while remaining > 0
        paraLog.log("while loop: remaining", remaining)
        --find a suitable slot to withdraw from
        res = db\query(
          "select chest_name, slot, count from stack where item_id = $1 and chest_computer = $2 and count > 0 order by count asc limit 1 for no key update skip locked",
          {ty: "int4", val: item_id},
          {ty: "int4", val: my_id}
        )
        paraLog.log("find suitable slot", res)
        if #res == 0
          print("ERR: no items to withdraw for req#"..withdrawal_id)
          remaining = 0
          break
        row = res[1]
        chest_name = row[1].val
        from_slot = row[2].val
        stack_count = row[3].val
        paraLog.log("stack to withdraw",{:row,:chest_name,:from_slot,:stack_count})
        --sc = peripheral.wrap(chest_name)
        --print(textutils.serialise({output_chest, from_slot, remaining, to_slot}))
        --pushed = sc.pushItems(output_chest, from_slot, remaining, to_slot)
        pushed = paraLog.loggedCall("doing the withdrawal", chest_name, "pushItems", output_chest, from_slot, remaining, to_slot)
        if pushed == 0
          error "Pushed 0 items in withdrawal process"
        paraLog.log("before decrement",{:remaining,:stack_count})
        remaining -= pushed
        stack_count -= pushed
        paraLog.log("after decrement",{:remaining,:stack_count})
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
    db\query("commit")
common.with_db(legacy_output_thread)()