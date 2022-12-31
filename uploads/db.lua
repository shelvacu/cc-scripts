--v2
local mp = require"mp"

local Connection = {msgid_inc = 1}

local conn_id = 1

--local doDebug = settings.get("db.debug", false)
local doDebug = true

if paraLog == nil then
  error("paraLog required")
end

function Connection:new(url, use_id)
  if doDebug then
    paraLog.log("Connecting to", url)
  end
  local conn = setmetatable({}, {__index = self})
  local res = {http.websocket(url)}
  if not res[1] then
    error(res[2])
  end
  conn.msgid_inc = 1
  conn.address = url
  conn.internal = res[1]
  if use_id == nil then
    conn.id = conn_id
    conn_id = conn_id + 1
  else
    conn.id = use_id
  end
  return conn
end

function Connection:default(pass)
  if pass == nil then
    pass = fs.open("dbpass","r"):readAll()
  end
  if string.byte(pass, #pass) == 10 then --if last char is a newline
    pass = string.sub(pass, 1, #pass - 1) --chop off the newline
  end
  local this_id = conn_id
  conn_id = conn_id + 1
  --return self:new("wss://zakxkoyodg.shelvacu.com/?"..this_id, this_id)
  return self:new("wss://user:"..pass.."@zakxkoyodg.shelvacu.com/?"..this_id, this_id)
end

function Connection:process()
  if doDebug then
    paraLog.log("Connection:process running for",self.address)
  end
  while true do
    local evName, address, data, isBinary = os.pullEvent("websocket_message")
    if address == self.address then
      local parsed = mp.unpack(data)
      local message_name
      --print(#data)
      --if doDebug then
      --  paraLog.log("parsed", textutils.serialise(parsed))
      --end
      if parsed.ty == "error" and parsed.id == nil then
        paraLog.die("Error from server:", parsed.msg)
      end
      if parsed.ty == "notification" then
        --print("got notification " .. textutils.serialise(parsed))
        message_name = "database_notification"
      else
        message_name = "database_message"
      end
      os.queueEvent(message_name, self.id, parsed)
    end
  end
      
  -- local data, isBinary = self.internal.receive()
  -- while data do
  --   --print(textutils.serialise{address=address, dataLen=#data, isBinary=isBinary})
  --   local parsed = mp.unpack(data)
  --   --print("got some data "..textutils.serialise(parsed))
  --   local message_name
  --   if data.ty == "notification" then
  --     message_name = "database_notification"
  --   else
  --     message_name = "database_message"
  --   end
  --   os.queueEvent(message_name, self.id, parsed)
  --   data, isBinary = self.internal.receive()
  -- end
end

function Connection:query(q, ...)
  --if params == nil then params = {} end
  local tArgs = {...}
  if doDebug then
    paraLog.logbt("Connection:query", tArgs)
  end
  local params = mp.configWrapper(setmetatable(tArgs, {isSequence = true}), {recode = true, convertNull = true})
  local msgid = self.msgid_inc or 1
  if doDebug then
    paraLog.log("msgid", msgid)
  end
  self.msgid_inc = msgid + 1
  --print"sending"
  local the_msg = {ty = "query", statement = q, params = params, msgid = msgid}
  if doDebug then
    paraLog.log("the_msg", the_msg)
  end
  self.internal.send(mp.pack(the_msg), true)
  --print"sent; waiting"
  while true do
    local evName, connid, msg = os.pullEvent("database_message")
    --print("got ev " .. evName .. " ids " .. textutils.serialise{self.id,connid} .. " msg " .. textutils.serialise(msg) .. " othereq " .. textutils.serialise(msg.msgid == msgid))
    if self.id == connid and (msg.ty == "results" or msg.ty == "error") and msg.msgid == msgid then
      if msg.ty == "results" then
        return msg.rows
      elseif msg.ty == "error" then
        paraLog.die("db error",msgid, msg.msg)
      end
    end
  end
end

function Connection:prepare(q)
  local msgid = self.msgid_inc
  self.msgid_inc = msgid + 1
  self.internal.send(mp.pack{ty = "prepare", statement = q, msgid = msgid}, true)
  while true do
    local evName, connid, msg = os.pullEvent("database_message")
    print(msg.ty)
    if connid == self.id and (msg.ty == "prepared" or msg.ty == "error") and msg.msgid == msgid then
      if msg.ty == "prepared" then
        return msg.id
      elseif msg.ty == "error" then
        error(msg.msg)
      end
    end
  end
end

function Connection:close()
  self.internal.close()
end

return Connection
