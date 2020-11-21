local tArgs = {...}
if shell.run("u", tArgs[1]) then
    shell.run(...)
end