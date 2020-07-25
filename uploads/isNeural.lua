local function isNeural()
  local function check(...)
    local n = select('#', ...)
    if n > 0 then
      return true
    end
    return false
  end
  return check(peripheral.find("neuralInterface"))
end
print(isNeural())
