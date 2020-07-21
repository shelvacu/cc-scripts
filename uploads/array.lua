--local Array = {}

local Array.mt = {}

function Array.mt.__index = function (table, key)
  table.

function Array:new(init)
  local private = {length = 0, values = {}}
  local mt = {}
  local f = {}
  function f:length()
    return private.length
  end
  function f:append(val)
    if type(val) == "nil" then
      error"cannot set to nil"
    end
    private.length = private.length + 1
    private.values[private.length] = val
  end
  function f:pop()
    local val = private.values[private.length]
    private.values[private.length] = nil
    private.length = private.length - 1
    return val
  end
  function f:first()
    return private.values[1]
  end
  function f:last()
    return private.values[private.length]
  end
  function f:pairs()
    local idx = 0
    return function()
      idx = idx + 1
      if idx <= private.length then
        return idx, private.values[idx]
      end
    end
  end
  f.ipairs = f.pairs
  function f:values()
    local idx = 0
    return function()
      idx = idx + 1
      if idx < private.length then
        return private.values[idx]
      end
    end
  end
  function f:map_inplace(func)
    for i,v in self:pairs() do
      self[i] = func(v)
    end
  end
  function f:map(func)
    local new = Array:new(self)
    new:map_inplace(func)
  end
  f.isSeq = true

  function mt.__index = function(table, key)
    if type(key) == "string" then
      return f[key]
    elseif type(key) ~= "number" then
      error"invalid key type"
    elseif key%1 == 0 then
      error"key must be integer"
    elseif key < 1 then
      error"key out of bounds"
    elseif key > private.length then
      error"key out of bounds"
    end
    return private.values[key]
  end
  function mt.__newindex = function(table, key, value)
    if type(key) ~= "number" then
      error"invalid key type"
    elseif a%1 ~= 0 then
      error"key must be integer"
    elseif key < 1 then
      error"key must be >= 1"
    elseif key > (private.length + 1) then
      error"key must be <= length+1"
    elseif type(value) == "nil" then
      error"cannot set to nil"
    end
    private.values[key] = value
    if key > private.length then
      private.length = key
    end
  end
  local checkArr = {}
  local maxVal = 0
  for k,v in pairs(init) do
    if type(k) ~= "number" then
      error"Bad key type"
    elseif k < 1 then
      error"Key out of range"
    elseif k%1 ~= 0 then
      error"Key is float"
    end
    if maxVal < k then maxVal = k end
    checkArr[k] = true
  end
  for i=1,maxVal do
    if not checkArr[i] then
      error"Non-sequential table"
    end
  end
  init = init or {}
  private.values = init
  private.length = maxVal
  return setmetatable({}, mt)
end

--function Array:length()


