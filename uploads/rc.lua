require("paranoidLogger")("rc")
require("shellib")
local db = require("db"):default()
local tArgs = {
  ...
}
local channel = tArgs[1]
if channel == nil or channel == "" then
  error("bad channel")
end
getGlobalOffset()
local selectItem
selectItem = function()
  for i = 1, 16 do
    if not (turtle.getItemCount() == 0) then
      break
    end
    local sel = turtle.getSelectedSlot()
    sel = sel + 1
    if sel == 17 then
      sel = 1
    end
    turtle.select(sel)
  end
end
local control_channel = "turtle_rc_control"
local feedback_channel = "turtle_rc_feedback"
local process
process = function()
  return db:process()
end
local main
main = function()
  db:query("listen " .. control_channel)
  while true do
    local _continue_0 = false
    repeat
      local evName, id, parsed = os.pullEvent("database_notification")
      print(textutils.serialise(parsed))
      if id ~= db.id then
        _continue_0 = true
        break
      end
      if parsed.channel ~= control_channel then
        _continue_0 = true
        break
      end
      local payload = textutils.unserializeJSON(parsed.payload)
      print(textutils.serialise(payload))
      if payload.channel ~= channel then
        _continue_0 = true
        break
      end
      local res
      if payload.cmd == "up" then
        res = tryUp()
      else
        if payload.cmd == "down" then
          res = tryDown()
        else
          if payload.cmd == "forward" then
            res = tryForward()
          else
            if payload.cmd == "back" then
              res = tryBack()
            else
              if payload.cmd == "left" then
                turnLeft()
                res = true
              else
                if payload.cmd == "right" then
                  turnRight()
                  res = true
                else
                  if payload.cmd == "dig_up" then
                    res = {
                      turtle.digUp()
                    }
                  else
                    if payload.cmd == "dig_fwd" then
                      res = {
                        turtle.dig()
                      }
                    else
                      if payload.cmd == "dig_down" then
                        res = {
                          turtle.digDown()
                        }
                      else
                        if payload.cmd == "place_up" then
                          selectItem()
                          res = {
                            turtle.placeUp()
                          }
                        else
                          if payload.cmd == "place_fwd" then
                            selectItem()
                            res = {
                              turtle.place()
                            }
                          else
                            if payload.cmd == "place_down" then
                              selectItem()
                              res = {
                                turtle.placeDown()
                              }
                            else
                              res = "warn: unrecognized command"
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
      local inventory = { }
      for i = 1, 16 do
        inventory[i] = (turtle.getItemDetail(i) or {
          count = 0
        })
      end
      local response = textutils.serializeJSON({
        cmd = payload.cmd,
        position = globalPosition(),
        fuel = turtle.getFuelLevel(),
        inventory = inventory,
        res = res,
        channel = channel
      })
      db:query("select pg_notify($1, $2)::text", {
        ty = "text",
        val = feedback_channel
      }, {
        ty = "text",
        val = response
      })
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
end
return parallel.waitForAny(process, main)
