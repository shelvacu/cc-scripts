require("paranoidLogger")("chester2jobdepfinish")
local common = require("chestercommon")
local my_id = 55
local job_dep_finish_thread
job_dep_finish_thread = function(db)
  paraLog.log("job dep finish running")
  local sleeptime = 0
  while true do
    local res1 = db:query("update job_dep_graph j set children_finished=true from lateral (\n        select n.id, coalesce(bool_and(c.finished), true) as all_finished from job_dep_graph n left join job_dep_graph c on c.parent = n.id where n.children_finished = false group by n.id\n      ) q where j.id = q.id and q.all_finished returning j.is")
    local count1 = #res1
    local res2 = db:query("update job_dep_graph j set finished=true from lateral (\n        select n.id, coalesce( bool_and(c.finished), true ) as all_finished from job_dep_graph n left join job c on c.parent = n.id where n.finished = false and n.children_finished = true group by n.id\n      ) q where j.id = q.id and q.all_finished returning j.id")
    local count2 = #res2
    local count = count1 + count2
    paraLog.log("counts", {
      count = count,
      res1 = res1,
      res2 = res2
    })
    if count == 0 then
      sleeptime = clamp(sleeptime * 2, 0.1, 1)
      sleep(sleeptime)
    end
  end
end
return common.with_db(job_dep_finish_thread)()
