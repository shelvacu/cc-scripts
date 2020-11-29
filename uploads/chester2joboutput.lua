require("paranoidLogger")("chester2joboutput")
local common = require("chestercommon")
local my_id = 55
local clamp
clamp = function(num, low, high)
  return math.min(math.max(num, low), high)
end
local job_output_thread
job_output_thread = function(db)
  paraLog.log("job output running")
  local sleeptime = 0
  while true do
    local _continue_0 = false
    repeat
      os.sleep(0)
      db:query("start transaction")
      local res = db:query("select j.chest_computer, j.chest_name, j.quantity, j.item_id, j.id, j.parent from job j, job_dep_graph jdg where j.parent = jdg.id and jdg.finished = false and jdg.children_finished = true and j.finished = false and j.chest_computer is not null limit 1 for no key update skip locked")
      if #res == 0 then
        db:query("commit")
        paraLog.log("found no output jobs")
        sleeptime = clamp(sleeptime * 2, 0.1, 1)
        sleep(sleeptime)
        _continue_0 = true
        break
      end
      local row = res[1]
      local out_chest_computer = row[1].val
      local out_chest_name = row[2].val
      local quantity = row[3].val
      local item_id = row[4].val
      local job_id = row[5].val
      local job_parent_id = row[6].val
      paraLog.log("found output job", {
        out_chest_computer = out_chest_computer,
        out_chest_name = out_chest_name,
        quantity = quantity,
        item_id = item_id,
        job_id = job_id,
        job_parent_id = job_parent_id
      })
      res = db:query("select chest_computer, chest_name, slot, count from stack where item_id = $1 and count >= $2 limit 1 for no key update skip locked", {
        ty = "int4",
        val = item_id
      }, {
        ty = "int4",
        val = quantity
      })
      paraLog.log("lock output#1", res)
      if #res == 0 then
        res = db:query("select chest_computer, chest_name, slot, count from stack where item_id = $1 order by count desc limit 1 for no key update", {
          ty = "int4",
          val = item_id
        })
        paraLog.log("lock output#2", res)
      end
      if #res == 0 then
        db:query("rollback")
        paraLog.log("no items avail", job_id)
        print("no items avail for job " .. job_id)
        sleep(1)
        _continue_0 = true
        break
      end
      row = res[1]
      local stack_chest_computer = row[1].val
      local stack_chest_name = row[2].val
      local stack_slot = row[3].val
      local stack_count = row[4].val
      paraLog.log("output lock", {
        stack_chest_computer = stack_chest_computer,
        stack_chest_name = stack_chest_name,
        stack_slot = stack_slot,
        stack_count = stack_count
      })
      local transferred = paraLog.loggedCall("vehuiwqaolfew", stack_chest_name, "pushItems", out_chest_name, stack_slot, quantity)
      if transferred == 0 and quantity ~= 0 then
        paraLog.log("0 transferred, what?")
        db:query("commit")
        sleep(2)
        _continue_0 = true
        break
      end
      local new_stack_count = stack_count - transferred
      if new_stack_count == 0 then
        db:query("update stack set item_id = NULL, count = 0 where chest_computer = $1 and chest_name = $2 and slot = $3", {
          ty = "int4",
          val = stack_chest_computer
        }, {
          ty = "text",
          val = stack_chest_name
        }, {
          ty = "int2",
          val = stack_slot
        })
      else
        db:query("update stack set count = $4 where chest_computer = $1 and chest_name = $2 and slot = $3", {
          ty = "int4",
          val = stack_chest_computer
        }, {
          ty = "text",
          val = stack_chest_name
        }, {
          ty = "int2",
          val = stack_slot
        }, {
          ty = "int4",
          val = new_stack_count
        })
      end
      if transferred == quantity then
        db:query("update job set finished = true where id = $1", {
          ty = "int4",
          val = job_id
        })
      else
        paraLog.log("output job split :(", {
          transferred = transferred,
          job_id = job_id,
          job_parent_id = job_parent_id,
          out_chest_computer = out_chest_computer,
          out_chest_name = out_chest_name,
          item_id = item_id,
          quantity_minus_transferred = quantity - transferred
        })
        db:query("update job set finished = true, quantity = $1 where id = $2", {
          ty = "int4",
          val = transferred
        }, {
          ty = "int4",
          val = job_id
        })
        db:query("insert into job (parent, chest_computer, chest_name, item_id, quantity, finished) VALUES ($1, $2, $3, $4, $5, false)", {
          ty = "int4",
          val = job_parent_id
        }, {
          ty = "int4",
          val = out_chest_computer
        }, {
          ty = "text",
          val = out_chest_name
        }, {
          ty = "int4",
          val = item_id
        }, {
          ty = "int4",
          val = quantity - transferred
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
return common.with_db(job_output_thread)()
