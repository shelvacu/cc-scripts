require("paranoidLogger")("chester2unstorage")
local common = require("chestercommon")
local computer = 55
local computer_parm = {
  ty = "int4",
  val = 55
}
local tArgs = {
  ...
}
if tArgs[2] ~= "input" and tArgs[2] ~= "output" then
  paraLog.die("must specify new chest ty")
end
local main
main = function(db)
  paraLog.log("run rescan fix")
  shell.run("chester2rescan", "fix", tArgs[1])
  db:query("start transaction")
  local chest_name = tArgs[1]
  local chest_name_parm = {
    ty = "text",
    val = tArgs[1]
  }
  local res = db:query("select ty from chest where computer = $1 and name = $2 for update", computer_parm, chest_name_parm)
  if #res == 0 then
    paraLog.die("chest not found")
  elseif #res ~= 1 then
    paraLog.die("expected exactly 1 result", res)
  end
  local row = res[1]
  if row[1].val ~= 'storage' then
    paraLog.die("chest already not storage")
  end
  local quickList = peripheral.call(chest_name, "list")
  paraLog.log("Got list", {
    quickList = quickList
  })
  paraLog.log("Get slots from db", {
    chest_name_parm = chest_name_parm
  })
  res = db:query("select slot, count, item_id from stack where chest_computer = $1 and chest_name = $2 for update", computer_parm, chest_name_parm)
  for _, row in ipairs(res) do
    local from_slot_parm = row[1]
    local from_slot = from_slot_parm.val
    local from_count_parm = row[2]
    local from_count = from_count_parm.val
    local item_id_parm = row[3]
    local real_from_count
    local meta = quickList[from_slot]
    if meta == nil then
      real_from_count = 0
    else
      real_from_count = meta.count
    end
    if real_from_count ~= from_count then
      paraLog.die("from_count did not match slot " .. from_slot)
    end
    if from_count ~= 0 then
      paraLog.log("find empty", {
        computer_parm = computer_parm,
        chest_name_parm = chest_name_parm
      })
      res = db:query("select chest_name, slot from stack where item_id is null and count = 0 and chest_computer = $1 and chest_name != $2 limit 1 for no key update", computer_parm, chest_name_parm)
      if #res == 0 then
        paraLog.die("no item space avail")
      elseif #res ~= 1 then
        paraLog.die("expected exactly one row")
      end
      row = res[1]
      local to_chest_parm = row[1]
      local to_slot_parm = row[2]
      local to_chest = to_chest_parm.val
      local to_slot = to_slot_parm.val
      paraLog.log("update to stack", {
        from_count_param = from_count_param,
        item_id_parm = item_id_parm,
        computer_parm = computer_parm,
        to_chest_parm = to_chest_parm,
        to_slot_parm = to_slot_parm
      })
      db:query("update stack set count = $1, item_id = $2 where chest_computer = $3 and chest_name = $4 and slot = $5", from_count_parm, item_id_parm, computer_parm, to_chest_parm, to_slot_parm)
      local transferred = paraLog.loggedCall("do the input", chest_name, "pushItems", to_chest, from_slot, from_count, to_slot)
      if transferred ~= from_count then
        paraLog.die("Transfer failed, rescan needed")
      end
    end
    paraLog.log("delete", {
      computer_parm = computer_parm,
      chest_name_parm = chest_name_parm,
      from_slot_parm = from_slot_parm
    })
    db:query("delete from stack where chest_computer = $1 and chest_name = $2 and slot = $3", computer_parm, chest_name_parm, from_slot_parm)
  end
  db:query("update chest set ty = $1 where computer = $2 and name = $3", {
    ty = "text",
    val = tArgs[2]
  }, computer_parm, chest_name_parm)
  return db:query("COMMIT")
end
return common.with_db(main)()
