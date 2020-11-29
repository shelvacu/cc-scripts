require("paranoidLogger")("chester2input")
local common = require("chestercommon")
local my_id = 55
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
        paraLog.log("iter on chest", {
          name = name
        })
        local p = peripheral.wrap(name)
        if not p then
          print("WARN: chest disappeared " .. name)
          _continue_0 = true
          break
        end
        local items = p.list()
        paraLog("item list count", #items)
        for from_slot, v in pairs(items) do
          local meta = paraLog.loggedCall("get details", name, "getItemMeta", from_slot)
          local item_id = common.insertOrGetId(db, meta)
          local remaining = meta.count
          while remaining > 0 do
            paraLog.log("remaining", remaining)
            db:query("start transaction")
            local res
            if remaining < meta.maxCount then
              paraLog.log("move substack")
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
              paraLog.log("move full stack")
              res = db:query("select chest_name, slot, count from stack where item_id is null and count = 0 and chest_computer = $1 order by count desc limit 1 for no key update", {
                ty = "int4",
                val = my_id
              })
            end
            if #res == 0 then
              paraLog.die("no space available!")
            elseif #res ~= 1 then
              paraLog.die("expected exactly 1 result", res)
            end
            row = res[1]
            local chest_name = row[1].val
            local to_slot = row[2].val
            local count = row[3].val
            local quantity = math.min(remaining, meta.maxCount - count)
            paraLog.log("updating stack", {
              row = row,
              chest_name = chest_name,
              to_slot = to_slot,
              count = count,
              quantity = quantity
            })
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
            local transferred = paraLog.loggedCall("do the input", name, "pushItems", chest_name, from_slot, quantity, to_slot)
            if quantity ~= transferred then
              db:query("rollback")
              paraLog.die("Transfer failed! Expected " .. quantity .. " items pushed, instead " .. transferred .. " were pushed. Item#" .. item_id .. ", from " .. from_slot .. " to " .. chest_name .. ":" .. to_slot .. ". Rescan needed.")
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
return common.with_db(input_thread)()
