local t = require"timings"
local mp = require"mp"
local mpc = require"mpConcat"
local mp3 = require"mp3"
local mppc = require"mpPureConcat"

timings.enable = true
t.start("init")
local data = {}
for i=1,10000 do
  data[i] = {a = 1, b = 2, c = i % 5}
end
t.finish()

t.start("mp") mp.pack(data) t.finish()
t.start("mpc") mpc.pack(data) t.finish()
t.start("mp3") mp3.pack(data) t.finish()
t.start("mppc") mppc.pack(data) t.finish()

print("----")
t.start("mp") mp.pack(data) t.finish()
t.start("mpc") mpc.pack(data) t.finish()
t.start("mp3") mp3.pack(data) t.finish()
t.start("mppc") mppc.pack(data) t.finish()
