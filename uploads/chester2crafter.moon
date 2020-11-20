-- must run in a crafty turtle connected to chest grid
-- turtle does not need fuel
-- turtle must have inventory introspection module and crafting table equippedpp
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
    )
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
        row = res[1]
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
                if item_outputs[slots[i]] == nil
                    item_outputs[slots[i]] = 0
                item_outputs[slots[i]] += 1
        for k,v in pairs(item_inputs)
            item_inputs[k] = v*quantity
        for k,v in pairs(item_outputs)
            item_outputs[k] = v*quantity
        input_reservations = {} -- item_id => {slot, qty}[]
        for item_id, quantity in pairs(item_inputs)
            stackSize = getStackSize(item_id)
            quantity_reserved = 0
            reservations = {}
            while quantity_reserved < quantity
                res = {}
                if quantity - quantity_reserved >= stackSize
                    res = db\query(
                        "select chest_computer, chest_name, slot, count from stack where item_id = $1 and count = $2 limit 1 for no key update skip locked",
                        {ty: "int4", val: item_id},
                        {ty: "int4", val: stackSize}
                    )
                if #res == 0
                    --do it again, but this any count
                    res = db\query(
                        "select chest_computer, chest_name, slot, count from stack where item_id = $1 limit 1 for no key update skip locked",
                        {ty: "int4", val: item_id}
                    )
                if #res == 0
                    --do it again, but this time don't SKIP LOCKED
                    res = db\query(
                        "select chest_computer, chest_name, slot, count from stack where item_id = $1 order by count desc limit 1 for no key update",
                        {ty: "int4", val: item_id}
                    )
                if #res == 0
                    db\query("rollback")
                    error("Bad job, not enough input available.")
                    return
                row = res[1]
                reservation = {
                    chest_computer: row[1],
                    chest_name: row[2],
                    slot: row[3],
                    count: row[4],
                    item_id: item_id
                }
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
                    "select chest_computer, chest_name, slot from stack where item_id IS NULL and count = 0 limit 1 for no key update skip locked"
                )
                if #res == 0
                    res = db\query(
                        "select chest_computer, chest_name, slot from stack where item_id IS NULL and count = 0 limit 1 for no key update"
                    )
                if #res == 0
                    db\query("rollback")
                    error("Not enough space in inventory")
                    return
                row = res[1]
                reservation = {
                    chest_computer: row[1],
                    chest_name: row[2],
                    slot: row[3],
                    count: 0,
                    item_id: item_id
                }
                reservations[#reservations + 1] = reservation
                quantity_reserved += stackSize
            output_reservations[item_id] = reservations
        used_input_reservations = {}
        for i=1,9
            continue if slot[i] == nil
            item_id = slot[i]
            turtle_slot = craftingSlotToTurtleSlot[i]
            while turtle.getItemCount(turtle_slot) < result_count
                reservation = input_reservations[item_id][#input_reservations]
                num_to_move = math.min(reservation.count, result_count - turtle.getItemCount(turtle_slot))
                chest = peripheral.wrap(reservation.chest_name)
                transferred = chest.pushItems(myName, reservation.slot, num_to_move, turtle_slot)
                if num_to_move ~= transferred
                    db\query("rollback")
                    error("Turtle crafter transfer failed! Expected "..num_to_move.." items pushed, instead "..transferred.." were pushed. Item#"..item_id..", from "..from_slot.." to " .. chest_name .. ":" .. to_slot .. ". Rescan needed.")
                    return
                reservation.count -= transferred
                if reservation.count == 0
                    used_input_reservations[#used_input_reservations + 1] = reservation
                    input_reservations[item_id][#input_reservations[item_id]] = nil
        --After a billion years of preparation, we're finally ready
        --DO. THE. CRAFT
        res = turtle.craft()
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
            this_item_reservations = output_reservations[actual_item_id]
            while turtle.getItemCount(i) > 0
                reservation = this_item_reservations[#this_item_reservations]
                c = peripheral.wrap(reservation.chest_name)
                transferred = c.pullItems(myName, i, stackSize - reservation.count, reservation.slot)
                reservation.count += transferred
                if reservation.count == stackSize
                    used_output_reservations[#used_output_reservations+1] = reservation
                    this_item_reservations[#this_item_reservations] = nil
        for _,res in ipairs(used_input_reservations)
            if res.count == 0
                db.query(
                    "update stack set item_id = NULL, count = 0 where chest_computer = $1 and chest_name = $2 and slot = $3",
                    {ty: "int4", val: res.chest_computer},
                    {ty: "int4", val: res.chest_name},
                    {ty: "int4", val: res.slot}
                )
            else
                db.query(
                    "update stack set count = $4 where chest_computer = $1 and chest_name = $2 and slot = $3",
                    {ty: "int4", val: res.chest_computer},
                    {ty: "int4", val: res.chest_name},
                    {ty: "int4", val: res.slot},
                    {ty: "int4", val: res.count}
                )
        for _,res in ipairs(used_output_reservations)
            continue if res.count == 0
            db.query(
                "update stack set item_id = $1, count = $2 where chest_computer = $3 and chest_name = $4 and slot = $5",
                    {ty: "int4", val: res.item_id},
                    {ty: "int4", val: res.count},
                    {ty: "int4", val: res.chest_computer},
                    {ty: "int4", val: res.chest_name},
                    {ty: "int4", val: res.slot}
            )
        db\query(
            "update job set finished = true where id = $1", 
            {ty: "int4", val: job_id}
        )
        db\query("commit")

parallel.waitForAll process, main