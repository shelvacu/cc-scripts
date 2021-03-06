local vstruct = require"vstruct"
local unicode = require"unicode"

local f4 = vstruct.compile(">f4")
local f8 = vstruct.compile(">f8")

local function isInt(n)
  return math.floor(n) == n and n < 2^64 and -(2^63) < n
end

-- Config docs
-- recode:bool
--   when true: convert CC -> unicode when packing and unicode -> CC when unpacking
--   default: no conversion
-- convertNull:bool
--   when true: converts any CC nulls to U+2400 "symbol for null" on pack. Has no effect on unpack, or when recode is false
--   default: no conversion

local mp = {}

local function messagePackImpl(val, config)
  local ty = type(val)
  if ty == "number" then
    if isInt(val) then
      if val >= 0 and val < 2^7 then
        return string.char(val)
      elseif val >= 0 and val < 2^8 then
        return string.char(0xcc, val)
      elseif val >= 0 and val < 2^16 then
        return string.char(0xcd, bit.blogic_rshift(val, 8), bit.band(val, 0xff))
      elseif val >= 0 and val < 2^32 then
        return string.char(
          0xce,
          bit.blogic_rshift(val, 24),
          bit.band(bit.blogic_rshift(val, 16), 0xff),
          bit.band(bit.blogic_rshift(val, 8), 0xff),
          bit.band(val, 0xff)
        )
      elseif val >= 0 then -- value is assured to be < 2^64 in isInt
        error("not supported")
        return string.char(
          0xcf,
          bit.blogic_rshift(val, 56),
          bit.band(bit.blogic_rshift(val, 48), 0xff),
          bit.band(bit.blogic_rshift(val, 40), 0xff),
          bit.band(bit.blogic_rshift(val, 32), 0xff),
          bit.band(bit.blogic_rshift(val, 24), 0xff),
          bit.band(bit.blogic_rshift(val, 16), 0xff),
          bit.band(bit.blogic_rshift(val, 8), 0xff),
          bit.band(val, 0xff)
        )
      elseif val >= -2^5 then
        return string.char(0x100 + val)
      elseif val >= -2^7 then
        return string.char(0xd0, 0x100 + val)
      elseif val >= -2^15 then
        local uns = 2^16 + val
        return string.char(0xd1, bit.blogic_rshift(uns, 8), bit.band(uns, 0xff))
      elseif val >= -2^31 then
        local uns = 2^32 + val
        return string.char(
          0xd2,
          bit.blogic_rshift(uns, 24),
          bit.band(bit.blogic_rshift(uns, 16), 0xff),
          bit.band(bit.blogic_rshift(uns, 8), 0xff),
          bit.band(uns, 0xff)
        )
      else -- value is assured to be > -2^63 in isInt
        error("not supported")
        local uns = 2^64 + val
        return string.char(
          0xd3,
          bit.blogic_rshift(uns, 56),
          bit.band(bit.blogic_rshift(uns, 48), 0xff),
          bit.band(bit.blogic_rshift(uns, 40), 0xff),
          bit.band(bit.blogic_rshift(uns, 32), 0xff),
          bit.band(bit.blogic_rshift(uns, 24), 0xff),
          bit.band(bit.blogic_rshift(uns, 16), 0xff),
          bit.band(bit.blogic_rshift(uns, 8), 0xff),
          bit.band(uns, 0xff)
        )
      end
    else -- float
      return string.char(0xcb) .. f8:write{val}
    end
  elseif ty == "nil" then
    return string.char(0xc0)
  elseif ty == "boolean" then
    if val then
      return string.char(0xc3)
    else
      return string.char(0xc2)
    end
  elseif ty == "string" then
    if config.recode and not unicode.symmetric(val) then
      val = unicode.convertToUnicode(val, config.convertNull)
    end
    local len = #val
    local prefix
    if len <= 31 then
      prefix = string.char(bit.bor(0xa0, len))
    elseif len <= 255 then
      prefix = string.char(0xd9, len)
    elseif len <= 2^16-1 then
      prefix = string.char(0xda, bit.blogic_rshift(len, 8), bit.band(len, 0xff))
    elseif len <= 2^32-1 then
      prefix = string.char(
        0xdb,
        bit.blogic_rshift(len, 24),
        bit.band(bit.blogic_rshift(len, 16), 0xff),
        bit.band(bit.blogic_rshift(len, 8), 0xff),
        bit.band(len, 0xff)
      )
    else
      error("string too long! " .. len .. " bytes!")
    end
    return prefix .. val
  elseif ty == "table" then
    local mt = getmetatable(val)
    --if type(mt) == "table" then
    --  print("mt:"..textutils.serialise(mt))
    --end
    if type(mt) == "table" and mt.isSequence then --assume array-like table
      local len = #val
      local prefix
      if len <= 15 then
        prefix = string.char(bit.bor(0x90, len))
      elseif len <= 2^16-1 then
        prefix = string.char(0xdc, bit.blogic_rshift(len, 8), bit.band(len, 0xff))
      elseif len <= 2^32-1 then
        prefix = string.char(
          0xdd,
          bit.blogic_rshift(len, 24),
          bit.band(bit.blogic_rshift(len, 16), 0xff),
          bit.band(bit.blogic_rshift(len, 8), 0xff),
          bit.band(len, 0xff)
        )
      end
      --local res = prefix
      local res = {}
      local iters = 0
      for idx, val in ipairs(val) do
        res[iters+1] = messagePackImpl(val,config)
        if math.fmod(iters,1000) == 0 then sleep(0) end
        iters = iters + 1
      end
      if iters ~= len then
        error("malformed array-like table")
      end
      return prefix .. table.concat(res)
    elseif type(mt) == "table" and mt.isConfigWrapper then
      local newconfig = setmetatable(val.newConfig, {__index = config})
      --print("configwrapped, new config: "..textutils.serialise(newconfig))
      --print("inner: "..textutils.serialise(val.val))
      return messagePackImpl(val.val, newconfig)
    else -- assume hashmap-like table
      local len = 0
      local prefix
      local res = {} 
      for k,v in pairs(val) do
        res[(len*2)+1] = messagePackImpl(k, config)
        res[(len*2)+2] = messagePackImpl(v, config)
        --sleep(0)
        len = len + 1
      end
      if len <= 15 then
        prefix = string.char(bit.bor(len, 0x80))
      elseif len <= 2^15-1 then
        prefix = string.char(0xde, bit.blogic_rshift(len, 8), bit.band(len, 0xff))
      elseif len <= 2^31-1 then
        prefix = string.char(
          0xdf,
          bit.blogic_rshift(len, 24),
          bit.band(bit.blogic_rshift(len, 16), 0xff),
          bit.band(bit.blogic_rshift(len, 8), 0xff),
          bit.band(len, 0xff)
        )
      end
      return prefix .. table.concat(res)
    end
  else
    error("cannot pack data type "..ty)
  end
