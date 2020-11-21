local mp = require"mp"

local Connection = {msgid_inc = 1}

local conn_id = 1

local doDebug = settings.get("db.debug", false)

function Connection:new(url, use_id)
  if doDebug then
    print("Connecting to "..url)
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

function Connection:default()
  local this_id = conn_id
  conn_id = conn_id + 1
  return self:new("ws://10.244.65.57:7648/?"..this_id, this_id)
end

function Connection:process()
  if doDebug then
    print("process running for "..self.address)
  end
  while true do
    local evName, address, data, isBinary = os.pullEvent("websocket_message")
    if doDebug then
      print(address)
    end
    if address == self.address then
      local parsed = mp.unpack(data)
      local message_name
      --print(#data)
      if doDebug then
        print(textutils.serialise(parsed))
      end
      if parsed.ty == "error" and parsed.id == nil then
        error("Error from server: " .. parsed.msg)
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
    print(debug.traceback())
    print("original args "..textutils.serialise(tArgs))
  end
  local params = mp.configWrapper(setmetatable(tArgs, {isSequence = true}), {recode = true, convertNull = true})
  local msgid = self.msgid_inc or 1
  if doDebug then
    print("Sending query "..msgid.." with "..(#params.val).." params")
    print("  Query: "..q);
  end
  self.msgid_inc = msgid + 1
  --print"sending"
  local the_msg = {ty = "query", statement = q, params = params, msgid = msgid}
  if doDebug then
    print(textutils.serialise(the_msg))
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
        error(msg.msg)
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
