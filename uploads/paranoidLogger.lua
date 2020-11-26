return function(scriptName)
    if not paraLog then
        paraLog = {scriptName = scriptName}
        local handle, err = fs.open(scriptName .. ".log", "a")
        if handle == nil then
            error("error opening logfile "..err)
        end
        --paraLog.h = handle
        paraLog.log = function(text,...)
            handle.write("["..os.date().."] "..paraLog.scriptName..":"..text..":"..textutils.serialise({...}).."\n")
        end
        paraLog.loggedCall = function(description, peripheral_name, method, ...)
            paraLog.log(description, "calling "..peripheral_name..":"..method, {...})
            local res = peripheral.call(peripheral_name, method, ...)
            paraLog.log(description, "result", res)
            return res
        end
        paraLog.btlog = function(text,...)
            paraLog.log(text,debug.traceback(),...)
        end
        paraLog.die = function(text,...)
            paraLog.btlog("FATAL: "..text,...)
            error(text)
        end
        paraLog.log("paranoidLogger initialized",{computer_id: os.getComputerId()})
    else
        error("paranoidLogger already initialized")
    end
end


