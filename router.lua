local fs = require('fs')
local path = require('path')
local router = {}

-- functions

local function readFile(filepath)
    return fs.readFileSync(filepath)
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

local routes = {

    ['assets'] = function(req, res, parsedUrl)
        
        local asset = parsedUrl[2]
        Logger:Log('Requested asset: '..asset)

        serve_file(res, './assets/general/'..asset)

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
        
    end

}

function router:handler(req, res)
    
    local url = req.url
    local parsedUrl = parseUrl(url) or {}

    if #parsedUrl > 0 then
        for route, handler in pairs(routes) do
            if route == parsedUrl[1] then
                handler(req, res, parsedUrl)
                return
            end
        end

        notfound(req, res)
    else
        routes['/'](req, res)
        return
    end






end

return router