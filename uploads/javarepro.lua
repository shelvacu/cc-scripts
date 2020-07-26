local t = require"timings"
timings.enable = true

local function process()
  --os.sleep(100000000)
  while true do
    local _, a = os.pullEvent("ping")
    os.queueEvent("pong",a)
  end
end

local function time()
  local i = 1
  local big = 3000
  local function time_parallel(n)
    local function q()
      for i=1,(big/n) do
        local my_i = i
        i = i + 1
        os.queueEvent("ping", i)
        while ({os.pullEvent("pong")})[2] ~= i do end
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
  time_parallel(1000)
  time_parallel(500)
  time_parallel(100)
  time_parallel(20)
  time_parallel(10)
  time_parallel(5)
  time_parallel(4)
  time_parallel(3)
  time_parallel(2)
  --time_parallel(100)

end

parallel.waitForAny(process, time)
