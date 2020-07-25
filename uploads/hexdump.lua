local hexChars = {
  "0",
  "1",
  "2",
  "3",
  "4",
  "5",
  "6",
  "7",
  "8",
  "9",
  "a",
  "b",
  "c",
  "d",
  "e",
  "f",
}

return function(data)
  local res = {}
  for i=1,#data do
    local by = string.byte(data, i)
    local upper = bit.blogic_rshift(by, 4)
    local lower = bit.band(by, 0x0f)
    res[(i*2)] = hexChars[upper+1]
    res[(i*2)+1] = hexChars[lower+1]
  end
  return table.concat(res)
end
