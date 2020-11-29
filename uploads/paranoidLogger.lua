local pretty = require("cc.pretty")
return function(scriptName)
    if not paraLog then
        paraLog = {scriptName = scriptName}
        local logFileName = scriptName..".log"
        local handle, err = fs.open(logFileName, "a")
        print("paraLog: Opened "..logFileName)
        if handle == nil then
            error("error opening logfile "..err)
        end
        --paraLog.h = handle
        paraLog.log = function(text,...)
            handle.write("["..os.date().."] "..paraLog.scriptName..":"..text..":"..pretty.render(pretty.pretty({...})).."\n!!!\n")
            handle.flush()
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
        paraLog.logbt = paraLog.btlog
        paraLog.die = function(text,...)
            paraLog.btlog("FATAL: "..text,...)
            handle.close()
            error(text)
        end
        paraLog.log("paranoidLogger initialized",{computer_id = os.getComputerID()})
    else
        error("paranoidLogger already initialized")
    end
end


