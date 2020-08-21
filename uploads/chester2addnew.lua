local db = require("db"):default()
local mp = require("mp")
local wired_modem
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
local process
process = function()
  return db:process()
end
local main
main = function()
  local connecteds = wired_modem.getNamesRemote()
  for _, name in ipairs(connecteds) do
    local res = db:query("select ty from chest where computer = $1 and name = $2;", {
      ty = "int4",
      val = my_id
    }, {
      ty = "text",
      val = name
    })
    if #res == 0 then
      local size = wired_modem.callRemote(name, "size")
      print("adding " .. name)
      db:query("start transaction")
      db:query("insert into chest (computer, name, ty, slots) VALUES ($1, $2, $3, $4)", {
        ty = "int4",
        val = my_id
      }, {
        ty = "text",
        val = name
      }, {
        ty = "text",
        val = "storage"
      }, {
        ty = "int4",
        val = size
      })
      local query_prefix = "insert into stack (chest_computer, chest_name, slot, count) VALUES "
      local query_builder = { }
      local params = {
        {
          ty = "int4",
          val = my_id
        },
        {
          ty = "text",
          val = name
        }
      }
      for i = 1, size do
        query_builder[i] = "($1, $2, $" .. (i + 2) .. ", 0)"
        params.val[i + 2] = {
          ty = "int2",
          val = i
        }
      end
      db:query(query_prefix .. table.concat(query_builder, ","), table.unpack(params))
      db:query("commit")
    end
  end
  return print("all chests added")
end
return parallel.waitForAny(process, main)
