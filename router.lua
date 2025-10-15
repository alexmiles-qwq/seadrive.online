local fs = require('fs')
local path = require('path')
local router = {}

-- functions

local function readFile(filepath)
    return fs.readFileSync(filepath)
end

local function ensureFolder(p)
  if not fs.existsSync(p) then
    fs.mkdirSync(p)
  end
end


local function ext_from_type(ct)
  if not ct then return 'bin' end
  if ct:match('png') then return 'png' end
  if ct:match('jpeg') or ct:match('jpg') then return 'jpg' end
  if ct:match('gif') then return 'gif' end
  return 'bin'
end

local function parseUrl(url)
	local parsed = {}
	for part in url:gmatch("[^/]+") do
		table.insert(parsed, part)
	end
	return parsed
end

local function get_ext(p)
  local ext = p:match("^.+%.([^.]+)$")
  if ext then return ext:lower() end
end

local function notfound(req, res)
     
    local path = './pages/404/'
    local html = readFile(path..'index.html')

    local ct = mime.html

    res.statusCode = 404
    res:setHeader("Content-Type", ct)
    res:setHeader("Content-Length", #html)
    res:finish(html)
    return
end

local function serve_file(res, filepath)
  fs.readFile(filepath, function(err, data)
    if err then
      notfound(nil, res)
      return
    end
    local ext = get_ext(filepath) or 'txt'

    if ext == 'gif' then
        local ct = mime.gif
        res:setHeader("Content-Type", ct)
        res:setHeader("Content-Length", #data)
        res:finish(data)
        return
    else
        local ct = mime[ext]
        res:setHeader("Content-Type", ct)
        res:setHeader("Content-Length", #data)
        res:finish(data)
        return
    end


    local ct = "application/octet-stream"
    res:setHeader("Content-Type", ct)
    res:setHeader("Content-Length", #data)
    res:finish(data)
  end)
end


local function getRandomFile(folder)
    local success, files = pcall(function()
        return fs.readdirSync(folder)
    end)

    if not success then
        return
    end

    if #files == 0 then
        return nil
    end
    return path.join(folder, files[math.random(1, #files)])
end

local function mainPage(res)
    local path = './pages/main/'
    local html = readFile(path..'index.html')

    local ct = mime.html
    res:setHeader("Content-Type", ct)
    res:setHeader("Content-Length", #html)
    res:finish(html)
    return
end

local GET_Routes = {

    ['assets'] = function(req, res, parsedUrl)
        
        local asset = parsedUrl[2]
        Logger:Log('Requested asset: '..asset)

        serve_file(res, './assets/general/'..asset)

    end,

    ['attachments'] = function(req, res, parsedUrl)
        local id = parsedUrl[2]
        print(id)
        local data = AttachmentsDataStore:GetValue(tostring(id))
        
        if not data then notfound(req, res) return end

        local filepath = data.path
        local timestamp = data.timestamp

        serve_file(res, filepath)
    end,

    ['random'] = function(req, res, parsedUrl)
        local typ = parsedUrl[2]
        
        local ppath = './assets/'..typ..'/'
        local file = getRandomFile(ppath)
        if not file then
            notfound(req, res)
            return
        end

        local data = fs.readFileSync(file)
        local ext = get_ext(file)


        local ct = mime[ext]
        res:setHeader("Content-Type", ct)
        res:setHeader("Content-Length", #data)
        res:finish(data)
        
    end,

    ['/']  = function(req, res)
        mainPage(res)
    end,

    ['404'] = function(req, res)
        notfound(req, res)
    end,

    ['favicon.ico'] = function(req, res)
        print('favicon :p')
        serve_file(res, '/assets/general/favicon.ico')
        
    end,
    ['ip'] = function(req, res, arg, ip)

        local str = 'Your ip: '..ip

        res:setHeader("Content-Type", mime.txt)
        res:setHeader("Content-Length", #str)
        res:finish(str)
    end

}

local POST_Routes = {

    ['attachments'] = function(req, res)
        local nextID = AttachmentsDataStore:GetValue('nextID') or 1
        local contentType = req.headers['content-type'] or ''

        if not contentType:match('image/') and not contentType:match('application/octet%-stream') then
            res:writeHead(400, { ['Content-Type'] = 'text/plain' })
            res:finish('Expected image content-type or application/octet-stream')
            return
        end   
        
        local chunks = {}
        
        req:on('data', function(chunk)
            table.insert(chunks, chunk)
        end)    

        req:on('end', function()

            local data = {}

            local body = table.concat(chunks)
            local ext = ext_from_type(contentType)
            local filename = nextID .. '.' .. ext

            local ok, err = pcall(fs.writeFileSync, './attachments/' .. filename, body)
                if not ok then
                    res:writeHead(500, { ['Content-Type'] = 'text/plain' })
                    res:finish('Failed to save file: ' .. tostring(err))
                return
            end

            res:writeHead(200, { ['Content-Type'] = 'application/json' })
            res:finish('{ "status": "ok", "file": "' .. filename .. '" }')

            data.timestamp = os.time()
            data.path = './attachments/' .. filename
            
            AttachmentsDataStore:SetValue(tostring(nextID), data)
            AttachmentsDataStore:SetValue('nextID', nextID + 1)
        end)
    end

}

local MaxReqPerSec = 8
local RateLimitTimer = 10 * 60

local requests = {}
local rateLimitedIps = {} 

local rateLimitEnabled = true

local function IsRateLimited(ip)
    local now = os.time()
    for i = #rateLimitedIps, 1, -1 do
        local entry = rateLimitedIps[i]
        if entry.ip == ip   then
            if entry.limitUntil > now then
                return true
            else
                table.remove(rateLimitedIps, i)
            end
        else
            if entry.limitUntil <= now then
                table.remove(rateLimitedIps, i)
            end
        end
    end
    return false
end

local function clearRequests()
    local now = os.time()
    for i = #requests, 1, -1 do
        if now - requests[i].timestamp >= 1 then
            table.remove(requests, i)
        end
    end
end

local function RateLimit(ip)
    local now = os.time()
    local limitUntil = now + RateLimitTimer
    
    local tbl = { ip = ip, limitUntil = now + RateLimitTimer }
    table.insert(rateLimitedIps, tbl)
end

local function countReqs()
    local counts = {}
    for _, v in ipairs(requests) do
        if IsRateLimited(v.ip) then
            goto continue
        end

        counts[v.ip] = (counts[v.ip] or 0) + 1
        print(v.ip..': '..counts[v.ip])
        ::continue::
    end
    return counts
end

local function onReq(req, ip)

    local reqData = {
        ip = ip,
        url = req.url,
        timestamp = os.time()
    }

    table.insert(requests, reqData)
    clearRequests()

    local counts = countReqs()
    for ipAddr, count in pairs(counts) do
        if count > MaxReqPerSec then
            RateLimit(ipAddr)
        end
    end
end

local function datastoreVisitLog(req, ip)   -- ips are saving for debugging stuff.
    local datastore = _G.VisitsDataStore
    local data = datastore:GetValue(tostring(ip)) or {}

    local requests = data.requests or {}

    local request = {}
    request.url = req.url
    request.method = req.method
    request.timestamp = os.time()

    table.insert(requests, request)

    data.requests = requests

    datastore:SetValue(tostring(ip), data)
end

function router:handler(req, res)
    
    local url = req.url
    local method = req.method
    local parsedUrl = parseUrl(url) or {}
    
    local sockaddr = req.socket:address()
    local ip = sockaddr and sockaddr.ip or "unknown"

    onReq(req, ip)

    if IsRateLimited(ip) then
        res.statusCode = 429
        res:finish([[You're rate limited. Try again in ]] .. RateLimitTimer / 60 .. ' minutes.')
        return
    end

    datastoreVisitLog(req, ip)

    if method == 'GET' then
        if #parsedUrl > 0 then
            for route, handler in pairs(GET_Routes) do
                if route == parsedUrl[1] then
                    handler(req, res, parsedUrl, ip)
                    return
                end
            end

            notfound(req, res)
        else
            GET_Routes['/'](req, res)
            return
        end
    elseif  method == 'POST' then
        if #parsedUrl > 0 then
            for route, handler in pairs(POST_Routes) do
                if route == parsedUrl[1] then
                    handler(req, res, parsedUrl, ip)
                    return
                end
            end

            notfound(req, res)
        else
            notfound(req, res)
            -- POST_Routes['/'](req, res)
            return
        end
    end

end

return router