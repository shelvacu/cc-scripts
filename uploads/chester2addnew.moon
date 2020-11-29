require("paranoidLogger")("chester2addnew")
common = require("chestercommon")

db = require("db")\default!
mp = require("mp")

local wired_modem

print "find wired modem"
for _,mod in ipairs {peripheral.find "modem"}
  if not mod.isWireless!
    wired_modem = mod
if not wired_modem
  error"Could not find any wired modem"

my_id = os.getComputerID!


process = ->
  db\process!

main = ->
  connecteds = wired_modem.getNamesRemote()
  --chest_map = {} --maps name to ty
  --chest_ty_map = {input: {}, output: {}, storage: {}, unknown: {}}
  for _,name in ipairs(connecteds)
    continue unless common.starts_with(name, "minecraft:chest_")
    res = db\query(
      "select ty from chest where computer = $1 and name = $2;",
      {ty: "int4", val: my_id},
      {ty: "text", val: name}
    )
    if #res == 0
      size = wired_modem.callRemote(name, "size")
      print("adding "..name)
      db\query("start transaction")
      db\query(
        "insert into chest (computer, name, ty, slots) VALUES ($1, $2, $3, $4)",
        {ty: "int4", val: my_id},
        {ty: "text", val: name},
        {ty: "text", val: "storage"},
        {ty: "int4", val: size}
      )
      query_prefix = "insert into stack (chest_computer, chest_name, slot, count) VALUES "
      query_builder = {}
      params = {{ty: "int4", val: my_id}, {ty: "text", val: name}}
      for i=1,size
        query_builder[i] = "($1, $2, $" .. (i+2) .. ", 0)"
        params[i+2] = {ty: "int2", val: i}
        -- db\query(
        --   "insert into stack (chest_computer, chest_name, slot, count) VALUES ($1, $2, $3, 0)",
        --   {ty: "int4", val: my_id},
        --   {ty: "text", val: name},
        --   {ty: "int2", val: i}
        -- )
      db\query(
        query_prefix .. table.concat(query_builder, ","),
        table.unpack(params)
      )
      db\query("commit")
  print("all chests added")

parallel.waitForAny(process, main)
