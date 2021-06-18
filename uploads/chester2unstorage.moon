require("paranoidLogger")("chester2unstorage")
common = require("chestercommon")

computer = 55
computer_parm = {ty: "int4", val: 55}

tArgs = {...}

if tArgs[2] ~= "input" and tArgs[2] ~= "output"
  paraLog.die("must specify new chest ty")

main = (db) ->
  paraLog.log("run rescan fix")
  shell.run("chester2rescan", "fix", tArgs[1])
  db\query("start transaction")
  chest_name = tArgs[1]
  chest_name_parm = {ty: "text", val: tArgs[1]}
  res = db\query("select ty from chest where computer = $1 and name = $2 for update", computer_parm, chest_name_parm)
  if #res == 0
    paraLog.die("chest not found")
  elseif #res ~= 1
    paraLog.die("expected exactly 1 result",res)
  row = res[1]
  if row[1].val != 'storage'
    paraLog.die("chest already not storage")
  quickList = peripheral.call(chest_name, "list")
  paraLog.log("Got list",{:quickList})
  paraLog.log("Get slots from db",{:chest_name_parm})
  res = db\query("select slot, count, item_id from stack where chest_computer = $1 and chest_name = $2 for update", computer_parm, chest_name_parm)
  for _,row in ipairs(res)
    from_slot_parm = row[1]
    from_slot = from_slot_parm.val
    from_count_parm = row[2]
    from_count = from_count_parm.val
    item_id_parm = row[3]
    local real_from_count
    meta = quickList[from_slot]
    if meta == nil
      real_from_count = 0
    else
      real_from_count = meta.count
    if real_from_count ~= from_count
      paraLog.die("from_count did not match slot "..from_slot)

    if from_count ~= 0
      paraLog.log("find empty", {:computer_parm, :chest_name_parm})
      res = db\query(
        "select chest_name, slot from stack where item_id is null and count = 0 and chest_computer = $1 and chest_name != $2 limit 1 for no key update",
        computer_parm,
        chest_name_parm
      )
      if #res == 0
        paraLog.die("no item space avail")
      elseif #res ~= 1
        paraLog.die("expected exactly one row")
      row = res[1]
      to_chest_parm = row[1]
      to_slot_parm = row[2]
      to_chest = to_chest_parm.val
      to_slot = to_slot_parm.val

      paraLog.log(
        "update to stack",
        {:from_count_param, :item_id_parm, :computer_parm, :to_chest_parm, :to_slot_parm}
      )
      db\query(
        "update stack set count = $1, item_id = $2 where chest_computer = $3 and chest_name = $4 and slot = $5",
        from_count_parm,
        item_id_parm,
        computer_parm,
        to_chest_parm,
        to_slot_parm
      )

      paraLog.log("to chest has",{meta: peripheral.call(to_chest,"list")[to_slot]})

      transferred = paraLog.loggedCall("do the input", chest_name, "pushItems", to_chest, from_slot, from_count, to_slot)
      if transferred ~= from_count
        paraLog.die("Transfer failed, rescan needed")

    paraLog.log("delete", {:computer_parm, :chest_name_parm, :from_slot_parm})
    db\query(
      "delete from stack where chest_computer = $1 and chest_name = $2 and slot = $3",
      computer_parm,
      chest_name_parm,
      from_slot_parm
    )
  
  -- We've now deleted all slots; set this as an input/output chest depending on tArgs[2]
  db\query(
    "update chest set ty = $1 where computer = $2 and name = $3",
    {ty: "text", val: tArgs[2]},
    computer_parm,
    chest_name_parm
  )

  db\query("COMMIT")
common.with_db(main)()