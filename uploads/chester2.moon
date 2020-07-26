export os, turtle, pocket, peripheral, term, multishell
print "make connection"
db = require("db")\default!

wired_modem = nil

array = (...) -> setmetatable({...}, {isSequence: true})

print "find wired modem"
for _,mod in ipairs {peripheral.find "modem"}
  if not mod.isWireless!
    wired_modem = mod
if not wired_modem
  error"Could not find any wired modem"

my_id = os.getComputerID!

golden = not not multishell

local ty

if turtle
  ty = "turtle"
elseif pocket
  ty = "pocket"
elseif select(2, term.getSize()) == 13 and golden
  ty = "neural"
else
  ty = "computer"

process = -> db\process!

input_thread = ->
  

main = ->
  print "about to query"
  res = db\query(
    "insert into computer (id, ty, is_golden) values ($1, $2, $3) on conflict (id) do update set ty = $2, is_golden = $3",
    array(
      {ty: "int4", val: my_id},
      {ty: "text", val: ty},
      {ty: "bool", val: golden}
    )
  )
  print "res is "..textutils.serialise(res)
  connecteds = wired_modem.getNamesRemote()
  --chest_map = {} --maps name to ty
  --chest_ty_map = {input: {}, output: {}, storage: {}, unknown: {}}
  for _,name in ipairs(connecteds)
    res = db\query(
      "select ty from chest where computer = $1 and name = $2;",
      array(
        {ty: "int4", val: my_id},
        {ty: "text", val: name}
      )
    )
    if #res == 0
      size = wired_modem.callRemote(name, "size")
      print("adding "..name)
      db\query("start transaction")
      db\query(
        "insert into chest (computer, name, ty, slots) VALUES ($1, $2, $3, $4)",
        array(
          {ty: "int4", val: my_id},
          {ty: "text", val: name},
          {ty: "text", val: "unknown"},
          {ty: "int4", val: size}
        )
      )
      for i=1,size
        db\query(
          "insert into stack (chest_computer, chest_name, slot, count) VALUES ($1, $2, $3, 0)",
          array(
            {ty: "int4", val: my_id},
            {ty: "text", val: name},
            {ty: "int2", val: i}
          )
        )
      db\query("commit")
    else
      assert(#res == 1)
  print("all chests added")

parallel.waitForAll process, main
