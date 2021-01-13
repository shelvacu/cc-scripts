local v = require "vstruct"
v.cache = true
-- consts

TAG_END =        0
TAG_BYTE =       1
TAG_SHORT =      2
TAG_INT =        3
TAG_LONG =       4
TAG_FLOAT =      5
TAG_DOUBLE =     6
TAG_BYTE_ARRAY = 7
TAG_STRING =     8
TAG_LIST =       9
TAG_COMPOUND =   10
TAG_INT_ARRAY =  11
TAG_LONG_ARRAY = 12

--unsigned types (not part of official spec)
TAG_UBYTE =      21
TAG_USHORT =     22
TAG_UINT =       23

--always big-endian ">"

local function read_tag_head(from, data)
  --print("reading tag head from "..from.pos)
  if data == nil then data = {} end
  data.tag_id = v.readvals(">i1", from)
  if data.tag_id == TAG_END then
    data.name = ""
  else
    data.name = v.readvals(">c2", from)
    --print("reading "..data.tag_id..":"..data.name)
  end
  return data
end

local read_tag_data = nil

local function read_tag(from, data)
  --print("reading tag at "..from.pos)
  if data == nil then data = {} end
  read_tag_head(from, data)
  data.val = read_tag_data(data.tag_id, from)
  return data
end

read_tag_data = function (tag_id, from)
  --print("reading data at "..from.pos)
  if tag_id == TAG_END then
    return nil
  elseif tag_id == TAG_BYTE then
    return v.readvals(">i1", from)
  elseif tag_id == TAG_SHORT then
    return v.readvals(">i2", from)
  elseif tag_id == TAG_INT then
    return v.readvals(">i4", from)
  elseif tag_id == TAG_LONG then
    return v.readvals(">i8", from)
  elseif tag_id == TAG_FLOAT then
    return v.readvals(">f4", from)
  elseif tag_id == TAG_DOUBLE then
    return v.readvals(">f8", from)
  elseif tag_id == TAG_BYTE_ARRAY then
    local sizeBytes = from:read(4)
    --for i=1,#sizeBytes do
    --  print(string.format("%02X", string.byte(sizeBytes, i)))
    --end
    local size = v.readvals(">i4", sizeBytes)
    --print("reading byte array of size "..size)
    local res = {}
    for i=1,size do
      if math.fmod(i,1024) == 0 then sleep() end
      res[i] = v.readvals(">u1", from)
    end
    res.n = size
    return res
  elseif tag_id == TAG_STRING then
    return v.readvals(">c2", from)
  elseif tag_id == TAG_LIST then
    local inner_tag_id = v.readvals(">i1", from)
    local size = v.readvals(">i4", from)
    local res = {tag = inner_tag_id}
    for i=1,size do
      res[i] = read_tag_data(inner_tag_id, from)
    end
    res.n = size
    return res
  elseif tag_id == TAG_COMPOUND then
    local res = {}
    local itercount = 1
    while true do
      if math.fmod(itercount, 1024) then sleep() end
      local tag = read_tag(from)
      if tag.tag_id == TAG_END then
        break
      end
      res[tag.name] = tag.val
      itercount = itercount + 1
    end
    return res
  elseif tag_id == TAG_INT_ARRAY then
    local res = {}
    local size = v.readvals(">i4", from)
    for i=1,size do
      res[i] = v.readvals(">i4", from)
    end
    res.n = size
    return res
  elseif tag_id == TAG_LONG_ARRAY then
    local res = {}
    local size = v.readvals(">i4", from)
    for i=1,size do
      res[i] = v.readvals(">i8", from)
    end
    res.n = size
    return res
  elseif tag_id == TAG_UBYTE then
    return v.readvals(">u1")
  elseif tag_id == TAG_USHORT then
    return v.readvals(">u2")
  elseif tag_id == TAG_UINT then
    return v.readvals(">u4")
  else
    error("Unrecognized NBT tag id "..tag_id)
  end
end

return function(string_or_file)
  local from
  if type(string_or_file) == "string" then
    from = v.cursor(string_or_file)
  else
    from = string_or_file
  end
  return read_tag(from).val
end
