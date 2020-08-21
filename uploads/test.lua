mp = require"mp"
db = require("db"):default()

bigstr = ""
for i=0,255 do bigstr = bigstr .. string.char(i) end


local function go()
  res = db:query("insert into test (a) values ($1);", {ty = "text", val = bigstr})
  print("done")
end

local function process()
  db:process()
end

parallel.waitForAll(go, process)

