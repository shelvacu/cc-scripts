rednet.open("back")
while true do
  os.pullEvent("redstone")
  rednet.broadcast("drop", "dropit")
end
