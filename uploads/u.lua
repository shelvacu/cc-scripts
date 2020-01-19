
for i,v in ipairs({...}) do
  local name = v..".lua"
  shell.run("rm", name)
  shell.run("wget", "http://10.4.5.17:8000/"..name, name)
end
