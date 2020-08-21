local mp = require("mp")
return {
  insertOrGetId = function(db, meta)
    if meta == nil then
      return nil
    end
    for _, v in ipairs({
      "effects",
      "enchantments",
      "banner",
      "spawnedEntities",
      "tanks",
      "lines"
    }) do
      if meta[v] then
        setmetatable(meta[v], {
          isSequence = true
        })
      end
    end
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
    return item_id
  end
}
