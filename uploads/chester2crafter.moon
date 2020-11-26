-- must run in a crafty turtle connected to chest grid
-- turtle does not need fuel
-- turtle must have inventory introspection module and crafting table equipped
require("paranoidLogger")("chester2crafter")
dblib = require("db")
db = dblib\default!
common = require "chestercommon"

wired_modem = nil

print "find wired modem"
for _,mod in ipairs {peripheral.find "modem"}
  if not mod.isWireless!
    wired_modem = mod
if not wired_modem
  error"Could not find any wired modem"

--introspection = peripheral.find("plethora:introspection")
--myInv = introspection.getInventory()

myName = wired_modem.getNameLocal()

craftingSlotToTurtleSlot = {
    1, 2, 3,
    5, 6, 7,
    9,10,11
}

turtleSlotToCraftingSlot = {
    ---,---,---,---
      1,  2,  3,nil,
      4,  5,  6,nil,
      7,  8,  9
}

stackSizeCache = {}

getStackSize = (item_id) ->
    if stackSizeCache[item_id] != nil
        return stackSizeCache[item_id]
    stackSize = db\query(
        "select fullmeta->'maxCount' from item where id=$1",
        {ty: "int4", val: item_id}
    )[1][1].val
    stackSizeCache[item_id] = stackSize
    return stackSize

splice = (tbl, start_idx, end_idx) ->
    table.pack(table.unpack(tbl, start_idx, end_idx))

process = -> db\process!

