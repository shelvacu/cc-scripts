local dims = 64
local down = 500 -- very large basically means to bedrock

require"shellib"
local af = require"atomicFile"
getGlobalOffset()

local startingPos = globalPosition()

af.write("tmparams", {
  dims = dims,
  down = down,
  startingPos = startingPos,
  gotToY = startingPos.y,
  gotToX = startingPos.x
})
