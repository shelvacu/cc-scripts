-- This reads and writes files hopefully in a way such that it is atomic; Every change either happens or doesn't even in the case of a sudden shutdown/abort/whatever
-- This is achieved by using two files, <file>.old and <file>.new
-- Writing looks like such (assuming old data in <file>.old already exists):
-- * Create empty file <file>.new
-- * Write messagePack data to <file>.new. When the last byte is finished writing, the data is considered comitted.
-- * Delete <file>.old
-- * Rename/move <file>.new to <file>.old
--
--
-- Recovery looks like:
-- * Look for <file>.new; If it exists and contains "complete" data:
--   * Delete <file>.old if exists
--   * Rename/move <file>.new to <file>.old
-- * Otherwise, delete <file>.new if it exists

local mp = require "mp"

local exports = {}

exports.oldPostfix = ".old"
exports.newPostfix = ".new"

-- https://stackoverflow.com/a/10387949/1267729
local function readAll(file)
  local f = assert(io.open(file, "rb"))
  local content = f:read("*all")
  f:close()
  return content
end

function exports.exists(name)
  local oldName = name .. exports.oldPostfix
  local newName = name .. exports.newPostfix
  return fs.exists(oldName) or fs.exists(newName)
end

exports.exist = exports.exists
  
-- Returns whether there were any files needing recovery
function exports.recover(name)
  local oldName = name .. exports.oldPostfix
  local newName = name .. exports.newPostfix
  if fs.exists(newName) then
    local content = readAll(newName)
    local data, remaining = mp.unpack(content)
    if not remaining or #remaining > 0 then
      -- this file is bogus
      fs.delete(newName)
    else
      fs.delete(oldName)
      fs.move(newName, oldName)
    end
    return true
  end
  return false
end
    
function exports.write(name, data)
  local rawData = {mp.packArr(data)}
  local oldName = name .. exports.oldPostfix
  local newName = name .. exports.newPostfix
  exports.recover(name)
  local f = assert(io.open(newName, "wb"))
  for _,v in ipairs(rawData) do
    f:write(v)
  end
  --f:write(table.concat(rawData))
  f:close()
  fs.delete(oldName)
  fs.move(newName, oldName)
  return true
end

function exports.read(name)
  assert(name)
  local oldName = name .. exports.oldPostfix
  exports.recover(name)
  local data, remaining = mp.unpack(readAll(oldName))
  assert(remaining)
  assert(#remaining == 0)
  return data
end

return exports
