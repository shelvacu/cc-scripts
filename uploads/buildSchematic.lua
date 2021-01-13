require("paranoidLogger")("buildSchematic")
local nbt = require("nbt")
local dblib = require("db")
local db = dblib:default()
local tArgs = {
  ...
}
local fn = tArgs[1]
local h, err = fs.open(fn, "rb")
if h == nil then
  error(err)
end
local dataBytes = h:readAll()
local dataNbt = nbt(dataBytes)
print("finished reading nbt")
for k, v in pairs(dataNbt) do
  print(k)
end
local schematic = dataNbt
if schematic.Entities ~= nil then
  print("Ignoring " .. (#schematic.Entities) .. " entities")
end
local oppositeMapping = { }
for k, v in pairs(schematic.SchematicaMapping) do
  oppositeMapping[v] = k
end
local item_counts = { }
for i, b in ipairs(schematic.Blocks) do
  if math.fmod(i, 1024) == 0 then
    sleep()
  end
  local d = schematic.Data[i]
  local key = oppositeMapping[b] .. ":" .. d
  if item_counts[key] == nil then
    item_counts[key] = 0
  end
  item_counts[key] = item_counts[key] + 1
end
for k, v in pairs(item_counts) do
  local key = k
  if key == nil then
    key = "nil:" .. k
  end
  print(key .. "=>" .. v)
end
