local mp = require"mp"

local Connection = {msgid_inc = 1}

function Connection:new(url)
  local conn = setmetatable({}, {__index = self})
  local res = {http.websocket(url)}
  if not res[1] then
    error(res[2])
  end
  conn.internal = res[1]
  return conn
end

function Connection:default()
  return self:new("ws://127.0.0.1:7648/")
end

function Connection:process()
  local data, isBinary = self.internal.receive()
  while data do
    --print(textutils.serialise{address=address, dataLen=#data, isBinary=isBinary})
    local parsed = mp.unpack(data)
    local message_name
    if data.ty == "notification" then
      message_name = "database_notification"
    else
      message_name = "database_message"
    end
    os.queueEvent(message_name, self, parsed)
    data, isBinary = self.internal.receive()
  end
end

function Connection:query(q, params)
  if params == nil then params = {} end
  local msgid = self.msgid_inc
  self.msgid_inc = msgid + 1
  setmetatable(params, {isSequence = true})
  self.internal.send(mp.pack{ty = "query", statement = q, params = params, msgid = msgid}, true)
  while true do
    local evName, connection, msg = os.pullEvent("database_message")
    if connection == self and (msg.ty == "results" or msg.ty == "error") and msg.msgid == msgid then
      if msg.ty == "results" then
        return true, msg.rows
      elseif msg.ty == "error" then
        return false, msg.msg
      end
    end
  end
end

function Connection:prepare(q)
  local msgid = self.msgid_inc
  self.msgid_ic = msgid + 1
  self.internal.send(mp.pack{ty = "prepare", statement = q, msgid = msgid}, true)
  while true do
    local evName, connection, msg = os.pullEvent("database_message")
    if connection == self and (msg.ty == "prepared" or msg.ty == "error") and msg.msgid == msgid then
      if msg.ty == "prepared" then
        return true, msg.id
      elseif msg.ty == "error" then
        return false, msg.msg
      end
    end
  end
end

function Connection:close()
  self.internal.close()
end

return Connection
