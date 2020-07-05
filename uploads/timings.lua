shelTimings = {}

if not timings then
  timings = {enable = false}
end

return {
  start = function(name)
    if timings.enable then
      print(string.rep("++",#shelTimings) .. "S " .. name)
      shelTimings[#shelTimings + 1] = {
        name = name,
        startAt = os.time(),
        otherwiseTimed = 0.0
      }
    end
  end,
  finish = function()
    if timings.enable then
      local endAt = os.time()
      local info = shelTimings[#shelTimings]
      shelTimings[#shelTimings] = nil
      local dur = endAt - info.startAt
      if #shelTimings > 0 then
        local parent = shelTimings[#shelTimings]
        parent.otherwiseTimed = parent.otherwiseTimed + dur
      end
      print(string.rep("++",#shelTimings) .. "E " .. info.name .. " total " .. dur .. " N.O.T. " .. dur - info.otherwiseTimed)
    end
  end
}


