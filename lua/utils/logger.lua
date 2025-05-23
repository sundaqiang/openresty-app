local cjson = require("cjson")
local Logger = require("resty.logger")
local conf = require("utils.config")

local function find_caller(index)
    if index > 0 then
        local info = debug.getinfo(index)
        return (info.short_src or "") .. ":" .. (info.currentline or "")
    end
    for i = 2, 20 do
        local info = debug.getinfo(i)
        if not info then break end
        local src = tostring(info.short_src)
        if not src:find("logger") then -- 跳过所有包名含"logger"的文件
            return i .. ":" .. (info.short_src or "") .. ":" .. (info.currentline or "")
        end
    end
    return ""
end

Logger:set_globle_opts({
    oputput_level = conf.log.level,
    log_file = function(scope, level)
        return ngx.config.prefix() .. "logs/" .. conf.app_name .. "." .. level .. ".log"
    end,
    formatter = function(log)
        local caller = find_caller(conf.log.caller_depth)
        return cjson.encode({
            ts = ngx.localtime(),
            scope = log.scope,
            level = log.level,
            message = log.message,
            error = log.error,
            data = log.data,
            caller = caller
        })
    end
})

local _M = {}

_M = Logger(conf.app_name)
return _M
