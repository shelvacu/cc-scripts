local tArgs = {...}

local v = tArgs[1]
local name = v..".lua"
local dir = fs.getDir(name)
if dir ~= "" and not fs.exists(dir) then
  fs.makeDir(dir)
end
if not fs.isDir(dir) then
  error(dir .. " already exists and is not a directory")
end
local exists = fs.exists(name)
if exists then
  shell.run("mv", name, name .. ".old")
end
if shell.run("wget", "https://github.com/shelvacu/cc-scripts/raw/master/uploads/"..name, name) then
  if exists then
    shell.run("rm", name .. ".old")
  end
else
  print("Failed to grab!")
  if exists then
    shell.run("mv", name .. ".old", name)
  end
end

shell.run(...)
