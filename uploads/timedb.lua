local t = require"timings"
timings.enable = true
local db = require("db"):default()

local tArgs = {...}

local function process()
  db:process()
end

local function time()
  t.start("preparing")
  local prepared = db:prepare("select 1")
  t.finish()
  -- t.start("select 1 x1000")
  -- for i=1,1000 do
  --   assert(db:query("select 1")[1][1].val == 1)
  -- end
  -- t.finish()
  local big = 3000
  local function time_parallel(n)
    local function q()
      for i=1,(big/n) do
        assert(db:query(prepared)[1][1].val == 1)
      end
    end
    local qs = {}
    for i = 1,n do
      qs[i] = q
    end
    t.start("select 1 "..n.."x"..(big/n))
    parallel.waitForAll(table.unpack(qs))
    t.finish()
  end
  if tArgs[1] then time_parallel(1000) end
  time_parallel(100)
  --time_parallel(20)
  --time_parallel(10)
  time_parallel(5)
  time_parallel(4)
  time_parallel(3)
  time_parallel(2)
  --time_parallel(100)

  db:close()
end

parallel.waitForAny(process, time)
