local conf = require("servers.config")
local route = require("resty.route").new()

local svcs = {
    -- 注入配置和日志
    conf = conf,
    log = require("servers.logger")
}

local middleware = require("middleware.main").new(svcs)

-- 引入中间件
middleware:add_middlewares_to(route)

-- 路由
route:get("=/", require("controllers.home").index)

return route
