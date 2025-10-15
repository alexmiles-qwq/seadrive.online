--local DataStore = require('./services/datastore')
local fs = require('fs')
local Logger = _G.Logger

local ServicesFolder = './services/'

local function get_ext(p)
  local ext = p:match("^.+%.([^.]+)$")
  if ext then return ext:lower() end
end

local function LoadServices()
    local s = {}
   
    local success, files = pcall(function()
        return fs.readdirSync(ServicesFolder)
    end)

    if not success then
        error('Unable to acces to services: '..files)
    end

    if #files == 0 then
        return nil
    end

    for i, file in pairs(files) do
        local info = fs.statSync(ServicesFolder .. file)
        if info.type ~= 'file' then goto continue end
        local ext = get_ext(ServicesFolder .. file)
        if ext ~= 'lua' then goto continue end

        local success, err = pcall(function()
            local module = require(ServicesFolder .. file)
            local serviceName = module.__ServiceName or file

            Logger:Log('Successfully loaded Service ' .. serviceName, 99)

            s[serviceName] = module
        end)

        if not success then
            Logger:Log('An error occured while loading module '..file..': '..err, 2)
        end

        ::continue::
    end

    return s
end

local server = {}

local services = LoadServices()
for i, v in pairs(services) do
    server[i] = v
end

function server:GetService(servicename)
    if server[servicename] then
        return server[servicename]
    end

    error('Could not find Service called '..tostring(servicename)'.')
end

return server