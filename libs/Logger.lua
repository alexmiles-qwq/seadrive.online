
local Logger = {}
Logger.filename = 'logs.log'
Logger.printlogstoconsole = true
Logger.minimalranktoprint = 1

-- locals
local startTime = os.clock()
local logfile = io.open(Logger.filename, "a")

if not logfile then
    print('No log file found. New file will be created.')
end



function Logger:Log(message, rank)
    rank = rank or 1
    
    local Time = os.date('%X')
    local str = '['..Time..']: ' .. message

    if Logger.printlogstoconsole then
        if rank >= Logger.minimalranktoprint then
            print(str)
        end
    end

    logfile:write(str .. '\n')
    logfile:flush()

end

function Logger:Stop()
    logfile:close()
end


return Logger