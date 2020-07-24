local db = require"db"

local conn1 = db:new("ws://127.0.0.1:7648/")
local conn2 = db:new("ws://127.0.0.1:7648/")

parallel.waitForAll(
  function()
    conn1:process()
    print("conn1 process finished")
  end,
  function()
    conn2:process()
    print("conn2 process finished")
  end,
  function()
    conn1:query("select 1;")

    print("queried")
    os.sleep(10)
    conn1:close()
    print("conn1 closed")
    conn2:close()
    print("conn2 closed")
  end
)

