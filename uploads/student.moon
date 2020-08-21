db = require("db")\default!
common = require"chestercommon"

introspection = peripheral.find("plethora:introspection")
inv = introspection.getInventory()

process = -> db\process!

main = ->
  while true
    print"Place craft recipe in top-left corner, then press L to learn"
    while true
      ev, key = os.pullEvent("key")
      break if key == keys.l
    term.clear()
    print("Processing, please wait...")
    doContinue = false
    for _, i in ipairs {4,8,12,13,14,15,16}
      if turtle.getItemCount(i) ~= 0
        print "err: Unexpected item in slot "..i
        doContinue = true
        break
    continue if doContinue
    -- These index pairs map the top-left of the turtle's inventory:
    -- 01 02 03 04
    -- 05 06 07 08
    -- 09 10 11 12
    -- 13 14 15 16
    -- To the crafting square in the DB:
    -- 01 02 03
    -- 04 05 06
    -- 07 08 09
    idxPairs = {
      { 1,1},{ 2,2},{ 3,3},
      { 5,4},{ 6,5},{ 7,6},
      { 9,7},{10,8},{11,9}
    }
    dbItemsIn = {}
    doContinue = false
    for _, idxPair in ipairs idxPairs
      turtleIdx = idxPair[1]
      dbIdx = idxPair[2]
      meta = inv.getItemMeta(turtleIdx)
      if meta and meta.count > 1
        print("err: only put one of each item")
        doContinue = true
        break
      itemId = common.insertOrGetId(db, meta)
      dbItemsIn[dbIdx] = itemId
    continue if doContinue
    -- 'is not distinct from' is sql magic incantation for "equals but with some sanity regarding nulls". 
    -- 'NULL = NULL' is NULL (falsy, but not false), whereas 'NULL is not distinct from NULL' is true
    --can't use table.unpack! dbItemsIn may have nils
    res = db\query(
      "select exists(select * from crafting_recipe where
        slot_1 is not distinct from $1 and 
        slot_2 is not distinct from $2 and 
        slot_3 is not distinct from $3 and
        slot_4 is not distinct from $4 and
        slot_5 is not distinct from $5 and
        slot_6 is not distinct from $6 and
        slot_7 is not distinct from $7 and
        slot_8 is not distinct from $8 and
        slot_9 is not distinct from $9
      )",
      {ty: "int4", val: dbItemsIn[1]},
      {ty: "int4", val: dbItemsIn[2]},
      {ty: "int4", val: dbItemsIn[3]},
      {ty: "int4", val: dbItemsIn[4]},
      {ty: "int4", val: dbItemsIn[5]},
      {ty: "int4", val: dbItemsIn[6]},
      {ty: "int4", val: dbItemsIn[7]},
      {ty: "int4", val: dbItemsIn[8]},
      {ty: "int4", val: dbItemsIn[9]}
    )
    if res[1][1].val
      print("err: Crafting recipe already learned!")
      continue
    turtle.select(16)
    if not turtle.craft(1)
      print("err: Failed to craft")
      continue
    dbItemsOut = {}
    for _, idxPair in ipairs idxPairs
      turtleIdx = idxPair[1]
      dbIdx = idxPair[2]
      meta = inv.getItemMeta(turtleIdx)
      itemId = common.insertOrGetId(db, meta)
      dbItemsOut[dbIdx] = itemId
    resultItem = inv.getItemMeta(16)
    resultItemId = common.insertOrGetId(db, resultItem)
    res = db\query(
      "insert into crafting_recipe (
        result,
        result_count,
        slot_1,
        slot_2,
        slot_3,
        slot_4,
        slot_5,
        slot_6,
        slot_7,
        slot_8,
        slot_9,
        out_1,
        out_2,
        out_3,
        out_4,
        out_5,
        out_6,
        out_7,
        out_8,
        out_9
      ) VALUES ( " .. table.concat(["$"..x for x=1,20],",") .. ") returning id",
      {ty: "int4", val: resultItemId},
      {ty: "int4", val: resultItem.count},
      {ty: "int4", val: dbItemsIn[1]},
      {ty: "int4", val: dbItemsIn[2]},
      {ty: "int4", val: dbItemsIn[3]},
      {ty: "int4", val: dbItemsIn[4]},
      {ty: "int4", val: dbItemsIn[5]},
      {ty: "int4", val: dbItemsIn[6]},
      {ty: "int4", val: dbItemsIn[7]},
      {ty: "int4", val: dbItemsIn[8]},
      {ty: "int4", val: dbItemsIn[9]},
      {ty: "int4", val: dbItemsOut[1]},
      {ty: "int4", val: dbItemsOut[2]},
      {ty: "int4", val: dbItemsOut[3]},
      {ty: "int4", val: dbItemsOut[4]},
      {ty: "int4", val: dbItemsOut[5]},
      {ty: "int4", val: dbItemsOut[6]},
      {ty: "int4", val: dbItemsOut[7]},
      {ty: "int4", val: dbItemsOut[8]},
      {ty: "int4", val: dbItemsOut[9]}
    )
    print("Success! Added new recipe id "..res[1][1].val)

parallel.waitForAll(process, main)
