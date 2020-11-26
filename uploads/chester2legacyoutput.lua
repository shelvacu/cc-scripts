require("paranoidLogger")("chester2legacyoutput")
local common = require("chestercommon")
local my_id = 55
local legacy_output_thread
legacy_output_thread = function(db)
  paraLog.log("legacy output running")
  db:query("listen withdrawal_rescan")
  while true do
    local _continue_0 = false
    repeat
      local evName, id, parsed = os.pullEvent("database_notification")
      if id ~= db.id then
        _continue_0 = true
        break
      end
      if parsed.channel ~= "withdrawal_rescan" then
        _continue_0 = true
        break
      end
      paraLog.log("withdrawal rescan", {
        evName = evName,
        id = id,
        parsed = parsed
      })
      db:query("start transaction")
      local withdrawals = db:query("select id, item_id, output_chest, slot, count from withdrawal where computer = $1 and not finished for no key update", {
        ty = "int4",
        val = my_id
      })
      print("found " .. #withdrawals .. " withdrawals")
      for _, row in ipairs(withdrawals) do
        local withdrawal_id = row[1].val
        local item_id = row[2].val
        local output_chest = row[3].val
        local to_slot = row[4].val
        local count = row[5].val
        local remaining = count
        paraLog.log("legacy withdrawal", {
          withdrawal_id = withdrawal_id,
          item_id = item_id,
          output_chest = output_chest,
          to_slot = to_slot,
          count = count,
          remaining = remaining
        })
        if type(to_slot) == "table" then
          to_slot = nil
        end
        while remaining > 0 do
          paraLog.log("while loop: remaining", remaining)
          local res = db:query("select chest_name, slot, count from stack where item_id = $1 and chest_computer = $2 and count > 0 order by count asc limit 1 for no key update skip locked", {
            ty = "int4",
            val = item_id
          }, {
            ty = "int4",
            val = my_id
          })
          paraLog.log("find suitable slot", res)
          if #res == 0 then
            print("ERR: no items to withdraw for req#" .. withdrawal_id)
            remaining = 0
            break
          end
          row = res[1]
          local chest_name = row[1].val
          local from_slot = row[2].val
          local stack_count = row[3].val
          paraLog.log("stack to withdraw", {
            row = row,
            chest_name = chest_name,
            from_slot = from_slot,
            stack_count = stack_count
          })
          local pushed = paraLog.loggedCall("doing the withdrawal", chest_name, "pushItems", output_chest, from_slot, remaining, to_slot)
          if pushed == 0 then
            error("Pushed 0 items in withdrawal process")
          end
          paraLog.log("before decrement", {
            remaining = remaining,
            stack_count = stack_count
          })
          remaining = remaining - pushed
          stack_count = stack_count - pushed
          paraLog.log("after decrement", {
            remaining = remaining,
            stack_count = stack_count
          })
          local new_item_id
          if stack_count == 0 then
            new_item_id = nil
          else
            new_item_id = item_id
          end
          db:query("update stack set count = $1, item_id = $2 where chest_computer = $3 and chest_name = $4 and slot = $5", {
            ty = "int4",
            val = stack_count
          }, {
            ty = "int4",
            val = new_item_id
          }, {
            ty = "int4",
            val = my_id
          }, {
            ty = "text",
            val = chest_name
          }, {
            ty = "int2",
            val = from_slot
          })
        end
        db:query("update withdrawal set finished = true where id = $1", {
          ty = "int4",
          val = withdrawal_id
        })
      end
      db:query("commit")
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
end
return common.with_db(legacy_output_thread)()
