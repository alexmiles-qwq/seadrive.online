
print('Server is starting..\n')

_G.Logger = require('./libs/Logger')
Logger.minimalranktoprint = 2
local __VERSION = '0.1.1'

local http = require('http')
local timer = require('timer')

local router = require('./router')
_G.mime  = require('.mime')
_G.DataStore = require('./datastore')

_G.AttachmentsDataStore = DataStore:GetDatastore('Attachments')
_G.VisitsDataStore = DataStore:GetDatastore('VisitsDataStore')

local HttpServer = http.createServer(function(req, res)

    local sockaddr = req.socket:address()
    local ip = sockaddr and sockaddr.ip or "unknown"

    local logString = 'New Http request.\n\n=== INFO ===\n - url: %s\n - IP: %s\n'
    local fLogString = logString:format(req.url, ip)

    Logger:Log(fLogString, 2)

    local success, err = pcall(function()
        router:handler(req, res)
    end)

    if not success then
        Logger:Log('ROUTER: '..err, 2)
    end

end)

HttpServer:listen(80)
Logger:Log('Session Started at ' .. os.date('%x') .. '.\n Version: '..__VERSION..'.\n Made by AlexMiles.', 99)

timer.setInterval(30 * 1000, function()
    local success, err = pcall(function()
        AttachmentsDataStore:_save()
    end)

    if not success then
        Logger:Log('Unable to save AttachmentsDataStore: '..err, 3)
    else
         Logger:Log('Saved AttachmentsDataStore.', 3)
    end

    local success, err = pcall(function()
        VisitsDataStore:_save()
    end)

    if not success then
        Logger:Log('Unable to save VisitsDataStore: '..err, 3)
    else
         Logger:Log('Saved VisitsDataStore.', 3)
    end

end)
-- print('Running on localhost')