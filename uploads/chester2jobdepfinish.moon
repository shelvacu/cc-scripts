require("paranoidLogger")("chester2jobdepfinish")
common = require("chestercommon")

my_id = 55

job_dep_finish_thread = (db) ->
  paraLog.log("job dep finish running")
  sleeptime = 0
  while true
    res1 = db\query(
      "update job_dep_graph j set children_finished=true from lateral (
        select n.id, coalesce(bool_and(c.finished), true) as all_finished from job_dep_graph n left join job_dep_graph c on c.parent = n.id where n.children_finished = false group by n.id
      ) q where j.id = q.id and q.all_finished returning j.is"
    )
    count1 = #res1
    res2 = db\query(
      "update job_dep_graph j set finished=true from lateral (
        select n.id, coalesce( bool_and(c.finished), true ) as all_finished from job_dep_graph n left join job c on c.parent = n.id where n.finished = false and n.children_finished = true group by n.id
      ) q where j.id = q.id and q.all_finished returning j.id"
    )
    count2 = #res2
    count = count1+count2
    paraLog.log("counts",{:count, :res1, :res2})
    if count == 0
      sleeptime = clamp(sleeptime*2, 0.1, 1)
      sleep(sleeptime)

common.with_db(job_dep_finish_thread)()