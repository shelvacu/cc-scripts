local db = require("db"):default()
local wired_modem
print("find wired modem")
for _, mod in ipairs({
  peripheral.find("modem")
}) do
  if not mod.isWireless() then
    wired_modem = mod
  end
end
if not wired_modem then
  error("Could not find any wired modem")
end
local my_id = os.getComputerID()
local tArgs = {
  ...
}
local process
process = function()
  return db:process()
end
local main
main = function()
  local chests = nil
  if tArgs[2] == nil then
    chests = db:query("select name, ty from chest where computer = $1;", {
      ty = "int4",
      val = my_id
    })
  elseif tArgs[2] == "cake" then
    chests = db:query("select name, ty from chest where computer = $1 and name in (select chest_name from stack where item_id in (15429, 15674, 10764, 4128, 21405, 4110) group by chest_name)", {
      ty = "int4",
      val = my_id
    })
  else
    chests = {
      table.unpack(tArgs, 2, #tArgs)
    }
  end
  for i, row in ipairs(chests) do
    print("chest " .. i .. " of " .. #chests)
    local name = nil
    local chest_ty = nil
    if type(row) == "string" then
      name = row
      chest_ty = "storage"
    else
      name = row[1].val
      chest_ty = row[2].val
    end
    local stacks = db:query("select stack.slot, stack.count, item.name, item.damage, item.nbtHash from stack left join item on stack.item_id = item.id where stack.chest_computer = $1 and stack.chest_name = $2", {
      ty = "int4",
      val = my_id
    }, {
      ty = "text",
      val = name
    })
    for _, row in ipairs(stacks) do
      if chest_ty ~= 'storage' then
        print(name .. " is ty " .. chest_ty .. " but has stacks associated!")
        break
      end
      local slot = row[1].val
      local dbCount = row[2].val
      local item_name = row[3].val
      local item_damage = row[4].val
      local item_nbtHash = row[5].val
      local meta = peripheral.call(name, "getItemMeta", slot)
      local chestCount
      local chest_nbtHash = ""
      if not meta then
        chestCount = 0
      else
        chestCount = meta.count
        if meta.nbtHash then
          chest_nbtHash = meta.nbtHash
        end
      end
      local needsFix = false
      if dbCount ~= chestCount then
        print(name .. " count mismatch! " .. dbCount .. " vs " .. chestCount)
        needsFix = true
      elseif chestCount ~= 0 then
        if not (meta.name == item_name and meta.damage == item_damage and chest_nbtHash == item_nbtHash) then
          local ms
          ms = function(s)
            if not s then
              return "nil"
            else
              return s
            end
          end
          print(name .. " meta mismatch " .. ms(meta.name) .. ":" .. ms(item_name) .. " " .. ms(meta.damage) .. ":" .. ms(item_damage) .. " " .. ms(meta.nbtHash) .. ":" .. ms(item_nbtHash))
          needsFix = true
        end
      end
      if needsFix and tArgs[1] == "fix" then
        if meta then
          local res = db:query("insert into item (name, damage, maxDamage, rawName, nbtHash, fullMeta) values ($1, $2, $3, $4, $5, $6) on conflict (name, damage, nbtHash) do nothing returning id", {
            ty = "text",
            val = meta.name
          }, {
            ty = "int",
            val = meta.damage
          }, {
            ty = "int",
            val = meta.maxDamage
          }, {
            ty = "text",
            val = meta.rawName
          }, {
            ty = "text",
            val = (meta.nbtHash or "")
          }, {
            ty = "jsonb",
            val = meta
          })
          local item_id
          if #res > 0 then
            item_id = res[1][1].val
          else
            res = db:query("select id from item where name = $1 and damage = $2 and nbtHash = $3", {
              ty = "text",
              val = meta.name
            }, {
              ty = "int",
              val = meta.damage
            }, {
              ty = "text",
              val = (meta.nbtHash or "")
            })
            if #res ~= 1 then
              error("expected 1 result")
            end
            item_id = res[1][1].val
          end
          db:query("update stack set count = $1, item_id = $2 where chest_computer = $3 and chest_name = $4 and slot = $5", {
            ty = "int4",
            val = chestCount
          }, {
            ty = "int4",
            val = item_id
          }, {
            ty = "int4",
            val = my_id
          }, {
            ty = "text",
            val = name
          }, {
            ty = "int2",
            val = slot
          })
        else
          db:query("update stack set count = 0, item_id = NULL where chest_computer = $1 and chest_name = $2 and slot = $3", {
            ty = "int4",
            val = my_id
          }, {
            ty = "text",
            val = name
          }, {
            ty = "int2",
            val = slot
          })
        end
      end
    end
  end
end
return parallel.waitForAny(process, main)
