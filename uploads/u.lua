
for i,v in ipairs({...}) do
  local name = v..".lua"
  shell.run("mv", name, name .. ".old")
  if shell.run("wget", "http://10.244.227.200:8000/"..name, name) then
    shell.run("rm", name .. ".old")
  else
    print("Failed to grab!")
    shell.run("mv", name .. ".old", name)
  end
end
