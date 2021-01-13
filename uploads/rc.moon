require("paranoidLogger")("rc")
require("shellib")
db = require("db")\default!

tArgs = {...}
channel = tArgs[1]

if channel == nil or channel == ""
    error("bad channel")

getGlobalOffset()


selectItem = ->
    for i=1,16
        break unless turtle.getItemCount() == 0
        sel = turtle.getSelectedSlot()
        sel = sel + 1
        if sel == 17
            sel = 1
        turtle.select(sel)

control_channel = "turtle_rc_control"
feedback_channel = "turtle_rc_feedback"

process = -> db\process!

main = ->
    db\query("listen "..control_channel)
    while true
        evName, id, parsed = os.pullEvent("database_notification")
        print(textutils.serialise(parsed))
        continue if id ~= db.id
        continue if parsed.channel ~= control_channel
        payload = textutils.unserializeJSON(parsed.payload)
        print(textutils.serialise(payload))
        continue if payload.channel ~= channel
        local res
        if payload.cmd == "up"
            res = tryUp()
        else if payload.cmd == "down"
            res = tryDown()
        else if payload.cmd == "forward"
            res = tryForward()
        else if payload.cmd == "back"
            res = tryBack()
        else if payload.cmd == "left"
            turnLeft()
            res = true
        else if payload.cmd == "right"
            turnRight()
            res = true
        else if payload.cmd == "dig_up"
            res = {turtle.digUp()}
        else if payload.cmd == "dig_fwd"
            res = {turtle.dig()}
        else if payload.cmd == "dig_down"
            res = {turtle.digDown()}
        else if payload.cmd == "place_up"
            selectItem()
            res = {turtle.placeUp()}
        else if payload.cmd == "place_fwd"
            selectItem()
            res = {turtle.place()}
        else if payload.cmd == "place_down"
            selectItem()
            res = {turtle.placeDown()}
        else
            --print("warn: unrecognized command")
            --res = false
            res = "warn: unrecognized command"
        inventory = {}
        for i=1,16
            inventory[i] = (turtle.getItemDetail(i) or {count: 0})
        response = textutils.serializeJSON({
            cmd: payload.cmd,
            position: globalPosition(),
            fuel: turtle.getFuelLevel(),
            :inventory,
            :res,
            :channel
        })
        db\query("select pg_notify($1, $2)::text",{ty:"text",val: feedback_channel},{ty: "text", val: response})

parallel.waitForAny(process, main)