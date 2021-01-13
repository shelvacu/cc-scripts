require("paranoidLogger")("buildSchematic")
nbt = require("nbt")
dblib = require("db")
db = dblib\default!

tArgs = {...}

fn = tArgs[1]
h, err = fs.open(fn, "rb")
if h == nil
  error(err)
dataBytes = h\readAll!
dataNbt = nbt(dataBytes)
print "finished reading nbt"
for k,v in pairs dataNbt
  print k
schematic = dataNbt--["Schematic"]

if schematic.Entities != nil
  print "Ignoring "..(#schematic.Entities).." entities"

oppositeMapping = {}
for k,v in pairs schematic.SchematicaMapping
  oppositeMapping[v] = k

item_counts = {}

for i,b in ipairs schematic.Blocks
  if math.fmod(i, 1024) == 0
    sleep!
  d = schematic.Data[i]
  key = oppositeMapping[b]..":"..d
  if item_counts[key] == nil
    item_counts[key] = 0
  item_counts[key] += 1

for k,v in pairs item_counts
  key = k--oppositeMapping[k]
  if key == nil
    key = "nil:"..k
  print key .. "=>" .. v
