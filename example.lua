#!/usr/local/bin/luvit

local lever = require('lever'):new(8080,"127.0.0.1")
local json = require('json')
local redis = require('redis')
local table = require('table')
local Transform = lever.Stream.Transform


local Body = Transform:extend()

function Body:initialize(max)
    self.max = max
    local opt = 
        {objectMode = true}
    Transform.initialize(self, opt)
end

function Body:_transform(data,encoding,cb)
    local chunks = {}
    data.req:on('data',function(data)
        chunks[#chunks + 1] = data
    end)

    data.req:on('end',function()
        data.data = json.parse(table.concat(chunks,""))
       	p(data.data)
        cb(nil,data)
    end)
end


-- kind of messy right now, but working to clean it up
local Request = Transform:extend()

function Request:initialize(ip,port)
    self.redis = redis:new(ip,port)
    self.redis:on('error',function(...)
        p(...)
    end)
    local opt = {objectMode = true}
    Transform.initialize(self, opt)
end

function Request:_transform(opts,encoding,cb)
    local cmd = opts.req.env.cmd
    if type(self.redis[cmd:lower()]) == "function" and type(self.redis[cmd:upper()]) == "function" then
    	-- p(cmd:lower(),unpack(opts.data))
        self.redis[cmd:lower()](self.redis,opts.data,function(err,res)
            if err then
                opts.code = 500
                opts.data = err.message
            else
                opts.data = res
            end
            cb(nil,opts)
        end)
    else
        opts.code = 404
        cb(nil,opts)
    end
end

local request = Request:new("127.0.0.1",6379)
local body = Body:new()


lever:post('/?cmd'):pipe(body):pipe(request):pipe(lever.json()):pipe(lever.reply())