
for i,v in ipairs({...}) do
  local name = v..".lua"
  shell.run("rm", name)
  shell.run("wget", "http://10.244.227.200:8000/"..name, name)
end
