require("paranoidLogger")("chester2")
local dblib = require("db")
local mp = require("mp")
local common = require("chestercommon")
local wired_modem = nil
print("find wired modem")
for _, mod in ipairs({
  peripheral.find("modem")
}) do
  if not mod.isWireless() then
    wired_modem = mod
  end
end
if not wired_modem then
  error("Could not find any wired modem")
end
local my_id = os.getComputerID()
local golden = not not multishell
local ty
if turtle then
  ty = "turtle"
elseif pocket then
  ty = "pocket"
elseif select(2, term.getSize()) == 13 and golden then
  ty = "neural"
else
  ty = "computer"
end
local with_db
with_db = function(func)
  print("withdb")
  local idb = dblib:default()
  print("db id " .. idb.id)
  return function()
    return parallel.waitForAny((function()
      return idb:process()
    end), (function()
      return func(idb)
    end))
  end
end
local clamp
clamp = function(num, low, high)
  return math.min(math.max(num, low), high)
end
local job_dep_finish_thread
job_dep_finish_thread = function(db)
  print("job dep finish running")
  local sleeptime = 0
  while true do
    os.sleep(0)
    local res = db:query("update job_dep_graph j set children_finished=true from lateral (\n        select n.id, coalesce(bool_and(c.finished), true) as all_finished from job_dep_graph n left join job_dep_graph c on c.parent = n.id where n.children_finished = false group by n.id\n      ) q where j.id = q.id and q.all_finished returning null")
    print("res is " .. textutils.serialise(res))
    local count1 = #res
    res = db:query("update job_dep_graph j set finished=true from lateral (\n        select n.id, coalesce( bool_and(c.finished), true ) as all_finished from job_dep_graph n left join job c on c.parent = n.id where n.finished = false and n.children_finished = true group by n.id\n      ) q where j.id = q.id and q.all_finished returning null")
    local count2 = #res
    local count = count1 + count2
    if count == 0 then
      sleeptime = clamp(sleeptime * 2, 0.1, 6)
      sleep(sleeptime)
    end
  end