end

local function messagePack(data, config)
  if config == nil then
    config = {}
  end
  return messagePackImpl(data, config) --table.concat({messagePackImpl(data)})
end

mp.pack = messagePack

local messageUnpack = nil

local function unpack8(data)
  if #data < 1 then
    return nil, nil
  end
  return string.byte(data, 1), string.sub(data, 2, -1)
end

local function unpack16(data)
  if #data < 2 then
    return nil, nil
  end
  return bit.blshift(string.byte(data, 1), 8) + string.byte(data,2), string.sub(data, 3, -1)
end

local function unpack32(data)
  if #data < 4 then
    return nil, nil
  end
  return bit.blshift(string.byte(data, 1), 24) +
    bit.blshift( string.byte(data, 2), 16 ) +
    bit.blshift( string.byte(data, 3), 8  ) +
    string.byte(data, 4), string.sub(data, 5, -1)
end

local function unpack64(data)
  error("not supported")
  if #data < 8 then
    return nil, nil
  end
  return bit.blshift(string.byte(data, 1), 56) +
    bit.blshift( string.byte(data, 2), 48 ) +
    bit.blshift( string.byte(data, 3), 40 ) +
    bit.blshift( string.byte(data, 4), 32 ) +
    bit.blshift( string.byte(data, 5), 24 ) +
    bit.blshift( string.byte(data, 6), 16 ) +
    bit.blshift( string.byte(data, 7), 8  ) +
    string.byte(data, 8), string.sub(data, 9, -1)
end

local function unpackMap(len, data, config)
  local remaining = data
  local res = {}
  for i=1,len do
    local key
    local value
    key, remaining = messageUnpack(remaining, config)
    if not remaining then return end
    value, remaining = messageUnpack(remaining, config)
    if not remaining then return end
    res[key] = value
  end
  return res, remaining
end

local function unpackArray(len, data, config)
  local remaining = data
  local res = {}
  for i=1,len do
    local value
    value, remaining = messageUnpack(remaining, config)
    if not remaining then
      return nil, nil
    end
    res[i] = value
  end
  setmetatable(res,{isSequence = true})
  return res, remaining
end

local function unpackStr(len, data, bin, config)
  if #data < len then
    return nil, nil
  end
  local res = string.sub(data, 1, len)
  if not bin and config.recode and not unicode.symmetric(val) then
    res = unicode.convertToCC(res)
  end
  return res, string.sub(data, len+1, -1)
