require("paranoidLogger")("chester2crafter")
local dblib = require("db")
local db = dblib:default()
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
local myName = wired_modem.getNameLocal()
local craftingSlotToTurtleSlot = {
  1,
  2,
  3,
  5,
  6,
  7,
  9,
  10,
  11
}
local turtleSlotToCraftingSlot = {
  1,
  2,
  3,
  nil,
  4,
  5,
  6,
  nil,
  7,
  8,
  9
}
local stackSizeCache = { }
local getStackSize
getStackSize = function(item_id)
  if stackSizeCache[item_id] ~= nil then
    return stackSizeCache[item_id]
  end
  local stackSize = db:query("select fullmeta->'maxCount' from item where id=$1", {
    ty = "int4",
    val = item_id
  })[1][1].val
  stackSizeCache[item_id] = stackSize
  return stackSize
end
local splice
splice = function(tbl, start_idx, end_idx)
  return table.pack(table.unpack(tbl, start_idx, end_idx))
end
local process
process = function()
  return db:process()
end
local main
main = function()
  while true do
    local _continue_0 = false
    repeat
      db:query("start transaction")
      local res = db:query("select j.crafting_recipe_id, j.quantity, j.id from job j, job_dep_graph jdg where j.parent = jdg.id and jdg.finished = false and jdg.children_finished = true and j.finished = false and j.crafting_recipe_id is not null limit 1 for no key update skip locked")
      if #res == 0 then
        db:query("commit")
        stackSizeCache = { }
        sleep(2)
        _continue_0 = true
        break
      end
      local row = res[1]
      local crafting_recipe_id = row[1].val
      local quantity = row[2].val
      local job_id = row[3].val
      res = db:query("select result, result_count, slot_1, slot_2, slot_3, slot_4, slot_5, slot_6, slot_7, slot_8, slot_9, out_1, out_2, out_3, out_4, out_5, out_6, out_7, out_8, out_9 from crafting_recipe where id = $1", {
        ty = "int4",
        val = crafting_recipe_id
      })
      local db_row = res[1]
      row = { }
      for i, v in ipairs(db_row) do
        if v.ty == "null" then
          row[i] = nil
        else
          row[i] = v.val
        end
      end
      local result_item_id = row[1]
      local result_count = row[2]
      local slots = splice(row, 3, 11)
      local outs = splice(row, 12, 20)
      local item_inputs = { }
      local item_outputs = { }
      item_outputs[result_item_id] = result_count
      for i = 1, 9 do
        if slots[i] ~= nil then
          if item_inputs[slots[i]] == nil then
            item_inputs[slots[i]] = 0
          end
          item_inputs[slots[i]] = item_inputs[slots[i]] + 1
        end
        if outs[i] ~= nil then
          if item_outputs[outs[i]] == nil then
            item_outputs[outs[i]] = 0
          end
          item_outputs[outs[i]] = item_outputs[outs[i]] + 1
        end
      end
      for k, v in pairs(item_inputs) do
        item_inputs[k] = v * quantity
      end
      for k, v in pairs(item_outputs) do
        print(textutils.serialise(v))
        item_outputs[k] = v * quantity * result_count
      end
      local reserved_stack_ids = {
        -1
      }
      local input_reservations = { }
      for item_id, quantity in pairs(item_inputs) do
        local stackSize = getStackSize(item_id)
        local quantity_reserved = 0
        local reservations = { }
        while quantity_reserved < quantity do
          res = { }
          if quantity - quantity_reserved >= stackSize then
            res = db:query("select chest_computer, chest_name, slot, count, id from stack where item_id = $1 and count = $2 and id not in (" .. table.concat(reserved_stack_ids, ",") .. ") limit 1 for no key update skip locked", {
              ty = "int4",
              val = item_id
            }, {
              ty = "int4",
              val = stackSize
            })
          end
          if #res == 0 then
            res = db:query("select chest_computer, chest_name, slot, count, id from stack where item_id = $1 and id not in (" .. table.concat(reserved_stack_ids, ",") .. ") limit 1 for no key update skip locked", {
              ty = "int4",
              val = item_id
            })
          end
          if #res == 0 then
            res = db:query("select chest_computer, chest_name, slot, count, id from stack where item_id = $1 and id not in (" .. table.concat(reserved_stack_ids, ",") .. ") order by count desc limit 1 for no key update", {
              ty = "int4",
              val = item_id
            })
          end
          if #res == 0 then
            db:query("rollback")
            error("Bad job, not enough input available.")
            return 
          end
          row = res[1]
          local reservation = {
            chest_computer = row[1].val,
            chest_name = row[2].val,
            slot = row[3].val,
            count = row[4].val,
            item_id = item_id
          }
          reserved_stack_ids[#reserved_stack_ids + 1] = row[5].val
          quantity_reserved = quantity_reserved + reservation.count
          reservations[#reservations + 1] = reservation
        end
        input_reservations[item_id] = reservations
      end
      local output_reservations = { }
      for item_id, quantity in pairs(item_outputs) do
        local stackSize = getStackSize(item_id)
        local reservations = { }
        local quantity_reserved = 0
        while quantity_reserved < quantity do
          res = db:query("select chest_computer, chest_name, slot, id from stack where item_id IS NULL and count = 0 and id not in (" .. table.concat(reserved_stack_ids, ",") .. ") limit 1 for no key update skip locked")
          if #res == 0 then
            res = db:query("select chest_computer, chest_name, slot, id from stack where item_id IS NULL and count = 0 and id not in (" .. table.concat(reserved_stack_ids, ",") .. ") limit 1 for no key update")
          end
          if #res == 0 then
            db:query("rollback")
            error("Not enough space in inventory")
            return 
          end
          row = res[1]
          local reservation = {
            chest_computer = row[1].val,
            chest_name = row[2].val,
            slot = row[3].val,
            count = 0,
            item_id = item_id
          }
          reserved_stack_ids[#reserved_stack_ids + 1] = row[4].val
          reservations[#reservations + 1] = reservation
          quantity_reserved = quantity_reserved + stackSize
        end
        output_reservations[item_id] = reservations
      end
      local used_input_reservations = { }
      for i = 1, 9 do
        local _continue_1 = false
        repeat
          print("doing slot " .. i .. " which has " .. textutils.serialise(slots[i]))
          if slots[i] == nil then
            _continue_1 = true
            break
          end
          local item_id = slots[i]
          local this_item_reservations = input_reservations[item_id]
          local turtle_slot = craftingSlotToTurtleSlot[i]
          while turtle.getItemCount(turtle_slot) < result_count do
            local reservation = this_item_reservations[#this_item_reservations]
            if reservation.count == 0 then
              error("count is 0!!!")
            end
            local num_to_move = math.min(reservation.count, result_count - turtle.getItemCount(turtle_slot))
            print("wrapped '" .. reservation.chest_name .. "'")
            local chest = peripheral.wrap(reservation.chest_name)
            local turtleCountBefore = turtle.getItemCount(turtle_slot)
            print(textutils.serialise({
              m = myName,
              s = reservation.slot,
              n = num_to_move,
              t = turtle_slot
            }))
            local transferred = chest.pushItems(myName, reservation.slot, num_to_move, turtle_slot)
            local turtleCountAfter = turtle.getItemCount(turtle_slot)
            local otherTransferred = turtleCountAfter - turtleCountBefore
            if transferred ~= otherTransferred then
              print("WARN: Bad transferred value " .. transferred .. ", actually transferred " .. otherTransferred)
              transferred = otherTransferred
            end
            if num_to_move ~= transferred then
              db:query("rollback")
              print("tcrf " .. reservation.chest_name)
              sleep(1000)
              error("Turtle crafter transfer failed! Expected " .. num_to_move .. " items pushed, instead " .. transferred .. " were pushed. Item#" .. item_id .. ", from " .. reservation.chest_name .. ":" .. reservation.slot .. " to " .. myName .. ":" .. turtle_slot .. ". Rescan needed.")
            end
            reservation.count = reservation.count - transferred
            if reservation.count == 0 then
              used_input_reservations[#used_input_reservations + 1] = reservation
              table.remove(this_item_reservations, #this_item_reservations)
            end
          end
          _continue_1 = true
        until true
        if not _continue_1 then
          break
        end
      end
      res = turtle.craft()
      sleep(1)
      if not res then
        db:query("rollback")
        error("Failed to craft. Rescan needed")
        return 
      end
      local used_output_reservations = { }
      for i = 1, 16 do
        local _continue_1 = false
        repeat
          if turtle.getItemCount(i) == 0 then
            _continue_1 = true
            break
          end
          local item_id = nil
          local craftingSlot = turtleSlotToCraftingSlot[i]
          if craftingSlot ~= nil and outs[craftingSlot] ~= nil then
            item_id = outs[craftingSlot]
          else
            item_id = result_item_id
          end
          local stackSize = getStackSize(item_id)
          local this_item_reservations = output_reservations[item_id]
          while turtle.getItemCount(i) > 0 do
            local reservation = this_item_reservations[#this_item_reservations]
            local c = peripheral.wrap(reservation.chest_name)
            print("transferring to " .. reservation.chest_name .. ":" .. reservation.slot .. " which has " .. reservation.count)
            local transferred = c.pullItems(myName, i, stackSize - reservation.count, reservation.slot)
            if transferred == 0 then
              error("err, transferred ZERO. Rescan needed at least on " .. reservation.chest_name .. ":" .. reservation.slot)
            end
            reservation.count = reservation.count + transferred
            if reservation.count == stackSize then
              used_output_reservations[#used_output_reservations + 1] = reservation
              table.remove(this_item_reservations, #this_item_reservations)
            end
          end
          _continue_1 = true
        until true
        if not _continue_1 then
          break
        end
      end
      for _, res in ipairs(used_input_reservations) do
        if res.count == 0 then
          db:query("update stack set item_id = NULL, count = 0 where chest_computer = $1 and chest_name = $2 and slot = $3", {
            ty = "int4",
            val = res.chest_computer
          }, {
            ty = "text",
            val = res.chest_name
          }, {
            ty = "int2",
            val = res.slot
          })
        else
          db:query("update stack set count = $4 where chest_computer = $1 and chest_name = $2 and slot = $3", {
            ty = "int4",
            val = res.chest_computer
          }, {
            ty = "text",
            val = res.chest_name
          }, {
            ty = "int2",
            val = res.slot
          }, {
            ty = "int4",
            val = res.count
          })
        end
      end
      for _, res in ipairs(used_output_reservations) do
        local _continue_1 = false
        repeat
          if res.count == 0 then
            _continue_1 = true
            break
          end
          db:query("update stack set item_id = $1, count = $2 where chest_computer = $3 and chest_name = $4 and slot = $5", {
            ty = "int4",
            val = res.item_id
          }, {
            ty = "int4",
            val = res.count
          }, {
            ty = "int4",
            val = res.chest_computer
          }, {
            ty = "text",
            val = res.chest_name
          }, {
            ty = "int2",
            val = res.slot
          })
          _continue_1 = true
        until true
        if not _continue_1 then
          break
        end
      end
      db:query("update job set finished = true where id = $1", {
        ty = "int4",
        val = job_id
      })
      db:query("commit")
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
end
return parallel.waitForAll(process, main)
