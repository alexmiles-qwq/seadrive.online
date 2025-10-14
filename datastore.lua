--[[
    TODO: encrypt datastore
]]

local json = require('json')
local fs = require('fs')

local folderName = './datastores/'
local DataStore = {}

local Logger = _G and _G.Logger or nil
local function log(msg, rank)
    if Logger and type(Logger.Log) == 'function' then
        pcall(function() Logger:Log('[DataStore]: ' .. tostring(msg), rank or 1) end)
    end
end

local function ensureFolder(path)
    if not fs.existsSync(path) then
        local ok, err = pcall(fs.mkdirSync, path)
        if ok then
            log("Created folder: " .. path)
        else
            log("Failed to create folder " .. path .. ": " .. tostring(err))
            error("Failed to create folder " .. path .. ": " .. tostring(err))
        end
    else
        local stat = nil
        local ok, s = pcall(fs.statSync, path)
        if ok then stat = s end
        if not stat or stat.type ~= 'directory' then
            log(path .. " already exists and is not a directory")
            error(path .. " already exists and is not a directory")
        end
    end
end

function DataStore:GetDatastore(name)
    ensureFolder(folderName)

    local instance = {}
    instance.Name = name
    local filePath = folderName .. name .. '.json'
    local data = {}

    function instance:_load()
        if fs.existsSync(filePath) then
            local ok, content = pcall(fs.readFileSync, filePath)
            if not ok or not content then
                log("Could not read file: " .. filePath)
                data = {}
                return
            end

            local succ, decoded = pcall(json.decode, content)
            if succ and type(decoded) == 'table' then
                data = decoded
                log("Loaded datastore '" .. name .. "' from " .. filePath)
            else
                log("Invalid JSON in " .. filePath .. " — resetting data")
                data = {}
            end
        else
            log("Datastore file not found, starting fresh: " .. filePath)
            data = {}
        end
    end

    function instance:_save()
        local ok, encoded = pcall(json.encode, data)
        if not ok or not encoded then
            log("Failed to serialize data for " .. tostring(name))
            error("Failed to serialize data for " .. tostring(name))
        end

        local succ, err = pcall(fs.writeFileSync, filePath, encoded)
        if not succ then
            log("Failed to write file " .. filePath .. ": " .. tostring(err))
            error("Failed to write file " .. filePath .. ": " .. tostring(err))
        else
            log("Saved datastore '" .. name .. "' to " .. filePath)
        end
    end

    function instance:Get()
        return data
    end

    function instance:Set(newData)
        if type(newData) ~= 'table' then
            log("Set: expected a table for datastore " .. name)
            error("Set: expected a table")
        end
        data = newData
        log("Set whole data for datastore '" .. name .. "'")
    end

    function instance:GetValue(key)
        return data[key]
    end

    function instance:SetValue(key, value)
        data[key] = value
        log("SetValue in '" .. name .. "': " .. tostring(key))
    end

    instance:_load()

    return instance
end

return DataStore
