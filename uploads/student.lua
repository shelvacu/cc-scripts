local db = require("db"):default()
local common = require("chestercommon")
local introspection = peripheral.find("plethora:introspection")
local inv = introspection.getInventory()
local process
process = function()
  return db:process()
end
local main
main = function()
  while true do
    local _continue_0 = false
    repeat
      print("Place craft recipe in top-left corner, then press L to learn")
      while true do
        local ev, key = os.pullEvent("key")
        if key == keys.l then
          break
        end
      end
      term.clear()
      print("Processing, please wait...")
      local doContinue = false
      for _, i in ipairs({
        4,
        8,
        12,
        13,
        14,
        15,
        16
      }) do
        if turtle.getItemCount(i) ~= 0 then
          print("err: Unexpected item in slot " .. i)
          doContinue = true
          break
        end
      end
      if doContinue then
        _continue_0 = true
        break
      end
      local idxPairs = {
        {
          1,
          1
        },
        {
          2,
          2
        },
        {
          3,
          3
        },
        {
          5,
          4
        },
        {
          6,
          5
        },
        {
          7,
          6
        },
        {
          9,
          7
        },
        {
          10,
          8
        },
        {
          11,
          9
        }
      }
      local dbItemsIn = { }
      doContinue = false
      for _, idxPair in ipairs(idxPairs) do
        local turtleIdx = idxPair[1]
        local dbIdx = idxPair[2]
        local meta = inv.getItemMeta(turtleIdx)
        if meta and meta.count > 1 then
          print("err: only put one of each item")
          doContinue = true
          break
        end
        local itemId = common.insertOrGetId(db, meta)
        dbItemsIn[dbIdx] = itemId
      end
      if doContinue then
        _continue_0 = true
        break
      end
      local res = db:query("select exists(select * from crafting_recipe where\n        slot_1 is not distinct from $1 and \n        slot_2 is not distinct from $2 and \n        slot_3 is not distinct from $3 and\n        slot_4 is not distinct from $4 and\n        slot_5 is not distinct from $5 and\n        slot_6 is not distinct from $6 and\n        slot_7 is not distinct from $7 and\n        slot_8 is not distinct from $8 and\n        slot_9 is not distinct from $9\n      )", {
        ty = "int4",
        val = dbItemsIn[1]
      }, {
        ty = "int4",
        val = dbItemsIn[2]
      }, {
        ty = "int4",
        val = dbItemsIn[3]
      }, {
        ty = "int4",
        val = dbItemsIn[4]
      }, {
        ty = "int4",
        val = dbItemsIn[5]
      }, {
        ty = "int4",
        val = dbItemsIn[6]
      }, {
        ty = "int4",
        val = dbItemsIn[7]
      }, {
        ty = "int4",
        val = dbItemsIn[8]
      }, {
        ty = "int4",
        val = dbItemsIn[9]
      })
      if res[1][1].val then
        print("err: Crafting recipe already learned!")
        _continue_0 = true
        break
      end
      turtle.select(16)
      if not turtle.craft(1) then
        print("err: Failed to craft")
        _continue_0 = true
        break
      end
      local dbItemsOut = { }
      for _, idxPair in ipairs(idxPairs) do
        local turtleIdx = idxPair[1]
        local dbIdx = idxPair[2]
        local meta = inv.getItemMeta(turtleIdx)
        local itemId = common.insertOrGetId(db, meta)
        dbItemsOut[dbIdx] = itemId
      end
      local resultItem = inv.getItemMeta(16)
      local resultItemId = common.insertOrGetId(db, resultItem)
      res = db:query("insert into crafting_recipe (\n        result,\n        result_count,\n        slot_1,\n        slot_2,\n        slot_3,\n        slot_4,\n        slot_5,\n        slot_6,\n        slot_7,\n        slot_8,\n        slot_9,\n        out_1,\n        out_2,\n        out_3,\n        out_4,\n        out_5,\n        out_6,\n        out_7,\n        out_8,\n        out_9\n      ) VALUES ( " .. table.concat((function()
        local _accum_0 = { }
        local _len_0 = 1
        for x = 1, 20 do
          _accum_0[_len_0] = "$" .. x
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)(), ",") .. ") returning id", {
        ty = "int4",
        val = resultItemId
      }, {
        ty = "int4",
        val = resultItem.count
      }, {
        ty = "int4",
        val = dbItemsIn[1]
      }, {
        ty = "int4",
        val = dbItemsIn[2]
      }, {
        ty = "int4",
        val = dbItemsIn[3]
      }, {
        ty = "int4",
        val = dbItemsIn[4]
      }, {
        ty = "int4",
        val = dbItemsIn[5]
      }, {
        ty = "int4",
        val = dbItemsIn[6]
      }, {
        ty = "int4",
        val = dbItemsIn[7]
      }, {
        ty = "int4",
        val = dbItemsIn[8]
      }, {
        ty = "int4",
        val = dbItemsIn[9]
      }, {
        ty = "int4",
        val = dbItemsOut[1]
      }, {
        ty = "int4",
        val = dbItemsOut[2]
      }, {
        ty = "int4",
        val = dbItemsOut[3]
      }, {
        ty = "int4",
        val = dbItemsOut[4]
      }, {
        ty = "int4",
        val = dbItemsOut[5]
      }, {
        ty = "int4",
        val = dbItemsOut[6]
      }, {
        ty = "int4",
        val = dbItemsOut[7]
      }, {
        ty = "int4",
        val = dbItemsOut[8]
      }, {
        ty = "int4",
        val = dbItemsOut[9]
      })
      print("Success! Added new recipe id " .. res[1][1].val)
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
end
return parallel.waitForAll(process, main)