main = ->
    while true
        db\query("start transaction")
        res = db\query(
            "select j.crafting_recipe_id, j.quantity, j.id from job j, job_dep_graph jdg where j.parent = jdg.id and jdg.finished = false and jdg.children_finished = true and j.finished = false and j.crafting_recipe_id is not null limit 1 for no key update skip locked"
        )
        if #res == 0
            db\query("commit")
            stackSizeCache = {}
            sleep 2
            continue
        row = res[1]
        crafting_recipe_id = row[1].val
        quantity = row[2].val
        job_id = row[3].val
        res = db\query(
            "select result, result_count, slot_1, slot_2, slot_3, slot_4, slot_5, slot_6, slot_7, slot_8, slot_9, out_1, out_2, out_3, out_4, out_5, out_6, out_7, out_8, out_9 from crafting_recipe where id = $1",
            {ty: "int4", val: crafting_recipe_id}
        )
        db_row = res[1]
        row = {}
        for i,v in ipairs(db_row)
            if v.ty == "null"
                row[i] = nil
            else
                row[i] = v.val
        result_item_id = row[1]
        result_count = row[2]
        slots = splice(row,3,11)
        outs = splice(row,12,20)
        item_inputs = {}
        item_outputs = {}
        item_outputs[result_item_id] = result_count
        for i=1,9
            if slots[i] != nil
                if item_inputs[slots[i]] == nil
                    item_inputs[slots[i]] = 0
                item_inputs[slots[i]] += 1
            if outs[i] != nil
                if item_outputs[outs[i]] == nil
                    item_outputs[outs[i]] = 0
                item_outputs[outs[i]] += 1
        for k,v in pairs(item_inputs)
            item_inputs[k] = v*quantity
        for k,v in pairs(item_outputs)
            print(textutils.serialise(v))
            item_outputs[k] = v*quantity*result_count
        reserved_stack_ids = {-1}
        input_reservations = {} -- item_id => {slot, qty}[]
        for item_id, quantity in pairs(item_inputs)
            stackSize = getStackSize(item_id)
            quantity_reserved = 0
            reservations = {}
            while quantity_reserved < quantity
                res = {}
                if quantity - quantity_reserved >= stackSize
                    res = db\query(
                        "select chest_computer, chest_name, slot, count, id from stack where item_id = $1 and count = $2 and id not in ("..table.concat(reserved_stack_ids,",")..") limit 1 for no key update skip locked",
                        {ty: "int4", val: item_id},
                        {ty: "int4", val: stackSize}
                    )
                if #res == 0
                    --do it again, but this any count
                    res = db\query(
                        "select chest_computer, chest_name, slot, count, id from stack where item_id = $1 and id not in ("..table.concat(reserved_stack_ids,",")..") limit 1 for no key update skip locked",
                        {ty: "int4", val: item_id}
                    )
                if #res == 0
                    --do it again, but this time don't SKIP LOCKED
                    res = db\query(
                        "select chest_computer, chest_name, slot, count, id from stack where item_id = $1 and id not in ("..table.concat(reserved_stack_ids,",")..") order by count desc limit 1 for no key update",
                        {ty: "int4", val: item_id}
                    )
                if #res == 0
                    db\query("rollback")
                    error("Bad job, not enough input available.")
                    return
                row = res[1]
                reservation = {
                    chest_computer: row[1].val,
                    chest_name: row[2].val,
                    slot: row[3].val,
                    count: row[4].val,
                    item_id: item_id
                }
                reserved_stack_ids[#reserved_stack_ids + 1] = row[5].val
                quantity_reserved += reservation.count
                reservations[#reservations + 1] = reservation
            input_reservations[item_id] = reservations
        output_reservations = {}
        for item_id, quantity in pairs(item_outputs)
            stackSize = getStackSize(item_id)
            reservations = {}
            quantity_reserved = 0
            while quantity_reserved < quantity
                res = db\query(
                    "select chest_computer, chest_name, slot, id from stack where item_id IS NULL and count = 0 and id not in ("..table.concat(reserved_stack_ids,",")..") limit 1 for no key update skip locked"
                )
                if #res == 0
                    res = db\query(
                        "select chest_computer, chest_name, slot, id from stack where item_id IS NULL and count = 0 and id not in ("..table.concat(reserved_stack_ids,",")..") limit 1 for no key update"
                    )
                if #res == 0
                    db\query("rollback")
                    error("Not enough space in inventory")
                    return
                row = res[1]
                reservation = {
                    chest_computer: row[1].val,
                    chest_name: row[2].val,
                    slot: row[3].val,
                    count: 0,
                    item_id: item_id
                }
                reserved_stack_ids[#reserved_stack_ids + 1] = row[4].val
                reservations[#reservations + 1] = reservation
                quantity_reserved += stackSize
            output_reservations[item_id] = reservations
        used_input_reservations = {}
        for i=1,9
            print("doing slot "..i.." which has "..textutils.serialise(slots[i]))
            --sleep(1)
            continue if slots[i] == nil
            item_id = slots[i]
            this_item_reservations = input_reservations[item_id]
            turtle_slot = craftingSlotToTurtleSlot[i]
            while turtle.getItemCount(turtle_slot) < result_count
                reservation = this_item_reservations[#this_item_reservations]
                if reservation.count == 0
                    error("count is 0!!!")
                num_to_move = math.min(reservation.count, result_count - turtle.getItemCount(turtle_slot))
                print("wrapped '"..reservation.chest_name.."'")
                chest = peripheral.wrap(reservation.chest_name)
                turtleCountBefore = turtle.getItemCount(turtle_slot)
                print(textutils.serialise{m:myName, s:reservation.slot, n:num_to_move, t:turtle_slot})
                transferred = chest.pushItems(myName, reservation.slot, num_to_move, turtle_slot)
                turtleCountAfter = turtle.getItemCount(turtle_slot)
                otherTransferred = turtleCountAfter - turtleCountBefore
                if transferred ~= otherTransferred
                    print("WARN: Bad transferred value "..transferred..", actually transferred "..otherTransferred)
                    transferred = otherTransferred
                if num_to_move ~= transferred
                    db\query("rollback")
                    print("tcrf "..reservation.chest_name)
                    sleep(1000)
                    error("Turtle crafter transfer failed! Expected "..num_to_move.." items pushed, instead "..transferred.." were pushed. Item#"..item_id..", from " .. reservation.chest_name .. ":" .. reservation.slot .." to " .. myName .. ":" .. turtle_slot .. ". Rescan needed.")
                    --return
                
                --print "count before "..reservation.count
                reservation.count -= transferred
                --print "count after "..reservation.count
                if reservation.count == 0
                    --print "removing reservation"
                    used_input_reservations[#used_input_reservations + 1] = reservation
                    --print "b4 "..#this_item_reservations
                    table.remove(this_item_reservations, #this_item_reservations)
                    --print "af "..#this_item_reservations
        --After a billion years of preparation, we're finally ready
        --DO. THE. CRAFT
        res = turtle.craft()
        sleep(1)
        if not res
            db\query("rollback")
            error("Failed to craft. Rescan needed")
            return
        used_output_reservations = {}
        for i=1,16
            --meta = myInv.getItemMeta(i)
            continue if turtle.getItemCount(i) == 0
            --actual_item_id = common.insertOrGetId(db, meta)
            item_id = nil
            craftingSlot = turtleSlotToCraftingSlot[i]
            if craftingSlot != nil and outs[craftingSlot] != nil
                item_id = outs[craftingSlot]
            else
                item_id = result_item_id
            stackSize = getStackSize(item_id)
            this_item_reservations = output_reservations[item_id]
            while turtle.getItemCount(i) > 0
                reservation = this_item_reservations[#this_item_reservations]
                c = peripheral.wrap(reservation.chest_name)
                print("transferring to "..reservation.chest_name..":"..reservation.slot.." which has "..reservation.count)
                transferred = c.pullItems(myName, i, stackSize - reservation.count, reservation.slot)
                if transferred == 0
                    error("err, transferred ZERO. Rescan needed at least on "..reservation.chest_name..":"..reservation.slot)
                reservation.count += transferred
                if reservation.count == stackSize
                    used_output_reservations[#used_output_reservations+1] = reservation
                    table.remove(this_item_reservations, #this_item_reservations)
        for _,res in ipairs(used_input_reservations)
            if res.count == 0
                db\query(
                    "update stack set item_id = NULL, count = 0 where chest_computer = $1 and chest_name = $2 and slot = $3",
                    {ty: "int4", val: res.chest_computer},
                    {ty: "text", val: res.chest_name},
                    {ty: "int2", val: res.slot}
                )
            else
                db\query(
                    "update stack set count = $4 where chest_computer = $1 and chest_name = $2 and slot = $3",
                    {ty: "int4", val: res.chest_computer},
                    {ty: "text", val: res.chest_name},
                    {ty: "int2", val: res.slot},
                    {ty: "int4", val: res.count}
                )
        for _,res in ipairs(used_output_reservations)
            continue if res.count == 0
            db\query(
                "update stack set item_id = $1, count = $2 where chest_computer = $3 and chest_name = $4 and slot = $5",
                    {ty: "int4", val: res.item_id},
                    {ty: "int4", val: res.count},
                    {ty: "int4", val: res.chest_computer},
                    {ty: "text", val: res.chest_name},
                    {ty: "int2", val: res.slot}
            )
        db\query(
            "update job set finished = true where id = $1", 
            {ty: "int4", val: job_id}
        )
        db\query("commit")

parallel.waitForAll process, main