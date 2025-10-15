
print('Server is starting..\n')

local fs = require('fs')
_G.Logger = require('./libs/Logger')
Logger.minimalranktoprint = 2
local __VERSION = '0.1.5'

local https = require('https')
local http = require('http')
local timer = require('timer')

local router = require('./router')
_G.mime  = require('.mime')
-- _G.DataStore = require('./datastore')

_G.server = require('./server')
_G.DataStore = server:GetService('DataStoreService')

_G.AttachmentsDataStore = DataStore:GetDatastore('Attachments')
_G.VisitsDataStore = DataStore:GetDatastore('VisitsDataStore')

local function readFile(filepath)
    return fs.readFileSync(filepath)
end

local key, cert = readFile('./privkey.pem'), readFile('./fullchain.pem')

local options = {
  key = key,
  cert = cert
  -- ca = fs.readFileSync('path/to/ca_bundle.pem'),
  -- requestCert = true,
  -- rejectUnauthorized = true
}

local useHttps = false

if not cert or not key then
    useHttps = false
    Logger:Log('Certificate files are missing or corrupted. Using http mode.', 99)
end

if not useHttps then
    _G.server.InsecureMode = true
end

local function OnReq(req, res)
    
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
        res.statusCode = 500
        res:finish('Interal error')
    end

end

if useHttps then
    local HttpsServer = https.createServer(options, OnReq)
    HttpsServer:listen(443)
else
    Logger:Log('WARNING: Running server in insecure mode. Use it only for local tests!', 99)
    local HttpServer = http.createServer(OnReq)
    HttpServer:listen(80)
end



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