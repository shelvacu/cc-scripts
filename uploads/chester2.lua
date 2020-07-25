local db = require("db"):default()
local wired_modem = nil
local array
array = function(...)
  return setmetatable({
    ...
  }, {
    isSequence = true
  })
end
for _, mod in ipairs({
  peripheral.find("modem")
}) do
  if not mod.isWireless() then
    wired_modem = mod
  end
end
if not wired_modem then
  error("Could not find any wired modem")
end
local my_id = os.getComputerID()
local golden = not not multishell
local ty
if turtle then
  ty = "turtle"
elseif pocket then
  ty = "pocket"
elseif select(2, term.getSize()) == 13 and golden then
  ty = "neural"
else
  ty = "computer"
end
local process
process = function()
  return db:process()
end
local main
main = function()
  return db:query("insert into computer (id, ty, is_golden) values ($1, $2, $3) on conflict update", array({
    ty = "int4",
    val = my_id
  }, {
    ty = "text",
    val = ty
  }, {
    ty = "bool",
    val = golden
  }))
end
return parallel.waitForAll(process, main)
