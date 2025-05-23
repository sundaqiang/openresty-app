local cjson = require("cjson")
local logger = require("utils.logger")
local conf = require("utils.config")

local _M = {}

function _M.index(self)
    logger:info(self.content)
    -- cat ngx.config.prefix()/logs/info.log
    logger:warn("This is a warn")
    -- cat ngx.config.prefix()/logs/warn.log
    logger:error("This is a error")
    -- cat ngx.config.prefix()/logs/error.log
    ngx.say(cjson.encode({
        data = conf
    }))
    ngx.exit(ngx.OK)
end

return _M
