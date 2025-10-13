
print('Server is starting..\n')

_G.Logger = require('./libs/Logger')
Logger.minimalranktoprint = 2
local __VERSION = 0.1

local http = require('http')
local router = require('./router')
_G.mime  = require('.mime')

local HttpServer = http.createServer(function(req, res)
    
    local logString = [[New Http request: url: %s]]
    local fLogString = logString:format(req.url)

    Logger:Log(fLogString, 2)

    router:handler(req, res)

end)

HttpServer:listen(80)

Logger:Log('Session Started at ' .. os.date('%x') .. '.\n Version: '..__VERSION..'.\n Made by AlexMiles.', 99)

-- print('Running on localhost')