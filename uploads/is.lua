if not starNav then
  if not os.loadAPI("sn/starNav") then
    error"no starNav"
  end
end

starNav.setMap"map"

--starNav.goto(-256,16,291,100)
--starNav.goto(-158,14,249,100,0)

--sleep(10)

starNav.goto(-256,16,291,100)
starNav.goto(-250,65,286,200,3)