end
local job_output_thread
job_output_thread = function(db)
  print("job output running")
  local sleeptime = 0
  while true do
    local _continue_0 = false
    repeat
      os.sleep(0)
      db:query("start transaction")
      local res = db:query("select j.chest_computer, j.chest_name, j.quantity, j.item_id, j.id, j.parent from job j, job_dep_graph jdg where j.parent = jdg.id and jdg.finished = false and jdg.children_finished = true and j.finished = false and j.chest_computer is not null limit 1 for no key update skip locked")
      if #res == 0 then
        db:query("commit")
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
      res = db:query("select chest_computer, chest_name, slot, count from stack where item_id = $1 and count >= $2 limit 1 for no key update skip locked", {
        ty = "int4",
        val = item_id
      }, {
        ty = "int4",
        val = quantity
      })
      if #res == 0 then
        res = db:query("select chest_computer, chest_name, slot, count from stack where item_id = $1 order by count desc limit 1 for no key update", {
          ty = "int4",
          val = item_id
        })
      end
      if #res == 0 then
        db:query("rollback")
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
      local source_chest = peripheral.wrap(stack_chest_name)
      local transferred = source_chest.pushItems(out_chest_name, stack_slot, quantity)
      if transferred == 0 and quantity ~= 0 then
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
local legacy_output_thread
legacy_output_thread = function(db)
  print("legacy output running")
  db:query("listen withdrawal_rescan")
  print("listening for withdrawal_rescan")
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
      print("withdrawal rescan")
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
        if type(to_slot) == "table" then
          to_slot = nil
        end
        while remaining > 0 do
          print(remaining .. " remaining")
          local res = db:query("select chest_name, slot, count from stack where item_id = $1 and chest_computer = $2 and count > 0 order by count asc limit 1 for no key update skip locked", {
            ty = "int4",
            val = item_id
          }, {
            ty = "int4",
            val = my_id
          })
          if #res == 0 then
            print("ERR: no items to withdraw for req#" .. withdrawal_id)
            remaining = 0
            break
          end
          row = res[1]
          local chest_name = row[1].val
          local from_slot = row[2].val
          local stack_count = row[3].val
          local sc = peripheral.wrap(chest_name)
          print(textutils.serialise({
            output_chest,
            from_slot,
            remaining,
            to_slot
          }))
          local pushed = sc.pushItems(output_chest, from_slot, remaining, to_slot)
          if pushed == 0 then
            error("Pushed 0 items in withdrawal process")
          end
          remaining = remaining - pushed
          stack_count = stack_count - pushed
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
local input_thread
input_thread = function(db)
  print("input thread running")
  while true do
    os.sleep(5)
    local names = db:query("select name from chest where computer = $1 and ty = 'input';", {
      ty = "int4",
      val = my_id
    })
    for _, row in ipairs(names) do
      local _continue_0 = false
      repeat
        local name = row[1].val
        local p = peripheral.wrap(name)
        if not p then
          print("WARN: chest disappeared " .. name)
          _continue_0 = true
          break
        end
        local items = p.list()
        for from_slot, v in pairs(items) do
          local meta = p.getItemMeta(from_slot)
          print(meta.name .. " x" .. meta.count .. " " .. from_slot)
          local item_id = common.insertOrGetId(db, meta)
          local remaining = meta.count
          while remaining > 0 do
            db:query("start transaction")
            local res
            if remaining < meta.maxCount then
              res = db:query("select chest_name, slot, count from stack where (item_id = $1 or item_id is null) and count < $2 and chest_computer = $3 order by count desc limit 1 for no key update ;", {
                ty = "int4",
                val = item_id
              }, {
                ty = "int4",
                val = meta.maxCount
              }, {
                ty = "int4",
                val = my_id
              })
            else
              res = db:query("select chest_name, slot, count from stack where item_id is null and count = 0 and chest_computer = $1 order by count desc limit 1 for no key update", {
                ty = "int4",
                val = my_id
              })
            end
            if #res == 0 then
              error("no space available!")
            elseif #res ~= 1 then
              error("expected exactly 1 result")
            end
            row = res[1]
            local chest_name = row[1].val
            local to_slot = row[2].val
            local count = row[3].val
            local quantity = math.min(remaining, meta.maxCount - count)
            db:query("update stack set count = $1, item_id = $2 where chest_computer = $3 and chest_name = $4 and slot = $5", {
              ty = "int4",
              val = count + quantity
            }, {
              ty = "int4",
              val = item_id
            }, {
              ty = "int4",
              val = my_id
            }, {
              ty = "text",
              val = chest_name
            }, {
              ty = "int2",
              val = to_slot
            })
            local transferred = p.pushItems(chest_name, from_slot, quantity, to_slot)
            if quantity ~= transferred then
              db:query("rollback")
              error("Transfer failed! Expected " .. quantity .. " items pushed, instead " .. transferred .. " were pushed. Item#" .. item_id .. ", from " .. from_slot .. " to " .. chest_name .. ":" .. to_slot .. ". Rescan needed.")
            end
            remaining = remaining - quantity
            db:query("commit")
          end
        end
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
  end
end
local main
main = function(db)
  print("about to query")
  local res = db:query("insert into computer (id, ty, is_golden) values ($1, $2, $3) on conflict (id) do update set ty = $2, is_golden = $3", {
    ty = "int4",
    val = my_id
  }, {
    ty = "text",
    val = ty
  }, {
    ty = "bool",
    val = golden
  })
  print("res is " .. textutils.serialise(res))
  local connecteds = wired_modem.getNamesRemote()
  if false then
    for _, name in ipairs(connecteds) do
      local _continue_0 = false
      repeat
        if common.starts_with(name, "turtle_") then
          _continue_0 = true
          break
        end
        res = db:query("select ty from chest where computer = $1 and name = $2;", {
          ty = "int4",
          val = my_id
        }, {
          ty = "text",
          val = name
        })
        if #res == 0 then
          print("warn: unrecognized chest " .. name)
        elseif false then
          local size = wired_modem.callRemote(name, "size")
          print("adding " .. name)
          db:query("start transaction")
          db:query("insert into chest (computer, name, ty, slots) VALUES ($1, $2, $3, $4)", {
            ty = "int4",
            val = my_id
          }, {
            ty = "text",
            val = name
          }, {
            ty = "text",
            val = "unknown"
          }, {
            ty = "int4",
            val = size
          })
          for i = 1, size do
            db:query("insert into stack (chest_computer, chest_name, slot, count) VALUES ($1, $2, $3, 0)", {
              ty = "int4",
              val = my_id
            }, {
              ty = "text",
              val = name
            }, {
              ty = "int2",
              val = i
            })
          end
          db:query("commit")
        end
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    print("all chests added")
  end
  db:close()
  return parallel.waitForAll(with_db(input_thread), with_db(legacy_output_thread), with_db(job_dep_finish_thread), with_db(job_output_thread))
end
return parallel.waitForAll(with_db(main))
