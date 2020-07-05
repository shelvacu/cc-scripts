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

local mp = require "mpConcat"
local t = require "timings"

local exports = {}

exports.oldPostfix = ".old"
exports.newPostfix = ".new"

-- https://stackoverflow.com/a/10387949/1267729
local function readAll(file)
  t.start("openreadclose "..file)
  t.start("open "..file)
  local f = assert(io.open(file, "rb"))
  t.finish()
  t.start("read "..file)
  local content = f:read("*all")
  t.finish()
  t.start("close "..file)
  f:close()
  t.finish()
  t.finish()
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
  t.start("recover "..name)
  local oldName = name .. exports.oldPostfix
  local newName = name .. exports.newPostfix
  if fs.exists(newName) then
    t.start("recoverif "..name)
    local content = readAll(newName)
    local data, remaining = mp.unpack(content)
    if not remaining or #remaining > 0 then
      -- this file is bogus
      fs.delete(newName)
    else
      fs.delete(oldName)
      fs.move(newName, oldName)
    end
    t.finish()
    t.finish()
    return true
  end
  t.finish()
  return false
end
    
function exports.write(name, data)
  t.start("writeaf "..name)
  t.start("pack "..name)
  local rawData = {mp.packArr(data)}
  t.finish()
  local oldName = name .. exports.oldPostfix
  local newName = name .. exports.newPostfix
  exports.recover(name)
  t.start("openaf "..name)
  local f = assert(io.open(newName, "wb"))
  t.finish()
  t.start("write rawData "..name)
  for _,v in ipairs(rawData) do
    f:write(v)
  end
  t.finish()
  --f:write(table.concat(rawData))
  t.start("closeaf "..name)
  f:close()
  t.finish()
  t.start("deletemove "..name)
  fs.delete(oldName)
  fs.move(newName, oldName)
  t.finish()
  t.finish()
  return true
end

function exports.read(name)
  assert(name)
  t.start("readaf "..name)
  local oldName = name .. exports.oldPostfix
  exports.recover(name)
  local data, remaining = mp.unpack(readAll(oldName))
  assert(remaining)
  assert(#remaining == 0)
  t.finish()
  return data
end

return exports