end

local function signed(unsigned, bits)
  if unsigned < 2^(bits-1) then
    return unsigned
  else
    return unsigned - (2^bits)
  end
end

messageUnpack = function(data, config)
  if config == nil then
    config = {}
  end
  local first = string.byte(string.sub(data, 1, 1))
  if not first then
    return nil, nil
  end
  local remaining = string.sub(data, 2, -1)
  if first < 2^7 then
    return first, remaining
  elseif first < 0x90 then --fixmap, last 4 bits
    return unpackMap(bit.band(first, 0x0f), remaining, config)
  elseif first < 0xa0 then --fixarray, last 4
    return unpackArray(bit.band(first, 0x0f), remaining, config)
  elseif first < 0xc0 then --fixstr, last 5
    return unpackStr(bit.band(first, 0x1f), remaining, false, config)
  elseif first == 0xc0 then
    return nil, remaining
  elseif first == 0xc1 then
    error("Bad value 0xc1")
  elseif first == 0xc2 then
    return false, remaining
  elseif first == 0xc3 then
    return true, remaining
  elseif first == 0xc4 then --bin8
    local len
    len, remaining = unpack8(remaining)
    if not remaining then return end
    return unpackStr(len, remaining, true, config)
  elseif first == 0xc5 then --bin16
    local len
    len, remaining = unpack16(remaining)
    if not remaining then return end
    return unpackStr(len, remaining, true, config)
  elseif first == 0xc6 then --bin32
    local len
    len, remaining = unpack32(remaining)
    if not remaining then return end
    return unpackStr(len, remaining, true, config)
  elseif first < 0xca then --extensions, blegh
    error("ext not supported")
  elseif first == 0xca then --float 32bit/4byte
    local res = {}
    if #remaining < 4 then
      return nil,nil
    end
    f4:read(remaining, res)
    return res[1], string.sub(remaining,5,-1)
  elseif first == 0xcb then --float 64bit/8byte
    local res = {}
    if #remaining < 8 then
      return nil, nil
    end
    f8:read(remaining, res)
    return res[1], string.sub(remaining,9,-1)
  elseif first == 0xcc then
    return unpack8(remaining)
  elseif first == 0xcd then
    return unpack16(remaining)
  elseif first == 0xce then
    return unpack32(remaining)
  elseif first == 0xcf then
    return unpack64(remaining)
  elseif first == 0xd0 then
    local res
    res, remaining = unpack8(remaining)
    if not remaining then return end
    return signed(res, 8), remaining
  elseif first == 0xd1 then
    local res
    res, remaining = unpack16(remaining)
    if not remaining then return end
    return signed(res, 16), remaining
  elseif first == 0xd2 then
    local res
    res, remaining = unpack32(remaining)
    if not remaining then return end
    return signed(res, 32), remaining
  elseif first == 0xd3 then
    local res
    res, remaining = unpack64(remaining)
    if not remaining then return end
    return signed(res, 64), remaining
  elseif first < 0xd9 then
    error("extensions not supported")
  elseif first == 0xd9 then
    local len
    len, remaining = unpack8(remaining)
    if not remaining then return end
    return unpackStr(len, remaining, false, config)
  elseif first == 0xda then
    local len
    len, remaining = unpack16(remaining)
    if not remaining then return end
    return unpackStr(len, remaining, false, config)
  elseif first == 0xdb then
    local len
    len, remaining = unpack32(remaining)
    if not remaining then return end
    return unpackStr(len, remaining, false, config)
  elseif first == 0xdc then
    local len
    len, remaining = unpack16(remaining)
    if not remaining then return end
    return unpackArray(len, remaining, config)
  elseif first == 0xdd then
    local len
    len, remaining = unpack32(remaining)
    if not remaining then return end
    return unpackArray(len, remaining, config)
  elseif first == 0xde then
    local len
    len, remaining = unpack16(remaining)
    if not remaining then return end
    return unpackMap(len, remaining, config)
  elseif first == 0xdf then
    local len
    len, remaining = unpack32(remaining)
    if not remaining then return end
    return unpackMap(len, remaining, config)
  else -- 0xe0 <= first <= 0xff
    return signed(bit.band(first, 0x1f), 5), remaining
  end
end

mp.unpack = messageUnpack

local function clone(data)
  local res = {mp.unpack(mp.pack(data))}
  return res[1]
end

mp.clone = clone

mp.configWrapper = function(val, config)
  return setmetatable({val = val, newConfig = config}, {isConfigWrapper = true})
end

return mp
