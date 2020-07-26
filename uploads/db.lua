local mp = require"mp"

local Connection = {msgid_inc = 1}

local conn_id = 1

function Connection:new(url)
  local conn = setmetatable({}, {__index = self})
  local res = {http.websocket(url)}
  if not res[1] then
    error(res[2])
  end
  conn.address = url
  conn.internal = res[1]
  conn.id = conn_id
  conn_id = conn_id + 1
  return conn
end

function Connection:default()
  return self:new("ws://127.0.0.1:7648/")
end

function Connection:process()
  while true do
    local evName, address, data, isBinary = os.pullEvent("websocket_message")
    --print(address)
    if address == self.address then
      local parsed = mp.unpack(data)
      local message_name
      if data.ty == "notification" then
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

function Connection:query(q, params)
  if params == nil then params = {} end
  local msgid = self.msgid_inc
  self.msgid_inc = msgid + 1
  setmetatable(params, {isSequence = true})
  --print"sending"
  self.internal.send(mp.pack{ty = "query", statement = q, params = params, msgid = msgid}, true)
  --print"sent; waiting"
  while true do
    local evName, connid, msg = os.pullEvent("database_message")
    --print("got ev " .. evName .. " ids " .. textutils.serialise{self.id,connid} .. " msg " .. textutils.serialise(msg) .. " othereq " .. textutils.serialise(msg.msgid == msgid))
    if self.id == connid and (msg.ty == "results" or msg.ty == "error") and msg.msgid == msgid then
      if msg.ty == "results" then
        return msg.rows
      elseif msg.ty == "error" then
        error(msg.msg)
      end
    end
  end
end

function Connection:prepare(q)
  local msgid = self.msgid_inc
  self.msgid_ic = msgid + 1
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
