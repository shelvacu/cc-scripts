dblib = require("db")
mp = require "mp"

return {
  starts_with: (str, start) ->
    str\sub(1, #start) == start
  ends_with: (str, ending) ->
    ending == "" or str\sub(-#ending) == ending
  insertOrGetId: (db, meta) ->
    paraLog.log("insertOrGetId", db, meta)
    if meta == nil
      return nil
    -- still not good, doesn't handle nested data
    for _,v in ipairs{"effects","enchantments","banner","spawnedEntities","tanks","lines"}
      if meta[v]
        setmetatable(meta[v],{isSequence: true})

    -- if meta.enchantments
    --   setmetatable(meta.enchantments,{isSequence: true})
      -- print textutils.serialise meta.enchantments
      -- print #meta.enchantments
      -- for _,_ in ipairs(meta.enchantments)
      --   print "iter"
    --print(textutils.serialise(meta))
    res = db\query(
      "insert into item (name, damage, maxDamage, rawName, nbtHash, fullMeta) values ($1, $2, $3, $4, $5, $6) on conflict (name, damage, nbtHash) do nothing returning id",
      {ty: "text", val: meta.name},
      {ty: "int" , val: meta.damage},
      {ty: "int" , val: meta.maxDamage},
      {ty: "text", val: meta.rawName},
      {ty: "text", val: (meta.nbtHash or "")},
      {ty: "jsonb", val: meta}
    )
    --print textutils.serialise(res)
    local item_id
    if #res > 0
      item_id = res[1][1].val
    else
      res = db\query(
        "select id from item where name = $1 and damage = $2 and nbtHash = $3",
        {ty: "text", val: meta.name},
        {ty: "int" , val: meta.damage},
        {ty: "text", val: (meta.nbtHash or "")}
      )
      if #res ~= 1
        error"expected 1 result"
      item_id = res[1][1].val
    return item_id
  with_db: (func) ->
    idb = dblib\default!
    return -> parallel.waitForAny(
      (-> idb\process!)
      (-> func(idb))
    )
}
