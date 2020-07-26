print("make connection")
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
print("find wired modem")
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
local input_thread
input_thread = function() end
local main
main = function()
  print("about to query")
  local res = db:query("insert into computer (id, ty, is_golden) values ($1, $2, $3) on conflict (id) do update set ty = $2, is_golden = $3", array({
    ty = "int4",
    val = my_id
  }, {
    ty = "text",
    val = ty
  }, {
    ty = "bool",
    val = golden
  }))
  print("res is " .. textutils.serialise(res))
  local connecteds = wired_modem.getNamesRemote()
  for _, name in ipairs(connecteds) do
    res = db:query("select ty from chest where computer = $1 and name = $2;", array({
      ty = "int4",
      val = my_id
    }, {
      ty = "text",
      val = name
    }))
    if #res == 0 then
      local size = wired_modem.callRemote(name, "size")
      print("adding " .. name)
      db:query("start transaction")
      db:query("insert into chest (computer, name, ty, slots) VALUES ($1, $2, $3, $4)", array({
        ty = "int4",
        val = my_id
      }, {
        ty = "text",
        val = name
      }, {
        ty = "text",
        val = "unknown"
      }, {
        ty = "int4",
        val = size
      }))
      for i = 1, size do
        db:query("insert into stack (chest_computer, chest_name, slot, count) VALUES ($1, $2, $3, 0)", array({
          ty = "int4",
          val = my_id
        }, {
          ty = "text",
          val = name
        }, {
          ty = "int2",
          val = i
        }))
      end
      db:query("commit")
    else
      assert(#res == 1)
    end
  end
  return print("all chests added")
end
return parallel.waitForAll(process, main)
