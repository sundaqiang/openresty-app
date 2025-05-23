local logger = require("utils.logger")
local conf = require("utils.config")
local route = require("resty.route").new()

local deps = {}

local middleware = require("middleware.main").new(deps)

middleware:add_middlewares_to(route)

route:get("=/", require("controllers.home").index)

logger:info("OpenResty 启动，配置加载成功", conf)

return route
