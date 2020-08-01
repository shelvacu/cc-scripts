mp = require"mp"
db = require("db"):default()

bigstr = ""
for i=0,255 do bigstr = bigstr .. string.char(i) end

local array
array = function(...)
  return mp.configWrapper(setmetatable({
    ...
  }, {
    isSequence = true
  }), {
    recode = true,
    convertNull = true
  })
end

--print(textutils.serialise(array(bigstr)))

local function go()
  res = db:query("insert into test (a) values ($1);", array({ty = "text", val = bigstr}))
  print("done")
end

local function process()
  db:process()
end

parallel.waitForAll(go, process)

