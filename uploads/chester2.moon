export os, turtle, pocket, peripheral, term, multishell

db = require("db")\default!

wired_modem = nil

array = (...) -> setmetatable({...}, {isSequence: true})

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

main = ->
  db\query(
    "insert into computer (id, ty, is_golden) values ($1, $2, $3) on conflict update",
    array(
      {ty: "int4", val: my_id},
      {ty: "text", val: ty},
      {ty: "bool", val: golden}
    )
  )

parallel.waitForAll process, main
